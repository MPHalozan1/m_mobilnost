//**********************************************
// Trip planning models, sorting & transfers   *
//**********************************************

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/network/data_freshness.dart';

import 'bus_line.dart';
import 'occupancy.dart';

/// Specifies how target trip timing should be interpreted by the planner.
enum TripTimeMode {
  /// Plan a trip departing as soon as possible from now.
  leaveNow,

  /// Plan a trip departing at or after a chosen time.
  departAt,

  /// Plan a trip arriving at or before a chosen deadline.
  arriveBy,
}

/// Sorting strategy for multi-bus trip results.
enum TripSortMode {
  /// Rank by shortest total duration / earliest arrival.
  fastest,

  /// Rank by fewest bus transfers first, then shortest duration.
  fewestTransfers,
}

/// Identifies the travel mode of a single [TripLeg].
enum TripLegType {
  /// Pedestrian walking segment.
  walk,

  /// Marprom city bus ride segment.
  bus,
}

/// Detailed transfer breakdown between two consecutive bus legs.
@immutable
class TransferSummary {
  /// Creates a [TransferSummary].
  const TransferSummary({
    required this.alightingStopName,
    required this.boardingStopName,
    required this.fromLineCode,
    required this.toLineCode,
    required this.walkMeters,
    required this.walkMinutes,
    required this.waitMinutes,
    required this.arrivalAtTransfer,
    required this.departureFromTransfer,
    this.isTight = false,
  });

  /// Station where the rider exits the previous bus.
  final String alightingStopName;

  /// Station where the rider boards the connecting bus.
  final String boardingStopName;

  /// Line code of the arriving bus.
  final String fromLineCode;

  /// Line code of the connecting bus.
  final String toLineCode;

  /// Walking distance between transfer stops in meters (0 if same stop).
  final double walkMeters;

  /// Walking duration between transfer stops in minutes.
  final int walkMinutes;

  /// Waiting time at the transfer stop in minutes.
  final int waitMinutes;

  /// Arrival timestamp of the first bus at the transfer station.
  final DateTime arrivalAtTransfer;

  /// Departure timestamp of the connecting bus from the transfer station.
  final DateTime departureFromTransfer;

  /// True when transfer wait buffer is tight (<= 4 min).
  final bool isTight;
}

/// Represents one contiguous walking or bus leg within a [TripOption].
@immutable
class TripLeg {
  /// Creates a [TripLeg] with timing, geometry, and optional Marprom fleet metadata.
  const TripLeg({
    required this.type,
    required this.fromName,
    required this.toName,
    this.fromStopId,
    this.toStopId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.distanceMeters,
    this.lineId,
    this.lineCode,
    this.directionId,
    this.directionName,
    this.stopCount,
    this.intermediateStopIds = const [],
    this.polyline = const [],
    this.occupancy = BusOccupancyLevel.unknown,
    this.delaySeconds = 0,
    this.isAccessible = true,
    this.vehicleClass = MarpromVehicleClass.solo12m,
    this.vehicleModel,
    this.passengerCount,
    this.vehicleCapacity,
    this.seatedCount,
    this.seatedCapacity,
    this.standingCount,
    this.standingCapacity,
    this.loadPercent,
    this.isLowFloor = true,
    this.hasWheelchairRamp = true,
    this.hasWheelchairSpace = true,
    this.hasAudioAnnouncements = true,
    this.navigationInstructions = const [],
  });

  /// Whether this leg is walking or riding a bus.
  final TripLegType type;

  /// Origin label for this leg.
  final String fromName;

  /// Destination label for this leg.
  final String toName;

  /// Origin stop ID when starting at a bus stop.
  final String? fromStopId;

  /// Destination stop ID when ending at a bus stop.
  final String? toStopId;

  /// Scheduled or estimated leg start time.
  final DateTime startTime;

  /// Scheduled or estimated leg end time.
  final DateTime endTime;

  /// Leg duration in whole minutes.
  final int durationMinutes;

  /// Approximate leg distance in meters.
  final double distanceMeters;

  /// Line ID for bus legs.
  final String? lineId;

  /// Line code for bus legs.
  final String? lineCode;

  /// Direction ID for bus legs.
  final String? directionId;

  /// Direction label for bus legs.
  final String? directionName;

  /// Number of stops traversed on a bus leg.
  final int? stopCount;

  /// Ordered stop IDs traversed on a bus leg.
  final List<String> intermediateStopIds;

  /// Geographic road/walk polyline coordinates for map preview.
  final List<LatLng> polyline;

  /// Expected occupancy for bus legs.
  final BusOccupancyLevel occupancy;

  /// Delay in seconds applied to bus legs.
  final int delaySeconds;

  /// Whether this leg meets wheelchair accessibility criteria (low-floor + ramp + step-free stops).
  final bool isAccessible;

  /// Marprom vehicle chassis class for this bus leg.
  final MarpromVehicleClass vehicleClass;

  /// Optional fleet model name (e.g. `IVECO E-WAY 12m`).
  final String? vehicleModel;

  /// Live estimated passenger count aboard (<= 120).
  final int? passengerCount;

  /// Realistic vehicle capacity (64 midibus, 85-95 solo, 120 articulated).
  final int? vehicleCapacity;

  /// Current seated passenger count.
  final int? seatedCount;

  /// Maximum seated capacity.
  final int? seatedCapacity;

  /// Current standing passenger count.
  final int? standingCount;

  /// Maximum standing capacity.
  final int? standingCapacity;

  /// Live load percentage (`0..100`).
  final int? loadPercent;

  /// Low-floor (*nizkopodni*) vehicle flag.
  final bool isLowFloor;

  /// Deployable wheelchair ramp (*izvlečna klančina*) flag.
  final bool hasWheelchairRamp;

  /// Dedicated wheelchair bay flag.
  final bool hasWheelchairSpace;

  /// Audio stop announcement flag.
  final bool hasAudioAnnouncements;

  /// Optional turn-by-turn instruction lines returned by Google Routes API v2.
  final List<String> navigationInstructions;

  /// True when live occupancy exceeds 85% or occupancy level is full.
  bool get isCrowdedOrFull =>
      (loadPercent != null && loadPercent! > 85) ||
      occupancy == BusOccupancyLevel.full;

  /// Returns a copy with selected fields replaced.
  TripLeg copyWith({
    List<LatLng>? polyline,
    BusOccupancyLevel? occupancy,
    int? delaySeconds,
    bool? isAccessible,
    MarpromVehicleClass? vehicleClass,
    String? vehicleModel,
    int? passengerCount,
    int? vehicleCapacity,
    int? seatedCount,
    int? seatedCapacity,
    int? standingCount,
    int? standingCapacity,
    int? loadPercent,
    bool? isLowFloor,
    bool? hasWheelchairRamp,
    bool? hasWheelchairSpace,
    bool? hasAudioAnnouncements,
    List<String>? navigationInstructions,
  }) {
    return TripLeg(
      type: type,
      fromName: fromName,
      toName: toName,
      fromStopId: fromStopId,
      toStopId: toStopId,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      distanceMeters: distanceMeters,
      lineId: lineId,
      lineCode: lineCode,
      directionId: directionId,
      directionName: directionName,
      stopCount: stopCount,
      intermediateStopIds: intermediateStopIds,
      polyline: polyline ?? this.polyline,
      occupancy: occupancy ?? this.occupancy,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      isAccessible: isAccessible ?? this.isAccessible,
      vehicleClass: vehicleClass ?? this.vehicleClass,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      passengerCount: passengerCount ?? this.passengerCount,
      vehicleCapacity: vehicleCapacity ?? this.vehicleCapacity,
      seatedCount: seatedCount ?? this.seatedCount,
      seatedCapacity: seatedCapacity ?? this.seatedCapacity,
      standingCount: standingCount ?? this.standingCount,
      standingCapacity: standingCapacity ?? this.standingCapacity,
      loadPercent: loadPercent ?? this.loadPercent,
      isLowFloor: isLowFloor ?? this.isLowFloor,
      hasWheelchairRamp: hasWheelchairRamp ?? this.hasWheelchairRamp,
      hasWheelchairSpace: hasWheelchairSpace ?? this.hasWheelchairSpace,
      hasAudioAnnouncements:
          hasAudioAnnouncements ?? this.hasAudioAnnouncements,
      navigationInstructions:
          navigationInstructions ?? this.navigationInstructions,
    );
  }
}

/// Complete door-to-door itinerary option returned by the trip planner.
@immutable
class TripOption {
  /// Creates a [TripOption] summarizing legs, transfers, and freshness.
  const TripOption({
    this.id = '',
    required this.totalMinutes,
    required this.walkMeters,
    required this.walkMinutes,
    required this.transferCount,
    required this.hasTightTransfer,
    this.tightTransferMinutes,
    required this.legs,
    required this.freshness,
    this.reliabilityNote,
    this.isGoogleTransit = false,
    this.accessibleAlternativeNote,
  });

  /// Stable option identifier for selection and keys.
  final String id;

  /// Total door-to-door duration in minutes.
  final int totalMinutes;

  /// Total walking distance across all walk legs in meters.
  final double walkMeters;

  /// Total walking time across all walk legs in minutes.
  final int walkMinutes;

  /// Number of bus-to-bus transfers (0 for direct routes).
  final int transferCount;

  /// Whether any transfer buffer is short enough to warrant a tight warning.
  final bool hasTightTransfer;

  /// Minimum transfer buffer in minutes when [hasTightTransfer] is true.
  final int? tightTransferMinutes;

  /// Ordered list of walk and bus legs from origin to destination.
  final List<TripLeg> legs;

  /// Freshness metadata of the underlying timetable/live data.
  final DataFreshness freshness;

  /// Optional note explaining tight connections or simulated delay risks.
  final String? reliabilityNote;

  /// True when computed live from Google Routes API v2 `TRANSIT`.
  final bool isGoogleTransit;

  /// Optional note shown when an accessible alternative replaced a non-accessible bus.
  final String? accessibleAlternativeNote;

  /// Start time of the first leg, or `DateTime.now()` if empty.
  DateTime get departureTime =>
      legs.isEmpty ? DateTime.now() : legs.first.startTime;

  /// Arrival time of the final leg, or `DateTime.now()` if empty.
  DateTime get arrivalTime =>
      legs.isEmpty ? DateTime.now() : legs.last.endTime;

  /// True when every leg in the itinerary is wheelchair-accessible.
  bool get isAccessible => legs.every((leg) => leg.isAccessible);

  /// Highest passenger load % across all bus legs, if known.
  int? get maxBusLoadPercent {
    int? best;
    for (final leg in legs) {
      if (leg.type != TripLegType.bus || leg.loadPercent == null) continue;
      if (best == null || leg.loadPercent! > best) best = leg.loadPercent!;
    }
    return best;
  }

  /// True if any bus leg exceeds 85% capacity or is marked full.
  bool get hasFullBusAlert =>
      legs.any((l) => l.type == TripLegType.bus && l.isCrowdedOrFull);

  /// Most significant delay delta across bus legs (`< -60` early, `> 120` late).
  int get primaryDelaySeconds {
    var best = 0;
    for (final leg in legs) {
      if (leg.type != TripLegType.bus) continue;
      if (leg.delaySeconds.abs() > best.abs()) best = leg.delaySeconds;
    }
    return best;
  }

  /// Extracts structured [TransferSummary] entries between consecutive bus legs.
  List<TransferSummary> get transfers {
    final result = <TransferSummary>[];
    for (var i = 0; i < legs.length; i++) {
      final curr = legs[i];
      if (curr.type != TripLegType.bus) continue;

      int prevBusIdx = -1;
      for (var j = i - 1; j >= 0; j--) {
        if (legs[j].type == TripLegType.bus) {
          prevBusIdx = j;
          break;
        }
      }
      if (prevBusIdx == -1) continue;

      final prevBus = legs[prevBusIdx];
      var walkMeters = 0.0;
      var walkMin = 0;
      for (var k = prevBusIdx + 1; k < i; k++) {
        if (legs[k].type == TripLegType.walk) {
          walkMeters += legs[k].distanceMeters;
          walkMin += legs[k].durationMinutes;
        }
      }
      final arriveAtXfer = prevBus.endTime.add(Duration(minutes: walkMin));
      final waitMin =
          curr.startTime.difference(arriveAtXfer).inMinutes.clamp(0, 120);
      result.add(
        TransferSummary(
          alightingStopName: prevBus.toName,
          boardingStopName: curr.fromName,
          fromLineCode: prevBus.lineCode ?? prevBus.lineId ?? '',
          toLineCode: curr.lineCode ?? curr.lineId ?? '',
          walkMeters: walkMeters,
          walkMinutes: walkMin,
          waitMinutes: waitMin,
          arrivalAtTransfer: prevBus.endTime,
          departureFromTransfer: curr.startTime,
          isTight: waitMin <= 4,
        ),
      );
    }
    return result;
  }
}
