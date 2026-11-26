//**********************************************
// Resilient Gemini Multi-Model AI Transit     *
// Failover + Google Maps Grounding + GPS      *
//**********************************************

import 'dart:async';
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
import 'marprom_route_fusion.dart';

//**********************************************
// GeminiResolvedTrip & AiTransitSearchResult  *
//**********************************************

/// Structured transit intent & coordinates resolved by Gemini AI + Google Maps Grounding.
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
    this.resolvedByModel,
  });

  /// Display label for the resolved start location.
  final String originName;

  /// Geographic start point (defaults to user GPS unless overridden).
  final LatLng originPosition;

  /// Display label for the resolved destination in Maribor.
  final String destinationName;

  /// Geographic destination point resolved via Google Maps Grounding or Maribor matcher.
  final LatLng destinationPosition;

  /// True if accessibility/wheelchair preference is active or mentioned.
  final bool wheelchairOnly;

  /// `'LESS_WALKING'` or `'FEWER_TRANSFERS'` for Google Routes API v2.
  final String routingPreference;

  /// Friendly 1-sentence answer in Slovenian or English.
  final String shortReply;

  /// Model identifier (or `'local-marprom-fallback'`) that produced this result.
  final String? resolvedByModel;
}

/// Combined outcome of Gemini intent resolution + Google Routes execution.
@immutable
class AiTransitSearchResult {
  /// Creates an [AiTransitSearchResult].
  const AiTransitSearchResult({
    required this.resolvedTrip,
    required this.routes,
    this.errorMessage,
    this.debugDetails,
  });

  /// Parsed origin, destination, accessibility flag, and reply text.
  final GeminiResolvedTrip resolvedTrip;

  /// Computed Google Routes + Marprom enriched trip options.
  final List<TripOption> routes;

  /// Friendly error banner if Google Routes failed or returned zero night routes.
  final String? errorMessage;

  /// Optional collapsible technical diagnostics when Google Routes fails.
  final String? debugDetails;
}

//**********************************************
// GeminiTransitService multi-model failover   *
//**********************************************

/// Resilient Gemini AI transit resolver cycling automatically through all active
/// free-tier text models (`3.8-flash` -> `4-hydrogen`) across Grounding with
/// Google Maps and strict JSON fallback, backed by a local Maribor matcher.
class GeminiTransitService {
  /// Creates a [GeminiTransitService].
  GeminiTransitService({
    String? geminiApiKey,
    http.Client? client,
  })  : _geminiApiKeyOverride = geminiApiKey,
        _client = client ?? http.Client();

  /// Exact priority fallback list of active free-tier text/JSON Gemini models.
  static const List<String> freeTierModels = <String>[
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-3-flash-preview',
    'gemini-4-hydrogen',
  ];

  // Tight Maribor & surroundings bounding box preventing bogus geocodes.
  static const double _minLat = 46.45;
  static const double _maxLat = 46.65;
  static const double _minLng = 15.50;
  static const double _maxLng = 15.80;

  final String? _geminiApiKeyOverride;
  final http.Client _client;

  // Pin last healthy (model, useMapsGrounding) pair across session queries.
  String? _lastWorkingModel;
  bool? _lastWorkingGrounding;

  String get _apiKey => _geminiApiKeyOverride ?? ApiKeysConfig.geminiApiKey;

  //**********************************************
  // Combined Gemini Intent + Google Routes Call *
  //**********************************************

  /// Resolves [userQuery] using the Gemini free-tier failover chain, then runs
  /// [RoutePlanner.planTrip] and keeps AI vs Routes error banners clearly separated.
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

    try {
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
    } on RoutesApiException catch (e) {
      return AiTransitSearchResult(
        resolvedTrip: resolved,
        routes: const [],
        errorMessage: e.localizedMessage(localeCode),
        debugDetails: e.technicalDetails,
      );
    }
  }

  //**********************************************
  // Multi-Model & Two-Stage Grounding Failover  *
  //**********************************************

  /// Resolves [userQuery] across Pass 1 (Grounding with Google Maps) and Pass 2
  /// (strict JSON mode), falling back to a local Maribor stop/landmark matcher.
  Future<GeminiResolvedTrip> resolveQuery({
    required String userQuery,
    LatLng? userLatLng,
    bool profileWheelchairOnly = false,
    String localeCode = 'sl',
    bool allowLocalFallback = true,
  }) async {
    final key = _apiKey.trim();
    if (key.isEmpty) {
      if (allowLocalFallback) {
        final local = _tryLocalMariborMatch(
          userQuery: userQuery,
          userLocation: userLatLng,
          defaultWheelchairOnly: profileWheelchairOnly,
          localeCode: localeCode,
        );
        if (local != null) return local;
      }
      throw const GeminiApiException(401, 'Missing GEMINI_API_KEY configuration.');
    }

    final attempts = <(bool grounding, String model)>[];
    final seen = <String>{};
    void addAttempt(bool grounding, String model) {
      final sig = '$grounding|$model';
      if (seen.add(sig)) {
        attempts.add((grounding, model));
      }
    }

    // Try last proven working (model, grounding) first to minimize latency.
    if (_lastWorkingModel != null && _lastWorkingGrounding != null) {
      addAttempt(_lastWorkingGrounding!, _lastWorkingModel!);
    }
    for (final useMapsGrounding in const [true, false]) {
      for (final model in freeTierModels) {
        addAttempt(useMapsGrounding, model);
      }
    }

    final errors = <String>[];
    for (final (useMapsGrounding, model) in attempts) {
      try {
        final result = await _callSingleModel(
          apiKey: key,
          model: model,
          userQuery: userQuery,
          userLocation: userLatLng,
          defaultWheelchairOnly: profileWheelchairOnly,
          localeCode: localeCode,
          useMapsGrounding: useMapsGrounding,
        );
        _lastWorkingModel = model;
        _lastWorkingGrounding = useMapsGrounding;
        return result;
      } catch (e) {
        errors.add('$model (mapsGrounding=$useMapsGrounding): $e');
        continue;
      }
    }

    if (allowLocalFallback) {
      final local = _tryLocalMariborMatch(
        userQuery: userQuery,
        userLocation: userLatLng,
        defaultWheelchairOnly: profileWheelchairOnly,
        localeCode: localeCode,
      );
      if (local != null) {
        return local;
      }
    }

    throw GeminiApiException(
      503,
      'All Gemini models failed:\n${errors.join('\n')}',
    );
  }

  //**********************************************
  // Execute Single Gemini REST Call             *
  //**********************************************

  Future<GeminiResolvedTrip> _callSingleModel({
    required String apiKey,
    required String model,
    required String userQuery,
    required LatLng? userLocation,
    required bool defaultWheelchairOnly,
    required String localeCode,
    required bool useMapsGrounding,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
    final mobilityHint = _mentionsMobilityImpairment(userQuery);
    final effectiveWheelchair = defaultWheelchairOnly || mobilityHint;
    final defaultOrigin = userLocation ?? const LatLng(46.5547, 15.6459);

    final prompt = _buildMariborPrompt(
      userQuery: userQuery,
      defaultOrigin: defaultOrigin,
      profileWheelchairOnly: defaultWheelchairOnly,
      effectiveWheelchair: effectiveWheelchair,
      localeCode: localeCode,
    );

    final body = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      if (useMapsGrounding) ...{
        'tools': [
          {'googleMaps': {}},
        ],
        if (userLocation != null)
          'toolConfig': {
            'retrievalConfig': {
              'latLng': {
                'latitude': userLocation.latitude,
                'longitude': userLocation.longitude,
              },
            },
          },
      },
      // Only enforce JSON mime type when NOT combining with Google Maps grounding.
      if (!useMapsGrounding)
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.1,
        },
    };

    final res = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw GeminiApiException(res.statusCode, res.body);
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawText = _extractCandidateText(decoded);
    final jsonMap = extractJsonObject(rawText);

    return _buildResolvedTrip(
      jsonMap,
      fallbackOrigin: defaultOrigin,
      forceWheelchair: effectiveWheelchair,
      localeCode: localeCode,
      resolvedByModel: model,
    );
  }

  static String _extractCandidateText(Map<String, dynamic> decoded) {
    final candidates = decoded['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      throw const FormatException('Gemini returned no candidates.');
    }
    final first = candidates.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('Gemini candidate is not an object.');
    }
    final parts =
        ((first['content'] as Map<String, dynamic>?)?['parts'] as List<dynamic>?) ??
            const [];
    final text = parts
        .whereType<Map<String, dynamic>>()
        .map((p) => p['text'] as String? ?? '')
        .join('\n')
        .trim();
    if (text.isEmpty) {
      throw const FormatException('Gemini candidate text is empty.');
    }
    return text;
  }

  static String _buildMariborPrompt({
    required String userQuery,
    required LatLng defaultOrigin,
    required bool profileWheelchairOnly,
    required bool effectiveWheelchair,
    required String localeCode,
  }) {
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

    return '''
You are M-Mobilnost Maribor, a helpful Marprom city bus assistant in Maribor, Slovenia.
Resolve the passenger's transit request into exact Maribor coordinates inside (lat 46.45..46.65, lng 15.50..15.80).
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
  "destinationLat": 46.55350,
  "destinationLng": 15.65330,
  "wheelchairOnly": $effectiveWheelchair,
  "routingPreference": "${effectiveWheelchair ? 'LESS_WALKING' : 'FEWER_TRANSFERS'}",
  "shortReply": "One clear friendly sentence in the user's language (${localeCode == 'sl' ? 'Slovenian' : 'English'})."
}
```
Known Marprom places: $knownPlacesPreview
Known Marprom stops: $knownStopsPreview
User query: "$userQuery"
''';
  }

  //**********************************************
  // Defensive JSON Extraction & Coords Validation*
  //**********************************************

  /// Extracts `{...}` cleanly from fenced markdown JSON or surrounding text.
  static Map<String, dynamic> extractJsonObject(String rawText) {
    final cleaned = rawText
        .replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('Could not locate JSON block in Gemini output.');
    }
    final candidate = cleaned.substring(start, end + 1);
    final parsed = jsonDecode(candidate);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Gemini JSON root is not an object.');
    }
    return parsed;
  }

  static bool _isInMariborBox(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= _minLat &&
        lat <= _maxLat &&
        lng >= _minLng &&
        lng <= _maxLng;
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
    required String resolvedByModel,
  }) {
    final origLat = (json['originLat'] as num?)?.toDouble();
    final origLng = (json['originLng'] as num?)?.toDouble();
    final destLat = (json['destinationLat'] as num?)?.toDouble();
    final destLng = (json['destinationLng'] as num?)?.toDouble();

    final validOrig = _isInMariborBox(origLat, origLng);
    final validDest = _isInMariborBox(destLat, destLng);

    final rawDestName = (json['destinationName'] as String? ?? '').trim();
    final destName =
        rawDestName.isNotEmpty ? rawDestName : 'Glavni trg Maribor';
    final matchedPlacePos = validDest
        ? LatLng(destLat!, destLng!)
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
      originPosition: validOrig ? LatLng(origLat!, origLng!) : fallbackOrigin,
      destinationName: destName,
      destinationPosition: matchedPlacePos,
      wheelchairOnly: wheelchairOnly,
      routingPreference: routingPref,
      shortReply: (json['shortReply'] as String?)?.trim().isNotEmpty == true
          ? (json['shortReply'] as String).trim()
          : defaultReply,
      resolvedByModel: resolvedByModel,
    );
  }

  //**********************************************
  // Final Safety Net: Local Maribor Matcher     *
  //**********************************************

  static GeminiResolvedTrip? _tryLocalMariborMatch({
    required String userQuery,
    required LatLng? userLocation,
    required bool defaultWheelchairOnly,
    required String localeCode,
  }) {
    final clean = _foldDiacritics(userQuery).trim();
    if (clean.isEmpty) return null;

    final wheelchairOnly =
        defaultWheelchairOnly || _mentionsMobilityImpairment(userQuery);
    final fallbackOrigin = userLocation ?? const LatLng(46.5547, 15.6459);

    String originName =
        localeCode == 'sl' ? 'Moja lokacija' : 'My Current Location';
    LatLng originPos = fallbackOrigin;

    String destQuery = clean;
    final fromToMatch = RegExp(
      r'(?:od|from)\s+(.+?)\s+(?:do|to|na|v)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (fromToMatch != null) {
      final origPart = fromToMatch.group(1)?.trim() ?? '';
      destQuery = fromToMatch.group(2)?.trim() ?? clean;
      final origMatch = _findBestLocationMatch(origPart);
      if (origMatch != null) {
        originName = origMatch.$1;
        originPos = origMatch.$2;
      }
    } else {
      destQuery = clean
          .replaceAll(
            RegExp(
              r'\b(pelji me|peljite me|odpelji me|take me|najblizji|najbližji|nizkopodni|avtobus|bus|pot|route|do|na|v|to|in|prosim|please|invalid|vozicek)\b',
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (destQuery.isEmpty) destQuery = clean;
    }

    final destMatch =
        _findBestLocationMatch(destQuery) ?? _findBestLocationMatch(clean);
    if (destMatch == null) return null;

    final destName = destMatch.$1;
    final destPos = destMatch.$2;
    final reply = localeCode == 'sl'
        ? (wheelchairOnly
            ? 'Prikazujem dostopno nizkopodno Marprom povezavo do $destName.'
            : 'Iščem najboljšo Marprom povezavo do $destName.')
        : (wheelchairOnly
            ? 'Showing a wheelchair-accessible Marprom route to $destName.'
            : 'Finding the best Marprom route to $destName.');

    return GeminiResolvedTrip(
      originName: originName,
      originPosition: originPos,
      destinationName: destName,
      destinationPosition: destPos,
      wheelchairOnly: wheelchairOnly,
      routingPreference: wheelchairOnly ? 'LESS_WALKING' : 'FEWER_TRANSFERS',
      shortReply: reply,
      resolvedByModel: 'local-marprom-fallback',
    );
  }

  static (String, LatLng)? _findBestLocationMatch(String rawQuery) {
    final q = _foldDiacritics(rawQuery).trim();
    if (q.isEmpty) return null;

    // Built-in popular Maribor aliases for fuzzy voice queries
    const aliases = <String, String>{
      'europark': 'place_europark',
      'ukc': 'place_ukc',
      'bolnisnica': 'place_ukc',
      'bolnica': 'place_ukc',
      'hospital': 'place_ukc',
      'zelezniska': 'place_avtobusna_postaja',
      'train': 'place_avtobusna_postaja',
      'avtobusna': 'place_avtobusna_postaja',
      'pohorje': 'place_vzpenjaca',
      'vzpenjaca': 'place_vzpenjaca',
      'gondola': 'place_vzpenjaca',
      'glavni trg': 'place_glavni_trg',
      'center': 'place_glavni_trg',
      'lent': 'place_stara_trta',
      'feri': 'place_feri',
      'univerza': 'place_univerza',
      'ljudski vrt': 'place_ljudski_vrt',
      'stadion': 'place_ljudski_vrt',
      'trznica': 'place_trznica',
      'dvorana tabor': 'place_dvorana_tabor',
      'tezno': 'place_tezno_cona',
      'pobrezje': 'place_pobrezje_park',
      'kamnica': 'place_kamnica_center',
    };
    for (final entry in aliases.entries) {
      if (q.contains(entry.key)) {
        for (final place in seedPlaces) {
          if (place.id == entry.value) {
            return (place.name, place.position);
          }
        }
      }
    }

    final tokens = q.split(RegExp(r'\s+')).where((t) => t.length >= 3).toList();
    int bestScore = 0;
    (String, LatLng)? bestMatch;

    void consider(String name, LatLng pos) {
      final folded = _foldDiacritics(name);
      var score = 0;
      if (folded == q) {
        score = 100;
      } else if (folded.startsWith(q) || q.contains(folded)) {
        score = 70;
      } else if (folded.contains(q)) {
        score = 55;
      } else {
        for (final token in tokens) {
          if (folded.contains(token)) score += 20;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = (name, pos);
      }
    }

    for (final p in seedPlaces) {
      consider(p.name, p.position);
    }
    for (final s in seedStops) {
      consider(s.name, s.position);
    }
    return bestScore >= 20 ? bestMatch : null;
  }

  static String _foldDiacritics(String input) {
    return input
        .toLowerCase()
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('š', 's')
        .replaceAll('ž', 'z')
        .replaceAll('đ', 'd');
  }

  static LatLng _fallbackCoordinateForName(String name) {
    final matched = _findBestLocationMatch(name);
    if (matched != null) return matched.$2;
    return const LatLng(46.5547, 15.6459);
  }
}

/// Thrown when all Gemini models return non-200 / invalid responses and no local fallback applies.
class GeminiApiException implements Exception {
  /// Creates a [GeminiApiException].
  const GeminiApiException(this.statusCode, this.body);

  /// HTTP response status code.
  final int statusCode;

  /// Raw error payload or combined failover diagnostics.
  final String body;

  @override
  String toString() => 'GeminiApiException($statusCode): $body';
}

/// Provides the shared [GeminiTransitService] instance.
final geminiTransitServiceProvider = Provider<GeminiTransitService>((ref) {
  return GeminiTransitService();
});
