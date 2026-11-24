//**********************************************
// Bundled bus-line road geometry service      *
//**********************************************

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/bus_line.dart';
import '../../data/models/trip_plan.dart';
import '../../data/seed/seed_lines.dart';
import '../../data/seed/seed_timetables.dart';
import '../utils/geo.dart';
import 'google_routes_service.dart';

//**********************************************
// Polyline slicing & routeGeometryProvider    *
//**********************************************

/// Slices the nearest contiguous segment between [start] and [end] along a road [polyline].
List<LatLng> slicePolylineBetweenPoints(
  List<LatLng> polyline,
  LatLng start,
  LatLng end,
) {
  if (polyline.length < 2) {
    return [start, end];
  }

  var startIdx = 0;
  var endIdx = polyline.length - 1;
  var bestStartDist = double.infinity;
  var bestEndDist = double.infinity;

  for (var i = 0; i < polyline.length; i++) {
    final dStart = GeoUtils.haversineMeters(polyline[i], start);
    if (dStart < bestStartDist) {
      bestStartDist = dStart;
      startIdx = i;
    }
    final dEnd = GeoUtils.haversineMeters(polyline[i], end);
    if (dEnd < bestEndDist) {
      bestEndDist = dEnd;
      endIdx = i;
    }
  }

  final segment = startIdx <= endIdx
      ? polyline.sublist(startIdx, endIdx + 1)
      : polyline.sublist(endIdx, startIdx + 1).reversed.toList(growable: true);

  final result = List<LatLng>.from(segment);
  if (result.isEmpty) {
    return [start, end];
  }
  if (GeoUtils.haversineMeters(result.first, start) > 25) {
    result.insert(0, start);
  }
  if (GeoUtils.haversineMeters(result.last, end) > 25) {
    result.add(end);
  }
  if (result.length < 2) {
    return [start, end];
  }
  return result;
}

/// Resolves the drawable path of a planned [leg].
///
/// A bus leg that rides a known Marprom line between two of its stops is
/// drawn along the bundled bus road geometry
/// ([LineDirection.roadPathBetween]); every other leg (walking, unknown
/// lines or stops) keeps its own [TripLeg.polyline].
List<LatLng> roadPathForBusLeg(
  TripLeg leg, {
  Map<String, BusLine>? linesById,
}) {
  if (leg.type != TripLegType.bus) return leg.polyline;
  final match = matchBusLegToLine(leg, linesById: linesById);
  if (match == null) return leg.polyline;
  final path = match.$1.roadPathBetween(match.$2, match.$3);
  return path.length >= 2 ? path : leg.polyline;
}

/// Finds the [LineDirection] and stop indices (`fromIdx < toIdx`) a bus [leg]
/// rides on, or null when the line or its stops are unknown.
///
/// Uses [TripLeg.directionId] when set, otherwise the first direction of the
/// line that visits the leg's from-stop before its to-stop.
(LineDirection, int, int)? matchBusLegToLine(
  TripLeg leg, {
  Map<String, BusLine>? linesById,
}) {
  final lineId = leg.lineId;
  final fromId = leg.fromStopId;
  final toId = leg.toStopId;
  if (lineId == null || fromId == null || toId == null) return null;
  final line = (linesById ?? seedLinesById)[lineId] ?? seedLinesById[lineId];
  if (line == null) return null;

  final preferred =
      leg.directionId != null ? line.directionById(leg.directionId!) : null;
  for (final dir in [?preferred, ...line.directions]) {
    final fromIdx = dir.stopIds.indexOf(fromId);
    if (fromIdx < 0) continue;
    final toIdx = dir.stopIds.indexOf(toId, fromIdx + 1);
    if (toIdx > fromIdx) return (dir, fromIdx, toIdx);
  }
  return null;
}

/// Bundled road-following geometry for a single Marprom line direction
/// (`'lineId|directionId'`). No network call.
final routeGeometryProvider =
    FutureProvider.family<List<LatLng>, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length != 2) return const <LatLng>[];
  final direction = seedLinesById[parts.first]?.directionById(parts.last);
  if (direction == null || direction.polyline.length < 2) {
    return const <LatLng>[];
  }
  return direction.routePolyline;
});

/// Builds the route summary (road geometry, road length, scheduled run time)
/// of [direction] from the bundled geometry. Not a live Google result.
GoogleRouteResult bundledLineRouteResult(LineDirection direction) {
  final points = direction.routePolyline;
  final offsets = computeStopOffsetsSeconds(direction);
  final seconds = offsets.isEmpty ? 0 : offsets.last;
  return GoogleRouteResult(
    distanceMeters: GeoUtils.polylineLengthMeters(points).round(),
    durationSeconds: seconds,
    rawDuration: '${seconds}s',
    polylinePoints: points,
    isLiveApi: false,
  );
}

//**********************************************
// GoogleLineRoutesNotifier                    *
//**********************************************

/// Road geometries & metrics (distance, scheduled duration) for every Marprom
/// line direction, keyed `'lineId|directionId'`.
///
/// Built from the bundled stop-to-stop road geometry; it used to request each
/// line from Google Routes API with all stops as waypoints, which drew loops
/// and zig-zags wherever a stop snapped to the wrong side of a road.
class GoogleLineRoutesNotifier
    extends StateNotifier<Map<String, GoogleRouteResult>> {
  /// Creates a [GoogleLineRoutesNotifier] pre-populated with all seed lines.
  GoogleLineRoutesNotifier() : super(_allSeedRoutes());

  static Map<String, GoogleRouteResult> _allSeedRoutes() => {
        for (final line in seedLines)
          for (final dir in line.directions)
            if (dir.polyline.length >= 2)
              '${line.id}|${dir.id}': bundledLineRouteResult(dir),
      };

  /// Returns the bundled route of [line] & [direction], adding it to the
  /// state when it is not a seed line yet.
  Future<GoogleRouteResult?> ensureLineDirectionLoaded(
    BusLine line,
    LineDirection direction, {
    bool forceInTests = false,
  }) async {
    final key = '${line.id}|${direction.id}';
    final existing = state[key];
    if (existing != null) return existing;
    if (direction.polyline.length < 2) return null;
    final result = bundledLineRouteResult(direction);
    if (mounted) state = {...state, key: result};
    return result;
  }

  /// Ensures both directions of [lineId] are available.
  Future<void> ensureLineLoaded(
    String lineId, {
    bool forceInTests = false,
  }) async {
    final line = seedLinesById[lineId];
    if (line == null) return;
    for (final dir in line.directions) {
      await ensureLineDirectionLoaded(line, dir);
    }
  }

  /// Ensures the routes of [lineIds] (or all seed lines) are available.
  Future<void> warmAllActiveLines({
    Iterable<String>? lineIds,
    bool forceInTests = false,
  }) async {
    for (final id in lineIds ?? [for (final line in seedLines) line.id]) {
      await ensureLineLoaded(id);
    }
  }
}

/// Provides the bundled road geometries across all 19 Marprom lines.
final googleLineRoutesProvider = StateNotifierProvider<
    GoogleLineRoutesNotifier,
    Map<String, GoogleRouteResult>>((ref) => GoogleLineRoutesNotifier());
