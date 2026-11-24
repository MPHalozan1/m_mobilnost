// Accessibility audit widget tests pumping all 18 screens at 200% text scale and High Contrast AAA theme on a 390x844 phone viewport.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/app/app.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/theme/high_contrast_theme.dart';
import 'package:m_mobilnost/core/widgets/occupancy_strip.dart';
import 'package:m_mobilnost/data/mock/mock_auth_repository.dart';
import 'package:m_mobilnost/data/mock/mock_line_repository.dart';
import 'package:m_mobilnost/data/mock/mock_notice_repository.dart';
import 'package:m_mobilnost/data/mock/mock_ticket_repository.dart';
import 'package:m_mobilnost/data/mock/mock_timetable_repository.dart';
import 'package:m_mobilnost/data/models/bus_position.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/seed/seed_tickets.dart';
import 'package:m_mobilnost/features/account/presentation/account_screen.dart';
import 'package:m_mobilnost/features/account/presentation/payment_methods_screen.dart';
import 'package:m_mobilnost/features/home/presentation/home_screen.dart';
import 'package:m_mobilnost/features/lines/presentation/line_detail_screen.dart';
import 'package:m_mobilnost/features/lines/presentation/lines_screen.dart';
import 'package:m_mobilnost/features/live_tracker/presentation/live_tracker_screen.dart';
import 'package:m_mobilnost/features/map/data/location_service.dart';
import 'package:m_mobilnost/features/map/presentation/map_screen.dart';
import 'package:m_mobilnost/features/nearest_stop/presentation/nearest_stop_screen.dart';
import 'package:m_mobilnost/features/notices/presentation/notices_screen.dart';
import 'package:m_mobilnost/features/onboarding/presentation/new_rider_guide_screen.dart';
import 'package:m_mobilnost/features/onboarding/presentation/onboarding_screen.dart';
import 'package:m_mobilnost/features/settings/presentation/settings_screen.dart';
import 'package:m_mobilnost/features/tickets/presentation/ticket_checkout_screen.dart';
import 'package:m_mobilnost/features/tickets/presentation/ticket_shop_screen.dart';
import 'package:m_mobilnost/features/tickets/presentation/ticket_view_screen.dart';
import 'package:m_mobilnost/features/tickets/presentation/tickets_wallet_screen.dart';
import 'package:m_mobilnost/features/timetable/presentation/stop_detail_screen.dart';
import 'package:m_mobilnost/features/trip_planner/domain/route_planner.dart';
import 'package:m_mobilnost/features/trip_planner/presentation/trip_planner_screen.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _buildHighContrast200Container({
  bool signInDemoUser = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'a11y_locale_code': 'en',
    'a11y_extra_large_text': true,
    'a11y_theme_mode': AppThemeChoice.highContrast.name,
    'a11y_location_manual': true,
    'a11y_haptic_alerts': false,
    'a11y_onboarding_done': true,
  });
  final prefs = await SharedPreferences.getInstance();

  final suffix = DateTime.now().microsecondsSinceEpoch;
  final ticketRepo = MockTicketRepository(boxName: 'a11y_tkt_$suffix');
  final noticeRepo = MockNoticeRepository(boxName: 'a11y_ntc_$suffix');

  final now = DateTime(2026, 11, 23, 8, 15);
  final sampleBus = BusPosition(
    vehicleId: 'MB-G6-A11Y',
    lineId: 'G6',
    lineCode: 'G6',
    directionId: 'G6_out',
    directionName: 'Vzpenjača – AP Maribor – Melje',
    position: const LatLng(46.5457, 15.6448),
    progress: 0.45,
    speedKmh: 25.0,
    nextStopId: 'tabor',
    nextStopName: 'Tabor',
    remainingStopsCount: 5,
    etaToNextStopSeconds: 150,
    delaySeconds: 0,
    occupancy: BusOccupancyLevel.medium,
    updatedAt: now,
  );

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      isOfflineProvider.overrideWithValue(false),
      ticketRepositoryProvider.overrideWithValue(ticketRepo),
      noticeRepositoryProvider.overrideWithValue(noticeRepo),
      locationServiceProvider.overrideWithValue(
        LocationService(gpsProbe: () async => null),
      ),
      liveBusesStreamProvider.overrideWith(
        (ref) => Stream.value([sampleBus]),
      ),
      routePlannerProvider.overrideWithValue(
        RoutePlanner(
          lineRepository: const MockLineRepository(),
          timetableRepository: MockTimetableRepository(),
          clock: () => now,
        ),
      ),
    ],
  );

  final notifier = container.read(a11ySettingsProvider.notifier);
  await notifier.setLocaleCode('en');
  await notifier.setExtraLargeText(true);
  await notifier.setThemeMode(AppThemeChoice.highContrast);
  await notifier.setLocationManualMode(true);
  await notifier.setHapticAlertsEnabled(false);

  if (signInDemoUser) {
    final user = await container.read(authRepositoryProvider).signIn(
          email: MockAuthRepository.demoEmail,
          password: MockAuthRepository.demoPassword,
        );
    await ticketRepo.purchaseTicket(
      type: seedTicketTypes.first,
      userId: user.id,
    );
  }

  return container;
}

Future<void> _pumpAt200HighContrast(
  WidgetTester tester, {
  required ProviderContainer container,
  required Widget screen,
  bool wrapInScaffold = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final homeWidget = wrapInScaffold ? Scaffold(body: screen) : screen;
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => homeWidget,
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: MMobilnostApp.appSupportedLocales,
        locale: const Locale('en'),
        theme: HighContrastTheme.build(),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: const TextScaler.linear(2.0),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8: 200% Text Scale & High Contrast AAA on 390x844 phone viewport',
      () {
    testWidgets('1. HomeScreen renders without overflow at 200% text scale',
        (tester) async {
      final container =
          await _buildHighContrast200Container(signInDemoUser: true);
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const HomeScreen(),
        wrapInScaffold: true,
      );
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('2. LinesScreen renders without overflow at 200% text scale',
        (tester) async {
      final container = await _buildHighContrast200Container();
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const LinesScreen(),
      );
      expect(find.byType(LinesScreen), findsOneWidget);
    });

    testWidgets(
        '3. LineDetailScreen renders without overflow at 200% text scale',
        (tester) async {
      final container = await _buildHighContrast200Container();
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const LineDetailScreen(lineId: 'G6'),
      );
      expect(find.byType(LineDetailScreen), findsOneWidget);
    });

    testWidgets(
        '4. StopDetailScreen renders without overflow at 200% text scale',
        (tester) async {
      final container = await _buildHighContrast200Container();
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const StopDetailScreen(stopId: 'glavni_trg'),
      );
      expect(find.byType(StopDetailScreen), findsOneWidget);
    });

    testWidgets('5. MapScreen renders without overflow at 200% text scale',
        (tester) async {
      final container = await _buildHighContrast200Container();
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const MapScreen(),
        wrapInScaffold: true,
      );
      expect(find.byType(MapScreen), findsOneWidget);
    });

    testWidgets(
        '6. LiveTrackerScreen renders without overflow at 200% text scale',
        (tester) async {
      final container = await _buildHighContrast200Container();
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const LiveTrackerScreen(initialLineId: 'G6'),
      );
      expect(find.byType(LiveTrackerScreen), findsOneWidget);
    });

    testWidgets(
        '7. TripPlannerScreen renders without overflow at 200% text scale',
        (tester) async {
      final container = await _buildHighContrast200Container();
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const TripPlannerScreen(
          initialFromStopId: 'glavni_trg',
          initialToStopId: 'ukc_maribor',
        ),
      );
      expect(find.byType(TripPlannerScreen), findsOneWidget);
    });

    testWidgets(
        '8. NearestStopScreen renders without overflow at 200% text scale',
        (tester) async {
      final container = await _buildHighContrast200Container();
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const NearestStopScreen(initialToName: 'UKC Maribor'),
      );
      expect(find.byType(NearestStopScreen), findsOneWidget);
    });

    testWidgets(
        '9. TicketsWalletScreen renders without overflow at 200% text scale',
        (tester) async {
      final container =
          await _buildHighContrast200Container(signInDemoUser: true);
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const TicketsWalletScreen(),
      );
      expect(find.byType(TicketsWalletScreen), findsOneWidget);
    });

    testWidgets(
        '10. TicketShopScreen renders without overflow at 200% text scale',
        (tester) async {
      final container =
          await _buildHighContrast200Container(signInDemoUser: true);
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const TicketShopScreen(),
      );
      expect(find.byType(TicketShopScreen), findsOneWidget);
    });

    testWidgets(
        '11. TicketCheckoutScreen renders without overflow at 200% text scale',
        (tester) async {
      final container =
          await _buildHighContrast200Container(signInDemoUser: true);
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const TicketCheckoutScreen(typeId: 'single'),
      );
      expect(find.byType(TicketCheckoutScreen), findsOneWidget);
    });

    testWidgets(
        '12. TicketViewScreen renders without overflow at 200% text scale',
        (tester) async {
      final container =
          await _buildHighContrast200Container(signInDemoUser: true);
      addTearDown(container.dispose);

      final user = container.read(authRepositoryProvider).currentUser!;
      final tickets =
          await container.read(ticketRepositoryProvider).getUserTickets(user.id);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: TicketViewScreen(ticketId: tickets.first.id),
      );
      expect(find.byType(TicketViewScreen), findsOneWidget);
    });

    testWidgets(
        '13. AccountScreen (guest & signed-in) renders without overflow at 200% text scale',
        (tester) async {
      final guestContainer = await _buildHighContrast200Container();
      addTearDown(guestContainer.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: guestContainer,
        screen: const AccountScreen(),
      );
      expect(find.byType(AccountScreen), findsOneWidget);

      final authContainer =
          await _buildHighContrast200Container(signInDemoUser: true);
      addTearDown(authContainer.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: authContainer,
        screen: const AccountScreen(),
      );
      expect(find.byType(AccountScreen), findsOneWidget);
    });

    testWidgets(
        '14. PaymentMethodsScreen renders without overflow at 200% text scale',
        (tester) async {
      final container =
          await _buildHighContrast200Container(signInDemoUser: true);
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const PaymentMethodsScreen(),
      );
      expect(find.byType(PaymentMethodsScreen), findsOneWidget);
    });

    testWidgets(
        '15. NoticesScreen renders without overflow at 200% text scale',
        (tester) async {
      final container = await _buildHighContrast200Container();
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const NoticesScreen(),
      );
      expect(find.byType(NoticesScreen), findsOneWidget);
    });

    testWidgets(
        '16. SettingsScreen renders without overflow at 200% text scale',
        (tester) async {
      final container = await _buildHighContrast200Container();
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const SettingsScreen(),
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets(
        '17. OnboardingScreen renders without overflow at 200% text scale',
        (tester) async {
      final container = await _buildHighContrast200Container();
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const OnboardingScreen(),
      );
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets(
        '18. NewRiderGuideScreen renders without overflow at 200% text scale',
        (tester) async {
      final container = await _buildHighContrast200Container();
      addTearDown(container.dispose);

      await _pumpAt200HighContrast(
        tester,
        container: container,
        screen: const NewRiderGuideScreen(),
      );
      expect(find.byType(NewRiderGuideScreen), findsOneWidget);
    });
  });
}
