//**********************************************
// Google Routes API v2 Service (Marprom)      *
// Handles real transit routes + road paths    *
// for all Marprom bus lines with caching      *
//**********************************************

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../data/models/bus_line.dart';
import '../../data/models/bus_position.dart';
import '../../data/models/bus_stop.dart';
import '../../data/models/trip_plan.dart';
import '../config/api_keys_config.dart';
import '../firebase/firestore_transit_service.dart';
import '../utils/distance.dart';
import 'marprom_route_fusion.dart';

//**********************************************
// GoogleRouteResult model                     *
//**********************************************

/// Parsed result returned by Google Routes API v2 (`computeRoutes`).
class GoogleRouteResult {
  /// Creates a [GoogleRouteResult].
  const GoogleRouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.rawDuration,
    required this.polylinePoints,
    required this.isLiveApi,
    this.encodedPolyline,
  });

  /// Total route distance in meters.
  final int distanceMeters;

  /// Parsed route travel duration in seconds.
  final int durationSeconds;

  /// Raw duration string from the Routes API (e.g. `"1094s"`).
  final String rawDuration;

  /// Decoded road geometry points along the computed route.
  final List<LatLng> polylinePoints;

  /// True when computed live by `routes.googleapis.com` or loaded from Firestore road cache.
  final bool isLiveApi;

  /// Raw Google encoded polyline string.
  final String? encodedPolyline;

  /// Distance formatted in kilometers or meters (e.g. `"10.5 km"`).
  String get formattedDistanceKm =>
      distanceMeters >= 1000
          ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
          : '$distanceMeters m';

  /// Duration formatted in minutes (e.g. `"18 min"`).
  String get formattedDurationMinutes {
    final mins = (durationSeconds / 60).round().clamp(1, 999);
    return '$mins min';
  }

  // Returns compact pretty-formatted summary of Google Routes payload metrics.
  String toPrettyJsonSummary() => const JsonEncoder.withIndent('  ').convert({
        'distanceMeters': distanceMeters,
        'duration': rawDuration,
        'isLiveApi': isLiveApi,
        'polylinePointsCount': polylinePoints.length,
      });
}

//**********************************************
// GoogleRoutesService implementation          *
//**********************************************

/// Unified cached client for Google Routes API v2 (`routes.googleapis.com`).
/// Zero straight-line fallbacks: throws [RoutesApiException] on failures.
class GoogleRoutesService {
  /// Creates a [GoogleRoutesService] with optional key, Firestore cache, and client.
  GoogleRoutesService({
    String? mapsApiKey,
    FirestoreTransitService? firestoreService,
    http.Client? client,
  })  : _mapsApiKeyOverride = mapsApiKey,
        _firestore = firestoreService,
        _client = client ?? http.Client();

  static const String _endpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  // Exact minimal field mask (NO spaces) for passenger TRANSIT routing
  static const String _transitFieldMask =
      'routes.duration,'
      'routes.distanceMeters,'
      'routes.polyline.encodedPolyline,'
      'routes.legs.duration,'
      'routes.legs.distanceMeters,'
      'routes.legs.startLocation,'
      'routes.legs.endLocation,'
      'routes.legs.steps.travelMode,'
      'routes.legs.steps.staticDuration,'
      'routes.legs.steps.distanceMeters,'
      'routes.legs.steps.polyline.encodedPolyline,'
      'routes.legs.steps.navigationInstruction,'
      'routes.legs.steps.transitDetails';

  // Exact minimal field mask (NO spaces) for bus line road geometry
  static const String _roadPathFieldMask =
      'routes.polyline.encodedPolyline,'
      'routes.distanceMeters,'
      'routes.duration';

  final String? _mapsApiKeyOverride;
  final FirestoreTransitService? _firestore;
  final http.Client _client;

  final Map<String, List<EnrichedTransitRoute>> _transitCache = {};
  final Map<String, List<LatLng>> _busLinePolylineCache = {};
  final Map<String, List<LatLng>> _walkPolylineCache = {};

  String get mapsApiKey => _mapsApiKeyOverride ?? ApiKeysConfig.googleMapsApiKey;

  //**********************************************
  // Compute optimal bus + walking trip routes   *
  //**********************************************

  /// Queries Google Routes API v2 `TRANSIT` (BUS only) for multi-bus and
  /// sidewalk-walking trips across Maribor, fusing results with Marprom data.
  Future<List<EnrichedTransitRoute>> computePassengerTransitRoutes({
    required LatLng origin,
    required LatLng destination,
    String transitPreference = 'FEWER_TRANSFERS', // or 'LESS_WALKING'
    String languageCode = 'sl',
    DateTime? departureTime,
    DateTime? arrivalTime,
    Map<String, BusLine>? marpromLinesByCode,
    List<BusStop>? marpromStops,
    List<BusPosition> liveFleet = const [],
    String originLabel = '',
    String destinationLabel = '',
  }) async {
    final timeBucket = departureTime != null
        ? '${departureTime.year}-${departureTime.month}-${departureTime.day}-${departureTime.hour}:${departureTime.minute ~/ 5}'
        : 'now';
    final cacheKey =
        '${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}|'
        '${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}|'
        '$transitPreference|$languageCode|$timeBucket';

    final cached = _transitCache[cacheKey];
    if (cached != null) return cached;

    // IMPORTANT: Never include top-level routingPreference when travelMode is TRANSIT
    final payload = <String, dynamic>{
      'origin': _latLngPayload(origin),
      'destination': _latLngPayload(destination),
      'travelMode': 'TRANSIT',
      'computeAlternativeRoutes': true,
      'languageCode': languageCode,
      'units': 'METRIC',
      'transitPreferences': {
        'allowedTravelModes': ['BUS'],
        'routingPreference': transitPreference,
      },
      if (departureTime != null)
        'departureTime': departureTime.toUtc().toIso8601String(),
      if (departureTime == null && arrivalTime != null)
        'arrivalTime': arrivalTime.toUtc().toIso8601String(),
    };

    late final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': mapsApiKey,
              'X-Goog-FieldMask': _transitFieldMask,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw RoutesApiException(0, e.toString(), isNetworkError: true);
    }

    if (res.statusCode != 200) {
      throw RoutesApiException(res.statusCode, res.body);
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final rawRoutes = (data['routes'] as List<dynamic>?) ?? const [];

    final refTime = departureTime ?? arrivalTime ?? DateTime.now();
    final enriched = <EnrichedTransitRoute>[
      for (var i = 0; i < rawRoutes.length; i++)
        if (rawRoutes[i] is Map<String, dynamic>)
          MarpromRouteFusion.enrichFromGoogleJson(
            rawRoutes[i] as Map<String, dynamic>,
            marpromLinesByCode: marpromLinesByCode,
            marpromStops: marpromStops,
            liveFleet: liveFleet,
            originLabel: originLabel,
            destinationLabel: destinationLabel,
            referenceTime: refTime,
            routeIndex: i,
          ),
    ];

    _transitCache[cacheKey] = enriched;
    return enriched;
  }

  //**********************************************
  // Compute road-following path for a bus line  *
  //**********************************************

  /// Computes a smooth road-following `DRIVE` polyline through [orderedStops]
  /// (`via: true` intermediates chunked safely in batches of 25), checking
  /// memory and Firestore `bus_lines/{lineId}.cachedRoadPolyline` first.
  Future<List<LatLng>> computeBusLineRoadPath({
    required String lineId,
    required List<LatLng> orderedStops,
    BusLine? line,
    String? cacheKey,
  }) async {
    final effectiveKey = cacheKey ?? lineId;
    final memCached = _busLinePolylineCache[effectiveKey];
    if (memCached != null && memCached.length >= 2) {
      return memCached;
    }

    // Check Firestore cachedRoadPolyline before spending Routes API quota
    final fs = _firestore;
    if (fs != null) {
      final stored = await fs.getCachedLinePolylines(lineId);
      final encoded = stored[effectiveKey] ?? stored[lineId];
      if (encoded != null && encoded.isNotEmpty) {
        final decoded = decodeEncodedPolyline(encoded);
        if (decoded.length >= 2) {
          _busLinePolylineCache[effectiveKey] = decoded;
          return decoded;
        }
      }
    }

    if (orderedStops.length < 2) return orderedStops;

    final fullPath = <LatLng>[];
    // Google Routes supports up to 25 intermediates; keep chunks safely <= 25 points
    const maxChunkPoints = 25;
    var startIdx = 0;

    while (startIdx < orderedStops.length - 1) {
      final endIdx = (startIdx + maxChunkPoints < orderedStops.length)
          ? startIdx + maxChunkPoints
          : orderedStops.length - 1;

      final chunk = orderedStops.sublist(startIdx, endIdx + 1);
      final chunkOrigin = chunk.first;
      final chunkDest = chunk.last;
      final intermediates = chunk.length > 2
          ? chunk
              .sublist(1, chunk.length - 1)
              .map(
                (p) => <String, dynamic>{
                  'via': true,
                  'location': {
                    'latLng': {
                      'latitude': p.latitude,
                      'longitude': p.longitude,
                    },
                  },
                },
              )
              .toList()
          : <Map<String, dynamic>>[];

      final payload = <String, dynamic>{
        'origin': _latLngPayload(chunkOrigin),
        'destination': _latLngPayload(chunkDest),
        if (intermediates.isNotEmpty) 'intermediates': intermediates,
        'travelMode': 'DRIVE',
        'units': 'METRIC',
      };

      late final http.Response res;
      try {
        res = await _client
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': mapsApiKey,
                'X-Goog-FieldMask': _roadPathFieldMask,
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        throw RoutesApiException(0, e.toString(), isNetworkError: true);
      }

      if (res.statusCode != 200) {
        throw RoutesApiException(res.statusCode, res.body);
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = (data['routes'] as List<dynamic>?) ?? const [];
      if (routes.isNotEmpty) {
        final polyObj = routes.first['polyline'] as Map<String, dynamic>?;
        final encoded = polyObj?['encodedPolyline'] as String?;
        if (encoded != null && encoded.isNotEmpty) {
          final decoded = decodeEncodedPolyline(encoded);
          if (fullPath.isNotEmpty && decoded.isNotEmpty) {
            fullPath.addAll(decoded.skip(1));
          } else {
            fullPath.addAll(decoded);
          }
        }
      }

      startIdx = endIdx;
    }

    if (fullPath.length >= 2) {
      _busLinePolylineCache[effectiveKey] = fullPath;
      if (fs != null && line != null) {
        await fs.saveCachedLinePolyline(
          line: line,
          cacheKey: effectiveKey,
          encodedPolyline: encodeGooglePolyline(fullPath),
        );
      }
    }
    return fullPath;
  }

  //**********************************************
  // Compute real WALK footpath polyline         *
  //**********************************************

  /// Computes a sidewalk walking polyline via Google Routes API v2 (`WALK`)
  /// with in-memory session caching. Never returns a synthetic straight line.
  Future<List<LatLng>> computeWalkPolyline(
    LatLng origin,
    LatLng destination,
  ) async {
    final key =
        '${origin.latitude.toStringAsFixed(5)},${origin.longitude.toStringAsFixed(5)}|'
        '${destination.latitude.toStringAsFixed(5)},${destination.longitude.toStringAsFixed(5)}';
    final cached = _walkPolylineCache[key];
    if (cached != null) return cached;

    final payload = <String, dynamic>{
      'origin': _latLngPayload(origin),
      'destination': _latLngPayload(destination),
      'travelMode': 'WALK',
      'units': 'METRIC',
    };

    late final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': mapsApiKey,
              'X-Goog-FieldMask': _roadPathFieldMask,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 9));
    } catch (e) {
      throw RoutesApiException(0, e.toString(), isNetworkError: true);
    }

    if (res.statusCode != 200) {
      throw RoutesApiException(res.statusCode, res.body);
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = (data['routes'] as List<dynamic>?) ?? const [];
    if (routes.isEmpty) return const <LatLng>[];
    final encoded =
        (routes.first['polyline'] as Map<String, dynamic>?)?['encodedPolyline']
            as String?;
    if (encoded == null || encoded.isEmpty) return const <LatLng>[];
    final decoded = decodeEncodedPolyline(encoded);
    if (decoded.length >= 2) {
      _walkPolylineCache[key] = decoded;
    }
    return decoded;
  }

  //**********************************************
  // Legacy-compatible route metric & parse APIs *
  //**********************************************

  /// Queries a single `DRIVE` or `WALK` route summary via Google Routes API v2.
  Future<GoogleRouteResult> computeRouteByCoordinates({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> intermediates = const [],
    String travelMode = 'DRIVE',
    bool avoidTolls = false,
    bool avoidHighways = false,
    bool includePolyline = true,
  }) async {
    final sampled = intermediates.length <= 23
        ? intermediates
        : [
            for (var i = 0; i < 23; i++)
              intermediates[((i * (intermediates.length - 1)) / 22).round()],
          ];

    final payload = <String, dynamic>{
      'origin': _latLngPayload(origin),
      'destination': _latLngPayload(destination),
      if (sampled.isNotEmpty)
        'intermediates': [
          for (final point in sampled)
            {
              'via': true,
              'location': {
                'latLng': {
                  'latitude': point.latitude,
                  'longitude': point.longitude,
                },
              },
            },
        ],
      'travelMode': travelMode,
      'units': 'METRIC',
      if (travelMode == 'DRIVE' && (avoidTolls || avoidHighways))
        'routeModifiers': {
          'avoidTolls': avoidTolls,
          'avoidHighways': avoidHighways,
        },
    };

    final fieldMask = includePolyline
        ? _roadPathFieldMask
        : 'routes.distanceMeters,routes.duration';

    late final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': mapsApiKey,
              'X-Goog-FieldMask': fieldMask,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 9));
    } catch (e) {
      throw RoutesApiException(0, e.toString(), isNetworkError: true);
    }

    if (res.statusCode != 200) {
      throw RoutesApiException(res.statusCode, res.body);
    }

    final parsed = parseComputeRoutesResponse(res.body);
    if (parsed == null) {
      throw RoutesApiException(404, 'Empty routes response');
    }
    return parsed;
  }

  /// Parses a Google Routes API v2 `TRANSIT` response JSON into [TripOption]s.
  static List<TripOption> parseTransitRoutesResponse(
    String responseBody, {
    required Map<String, BusLine> marpromLinesByCode,
    required List<BusStop> marpromStops,
    List<BusPosition> liveFleet = const [],
    String originLabel = '',
    String destinationLabel = '',
    DateTime? referenceTime,
  }) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) return const [];
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return const [];

    return [
      for (var i = 0; i < routes.length; i++)
        if (routes[i] is Map<String, dynamic>)
          MarpromRouteFusion.enrichFromGoogleJson(
            routes[i] as Map<String, dynamic>,
            marpromLinesByCode: marpromLinesByCode,
            marpromStops: marpromStops,
            liveFleet: liveFleet,
            originLabel: originLabel,
            destinationLabel: destinationLabel,
            referenceTime: referenceTime,
            routeIndex: i,
          ).option,
    ];
  }

  /// Parses a Google Routes API v2 `DRIVE`/`WALK` JSON response into [GoogleRouteResult].
  static GoogleRouteResult? parseComputeRoutesResponse(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) return null;
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return null;

    final first = routes.first;
    if (first is! Map<String, dynamic>) return null;

    final distanceRaw = first['distanceMeters'];
    final durationRaw = first['duration'] as String?;
    if (distanceRaw is! num || durationRaw == null) return null;

    final seconds = MarpromRouteFusion.parseDurationSeconds(durationRaw);
    final polylineMap = first['polyline'] as Map<String, dynamic>?;
    final encoded = polylineMap?['encodedPolyline'] as String?;
    final points = encoded != null && encoded.isNotEmpty
        ? decodeEncodedPolyline(encoded)
        : const <LatLng>[];

    return GoogleRouteResult(
      distanceMeters: distanceRaw.round(),
      durationSeconds: seconds,
      rawDuration: durationRaw,
      polylinePoints: points,
      isLiveApi: true,
      encodedPolyline: encoded,
    );
  }

  /// Decodes a Google encoded polyline string into geographic [LatLng] points.
  static List<LatLng> decodeGooglePolyline(String encoded) =>
      MarpromRouteFusion.decodeEncodedPolyline(encoded);

  /// Encodes [points] into a standard Google precision-1e5 encoded polyline string.
  static String encodeGooglePolyline(List<LatLng> points) {
    final buffer = StringBuffer();
    var prevLat = 0;
    var prevLng = 0;

    void encodeValue(int value) {
      var v = value < 0 ? ~(value << 1) : (value << 1);
      while (v >= 0x20) {
        buffer.writeCharCode((0x20 | (v & 0x1f)) + 63);
        v >>= 5;
      }
      buffer.writeCharCode(v + 63);
    }

    for (final p in points) {
      final lat = (p.latitude * 1e5).round();
      final lng = (p.longitude * 1e5).round();
      encodeValue(lat - prevLat);
      encodeValue(lng - prevLng);
      prevLat = lat;
      prevLng = lng;
    }
    return buffer.toString();
  }

  /// Estimates walking duration in minutes using [DistanceUtils].
  static int estimateWalkMinutes(double meters) =>
      DistanceUtils.estimateWalkMinutes(meters);

  static Map<String, dynamic> _latLngPayload(LatLng p) => {
        'location': {
          'latLng': {
            'latitude': p.latitude,
            'longitude': p.longitude,
          },
        },
      };
}

//**********************************************
// Pure-Dart Google Encoded Polyline Decoder   *
//**********************************************

/// Top-level encoded polyline decoder matching the service blueprint.
List<LatLng> decodeEncodedPolyline(String encoded) =>
    MarpromRouteFusion.decodeEncodedPolyline(encoded);

/// Provides the shared [GoogleRoutesService] wired to [firestoreTransitServiceProvider].
final googleRoutesServiceProvider = Provider<GoogleRoutesService>((ref) {
  return GoogleRoutesService(
    firestoreService: ref.watch(firestoreTransitServiceProvider),
  );
});
