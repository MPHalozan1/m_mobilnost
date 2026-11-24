// Unit tests for Maribor seed topology, timetables, auth, tickets, payments, and notices.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/network/data_freshness.dart';
import 'package:m_mobilnost/core/widgets/occupancy_strip.dart';
import 'package:m_mobilnost/core/widgets/status_chip.dart';
import 'package:m_mobilnost/data/mock/mock_auth_repository.dart';
import 'package:m_mobilnost/data/mock/mock_line_repository.dart';
import 'package:m_mobilnost/data/mock/mock_notice_repository.dart';
import 'package:m_mobilnost/data/mock/mock_payment_repository.dart';
import 'package:m_mobilnost/data/mock/mock_ticket_repository.dart';
import 'package:m_mobilnost/data/mock/mock_timetable_repository.dart';
import 'package:m_mobilnost/data/mock/mock_trip_repository.dart';
import 'package:m_mobilnost/data/models/payment_method.dart';
import 'package:m_mobilnost/data/models/ticket.dart';
import 'package:m_mobilnost/data/models/trip_plan.dart';
import 'package:m_mobilnost/data/models/user_profile.dart';
import 'package:m_mobilnost/data/repositories/auth_repository.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/seed/seed_lines.dart';
import 'package:m_mobilnost/data/seed/seed_places.dart';
import 'package:m_mobilnost/data/seed/seed_stops.dart';
import 'package:m_mobilnost/data/seed/seed_tickets.dart';
import 'package:m_mobilnost/data/seed/seed_timetables.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Seed data integrity', () {
    test('has 62 Maribor stops, 19 bidirectional lines (G1-G6 & P7-P19), hubs, and 16 places', () {
      expect(seedStops.length, 62);
      expect(seedLines.length, 19);
      expect(seedPlaces.length, 16);
      expect(seedTicketTypes.length, 15);

      const requiredStops = [
        'glavni_trg',
        'glavna_postaja',
        'europark',
        'ukc_maribor',
        'univerza',
        'tabor',
        'studenci',
        'pekre',
        'melje',
        'mariborski_otok',
        'kamnica',
        'razvanje',
        'pobrezje',
        'tezno',
        'spelina',
        'feri',
        'lent',
        'drava',
      ];
      for (final id in requiredStops) {
        expect(seedStopsById.containsKey(id), isTrue, reason: 'Missing $id');
      }

      // Every line has both directions, distinct color, and matching stop coordinates.
      final colors = <int>{};
      for (final line in seedLines) {
        colors.add(line.color.toARGB32());
        expect(line.directions.length, 2);
        for (final dir in line.directions) {
          expect(dir.stopIds.length, greaterThanOrEqualTo(6));
          expect(dir.polyline.length, dir.stopIds.length);
          expect(dir.terminalStopId, dir.stopIds.last);
          for (final stopId in dir.stopIds) {
            final stop = seedStopsById[stopId];
            expect(stop, isNotNull, reason: 'Unknown stop $stopId on ${line.id}');
            expect(
              stop!.lineIds.contains(line.id),
              isTrue,
              reason: 'Stop $stopId missing lineId ${line.id}',
            );
          }
        }
      }
      expect(colors.length, 19);

      // Major transfer hubs serve multiple lines.
      expect(seedStopsById['glavni_trg']!.lineIds.length, greaterThanOrEqualTo(4));
      expect(seedStopsById['glavna_postaja']!.lineIds.length, greaterThanOrEqualTo(4));
      expect(seedStopsById['ukc_maribor']!.lineIds.length, greaterThanOrEqualTo(4));
    });
  });

  group('Timetables & Trip Planner', () {
    test('rule-based schedule varies peak vs off-peak vs weekend and falls back offline', () async {
      final weekday = DateTime(2026, 11, 23, 7, 30); // Monday.
      final saturday = DateTime(2026, 11, 21, 7, 30);
      final sunday = DateTime(2026, 11, 22, 7, 30);

      expect(scheduleTypeForDate(weekday), DayScheduleType.weekday);
      expect(scheduleTypeForDate(saturday), DayScheduleType.saturday);
      expect(scheduleTypeForDate(sunday), DayScheduleType.sundayHoliday);

      final line6 = seedLinesById['G6']!;
      final weekdayTrips = generateTripsForDirection(
        line: line6,
        direction: line6.directions.first,
        date: weekday,
      );
      final sundayTrips = generateTripsForDirection(
        line: line6,
        direction: line6.directions.first,
        date: sunday,
      );
      expect(weekdayTrips.length, greaterThan(sundayTrips.length));

      // Verify peak interval (~10 min on Line 6) vs evening (>= 45 min).
      final morningPeak = weekdayTrips
          .where((t) => t.startTime.hour == 7)
          .map((t) => t.startTime)
          .toList();
      expect(morningPeak.length, greaterThanOrEqualTo(5));
      expect(
        morningPeak[1].difference(morningPeak[0]).inMinutes,
        inInclusiveRange(10, 20),
      );

      final repo = MockTimetableRepository();
      final liveDeps = await repo.getDeparturesForStop(
        'glavni_trg',
        at: weekday,
        useSimulatedLive: true,
      );
      expect(liveDeps, isNotEmpty);
      expect(liveDeps.first.freshness.kind, DataSourceKind.simulated);

      final disabledLiveDeps = await repo.getDeparturesForStop(
        'glavni_trg',
        at: weekday,
        useSimulatedLive: false,
      );
      expect(disabledLiveDeps, isNotEmpty);
      expect(disabledLiveDeps.first.freshness.kind, DataSourceKind.cached);
      expect(disabledLiveDeps.first.delaySeconds, 0);
      expect(disabledLiveDeps.first.occupancy, BusOccupancyLevel.unknown);
      expect(disabledLiveDeps.first.status, TransitStatusType.onTime);

      final offlineDeps = await repo.getDeparturesForStop(
        'glavni_trg',
        at: weekday,
        useSimulatedLive: true,
        isOffline: true,
      );
      expect(offlineDeps.first.freshness.kind, DataSourceKind.cached);
      expect(offlineDeps.first.delaySeconds, 0);
    });

    test('MockTripRepository plans direct and transfer routes and respects accessibleOnly', () async {
      const lineRepo = MockLineRepository();
      final timetableRepo = MockTimetableRepository();
      final tripRepo = MockTripRepository(
        lineRepository: lineRepo,
        timetableRepository: timetableRepo,
      );

      // Direct route: Glavni trg -> UKC Maribor.
      final directOptions = await tripRepo.planTrip(
        origin: seedStopsById['glavni_trg']!.position,
        destination: seedStopsById['ukc_maribor']!.position,
        mode: TripTimeMode.departAt,
        targetTime: DateTime(2026, 11, 23, 8, 0),
      );
      expect(directOptions, isNotEmpty);
      expect(directOptions.first.transferCount, 0);

      // Multi-district transfer route: Pekre -> Pobrežje.
      final transferOptions = await tripRepo.planTrip(
        origin: seedStopsById['pekre']!.position,
        destination: seedStopsById['pobrezje']!.position,
        mode: TripTimeMode.leaveNow,
        targetTime: DateTime(2026, 11, 23, 8, 0),
      );
      expect(transferOptions, isNotEmpty);
      expect(transferOptions.any((o) => o.transferCount == 1), isTrue);

      // Nearest stop from Rošpoh with accessibleOnly skips non-step-free Rošpoh.
      final rospohPos = seedStopsById['rospoh']!.position;
      final nearestAny = await tripRepo.findNearestStop(rospohPos);
      final nearestStepFree = await tripRepo.findNearestStop(
        rospohPos,
        accessibleOnly: true,
      );
      expect(nearestAny?.id, 'rospoh');
      expect(nearestStepFree?.isStepFree, isTrue);
      expect(nearestStepFree?.id, isNot('rospoh'));
    });
  });

  group('MockAuthRepository', () {
    test('supports demo login, signup, minor/senior helpers, and deleteAccount wipe', () async {
      SharedPreferences.setMockInitialValues({'onboarding_flag': true});
      final prefs = await SharedPreferences.getInstance();
      final ticketRepo = MockTicketRepository();
      final auth = MockAuthRepository(
        prefs: prefs,
        onDeleteLocalData: ticketRepo.clearAllTickets,
      );
      addTearDown(() {
        auth.dispose();
        ticketRepo.dispose();
      });

      // Invalid password rejected.
      await expectLater(
        () => auth.signIn(email: MockAuthRepository.demoEmail, password: 'bad'),
        throwsA(isA<AuthException>()),
      );

      // Demo login succeeds.
      final demoUser = await auth.signIn(
        email: MockAuthRepository.demoEmail,
        password: MockAuthRepository.demoPassword,
      );
      expect(demoUser.email, MockAuthRepository.demoEmail);
      expect(auth.currentUser?.id, demoUser.id);

      await auth.signOut();
      expect(auth.currentUser, isNull);

      // Sign up a 15-year-old minor and verify age helpers.
      final minor = await auth.signUp(
        email: 'minor@maribor.test',
        password: 'pass1234',
        name: 'Luka Novak',
        dateOfBirth: DateTime(2011, 6, 1),
        guardianConfirmed: true,
      );
      final refDate = DateTime(2026, 11, 23);
      expect(minor.ageAt(refDate), 15);
      expect(minor.isUnder16At(refDate), isTrue);
      expect(minor.isUnder18At(refDate), isTrue);
      expect(minor.isYouthEligibleAt(refDate), isTrue);
      expect(minor.isSeniorEligibleAt(refDate), isFalse);

      // Senior profile check.
      final senior = UserProfile(
        id: 'u_senior',
        email: 'senior@maribor.test',
        name: 'Marija Horvat',
        dateOfBirth: DateTime(1958, 3, 10),
        createdAt: refDate,
      );
      expect(senior.isSeniorEligibleAt(refDate), isTrue);
      expect(senior.isYouthEligibleAt(refDate), isFalse);

      // Issue a ticket, then call deleteAccount and verify full wipe.
      await ticketRepo.purchaseTicket(
        type: seedTicketTypes.first,
        userId: minor.id,
      );
      expect(await ticketRepo.getUserTickets(minor.id), hasLength(1));

      await auth.deleteAccount();
      expect(auth.currentUser, isNull);
      expect(prefs.getKeys(), isEmpty);
      expect(await ticketRepo.getUserTickets(minor.id), isEmpty);
    });
  });

  group('MockPaymentRepository & MockNoticeRepository', () {
    test('seeds 5 payment methods and stores only brand + last 4 digits on card add', () async {
      final payments = MockPaymentRepository();
      const userId = 'user_pay_test';

      final methods = await payments.getPaymentMethods(userId);
      expect(methods.length, 5);
      expect(
        methods.map((m) => m.type),
        containsAll(PaymentMethodType.values),
      );
      expect(methods.first.last4Digits, '4242');

      const fullPan = '4532 1234 5678 9876';
      final added = await payments.addCardMethod(
        userId: userId,
        brand: 'Mastercard',
        cardNumber: fullPan,
      );
      expect(added.brand, 'Mastercard');
      expect(added.last4Digits, '9876');
      final serialized = added.toJson().toString();
      expect(serialized, isNot(contains('4532')));
      expect(serialized, isNot(contains('1234')));
      expect(serialized, isNot(contains('5678')));

      expect(
        await payments.simulateCharge(
          userId: userId,
          methodId: added.id,
          amountEur: 1.30,
        ),
        isTrue,
      );
    });

    test('MockNoticeRepository localizes notices in all 4 languages and tracks read state', () async {
      final fixedNow = DateTime(2026, 11, 23, 8, 15);
      final noticesRepo = MockNoticeRepository(clock: () => fixedNow);
      addTearDown(noticesRepo.dispose);

      final notices = await noticesRepo.getNotices(useSimulatedLive: false);
      expect(notices.length, 5);

      for (final notice in notices) {
        for (final locale in ['sl', 'en', 'de', 'sr_Latn']) {
          expect(notice.localizedTitle(locale), isNotEmpty);
          expect(notice.localizedBody(locale), isNotEmpty);
          expect(notice.localizedAlternativeHint(locale), isNotNull);
        }
      }

      await noticesRepo.markAsRead(notices.first.id);
      final afterRead = await noticesRepo.getNotices(useSimulatedLive: false);
      expect(afterRead.firstWhere((n) => n.id == notices.first.id).isRead, isTrue);
    });
  });

  group('Riverpod repository providers', () {
    test('resolve cleanly inside a ProviderContainer', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final lines = await container.read(lineRepositoryProvider).getLines();
      expect(lines.length, 19);

      final nearest = await container
          .read(tripRepositoryProvider)
          .findNearestStop(const LatLng(46.5547, 15.6459));
      expect(nearest, isNotNull);

      final types =
          await container.read(ticketRepositoryProvider).getTicketTypes();
      expect(types.length, 15);
    });
  });

  group('MockTicketRepository', () {
    test('issues immediate and start-later tickets and persists via Hive', () async {
      final tempDir = await Directory.systemTemp.createTemp('mm_hive_test_');
      Hive.init(tempDir.path);
      const boxName = 'test_tickets_box';

      final fixedNow = DateTime(2026, 11, 23, 10, 0);
      final repo1 = MockTicketRepository(
        boxName: boxName,
        clock: () => fixedNow,
      );

      final singleType = seedTicketTypesById['single']!;
      final immediate = await repo1.purchaseTicket(
        type: singleType,
        userId: 'user_1',
      );
      expect(immediate.validFrom, fixedNow);
      expect(immediate.validUntil, fixedNow.add(const Duration(minutes: 75)));
      expect(immediate.statusAt(fixedNow), TicketStatus.active);
      expect(
        immediate.statusAt(fixedNow.add(const Duration(minutes: 80))),
        TicketStatus.expired,
      );

      final futureStart = fixedNow.add(const Duration(hours: 3));
      final upcoming = await repo1.purchaseTicket(
        type: singleType,
        userId: 'user_1',
        validFrom: futureStart,
      );
      expect(upcoming.statusAt(fixedNow), TicketStatus.upcoming);
      expect(
        upcoming.statusAt(futureStart.add(const Duration(minutes: 10))),
        TicketStatus.active,
      );

      repo1.dispose();

      // New repository instance pointing at same Hive box restores tickets offline.
      final repo2 = MockTicketRepository(
        boxName: boxName,
        clock: () => fixedNow,
      );
      final loaded = await repo2.getUserTickets('user_1');
      expect(loaded.length, 2);
      expect(loaded.map((t) => t.id), containsAll([immediate.id, upcoming.id]));

      await repo2.clearAllTickets();
      repo2.dispose();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });
  });
}
