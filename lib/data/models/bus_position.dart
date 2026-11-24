//**********************************************
// BusPosition telemetry & accessibility model *
//**********************************************

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/widgets/status_chip.dart';

import 'bus_line.dart';
import 'occupancy.dart';

/// Snapshot of an active city bus moving along a line direction polyline.
@immutable
class BusPosition {
  /// Creates a [BusPosition] telemetry snapshot for a single active vehicle.
  const BusPosition({
    required this.vehicleId,
    required this.lineId,
    required this.lineCode,
    required this.directionId,
    required this.directionName,
    required this.position,
    required this.progress,
    required this.speedKmh,
    required this.nextStopId,
    required this.nextStopName,
    required this.remainingStopsCount,
    required this.etaToNextStopSeconds,
    required this.delaySeconds,
    required this.occupancy,
    required this.updatedAt,
    this.passengerCount = 24,
    this.vehicleCapacity = 90,
    this.loadPercent = 27,
    this.vehicleModel = "MAN Lion's City 12",
    this.isElectric = false,
    this.vehicleClass = MarpromVehicleClass.solo12m,
    this.seatedCount = 18,
    this.standingCount = 6,
    this.seatedCapacity = 30,
    this.standingCapacity = 60,
    this.isLowFloor = true,
    this.hasWheelchairRamp = true,
    this.hasWheelchairSpace = true,
    this.hasAudioAnnouncements = true,
    this.headingDegrees = 0.0,
  });

  /// Unique vehicle or active trip identifier.
  final String vehicleId;

  /// Bus line identifier.
  final String lineId;

  /// Short public line code.
  final String lineCode;

  /// Active direction ID along the route.
  final String directionId;

  /// Human-readable direction label.
  final String directionName;

  /// Current interpolated geographic coordinate along the route polyline.
  final LatLng position;

  /// Normalized route progress in the range `0.0` to `1.0`.
  final double progress;

  /// Current estimated speed in km/h.
  final double speedKmh;

  /// ID of the upcoming stop ahead of the vehicle.
  final String nextStopId;

  /// Name of the upcoming stop ahead of the vehicle.
  final String nextStopName;

  /// Number of stops remaining until the terminal stop (including [nextStopId]).
  final int remainingStopsCount;

  /// Estimated seconds until arriving at [nextStopId].
  final int etaToNextStopSeconds;

  /// Current delay in seconds relative to schedule.
  final int delaySeconds;

  /// Current passenger crowding level.
  final BusOccupancyLevel occupancy;

  /// Timestamp when this telemetry snapshot was produced.
  final DateTime updatedAt;

  /// Estimated number of passengers currently aboard this vehicle (<= [vehicleCapacity] <= 120).
  final int passengerCount;

  /// Rated passenger capacity (seated + standing) of this vehicle (capped <= 120).
  final int vehicleCapacity;

  /// Load percentage (`0..100`) derived from Automatic Passenger Counting telemetry.
  final int loadPercent;

  /// Fleet vehicle model operating this run (e.g. `Iveco E-Way 12m`).
  final String vehicleModel;

  /// Whether this vehicle is a zero-emission battery-electric bus.
  final bool isElectric;

  /// Marprom vehicle chassis class (`midibus9m`, `solo12m`, or `articulated18m`).
  final MarpromVehicleClass vehicleClass;

  /// Current number of seated passengers aboard.
  final int seatedCount;

  /// Current number of standing passengers aboard.
  final int standingCount;

  /// Rated number of seats in this vehicle.
  final int seatedCapacity;

  /// Rated standing room capacity in this vehicle.
  final int standingCapacity;

  /// Whether this bus is low-floor (*nizkopodni*).
  final bool isLowFloor;

  /// Whether this bus has a wheelchair boarding ramp (*izvlečna klančina*).
  final bool hasWheelchairRamp;

  /// Whether this bus has a dedicated wheelchair bay opposite middle doors.
  final bool hasWheelchairSpace;

  /// Whether this bus provides audio stop announcements (*zvočne najave*).
  final bool hasAudioAnnouncements;

  /// Travel compass heading in degrees (`0..360`).
  final double headingDegrees;

  /// True only when the bus is low-floor and equipped with ramp + wheelchair bay.
  bool get isWheelchairAccessible =>
      isLowFloor && hasWheelchairRamp && hasWheelchairSpace;

  /// Semantic status derived from [delaySeconds] thresholds.
  TransitStatusType get status {
    if (delaySeconds < -60) return TransitStatusType.early;
    if (delaySeconds <= 120) return TransitStatusType.onTime;
    return TransitStatusType.late;
  }

  /// Serializes this snapshot for Cloud Firestore `active_buses` collection
  /// matching the strict field allowlist in `firestore.rules`.
  Map<String, dynamic> toFirestore() => {
        'vehicleId': vehicleId,
        'lineId': lineId,
        'lineCode': lineCode,
        'directionId': directionId,
        'directionName': directionName,
        'lat': position.latitude,
        'lng': position.longitude,
        'progress': progress,
        'speedKmh': speedKmh,
        'nextStopId': nextStopId,
        'nextStopName': nextStopName,
        'remainingStopsCount': remainingStopsCount,
        'etaToNextStopSeconds': etaToNextStopSeconds,
        'delaySeconds': delaySeconds,
        'occupancy': occupancy.name,
        'passengerCount': passengerCount.clamp(0, 120),
        'vehicleCapacity': vehicleCapacity.clamp(1, 120),
        'loadPercent': loadPercent.clamp(0, 100),
        'vehicleModel': vehicleModel,
        'isElectric': isElectric,
        'isLowFloor': isLowFloor,
        'hasWheelchairRamp': hasWheelchairRamp,
        'hasWheelchairSpace': hasWheelchairSpace,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}
