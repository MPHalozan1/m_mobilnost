//**********************************************
// Google Routes Bus-Line Road Geometry Cache  *
//**********************************************

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/bus_line.dart';
import '../../data/models/trip_plan.dart';
import '../../data/seed/seed_lines.dart';
import '../../data/seed/seed_stops.dart';
import '../../data/seed/seed_timetables.dart';
import '../maps/google_web_views.dart';
import '../utils/geo.dart';
import 'google_routes_service.dart';

//**********************************************
// Road-snap overrides for off-street stops    *
//**********************************************

/// Coordinates snapped to nearby bus lanes for stops whose map pin sits inside
/// a building or pedestrian plaza (prevents parking-lot loops in Google DRIVE).
const Map<String, LatLng> _busStopRoadSnapOverrides = {
  'europark': LatLng(46.55451, 15.65147),
};

//**********************************************
// Polyline slicing & leg road-path resolver   *
//**********************************************

/// Slices the nearest contiguous segment between [start] and [end] along a road [polyline].
List<LatLng> slicePolylineBetweenPoints(
  List<LatLng> polyline,
  LatLng start,
  LatLng end,
) {
  if (polyline.length < 2) {
    return polyline;
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
  if (result.length < 2) {
    return polyline;
  }
  return result;
}

/// Resolves the drawable road path of a planned [leg], preferring live Google
/// Routes cached polylines when available and preserving `leg.polyline` otherwise.
List<LatLng> roadPathForBusLeg(
  TripLeg leg, {
  Map<String, BusLine>? linesById,
  Map<String, GoogleRouteResult>? cachedGoogleRoutes,
}) {
  if (leg.type != TripLegType.bus) return leg.polyline;

  // Prefer live Google Routes cached road trajectory when loaded
  if (cachedGoogleRoutes != null &&
      leg.lineId != null &&
      leg.polyline.length >= 2) {
    final key = leg.directionId != null
        ? '${leg.lineId}|${leg.directionId}'
        : '${leg.lineId}|${leg.lineId}_out';
    final liveRoute = cachedGoogleRoutes[key];
    if (liveRoute != null &&
        liveRoute.isLiveApi &&
        liveRoute.polylinePoints.length >= 2) {
      final sliced = slicePolylineBetweenPoints(
        liveRoute.polylinePoints,
        leg.polyline.first,
        leg.polyline.last,
      );
      if (sliced.length >= 2) return sliced;
    }
  }

  final match = matchBusLegToLine(leg, linesById: linesById);
  if (match == null) return leg.polyline;
  final path = match.$1.roadPathBetween(match.$2, match.$3);
  return path.length >= 2 ? path : leg.polyline;
}

/// Finds the [LineDirection] and stop indices (`fromIdx < toIdx`) a bus [leg]
/// rides on, or null when the line or its stops are unknown.
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

/// Builds road-following geometry for a single Marprom line direction
/// (`'lineId|directionId'`) using Google Routes API v2 + Firestore caching.
final routeGeometryProvider =
    FutureProvider.family<List<LatLng>, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length != 2) return const <LatLng>[];
  final line = seedLinesById[parts.first];
  final direction = line?.directionById(parts.last);
  if (line == null || direction == null || direction.stopIds.length < 2) {
    return const <LatLng>[];
  }
  final loaded = await ref
      .read(googleLineRoutesProvider.notifier)
      .ensureLineDirectionLoaded(line, direction);
  return loaded?.polylinePoints ?? const <LatLng>[];
});

/// Builds route summary metrics from bundled geometry (used in unit tests).
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
/// In live execution, resolves each line direction via [GoogleRoutesService.computeBusLineRoadPath]
/// (`travelMode: DRIVE`, `via: true` waypoints chunked <= 25, cached in memory
/// and Cloud Firestore `bus_lines/{lineId}.cachedRoadPolyline`).
class GoogleLineRoutesNotifier
    extends StateNotifier<Map<String, GoogleRouteResult>> {
  /// Creates a [GoogleLineRoutesNotifier].
  GoogleLineRoutesNotifier({
    this.routesService,
  }) : super(isFlutterTestEnvironment ? _allSeedRoutes() : const {});

  /// Active [GoogleRoutesService] used for live Google Drive road geometry.
  final GoogleRoutesService? routesService;
  final Map<String, Future<GoogleRouteResult?>> _inflight = {};

  static Map<String, GoogleRouteResult> _allSeedRoutes() => {
        for (final line in seedLines)
          for (final dir in line.directions)
            if (dir.polyline.length >= 2)
              '${line.id}|${dir.id}': bundledLineRouteResult(dir),
      };

  static List<LatLng> _orderedStopsForGoogleDrive(LineDirection direction) {
    return [
      for (var i = 0; i < direction.stopIds.length; i++)
        _busStopRoadSnapOverrides[direction.stopIds[i]] ??
            seedStopsById[direction.stopIds[i]]?.position ??
            direction.polyline[i],
    ];
  }

  /// Ensures road-following Google Routes geometry for [line] & [direction]
  /// is loaded and cached in memory + Firestore.
  Future<GoogleRouteResult?> ensureLineDirectionLoaded(
    BusLine line,
    LineDirection direction, {
    bool forceInTests = false,
  }) async {
    final key = '${line.id}|${direction.id}';
    final existing = state[key];
    if (!forceInTests &&
        existing != null &&
        existing.polylinePoints.length >= 2) {
      return existing;
    }

    if (isFlutterTestEnvironment && !forceInTests) {
      final bundled = bundledLineRouteResult(direction);
      if (mounted) state = {...state, key: bundled};
      return bundled;
    }

    final service = routesService;
    if (service == null || (isFlutterTestEnvironment && !forceInTests)) {
      if (direction.polyline.length < 2) return null;
      final bundled = bundledLineRouteResult(direction);
      if (mounted) state = {...state, key: bundled};
      return bundled;
    }

    return _inflight[key] ??= () async {
      try {
        final orderedStops = _orderedStopsForGoogleDrive(direction);
        final roadPoints = await service.computeBusLineRoadPath(
          lineId: line.id,
          orderedStops: orderedStops,
          line: line,
          cacheKey: key,
        );
        if (roadPoints.length < 2) return null;

        final offsets = computeStopOffsetsSeconds(direction);
        final schedSec = offsets.isEmpty ? 600 : offsets.last;
        final result = GoogleRouteResult(
          distanceMeters: GeoUtils.polylineLengthMeters(roadPoints).round(),
          durationSeconds: schedSec,
          rawDuration: '${schedSec}s',
          polylinePoints: roadPoints,
          isLiveApi: true,
          encodedPolyline: GoogleRoutesService.encodeGooglePolyline(roadPoints),
        );
        if (mounted) {
          state = {...state, key: result};
        }
        return result;
      } catch (_) {
        // Never fabricate straight lines if Google Routes API fails
        return null;
      } finally {
        _inflight.remove(key);
      }
    }();
  }

  /// Ensures both directions of [lineId] are loaded via Google Routes API v2.
  Future<void> ensureLineLoaded(
    String lineId, {
    bool forceInTests = false,
  }) async {
    final line = seedLinesById[lineId];
    if (line == null) return;
    for (final dir in line.directions) {
      await ensureLineDirectionLoaded(
        line,
        dir,
        forceInTests: forceInTests,
      );
    }
  }

  /// Pre-warms active Marprom line road geometries gently in small batches.
  Future<void> warmAllActiveLines({
    Iterable<String>? lineIds,
    bool forceInTests = false,
  }) async {
    final targets =
        (lineIds ?? [for (final line in seedLines) line.id]).toList();
    // Load outbound direction first for instant map coverage, in batches of 4
    for (var i = 0; i < targets.length; i += 4) {
      final batch = targets.skip(i).take(4);
      await Future.wait([
        for (final id in batch)
          if (seedLinesById[id] != null &&
              seedLinesById[id]!.directions.isNotEmpty)
            ensureLineDirectionLoaded(
              seedLinesById[id]!,
              seedLinesById[id]!.directions.first,
              forceInTests: forceInTests,
            ),
      ]);
    }
  }
}

/// Provides the cached Google Routes road geometries across all 19 Marprom lines.
final googleLineRoutesProvider = StateNotifierProvider<
    GoogleLineRoutesNotifier,
    Map<String, GoogleRouteResult>>((ref) {
  return GoogleLineRoutesNotifier(
    routesService: ref.watch(googleRoutesServiceProvider),
  );
});
