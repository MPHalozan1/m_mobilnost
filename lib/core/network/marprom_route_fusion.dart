//**********************************************
// Google Routes API v2 + Marprom Data Fusion  *
//**********************************************

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/bus_line.dart';
import '../../data/models/bus_position.dart';
import '../../data/models/bus_stop.dart';
import '../../data/models/occupancy.dart';
import '../../data/models/trip_plan.dart';
import '../../data/seed/seed_lines.dart';
import '../../data/seed/seed_stops.dart';
import '../../data/simulation/delay_model.dart';
import '../../data/simulation/occupancy_model.dart';
import '../utils/geo.dart';
import 'data_freshness.dart';

//**********************************************
// Typed exception for Routes API v2 failures  *
//**********************************************

/// Thrown when Google Routes API v2 (and Web JS fallback) fails or rejects a request.
/// Ensures the UI displays a clear banner + collapsible diagnostics instead of straight lines.
class RoutesApiException implements Exception {
  /// Creates a [RoutesApiException].
  RoutesApiException(
    this.statusCode,
    this.body, {
    this.isNetworkError = false,
    this.diagnostics,
  });

  /// HTTP status code (0 for network/timeout/CORS failures).
  final int statusCode;

  /// Raw error body from `routes.googleapis.com` or exception string.
  final String body;

  /// True when the request failed before receiving an HTTP response.
  final bool isNetworkError;

  /// Optional extra context (e.g. Web JS fallback status or endpoint notes).
  final String? diagnostics;

  /// Returns a localized user-friendly error explanation without raw stack noise.
  String localizedMessage(String localeCode) {
    final isSl = localeCode == 'sl';
    if (isNetworkError) {
      return isSl
          ? 'Povezava z Google Routes ni na voljo. Preverite internetno povezavo in poskusite znova.'
          : 'Unable to reach Google Routes. Check your internet connection and try again.';
    }
    if (statusCode == 403 || statusCode == 401) {
      return isSl
          ? 'Google Routes ključ je omejen ali zavrnjen (HTTP $statusCode). Preverite dovoljenja API ključa.'
          : 'Google Routes API key rejected or restricted (HTTP $statusCode).';
    }
    if (statusCode == 429) {
      return isSl
          ? 'Dosežena je začasna omejitev Google Routes zahtevkov (HTTP 429). Počakajte trenutek.'
          : 'Google Routes rate limit reached (HTTP 429). Please wait a moment.';
    }
    return isSl
        ? 'Google Routes ni mogel izračunati trase (HTTP $statusCode).'
        : 'Google Routes could not compute a route (HTTP $statusCode).';
  }

  /// Compact technical details shown inside a collapsible Debug / Diagnostics section.
  String get technicalDetails {
    final buffer = StringBuffer('HTTP $statusCode');
    final extracted = _extractApiErrorMessage(body);
    if (extracted.isNotEmpty) {
      buffer.write(': $extracted');
    }
    if (diagnostics != null && diagnostics!.trim().isNotEmpty) {
      buffer.write('\n${diagnostics!.trim()}');
    }
    return buffer.toString();
  }

  static String _extractApiErrorMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map && err['message'] is String) {
          final status = err['status'] as String? ?? '';
          final msg = (err['message'] as String).trim();
          return status.isNotEmpty ? '$status — $msg' : msg;
        }
      }
    } catch (_) {}
    return trimmed.length > 260 ? '${trimmed.substring(0, 260)}...' : trimmed;
  }

  @override
  String toString() => 'RoutesApiException($statusCode): $body';
}

//**********************************************
// EnrichedTransitRoute wrapper                *
//**********************************************

/// Wraps a [TripOption] fused with Google Routes overview metrics and polyline.
@immutable
class EnrichedTransitRoute {
  /// Creates an [EnrichedTransitRoute].
  const EnrichedTransitRoute({
    required this.option,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.overviewPolyline,
  });

  /// Enriched door-to-door trip option ready for UI & map rendering.
  final TripOption option;

  /// Total route distance reported by Google Routes / Directions.
  final int distanceMeters;

  /// Total route duration in seconds reported by Google Routes / Directions.
  final int durationSeconds;

  /// Overview decoded polyline for the complete route.
  final List<LatLng> overviewPolyline;
}

//**********************************************
// MarpromRouteFusion data enrichment engine   *
//**********************************************

/// Bridges Google Routes API v2 & Web JS Directions output with Marprom fleet
/// telemetry, realistic capacities (<= 120), live punctuality, and wheelchair flags.
abstract final class MarpromRouteFusion {
  static final OccupancyModel _occupancyModel = const OccupancyModel();
  static final DelayModel _delayModel = const DelayModel();
  static final RegExp _durationSecRegex = RegExp(r'^(-?\d+(?:\.\d+)?)s?$');

  //**********************************************
  // Pure-Dart Google Encoded Polyline Decoder   *
  //**********************************************

  /// Decodes a Google precision-1e5 encoded polyline string into [LatLng] points.
  static List<LatLng> decodeEncodedPolyline(String encoded) {
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
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        if (index >= encoded.length) break;
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  //**********************************************
  // Normalize Marprom line codes                *
  //**********************************************

  /// Normalizes Google transit line names (`"Linija G1"`, `" 1 "`, `"P 7"`)
  /// into canonical Marprom codes (`G1`–`G6`, `P7`–`P19`).
  static String normalizeMarpromLineCode(String raw) {
    var clean = raw.trim().toUpperCase();
    if (clean.isEmpty) return '';
    clean = clean
        .replaceFirst(RegExp(r'^(LINIJA|LINE|BUS|AVTOBUS)\s*'), '')
        .replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^[GP]\d{1,2}$').hasMatch(clean)) return clean;
    final numOnly = int.tryParse(clean);
    if (numOnly != null) {
      if (numOnly >= 1 && numOnly <= 6) return 'G$numOnly';
      if (numOnly >= 7 && numOnly <= 19) return 'P$numOnly';
      if (numOnly == 21) return 'P11';
    }
    return clean;
  }

  /// Parses a Google Protobuf Duration string such as `"1094s"` cleanly.
  static int parseDurationSeconds(String raw) {
    final match = _durationSecRegex.firstMatch(raw.trim());
    if (match == null) return 0;
    final parsed = double.tryParse(match.group(1) ?? '');
    return parsed == null ? 0 : math.max(0, parsed.round());
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<LatLng> _resolveMissingStepPolyline({
    required double stepDistMeters,
    required LatLng? stepStart,
    required LatLng? stepEnd,
    required List<LatLng> overviewPts,
  }) {
    if (stepStart == null || stepEnd == null) return const <LatLng>[];
    final span = stepDistMeters > 0
        ? stepDistMeters
        : GeoUtils.haversineMeters(stepStart, stepEnd);

    // Allow tiny sub-25m curb/platform connectors between step endpoints only.
    if (span <= 25.0) {
      return <LatLng>[stepStart, stepEnd];
    }

    // For longer steps missing step polylines, slice the real route overview polyline.
    if (overviewPts.length >= 2) {
      return _sliceOverviewBetween(overviewPts, stepStart, stepEnd);
    }
    return const <LatLng>[];
  }

  static List<LatLng> _sliceOverviewBetween(
    List<LatLng> overview,
    LatLng start,
    LatLng end,
  ) {
    var startIdx = 0;
    var endIdx = overview.length - 1;
    var bestStart = double.infinity;
    var bestEnd = double.infinity;
    for (var i = 0; i < overview.length; i++) {
      final ds = GeoUtils.haversineMeters(overview[i], start);
      if (ds < bestStart) {
        bestStart = ds;
        startIdx = i;
      }
      final de = GeoUtils.haversineMeters(overview[i], end);
      if (de < bestEnd) {
        bestEnd = de;
        endIdx = i;
      }
    }
    final sliced = startIdx <= endIdx
        ? overview.sublist(startIdx, endIdx + 1)
        : overview.sublist(endIdx, startIdx + 1).reversed.toList();
    return sliced.length >= 2 ? sliced : const <LatLng>[];
  }

  //**********************************************
  // Enrich one Google Routes REST JSON route    *
  //**********************************************

  /// Converts a single `routes[i]` JSON object from `computeRoutes` into an
  /// [EnrichedTransitRoute] populated with Marprom fleet & accessibility data.
  static EnrichedTransitRoute enrichFromGoogleJson(
    Map<String, dynamic> routeMap, {
    Map<String, BusLine>? marpromLinesByCode,
    List<BusStop>? marpromStops,
    List<BusPosition> liveFleet = const [],
    String originLabel = '',
    String destinationLabel = '',
    DateTime? referenceTime,
    int routeIndex = 0,
  }) {
    final linesLookup = marpromLinesByCode ??
        {
          for (final l in seedLines) l.code.toUpperCase(): l,
          for (final l in seedLines) l.id.toUpperCase(): l,
        };
    final stopsList = marpromStops ?? seedStops;
    final now = referenceTime ?? DateTime.now();

    final routeDist = (routeMap['distanceMeters'] as num?)?.round() ?? 0;
    final routeDurSec = parseDurationSeconds(
      routeMap['duration'] as String? ?? '0s',
    );
    final overviewEncoded =
        _asMap(routeMap['polyline'])?['encodedPolyline'] as String?;
    final overviewPts = overviewEncoded != null && overviewEncoded.isNotEmpty
        ? decodeEncodedPolyline(overviewEncoded)
        : const <LatLng>[];

    final rawLegs = routeMap['legs'] as List<dynamic>? ?? const [];
    final parsedLegs = <TripLeg>[];
    var cursorTime = now;
    var totalWalkMeters = 0.0;
    var totalWalkMin = 0;

    // Accumulate adjacent WALK steps so sidewalks stay one clean walk leg
    double walkAccMeters = 0;
    int walkAccSec = 0;
    final walkAccPoly = <LatLng>[];
    final walkInstructions = <String>[];
    String? pendingWalkFromName;
    DateTime? pendingWalkStart;

    void flushWalk(String nextStopName, String? nextStopId) {
      if (walkAccPoly.isEmpty && walkAccMeters <= 10) {
        walkAccMeters = 0;
        walkAccSec = 0;
        walkInstructions.clear();
        return;
      }
      final mins = (walkAccSec / 60).ceil().clamp(1, 90);
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
          navigationInstructions: List<String>.from(walkInstructions),
        ),
      );
      walkAccMeters = 0;
      walkAccSec = 0;
      walkAccPoly.clear();
      walkInstructions.clear();
      pendingWalkFromName = null;
      pendingWalkStart = null;
    }

    for (final legRaw in rawLegs) {
      final legObj = _asMap(legRaw);
      if (legObj == null) continue;
      final steps = legObj['steps'] as List<dynamic>? ?? const [];
      for (final stepRaw in steps) {
        final stepObj = _asMap(stepRaw);
        if (stepObj == null) continue;
        final travelMode = (stepObj['travelMode'] as String? ?? '').toUpperCase();
        final stepDist = (stepObj['distanceMeters'] as num?)?.toDouble() ?? 0.0;
        final stepSec =
            parseDurationSeconds(stepObj['staticDuration'] as String? ?? '0s');
        final polyEncoded =
            _asMap(stepObj['polyline'])?['encodedPolyline'] as String?;
        final decodedStepPoints = polyEncoded != null && polyEncoded.isNotEmpty
            ? decodeEncodedPolyline(polyEncoded)
            : const <LatLng>[];
        final stepStart = _extractLatLng(_asMap(stepObj['startLocation']));
        final stepEnd = _extractLatLng(_asMap(stepObj['endLocation']));
        final stepPoints = decodedStepPoints.length >= 2
            ? decodedStepPoints
            : _resolveMissingStepPolyline(
                stepDistMeters: stepDist,
                stepStart: stepStart,
                stepEnd: stepEnd,
                overviewPts: overviewPts,
              );
        final navText =
            _asMap(stepObj['navigationInstruction'])?['instructions'] as String?;

        if (travelMode == 'WALK') {
          pendingWalkStart ??= cursorTime;
          pendingWalkFromName ??= parsedLegs.isEmpty
              ? (originLabel.isEmpty ? 'Začetek' : originLabel)
              : parsedLegs.last.toName;
          walkAccMeters += stepDist;
          walkAccSec += stepSec;
          walkAccPoly.addAll(stepPoints);
          if (navText != null && navText.trim().isNotEmpty) {
            walkInstructions.add(navText.trim());
          }
        } else if (travelMode == 'TRANSIT') {
          final td = _asMap(stepObj['transitDetails']) ?? const {};
          final stopDetails = _asMap(td['stopDetails']) ?? const {};
          final depStop = _asMap(stopDetails['departureStop']) ?? const {};
          final arrStop = _asMap(stopDetails['arrivalStop']) ?? const {};

          final depName = depStop['name'] as String? ?? 'Postajališče';
          final arrName = arrStop['name'] as String? ?? 'Postajališče';

          final depLatLng = _extractLatLng(depStop) ?? stepStart;
          final arrLatLng = _extractLatLng(arrStop) ?? stepEnd;
          final matchedDepStop = _matchMarpromStop(depName, depLatLng, stopsList);
          final matchedArrStop = _matchMarpromStop(arrName, arrLatLng, stopsList);

          final depTime =
              _parseTimestamp(stopDetails['departureTime'] as String?) ??
                  cursorTime;
          final arrTime =
              _parseTimestamp(stopDetails['arrivalTime'] as String?) ??
                  depTime.add(Duration(seconds: stepSec > 0 ? stepSec : 300));

          if (walkAccMeters > 10 || walkAccPoly.isNotEmpty) {
            flushWalk(matchedDepStop?.name ?? depName, matchedDepStop?.id);
          }

          final transitLine = _asMap(td['transitLine']) ?? const {};
          final shortName =
              (transitLine['nameShort'] as String? ?? '').trim();
          final fullName = (transitLine['name'] as String? ?? '').trim();
          final headsign = (td['headsign'] as String? ?? fullName).trim();
          final stopCount = (td['stopCount'] as num?)?.round();

          final busPoints = stepPoints.length >= 2
              ? stepPoints
              : (depLatLng != null &&
                      arrLatLng != null &&
                      overviewPts.length >= 2
                  ? _sliceOverviewBetween(overviewPts, depLatLng, arrLatLng)
                  : stepPoints);

          final busLeg = _buildEnrichedBusLeg(
            shortName: shortName,
            fullName: fullName,
            headsign: headsign,
            stopCount: stopCount,
            depName: depName,
            arrName: arrName,
            matchedDepStop: matchedDepStop,
            matchedArrStop: matchedArrStop,
            depTime: depTime,
            arrTime: arrTime,
            stepDist: stepDist,
            stepPoints: busPoints,
            navText: navText,
            linesLookup: linesLookup,
            liveFleet: liveFleet,
          );
          parsedLegs.add(busLeg);
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

    return _finalizeEnrichedRoute(
      parsedLegs: parsedLegs,
      routeDist: routeDist,
      routeDurSec: routeDurSec,
      totalWalkMeters: totalWalkMeters,
      totalWalkMin: totalWalkMin,
      overviewPts: overviewPts,
      now: now,
      routeIndex: routeIndex,
    );
  }

  //**********************************************
  // Enrich one Web JS DirectionsService route   *
  //**********************************************

  /// Converts a serialized `google.maps.DirectionsService` JSON route into the
  /// exact same [EnrichedTransitRoute] model used by REST `computeRoutes`.
  static EnrichedTransitRoute enrichFromWebDirectionsJson(
    Map<String, dynamic> routeMap, {
    Map<String, BusLine>? marpromLinesByCode,
    List<BusStop>? marpromStops,
    List<BusPosition> liveFleet = const [],
    String originLabel = '',
    String destinationLabel = '',
    DateTime? referenceTime,
    int routeIndex = 0,
  }) {
    final linesLookup = marpromLinesByCode ??
        {
          for (final l in seedLines) l.code.toUpperCase(): l,
          for (final l in seedLines) l.id.toUpperCase(): l,
        };
    final stopsList = marpromStops ?? seedStops;
    final now = referenceTime ?? DateTime.now();

    final overviewPts = _parsePointList(routeMap['overviewPath']);
    final rawLegs = routeMap['legs'] as List<dynamic>? ?? const [];
    final parsedLegs = <TripLeg>[];
    var cursorTime = now;
    var totalWalkMeters = 0.0;
    var totalWalkMin = 0;
    var totalDistMeters = 0;
    var totalDurSec = 0;

    double walkAccMeters = 0;
    int walkAccSec = 0;
    final walkAccPoly = <LatLng>[];
    final walkInstructions = <String>[];
    String? pendingWalkFromName;
    DateTime? pendingWalkStart;

    void flushWalk(String nextStopName, String? nextStopId) {
      if (walkAccPoly.isEmpty && walkAccMeters <= 10) {
        walkAccMeters = 0;
        walkAccSec = 0;
        walkInstructions.clear();
        return;
      }
      final mins = (walkAccSec / 60).ceil().clamp(1, 90);
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
          navigationInstructions: List<String>.from(walkInstructions),
        ),
      );
      walkAccMeters = 0;
      walkAccSec = 0;
      walkAccPoly.clear();
      walkInstructions.clear();
      pendingWalkFromName = null;
      pendingWalkStart = null;
    }

    for (final legRaw in rawLegs) {
      final legObj = _asMap(legRaw);
      if (legObj == null) continue;
      totalDistMeters += (legObj['distanceMeters'] as num?)?.round() ?? 0;
      totalDurSec += (legObj['durationSeconds'] as num?)?.round() ?? 0;

      final steps = legObj['steps'] as List<dynamic>? ?? const [];
      for (final stepRaw in steps) {
        final stepObj = _asMap(stepRaw);
        if (stepObj == null) continue;
        final mode = (stepObj['travelMode'] as String? ?? '').toUpperCase();
        final stepDist = (stepObj['distanceMeters'] as num?)?.toDouble() ?? 0.0;
        final stepSec = (stepObj['durationSeconds'] as num?)?.round() ?? 0;
        final stepStart = _parseSinglePoint(_asMap(stepObj['startLocation']));
        final stepEnd = _parseSinglePoint(_asMap(stepObj['endLocation']));
        final rawPath = _parsePointList(stepObj['path']);
        final stepPoints = rawPath.length >= 2
            ? rawPath
            : _resolveMissingStepPolyline(
                stepDistMeters: stepDist,
                stepStart: stepStart,
                stepEnd: stepEnd,
                overviewPts: overviewPts,
              );
        final navText = (stepObj['instructions'] as String?)
            ?.replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        if (mode == 'WALKING' || mode == 'WALK') {
          pendingWalkStart ??= cursorTime;
          pendingWalkFromName ??= parsedLegs.isEmpty
              ? (originLabel.isEmpty ? 'Začetek' : originLabel)
              : parsedLegs.last.toName;
          walkAccMeters += stepDist;
          walkAccSec += stepSec;
          walkAccPoly.addAll(stepPoints);
          if (navText != null && navText.isNotEmpty) {
            walkInstructions.add(navText);
          }
        } else if (mode == 'TRANSIT') {
          final td = _asMap(stepObj['transit']) ?? const {};
          final depStop = _asMap(td['departureStop']) ?? const {};
          final arrStop = _asMap(td['arrivalStop']) ?? const {};

          final depName = depStop['name'] as String? ?? 'Postajališče';
          final arrName = arrStop['name'] as String? ?? 'Postajališče';
          final depLatLng = _parseSinglePoint(_asMap(depStop['location'])) ?? stepStart;
          final arrLatLng = _parseSinglePoint(_asMap(arrStop['location'])) ?? stepEnd;
          final matchedDepStop = _matchMarpromStop(depName, depLatLng, stopsList);
          final matchedArrStop = _matchMarpromStop(arrName, arrLatLng, stopsList);

          final depTime =
              _parseTimestamp(td['departureTimeIso'] as String?) ?? cursorTime;
          final arrTime =
              _parseTimestamp(td['arrivalTimeIso'] as String?) ??
                  depTime.add(Duration(seconds: stepSec > 0 ? stepSec : 300));

          if (walkAccMeters > 10 || walkAccPoly.isNotEmpty) {
            flushWalk(matchedDepStop?.name ?? depName, matchedDepStop?.id);
          }

          final lineMap = _asMap(td['line']) ?? const {};
          final shortName = (lineMap['shortName'] as String? ?? '').trim();
          final fullName = (lineMap['name'] as String? ?? '').trim();
          final headsign = (td['headsign'] as String? ?? fullName).trim();
          final stopCount = (td['numStops'] as num?)?.round();

          final busLeg = _buildEnrichedBusLeg(
            shortName: shortName,
            fullName: fullName,
            headsign: headsign,
            stopCount: stopCount,
            depName: depName,
            arrName: arrName,
            matchedDepStop: matchedDepStop,
            matchedArrStop: matchedArrStop,
            depTime: depTime,
            arrTime: arrTime,
            stepDist: stepDist,
            stepPoints: stepPoints,
            navText: navText,
            linesLookup: linesLookup,
            liveFleet: liveFleet,
          );
          parsedLegs.add(busLeg);
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

    return _finalizeEnrichedRoute(
      parsedLegs: parsedLegs,
      routeDist: totalDistMeters,
      routeDurSec: totalDurSec,
      totalWalkMeters: totalWalkMeters,
      totalWalkMin: totalWalkMin,
      overviewPts: overviewPts,
      now: now,
      routeIndex: routeIndex,
    );
  }

  static TripLeg _buildEnrichedBusLeg({
    required String shortName,
    required String fullName,
    required String headsign,
    required int? stopCount,
    required String depName,
    required String arrName,
    required BusStop? matchedDepStop,
    required BusStop? matchedArrStop,
    required DateTime depTime,
    required DateTime arrTime,
    required double stepDist,
    required List<LatLng> stepPoints,
    required String? navText,
    required Map<String, BusLine> linesLookup,
    required List<BusPosition> liveFleet,
  }) {
    final normShort = normalizeMarpromLineCode(shortName);
    final normFull = normalizeMarpromLineCode(fullName);
    final matchedLine = linesLookup[normShort] ??
        linesLookup[shortName.toUpperCase()] ??
        linesLookup[normFull];

    final resolvedCode =
        matchedLine?.code ?? (normShort.isNotEmpty ? normShort : shortName);
    final resolvedId = matchedLine?.id ?? resolvedCode;

    final liveBus = _findMatchingFleetBus(
      liveFleet,
      lineId: resolvedId,
      lineCode: resolvedCode,
    );

    final fleetEnriched = enrichBusLegMetrics(
      line: matchedLine,
      liveBus: liveBus,
      fromStopId: matchedDepStop?.id ?? 'glavna_postaja',
      toStopId: matchedArrStop?.id ?? 'glavni_trg',
      departureTime: depTime,
    );

    final isAccessible = (matchedLine?.isWheelchairAccessible ?? true) &&
        (matchedDepStop?.isStepFree ?? true) &&
        (matchedArrStop?.isStepFree ?? true);

    final rideMin = arrTime.difference(depTime).inMinutes.clamp(1, 240);
    return TripLeg(
      type: TripLegType.bus,
      fromName: matchedDepStop?.name ?? depName,
      toName: matchedArrStop?.name ?? arrName,
      fromStopId: matchedDepStop?.id,
      toStopId: matchedArrStop?.id,
      startTime: depTime,
      endTime: arrTime,
      durationMinutes: rideMin,
      distanceMeters:
          stepDist > 0 ? stepDist : GeoUtils.polylineLengthMeters(stepPoints),
      lineId: resolvedId,
      lineCode: resolvedCode,
      directionName: headsign.isNotEmpty ? headsign : null,
      stopCount: stopCount,
      polyline: stepPoints,
      occupancy: fleetEnriched.occupancy,
      delaySeconds: fleetEnriched.delaySeconds,
      isAccessible: isAccessible,
      vehicleClass: fleetEnriched.vehicleClass,
      vehicleModel: fleetEnriched.vehicleModel,
      passengerCount: fleetEnriched.passengerCount,
      vehicleCapacity: fleetEnriched.vehicleCapacity,
      seatedCount: fleetEnriched.seatedCount,
      seatedCapacity: fleetEnriched.seatedCapacity,
      standingCount: fleetEnriched.standingCount,
      standingCapacity: fleetEnriched.standingCapacity,
      loadPercent: fleetEnriched.loadPercent,
      isLowFloor: matchedLine?.isLowFloor ?? true,
      hasWheelchairRamp: matchedLine?.hasWheelchairRamp ?? true,
      hasWheelchairSpace: matchedLine?.hasWheelchairSpace ?? true,
      hasAudioAnnouncements: matchedLine?.hasAudioAnnouncements ?? true,
      navigationInstructions: navText != null && navText.trim().isNotEmpty
          ? [navText.trim()]
          : const [],
    );
  }

  static EnrichedTransitRoute _finalizeEnrichedRoute({
    required List<TripLeg> parsedLegs,
    required int routeDist,
    required int routeDurSec,
    required double totalWalkMeters,
    required int totalWalkMin,
    required List<LatLng> overviewPts,
    required DateTime now,
    required int routeIndex,
  }) {
    final busLegs =
        parsedLegs.where((l) => l.type == TripLegType.bus).toList(growable: false);
    final transferCount =
        busLegs.isEmpty ? 0 : (busLegs.length - 1).clamp(0, 10);

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
    final totalDurationMin = parsedLegs.isNotEmpty
        ? parsedLegs.last.endTime
            .difference(parsedLegs.first.startTime)
            .inMinutes
            .clamp(1, 360)
        : (routeDurSec / 60).ceil().clamp(1, 360);

    final option = TripOption(
      id: 'gtransit_${routeIndex}_${now.millisecondsSinceEpoch}',
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
    );

    return EnrichedTransitRoute(
      option: option,
      distanceMeters: routeDist,
      durationSeconds: routeDurSec,
      overviewPolyline: overviewPts,
    );
  }

  /// Computes realistic Marprom capacity (`<= 120`), occupancy, and punctuality
  /// metrics for a bus leg using live fleet snapshots or deterministic models.
  static ({
    BusOccupancyLevel occupancy,
    int delaySeconds,
    MarpromVehicleClass vehicleClass,
    String vehicleModel,
    int passengerCount,
    int vehicleCapacity,
    int seatedCount,
    int seatedCapacity,
    int standingCount,
    int standingCapacity,
    int loadPercent,
  }) enrichBusLegMetrics({
    required BusLine? line,
    required BusPosition? liveBus,
    required String fromStopId,
    required String toStopId,
    required DateTime departureTime,
  }) {
    if (liveBus != null) {
      return (
        occupancy: liveBus.occupancy,
        delaySeconds: liveBus.delaySeconds,
        vehicleClass: liveBus.vehicleClass,
        vehicleModel: liveBus.vehicleModel,
        passengerCount: liveBus.passengerCount.clamp(0, 120),
        vehicleCapacity: liveBus.vehicleCapacity.clamp(1, 120),
        seatedCount: liveBus.seatedCount,
        seatedCapacity: liveBus.seatedCapacity,
        standingCount: liveBus.standingCount,
        standingCapacity: liveBus.standingCapacity,
        loadPercent: liveBus.loadPercent.clamp(0, 100),
      );
    }

    final vehicleClass = line?.defaultVehicleClass ?? MarpromVehicleClass.solo12m;
    final cap = (line?.maxCapacity ?? vehicleClass.defaultMaxCapacity).clamp(1, 120);
    final seatedCap = vehicleClass.defaultSeatedCapacity;
    final standingCap = (cap - seatedCap).clamp(10, 80);

    final segOcc = _occupancyModel.estimateSegment(
      lineId: line?.id ?? 'G1',
      directionId: '${line?.id ?? 'G1'}_out',
      fromStopId: fromStopId,
      toStopId: toStopId,
      at: departureTime,
    );
    final loadPct = segOcc.loadPercent.clamp(5, 96);
    final paxCount = ((cap * loadPct) / 100).round().clamp(0, cap);
    final seated = paxCount.clamp(0, seatedCap);
    final standing = (paxCount - seated).clamp(0, standingCap);

    final delaySec = _delayModel.delaySecondsForTrip(
      tripId: '${line?.id ?? 'G1'}_${departureTime.hour}_${departureTime.minute}',
      lineId: line?.id ?? 'G1',
      scheduledTime: departureTime,
    );

    final modelName = switch (vehicleClass) {
      MarpromVehicleClass.midibus9m => 'IVECO E-WAY 9.5m',
      MarpromVehicleClass.articulated18m => "MAN Lion's City 18",
      MarpromVehicleClass.solo12m =>
        (line?.isElectricDefault ?? false) ? 'IVECO E-WAY 12m' : "MAN Lion's City 12",
    };

    return (
      occupancy: segOcc.level,
      delaySeconds: delaySec,
      vehicleClass: vehicleClass,
      vehicleModel: modelName,
      passengerCount: paxCount,
      vehicleCapacity: cap,
      seatedCount: seated,
      seatedCapacity: seatedCap,
      standingCount: standing,
      standingCapacity: standingCap,
      loadPercent: loadPct,
    );
  }

  /// Enriches an existing [TripLeg] (e.g. RAPTOR daytime suburban line fallback)
  /// with realistic capacity, live occupancy, and accessibility flags.
  static TripLeg enrichExistingBusLeg(
    TripLeg leg, {
    Map<String, BusLine>? linesById,
    List<BusPosition> liveFleet = const [],
  }) {
    if (leg.type != TripLegType.bus) return leg;
    final line = (linesById ?? seedLinesById)[leg.lineId] ??
        (linesById ?? seedLinesById)[leg.lineCode];
    final liveBus = _findMatchingFleetBus(
      liveFleet,
      lineId: leg.lineId ?? '',
      lineCode: leg.lineCode ?? '',
    );
    final metrics = enrichBusLegMetrics(
      line: line,
      liveBus: liveBus,
      fromStopId: leg.fromStopId ?? 'glavna_postaja',
      toStopId: leg.toStopId ?? 'glavni_trg',
      departureTime: leg.startTime,
    );
    return leg.copyWith(
      vehicleClass: metrics.vehicleClass,
      vehicleModel: metrics.vehicleModel,
      passengerCount: metrics.passengerCount,
      vehicleCapacity: metrics.vehicleCapacity,
      seatedCount: metrics.seatedCount,
      seatedCapacity: metrics.seatedCapacity,
      standingCount: metrics.standingCount,
      standingCapacity: metrics.standingCapacity,
      loadPercent: metrics.loadPercent,
      isLowFloor: line?.isLowFloor ?? leg.isLowFloor,
      hasWheelchairRamp: line?.hasWheelchairRamp ?? leg.hasWheelchairRamp,
      hasWheelchairSpace: line?.hasWheelchairSpace ?? leg.hasWheelchairSpace,
      hasAudioAnnouncements:
          line?.hasAudioAnnouncements ?? leg.hasAudioAnnouncements,
      delaySeconds: leg.delaySeconds != 0 ? leg.delaySeconds : metrics.delaySeconds,
      occupancy: leg.occupancy != BusOccupancyLevel.unknown
          ? leg.occupancy
          : metrics.occupancy,
    );
  }

  /// Filters [routes] when [wheelchairOnly] is enabled so every bus leg is
  /// low-floor with ramp + wheelchair space, noting skipped inaccessible routes.
  static List<TripOption> filterAccessibleOptions(
    List<TripOption> routes, {
    required bool wheelchairOnly,
    String localeCode = 'sl',
  }) {
    if (!wheelchairOnly) return routes;
    final accessible = routes.where((r) => r.isAccessible).toList();
    if (accessible.length == routes.length) return accessible;
    final note = localeCode == 'sl'
        ? 'Prikazane so samo nizkopodne trase s klančino in prostorom za invalidski voziček.'
        : 'Filtered to low-floor wheelchair-accessible buses with ramps only.';
    return [
      for (final opt in accessible)
        TripOption(
          id: opt.id,
          totalMinutes: opt.totalMinutes,
          walkMeters: opt.walkMeters,
          walkMinutes: opt.walkMinutes,
          transferCount: opt.transferCount,
          hasTightTransfer: opt.hasTightTransfer,
          tightTransferMinutes: opt.tightTransferMinutes,
          legs: opt.legs,
          freshness: opt.freshness,
          reliabilityNote: opt.reliabilityNote,
          isGoogleTransit: opt.isGoogleTransit,
          accessibleAlternativeNote: note,
        ),
    ];
  }

  static BusPosition? _findMatchingFleetBus(
    List<BusPosition> liveFleet, {
    required String lineId,
    required String lineCode,
  }) {
    for (final b in liveFleet) {
      if (b.lineId == lineId || b.lineCode == lineCode) {
        return b;
      }
    }
    return null;
  }

  static LatLng? _extractLatLng(Map<String, dynamic>? stopOrLocationMap) {
    if (stopOrLocationMap == null) return null;
    final loc = _asMap(stopOrLocationMap['location']) ?? stopOrLocationMap;
    final latLng = _asMap(loc['latLng']) ?? loc;
    final lat = (latLng['latitude'] as num?)?.toDouble();
    final lng = (latLng['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static LatLng? _parseSinglePoint(Map<String, dynamic>? map) {
    if (map == null) return null;
    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static List<LatLng> _parsePointList(dynamic rawList) {
    if (rawList is! List) return const <LatLng>[];
    final pts = <LatLng>[];
    for (final item in rawList) {
      final pt = _parseSinglePoint(_asMap(item));
      if (pt != null) pts.add(pt);
    }
    return pts;
  }

  static DateTime? _parseTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
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
      if (nearest != null && bestDist <= 240) {
        return nearest;
      }
    }
    final clean = name.trim().toLowerCase();
    for (final stop in stops) {
      final stopLower = stop.name.toLowerCase();
      if (stopLower == clean ||
          stopLower.contains(clean) ||
          clean.contains(stopLower)) {
        return stop;
      }
    }
    return null;
  }
}
