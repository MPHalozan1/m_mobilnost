// Unit tests for DelayModel, OccupancyModel, BusSimulator, and NoticeGenerator.

import 'package:flutter_test/flutter_test.dart';
import 'package:m_mobilnost/core/utils/geo.dart';
import 'package:m_mobilnost/core/widgets/status_chip.dart';
import 'package:m_mobilnost/data/models/bus_position.dart';
import 'package:m_mobilnost/data/models/departure.dart';
import 'package:m_mobilnost/data/models/occupancy.dart';
import 'package:m_mobilnost/core/network/data_freshness.dart';
import 'package:m_mobilnost/data/seed/seed_lines.dart';
import 'package:m_mobilnost/data/simulation/bus_simulator.dart';
import 'package:m_mobilnost/data/simulation/delay_model.dart';
import 'package:m_mobilnost/data/simulation/notice_generator.dart';
import 'package:m_mobilnost/data/simulation/occupancy_model.dart';

void main() {
  group('DelayModel', () {
    test('enforces early, onTime, and late thresholds on DelayModel & Departure', () {
      expect(DelayModel.statusForDelay(-61), TransitStatusType.early);
      expect(DelayModel.statusForDelay(-60), TransitStatusType.onTime);
      expect(DelayModel.statusForDelay(0), TransitStatusType.onTime);
      expect(DelayModel.statusForDelay(120), TransitStatusType.onTime);
      expect(DelayModel.statusForDelay(121), TransitStatusType.late);

      final baseTime = DateTime(2026, 11, 23, 8, 0);
      final freshness = DataFreshness(
        kind: DataSourceKind.simulated,
        updatedAt: baseTime,
      );
      final earlyDep = Departure(
        id: 'd1',
        lineId: '1',
        lineCode: '1',
        directionId: '1_out',
        directionName: 'Tezno – Rošpoh',
        stopId: 'glavni_trg',
        scheduledTime: baseTime,
        delaySeconds: -90,
        occupancy: BusOccupancyLevel.low,
        freshness: freshness,
      );
      expect(earlyDep.status, TransitStatusType.early);
      expect(earlyDep.estimatedTime, DateTime(2026, 11, 23, 7, 58, 30));

      final onTimeDep = Departure(
        id: 'd2',
        lineId: '1',
        lineCode: '1',
        directionId: '1_out',
        directionName: 'Tezno – Rošpoh',
        stopId: 'glavni_trg',
        scheduledTime: baseTime,
        delaySeconds: 90,
        occupancy: BusOccupancyLevel.medium,
        freshness: freshness,
      );
      expect(onTimeDep.status, TransitStatusType.onTime);

      final lateDep = Departure(
        id: 'd3',
        lineId: '1',
        lineCode: '1',
        directionId: '1_out',
        directionName: 'Tezno – Rošpoh',
        stopId: 'glavni_trg',
        scheduledTime: baseTime,
        delaySeconds: 240,
        occupancy: BusOccupancyLevel.high,
        freshness: freshness,
      );
      expect(lateDep.status, TransitStatusType.late);
      expect(lateDep.estimatedTime, DateTime(2026, 11, 23, 8, 4));
    });

    test('is deterministic for the same seed and emits early, onTime, and late trips', () {
      const modelA = DelayModel(seed: 42);
      const modelA2 = DelayModel(seed: 42);
      const modelB = DelayModel(seed: 99);

      final time = DateTime(2026, 11, 23, 7, 45); // Monday rush hour.
      final statuses = <TransitStatusType>{};

      for (var i = 0; i < 60; i++) {
        final tripId = 'trip_$i';
        final lineId = seedLines[i % seedLines.length].id;
        final d1 = modelA.delaySecondsForTrip(
          tripId: tripId,
          lineId: lineId,
          scheduledTime: time.add(Duration(minutes: i * 3)),
        );
        final d2 = modelA2.delaySecondsForTrip(
          tripId: tripId,
          lineId: lineId,
          scheduledTime: time.add(Duration(minutes: i * 3)),
        );
        expect(d1, equals(d2));
        statuses.add(DelayModel.statusForDelay(d1));
      }

      // Different seed should alter at least some delays.
      final diffCount = List.generate(20, (i) {
        final t = time.add(Duration(minutes: i * 5));
        return modelA.delaySecondsForTrip(
              tripId: 'cmp_$i',
              lineId: '6',
              scheduledTime: t,
            ) !=
            modelB.delaySecondsForTrip(
              tripId: 'cmp_$i',
              lineId: '6',
              scheduledTime: t,
            );
      }).where((changed) => changed).length;

      expect(diffCount, greaterThan(5));
      expect(statuses, containsAll([
        TransitStatusType.early,
        TransitStatusType.onTime,
        TransitStatusType.late,
      ]));
    });
  });

  group('OccupancyModel', () {
    test('produces higher load during school rush hour than late evening', () {
      const model = OccupancyModel(seed: 42);
      final rushHour = DateTime(2026, 11, 23, 7, 40); // Monday school peak.
      final lateEvening = DateTime(2026, 11, 23, 21, 40);

      var rushLoadSum = 0;
      var eveningLoadSum = 0;
      for (final line in seedLines.take(6)) {
        final dir = line.directions.first;
        final rush = model.estimateSegment(
          lineId: line.id,
          directionId: dir.id,
          fromStopId: dir.stopIds[1],
          toStopId: dir.stopIds[2],
          at: rushHour,
        );
        final evening = model.estimateSegment(
          lineId: line.id,
          directionId: dir.id,
          fromStopId: dir.stopIds[1],
          toStopId: dir.stopIds[2],
          at: lateEvening,
        );
        rushLoadSum += rush.loadPercent;
        eveningLoadSum += evening.loadPercent;
      }

      expect(rushLoadSum, greaterThan(eveningLoadSum));
      expect(
        OccupancyModel.levelFromLoadPercent(20),
        BusOccupancyLevel.low,
      );
      expect(
        OccupancyModel.levelFromLoadPercent(55),
        BusOccupancyLevel.medium,
      );
      expect(
        OccupancyModel.levelFromLoadPercent(80),
        BusOccupancyLevel.high,
      );
      expect(
        OccupancyModel.levelFromLoadPercent(95),
        BusOccupancyLevel.full,
      );
    });
  });

  group('BusSimulator', () {
    test('generates active buses and advances positions smoothly along polylines', () {
      final sim = BusSimulator(seed: 42, useSimulatedLive: true);
      addTearDown(sim.dispose);

      final t1 = DateTime(2026, 11, 23, 8, 12, 0);
      final t2 = DateTime(2026, 11, 23, 8, 13, 30);

      final snap1 = sim.snapshotAt(t1);
      final snap2 = sim.snapshotAt(t2);

      expect(snap1, isNotEmpty);
      expect(snap2, isNotEmpty);

      // Find the same vehicle across t1 and t2 and verify polyline progress moved forward.
      // vehicleId alone is not unique (inbound and outbound trips can share
      // the same suffix), so match on vehicle + direction.
      final byId1 = {
        for (final b in snap1) '${b.vehicleId}|${b.directionId}': b,
      };
      BusPosition? movedBefore;
      BusPosition? movedAfter;
      for (final b2 in snap2) {
        final b1 = byId1['${b2.vehicleId}|${b2.directionId}'];
        if (b1 != null && b2.progress < 0.99) {
          movedBefore = b1;
          movedAfter = b2;
          break;
        }
      }

      expect(movedBefore, isNotNull);
      expect(movedAfter, isNotNull);
      expect(movedAfter!.progress, greaterThan(movedBefore!.progress));
      final movedMeters = GeoUtils.haversineMeters(
        movedBefore.position,
        movedAfter.position,
      );
      expect(movedMeters, greaterThan(50));
      expect(movedAfter.speedKmh, greaterThan(0));
      expect(movedAfter.remainingStopsCount, greaterThan(0));
      expect(movedAfter.passengerCount, greaterThan(0));
      expect(movedAfter.passengerCount, lessThanOrEqualTo(movedAfter.vehicleCapacity));
      expect(movedAfter.loadPercent, inInclusiveRange(1, 100));
      expect(movedAfter.vehicleModel, isNotEmpty);
    });

    test('respects disabled-live toggle and cleans up timers on dispose', () async {
      var now = DateTime(2026, 11, 23, 8, 15);
      final sim = BusSimulator(
        seed: 42,
        useSimulatedLive: true,
        tickInterval: const Duration(milliseconds: 50),
        clock: () => now,
      );

      final events = <List<BusPosition>>[];
      final sub = sim.positionsStream.listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(sim.isTimerActive, isTrue);
      expect(events, isNotEmpty);
      expect(events.first, isNotEmpty);

      // Disable simulated live mode -> timer stops and empty list is emitted.
      sim.updateConfig(useSimulatedLive: false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(sim.isTimerActive, isFalse);
      expect(events.last, isEmpty);
      expect(sim.snapshotAt(now), isEmpty);

      // Re-enable then dispose -> timer must cancel cleanly.
      sim.updateConfig(useSimulatedLive: true);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(sim.isTimerActive, isTrue);

      sim.dispose();
      await sub.cancel();
      expect(sim.isDisposed, isTrue);
      expect(sim.isTimerActive, isFalse);
    });
  });

  group('NoticeGenerator', () {
    test('combines static seed notices with dynamic simulated delay notices', () {
      const generator = NoticeGenerator(seed: 42);
      final at = DateTime(2026, 11, 23, 8, 15);

      final withLive = generator.generateNotices(at: at, useSimulatedLive: true);
      final withoutLive = generator.generateNotices(
        at: at,
        useSimulatedLive: false,
      );

      expect(withoutLive.length, 5);
      expect(withLive.length, greaterThanOrEqualTo(withoutLive.length));
    });
  });
}
