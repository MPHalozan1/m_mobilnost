// Mock TripRepository finding direct and 1-transfer Maribor transit itineraries.

import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/utils/distance.dart';
import 'package:m_mobilnost/core/utils/geo.dart';

import '../models/bus_line.dart';
import '../models/bus_stop.dart';
import '../models/departure.dart';
import '../models/trip_plan.dart';
import '../repositories/line_repository.dart';
import '../repositories/timetable_repository.dart';
import '../repositories/trip_repository.dart';

/// Mock [TripRepository] solving 0-transfer and 1-transfer bus routes across Maribor.
class MockTripRepository implements TripRepository {
  /// Creates a [MockTripRepository] querying [lineRepository] and [timetableRepository].
  MockTripRepository({
    required LineRepository lineRepository,
    required TimetableRepository timetableRepository,
    bool Function()? isSimulatedLiveEnabled,
    bool Function()? isOfflineCheck,
  })  : _lines = lineRepository,
        _timetables = timetableRepository,
        _isSimulatedLiveEnabled = isSimulatedLiveEnabled ?? (() => true),
        _isOfflineCheck = isOfflineCheck ?? (() => false);

  final LineRepository _lines;
  final TimetableRepository _timetables;
  final bool Function() _isSimulatedLiveEnabled;
  final bool Function() _isOfflineCheck;

  @override
  Future<BusStop?> findNearestStop(
    LatLng position, {
    bool accessibleOnly = false,
  }) async {
    final stops = await _lines.getStops();
    BusStop? best;
    var bestMeters = double.infinity;
    for (final stop in stops) {
      if (accessibleOnly && !stop.isStepFree) continue;
      final d = GeoUtils.haversineMeters(position, stop.position);
      if (d < bestMeters) {
        bestMeters = d;
        best = stop;
      }
    }
    return best;
  }

  @override
  Future<List<TripOption>> planTrip({
    required LatLng origin,
    required LatLng destination,
    TripTimeMode mode = TripTimeMode.leaveNow,
    DateTime? targetTime,
    bool accessibleOnly = false,
    bool fewerTransfers = false,
    bool? useSimulatedLive,
    bool isOffline = false,
  }) async {
    final now = targetTime ?? DateTime.now();
    final effectiveLive =
        (useSimulatedLive ?? _isSimulatedLiveEnabled()) &&
            !isOffline &&
            !_isOfflineCheck();

    final stops = await _lines.getStops();
    final stopsById = {for (final s in stops) s.id: s};
    final lines = (await _lines.getLines())
        .where((l) => !accessibleOnly || l.isLowFloorDefault)
        .toList(growable: false);

    final candidateStops = stops
        .where((s) => !accessibleOnly || s.isStepFree)
        .toList(growable: false);
    if (candidateStops.isEmpty || lines.isEmpty) return const [];

    final originStops = _nearestSorted(origin, candidateStops, 4);
    final destStops = _nearestSorted(destination, candidateStops, 4);
    final options = <TripOption>[];

    // 1. Direct (0-transfer) routes.
    for (final oStop in originStops) {
      for (final dStop in destStops) {
        if (oStop.id == dStop.id) continue;
        for (final line in lines) {
          for (final dir in line.directions) {
            final oIdx = dir.stopIds.indexOf(oStop.id);
            final dIdx = dir.stopIds.indexOf(dStop.id);
            if (oIdx == -1 || dIdx <= oIdx) continue;
            final option = await _buildDirectOption(
              origin: origin,
              destination: destination,
              oStop: oStop,
              dStop: dStop,
              line: line,
              dir: dir,
              oIdx: oIdx,
              dIdx: dIdx,
              stopsById: stopsById,
              mode: mode,
              target: now,
              effectiveLive: effectiveLive,
              isOffline: isOffline,
            );
            if (option != null) options.add(option);
          }
        }
      }
    }

    // 2. Single-transfer routes via shared intermediate hub stops.
    for (final oStop in originStops.take(3)) {
      for (final dStop in destStops.take(3)) {
        if (oStop.id == dStop.id) continue;
        for (final l1 in lines) {
          for (final dir1 in l1.directions) {
            final oIdx = dir1.stopIds.indexOf(oStop.id);
            if (oIdx == -1) continue;
            for (var tIdx1 = oIdx + 1; tIdx1 < dir1.stopIds.length; tIdx1++) {
              final transferId = dir1.stopIds[tIdx1];
              final tStop = stopsById[transferId];
              if (tStop == null || (accessibleOnly && !tStop.isStepFree)) {
                continue;
              }
              for (final l2 in lines) {
                if (l2.id == l1.id) continue;
                for (final dir2 in l2.directions) {
                  final tIdx2 = dir2.stopIds.indexOf(transferId);
                  final dIdx = dir2.stopIds.indexOf(dStop.id);
                  if (tIdx2 == -1 || dIdx <= tIdx2) continue;
                  final option = await _buildTransferOption(
                    origin: origin,
                    destination: destination,
                    oStop: oStop,
                    tStop: tStop,
                    dStop: dStop,
                    l1: l1,
                    dir1: dir1,
                    oIdx: oIdx,
                    tIdx1: tIdx1,
                    l2: l2,
                    dir2: dir2,
                    tIdx2: tIdx2,
                    dIdx: dIdx,
                    stopsById: stopsById,
                    mode: mode,
                    target: now,
                    effectiveLive: effectiveLive,
                    isOffline: isOffline,
                  );
                  if (option != null) options.add(option);
                  if (options.length >= 24) break;
                }
              }
            }
          }
        }
      }
    }

    // Deduplicate identical line combinations keeping the fastest itinerary.
    final bestBySignature = <String, TripOption>{};
    for (final opt in options) {
      final sig = opt.legs
          .where((l) => l.type == TripLegType.bus)
          .map((l) => '${l.lineId}:${l.fromStopId}->${l.toStopId}')
          .join('|');
      final prev = bestBySignature[sig];
      if (prev == null || opt.totalMinutes < prev.totalMinutes) {
        bestBySignature[sig] = opt;
      }
    }

    final ranked = bestBySignature.values.toList();
    ranked.sort((a, b) {
      if (fewerTransfers && a.transferCount != b.transferCount) {
        return a.transferCount.compareTo(b.transferCount);
      }
      final timeCmp = mode == TripTimeMode.arriveBy
          ? b.arrivalTime.compareTo(a.arrivalTime)
          : a.arrivalTime.compareTo(b.arrivalTime);
      if (timeCmp != 0) return timeCmp;
      return a.transferCount.compareTo(b.transferCount);
    });
    return ranked.take(4).toList(growable: false);
  }

  Future<TripOption?> _buildDirectOption({
    required LatLng origin,
    required LatLng destination,
    required BusStop oStop,
    required BusStop dStop,
    required BusLine line,
    required LineDirection dir,
    required int oIdx,
    required int dIdx,
    required Map<String, BusStop> stopsById,
    required TripTimeMode mode,
    required DateTime target,
    required bool effectiveLive,
    required bool isOffline,
  }) async {
    final walk1Meters = GeoUtils.haversineMeters(origin, oStop.position);
    final walk2Meters = GeoUtils.haversineMeters(dStop.position, destination);
    final walk1Min = DistanceUtils.estimateWalkMinutes(walk1Meters);
    final walk2Min = DistanceUtils.estimateWalkMinutes(walk2Meters);
    final rideMin = _rideMinutes(dir, oIdx, dIdx, stopsById);

    final searchAt = mode == TripTimeMode.arriveBy
        ? target.subtract(Duration(minutes: rideMin + walk2Min + 30))
        : target.add(Duration(minutes: walk1Min));

    final deps = await _timetables.getDeparturesForLine(
      line.id,
      dir.id,
      at: searchAt,
      stopId: oStop.id,
      useSimulatedLive: effectiveLive,
      isOffline: isOffline,
    );
    final chosen = _pickDeparture(
      deps: deps,
      mode: mode,
      target: target,
      walk1Min: walk1Min,
      rideMin: rideMin,
      walk2Min: walk2Min,
    );
    if (chosen == null) return null;

    final boardAt = chosen.estimatedTime;
    final alightAt = boardAt.add(Duration(minutes: rideMin));
    final start = boardAt.subtract(Duration(minutes: walk1Min));
    final end = alightAt.add(Duration(minutes: walk2Min));

    final legs = [
      if (walk1Meters > 15)
        _walkLeg(
          fromName: 'Origin',
          toName: oStop.name,
          toStopId: oStop.id,
          start: start,
          end: boardAt,
          minutes: walk1Min,
          meters: walk1Meters,
          fromPos: origin,
          toPos: oStop.position,
        ),
      _busLeg(
        fromStop: oStop,
        toStop: dStop,
        line: line,
        dir: dir,
        fromIdx: oIdx,
        toIdx: dIdx,
        departure: chosen,
        rideMin: rideMin,
      ),
      if (walk2Meters > 15)
        _walkLeg(
          fromName: dStop.name,
          toName: 'Destination',
          fromStopId: dStop.id,
          start: alightAt,
          end: end,
          minutes: walk2Min,
          meters: walk2Meters,
          fromPos: dStop.position,
          toPos: destination,
        ),
    ];

    return TripOption(
      id: 'direct_${line.id}_${oStop.id}_${dStop.id}_${boardAt.millisecondsSinceEpoch}',
      totalMinutes: end.difference(start).inMinutes.clamp(1, 300),
      walkMeters: walk1Meters + walk2Meters,
      walkMinutes: walk1Min + walk2Min,
      transferCount: 0,
      hasTightTransfer: false,
      legs: legs,
      freshness: chosen.freshness,
      reliabilityNote: chosen.delaySeconds > 120 ? 'simulated_delay' : null,
    );
  }

  Future<TripOption?> _buildTransferOption({
    required LatLng origin,
    required LatLng destination,
    required BusStop oStop,
    required BusStop tStop,
    required BusStop dStop,
    required BusLine l1,
    required LineDirection dir1,
    required int oIdx,
    required int tIdx1,
    required BusLine l2,
    required LineDirection dir2,
    required int tIdx2,
    required int dIdx,
    required Map<String, BusStop> stopsById,
    required TripTimeMode mode,
    required DateTime target,
    required bool effectiveLive,
    required bool isOffline,
  }) async {
    final walk1Meters = GeoUtils.haversineMeters(origin, oStop.position);
    final walk2Meters = GeoUtils.haversineMeters(dStop.position, destination);
    final walk1Min = DistanceUtils.estimateWalkMinutes(walk1Meters);
    final walk2Min = DistanceUtils.estimateWalkMinutes(walk2Meters);
    final ride1Min = _rideMinutes(dir1, oIdx, tIdx1, stopsById);
    final ride2Min = _rideMinutes(dir2, tIdx2, dIdx, stopsById);

    final queryTime = mode == TripTimeMode.arriveBy
        ? target.subtract(Duration(minutes: ride1Min + ride2Min + walk2Min + 45))
        : target;

    final deps1 = await _timetables.getDeparturesForLine(
      l1.id,
      dir1.id,
      at: queryTime,
      stopId: oStop.id,
      useSimulatedLive: effectiveLive,
      isOffline: isOffline,
    );
    final earliestBoard1 = mode == TripTimeMode.arriveBy
        ? queryTime
        : target.add(Duration(minutes: walk1Min));
    Departure? leg1Dep;
    for (final d in deps1) {
      if (!d.isCancelled && !d.estimatedTime.isBefore(earliestBoard1)) {
        leg1Dep = d;
        break;
      }
    }
    if (leg1Dep == null) return null;

    final alight1 = leg1Dep.estimatedTime.add(Duration(minutes: ride1Min));
    final deps2 = await _timetables.getDeparturesForLine(
      l2.id,
      dir2.id,
      at: alight1,
      stopId: tStop.id,
      useSimulatedLive: effectiveLive,
      isOffline: isOffline,
    );
    Departure? leg2Dep;
    for (final d in deps2) {
      final buffer = d.estimatedTime.difference(alight1).inMinutes;
      if (!d.isCancelled && buffer >= 1 && buffer <= 25) {
        leg2Dep = d;
        break;
      }
    }
    if (leg2Dep == null) return null;

    final board2 = leg2Dep.estimatedTime;
    final alight2 = board2.add(Duration(minutes: ride2Min));
    final start = leg1Dep.estimatedTime.subtract(Duration(minutes: walk1Min));
    final end = alight2.add(Duration(minutes: walk2Min));
    if (mode == TripTimeMode.arriveBy && end.isAfter(target)) return null;

    final bufferMin = board2.difference(alight1).inMinutes;
    final isTight = bufferMin <= 4;

    final legs = [
      if (walk1Meters > 15)
        _walkLeg(
          fromName: 'Origin',
          toName: oStop.name,
          toStopId: oStop.id,
          start: start,
          end: leg1Dep.estimatedTime,
          minutes: walk1Min,
          meters: walk1Meters,
          fromPos: origin,
          toPos: oStop.position,
        ),
      _busLeg(
        fromStop: oStop,
        toStop: tStop,
        line: l1,
        dir: dir1,
        fromIdx: oIdx,
        toIdx: tIdx1,
        departure: leg1Dep,
        rideMin: ride1Min,
      ),
      _busLeg(
        fromStop: tStop,
        toStop: dStop,
        line: l2,
        dir: dir2,
        fromIdx: tIdx2,
        toIdx: dIdx,
        departure: leg2Dep,
        rideMin: ride2Min,
      ),
      if (walk2Meters > 15)
        _walkLeg(
          fromName: dStop.name,
          toName: 'Destination',
          fromStopId: dStop.id,
          start: alight2,
          end: end,
          minutes: walk2Min,
          meters: walk2Meters,
          fromPos: dStop.position,
          toPos: destination,
        ),
    ];

    return TripOption(
      id: 'xfer_${l1.id}_${l2.id}_${tStop.id}_${leg1Dep.estimatedTime.millisecondsSinceEpoch}',
      totalMinutes: end.difference(start).inMinutes.clamp(1, 300),
      walkMeters: walk1Meters + walk2Meters,
      walkMinutes: walk1Min + walk2Min,
      transferCount: 1,
      hasTightTransfer: isTight,
      tightTransferMinutes: isTight ? bufferMin : null,
      legs: legs,
      freshness: leg1Dep.freshness,
      reliabilityNote: isTight ? 'tight_transfer' : null,
    );
  }

  Departure? _pickDeparture({
    required List<Departure> deps,
    required TripTimeMode mode,
    required DateTime target,
    required int walk1Min,
    required int rideMin,
    required int walk2Min,
  }) {
    if (mode == TripTimeMode.arriveBy) {
      final latestBoard = target.subtract(Duration(minutes: rideMin + walk2Min));
      Departure? best;
      for (final d in deps) {
        if (d.isCancelled) continue;
        if (!d.estimatedTime.isAfter(latestBoard)) best = d;
      }
      return best;
    }
    final earliestBoard = target.add(Duration(minutes: walk1Min));
    for (final d in deps) {
      if (!d.isCancelled && !d.estimatedTime.isBefore(earliestBoard)) return d;
    }
    return null;
  }

  int _rideMinutes(
    LineDirection dir,
    int fromIdx,
    int toIdx,
    Map<String, BusStop> stopsById,
  ) {
    var totalSeconds = 0;
    for (var i = fromIdx; i < toIdx; i++) {
      final a = stopsById[dir.stopIds[i]]?.position;
      final b = stopsById[dir.stopIds[i + 1]]?.position;
      final meters = (a != null && b != null)
          ? GeoUtils.haversineMeters(a, b)
          : 550.0;
      totalSeconds += (meters / 6.67).round() + 25;
    }
    return (totalSeconds / 60.0).ceil().clamp(1, 90);
  }

  List<BusStop> _nearestSorted(LatLng target, List<BusStop> stops, int count) {
    final copy = List<BusStop>.from(stops);
    copy.sort((a, b) => GeoUtils.haversineMeters(target, a.position)
        .compareTo(GeoUtils.haversineMeters(target, b.position)));
    return copy.take(count).toList(growable: false);
  }

  TripLeg _walkLeg({
    required String fromName,
    required String toName,
    String? fromStopId,
    String? toStopId,
    required DateTime start,
    required DateTime end,
    required int minutes,
    required double meters,
    required LatLng fromPos,
    required LatLng toPos,
  }) {
    return TripLeg(
      type: TripLegType.walk,
      fromName: fromName,
      toName: toName,
      fromStopId: fromStopId,
      toStopId: toStopId,
      startTime: start,
      endTime: end,
      durationMinutes: minutes,
      distanceMeters: meters,
      polyline: [fromPos, toPos],
    );
  }

  TripLeg _busLeg({
    required BusStop fromStop,
    required BusStop toStop,
    required BusLine line,
    required LineDirection dir,
    required int fromIdx,
    required int toIdx,
    required Departure departure,
    required int rideMin,
  }) {
    final poly = dir.polyline.length > toIdx && fromIdx < toIdx
        ? dir.roadPathBetween(fromIdx, toIdx)
        : <LatLng>[fromStop.position, toStop.position];
    final boardAt = departure.estimatedTime;
    return TripLeg(
      type: TripLegType.bus,
      fromName: fromStop.name,
      toName: toStop.name,
      fromStopId: fromStop.id,
      toStopId: toStop.id,
      startTime: boardAt,
      endTime: boardAt.add(Duration(minutes: rideMin)),
      durationMinutes: rideMin,
      distanceMeters: GeoUtils.polylineLengthMeters(poly),
      lineId: line.id,
      lineCode: line.code,
      directionId: dir.id,
      directionName: dir.name,
      stopCount: toIdx - fromIdx,
      intermediateStopIds: dir.stopIds.sublist(fromIdx, toIdx + 1),
      polyline: poly,
      occupancy: departure.occupancy,
      delaySeconds: departure.delaySeconds,
      isAccessible:
          line.isLowFloorDefault && fromStop.isStepFree && toStop.isStepFree,
    );
  }
}
