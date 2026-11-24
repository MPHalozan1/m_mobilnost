// Widget tests covering Lines, LineDetail, StopDetail, Map, and LiveTracker screens.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/app/app.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/accessibility/favorites_provider.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/network/map_tile_provider.dart';
import 'package:m_mobilnost/core/widgets/occupancy_strip.dart';
import 'package:m_mobilnost/core/widgets/simulated_data_badge.dart';
import 'package:m_mobilnost/data/models/bus_position.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/features/lines/presentation/line_detail_screen.dart';
import 'package:m_mobilnost/features/lines/presentation/lines_screen.dart';
import 'package:m_mobilnost/features/live_tracker/presentation/live_tracker_screen.dart';
import 'package:m_mobilnost/features/map/data/location_service.dart';
import 'package:m_mobilnost/features/map/presentation/map_screen.dart';
import 'package:m_mobilnost/features/timetable/presentation/stop_detail_screen.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Uint8List _transparent1x1Png = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _MemoryTestTileProvider extends TileProvider {
  _MemoryTestTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparent1x1Png);
  }
}

Future<ProviderContainer> _createTestContainer({
  bool useSimulatedLive = true,
  bool extraLargeText = false,
  bool locationManualMode = false,
  Future<LatLng?> Function()? gpsProbe,
  List<BusPosition>? liveBusesOverride,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      isOfflineProvider.overrideWithValue(false),
      mapTileProviderProvider.overrideWithValue(_MemoryTestTileProvider()),
      locationServiceProvider.overrideWithValue(
        LocationService(gpsProbe: gpsProbe ?? () async => null),
      ),
      if (liveBusesOverride != null)
        liveBusesStreamProvider.overrideWith(
          (ref) => Stream.value(liveBusesOverride),
        ),
    ],
  );
  final settingsNotifier = container.read(a11ySettingsProvider.notifier);
  await settingsNotifier.setLocaleCode('en');
  await settingsNotifier.setUseSimulatedLive(useSimulatedLive);
  await settingsNotifier.setExtraLargeText(extraLargeText);
  await settingsNotifier.setLocationManualMode(locationManualMode);
  await settingsNotifier.setHapticAlertsEnabled(false);
  return container;
}

Widget _wrapWithRouter({
  required ProviderContainer container,
  required Widget initialScreen,
  String initialPath = '/',
  bool extraLargeText = false,
}) {
  final router = GoRouter(
    initialLocation: initialPath,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => initialScreen,
      ),
      GoRoute(
        path: '/lines',
        builder: (_, _) => const LinesScreen(),
      ),
      GoRoute(
        path: '/lines/:lineId',
        builder: (_, state) => LineDetailScreen(
          lineId: state.pathParameters['lineId']!,
        ),
      ),
      GoRoute(
        path: '/stops/:stopId',
        builder: (_, state) => StopDetailScreen(
          stopId: state.pathParameters['stopId']!,
        ),
      ),
      GoRoute(
        path: '/map',
        builder: (_, state) => Scaffold(
          body: MapScreen(
            initialLineId: state.uri.queryParameters['lineId'],
            initialStopId: state.uri.queryParameters['stopId'],
          ),
        ),
      ),
      GoRoute(
        path: '/tracker',
        builder: (_, state) => LiveTrackerScreen(
          initialLineId: state.uri.queryParameters['lineId'],
          initialVehicleId: state.uri.queryParameters['vehicleId'],
          initialStopId: state.uri.queryParameters['stopId'],
        ),
      ),
      GoRoute(
        path: '/plan',
        builder: (_, state) => Scaffold(
          body: Text(
            'PLAN_ROUTE:${state.uri.queryParameters['fromStopId'] ?? ''}',
          ),
        ),
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: MMobilnostApp.appSupportedLocales,
      locale: const Locale('en'),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(extraLargeText ? 2.0 : 1.0),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LinesScreen searches lines and toggles favorites',
      (WidgetTester tester) async {
    final container = await _createTestContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrapWithRouter(
        container: container,
        initialScreen: const LinesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Line G1'), findsOneWidget);
    expect(find.text('Line G6'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'vzpenjača');
    await tester.pumpAndSettle();
    expect(find.text('Line G6'), findsOneWidget);
    expect(find.text('Line G1'), findsNothing);

    await tester.tap(find.byIcon(Icons.star_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(container.read(favoritesProvider).isLineFavorite('G6'), isTrue);
  });

  testWidgets(
      'LineDetailScreen switches directions, toggles map/list, shows occupancy and fallback',
      (WidgetTester tester) async {
    final container = await _createTestContainer(useSimulatedLive: false);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrapWithRouter(
        container: container,
        initialScreen: const LineDetailScreen(lineId: 'G6'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Line G6'), findsWidgets);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(OccupancyStrip), findsWidgets);
    expect(find.byType(SimulatedDataBadge), findsOneWidget);
    expect(
      find.text('Live data not available, showing timetable'),
      findsWidgets,
    );

    // Switch direction using Reverse direction button.
    await tester.tap(find.text('Reverse direction'));
    await tester.pumpAndSettle();
    expect(find.text('Direction: Vzpenjača – UKC – AP Maribor'), findsWidgets);

    // Toggle map to list view.
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsNothing);

    // Tap Follow a bus live navigates to /tracker?lineId=6.
    await tester.ensureVisible(find.text('Follow a bus live'));
    await tester.tap(find.text('Follow a bus live'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveTrackerScreen), findsOneWidget);
  });

  testWidgets(
      'StopDetailScreen survives 200% text scale, switches days, favorites, and plans trip',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = await _createTestContainer(extraLargeText: true);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrapWithRouter(
        container: container,
        extraLargeText: true,
        initialScreen: const StopDetailScreen(stopId: 'glavni_trg'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Glavni trg'), findsWidgets);
    expect(find.text('Shelter'), findsOneWidget);
    expect(find.text('Step-free access'), findsOneWidget);

    // Switch day schedule selector to Sunday / holiday.
    await tester.ensureVisible(find.text('Sunday / holiday'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sunday / holiday'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Add to favourites.
    await tester.ensureVisible(find.text('Add to favourites'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to favourites'));
    await tester.pumpAndSettle();
    expect(
      container.read(favoritesProvider).isStopFavorite('glavni_trg'),
      isTrue,
    );

    // Plan a trip from here navigates to /plan?fromStopId=glavni_trg.
    await tester.ensureVisible(find.text('Plan a trip from here'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan a trip from here'));
    await tester.pumpAndSettle();
    expect(find.text('PLAN_ROUTE:glavni_trg'), findsOneWidget);
  });

  testWidgets(
      'MapScreen handles denied location fallback, list toggle, stop sheet, and expanded split',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final mockBuses = [
      BusPosition(
        vehicleId: 'MB-G6-0800',
        lineId: 'G6',
        lineCode: 'G6',
        directionId: 'G6_out',
        directionName: 'Vzpenjača – AP Maribor – Melje',
        position: const LatLng(46.5457, 15.6448),
        progress: 0.45,
        speedKmh: 24.0,
        nextStopId: 'tabor',
        nextStopName: 'Tabor',
        remainingStopsCount: 6,
        etaToNextStopSeconds: 120,
        delaySeconds: 0,
        occupancy: BusOccupancyLevel.medium,
        updatedAt: now,
      ),
    ];

    final container = await _createTestContainer(
      liveBusesOverride: mockBuses,
    );
    addTearDown(container.dispose);

    // Test Expanded (> 1024px) two-pane split.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _wrapWithRouter(
        container: container,
        initialScreen: const Scaffold(body: MapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Location access unavailable'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Glavni trg'), findsWidgets);

    // Select a different manual Maribor stop cleanly without blocking usage.
    await tester.tap(find.text('Choose starting stop: Glavni trg'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Europark'),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(favoritesProvider).manualStopId, 'europark');

    // Tap a live bus in list pane to highlight route polyline & stop arrival times.
    await tester.dragUntilVisible(
      find.text('Next stop: Tabor'),
      find.byType(ListView).first,
      const Offset(0, -150),
    );
    await tester.tap(find.text('Next stop: Tabor'));
    await tester.pumpAndSettle();
    expect(find.text('Showing route for line G6'), findsOneWidget);

    // Toggle to full List view (hides FlutterMap).
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsNothing);

    // Scroll to a stop and tap to open modal bottom sheet with next departures.
    await tester.dragUntilVisible(
      find.text('Europark'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await tester.ensureVisible(find.text('Europark').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Europark').first);
    await tester.pumpAndSettle();
    expect(find.text('View stop departures'), findsOneWidget);
  });

  testWidgets(
      'LiveTrackerScreen renders early and late review advice cards, Notify me alert, and Next step card',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final earlyBus = BusPosition(
      vehicleId: 'MB-G6-EARLY',
      lineId: 'G6',
      lineCode: 'G6',
      directionId: 'G6_out',
      directionName: 'Vzpenjača – AP Maribor – Melje',
      position: const LatLng(46.5457, 15.6448),
      progress: 0.4,
      speedKmh: 28.0,
      nextStopId: 'tabor',
      nextStopName: 'Tabor',
      remainingStopsCount: 5,
      etaToNextStopSeconds: 120,
      delaySeconds: -120,
      occupancy: BusOccupancyLevel.low,
      updatedAt: now,
    );

    final earlyContainer = await _createTestContainer(
      liveBusesOverride: [earlyBus],
    );
    addTearDown(earlyContainer.dispose);

    await tester.pumpWidget(
      _wrapWithRouter(
        container: earlyContainer,
        initialScreen: const LiveTrackerScreen(initialLineId: 'G6'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next step on your trip'), findsOneWidget);
    expect(find.text('Get off at the next stop: Tabor'), findsOneWidget);
    expect(find.text('Bus is running early'), findsOneWidget);
    expect(
      find.text(
        'This bus is 2 min early. It may leave before the timetable time. Be at the stop 4 min sooner.',
      ),
      findsOneWidget,
    );

    // Trigger Notify me 5 min before arrival -> fires visual alert banner immediately since ETA is 2 min.
    await tester.ensureVisible(find.text('Notify me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notify me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notify 5 min before arrival'));
    await tester.pumpAndSettle();
    expect(find.text('Bus G6 is 2 min away from Tabor!'), findsOneWidget);

    // Verify late advice card cleanly on a delayed bus.
    final lateBus = BusPosition(
      vehicleId: 'MB-G1-LATE',
      lineId: 'G1',
      lineCode: 'G1',
      directionId: 'G1_out',
      directionName: 'Tezno Ind. – AP Maribor',
      position: const LatLng(46.5576, 15.6455),
      progress: 0.5,
      speedKmh: 18.0,
      nextStopId: 'glavni_trg',
      nextStopName: 'Glavni trg',
      remainingStopsCount: 6,
      etaToNextStopSeconds: 300,
      delaySeconds: 300,
      occupancy: BusOccupancyLevel.high,
      updatedAt: now,
    );

    final lateContainer = await _createTestContainer(
      liveBusesOverride: [lateBus],
    );
    addTearDown(lateContainer.dispose);

    await tester.pumpWidget(
      _wrapWithRouter(
        container: lateContainer,
        initialScreen: const LiveTrackerScreen(initialLineId: 'G1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bus is delayed'), findsOneWidget);
    expect(find.textContaining('This bus is 5 min late.'), findsOneWidget);
  });
}
