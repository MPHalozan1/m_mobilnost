//**********************************************
// Production Upgrade & Security Tests         *
//**********************************************

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/auth/email_validator.dart';
import 'package:m_mobilnost/core/config/download_links.dart';
import 'package:m_mobilnost/core/firebase/firestore_transit_service.dart';
import 'package:m_mobilnost/core/maps/google_map_models.dart';
import 'package:m_mobilnost/core/network/gemini_transit_service.dart';
import 'package:m_mobilnost/core/network/google_routes_service.dart';
import 'package:m_mobilnost/core/network/marprom_route_fusion.dart';
import 'package:m_mobilnost/core/widgets/bus_occupancy_cutaway.dart';
import 'package:m_mobilnost/data/mock/mock_auth_repository.dart';
import 'package:m_mobilnost/data/mock/mock_line_repository.dart';
import 'package:m_mobilnost/data/mock/mock_timetable_repository.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/bus_position.dart';
import 'package:m_mobilnost/data/models/occupancy.dart';
import 'package:m_mobilnost/data/models/trip_plan.dart';
import 'package:m_mobilnost/data/repositories/auth_repository.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/seed/seed_lines.dart';
import 'package:m_mobilnost/data/seed/seed_stops.dart';
import 'package:m_mobilnost/data/simulation/bus_simulator.dart';
import 'package:m_mobilnost/features/account/presentation/profile_settings_screen.dart';
import 'package:m_mobilnost/features/trip_planner/domain/route_planner.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Marprom Realistic Capacities & BusOccupancyCutaway', () {
    test('Every Marprom line & simulated bus enforces capacity <= 120 by class', () {
      for (final line in seedLines) {
        expect(
          line.maxCapacity,
          lessThanOrEqualTo(120),
          reason: '${line.code} exceeds 120 hard cap',
        );
        switch (line.defaultVehicleClass) {
          case MarpromVehicleClass.midibus9m:
            expect(line.maxCapacity, 64);
          case MarpromVehicleClass.solo12m:
            expect(line.maxCapacity, inInclusiveRange(85, 95));
          case MarpromVehicleClass.articulated18m:
            expect(line.maxCapacity, 120);
        }
      }

      final sim = BusSimulator(seed: 7, useSimulatedLive: true);
      addTearDown(sim.dispose);
      final buses = sim.snapshotAt(DateTime(2026, 11, 23, 8, 15));
      expect(buses, isNotEmpty);
      for (final bus in buses) {
        expect(bus.vehicleCapacity, lessThanOrEqualTo(120));
        expect(bus.passengerCount, lessThanOrEqualTo(bus.vehicleCapacity));
        expect(bus.seatedCount + bus.standingCount, bus.passengerCount);
      }
    });

    testWidgets('BusOccupancyCutaway renders cutaway and reveals breakdown on tap',
        (tester) async {
      final bus = BusPosition(
        vehicleId: 'MB-G1-18M',
        lineId: 'G1',
        lineCode: 'G1',
        directionId: 'G1_out',
        directionName: 'AP Maribor – Tezenska Dobrava',
        position: const LatLng(46.5547, 15.6459),
        progress: 0.4,
        speedKmh: 28,
        nextStopId: 'glavni_trg',
        nextStopName: 'Glavni trg',
        remainingStopsCount: 6,
        etaToNextStopSeconds: 90,
        delaySeconds: 0,
        occupancy: BusOccupancyLevel.medium,
        vehicleClass: MarpromVehicleClass.articulated18m,
        passengerCount: 74,
        vehicleCapacity: 120,
        seatedCount: 36,
        standingCount: 38,
        seatedCapacity: 40,
        standingCapacity: 80,
        isLowFloor: true,
        hasWheelchairRamp: true,
        hasWheelchairSpace: true,
        hasAudioAnnouncements: true,
        updatedAt: DateTime(2026, 11, 23, 8, 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BusOccupancyCutaway.fromBusPosition(bus),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('74 / 120'), findsOneWidget);
      await tester.tap(find.byType(BusOccupancyCutaway));
      await tester.pumpAndSettle();

      expect(find.textContaining('36/40'), findsOneWidget);
      expect(find.textContaining('38/80'), findsOneWidget);
    });
  });

  group('Wheelchair Accessibility Filter & Multi-Bus Transfers', () {
    test('4-flag accessibility distinguishes low-floor accessible lines vs older lines', () {
      expect(seedLinesById['G1']!.isWheelchairAccessible, isTrue);
      expect(seedLinesById['G6']!.isWheelchairAccessible, isTrue);
      expect(seedLinesById['P7']!.isWheelchairAccessible, isTrue);
      expect(seedLinesById['P18']!.isWheelchairAccessible, isFalse);
      expect(seedLinesById['P10']!.isWheelchairAccessible, isFalse);
    });

    test('RoutePlanner returns only all-accessible legs when accessibleOnly is true', () async {
      final planner = RoutePlanner(
        lineRepository: const MockLineRepository(),
        timetableRepository: MockTimetableRepository(),
        clock: () => DateTime(2026, 11, 23, 8, 15),
      );
      final accessibleRoutes = await planner.planTrip(
        origin: seedStopsById['glavna_postaja']!.position,
        destination: seedStopsById['vzpenjaca']!.position,
        accessibleOnly: true,
        sortMode: TripSortMode.fewestTransfers,
      );
      expect(accessibleRoutes, isNotEmpty);
      for (final opt in accessibleRoutes) {
        expect(opt.isAccessible, isTrue);
      }
    });

    test('GoogleRoutesService.parseTransitRoutesResponse parses multi-bus transfer summary', () {
      final encodedWalk1 = GoogleRoutesService.encodeGooglePolyline([
        const LatLng(46.557, 15.641),
        const LatLng(46.558, 15.645),
      ]);
      final encodedBus1 = GoogleRoutesService.encodeGooglePolyline([
        const LatLng(46.558, 15.645),
        const LatLng(46.554, 15.650),
      ]);
      final encodedWalkXfer = GoogleRoutesService.encodeGooglePolyline([
        const LatLng(46.554, 15.650),
        const LatLng(46.5542, 15.6504),
      ]);
      final encodedBus2 = GoogleRoutesService.encodeGooglePolyline([
        const LatLng(46.5542, 15.6504),
        const LatLng(46.535, 15.605),
      ]);

      final sampleJson = jsonEncode({
        'routes': [
          {
            'duration': '1620s',
            'distanceMeters': 6200,
            'legs': [
              {
                'steps': [
                  {
                    'travelMode': 'WALK',
                    'distanceMeters': 110,
                    'staticDuration': '90s',
                    'polyline': {'encodedPolyline': encodedWalk1},
                  },
                  {
                    'travelMode': 'TRANSIT',
                    'distanceMeters': 2400,
                    'staticDuration': '480s',
                    'polyline': {'encodedPolyline': encodedBus1},
                    'transitDetails': {
                      'stopDetails': {
                        'departureStop': {'name': 'Koroška vrata'},
                        'arrivalStop': {'name': 'Glavni trg'},
                        'departureTime': '2026-11-23T08:05:00Z',
                        'arrivalTime': '2026-11-23T08:13:00Z',
                      },
                      'transitLine': {'nameShort': 'G4'},
                      'headsign': 'AP Maribor',
                      'stopCount': 4,
                    },
                  },
                  {
                    'travelMode': 'WALK',
                    'distanceMeters': 65,
                    'staticDuration': '60s',
                    'polyline': {'encodedPolyline': encodedWalkXfer},
                  },
                  {
                    'travelMode': 'TRANSIT',
                    'distanceMeters': 3625,
                    'staticDuration': '720s',
                    'polyline': {'encodedPolyline': encodedBus2},
                    'transitDetails': {
                      'stopDetails': {
                        'departureStop': {'name': 'Glavni trg'},
                        'arrivalStop': {'name': 'Pohorska vzpenjača'},
                        'departureTime': '2026-11-23T08:19:00Z',
                        'arrivalTime': '2026-11-23T08:31:00Z',
                      },
                      'transitLine': {'nameShort': 'G6'},
                      'headsign': 'Pohorska vzpenjača',
                      'stopCount': 9,
                    },
                  },
                ],
              },
            ],
          },
        ],
      });

      final options = GoogleRoutesService.parseTransitRoutesResponse(
        sampleJson,
        marpromLinesByCode: {
          for (final l in seedLines) l.code: l,
        },
        marpromStops: seedStops,
        originLabel: 'Koroška vrata',
        destinationLabel: 'Pohorska vzpenjača',
      );

      expect(options, hasLength(1));
      final opt = options.single;
      expect(opt.isGoogleTransit, isTrue);
      expect(opt.transferCount, 1);
      expect(opt.transfers, hasLength(1));
      final xfer = opt.transfers.single;
      expect(xfer.fromLineCode, 'G4');
      expect(xfer.toLineCode, 'G6');
      expect(xfer.alightingStopName, contains('Glavni trg'));
      expect(xfer.walkMeters, closeTo(65, 1));
      expect(xfer.waitMinutes, 5);
    });
  });

  group('Strict Email Validation, Password Security & Spark APK Safety', () {
    test('EmailValidator accepts Gmail, Microsoft & school emails and blocks fake/phishing domains', () {
      expect(EmailValidator.validate('ana@gmail.com').isValid, isTrue);
      expect(EmailValidator.validate('marko@outlook.com').isValid, isTrue);
      expect(EmailValidator.validate('eva@hotmail.com').isValid, isTrue);
      expect(EmailValidator.validate('jan.novak@student.um.si').isValid, isTrue);
      expect(EmailValidator.validate('prof@arnes.si').isValid, isTrue);
      expect(EmailValidator.validate('demo@marprom.si').isValid, isTrue);

      // Block random gibberish, disposable, and typo/phishing domains
      expect(EmailValidator.validate('user@hjiusdhqi.com').isValid, isFalse);
      expect(EmailValidator.validate('temp@mailinator.com').isValid, isFalse);

      final typo = EmailValidator.validate('ana@gmial.com');
      expect(typo.isValid, isFalse);
      expect(typo.suggestedEmail, 'ana@gmail.com');
    });

    test('MockAuthRepository blocks invalid domain & never exposes password in UserProfile/Firestore', () async {
      final auth = MockAuthRepository(boxName: 'sec_${DateTime.now().microsecondsSinceEpoch}');
      addTearDown(auth.dispose);

      await expectLater(
        () => auth.signUp(
          email: 'spam@hjiusdhqi.com',
          password: 'StrongPassword!9',
          name: 'Test',
        ),
        throwsA(isA<AuthException>()),
      );

      final user = await auth.signUp(
        email: 'ana.novak@student.um.si',
        password: 'StrongPassword!9',
        name: 'Ana Novak',
      );
      final firestoreMap = user.toFirestore();
      expect(firestoreMap.containsKey('password'), isFalse);
      expect(firestoreMap.containsKey('passwordHash'), isFalse);
      expect(firestoreMap.containsKey('plainPassword'), isFalse);
      expect(firestoreMap.containsKey('salt'), isFalse);
      expect(jsonEncode(firestoreMap), isNot(contains('StrongPassword')));
    });

    test('APK URL points directly to GitHub v2.0 & SavedRouteRecord matches firestore.rules allowlist', () {
      expect(
        kMarpromAndroidApkUrl,
        'https://github.com/MPHalozan1/m_mobilnost/releases/download/v2.0/m-mobilnost.apk',
      );

      final now = DateTime(2026, 11, 24, 12, 0);
      final route = SavedRouteRecord(
        id: 'route_1',
        userId: 'uid_123',
        originName: 'Avtobusna postaja Maribor',
        destinationName: 'Pohorska vzpenjača',
        lineIds: const ['G6'],
        accessibleOnly: true,
        createdAt: now,
        updatedAt: now,
      );
      final payload = route.toFirestore();
      const allowedKeys = {
        'id',
        'userId',
        'originName',
        'destinationName',
        'originStopId',
        'destinationStopId',
        'originLat',
        'originLng',
        'destinationLat',
        'destinationLng',
        'lineIds',
        'label',
        'isFavorite',
        'accessibleOnly',
        'createdAt',
        'updatedAt',
      };
      expect(payload.keys.toSet().difference(allowedKeys), isEmpty);
    });
  });

  group('Gemini Failover, Google Routes Fixes, Always-Light Maps & Password Policy UI', () {
    test('GeminiTransitService cycles free-tier models across Maps Grounding & JSON passes', () async {
      expect(GeminiTransitService.freeTierModels, const [
        'gemini-3.8-flash',
        'gemini-3.6-flash',
        'gemini-3.5-flash-lite',
        'gemini-3.1-flash-lite',
        'gemini-3-flash-preview',
        'gemini-4-hydrogen',
      ]);

      final calledUrls = <String>[];
      var attemptCount = 0;
      final mockClient = MockClient((request) async {
        calledUrls.add(request.url.path);
        expect(request.headers['x-goog-api-key'], 'test-gemini-key');
        attemptCount++;
        // Fail first 7 attempts (all 6 models with Maps Grounding + first non-grounded)
        if (attemptCount <= 7) {
          return http.Response('rate limit / unsupported grounding', 429);
        }
        final reqJson = jsonDecode(request.body) as Map<String, dynamic>;
        expect(reqJson.containsKey('tools'), isFalse);
        expect(
          (reqJson['generationConfig'] as Map<String, dynamic>)['responseMimeType'],
          'application/json',
        );
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'originName': 'Moja lokacija',
                        'originLat': 46.5547,
                        'originLng': 15.6459,
                        'destinationName': 'Europark Maribor',
                        'destinationLat': 46.5535,
                        'destinationLng': 15.6533,
                        'wheelchairOnly': false,
                        'routingPreference': 'FEWER_TRANSFERS',
                        'shortReply': 'Najdena pot do Europarka.',
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiTransitService(
        geminiApiKey: 'test-gemini-key',
        client: mockClient,
      );
      final resolved = await service.resolveQuery(
        userQuery: 'Pelji me v Europark',
        userLatLng: const LatLng(46.5547, 15.6459),
        allowLocalFallback: false,
      );

      expect(calledUrls, hasLength(8));
      expect(calledUrls.first, contains('gemini-3.8-flash'));
      expect(resolved.resolvedByModel, 'gemini-3.6-flash');
      expect(resolved.destinationName, 'Europark Maribor');
      expect(resolved.destinationPosition.latitude, closeTo(46.5535, 0.001));
    });

    test('GeminiTransitService falls back to local Maribor matcher when all remote calls fail', () async {
      final mockClient = MockClient(
        (_) async => http.Response('service unavailable', 503),
      );
      final service = GeminiTransitService(
        geminiApiKey: 'test-gemini-key',
        client: mockClient,
      );
      final resolved = await service.resolveQuery(
        userQuery: 'Najbližji nizkopodni bus do UKC Maribor',
        userLatLng: const LatLng(46.557, 15.645),
      );
      expect(resolved.resolvedByModel, 'local-marprom-fallback');
      expect(resolved.wheelchairOnly, isTrue);
      expect(resolved.routingPreference, 'LESS_WALKING');
      expect(resolved.destinationName, contains('UKC Maribor'));
    });

    test('GoogleRoutesService omits departureTime on leave-now & handles Web Directions fallback JSON', () {
      final clock = DateTime.utc(2026, 11, 26, 10, 0, 0);
      final nowPayload = GoogleRoutesService.buildTransitPayload(
        origin: const LatLng(46.5547, 15.6459),
        destination: const LatLng(46.5535, 15.6533),
        departureTime: clock,
        clockNow: clock,
      );
      expect(nowPayload.containsKey('departureTime'), isFalse);
      expect(nowPayload.containsKey('routingPreference'), isFalse);

      final pastPayload = GoogleRoutesService.buildTransitPayload(
        origin: const LatLng(46.5547, 15.6459),
        destination: const LatLng(46.5535, 15.6533),
        departureTime: clock.subtract(const Duration(minutes: 5)),
        clockNow: clock,
      );
      expect(pastPayload['departureTime'], isNotNull);
      expect(
        DateTime.parse(pastPayload['departureTime'] as String).isAfter(clock),
        isTrue,
      );

      final webRoute = MarpromRouteFusion.enrichFromWebDirectionsJson({
        'overviewPath': [
          {'lat': 46.5575, 'lng': 15.6454},
          {'lat': 46.5555, 'lng': 15.6490},
          {'lat': 46.5535, 'lng': 15.6533},
        ],
        'legs': [
          {
            'distanceMeters': 1400,
            'durationSeconds': 540,
            'steps': [
              {
                'travelMode': 'WALKING',
                'distanceMeters': 18,
                'durationSeconds': 20,
                'startLocation': {'lat': 46.5575, 'lng': 15.6454},
                'endLocation': {'lat': 46.5576, 'lng': 15.6455},
                'path': <dynamic>[],
              },
              {
                'travelMode': 'TRANSIT',
                'distanceMeters': 1382,
                'durationSeconds': 480,
                'path': [
                  {'lat': 46.5576, 'lng': 15.6455},
                  {'lat': 46.5535, 'lng': 15.6533},
                ],
                'transit': {
                  'headsign': 'Pobrežje',
                  'numStops': 3,
                  'departureStop': {'name': 'Glavni trg'},
                  'arrivalStop': {'name': 'Europark'},
                  'line': {'shortName': '1', 'name': 'Linija G1'},
                },
              },
            ],
          },
        ],
      });

      expect(webRoute.option.legs, hasLength(2));
      expect(webRoute.option.legs.first.polyline, hasLength(2));
      expect(webRoute.option.legs.last.lineCode, 'G1');
      expect(webRoute.option.legs.last.vehicleCapacity, lessThanOrEqualTo(120));
    });

    test('Google Maps style preset remains locked to light in Dark & HighContrast modes', () async {
      SharedPreferences.setMockInitialValues({
        'a11y_theme_mode': 'dark',
        'a11y_map_style': 'dark',
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = A11ySettingsNotifier(prefs);
      expect(notifier.state.themeMode, AppThemeChoice.dark);
      expect(notifier.state.mapStylePreset, GoogleMapStylePreset.light);

      await notifier.setThemeMode(AppThemeChoice.highContrast);
      expect(notifier.state.mapStylePreset, GoogleMapStylePreset.light);

      await notifier.setMapStylePreset(GoogleMapStylePreset.dark);
      expect(notifier.state.mapStylePreset, GoogleMapStylePreset.light);
    });

    test('EmailValidator enforces Firebase 6-char + upper + lower + number password policy', () {
      expect(EmailValidator.evaluatePasswordPolicy('abc12').isCompliant, isFalse);
      expect(EmailValidator.evaluatePasswordPolicy('abcdef1').isCompliant, isFalse);
      expect(EmailValidator.evaluatePasswordPolicy('ABCDEF1').isCompliant, isFalse);
      expect(EmailValidator.evaluatePasswordPolicy('Abcdefg').isCompliant, isFalse);
      expect(EmailValidator.evaluatePasswordPolicy('Abcde1').isCompliant, isTrue);
    });

    testWidgets('ProfileSettingsScreen renders live 4-rule checklist and gates Sign-Up button',
        (tester) async {
      SharedPreferences.setMockInitialValues({'a11y_locale_code': 'en'});
      final prefs = await SharedPreferences.getInstance();
      final auth = MockAuthRepository(
        boxName: 'policy_ui_${DateTime.now().microsecondsSinceEpoch}',
      );
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(auth),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: ProfileSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Forgot Password & Support links visible in Sign-In view
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Help & Support'), findsOneWidget);

      // Switch to Sign-Up mode (`l10n.accountSignUp` = "Create account")
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.text('At least 6 characters'), findsOneWidget);
      expect(find.text('1 uppercase letter (A–Z)'), findsOneWidget);
      expect(find.text('1 lowercase letter (a–z)'), findsOneWidget);
      expect(find.text('1 number (0–9)'), findsOneWidget);

      final submitFinder = find.widgetWithText(FilledButton, 'Create account');
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

      // Type non-compliant password -> button stays disabled
      final pwdField = find.widgetWithText(TextFormField, 'Password');
      await tester.enterText(pwdField, 'abcde1');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

      // Add uppercase letter -> all 4 rules pass and submit enables
      await tester.enterText(pwdField, 'Abcde1');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);
    });
  });
}
