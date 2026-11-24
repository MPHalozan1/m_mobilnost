// Unit and widget tests for the 19-line Marprom network, 7-day schedules,
// Google Maps Embed / Routes API v2, exact passenger stats, and the 6-page Web Portal.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/app/app.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/config/download_links.dart';
import 'package:m_mobilnost/core/maps/full_screen_transit_map.dart';
import 'package:m_mobilnost/core/maps/google_maps_config.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/network/google_routes_service.dart';
import 'package:m_mobilnost/core/network/route_geometry_service.dart';
import 'package:m_mobilnost/core/widgets/bus_occupancy_cutaway.dart';
import 'package:m_mobilnost/core/widgets/occupancy_strip.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/seed/seed_lines.dart';
import 'package:m_mobilnost/data/seed/seed_timetables.dart';
import 'package:m_mobilnost/data/simulation/bus_simulator.dart';
import 'package:m_mobilnost/features/live_tracker/domain/fleet_statistics_provider.dart';
import 'package:m_mobilnost/features/map/data/location_service.dart';
import 'package:m_mobilnost/features/map/presentation/map_screen.dart';
import 'package:m_mobilnost/features/web_portal/presentation/marprom_web_scaffold.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_download_page.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_home_page.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_live_stats_page.dart';
import 'package:m_mobilnost/features/web_portal/presentation/widgets/live_bus_occupancy_card.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_route_planner_page.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_schedules_page.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_tickets_page.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingFakeGoogleRoutesService extends GoogleRoutesService {
  int callCount = 0;

  @override
  Future<GoogleRouteResult> computeRouteByCoordinates({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> intermediates = const [],
    String travelMode = 'DRIVE',
    bool avoidTolls = false,
    bool avoidHighways = false,
    bool includePolyline = true,
  }) async {
    callCount++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final pts = <LatLng>[
      origin,
      const LatLng(46.555, 15.650),
      const LatLng(46.540, 15.662),
      destination,
    ];
    return GoogleRouteResult(
      distanceMeters: 4200,
      durationSeconds: 610,
      rawDuration: '610s',
      polylinePoints: pts,
      isLiveApi: true,
      encodedPolyline: GoogleRoutesService.encodeGooglePolyline(pts),
    );
  }
}

Future<ProviderContainer> _createWebTestContainer() async {
  SharedPreferences.setMockInitialValues({'a11y_locale_code': 'sl'});
  final prefs = await SharedPreferences.getInstance();
  final sim = BusSimulator(seed: 42, useSimulatedLive: true);
  final morningBuses = sim.snapshotAt(DateTime(2026, 11, 23, 8, 10));
  sim.dispose();

  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      isOfflineProvider.overrideWithValue(false),
      liveBusesStreamProvider.overrideWith((ref) => Stream.value(morningBuses)),
    ],
  );
}

Widget _wrapWebPage(ProviderContainer container, Widget page) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: MMobilnostApp.appSupportedLocales,
      locale: const Locale('sl'),
      home: page,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('19 Official Marprom Lines (G1-G6 & P7-P19) & 7-Day Schedules', () {
    test('includes every required G1-G6 and P7-P19 code and 7-day schedules', () {
      const expectedCodes = [
        'G1', 'G2', 'G3', 'G4', 'G5', 'G6',
        'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13',
        'P14', 'P15', 'P16', 'P17', 'P18', 'P19',
      ];
      expect(seedLines.map((l) => l.code).toList(), expectedCodes);

      // Monday-Saturday operate all 19 lines; Sunday/Holidays suspend G5, P9, P13, P14, P17, P19.
      const noSundayLines = {'G5', 'P9', 'P13', 'P14', 'P17', 'P19'};
      for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
        final date = sampleDateForWeekday(weekday);
        final dayType = scheduleTypeForDate(date);
        expect(date.weekday, weekday);
        for (final line in seedLines) {
          final trips = generateTripsForDirection(
            line: line,
            direction: line.directions.first,
            date: date,
          );
          if (dayType == DayScheduleType.sundayHoliday &&
              noSundayLines.contains(line.id)) {
            expect(doesLineOperateOn(line.id, dayType), isFalse);
            expect(trips, isEmpty, reason: '${line.code} should not run on Sunday');
          } else {
            expect(doesLineOperateOn(line.id, dayType), isTrue);
            expect(trips, isNotEmpty, reason: '${line.code} day $weekday empty');
          }
        }
      }
    });

    test('BusSimulator & FleetStatistics compute exact passenger counts and capacities', () {
      final sim = BusSimulator(seed: 42, useSimulatedLive: true);
      addTearDown(sim.dispose);

      final morningBuses = sim.snapshotAt(DateTime(2026, 11, 23, 8, 10));
      expect(morningBuses, isNotEmpty);

      final stats = computeFleetStatistics(
        morningBuses,
        now: DateTime(2026, 11, 23, 8, 10),
      );
      expect(stats.activeBusCount, morningBuses.length);
      expect(stats.totalPassengers, greaterThan(0));
      expect(stats.totalCapacity, greaterThanOrEqualTo(stats.totalPassengers));
      expect(stats.electricBusCount, greaterThan(0));
      expect(stats.lineStats.length, 19);
      expect(stats.hourlyRidership.length, 19);
    });
  });

  group('Google Maps Vector Config & Routes API v2', () {
    test('GoogleMapsConfig configures Map ID & APK release URL points to GitHub v2.0', () {
      expect(GoogleMapsConfig.webApiKey, isNotEmpty);
      expect(GoogleMapsConfig.vectorMapId, isNotEmpty);
      expect(
        marpromAndroidApkUri.toString(),
        'https://github.com/MPHalozan1/m_mobilnost/releases/download/v2.0/m-mobilnost.apk',
      );
    });

    test('parseComputeRoutesResponse parses exact sample JSON and decodes polylines', () {
      const sampleJson = '''
      {
        "routes": [
          {
            "distanceMeters": 10491,
            "duration": "1094s"
          }
        ]
      }
      ''';
      final parsed = GoogleRoutesService.parseComputeRoutesResponse(sampleJson);
      expect(parsed, isNotNull);
      expect(parsed!.distanceMeters, 10491);
      expect(parsed.durationSeconds, 1094);
      expect(parsed.rawDuration, '1094s');
      expect(parsed.formattedDistanceKm, '10.5 km');
      expect(parsed.formattedDurationMinutes, '18 min');
      expect(parsed.isLiveApi, isTrue);

      final decoded = GoogleRoutesService.decodeGooglePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(decoded.length, 3);
      expect(decoded.first.latitude, closeTo(38.5, 0.01));
      expect(decoded.first.longitude, closeTo(-120.2, 0.01));
      final reEncoded = GoogleRoutesService.encodeGooglePolyline(decoded);
      expect(GoogleRoutesService.decodeGooglePolyline(reEncoded).length, 3);

      // BusSimulator accepts road geometries pushed from Google Routes API.
      final sim = BusSimulator(seed: 42, useSimulatedLive: true);
      addTearDown(sim.dispose);
      sim.setGoogleRouteGeometries({
        'G1|G1_out': [
          const LatLng(46.5587, 15.6557),
          const LatLng(46.5450, 15.6620),
          const LatLng(46.5198, 15.6835),
        ],
      });
      expect(sim.snapshotAt(DateTime(2026, 11, 23, 8, 10)), isNotEmpty);
    });

    test('buildOfflineFallback estimates road distance from Maribor coordinates', () {
      final fallback = GoogleRoutesService.buildOfflineFallback(
        origin: const LatLng(46.5594, 15.6561),
        destination: const LatLng(46.5343, 15.6042),
      );
      expect(fallback.isLiveApi, isFalse);
      expect(fallback.distanceMeters, greaterThan(4000));
      expect(fallback.durationSeconds, greaterThan(300));
    });

    test('GoogleLineRoutesNotifier serves bundled road geometry without network and slices segments cleanly', () async {
      // Adapted: line shapes now come from the bundled stop-to-stop road
      // geometry instead of a Google Routes request with all stops as
      // waypoints, so no routes call may happen.
      final fakeService = _CountingFakeGoogleRoutesService();
      final container = ProviderContainer(
        overrides: [googleRoutesServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(googleLineRoutesProvider.notifier);

      final line = seedLines.first;
      final dir = line.directions.first;
      final results = await Future.wait([
        notifier.ensureLineDirectionLoaded(line, dir, forceInTests: true),
        notifier.ensureLineDirectionLoaded(line, dir, forceInTests: true),
      ]);

      expect(fakeService.callCount, 0);
      expect(results[0], isNotNull);
      expect(results[1], isNotNull);
      expect(results[0]!.isLiveApi, isFalse);
      expect(results[0]!.polylinePoints, dir.routePolyline);
      expect(results[0]!.distanceMeters, greaterThan(0));
      expect(results[0]!.durationSeconds, greaterThan(0));
      expect(results[0]!.polylinePoints.length, results[1]!.polylinePoints.length);

      const fullRoad = [
        LatLng(46.560, 15.640),
        LatLng(46.555, 15.645),
        LatLng(46.550, 15.650),
        LatLng(46.545, 15.655),
        LatLng(46.540, 15.660),
      ];
      final forwardSlice = slicePolylineBetweenPoints(
        fullRoad,
        const LatLng(46.555, 15.645),
        const LatLng(46.545, 15.655),
      );
      expect(forwardSlice.length, 3);
      expect(forwardSlice.first.latitude, closeTo(46.555, 1e-4));
      expect(forwardSlice.last.latitude, closeTo(46.545, 1e-4));

      final reverseSlice = slicePolylineBetweenPoints(
        fullRoad,
        const LatLng(46.545, 15.655),
        const LatLng(46.555, 15.645),
      );
      expect(reverseSlice.first.latitude, closeTo(46.545, 1e-4));
      expect(reverseSlice.last.latitude, closeTo(46.555, 1e-4));
    });
  });

  group('Marprom 6-Page Web Portal Widgets', () {
    testWidgets('WebHomePage & MarpromWebScaffold render in Slovenian and switch languages', (tester) async {
      tester.view.physicalSize = const Size(1360, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = await _createWebTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWebPage(
          container,
          const MarpromWebScaffold(
            currentPath: '/',
            child: WebHomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MARPROM'), findsWidgets);
      expect(find.text('Google prijava'), findsOneWidget);
      expect(find.textContaining('Povezujemo Maribor'), findsOneWidget);
      expect(find.text('G1'), findsWidgets);
      expect(find.text('P19'), findsWidgets);

      // Switch to English via top corporate navbar pill.
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(find.text('Google Sign-In'), findsOneWidget);
      expect(find.textContaining('Connecting Maribor'), findsOneWidget);
    });

    testWidgets('WebSchedulesPage, WebRoutePlannerPage, WebLiveStatsPage, WebTicketsPage, WebDownloadPage render cleanly', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = await _createWebTestContainer();
      addTearDown(container.dispose);

      // 1. Schedules page with 7-day-of-week selector
      await tester.pumpWidget(
        _wrapWebPage(
          container,
          const Scaffold(body: SingleChildScrollView(child: WebSchedulesPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ponedeljek'), findsOneWidget);
      expect(find.text('Petek'), findsOneWidget);
      expect(find.text('Sobota'), findsOneWidget);
      expect(find.text('Nedelja / Praznik'), findsOneWidget);

      // 2. Route Planner page with Routes API card + Vector 2D/3D Map
      await tester.pumpWidget(
        _wrapWebPage(
          container,
          const Scaffold(body: SingleChildScrollView(child: WebRoutePlannerPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Google Routes API v2 (computeRoutes)'), findsOneWidget);
      expect(find.byKey(const Key('google_map_3d_stub_preview')), findsOneWidget);

      // 3. Live Stats page with 3D Map & exact passenger count table
      await tester.pumpWidget(
        _wrapWebPage(
          container,
          const Scaffold(body: SingleChildScrollView(child: WebLiveStatsPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Skupaj potnikov na avtobusih'), findsOneWidget);
      expect(find.byKey(const Key('google_map_3d_stub_preview')), findsOneWidget);

      // 4. Tickets page
      await tester.pumpWidget(
        _wrapWebPage(
          container,
          const Scaffold(body: SingleChildScrollView(child: WebTicketsPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vozovnice in cenik mestnega prometa Marprom'), findsOneWidget);

      // 5. Download page with Android APK + iOS QR codes (web preview) & native hide
      await tester.pumpWidget(
        _wrapWebPage(
          container,
          const Scaffold(
            body: SingleChildScrollView(
              child: WebDownloadPage(forceWebPreview: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Prenesi m-mobilnost.apk'), findsOneWidget);
      expect(find.byType(QrImageView), findsNWidgets(2));

      await tester.pumpWidget(
        _wrapWebPage(
          container,
          const Scaffold(body: SingleChildScrollView(child: WebDownloadPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Prenesi m-mobilnost.apk'), findsNothing);
    });

    for (final width in [1280.0, 400.0]) {
      testWidgets('WebLiveStatsPage shows per-bus occupancy cards and seat detail on select (${width.toInt()} px)', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = await _createWebTestContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _wrapWebPage(
            container,
            const Scaffold(body: SingleChildScrollView(child: WebLiveStatsPage())),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Truthful road-geometry source line instead of "Google Routes API v2".
        expect(find.textContaining('OpenStreetMap, avtobusno usmerjanje'), findsOneWidget);
        expect(find.textContaining('živih cestnih tras'), findsNothing);

        final panel = find.byKey(const Key('live_occupancy_panel'));
        expect(panel, findsOneWidget);
        final cards = find.descendant(of: panel, matching: find.byType(LiveBusOccupancyCard));
        expect(cards, findsWidgets);
        expect(find.descendant(of: panel, matching: find.byType(OccupancyStrip)), findsWidgets);
        expect(find.descendant(of: panel, matching: find.text('simulirano')), findsWidgets);

        // Fullest bus first; its card carries passengers / capacity (xx %).
        final first = tester.widget<LiveBusOccupancyCard>(cards.first);
        expect(
          find.descendant(of: panel, matching: find.textContaining('${first.bus.passengerCount} / ${first.bus.vehicleCapacity} potnikov (${first.bus.loadPercent} %)')),
          findsWidgets,
        );
        expect(find.byType(BusOccupancyCutaway), findsNothing);

        await tester.ensureVisible(cards.first);
        await tester.tap(cards.first);
        await tester.pumpAndSettle();
        expect(find.byType(BusOccupancyCutaway), findsOneWidget);
        expect(tester.widget<LiveBusOccupancyCard>(cards.first).selected, isTrue);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Mobile MapScreen expands into FullScreenTransitMapPage and closes cleanly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({'a11y_locale_code': 'sl'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isOfflineProvider.overrideWithValue(false),
          liveBusesStreamProvider.overrideWith((ref) => Stream.value(const [])),
          locationServiceProvider.overrideWithValue(
            LocationService(gpsProbe: () async => null),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWebPage(
          container,
          const Scaffold(body: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final toggleBtn = find.byKey(const Key('toggle_fullscreen_map_btn'));
      expect(toggleBtn, findsOneWidget);
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenTransitMapPage), findsOneWidget);
      final exitBtn = find.byKey(const Key('exit_fullscreen_map_btn'));
      expect(exitBtn, findsOneWidget);

      await tester.tap(exitBtn);
      await tester.pumpAndSettle();
      expect(find.byType(FullScreenTransitMapPage), findsNothing);
    });
  });
}
