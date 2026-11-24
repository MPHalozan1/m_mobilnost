// Unit and widget tests for the 19-line Marprom network, 7-day schedules,
// Google Maps Embed / Routes API v2, exact passenger stats, and the 6-page Web Portal.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/app/app.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/maps/google_maps_config.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/network/google_routes_service.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/seed/seed_lines.dart';
import 'package:m_mobilnost/data/seed/seed_timetables.dart';
import 'package:m_mobilnost/data/simulation/bus_simulator.dart';
import 'package:m_mobilnost/features/live_tracker/domain/fleet_statistics_provider.dart';
import 'package:m_mobilnost/features/web_portal/presentation/marprom_web_scaffold.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_download_page.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_home_page.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_live_stats_page.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_route_planner_page.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_schedules_page.dart';
import 'package:m_mobilnost/features/web_portal/presentation/pages/web_tickets_page.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('Google Maps Embed & Routes API v2', () {
    test('buildDirectionsEmbedUri encodes origin, destination, mode, and avoid flags', () {
      final uri = GoogleMapsConfig.buildDirectionsEmbedUri(
        origin: 'Oslo Norway',
        destination: 'Telemark Norway',
        mode: 'driving',
        avoidTolls: true,
        avoidHighways: true,
      );
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/embed/v1/directions');
      expect(uri.queryParameters['key'], GoogleMapsConfig.webApiKey);
      expect(uri.queryParameters['origin'], 'Oslo Norway');
      expect(uri.queryParameters['destination'], 'Telemark Norway');
      expect(uri.queryParameters['avoid'], 'tolls|highways');
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

      // 2. Route Planner page with Routes API card + Directions Embed card
      await tester.pumpWidget(
        _wrapWebPage(
          container,
          const Scaffold(body: SingleChildScrollView(child: WebRoutePlannerPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Google Routes API v2 (computeRoutes)'), findsOneWidget);
      expect(find.byKey(const Key('google_directions_embed_card')), findsOneWidget);

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

      // 5. Download page with Android APK + iOS QR codes
      await tester.pumpWidget(
        _wrapWebPage(
          container,
          const Scaffold(body: SingleChildScrollView(child: WebDownloadPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Prenesi m-mobilnost.apk'), findsOneWidget);
      expect(find.byType(QrImageView), findsNWidgets(2));
    });
  });
}
