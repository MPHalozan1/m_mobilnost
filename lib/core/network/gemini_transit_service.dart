//**********************************************
// Gemini 2.5 Flash + Google Maps Grounding    *
//**********************************************

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../data/models/trip_plan.dart';
import '../../data/seed/seed_places.dart';
import '../../data/seed/seed_stops.dart';
import '../../features/trip_planner/domain/route_planner.dart';
import '../config/api_keys_config.dart';

//**********************************************
// GeminiResolvedTrip & AiSearchOutcome models *
//**********************************************

/// Structured intent & coordinates resolved by Gemini 2.5 Flash + Google Maps Grounding.
@immutable
class GeminiResolvedTrip {
  /// Creates a [GeminiResolvedTrip].
  const GeminiResolvedTrip({
    required this.originName,
    required this.originPosition,
    required this.destinationName,
    required this.destinationPosition,
    required this.wheelchairOnly,
    required this.routingPreference,
    required this.shortReply,
  });

  /// Display label for the resolved start location.
  final String originName;

  /// Geographic start point (defaults to user GPS unless overridden).
  final LatLng originPosition;

  /// Display label for the resolved destination in Maribor.
  final String destinationName;

  /// Geographic destination point resolved via Google Maps Grounding.
  final LatLng destinationPosition;

  /// True if accessibility/wheelchair preference is active or mentioned.
  final bool wheelchairOnly;

  /// `'LESS_WALKING'` or `'FEWER_TRANSFERS'` for Google Routes API v2.
  final String routingPreference;

  /// Friendly 1-sentence answer in Slovenian or English.
  final String shortReply;
}

/// Combined outcome of Gemini intent resolution + Google Routes execution.
@immutable
class AiTransitSearchResult {
  /// Creates an [AiTransitSearchResult].
  const AiTransitSearchResult({
    required this.resolvedTrip,
    required this.routes,
    this.errorMessage,
  });

  /// Parsed origin, destination, accessibility flag, and reply text.
  final GeminiResolvedTrip resolvedTrip;

  /// Computed Google Routes + Marprom enriched trip options.
  final List<TripOption> routes;

  /// Friendly error banner if Google Routes failed or returned zero night routes.
  final String? errorMessage;
}

//**********************************************
// GeminiTransitService implementation         *
//**********************************************

/// Uses Gemini 2.5 Flash with Grounding with Google Maps (`tools: [{googleMaps: {}}]`)
/// and user GPS (`toolConfig.retrievalConfig.latLng`) to turn natural voice/text
/// queries into instant Maribor transit routes via [GoogleRoutesService].
class GeminiTransitService {
  /// Creates a [GeminiTransitService].
  GeminiTransitService({
    String? geminiApiKey,
    http.Client? client,
  })  : _geminiApiKeyOverride = geminiApiKey,
        _client = client ?? http.Client();

  static final Uri _endpoint = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
  );

  final String? _geminiApiKeyOverride;
  final http.Client _client;

  String get _apiKey => _geminiApiKeyOverride ?? ApiKeysConfig.geminiApiKey;

  /// Resolves [userQuery] using Gemini 2.5 Flash + Google Maps Grounding, then
  /// immediately executes [RoutePlanner.planTrip] so the user gets live bus routes.
  Future<AiTransitSearchResult> resolveAndPlan({
    required String userQuery,
    required RoutePlanner planner,
    LatLng? userLatLng,
    bool profileWheelchairOnly = false,
    String localeCode = 'sl',
  }) async {
    final resolved = await resolveQuery(
      userQuery: userQuery,
      userLatLng: userLatLng,
      profileWheelchairOnly: profileWheelchairOnly,
      localeCode: localeCode,
    );

    final routes = await planner.planTrip(
      origin: resolved.originPosition,
      destination: resolved.destinationPosition,
      originLabel: resolved.originName,
      destinationLabel: resolved.destinationName,
      accessibleOnly: resolved.wheelchairOnly,
      fewerTransfers: resolved.routingPreference == 'FEWER_TRANSFERS',
      sortMode: resolved.routingPreference == 'FEWER_TRANSFERS'
          ? TripSortMode.fewestTransfers
          : TripSortMode.fastest,
      localeCode: localeCode,
    );

    return AiTransitSearchResult(
      resolvedTrip: resolved,
      routes: routes,
    );
  }

  /// Calls Gemini 2.5 Flash with Google Maps Grounding to extract coordinates,
  /// mobility preference, and a friendly 1-sentence reply.
  Future<GeminiResolvedTrip> resolveQuery({
    required String userQuery,
    LatLng? userLatLng,
    bool profileWheelchairOnly = false,
    String localeCode = 'sl',
  }) async {
    final mobilityHint = _mentionsMobilityImpairment(userQuery);
    final effectiveWheelchair = profileWheelchairOnly || mobilityHint;
    final defaultOrigin = userLatLng ?? const LatLng(46.5547, 15.6459);

    final knownStopsPreview = seedStops
        .take(36)
        .map(
          (s) =>
              '${s.name} (${s.position.latitude.toStringAsFixed(4)},${s.position.longitude.toStringAsFixed(4)})',
        )
        .join('; ');
    final knownPlacesPreview = seedPlaces
        .map(
          (p) =>
              '${p.name} (${p.position.latitude.toStringAsFixed(4)},${p.position.longitude.toStringAsFixed(4)})',
        )
        .join('; ');

    final builtSystemAndUserPrompt = '''
You are M-Mobilnost Maribor, a helpful Marprom city bus assistant in Maribor, Slovenia.
Resolve the passenger's transit request into exact Maribor coordinates using Google Maps Grounding and the known Marprom network below.
Default origin is the passenger's live GPS (${defaultOrigin.latitude.toStringAsFixed(5)}, ${defaultOrigin.longitude.toStringAsFixed(5)}) labeled "${localeCode == 'sl' ? 'Moja lokacija' : 'My Current Location'}" unless the user explicitly names another start point (e.g. "od X do Y").
Set wheelchairOnly=true if profileWheelchairOnly=$profileWheelchairOnly OR the request mentions wheelchair/disability/low-floor/hard to walk ("na vozičku", "invalid", "ne morem hoditi", "wheelchair", "nizkopodni").
When wheelchairOnly=true, routingPreference MUST be "LESS_WALKING"; otherwise "FEWER_TRANSFERS".
Respond ONLY with a single fenced JSON block:
```json
{
  "originName": "Moja lokacija",
  "originLat": ${defaultOrigin.latitude.toStringAsFixed(5)},
  "originLng": ${defaultOrigin.longitude.toStringAsFixed(5)},
  "destinationName": "Europark Maribor",
  "destinationLat": 46.55451,
  "destinationLng": 15.65147,
  "wheelchairOnly": $effectiveWheelchair,
  "routingPreference": "${effectiveWheelchair ? 'LESS_WALKING' : 'FEWER_TRANSFERS'}",
  "shortReply": "One clear friendly sentence in the user's language (${localeCode == 'sl' ? 'Slovenian' : 'English'})."
}
```
Known Marprom places: $knownPlacesPreview
Known Marprom stops: $knownStopsPreview
User query: "$userQuery"
''';

    final geminiBody = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': builtSystemAndUserPrompt},
          ],
        },
      ],
      'tools': [
        {'googleMaps': {}},
      ],
      if (userLatLng != null)
        'toolConfig': {
          'retrievalConfig': {
            'latLng': {
              'latitude': userLatLng.latitude,
              'longitude': userLatLng.longitude,
            },
          },
        },
    };

    final res = await _client
        .post(
          _endpoint,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': _apiKey,
          },
          body: jsonEncode(geminiBody),
        )
        .timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw GeminiApiException(res.statusCode, res.body);
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      throw const FormatException('Gemini returned no candidates.');
    }
    final parts = ((candidates.first['content'] as Map<String, dynamic>?)?['parts']
            as List<dynamic>?) ??
        const [];
    final rawText = parts
        .whereType<Map<String, dynamic>>()
        .map((p) => p['text'] as String? ?? '')
        .join('\n');

    final jsonMap = extractJsonObject(rawText);
    return _buildResolvedTrip(
      jsonMap,
      fallbackOrigin: defaultOrigin,
      forceWheelchair: effectiveWheelchair,
      localeCode: localeCode,
    );
  }

  /// Extracts `{...}` cleanly from fenced markdown JSON or surrounding text.
  static Map<String, dynamic> extractJsonObject(String rawText) {
    final fenceMatch =
        RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```', caseSensitive: false)
            .firstMatch(rawText);
    final candidate = fenceMatch?.group(1) ??
        (() {
          final start = rawText.indexOf('{');
          final end = rawText.lastIndexOf('}');
          if (start >= 0 && end > start) {
            return rawText.substring(start, end + 1);
          }
          return '';
        })();
    if (candidate.isEmpty) {
      throw const FormatException('Could not locate JSON block in Gemini output.');
    }
    final parsed = jsonDecode(candidate);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Gemini JSON root is not an object.');
    }
    return parsed;
  }

  static bool _mentionsMobilityImpairment(String q) {
    final lower = q.toLowerCase();
    const keywords = [
      'vozič',
      'vozic',
      'invalid',
      'ne morem hoditi',
      'težko hodim',
      'tezko hodim',
      'wheelchair',
      'nizkopod',
      'klančin',
      'klancin',
      'step-free',
      'accessibility',
      'mobility',
    ];
    return keywords.any(lower.contains);
  }

  static GeminiResolvedTrip _buildResolvedTrip(
    Map<String, dynamic> json, {
    required LatLng fallbackOrigin,
    required bool forceWheelchair,
    required String localeCode,
  }) {
    final origLat = (json['originLat'] as num?)?.toDouble();
    final origLng = (json['originLng'] as num?)?.toDouble();
    final destLat = (json['destinationLat'] as num?)?.toDouble();
    final destLng = (json['destinationLng'] as num?)?.toDouble();

    final validOrig = origLat != null &&
        origLng != null &&
        origLat >= 46.30 &&
        origLat <= 46.80 &&
        origLng >= 15.30 &&
        origLng <= 16.05;
    final validDest = destLat != null &&
        destLng != null &&
        destLat >= 46.30 &&
        destLat <= 46.80 &&
        destLng >= 15.30 &&
        destLng <= 16.05;

    final destName = (json['destinationName'] as String? ?? 'Glavni trg').trim();
    final matchedPlacePos = validDest
        ? LatLng(destLat, destLng)
        : _fallbackCoordinateForName(destName);

    final wheelchairOnly =
        forceWheelchair || (json['wheelchairOnly'] as bool? ?? false);
    final rawPref = (json['routingPreference'] as String? ?? '').toUpperCase();
    final routingPref = wheelchairOnly
        ? 'LESS_WALKING'
        : (rawPref == 'LESS_WALKING' ? 'LESS_WALKING' : 'FEWER_TRANSFERS');

    final defaultReply = localeCode == 'sl'
        ? 'Iščem najboljšo Marprom povezavo do $destName.'
        : 'Finding the best Marprom bus route to $destName.';

    return GeminiResolvedTrip(
      originName: (json['originName'] as String?)?.trim().isNotEmpty == true
          ? (json['originName'] as String).trim()
          : (localeCode == 'sl' ? 'Moja lokacija' : 'My Current Location'),
      originPosition: validOrig ? LatLng(origLat, origLng) : fallbackOrigin,
      destinationName: destName,
      destinationPosition: matchedPlacePos,
      wheelchairOnly: wheelchairOnly,
      routingPreference: routingPref,
      shortReply: (json['shortReply'] as String?)?.trim().isNotEmpty == true
          ? (json['shortReply'] as String).trim()
          : defaultReply,
    );
  }

  static LatLng _fallbackCoordinateForName(String name) {
    final q = name.toLowerCase();
    for (final place in seedPlaces) {
      if (place.name.toLowerCase().contains(q) ||
          q.contains(place.name.toLowerCase())) {
        return place.position;
      }
    }
    for (final stop in seedStops) {
      if (stop.name.toLowerCase().contains(q) ||
          q.contains(stop.name.toLowerCase())) {
        return stop.position;
      }
    }
    return const LatLng(46.5547, 15.6459);
  }
}

/// Thrown when Gemini 2.5 Flash returns a non-200 HTTP response.
class GeminiApiException implements Exception {
  /// Creates a [GeminiApiException].
  const GeminiApiException(this.statusCode, this.body);

  /// HTTP response status code.
  final int statusCode;

  /// Raw error payload.
  final String body;

  @override
  String toString() => 'GeminiApiException($statusCode): $body';
}

/// Provides the shared [GeminiTransitService] instance.
final geminiTransitServiceProvider = Provider<GeminiTransitService>((ref) {
  return GeminiTransitService();
});
