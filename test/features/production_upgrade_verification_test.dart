//**********************************************
// Production Upgrade & Security Tests         *
//**********************************************

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/auth/email_validator.dart';
import 'package:m_mobilnost/core/config/download_links.dart';
import 'package:m_mobilnost/core/firebase/firestore_transit_service.dart';
import 'package:m_mobilnost/core/network/google_routes_service.dart';
import 'package:m_mobilnost/core/widgets/bus_occupancy_cutaway.dart';
import 'package:m_mobilnost/data/mock/mock_auth_repository.dart';
import 'package:m_mobilnost/data/mock/mock_line_repository.dart';
import 'package:m_mobilnost/data/mock/mock_timetable_repository.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/bus_position.dart';
import 'package:m_mobilnost/data/models/occupancy.dart';
import 'package:m_mobilnost/data/models/trip_plan.dart';
import 'package:m_mobilnost/data/models/user_profile.dart';
import 'package:m_mobilnost/data/repositories/auth_repository.dart';
import 'package:m_mobilnost/data/seed/seed_lines.dart';
import 'package:m_mobilnost/data/seed/seed_stops.dart';
import 'package:m_mobilnost/data/simulation/bus_simulator.dart';
import 'package:m_mobilnost/features/trip_planner/domain/route_planner.dart';

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
}
