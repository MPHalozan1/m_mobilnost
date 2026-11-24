//**********************************************
// Google Routes API v2 (DRIVE/WALK/TRANSIT)   *
//**********************************************

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../data/models/bus_line.dart';
import '../../data/models/bus_stop.dart';
import '../../data/models/trip_plan.dart';
import '../maps/google_maps_config.dart';
import '../utils/distance.dart';
import '../utils/geo.dart';
import 'data_freshness.dart';

//**********************************************
// GoogleRouteResult model                     *
//**********************************************

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

//**********************************************
// GoogleRoutesService (DRIVE, WALK, TRANSIT)  *
//**********************************************

/// Client for Google Routes API v2 (`https://routes.googleapis.com/directions/v2:computeRoutes`).
class GoogleRoutesService {
  /// Creates a [GoogleRoutesService] using an optional injectable [http.Client].
  GoogleRoutesService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, List<LatLng>> _walkPolylineCache = {};

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

  /// Computes a drivable or walking route between geographic coordinates [origin] and [destination].
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
      'origin': _latLngPayload(origin),
      'destination': _latLngPayload(destination),
      if (sampledIntermediates.isNotEmpty)
        'intermediates': [
          for (final point in sampledIntermediates) _latLngPayload(point),
        ],
      'travelMode': travelMode,
      if (travelMode == 'DRIVE' && (avoidTolls || avoidHighways))
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

  /// Computes a walking footpath polyline between [origin] and [destination] with caching.
  Future<List<LatLng>> computeWalkPolyline(LatLng origin, LatLng destination) async {
    final key =
        '${origin.latitude.toStringAsFixed(5)},${origin.longitude.toStringAsFixed(5)}|'
        '${destination.latitude.toStringAsFixed(5)},${destination.longitude.toStringAsFixed(5)}';
    final cached = _walkPolylineCache[key];
    if (cached != null) return cached;

    final result = await computeRouteByCoordinates(
      origin: origin,
      destination: destination,
      travelMode: 'WALK',
      includePolyline: true,
    );
    if (result.polylinePoints.length >= 2) {
      _walkPolylineCache[key] = result.polylinePoints;
      return result.polylinePoints;
    }
    return [origin, destination];
  }

  /// Queries Google Routes API v2 `TRANSIT` (prioritized for buses) for Maribor
  /// station-to-station and multi-transfer routes.
  Future<List<TripOption>> computeTransitRoutes({
    required LatLng origin,
    required LatLng destination,
    required Map<String, BusLine> marpromLinesByCode,
    required List<BusStop> marpromStops,
    DateTime? departureTime,
    DateTime? arrivalTime,
    bool fewerTransfers = false,
    String originLabel = '',
    String destinationLabel = '',
  }) async {
    final body = <String, dynamic>{
      'origin': _latLngPayload(origin),
      'destination': _latLngPayload(destination),
      'travelMode': 'TRANSIT',
      'computeAlternativeRoutes': true,
      'languageCode': 'sl',
      'transitPreferences': {
        'allowedTravelModes': ['BUS'],
        'routingPreference': fewerTransfers ? 'FEWER_TRANSFERS' : 'LESS_WALKING',
      },
      if (departureTime != null)
        'departureTime': departureTime.toUtc().toIso8601String(),
      if (departureTime == null && arrivalTime != null)
        'arrivalTime': arrivalTime.toUtc().toIso8601String(),
    };

    const fieldMask =
        'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,'
        'routes.legs.duration,routes.legs.distanceMeters,'
        'routes.legs.steps.travelMode,routes.legs.steps.staticDuration,'
        'routes.legs.steps.distanceMeters,routes.legs.steps.polyline.encodedPolyline,'
        'routes.legs.steps.transitDetails';

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
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return parseTransitRoutesResponse(
          response.body,
          marpromLinesByCode: marpromLinesByCode,
          marpromStops: marpromStops,
          originLabel: originLabel,
          destinationLabel: destinationLabel,
          referenceTime: departureTime ?? arrivalTime ?? DateTime.now(),
        );
      }
    } catch (_) {
      // Fall back cleanly to local Marprom RAPTOR transfer planner.
    }
    return const [];
  }

  /// Parses a Google Routes API v2 `TRANSIT` response into [TripOption]s.
  static List<TripOption> parseTransitRoutesResponse(
    String responseBody, {
    required Map<String, BusLine> marpromLinesByCode,
    required List<BusStop> marpromStops,
    String originLabel = '',
    String destinationLabel = '',
    DateTime? referenceTime,
  }) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) return const [];
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return const [];

    final now = referenceTime ?? DateTime.now();
    final options = <TripOption>[];

    for (var rIdx = 0; rIdx < routes.length; rIdx++) {
      final routeMap = routes[rIdx];
      if (routeMap is! Map<String, dynamic>) continue;
      final rawLegs = routeMap['legs'] as List<dynamic>? ?? const [];
      if (rawLegs.isEmpty) continue;

      final parsedLegs = <TripLeg>[];
      var cursorTime = now;
      var totalWalkMeters = 0.0;
      var totalWalkMin = 0;

      // Temporary accumulator for merging adjacent WALK steps
      double walkAccMeters = 0;
      int walkAccSec = 0;
      final walkAccPoly = <LatLng>[];
      String? pendingWalkFromName;
      DateTime? pendingWalkStart;

      void flushWalk(String nextStopName, String? nextStopId) {
        if (walkAccPoly.isEmpty && walkAccMeters <= 10) {
          walkAccMeters = 0;
          walkAccSec = 0;
          return;
        }
        final mins = (walkAccSec / 60).ceil().clamp(1, 60);
        final start = pendingWalkStart ?? cursorTime;
        final end = start.add(Duration(minutes: mins));
        cursorTime = end;
        totalWalkMeters += walkAccMeters;
        totalWalkMin += mins;

        parsedLegs.add(
          TripLeg(
            type: TripLegType.walk,
            fromName: pendingWalkFromName ??
                (parsedLegs.isEmpty
                    ? (originLabel.isEmpty ? 'Začetek' : originLabel)
                    : parsedLegs.last.toName),
            toName: nextStopName,
            fromStopId: parsedLegs.isEmpty ? null : parsedLegs.last.toStopId,
            toStopId: nextStopId,
            startTime: start,
            endTime: end,
            durationMinutes: mins,
            distanceMeters: walkAccMeters,
            polyline: List<LatLng>.from(walkAccPoly),
            isAccessible: true,
          ),
        );
        walkAccMeters = 0;
        walkAccSec = 0;
        walkAccPoly.clear();
        pendingWalkFromName = null;
        pendingWalkStart = null;
      }

      for (final legObj in rawLegs) {
        if (legObj is! Map<String, dynamic>) continue;
        final steps = legObj['steps'] as List<dynamic>? ?? const [];
        for (final stepObj in steps) {
          if (stepObj is! Map<String, dynamic>) continue;
          final travelMode = stepObj['travelMode'] as String? ?? '';
          final stepDist = (stepObj['distanceMeters'] as num?)?.toDouble() ?? 0.0;
          final stepSec =
              parseDurationSeconds(stepObj['staticDuration'] as String? ?? '0s');
          final polyEncoded =
              (stepObj['polyline'] as Map<String, dynamic>?)?['encodedPolyline']
                  as String?;
          final stepPoints = polyEncoded != null && polyEncoded.isNotEmpty
              ? decodeGooglePolyline(polyEncoded)
              : const <LatLng>[];

          if (travelMode == 'WALK') {
            pendingWalkStart ??= cursorTime;
            pendingWalkFromName ??= parsedLegs.isEmpty
                ? (originLabel.isEmpty ? 'Začetek' : originLabel)
                : parsedLegs.last.toName;
            walkAccMeters += stepDist;
            walkAccSec += stepSec;
            walkAccPoly.addAll(stepPoints);
          } else if (travelMode == 'TRANSIT') {
            final td = stepObj['transitDetails'] as Map<String, dynamic>? ?? const {};
            final stopDetails =
                td['stopDetails'] as Map<String, dynamic>? ?? const {};
            final depStop =
                stopDetails['departureStop'] as Map<String, dynamic>? ?? const {};
            final arrStop =
                stopDetails['arrivalStop'] as Map<String, dynamic>? ?? const {};

            final depName = depStop['name'] as String? ?? 'Postajališče';
            final arrName = arrStop['name'] as String? ?? 'Postajališče';

            final depLatLng = _extractLatLng(depStop);
            final arrLatLng = _extractLatLng(arrStop);
            final matchedDepStop = _matchMarpromStop(depName, depLatLng, marpromStops);
            final matchedArrStop = _matchMarpromStop(arrName, arrLatLng, marpromStops);

            final depTime = _parseTimestamp(
                  stopDetails['departureTime'] as String?,
                ) ??
                cursorTime;
            final arrTime = _parseTimestamp(
                  stopDetails['arrivalTime'] as String?,
                ) ??
                depTime.add(Duration(seconds: stepSec > 0 ? stepSec : 300));

            if (walkAccMeters > 10 || walkAccPoly.isNotEmpty) {
              flushWalk(depName, matchedDepStop?.id);
            }

            final transitLine =
                td['transitLine'] as Map<String, dynamic>? ?? const {};
            final shortName =
                (transitLine['nameShort'] as String? ?? '').trim();
            final fullName = (transitLine['name'] as String? ?? '').trim();
            final headsign = (td['headsign'] as String? ?? fullName).trim();
            final stopCount = (td['stopCount'] as num?)?.round();

            final normalizedCode = _normalizeMarpromCode(shortName);
            final matchedLine = marpromLinesByCode[normalizedCode] ??
                marpromLinesByCode[shortName];
            final isAccessible = matchedLine != null
                ? (matchedLine.isWheelchairAccessible &&
                    (matchedDepStop?.isStepFree ?? true) &&
                    (matchedArrStop?.isStepFree ?? true))
                : true;

            final rideMin =
                arrTime.difference(depTime).inMinutes.clamp(1, 240);
            parsedLegs.add(
              TripLeg(
                type: TripLegType.bus,
                fromName: matchedDepStop?.name ?? depName,
                toName: matchedArrStop?.name ?? arrName,
                fromStopId: matchedDepStop?.id,
                toStopId: matchedArrStop?.id,
                startTime: depTime,
                endTime: arrTime,
                durationMinutes: rideMin,
                distanceMeters: stepDist > 0
                    ? stepDist
                    : GeoUtils.polylineLengthMeters(stepPoints),
                lineId: matchedLine?.id ?? (normalizedCode.isNotEmpty ? normalizedCode : shortName),
                lineCode: matchedLine?.code ?? (normalizedCode.isNotEmpty ? normalizedCode : shortName),
                directionName: headsign.isNotEmpty ? headsign : null,
                stopCount: stopCount,
                polyline: stepPoints,
                isAccessible: isAccessible,
              ),
            );
            cursorTime = arrTime;
          }
        }
      }

      if (walkAccMeters > 10 || walkAccPoly.isNotEmpty) {
        flushWalk(
          destinationLabel.isEmpty ? 'Cilj' : destinationLabel,
          null,
        );
      }

      final busLegs = parsedLegs
          .where((l) => l.type == TripLegType.bus)
          .toList(growable: false);
      if (busLegs.isEmpty) continue;

      final transferCount = (busLegs.length - 1).clamp(0, 10);
      var minTransferBuffer = 999;
      for (var i = 0; i < parsedLegs.length; i++) {
        if (parsedLegs[i].type != TripLegType.bus) continue;
        final prevBusIdx = parsedLegs.lastIndexWhere(
          (l) => l.type == TripLegType.bus,
          i - 1,
        );
        if (prevBusIdx == -1) continue;
        final prevEnd = parsedLegs[prevBusIdx].endTime;
        final walkTime = parsedLegs
            .sublist(prevBusIdx + 1, i)
            .fold<int>(0, (s, l) => s + l.durationMinutes);
        final wait = parsedLegs[i]
            .startTime
            .difference(prevEnd.add(Duration(minutes: walkTime)))
            .inMinutes;
        if (wait < minTransferBuffer) minTransferBuffer = wait;
      }

      final isTight = transferCount > 0 && minTransferBuffer <= 4;
      final totalDurationMin = parsedLegs.last.endTime
          .difference(parsedLegs.first.startTime)
          .inMinutes
          .clamp(1, 360);

      options.add(
        TripOption(
          id: 'gtransit_${rIdx}_${parsedLegs.first.startTime.millisecondsSinceEpoch}',
          totalMinutes: totalDurationMin,
          walkMeters: totalWalkMeters,
          walkMinutes: totalWalkMin,
          transferCount: transferCount,
          hasTightTransfer: isTight,
          tightTransferMinutes: isTight ? minTransferBuffer.clamp(0, 4) : null,
          legs: parsedLegs,
          freshness: DataFreshness(
            kind: DataSourceKind.live,
            updatedAt: DateTime.now(),
          ),
          isGoogleTransit: true,
        ),
      );
    }

    return options;
  }

  static Map<String, dynamic> _latLngPayload(LatLng p) => {
        'location': {
          'latLng': {
            'latitude': p.latitude,
            'longitude': p.longitude,
          },
        },
      };

  static LatLng? _extractLatLng(Map<String, dynamic> stopMap) {
    final loc = stopMap['location'] as Map<String, dynamic>?;
    final latLng = loc?['latLng'] as Map<String, dynamic>?;
    final lat = (latLng?['latitude'] as num?)?.toDouble();
    final lng = (latLng?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static DateTime? _parseTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  static String _normalizeMarpromCode(String raw) {
    final upper = raw.trim().toUpperCase();
    if (upper.isEmpty) return '';
    if (RegExp(r'^[GP]\d+$').hasMatch(upper)) return upper;
    final numOnly = int.tryParse(upper);
    if (numOnly != null) {
      if (numOnly >= 1 && numOnly <= 6) return 'G$numOnly';
      if (numOnly >= 7 && numOnly <= 19) return 'P$numOnly';
    }
    return upper;
  }

  static BusStop? _matchMarpromStop(
    String name,
    LatLng? pos,
    List<BusStop> stops,
  ) {
    if (pos != null) {
      BusStop? nearest;
      var bestDist = double.infinity;
      for (final stop in stops) {
        final d = GeoUtils.haversineMeters(pos, stop.position);
        if (d < bestDist) {
          bestDist = d;
          nearest = stop;
        }
      }
      if (nearest != null && bestDist <= 220) {
        return nearest;
      }
    }
    final clean = name.trim().toLowerCase();
    for (final stop in stops) {
      if (stop.name.toLowerCase() == clean ||
          stop.name.toLowerCase().contains(clean) ||
          clean.contains(stop.name.toLowerCase())) {
        return stop;
      }
    }
    return null;
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
      // Fall back cleanly when offline or blocked.
    }

    return buildOfflineFallback(
      origin: fallbackOrigin,
      destination: fallbackDestination,
      intermediates: fallbackIntermediates,
    );
  }

  /// Parses a Google Routes API v2 JSON response into [GoogleRouteResult].
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

  /// Estimates walking duration minutes cleanly using shared [DistanceUtils].
  static int estimateWalkMinutes(double meters) =>
      DistanceUtils.estimateWalkMinutes(meters);
}

/// Provides the shared [GoogleRoutesService] instance.
final googleRoutesServiceProvider = Provider<GoogleRoutesService>((ref) {
  return GoogleRoutesService();
});
