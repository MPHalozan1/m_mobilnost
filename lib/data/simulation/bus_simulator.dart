//**********************************************
// Marprom deterministic fleet simulator       *
//**********************************************

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/utils/geo.dart';

import '../models/bus_line.dart';
import '../models/bus_position.dart';
import '../seed/seed_lines.dart';
import '../seed/seed_stops.dart';
import '../seed/seed_timetables.dart';
import 'delay_model.dart';
import 'occupancy_model.dart';

/// Deterministic Maribor fleet simulator advancing active trips along polylines.
class BusSimulator {
  /// Creates a [BusSimulator] emitting positions every [tickInterval].
  BusSimulator({
    int seed = 42,
    this._useSimulatedLive = true,
    this.tickInterval = const Duration(seconds: 2),
    DateTime Function()? clock,
  })  : _seed = seed,
        _clock = clock ?? DateTime.now,
        _delayModel = DelayModel(seed: seed),
        _occupancyModel = OccupancyModel(seed: seed) {
    _controller = StreamController<List<BusPosition>>.broadcast(
      onListen: _startTimerIfNeeded,
      onCancel: _stopTimerIfNoListeners,
    );
  }

  /// Interval between periodic telemetry emissions (default 2 seconds).
  final Duration tickInterval;

  final DateTime Function() _clock;
  late final StreamController<List<BusPosition>> _controller;

  final Map<String, List<LatLng>> _googleRouteGeometries = {};
  int _seed;
  bool _useSimulatedLive;
  DelayModel _delayModel;
  OccupancyModel _occupancyModel;
  Timer? _timer;
  bool _disposed = false;

  /// Updates simulated routes with real street polylines returned by Google Routes API v2.
  void setGoogleRouteGeometries(Map<String, List<LatLng>> geometries) {
    if (_disposed || geometries.isEmpty) return;
    var changed = false;
    for (final entry in geometries.entries) {
      if (entry.value.length >= 2) {
        _googleRouteGeometries[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed && _controller.hasListener) {
      _emitCurrent();
    }
  }

  /// Current RNG seed used for delays and occupancy.
  int get seed => _seed;

  /// Whether live simulation is currently enabled.
  bool get useSimulatedLive => _useSimulatedLive;

  /// Exposes whether the periodic simulation timer is active (for testing).
  @visibleForTesting
  bool get isTimerActive => _timer?.isActive ?? false;

  /// Exposes whether [dispose] has been called (for testing).
  @visibleForTesting
  bool get isDisposed => _disposed;

  /// Broadcast stream emitting updated [BusPosition] lists every [tickInterval].
  Stream<List<BusPosition>> get positionsStream {
    if (_disposed) {
      return const Stream<List<BusPosition>>.empty();
    }
    return _controller.stream;
  }

  /// Updates simulation toggle or seed at runtime and pushes an immediate tick.
  void updateConfig({int? seed, bool? useSimulatedLive}) {
    if (_disposed) return;
    if (seed != null && seed != _seed) {
      _seed = seed;
      _delayModel = DelayModel(seed: seed);
      _occupancyModel = OccupancyModel(seed: seed);
    }
    if (useSimulatedLive != null) {
      _useSimulatedLive = useSimulatedLive;
    }
    if (!_useSimulatedLive) {
      _stopTimer();
    } else if (_controller.hasListener) {
      _startTimerIfNeeded();
    }
    _emitCurrent();
  }

  /// Computes deterministic active bus positions at an exact [now] timestamp.
  List<BusPosition> snapshotAt(DateTime now) {
    if (!_useSimulatedLive) return const [];

    final buses = <BusPosition>[];
    for (final line in seedLines) {
      for (final direction in line.directions) {
        final trips = generateTripsForDirection(
          line: line,
          direction: direction,
          date: now,
        );
        final simulationPolyline =
            _googleRouteGeometries['${line.id}|${direction.id}'] ??
                direction.roadPolyline ??
                direction.polyline;
        final polylineMeters =
            GeoUtils.polylineLengthMeters(simulationPolyline);

        for (final trip in trips) {
          final delaySeconds = _delayModel.delaySecondsForTrip(
            tripId: trip.tripId,
            lineId: line.id,
            scheduledTime: trip.startTime,
          );
          if (_delayModel.isTripCancelled(
            tripId: trip.tripId,
            lineId: line.id,
            scheduledTime: trip.startTime,
          )) {
            continue;
          }

          final effectiveStart =
              trip.startTime.add(Duration(seconds: delaySeconds));
          final effectiveEnd =
              trip.endTime.add(Duration(seconds: delaySeconds));

          if (now.isBefore(effectiveStart) || now.isAfter(effectiveEnd)) {
            continue;
          }

          final totalDurationSec =
              effectiveEnd.difference(effectiveStart).inSeconds;
          if (totalDurationSec <= 0) continue;

          final elapsedSec = now.difference(effectiveStart).inSeconds;
          final progress = (elapsedSec / totalDurationSec).clamp(0.0, 1.0);
          final pos =
              GeoUtils.interpolatePolyline(simulationPolyline, progress);
          final aheadPos = GeoUtils.interpolatePolyline(
            simulationPolyline,
            (progress + 0.015).clamp(0.0, 1.0),
          );
          final headingDegrees = GeoUtils.bearingDegrees(pos, aheadPos);

          // Identify the next stop ahead of the vehicle based on adjusted stop times.
          var nextIdx = direction.stopIds.length - 1;
          for (var i = 0; i < trip.stopTimes.length; i++) {
            final stopEta =
                trip.stopTimes[i].add(Duration(seconds: delaySeconds));
            if (!stopEta.isBefore(now)) {
              nextIdx = i;
              break;
            }
          }

          final prevIdx = nextIdx > 0 ? nextIdx - 1 : 0;
          final fromStopId = direction.stopIds[prevIdx];
          final nextStopId = direction.stopIds[nextIdx];
          final nextStopName = seedStopsById[nextStopId]?.name ?? nextStopId;
          final nextStopEta =
              trip.stopTimes[nextIdx].add(Duration(seconds: delaySeconds));
          final etaSeconds =
              nextStopEta.difference(now).inSeconds.clamp(0, 7200);

          final speedKmh = totalDurationSec > 0
              ? ((polylineMeters / 1000.0) / (totalDurationSec / 3600.0))
                  .clamp(16.0, 38.0)
              : 24.0;

          final occupancy = _occupancyModel.estimateSegment(
            lineId: line.id,
            directionId: direction.id,
            fromStopId: fromStopId,
            toStopId: nextStopId,
            at: now,
          );

          // Resolve realistic vehicle class & capacity strictly <= 120.
          final isPeakHour = (now.hour >= 7 && now.hour <= 8) ||
              (now.hour >= 13 && now.hour <= 16);
          final MarpromVehicleClass vehicleClass;
          final int capacity;
          if (line.defaultVehicleClass == MarpromVehicleClass.midibus9m) {
            vehicleClass = MarpromVehicleClass.midibus9m;
            capacity = line.maxCapacity.clamp(1, 64);
          } else if (line.defaultVehicleClass ==
              MarpromVehicleClass.articulated18m) {
            // Peak trunk runs deploy 18m articulated buses (max 120); off-peak deploy 12m solo (90).
            if (isPeakHour || occupancy.loadPercent >= 62) {
              vehicleClass = MarpromVehicleClass.articulated18m;
              capacity = 120;
            } else {
              vehicleClass = MarpromVehicleClass.solo12m;
              capacity = 90;
            }
          } else {
            vehicleClass = MarpromVehicleClass.solo12m;
            capacity = line.maxCapacity.clamp(85, 95);
          }

          final seatedCapacity = vehicleClass.defaultSeatedCapacity;
          final standingCapacity =
              (capacity - seatedCapacity).clamp(1, capacity);
          final passengerCount =
              ((occupancy.loadPercent / 100.0) * capacity)
                  .round()
                  .clamp(1, capacity);

          // Riders fill seats first (realistic urban behavior) before standing room fills.
          final seatedTarget = occupancy.loadPercent <= 45
              ? math.min(passengerCount, (seatedCapacity * 0.88).round())
              : math.min(passengerCount, seatedCapacity);
          final seatedCount = seatedTarget.clamp(0, seatedCapacity);
          final standingCount =
              (passengerCount - seatedCount).clamp(0, standingCapacity);

          final isElectric = line.isElectricDefault ||
              ((line.id == 'G1' || line.id == 'G2') &&
                  trip.tripId.hashCode.isEven);
          final vehicleModel = switch (vehicleClass) {
            MarpromVehicleClass.midibus9m => 'IVECO E-WAY 9.5m (E)',
            MarpromVehicleClass.articulated18m => isElectric
                ? "MAN Lion's City 18E (Zgibni)"
                : "MAN Lion's City 18G (Zgibni)",
            MarpromVehicleClass.solo12m => isElectric
                ? (line.id == 'G5'
                    ? 'IVECO E-WAY 12m (E)'
                    : "MAN Lion's City 12E")
                : (line.isLowFloor
                    ? "MAN Lion's City 12"
                    : 'IVECO Crossway High-Floor'),
          };

          buses.add(
            BusPosition(
              vehicleId: 'MB-${line.code}-${trip.tripId.split('_').last}',
              lineId: line.id,
              lineCode: line.code,
              directionId: direction.id,
              directionName: direction.name,
              position: pos,
              progress: progress,
              speedKmh: double.parse(speedKmh.toStringAsFixed(1)),
              nextStopId: nextStopId,
              nextStopName: nextStopName,
              remainingStopsCount: direction.stopIds.length - nextIdx,
              etaToNextStopSeconds: etaSeconds,
              delaySeconds: delaySeconds,
              occupancy: occupancy.level,
              updatedAt: now,
              passengerCount: passengerCount,
              vehicleCapacity: capacity,
              loadPercent:
                  ((passengerCount / capacity) * 100).round().clamp(0, 100),
              vehicleModel: vehicleModel,
              isElectric: isElectric,
              vehicleClass: vehicleClass,
              seatedCount: seatedCount,
              standingCount: standingCount,
              seatedCapacity: seatedCapacity,
              standingCapacity: standingCapacity,
              isLowFloor: line.isLowFloor,
              hasWheelchairRamp: line.hasWheelchairRamp,
              hasWheelchairSpace: line.hasWheelchairSpace,
              hasAudioAnnouncements: line.hasAudioAnnouncements,
              headingDegrees: headingDegrees,
            ),
          );
        }
      }
    }
    return buses;
  }

  void _startTimerIfNeeded() {
    if (_disposed || !_useSimulatedLive) {
      scheduleMicrotask(_emitCurrent);
      return;
    }
    scheduleMicrotask(_emitCurrent);
    _timer ??= Timer.periodic(tickInterval, (_) => _emitCurrent());
  }

  void _stopTimerIfNoListeners() {
    if (!_controller.hasListener) {
      _stopTimer();
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _emitCurrent() {
    if (_disposed || _controller.isClosed) return;
    _controller.add(snapshotAt(_clock()));
  }

  /// Cancels any active simulation timers and closes the telemetry stream.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopTimer();
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
