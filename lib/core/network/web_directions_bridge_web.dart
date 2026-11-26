//**********************************************
// Web Google Maps JS DirectionsService Bridge *
//**********************************************

import 'dart:convert';
import 'dart:js_interop';

import 'package:latlong2/latlong.dart';

import '../maps/google_maps_config.dart';

@JS('__marpromComputeJsDirections')
external JSPromise<JSString>? _marpromComputeJsDirections(JSString payloadJson);

@JS('__marpromSearchPlaces')
external JSPromise<JSString>? _marpromSearchPlaces(JSString payloadJson);

/// Calls `google.maps.DirectionsService` on Flutter Web as an automatic
/// CORS/referrer-safe fallback whenever REST `routes.googleapis.com` fails.
abstract final class WebDirectionsBridge {
  /// True on Web targets where `dart:js_interop` is available.
  static bool get isSupported => true;

  /// Computes `TRANSIT` (BUS) routes via `google.maps.DirectionsService`.
  static Future<List<Map<String, dynamic>>?> computeTransitRoutes({
    required LatLng origin,
    required LatLng destination,
    String transitPreference = 'FEWER_TRANSFERS',
    String languageCode = 'sl',
    DateTime? departureTime,
    DateTime? arrivalTime,
  }) async {
    final payload = <String, dynamic>{
      'apiKey': GoogleMapsConfig.webApiKey,
      'mode': 'TRANSIT',
      'origin': {'lat': origin.latitude, 'lng': origin.longitude},
      'destination': {
        'lat': destination.latitude,
        'lng': destination.longitude,
      },
      'routingPreference': transitPreference,
      'languageCode': languageCode,
      if (departureTime != null)
        'departureTimeMs': departureTime.millisecondsSinceEpoch,
      if (departureTime == null && arrivalTime != null)
        'arrivalTimeMs': arrivalTime.millisecondsSinceEpoch,
    };

    final decoded = await _invoke(payload);
    if (decoded == null) return null;
    final rawRoutes = decoded['routes'];
    if (rawRoutes is! List) return null;
    return [
      for (final item in rawRoutes)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  /// Computes a `DRIVING` road path through intermediate stops on Web.
  static Future<List<LatLng>?> computeDrivingRoadPath({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    final payload = <String, dynamic>{
      'apiKey': GoogleMapsConfig.webApiKey,
      'mode': 'DRIVING',
      'origin': {'lat': origin.latitude, 'lng': origin.longitude},
      'destination': {
        'lat': destination.latitude,
        'lng': destination.longitude,
      },
      if (waypoints.isNotEmpty)
        'waypoints': [
          for (final pt in waypoints) {'lat': pt.latitude, 'lng': pt.longitude},
        ],
    };

    final decoded = await _invoke(payload);
    return _extractFirstOverviewPath(decoded);
  }

  /// Computes a `WALKING` footpath polyline via Google Maps JS on Web.
  static Future<List<LatLng>?> computeWalkingPath({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final payload = <String, dynamic>{
      'apiKey': GoogleMapsConfig.webApiKey,
      'mode': 'WALKING',
      'origin': {'lat': origin.latitude, 'lng': origin.longitude},
      'destination': {
        'lat': destination.latitude,
        'lng': destination.longitude,
      },
    };

    final decoded = await _invoke(payload);
    return _extractFirstOverviewPath(decoded);
  }

  /// Searches real Maribor places/POIs via Google Maps JS Places library.
  static Future<List<Map<String, dynamic>>?> searchPlacesInMaribor({
    required String query,
    LatLng? userLocation,
  }) async {
    try {
      final payload = <String, dynamic>{
        'apiKey': GoogleMapsConfig.webApiKey,
        'query': query,
        if (userLocation != null)
          'userLocation': {
            'lat': userLocation.latitude,
            'lng': userLocation.longitude,
          },
      };
      final promise = _marpromSearchPlaces(jsonEncode(payload).toJS);
      if (promise == null) return null;
      final jsResult = await promise.toDart;
      final raw = jsResult.toDart;
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final rawPlaces = decoded['places'];
      if (rawPlaces is! List) return null;
      return [
        for (final p in rawPlaces)
          if (p is Map) Map<String, dynamic>.from(p),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _invoke(
    Map<String, dynamic> payload,
  ) async {
    try {
      final promise = _marpromComputeJsDirections(jsonEncode(payload).toJS);
      if (promise == null) return null;
      final jsResult = await promise.toDart;
      final raw = jsResult.toDart;
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final status = map['status'] as String? ?? '';
      if (status == 'OK' || status == 'ZERO_RESULTS') {
        return map;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static List<LatLng>? _extractFirstOverviewPath(Map<String, dynamic>? decoded) {
    if (decoded == null) return null;
    final rawRoutes = decoded['routes'];
    if (rawRoutes is! List || rawRoutes.isEmpty) return null;
    final first = rawRoutes.first;
    if (first is! Map) return null;
    final overview = first['overviewPath'];
    if (overview is! List) return null;
    final pts = <LatLng>[];
    for (final p in overview) {
      if (p is Map) {
        final lat = (p['lat'] as num?)?.toDouble();
        final lng = (p['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          pts.add(LatLng(lat, lng));
        }
      }
    }
    return pts.length >= 2 ? pts : null;
  }
}
