// Google Routes API v2 (directions/v2:computeRoutes) client with polyline decoding.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../maps/google_maps_config.dart';
import '../utils/geo.dart';

/// Parsed result returned by Google Routes API v2 (`computeRoutes`) or offline fallback.
@immutable
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

  /// True when computed live by `routes.googleapis.com`; false on fallback.
  final bool isLiveApi;

  /// Raw Google encoded polyline string when requested in the field mask.
  final String? encodedPolyline;

  /// Distance formatted in kilometers (e.g. `"10.5 km"`).
  String get formattedDistanceKm =>
      distanceMeters >= 1000
          ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
          : '$distanceMeters m';

  /// Duration formatted in minutes (e.g. `"18 min"`).
  String get formattedDurationMinutes {
    final mins = (durationSeconds / 60).round().clamp(1, 999);
    return '$mins min';
  }

  /// Compact JSON representation matching Google Routes v2 minimal response shape.
  String toPrettyJsonSummary() {
    final payload = {
      'routes': [
        {
          'distanceMeters': distanceMeters,
          'duration': rawDuration,
        },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}

/// Client for Google Routes API v2 (`https://routes.googleapis.com/directions/v2:computeRoutes`).
class GoogleRoutesService {
  /// Creates a [GoogleRoutesService] using an optional injectable [http.Client].
  GoogleRoutesService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Computes a route between two text [originAddress] and [destinationAddress] strings.
  Future<GoogleRouteResult> computeRouteByAddresses({
    required String originAddress,
    required String destinationAddress,
    String travelMode = 'DRIVE',
    bool avoidTolls = false,
    bool avoidHighways = false,
    bool includePolyline = true,
    LatLng? fallbackOrigin,
    LatLng? fallbackDestination,
  }) async {
    final body = <String, dynamic>{
      'origin': {'address': originAddress},
      'destination': {'address': destinationAddress},
      'travelMode': travelMode,
      if (avoidTolls || avoidHighways)
        'routeModifiers': {
          'avoidTolls': avoidTolls,
          'avoidHighways': avoidHighways,
        },
    };

    return _executeComputeRoutes(
      body: body,
      includePolyline: includePolyline,
      fallbackOrigin: fallbackOrigin ?? GeoUtils.mariborCenter,
      fallbackDestination:
          fallbackDestination ?? const LatLng(46.5343, 15.6042),
    );
  }

  /// Computes a drivable route between geographic coordinates [origin] and [destination].
  Future<GoogleRouteResult> computeRouteByCoordinates({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> intermediates = const [],
    String travelMode = 'DRIVE',
    bool avoidTolls = false,
    bool avoidHighways = false,
    bool includePolyline = true,
  }) async {
    final sampledIntermediates = _sampleIntermediates(intermediates, maxCount: 23);
    final body = <String, dynamic>{
      'origin': {
        'location': {
          'latLng': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
        },
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        },
      },
      if (sampledIntermediates.isNotEmpty)
        'intermediates': [
          for (final point in sampledIntermediates)
            {
              'location': {
                'latLng': {
                  'latitude': point.latitude,
                  'longitude': point.longitude,
                },
              },
            },
        ],
      'travelMode': travelMode,
      if (avoidTolls || avoidHighways)
        'routeModifiers': {
          'avoidTolls': avoidTolls,
          'avoidHighways': avoidHighways,
        },
    };

    return _executeComputeRoutes(
      body: body,
      includePolyline: includePolyline,
      fallbackOrigin: origin,
      fallbackDestination: destination,
      fallbackIntermediates: intermediates,
    );
  }

  Future<GoogleRouteResult> _executeComputeRoutes({
    required Map<String, dynamic> body,
    required bool includePolyline,
    required LatLng fallbackOrigin,
    required LatLng fallbackDestination,
    List<LatLng> fallbackIntermediates = const [],
  }) async {
    final fieldMask = includePolyline
        ? 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline'
        : 'routes.duration,routes.distanceMeters';

    try {
      final response = await _client
          .post(
            GoogleMapsConfig.computeRoutesEndpoint,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': GoogleMapsConfig.routesApiKey,
              'X-Goog-FieldMask': fieldMask,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final parsed = parseComputeRoutesResponse(response.body);
        if (parsed != null) return parsed;
      }
    } catch (_) {
      // Fall back cleanly to local haversine/polyline calculation when offline or blocked.
    }

    return buildOfflineFallback(
      origin: fallbackOrigin,
      destination: fallbackDestination,
      intermediates: fallbackIntermediates,
    );
  }

  /// Parses a Google Routes API v2 JSON response into [GoogleRouteResult].
  ///
  /// Handles both minimal responses (`{"routes": [{"distanceMeters": 10491, "duration": "1094s"}]}`)
  /// and responses including `polyline.encodedPolyline`.
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

    final seconds = parseDurationSeconds(durationRaw);
    final polylineMap = first['polyline'] as Map<String, dynamic>?;
    final encoded = polylineMap?['encodedPolyline'] as String?;
    final points = encoded != null && encoded.isNotEmpty
        ? decodeGooglePolyline(encoded)
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

  /// Parses a Google Protobuf Duration string such as `"1094s"` or `"1094.5s"`.
  static int parseDurationSeconds(String raw) {
    final clean = raw.trim().replaceAll('s', '');
    final parsed = double.tryParse(clean);
    return parsed == null ? 0 : parsed.round();
  }

  /// Builds a deterministic fallback [GoogleRouteResult] from geographic coordinates.
  static GoogleRouteResult buildOfflineFallback({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> intermediates = const [],
  }) {
    final points = <LatLng>[origin, ...intermediates, destination];
    final straightMeters = GeoUtils.polylineLengthMeters(points);
    // Apply urban road-winding factor (~1.24x) and Maribor city speed (~26 km/h).
    final roadMeters = (straightMeters * 1.24).round().clamp(250, 250000);
    final seconds = ((roadMeters / 7.2) + 90).round();
    return GoogleRouteResult(
      distanceMeters: roadMeters,
      durationSeconds: seconds,
      rawDuration: '${seconds}s',
      polylinePoints: points,
      isLiveApi: false,
    );
  }

  /// Decodes a Google Maps encoded polyline string into geographic [LatLng] coordinates.
  static List<LatLng> decodeGooglePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        if (index >= encoded.length) break;
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  /// Encodes geographic [points] into a standard Google encoded polyline string.
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

  static List<LatLng> _sampleIntermediates(
    List<LatLng> points, {
    required int maxCount,
  }) {
    if (points.length <= maxCount) return points;
    final sampled = <LatLng>[];
    for (var i = 0; i < maxCount; i++) {
      final idx = ((i * (points.length - 1)) / (maxCount - 1)).round();
      sampled.add(points[idx]);
    }
    return sampled;
  }
}

/// Provides the shared [GoogleRoutesService] instance.
final googleRoutesServiceProvider = Provider<GoogleRoutesService>((ref) {
  return GoogleRoutesService();
});
