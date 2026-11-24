//**********************************************
// BusLine, LineDirection & Vehicle Classes    *
//**********************************************

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

//**********************************************
// Marprom vehicle class capacities (<= 120)   *
//**********************************************

/// Official Marprom Maribor bus chassis classes with realistic passenger limits.
/// No vehicle in the Marprom fleet exceeds 120 total passengers.
enum MarpromVehicleClass {
  /// 9.5m electric/city midibus (e.g. IVECO E-WAY 9.5m on P7, P17, P19).
  midibus9m(
    label: 'Midibus 9.5m',
    defaultMaxCapacity: 64,
    defaultSeatedCapacity: 18,
    defaultStandingCapacity: 46,
  ),

  /// 12m standard solo city bus (e.g. IVECO E-WAY 12m, MAN Lion's City 12).
  solo12m(
    label: 'Mestni solo 12m',
    defaultMaxCapacity: 90,
    defaultSeatedCapacity: 30,
    defaultStandingCapacity: 60,
  ),

  /// 18m articulated ("zgibni") city bus on high-demand trunk routes (hard cap 120).
  articulated18m(
    label: 'Zgibni mestni 18m',
    defaultMaxCapacity: 120,
    defaultSeatedCapacity: 44,
    defaultStandingCapacity: 76,
  );

  const MarpromVehicleClass({
    required this.label,
    required this.defaultMaxCapacity,
    required this.defaultSeatedCapacity,
    required this.defaultStandingCapacity,
  });

  /// Slovenian vehicle class name shown in fleet details.
  final String label;

  /// Realistic maximum passenger capacity (seated + standing).
  final int defaultMaxCapacity;

  /// Standard seated passenger count.
  final int defaultSeatedCapacity;

  /// Standard standing passenger count.
  final int defaultStandingCapacity;
}

//**********************************************
// LineDirection & BusLine domain models       *
//**********************************************

/// One travel direction of a [BusLine] with ordered stops and route polyline.
@immutable
class LineDirection {
  /// Creates a [LineDirection] linking ordered stops to a map polyline.
  const LineDirection({
    required this.id,
    required this.name,
    required this.terminalStopId,
    required this.stopIds,
    required this.polyline,
    this.roadPolyline,
    this.roadSegments = const [],
  });

  /// Unique direction ID (for example `G6_out` or `G6_in`).
  final String id;

  /// Display direction label (typically `Origin - Terminus`).
  final String name;

  /// Final destination stop ID for this direction.
  final String terminalStopId;

  /// Ordered sequence of stop IDs visited from origin to terminus.
  final List<String> stopIds;

  /// Stop waypoint coordinates used as input to Google Routes API v2.
  final List<LatLng> polyline;

  /// Full road-following route geometry for this direction.
  ///
  /// Seeded directions fill this with the bundled [roadSegments] joined
  /// together (see [routePolyline]); it is null only for directions built
  /// without road geometry.
  final List<LatLng>? roadPolyline;

  /// Road-following geometry between consecutive stops.
  ///
  /// Segment `i` runs along the road from stop `i` to stop `i + 1`, so a
  /// complete list has `stopIds.length - 1` entries. Missing or degenerate
  /// (fewer than two points) entries fall back to the straight line between
  /// the two stops; see [segment].
  final List<List<LatLng>> roadSegments;

  /// Number of stop-to-stop segments in this direction.
  int get segmentCount => polyline.length < 2 ? 0 : polyline.length - 1;

  /// Road geometry from stop [index] to stop `index + 1`.
  ///
  /// Returns the bundled road segment when present, otherwise the straight
  /// two-point segment between the stops. Returns an empty list when [index]
  /// is out of range.
  List<LatLng> segment(int index) {
    if (index < 0 || index >= segmentCount) return const [];
    if (index < roadSegments.length && roadSegments[index].length >= 2) {
      return roadSegments[index];
    }
    return [polyline[index], polyline[index + 1]];
  }

  /// Full route geometry to draw on maps: [roadPolyline] when set, otherwise
  /// all [segment]s concatenated without duplicated joint points (cached).
  List<LatLng> get routePolyline =>
      roadPolyline ??
      (_routePolylineCache[this] ??= List<LatLng>.unmodifiable(
        roadPathBetween(0, polyline.length - 1),
      ));

  /// Road-following path from stop [fromIdx] to stop [toIdx] (inclusive).
  ///
  /// Indices are clamped to the valid stop range. When `fromIdx >= toIdx`
  /// the result is the single stop point at [fromIdx].
  List<LatLng> roadPathBetween(int fromIdx, int toIdx) {
    if (polyline.isEmpty) return const [];
    final last = polyline.length - 1;
    final from = fromIdx.clamp(0, last);
    final to = toIdx.clamp(0, last);
    if (from >= to) return [polyline[from]];

    return joinSegments([for (var i = from; i < to; i++) segment(i)]);
  }

  /// Joins [segments] into one path without duplicated joint points.
  static List<LatLng> joinSegments(List<List<LatLng>> segments) {
    final path = <LatLng>[];
    for (final points in segments) {
      for (var p = 0; p < points.length; p++) {
        if (p == 0 && path.isNotEmpty && path.last == points.first) continue;
        path.add(points[p]);
      }
    }
    return path;
  }
}

final Expando<List<LatLng>> _routePolylineCache =
    Expando<List<LatLng>>('routePolyline');

/// Represents a Marprom city bus line with brand color, fleet class, and accessibility metadata.
@immutable
class BusLine {
  /// Creates a [BusLine] with two-way [directions] and realistic accessibility metadata.
  const BusLine({
    required this.id,
    required this.code,
    required this.name,
    required this.color,
    required this.directions,
    this.defaultVehicleClass = MarpromVehicleClass.solo12m,
    int? maxCapacity,
    bool isLowFloor = true,
    this.hasWheelchairRamp = true,
    this.hasWheelchairSpace = true,
    this.hasAudioAnnouncements = true,
    this.isElectricDefault = false,
  })  : maxCapacity = (maxCapacity ??
                (defaultVehicleClass == MarpromVehicleClass.midibus9m
                    ? 64
                    : defaultVehicleClass == MarpromVehicleClass.articulated18m
                        ? 120
                        : 90)) >
            120
            ? 120
            : (maxCapacity ??
                (defaultVehicleClass == MarpromVehicleClass.midibus9m
                    ? 64
                    : defaultVehicleClass == MarpromVehicleClass.articulated18m
                        ? 120
                        : 90)),
        isLowFloor = isLowFloor;

  /// Stable line identifier.
  final String id;

  /// Short public line code displayed on badges (for example `G1` or `P12`).
  final String code;

  /// Descriptive route name covering key terminals.
  final String name;

  /// Distinguishing line color used on badges and map polylines.
  final Color color;

  /// Available travel directions (typically outbound and inbound).
  final List<LineDirection> directions;

  /// Default Marprom chassis class assigned to this line.
  final MarpromVehicleClass defaultVehicleClass;

  /// Maximum realistic passenger capacity for this line's vehicles (capped <= 120).
  final int maxCapacity;

  /// Whether buses assigned to this line are low-floor (*nizkopodni avtobus*).
  final bool isLowFloor;

  /// Backwards-compatible alias for [isLowFloor].
  bool get isLowFloorDefault => isLowFloor;

  /// Whether buses on this line carry a deployable wheelchair ramp (*izvlečna klančina*).
  final bool hasWheelchairRamp;

  /// Whether buses on this line have a dedicated wheelchair bay opposite middle doors.
  final bool hasWheelchairSpace;

  /// Whether buses announce stops via audio (*zvočne najave postajališč*).
  final bool hasAudioAnnouncements;

  /// Whether this line primarily operates battery-electric vehicles.
  final bool isElectricDefault;

  /// True only when the bus is low-floor AND equipped with both a ramp and wheelchair bay.
  bool get isWheelchairAccessible =>
      isLowFloor && hasWheelchairRamp && hasWheelchairSpace;

  /// Whether this is a high-frequency main Marprom trunk line (`G1`–`G6`).
  bool get isMainTrunk => code.startsWith('G');

  /// Looks up a [LineDirection] by [directionId], returning null if absent.
  LineDirection? directionById(String directionId) {
    for (final direction in directions) {
      if (direction.id == directionId) return direction;
    }
    return null;
  }

  /// Serializes this [BusLine] metadata for Cloud Firestore `bus_lines` collection
  /// matching the strict field allowlist in `firestore.rules`.
  Map<String, dynamic> toFirestore({Map<String, String>? encodedPolylines}) => {
        'id': id,
        'code': code,
        'name': name,
        'colorHex':
            '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}',
        'maxCapacity': maxCapacity.clamp(1, 120),
        'isLowFloor': isLowFloor,
        'isLowFloorDefault': isLowFloor,
        'hasWheelchairRamp': hasWheelchairRamp,
        'hasWheelchairSpace': hasWheelchairSpace,
        'hasAudioAnnouncements': hasAudioAnnouncements,
        'isMainTrunk': isMainTrunk,
        'directions': [
          for (final dir in directions)
            {
              'id': dir.id,
              'name': dir.name,
              'terminalStopId': dir.terminalStopId,
              'stopIds': dir.stopIds,
              if (encodedPolylines != null &&
                  encodedPolylines['${id}|${dir.id}'] != null)
                'encodedPolyline': encodedPolylines['${id}|${dir.id}'],
            },
        ],
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

  /// Restores accessibility and capacity metadata overlaid from Firestore.
  static BusLine mergeFromFirestore(BusLine base, Map<String, dynamic> data) {
    final className = data['vehicleClass'] as String?;
    final vehicleClass = MarpromVehicleClass.values.firstWhere(
      (v) => v.name == className,
      orElse: () => base.defaultVehicleClass,
    );
    final rawCap = (data['maxCapacity'] as num?)?.round() ?? base.maxCapacity;
    return BusLine(
      id: base.id,
      code: data['code'] as String? ?? base.code,
      name: data['name'] as String? ?? base.name,
      color: base.color,
      directions: base.directions,
      defaultVehicleClass: vehicleClass,
      maxCapacity: rawCap.clamp(1, 120),
      isLowFloor: data['isLowFloor'] as bool? ?? base.isLowFloor,
      hasWheelchairRamp:
          data['hasWheelchairRamp'] as bool? ?? base.hasWheelchairRamp,
      hasWheelchairSpace:
          data['hasWheelchairSpace'] as bool? ?? base.hasWheelchairSpace,
      hasAudioAnnouncements:
          data['hasAudioAnnouncements'] as bool? ?? base.hasAudioAnnouncements,
      isElectricDefault:
          data['isElectricDefault'] as bool? ?? base.isElectricDefault,
    );
  }
}
