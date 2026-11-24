// Widget and unit smoke tests verifying app shell, routing, l10n, themes, and widgets.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:m_mobilnost/app/app.dart';
import 'package:m_mobilnost/app/router.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/accessibility/favorites_provider.dart';
import 'package:m_mobilnost/core/accessibility/haptic_cues.dart';
import 'package:m_mobilnost/core/layout/breakpoints.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/network/data_freshness.dart';
import 'package:m_mobilnost/core/utils/distance.dart';
import 'package:m_mobilnost/core/utils/geo.dart';
import 'package:m_mobilnost/core/utils/time_format.dart';
import 'package:m_mobilnost/core/widgets/big_button.dart';
import 'package:m_mobilnost/core/widgets/occupancy_strip.dart';
import 'package:m_mobilnost/core/widgets/simulated_data_badge.dart';
import 'package:m_mobilnost/core/widgets/state_views.dart';
import 'package:m_mobilnost/core/widgets/status_chip.dart';
import 'package:m_mobilnost/features/onboarding/presentation/onboarding_screen.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('First-launch redirects / to /onboarding when onboardingDone is false',
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
      UncontrolledProviderScope(
        container: container,
        child: const MMobilnostApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Dobrodošli v M Mobilnost 2.0'), findsWidgets);
  });

  testWidgets('MMobilnostApp builds cleanly in Slovenian and switches locales',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'a11y_onboarding_done': true,
      'a11y_location_manual': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isOfflineProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MMobilnostApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('M Mobilnost'), findsOneWidget);
    expect(find.text('Domov'), findsWidgets);
    expect(find.text('Zemljevid'), findsWidgets);
    expect(find.text('Načrtuj'), findsWidgets);
    expect(find.text('Vozovnice'), findsWidgets);

    await container.read(a11ySettingsProvider.notifier).setLocaleCode('sr_Latn');
    await tester.pumpAndSettle();
    expect(find.text('Početna'), findsWidgets);
    expect(find.text('Planiraj'), findsWidgets);

    await container.read(a11ySettingsProvider.notifier).setLocaleCode('en');
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Tickets'), findsWidgets);
  });

  testWidgets('Extra-large text and High Contrast theme apply cleanly',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'a11y_onboarding_done': true,
      'a11y_location_manual': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isOfflineProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MMobilnostApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Offline banner renders when offline.
    expect(find.text('Delovanje brez povezave'), findsOneWidget);

    await container
        .read(a11ySettingsProvider.notifier)
        .setThemeMode(AppThemeChoice.highContrast);
    await container
        .read(a11ySettingsProvider.notifier)
        .setExtraLargeText(true);
    await tester.pumpAndSettle();

    final scaffoldContext = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.textScalerOf(scaffoldContext).scale(1.0), 2.0);
  });

  testWidgets('Core widgets render with >= 56dp BigButton and state views',
      (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: MMobilnostApp.appSupportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Column(
              children: [
                BigButton(
                  icon: Icons.directions_bus,
                  label: 'Board',
                  onPressed: () {
                    tapped = true;
                  },
                ),
                const StatusChip(type: TransitStatusType.early),
                const OccupancyStrip(level: BusOccupancyLevel.medium),
                Expanded(
                  child: ErrorStateView(onRetry: () {}),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttonSize = tester.getSize(find.byType(BigButton).first);
    expect(buttonSize.width, greaterThanOrEqualTo(56));
    expect(buttonSize.height, greaterThanOrEqualTo(56));

    await tester.tap(find.byType(BigButton).first);
    expect(tapped, isTrue);
    expect(find.text('Early'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('AppBar targets are >= 56dp and SimulatedDataBadge falls back',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'a11y_onboarding_done': true,
      'a11y_location_manual': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isOfflineProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MMobilnostApp(),
      ),
    );
    await tester.pumpAndSettle();

    final settingsIconBtn = find.byIcon(Icons.settings_outlined);
    final btnBox = tester.getSize(
      find.ancestor(of: settingsIconBtn, matching: find.byType(IconButton)),
    );
    expect(btnBox.width, greaterThanOrEqualTo(56));
    expect(btnBox.height, greaterThanOrEqualTo(56));

    await container
        .read(a11ySettingsProvider.notifier)
        .setUseSimulatedLive(false);
    await container.read(a11ySettingsProvider.notifier).setLocaleCode('en');
    await tester.pumpAndSettle();

    expect(find.byType(SimulatedDataBadge), findsWidgets);
    expect(
      find.text('Live data not available, showing timetable'),
      findsWidgets,
    );

    final ctx = tester.element(find.byType(SimulatedDataBadge).first);
    final l10n = AppLocalizations.of(ctx)!;
    final freshness = DataFreshness(
      kind: DataSourceKind.cached,
      updatedAt: DateTime(2026, 11, 23, 8, 0),
    );
    expect(
      freshness.formattedAge(l10n, DateTime(2026, 11, 23, 10, 0)),
      'Updated 2 h ago',
    );
  });

  testWidgets('GoRouter renders wired feature routes cleanly',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'a11y_onboarding_done': true,
      'a11y_location_manual': true,
      'a11y_locale_code': 'en',
    });
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isOfflineProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MMobilnostApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(routerProvider);
    router.go('/lines');
    await tester.pumpAndSettle();
    expect(find.text('Lines & timetables'), findsOneWidget);

    router.go('/stops/glavni_trg');
    await tester.pumpAndSettle();
    expect(find.text('Glavni trg'), findsWidgets);

    router.go('/guide');
    await tester.pumpAndSettle();
    expect(find.text('New to the bus'), findsOneWidget);

    router.go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  test('Breakpoints, geo interpolation, and formatters behave accurately',
      () async {
    expect(LayoutBreakpoints.fromWidth(390), ScreenLayoutSize.compact);
    expect(LayoutBreakpoints.fromWidth(768), ScreenLayoutSize.medium);
    expect(LayoutBreakpoints.fromWidth(1280), ScreenLayoutSize.expanded);

    const a = LatLng(46.5547, 15.6459);
    const b = LatLng(46.5647, 15.6459);
    final dist = GeoUtils.haversineMeters(a, b);
    expect(dist, greaterThan(1000));
    expect(dist, lessThan(1200));

    final mid = GeoUtils.interpolatePolyline([a, b], 0.5);
    expect(mid.latitude, closeTo(46.5597, 0.0005));
    expect(mid.longitude, closeTo(15.6459, 0.0005));

    expect(DistanceUtils.estimateWalkMinutes(150), 2);
    expect(
      TimeFormatUtils.formatTime24(DateTime(2026, 11, 23, 9, 5)),
      '09:05',
    );
    await HapticCues.trigger(HapticCueType.tap, enabled: false);
  });

  test('FavoritesNotifier persists stops, lines, and manual stop cleanly',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(favoritesProvider).manualStopId,
      FavoritesState.defaultManualStopId,
    );

    final notifier = container.read(favoritesProvider.notifier);
    await notifier.toggleStop('glavni_trg');
    await notifier.toggleLine('6');
    await notifier.setManualStop('europark');

    expect(container.read(favoritesProvider).isStopFavorite('glavni_trg'), isTrue);
    expect(container.read(favoritesProvider).isLineFavorite('6'), isTrue);
    expect(container.read(favoritesProvider).manualStopId, 'europark');

    // Reload from persisted SharedPreferences in a new container.
    final reloaded = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(reloaded.dispose);
    expect(reloaded.read(favoritesProvider).isStopFavorite('glavni_trg'), isTrue);
    expect(reloaded.read(favoritesProvider).isLineFavorite('6'), isTrue);
    expect(reloaded.read(favoritesProvider).manualStopId, 'europark');

    await reloaded.read(favoritesProvider.notifier).clearAll();
    expect(reloaded.read(favoritesProvider).stopIds, isEmpty);
    expect(reloaded.read(favoritesProvider).lineIds, isEmpty);
    expect(
      reloaded.read(favoritesProvider).manualStopId,
      FavoritesState.defaultManualStopId,
    );
  });
}
