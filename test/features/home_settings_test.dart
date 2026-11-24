// Unit and widget tests for AskMarpromAssistant, UsabilityTracker, and Phase 7 screens.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:m_mobilnost/app/app.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/accessibility/favorites_provider.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/network/data_freshness.dart';
import 'package:m_mobilnost/core/widgets/big_button.dart';
import 'package:m_mobilnost/core/widgets/bus_occupancy_cutaway.dart';
import 'package:m_mobilnost/core/widgets/occupancy_strip.dart';
import 'package:m_mobilnost/core/widgets/status_chip.dart';
import 'package:m_mobilnost/data/mock/mock_line_repository.dart';
import 'package:m_mobilnost/data/mock/mock_notice_repository.dart';
import 'package:m_mobilnost/data/mock/mock_ticket_repository.dart';
import 'package:m_mobilnost/data/mock/mock_timetable_repository.dart';
import 'package:m_mobilnost/data/mock/mock_trip_repository.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/seed/seed_tickets.dart';
import 'package:m_mobilnost/features/home/domain/ask_marprom.dart';
import 'package:m_mobilnost/features/home/presentation/home_screen.dart';
import 'package:m_mobilnost/features/notices/presentation/notices_screen.dart';
import 'package:m_mobilnost/features/onboarding/presentation/new_rider_guide_screen.dart';
import 'package:m_mobilnost/features/onboarding/presentation/onboarding_screen.dart';
import 'package:m_mobilnost/features/settings/domain/usability_tracker.dart';
import 'package:m_mobilnost/features/settings/presentation/settings_screen.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';

Widget _wrapWithRouter({
  required ProviderContainer container,
  required Widget home,
  List<GoRoute> extraRoutes = const [],
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => home,
      ),
      for (final r in extraRoutes) r,
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(a11ySettingsProvider);
        return MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: MMobilnostApp.appSupportedLocales,
          locale: settings.toLocale(),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final scale = settings.extraLargeText ? 2.0 : 1.0;
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AskMarpromAssistant', () {
    late AskMarpromAssistant assistant;
    late MockNoticeRepository noticeRepo;
    late MockTicketRepository ticketRepo;

    setUp(() {
      const lineRepo = MockLineRepository();
      final timetableRepo = MockTimetableRepository();
      noticeRepo = MockNoticeRepository(
        boxName: 'test_ask_notices_${DateTime.now().microsecondsSinceEpoch}',
      );
      ticketRepo = MockTicketRepository(
        boxName: 'test_ask_tickets_${DateTime.now().microsecondsSinceEpoch}',
      );
      final tripRepo = MockTripRepository(
        lineRepository: lineRepo,
        timetableRepository: timetableRepo,
      );
      assistant = AskMarpromAssistant(
        lineRepository: lineRepo,
        timetableRepository: timetableRepo,
        noticeRepository: noticeRepo,
        tripRepository: tripRepo,
        ticketRepository: ticketRepo,
      );
    });

    tearDown(() {
      noticeRepo.dispose();
      ticketRepo.dispose();
    });

    test('answers next-bus stop query in Slovenian and English', () async {
      final slL10n = lookupAppLocalizations(const Locale('sl'));
      final enL10n = lookupAppLocalizations(const Locale('en'));
      final testNow = DateTime(2026, 11, 23, 9, 0);

      final slReply = await assistant.ask(
        slL10n.askSample1,
        l10n: slL10n,
        localeCode: 'sl',
        now: testNow,
      );
      expect(slReply.intent, AskIntent.nextBus);
      expect(slReply.text, contains('Glavni trg'));
      expect(slReply.suggestedRoute, '/stops/glavni_trg');
      expect(slReply.freshness?.kind, DataSourceKind.simulated);

      final enReply = await assistant.ask(
        'When is the next bus 6?',
        l10n: enL10n,
        localeCode: 'en',
        now: testNow,
        useSimulatedLive: false,
      );
      expect(enReply.intent, AskIntent.lineInfo);
      expect(enReply.text, contains('Line G6'));
      expect(enReply.suggestedRoute, '/lines/G6');
      expect(enReply.freshness?.kind, DataSourceKind.cached);
    });

    test('answers disruption, nearest-stop, ticket, and unknown queries',
        () async {
      final enL10n = lookupAppLocalizations(const Locale('en'));
      final testNow = DateTime(2026, 11, 23, 10, 0);

      final disruptionReply = await assistant.ask(
        enL10n.askSample3,
        l10n: enL10n,
        localeCode: 'en',
        now: testNow,
      );
      expect(disruptionReply.intent, AskIntent.disruptions);
      expect(disruptionReply.suggestedRoute, '/notices');
      expect(disruptionReply.text, contains('Detour'));

      final ticketReply = await assistant.ask(
        enL10n.askSample2,
        l10n: enL10n,
        localeCode: 'en',
        now: testNow,
      );
      expect(ticketReply.intent, AskIntent.ticket);
      expect(ticketReply.suggestedRoute, '/tickets/shop');
      expect(ticketReply.text, contains('€'));

      final nearestReply = await assistant.ask(
        enL10n.askSample4,
        l10n: enL10n,
        localeCode: 'en',
        now: testNow,
      );
      expect(nearestReply.intent, AskIntent.nearestStop);
      expect(nearestReply.suggestedRoute, '/nearest-stop');
      expect(nearestReply.text, contains('Drava'));

      final unknownReply = await assistant.ask(
        'blabla unrecognized prompt',
        l10n: enL10n,
        localeCode: 'en',
        now: testNow,
      );
      expect(unknownReply.intent, AskIntent.unknown);
      expect(unknownReply.text, enL10n.askNoMatch);
    });
  });

  group('UsabilityTracker', () {
    test('records timing, taps, errors, and exports zero-PII CSV and JSON', () {
      var now = DateTime.utc(2026, 11, 23, 12, 0, 0);
      final tracker = UsabilityTracker(clock: () => now);

      // No-op when idle.
      tracker.recordTap();
      tracker.recordError();
      expect(tracker.state.tapCount, 0);
      expect(tracker.finishScenario(), isNull);

      tracker.startScenario('find_next_bus');
      expect(tracker.state.isRunning, isTrue);

      tracker.recordTap();
      tracker.recordTap();
      tracker.recordTap();
      tracker.recordError();

      now = now.add(const Duration(seconds: 42));
      expect(tracker.elapsedSeconds(), 42);

      final result = tracker.finishScenario();
      expect(result, isNotNull);
      expect(result!.scenarioId, 'find_next_bus');
      expect(result.durationSeconds, 42);
      expect(result.tapCount, 3);
      expect(result.errorCount, 1);
      expect(tracker.state.isRunning, isFalse);

      final csv = tracker.exportCsv();
      final csvLines = csv.split('\n');
      expect(
        csvLines.first,
        'scenario_id,duration_seconds,tap_count,error_count,started_at_utc,completed_at_utc',
      );
      expect(csvLines.length, 2);
      expect(csvLines[1], startsWith('find_next_bus,42,3,1,'));

      final decoded = jsonDecode(tracker.exportJson()) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], 1);
      expect(decoded['containsPersonalData'], isFalse);
      final scenarios = decoded['scenarios'] as List<dynamic>;
      expect(scenarios.length, 1);
      final first = scenarios.first as Map<String, dynamic>;
      expect(first['scenarioId'], 'find_next_bus');
      expect(first['durationSeconds'], 42);
      expect(first['tapCount'], 3);
      expect(first['errorCount'], 1);
      expect(first.containsKey('email'), isFalse);
      expect(first.containsKey('name'), isFalse);
    });
  });

  group('Phase 7 Screens', () {
    testWidgets('SettingsScreen switches language, theme, offline, and usability',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isOfflineProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWithRouter(
          container: container,
          home: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Default Slovenian title.
      expect(find.text('Nastavitve'), findsOneWidget);

      // Switch to Srpski / Hrvatski.
      await tester.tap(find.text('Srpski / Hrvatski'));
      await tester.pumpAndSettle();
      expect(container.read(a11ySettingsProvider).localeCode, 'sr_Latn');
      expect(
        container.read(a11ySettingsProvider).toLocale(),
        const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
      );
      expect(find.text('Postavke'), findsOneWidget);

      // Switch to English.
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(container.read(a11ySettingsProvider).localeCode, 'en');
      expect(find.text('Settings'), findsOneWidget);

      // Switch theme to High Contrast (AAA).
      final highContrastBtn = find.text('High contrast (AAA)');
      await tester.ensureVisible(highContrastBtn);
      await tester.pumpAndSettle();
      await tester.tap(highContrastBtn);
      await tester.pumpAndSettle();
      expect(
        container.read(a11ySettingsProvider).themeMode,
        AppThemeChoice.highContrast,
      );

      // Toggle Usability test mode and run a scenario + export CSV.
      final usabilitySwitch = find.text('Usability test mode');
      await tester.ensureVisible(usabilitySwitch);
      await tester.pumpAndSettle();
      await tester.tap(usabilitySwitch);
      await tester.pumpAndSettle();

      final startBtn = find.text('Start timed scenario');
      await tester.ensureVisible(startBtn);
      await tester.pumpAndSettle();
      await tester.tap(startBtn);
      await tester.pumpAndSettle();
      expect(container.read(usabilityTrackerProvider).isRunning, isTrue);

      final logErrorBtn = find.text('Log error (+1)');
      await tester.ensureVisible(logErrorBtn);
      await tester.pumpAndSettle();
      await tester.tap(logErrorBtn);
      await tester.pumpAndSettle();
      expect(container.read(usabilityTrackerProvider).errorCount, 1);

      final finishBtn = find.text('Complete scenario');
      await tester.ensureVisible(finishBtn);
      await tester.pumpAndSettle();
      await tester.tap(finishBtn);
      await tester.pumpAndSettle();
      expect(container.read(usabilityTrackerProvider).isRunning, isFalse);

      final exportCsvBtn = find.text('Export CSV');
      await tester.ensureVisible(exportCsvBtn);
      await tester.pumpAndSettle();
      await tester.tap(exportCsvBtn);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('scenario_id,duration_seconds,tap_count'),
        findsOneWidget,
      );
    });

    testWidgets('OnboardingScreen defaults analytics OFF and completes flow',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isOfflineProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWithRouter(
          container: container,
          home: const OnboardingScreen(),
          extraRoutes: [
            GoRoute(
              path: '/guide',
              builder: (_, _) => const NewRiderGuideScreen(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(a11ySettingsProvider).analyticsConsent, isFalse);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Start riding'), findsOneWidget);

      final openGuideBtn = find.text('New to the bus? Open guide');
      await tester.ensureVisible(openGuideBtn);
      await tester.pumpAndSettle();
      await tester.tap(openGuideBtn);
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 5'), findsOneWidget);
      final nextBtn = find.text('Next');
      await tester.ensureVisible(nextBtn);
      await tester.pumpAndSettle();
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 5'), findsOneWidget);
    });

    testWidgets('NoticesScreen filters disruptions and triggers visual test',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final noticeRepo = MockNoticeRepository(
        boxName: 'test_notices_screen_${DateTime.now().microsecondsSinceEpoch}',
      );
      addTearDown(noticeRepo.dispose);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isOfflineProvider.overrideWithValue(false),
          noticeRepositoryProvider.overrideWithValue(noticeRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(a11ySettingsProvider.notifier).setLocaleCode('en');

      await tester.pumpWidget(
        _wrapWithRouter(
          container: container,
          home: const NoticesScreen(),
          extraRoutes: [
            GoRoute(
              path: '/plan',
              builder: (_, _) => const Scaffold(body: Text('Plan')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notices & smart alerts'), findsOneWidget);
      await tester.tap(find.text('Test visual & vibration alert'));
      await tester.pumpAndSettle();
      expect(find.text('Service alert on your favourite line'), findsOneWidget);

      await tester.tap(find.text('Disruptions'));
      await tester.pumpAndSettle();
      expect(find.text('Find alternative route'), findsWidgets);
    });

    testWidgets('HomeScreen renders Next bus, favorites, ticket, and Ask sheet',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ticketRepo = MockTicketRepository(
        boxName: 'test_home_tickets_${DateTime.now().microsecondsSinceEpoch}',
      );
      final noticeRepo = MockNoticeRepository(
        boxName: 'test_home_notices_${DateTime.now().microsecondsSinceEpoch}',
      );
      addTearDown(ticketRepo.dispose);
      addTearDown(noticeRepo.dispose);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isOfflineProvider.overrideWithValue(false),
          ticketRepositoryProvider.overrideWithValue(ticketRepo),
          noticeRepositoryProvider.overrideWithValue(noticeRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(a11ySettingsProvider.notifier).setLocaleCode('en');
      await container
          .read(a11ySettingsProvider.notifier)
          .setLocationManualMode(true);
      await container.read(favoritesProvider.notifier).toggleLine('4');

      // Sign in demo user and issue an active ticket.
      final user = await container.read(authRepositoryProvider).signIn(
            email: 'demo@marprom.si',
            password: 'demo1234',
          );
      await ticketRepo.purchaseTicket(
        type: seedTicketTypes.first,
        userId: user.id,
      );

      await tester.pumpWidget(
        _wrapWithRouter(
          container: container,
          home: const Scaffold(body: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Where are we going today?'), findsOneWidget);
      expect(find.byType(StatusChip), findsWidgets);
      expect(
        find.byWidgetPredicate(
          (w) => w is OccupancyStrip || w is BusOccupancyCutaway,
        ),
        findsWidgets,
      );
      expect(find.textContaining('Last updated:'), findsOneWidget);
      expect(find.text('Active ticket'), findsOneWidget);
      expect(find.text('Service alert on your favourite line'), findsOneWidget);
      expect(find.byType(BigButton), findsWidgets);

      // Open Ask Marprom sheet and verify response renders.
      final askBtn = find.text('Ask Marprom').last;
      await tester.ensureVisible(askBtn);
      await tester.pumpAndSettle();
      await tester.tap(askBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Which ticket is best for today?').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Maribor Zone'), findsOneWidget);
    });
  });
}
