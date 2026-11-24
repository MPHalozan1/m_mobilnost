// Resolves & caches Google Maps Routes API v2 street geometries for all 19 Marprom bus lines.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/bus_line.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/seed/seed_lines.dart';
import '../../data/simulation/bus_simulator.dart';
import '../accessibility/a11y_settings.dart';
import '../maps/google_web_views.dart';
import 'google_routes_service.dart';

const String _routeCachePrefix = 'marprom_groute_v3_';

/// Loads accurate drivable road geometry for a single seeded Marprom bus direction
/// (`'lineId|directionId'`) using Google Routes API v2 first, then OSRM, then dense fallback.
final routeGeometryProvider =
    FutureProvider.family<List<LatLng>, String>((ref, key) async {
  final cached = ref.read(googleLineRoutesProvider)[key];
  if (cached != null && cached.polylinePoints.length >= 2) {
    return cached.polylinePoints;
  }

  final parts = key.split('|');
  if (parts.length != 2) return const <LatLng>[];

  final line = seedLinesById[parts.first];
  final direction = line?.directionById(parts.last);
  if (line == null || direction == null || direction.polyline.length < 2) {
    return const <LatLng>[];
  }

  final fallback = _densify(direction.polyline);
  if (isFlutterTestEnvironment) {
    return fallback;
  }

  final liveResult = await ref
      .read(googleLineRoutesProvider.notifier)
      .ensureLineDirectionLoaded(line, direction);
  if (liveResult != null && liveResult.polylinePoints.length >= 2) {
    return liveResult.polylinePoints;
  }

  // Fallback to OSRM driving geometry if Google Routes API is unavailable or restricted.
  final coordinates = direction.polyline
      .map((point) => '${point.longitude},${point.latitude}')
      .join(';');
  final uri = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/$coordinates'
    '?overview=full&geometries=geojson&steps=false',
  );

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return fallback;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return fallback;

    final geometry =
        ((routes.first as Map<String, dynamic>)['geometry']
            as Map<String, dynamic>?)?['coordinates'] as List<dynamic>?;
    if (geometry == null || geometry.length < 2) return fallback;

    return [
      for (final coordinate in geometry)
        LatLng(
          (coordinate as List<dynamic>)[1] as double,
          coordinate[0] as double,
        ),
    ];
  } catch (_) {
    return fallback;
  }
});

/// Manages Google Maps Routes API (`computeRoutes`) road geometries & metrics for all
/// live Marprom bus lines, caching responses in [SharedPreferences] and pushing
/// street polylines into [BusSimulator].
class GoogleLineRoutesNotifier
    extends StateNotifier<Map<String, GoogleRouteResult>> {
  /// Creates a [GoogleLineRoutesNotifier] pre-populating from local cache if available.
  GoogleLineRoutesNotifier({
    required this._routesService,
    required this._simulator,
    this._prefs,
  }) : super(const {}) {
    _hydrateFromCache();
  }

  final GoogleRoutesService _routesService;
  final BusSimulator _simulator;
  final SharedPreferences? _prefs;
  final Set<String> _inFlight = {};
  bool _warmedAll = false;

  void _hydrateFromCache() {
    final prefs = _prefs;
    if (prefs == null) return;
    final restored = <String, GoogleRouteResult>{};
    final simMap = <String, List<LatLng>>{};

    for (final line in seedLines) {
      for (final dir in line.directions) {
        final key = '${line.id}|${dir.id}';
        final raw = prefs.getString('$_routeCachePrefix$key');
        if (raw == null || raw.isEmpty) continue;
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final encoded = decoded['encodedPolyline'] as String?;
          final distanceMeters = (decoded['distanceMeters'] as num?)?.round();
          final rawDuration = decoded['rawDuration'] as String?;
          final isLive = decoded['isLiveApi'] as bool? ?? false;
          if (encoded != null &&
              encoded.isNotEmpty &&
              distanceMeters != null &&
              rawDuration != null) {
            final points = GoogleRoutesService.decodeGooglePolyline(encoded);
            if (points.length >= 2) {
              restored[key] = GoogleRouteResult(
                distanceMeters: distanceMeters,
                durationSeconds:
                    GoogleRoutesService.parseDurationSeconds(rawDuration),
                rawDuration: rawDuration,
                polylinePoints: points,
                isLiveApi: isLive,
                encodedPolyline: encoded,
              );
              simMap[key] = points;
            }
          }
        } catch (_) {
          // Ignore malformed cache entries.
        }
      }
    }

    if (restored.isNotEmpty) {
      state = restored;
      _simulator.setGoogleRouteGeometries(simMap);
    }
  }

  /// Resolves a single [line] & [direction] via Google Routes API v2 (`computeRoutes`)
  /// and caches it locally + inside [BusSimulator].
  Future<GoogleRouteResult?> ensureLineDirectionLoaded(
    BusLine line,
    LineDirection direction, {
    bool forceInTests = false,
  }) async {
    final key = '${line.id}|${direction.id}';
    final existing = state[key];
    if (existing != null && existing.isLiveApi) {
      return existing;
    }
    if (isFlutterTestEnvironment && !forceInTests) {
      return existing;
    }
    if (_inFlight.contains(key)) {
      return existing;
    }
    if (direction.polyline.length < 2) return null;

    _inFlight.add(key);
    try {
      final result = await _routesService.computeRouteByCoordinates(
        origin: direction.polyline.first,
        destination: direction.polyline.last,
        intermediates: direction.polyline.length > 2
            ? direction.polyline.sublist(1, direction.polyline.length - 1)
            : const [],
        includePolyline: true,
      );

      final resolvedPoints = result.polylinePoints.length >= 2
          ? result.polylinePoints
          : _densify(direction.polyline);
      final normalized = GoogleRouteResult(
        distanceMeters: result.distanceMeters,
        durationSeconds: result.durationSeconds,
        rawDuration: result.rawDuration,
        polylinePoints: resolvedPoints,
        isLiveApi: result.isLiveApi,
        encodedPolyline: result.encodedPolyline ??
            GoogleRoutesService.encodeGooglePolyline(resolvedPoints),
      );

      state = {...state, key: normalized};

      if (normalized.isLiveApi && resolvedPoints.length >= 2) {
        _simulator.setGoogleRouteGeometries({key: resolvedPoints});
        await _persistEntry(key, normalized);
      }

      return normalized;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Hydrates Google Routes API street polylines for both directions of [lineId].
  Future<void> ensureLineLoaded(
    String lineId, {
    bool forceInTests = false,
  }) async {
    final line = seedLinesById[lineId];
    if (line == null) return;
    if (isFlutterTestEnvironment && !forceInTests) return;

    await Future.wait([
      for (final dir in line.directions)
        ensureLineDirectionLoaded(line, dir, forceInTests: forceInTests),
    ]);
  }

  /// Warms Google Routes geometries for priority / all active lines without blocking UI.
  Future<void> warmAllActiveLines({
    Iterable<String>? lineIds,
    bool forceInTests = false,
  }) async {
    if (isFlutterTestEnvironment && !forceInTests) return;
    if (_warmedAll && lineIds == null) return;
    if (lineIds == null) _warmedAll = true;

    final targets = lineIds?.toList(growable: false) ??
        [for (final line in seedLines) line.id];

    // Hydrate in batches of 3 to avoid saturating browser/mobile connections.
    for (var i = 0; i < targets.length; i += 3) {
      final batch = targets.skip(i).take(3);
      await Future.wait([
        for (final id in batch)
          ensureLineLoaded(id, forceInTests: forceInTests),
      ]);
    }
  }

  Future<void> _persistEntry(String key, GoogleRouteResult result) async {
    final prefs = _prefs;
    if (prefs == null || result.encodedPolyline == null) return;
    await prefs.setString(
      '$_routeCachePrefix$key',
      jsonEncode({
        'distanceMeters': result.distanceMeters,
        'rawDuration': result.rawDuration,
        'encodedPolyline': result.encodedPolyline,
        'isLiveApi': result.isLiveApi,
      }),
    );
  }
}

/// Provides live-resolved Google Maps Routes geometries across all 19 Marprom lines.
final googleLineRoutesProvider = StateNotifierProvider<
    GoogleLineRoutesNotifier, Map<String, GoogleRouteResult>>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    prefs = null;
  }
  return GoogleLineRoutesNotifier(
    routesService: ref.watch(googleRoutesServiceProvider),
    simulator: ref.watch(busSimulatorProvider),
    prefs: prefs,
  );
});

List<LatLng> _densify(List<LatLng> stops) {
  if (stops.length < 2) return List<LatLng>.from(stops);
  final result = <LatLng>[];
  for (var i = 0; i < stops.length - 1; i++) {
    final from = stops[i];
    final to = stops[i + 1];
    if (i == 0) result.add(from);
    for (var step = 1; step <= 8; step++) {
      final t = step / 8;
      result.add(
        LatLng(
          from.latitude + (to.latitude - from.latitude) * t,
          from.longitude + (to.longitude - from.longitude) * t,
        ),
      );
    }
  }
  return result;
}
