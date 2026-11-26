//**********************************************
// Native/VM Stub for Web JS Directions Bridge *
//**********************************************

import 'package:latlong2/latlong.dart';

/// Non-Web stub for Google Maps JS `DirectionsService` fallback.
abstract final class WebDirectionsBridge {
  /// Always false on non-Web platforms (Android uses direct Routes REST).
  static bool get isSupported => false;

  /// Returns null on non-Web targets.
  static Future<List<Map<String, dynamic>>?> computeTransitRoutes({
    required LatLng origin,
    required LatLng destination,
    String transitPreference = 'FEWER_TRANSFERS',
    String languageCode = 'sl',
    DateTime? departureTime,
    DateTime? arrivalTime,
  }) async =>
      null;

  /// Returns null on non-Web targets.
  static Future<List<LatLng>?> computeDrivingRoadPath({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async =>
      null;

  /// Returns null on non-Web targets.
  static Future<List<LatLng>?> computeWalkingPath({
    required LatLng origin,
    required LatLng destination,
  }) async =>
      null;
}
