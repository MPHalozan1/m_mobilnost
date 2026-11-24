// Unit and widget tests for Phase 6 account, payments, shop, checkout, wallet, QR, and NFC stub.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/theme/app_theme.dart';
import 'package:m_mobilnost/core/widgets/big_button.dart';
import 'package:m_mobilnost/data/mock/mock_auth_repository.dart';
import 'package:m_mobilnost/data/models/payment_method.dart';
import 'package:m_mobilnost/data/models/ticket.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/seed/seed_tickets.dart';
import 'package:m_mobilnost/features/account/presentation/account_screen.dart';
import 'package:m_mobilnost/features/account/presentation/payment_methods_screen.dart';
import 'package:m_mobilnost/features/account/providers/account_providers.dart';
import 'package:m_mobilnost/features/tickets/nfc/ticket_card_reader.dart';
import 'package:m_mobilnost/features/tickets/presentation/ticket_checkout_screen.dart';
import 'package:m_mobilnost/features/tickets/presentation/ticket_shop_screen.dart';
import 'package:m_mobilnost/features/tickets/presentation/ticket_view_screen.dart';
import 'package:m_mobilnost/features/tickets/presentation/tickets_wallet_screen.dart';
import 'package:m_mobilnost/features/tickets/providers/ticket_providers.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';

Widget _wrapWithApp({
  required ProviderContainer container,
  required Widget child,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.light(),
      builder: (context, innerChild) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: innerChild ?? const SizedBox.shrink(),
        );
      },
      home: child,
    ),
  );
}

Future<ProviderContainer> _createContainer({
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      isOfflineProvider.overrideWithValue(false),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pure logic: StubTicketCardReader, card validation, minor & wallet filtering',
      () {
    test('StubTicketCardReader reports coming soon and simulates validation',
        () async {
      final fixedTime = DateTime(2026, 11, 23, 12, 30);
      final reader = StubTicketCardReader(clock: () => fixedTime);

      expect(await reader.isAvailable(), isFalse);
      final status = await reader.readCardStatus();
      expect(status.isAvailable, isFalse);
      expect(status.message, 'NFC card in app coming soon');

      final validatedAt = await reader.simulateTapValidation('tkt_42');
      expect(validatedAt, fixedTime);
      expect(
        () => reader.simulateTapValidation('   '),
        throwsArgumentError,
      );

      final platformReader = PlatformNfcTicketCardReader(clock: () => fixedTime);
      final platformStatus = await platformReader.readCardStatus();
      expect(platformStatus.aidHex, PlatformNfcTicketCardReader.marpromAidHex);
      expect(
        await platformReader.armTicketForNfc(
          ticketId: 'tkt_42',
          payload: 'MARPROM|SINGLE75',
        ),
        isTrue,
      );
      expect(await platformReader.simulateTapValidation('tkt_42'), fixedTime);

      expect(seedTicketTypesById['single']!.priceEur, 1.50);
      expect(seedTicketTypesById['day_24h']!.priceEur, 6.00);
      expect(seedTicketTypesById['monthly']!.priceEur, 36.00);
      expect(seedTicketTypesById['pr_zone_a']!.priceEur, 49.00);
    });

    test('isValidCardLast4 strictly accepts only 4 numeric digits', () {
      expect(isValidCardLast4('4242'), isTrue);
      expect(isValidCardLast4(' 0099 '), isTrue);
      expect(isValidCardLast4('123'), isFalse);
      expect(isValidCardLast4('12345'), isFalse);
      expect(isValidCardLast4('12a4'), isFalse);
      expect(isValidCardLast4(''), isFalse);
    });

    test('requiresGuardianConsent distinguishes <16 signup vs <18 purchase',
        () {
      final refDate = DateTime(2026, 11, 23);
      final age15 = DateTime(2011, 5, 10);
      final age17 = DateTime(2009, 5, 10);
      final age20 = DateTime(2006, 5, 10);

      expect(
        requiresGuardianConsent(age15, forPurchase: false, referenceDate: refDate),
        isTrue,
      );
      expect(
        requiresGuardianConsent(age15, forPurchase: true, referenceDate: refDate),
        isTrue,
      );
      expect(
        requiresGuardianConsent(age17, forPurchase: false, referenceDate: refDate),
        isFalse,
      );
      expect(
        requiresGuardianConsent(age17, forPurchase: true, referenceDate: refDate),
        isTrue,
      );
      expect(
        requiresGuardianConsent(age20, forPurchase: true, referenceDate: refDate),
        isFalse,
      );
    });

    test('partitionTicketsByStatus separates active, upcoming, and expired', () {
      final now = DateTime(2026, 11, 23, 12, 0);
      final singleType = seedTicketTypesById['single']!;

      final active = Ticket.issue(
        id: 't_active',
        ticketTypeId: singleType.id,
        ticketCode: singleType.code,
        titles: singleType.titles,
        priceEur: singleType.priceEur,
        zone: singleType.zone,
        durationMinutes: singleType.durationMinutes,
        qrPayload: 'QR1',
        driverFallbackCode: 'MB-1',
        userId: 'u1',
        purchasedAt: now.subtract(const Duration(minutes: 10)),
      );
      final upcoming = Ticket.issue(
        id: 't_upcoming',
        ticketTypeId: singleType.id,
        ticketCode: singleType.code,
        titles: singleType.titles,
        priceEur: singleType.priceEur,
        zone: singleType.zone,
        durationMinutes: singleType.durationMinutes,
        qrPayload: 'QR2',
        driverFallbackCode: 'MB-2',
        userId: 'u1',
        purchasedAt: now,
        validFrom: now.add(const Duration(hours: 2)),
      );
      final expired = Ticket.issue(
        id: 't_expired',
        ticketTypeId: singleType.id,
        ticketCode: singleType.code,
        titles: singleType.titles,
        priceEur: singleType.priceEur,
        zone: singleType.zone,
        durationMinutes: singleType.durationMinutes,
        qrPayload: 'QR3',
        driverFallbackCode: 'MB-3',
        userId: 'u1',
        purchasedAt: now.subtract(const Duration(hours: 3)),
      );

      final partitioned = partitionTicketsByStatus(
        [expired, upcoming, active],
        referenceTime: now,
      );
      expect(partitioned.active.map((t) => t.id), ['t_active']);
      expect(partitioned.upcoming.map((t) => t.id), ['t_upcoming']);
      expect(partitioned.expired.map((t) => t.id), ['t_expired']);
      expect(formatTicketCountdown(const Duration(minutes: 14, seconds: 5)),
          '14:05');
    });
  });

  group('Shop & Checkout widget flows', () {
    testWidgets('Guest can browse shop but tapping Buy shows Sign In prompt',
        (tester) async {
      final container = await _createContainer(initialPrefs: {'a11y_locale_code': 'en'});
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWithApp(
          container: container,
          child: const TicketShopScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Single ride ticket (75 min)'), findsOneWidget);
      expect(find.text('Demo payment — no real money is charged'), findsOneWidget);

      await tester.tap(find.text('Buy ticket').first);
      await tester.pumpAndSettle();

      expect(find.text('Account needed to buy tickets'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Account needed to buy tickets'), findsNothing);
    });

    testWidgets(
        'Signed-in adult completes 3-step checkout with immediate or start-later validity',
        (tester) async {
      final container = await _createContainer(initialPrefs: {'a11y_locale_code': 'en'});
      addTearDown(container.dispose);

      final user = await container.read(authRepositoryProvider).signIn(
            email: MockAuthRepository.demoEmail,
            password: MockAuthRepository.demoPassword,
          );

      await tester.pumpWidget(
        _wrapWithApp(
          container: container,
          child: const TicketCheckoutScreen(typeId: 'single'),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Choose immediate or start later.
      expect(find.text('1. Ticket'), findsOneWidget);
      expect(find.text('Valid immediately (recommended)'), findsOneWidget);
      expect(find.text('Choose start time'), findsOneWidget);

      // Toggle start-later to verify date & time pickers appear, then switch back to immediate.
      await tester.ensureVisible(find.text('Choose start time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose start time'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      await tester.ensureVisible(find.text('Valid immediately (recommended)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valid immediately (recommended)'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Payment method selection.
      expect(find.text('2. Payment'), findsOneWidget);
      expect(find.text('Visa •••• 4242'), findsOneWidget);
      final googlePayFinder = find.text('Google Pay').first;
      await tester.ensureVisible(googlePayFinder);
      await tester.pumpAndSettle();
      await tester.tap(googlePayFinder);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: Confirmation and demo payment notice.
      expect(find.text('3. Confirm'), findsOneWidget);
      expect(find.text('Demo payment — no real money is charged'), findsOneWidget);

      await tester.ensureVisible(find.text('Pay now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay now'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ticket purchased and ready to use.'),
        findsOneWidget,
      );

      final tickets =
          await container.read(ticketRepositoryProvider).getUserTickets(user.id);
      expect(tickets, hasLength(1));
      expect(tickets.first.status, TicketStatus.active);
    });

    testWidgets(
        'Minor under 18 cannot advance checkout without guardian confirmation checkbox',
        (tester) async {
      final container = await _createContainer(initialPrefs: {'a11y_locale_code': 'en'});
      addTearDown(container.dispose);

      await container.read(authRepositoryProvider).signUp(
            email: 'minor17@maribor.test',
            password: 'pass1234',
            name: 'Rok Minor',
            dateOfBirth: DateTime(DateTime.now().year - 17, 1, 1),
          );

      await tester.pumpWidget(
        _wrapWithApp(
          container: container,
          child: const TicketCheckoutScreen(typeId: 'youth'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Parent or guardian confirmation'), findsOneWidget);

      // Next button must be disabled while unchecked.
      final nextBtn = tester.widget<BigButton>(
        find.ancestor(
          of: find.text('Next'),
          matching: find.byType(BigButton),
        ),
      );
      expect(nextBtn.onPressed, isNull);

      final guardianCheck =
          find.text('I confirm I have parent or guardian permission.');
      await tester.ensureVisible(guardianCheck);
      await tester.pumpAndSettle();
      await tester.tap(guardianCheck);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2. Payment'), findsOneWidget);
    });
  });

  group('Account & Payment Methods screens', () {
    testWidgets(
        'AccountScreen supports demo quick-fill login, youth badge, language sync, and deleteAccount',
        (tester) async {
      final container = await _createContainer(initialPrefs: {'a11y_locale_code': 'en'});
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWithApp(
          container: container,
          child: const AccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Guest mode'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // Quick-fill demo credentials and sign in.
      final demoBtn = find.text('Demo user: demo@marprom.test / demo1234');
      await tester.ensureVisible(demoBtn);
      await tester.pumpAndSettle();
      await tester.tap(demoBtn);
      await tester.pumpAndSettle();

      final signInBtn = find.widgetWithText(BigButton, 'Sign in').last;
      await tester.ensureVisible(signInBtn);
      await tester.pumpAndSettle();
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(find.text('Ana Kovač'), findsWidgets);

      // Switch language chip to English and verify a11ySettingsProvider updates.
      await tester.ensureVisible(find.text('Slovenščina'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slovenščina'));
      await tester.pumpAndSettle();
      expect(container.read(a11ySettingsProvider).localeCode, 'sl');

      await tester.ensureVisible(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(container.read(a11ySettingsProvider).localeCode, 'en');

      // Delete account confirmation dialog clears session.
      final deleteBtn = find.text('Delete my account and data');
      await tester.ensureVisible(deleteBtn);
      await tester.pumpAndSettle();
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Delete account and all local data?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(container.read(authRepositoryProvider).currentUser, isNull);
    });

    testWidgets('AccountScreen signs in with Google Account', (tester) async {
      final container =
          await _createContainer(initialPrefs: {'a11y_locale_code': 'en'});
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWithApp(
          container: container,
          child: const AccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      final user = container.read(authRepositoryProvider).currentUser;
      expect(user, isNotNull);
      expect(user!.authProvider, 'google');
      expect(find.text('Google Account'), findsOneWidget);
    });

    testWidgets(
        'AccountScreen minor signup under 16 requires guardian confirmation checkbox',
        (tester) async {
      final container = await _createContainer(initialPrefs: {'a11y_locale_code': 'en'});
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWithApp(
          container: container,
          child: const AccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(BigButton, 'Create account'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Maja Mlada',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'maja@maribor.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'pass1234',
      );

      // Pick DOB via DatePicker input mode (pencil icon).
      final dobBtn = find.text('Date of birth');
      await tester.ensureVisible(dobBtn);
      await tester.pumpAndSettle();
      await tester.tap(dobBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      final under16Year = DateTime.now().year - 14;
      final dateField = find.byType(TextField).last;
      await tester.enterText(dateField, '05/10/$under16Year');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Minor <16 warning and checkbox must now be shown.
      final guardianCheck =
          find.text('I confirm I have parent or guardian permission.');
      await tester.ensureVisible(guardianCheck);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Passengers under 16 require parent or legal guardian confirmation for online purchases.',
        ),
        findsWidgets,
      );

      // Tapping Create account without checking checkbox must block signup.
      final submitBtn = find.widgetWithText(BigButton, 'Create account').last;
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      expect(container.read(authRepositoryProvider).currentUser, isNull);

      // Check guardian checkbox and submit again -> succeeds.
      await tester.ensureVisible(guardianCheck);
      await tester.pumpAndSettle();
      await tester.tap(guardianCheck);
      await tester.pumpAndSettle();

      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      final created = container.read(authRepositoryProvider).currentUser;
      expect(created, isNotNull);
      expect(created!.guardianConfirmed, isTrue);
      expect(created.isYouthEligible, isTrue);
    });

    testWidgets(
        'PaymentMethodsScreen lists 5 methods, validates 4 digits only, sets default, and removes',
        (tester) async {
      final container = await _createContainer(initialPrefs: {'a11y_locale_code': 'en'});
      addTearDown(container.dispose);

      final user = await container.read(authRepositoryProvider).signIn(
            email: MockAuthRepository.demoEmail,
            password: MockAuthRepository.demoPassword,
          );

      await tester.pumpWidget(
        _wrapWithApp(
          container: container,
          child: const PaymentMethodsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Demo payment — no real money is charged'), findsOneWidget);
      expect(find.text('Visa •••• 4242'), findsOneWidget);
      expect(find.text('Google Pay'), findsWidgets);
      expect(find.text('Apple Pay'), findsWidgets);
      expect(find.text('NLB Klik / e-Banking'), findsOneWidget);
      expect(find.text('Valú / mBills'), findsOneWidget);

      // Open add card form and verify < 4 digit validation error.
      await tester.tap(find.text('Add payment method'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Card brand (e.g. Visa)'),
        'Mastercard',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last 4 digits only (demo)'),
        '12',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter exactly 4 digits'), findsOneWidget);

      // Enter valid 4 digits -> saved as default.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last 4 digits only (demo)'),
        '9876',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Mastercard •••• 9876'), findsOneWidget);
      final methods =
          await container.read(paymentRepositoryProvider).getPaymentMethods(user.id);
      final added = methods.firstWhere((m) => m.last4Digits == '9876');
      expect(added.type, PaymentMethodType.card);
      expect(added.isDefault, isTrue);

      // Remove a payment method.
      await tester.tap(find.text('Remove').first);
      await tester.pumpAndSettle();
      final afterRemove =
          await container.read(paymentRepositoryProvider).getPaymentMethods(user.id);
      expect(afterRemove.length, methods.length - 1);
    });
  });

  group('Wallet & QR Ticket Viewer', () {
    testWidgets(
        'TicketsWalletScreen filters active/upcoming/expired and adapts 2-pane on expanded width',
        (tester) async {
      final container = await _createContainer(initialPrefs: {'a11y_locale_code': 'en'});
      addTearDown(container.dispose);

      final user = await container.read(authRepositoryProvider).signIn(
            email: MockAuthRepository.demoEmail,
            password: MockAuthRepository.demoPassword,
          );
      final ticketRepo = container.read(ticketRepositoryProvider);
      final singleType = seedTicketTypesById['single']!;
      final dayType = seedTicketTypesById['day_24h']!;

      await ticketRepo.purchaseTicket(type: singleType, userId: user.id);
      await ticketRepo.purchaseTicket(
        type: dayType,
        userId: user.id,
        validFrom: DateTime.now().add(const Duration(hours: 3)),
      );

      // Render at expanded >1024px desktop size.
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          container: container,
          child: const TicketsWalletScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Buy ticket'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);

      // 2-pane detail shows QrImageView on the right pane.
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Single ride ticket (75 min)'), findsWidgets);

      // Switch to Upcoming tab.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();
      expect(find.text('24-hour day pass'), findsOneWidget);

      // Switch to Expired tab.
      await tester.tap(find.text('Expired'));
      await tester.pumpAndSettle();
      expect(find.text('No expired tickets.'), findsOneWidget);
    });

    testWidgets(
        'TicketViewScreen displays QR, live clock, reducedMotion, 200% text scale, TTS, and NFC stub',
        (tester) async {
      final container = await _createContainer(initialPrefs: {
        'a11y_locale_code': 'en',
        'a11y_reduced_motion': true,
      });
      addTearDown(container.dispose);

      final user = await container.read(authRepositoryProvider).signIn(
            email: MockAuthRepository.demoEmail,
            password: MockAuthRepository.demoPassword,
          );
      final ticket = await container.read(ticketRepositoryProvider).purchaseTicket(
            type: seedTicketTypesById['single']!,
            userId: user.id,
          );

      await tester.pumpWidget(
        _wrapWithApp(
          container: container,
          textScale: 2.0,
          child: TicketViewScreen(ticketId: ticket.id),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        find.text('Live clock prevents screenshot misuse'),
        findsOneWidget,
      );
      expect(
        find.text('Driver fallback code: ${ticket.driverFallbackCode}'),
        findsOneWidget,
      );
      expect(find.text('NFC card in app coming soon'), findsOneWidget);

      // Tap Read aloud TTS button (must not throw in headless tests).
      final readAloudBtn = find.text('Read aloud');
      await tester.ensureVisible(readAloudBtn);
      await tester.pumpAndSettle();
      await tester.tap(readAloudBtn);
      await tester.pumpAndSettle();

      // Tap Simulate NFC tap button -> validates ticket cleanly.
      final nfcBtn = find.text('Simulate NFC tap');
      await tester.ensureVisible(nfcBtn);
      await tester.pumpAndSettle();
      await tester.tap(nfcBtn);
      await tester.pumpAndSettle();

      expect(find.text('Ticket validated successfully.'), findsOneWidget);
      final updatedTickets =
          await container.read(ticketRepositoryProvider).getUserTickets(user.id);
      expect(updatedTickets.first.validatedAt, isNotNull);
    });
  });
}
