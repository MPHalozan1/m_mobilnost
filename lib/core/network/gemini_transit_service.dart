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

import '../../data/models/bus_stop.dart';
import '../../data/models/place.dart';
import '../../data/models/trip_plan.dart';
import '../../data/seed/seed_places.dart';
import '../../data/seed/seed_stops.dart';
import '../../features/trip_planner/domain/route_planner.dart';
import '../config/api_keys_config.dart';
import '../maps/google_maps_config.dart';
import '../maps/google_web_views.dart' show isFlutterTestEnvironment;
import '../utils/geo.dart';
import 'marprom_route_fusion.dart';
import 'web_directions_bridge.dart';

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

/// Disambiguated destination branch returned when a query matches multiple
/// locations in Maribor (e.g. `"mc"`, `"mekdonalds"`, `"hofer"`, `"lidl"`).
@immutable
class GeminiPlaceCandidate {
  /// Creates a [GeminiPlaceCandidate].
  const GeminiPlaceCandidate({
    required this.placeId,
    required this.name,
    required this.address,
    required this.position,
    required this.distanceMeters,
    this.nearestStopName,
    this.nearestStopId,
    this.lineIds = const [],
  });

  /// Unique place identifier.
  final String placeId;

  /// Human-readable branch name (e.g. `McDonald's Europark`).
  final String name;

  /// Street address in Maribor.
  final String address;

  /// Geographic coordinate of this branch.
  final LatLng position;

  /// Straight-line distance in meters from the user's current/origin position.
  final double distanceMeters;

  /// Closest Marprom bus stop name serving this branch.
  final String? nearestStopName;

  /// Closest Marprom bus stop ID serving this branch.
  final String? nearestStopId;

  /// Bus line codes serving the closest stop (e.g. `['G1', 'G2', 'G6']`).
  final List<String> lineIds;
}

/// Combined outcome of Gemini intent resolution + Google Routes execution.
@immutable
class AiTransitSearchResult {
  /// Creates an [AiTransitSearchResult].
  const AiTransitSearchResult({
    required this.resolvedTrip,
    required this.routes,
    this.candidates = const [],
    this.errorMessage,
    this.debugDetails,
  });

  /// Parsed origin, destination, accessibility flag, and reply text.
  final GeminiResolvedTrip resolvedTrip;

  /// Computed Google Routes + Marprom enriched trip options.
  final List<TripOption> routes;

  /// Multiple matching Maribor places when user input is ambiguous (e.g. `"mc"`).
  final List<GeminiPlaceCandidate> candidates;

  /// True when the user should pick among multiple matching branches first.
  bool get needsDisambiguation => candidates.length > 1 && routes.isEmpty;

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

  /// Resolves [userQuery] using multi-branch place matching + Gemini failover,
  /// then runs [RoutePlanner.planTrip] (or returns selectable [candidates] when
  /// more than one Maribor place matches, such as `"mc"` / `"mekdonalds"`).
  Future<AiTransitSearchResult> resolveAndPlan({
    required String userQuery,
    required RoutePlanner planner,
    LatLng? userLatLng,
    bool profileWheelchairOnly = false,
    String localeCode = 'sl',
  }) async {
    final mobilityHint = _mentionsMobilityImpairment(userQuery);
    final effectiveWheelchair = profileWheelchairOnly || mobilityHint;
    final defaultOrigin = userLatLng ?? const LatLng(46.5547, 15.6459);

    final (originName, originPos, destQuery) = _extractOriginAndDestQuery(
      userQuery: userQuery,
      fallbackOrigin: defaultOrigin,
      localeCode: localeCode,
    );

    final candidates = await findMatchingPlaceCandidates(
      query: destQuery.isEmpty ? userQuery : destQuery,
      userLatLng: originPos,
      wheelchairOnly: effectiveWheelchair,
    );

    if (candidates.length > 1) {
      final isSl = localeCode == 'sl';
      final cleanTerm = (destQuery.isEmpty ? userQuery : destQuery).trim();
      final reply = isSl
          ? 'Našel sem ${candidates.length} lokacij za "$cleanTerm". Izberite želeno spodaj ali na zemljevidu.'
          : 'Found ${candidates.length} locations for "$cleanTerm". Pick one below or on the map.';
      return AiTransitSearchResult(
        resolvedTrip: GeminiResolvedTrip(
          originName: originName,
          originPosition: originPos,
          destinationName: candidates.first.name,
          destinationPosition: candidates.first.position,
          wheelchairOnly: effectiveWheelchair,
          routingPreference:
              effectiveWheelchair ? 'LESS_WALKING' : 'FEWER_TRANSFERS',
          shortReply: reply,
          resolvedByModel: 'multi-branch-selector',
        ),
        routes: const [],
        candidates: candidates,
      );
    }

    if (candidates.length == 1) {
      return planToCandidate(
        originName: originName,
        originPosition: originPos,
        candidate: candidates.first,
        planner: planner,
        wheelchairOnly: effectiveWheelchair,
        routingPreference:
            effectiveWheelchair ? 'LESS_WALKING' : 'FEWER_TRANSFERS',
        localeCode: localeCode,
      );
    }

    final resolved = await resolveQuery(
      userQuery: userQuery,
      userLatLng: userLatLng,
      profileWheelchairOnly: profileWheelchairOnly,
      localeCode: localeCode,
    );

    return planToDestination(
      resolved: resolved,
      planner: planner,
      localeCode: localeCode,
    );
  }

  /// Plans Marprom bus routes to a specific chosen [candidate] branch.
  Future<AiTransitSearchResult> planToCandidate({
    required String originName,
    required LatLng originPosition,
    required GeminiPlaceCandidate candidate,
    required RoutePlanner planner,
    bool wheelchairOnly = false,
    String routingPreference = 'FEWER_TRANSFERS',
    String localeCode = 'sl',
  }) {
    final isSl = localeCode == 'sl';
    final resolved = GeminiResolvedTrip(
      originName: originName,
      originPosition: originPosition,
      destinationName: candidate.name,
      destinationPosition: candidate.position,
      wheelchairOnly: wheelchairOnly,
      routingPreference: wheelchairOnly ? 'LESS_WALKING' : routingPreference,
      shortReply: isSl
          ? 'Računam pot do ${candidate.name} (najbližja postaja ${candidate.nearestStopName ?? ''}).'
          : 'Routing to ${candidate.name} (nearest stop ${candidate.nearestStopName ?? ''}).',
      resolvedByModel: 'selected-place-candidate',
    );
    return planToDestination(
      resolved: resolved,
      planner: planner,
      localeCode: localeCode,
    );
  }

  /// Executes [RoutePlanner.planTrip] for an already-resolved trip intent.
  Future<AiTransitSearchResult> planToDestination({
    required GeminiResolvedTrip resolved,
    required RoutePlanner planner,
    String localeCode = 'sl',
  }) async {
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
  // Multi-Branch Place Search & Local Matcher   *
  //**********************************************

  /// Extracts `(originName, originPosition, strippedDestinationQuery)`.
  static (String, LatLng, String) _extractOriginAndDestQuery({
    required String userQuery,
    required LatLng fallbackOrigin,
    required String localeCode,
  }) {
    final clean = _foldDiacritics(userQuery).trim();
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
              r'\b(pelji me|peljite me|odpelji me|kako pridem|kako priti|take me|how do i get|route me|najblizji|najblizja|najblizje|nearest|closest|nizkopodni|avtobus|bus|pot|route|do|na|v|u|to|in|prosim|please|invalid|vozicek)\b',
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (destQuery.isEmpty) destQuery = clean;
    }

    return (originName, originPos, destQuery);
  }

  /// Finds matching Maribor locations across curated multi-branch places and
  /// (when live on Web/network) Google Places, returning >1 items when ambiguous.
  Future<List<GeminiPlaceCandidate>> findMatchingPlaceCandidates({
    required String query,
    required LatLng userLatLng,
    bool wheelchairOnly = false,
  }) async {
    final clean = _foldDiacritics(query).trim();
    if (clean.isEmpty) return const [];

    // 1. Check multi-branch chains & curated places in Maribor.
    final curated = _matchCuratedCandidates(
      cleanQuery: clean,
      userLatLng: userLatLng,
      wheelchairOnly: wheelchairOnly,
    );
    if (curated.isNotEmpty) {
      return curated;
    }

    // 2. If user searched something not in our 16 seeded landmarks or curated
    // multi-branch chains (e.g. "dm", "kavarna", "posta", "banka"), query
    // Google Places JS (Web) or Places v1 Text Search (native) bounded to Maribor.
    if (!isFlutterTestEnvironment) {
      final livePlaces = await _searchGooglePlacesInMaribor(
        query: query,
        userLatLng: userLatLng,
        wheelchairOnly: wheelchairOnly,
      );
      if (livePlaces.length > 1) {
        return livePlaces;
      }
    }

    return const [];
  }

  static List<GeminiPlaceCandidate> _matchCuratedCandidates({
    required String cleanQuery,
    required LatLng userLatLng,
    required bool wheelchairOnly,
  }) {
    final tokens = cleanQuery
        .split(RegExp(r'[\s,\-]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return const [];

    // Common Slovenian declensions / slang aliases mapped to canonical brandGroup.
    const brandKeywordGroups = <String, String>{
      'mc': 'mcdonalds',
      'mcka': 'mcdonalds',
      'mck': 'mcdonalds',
      'mek': 'mcdonalds',
      'meka': 'mcdonalds',
      'mekdonalds': 'mcdonalds',
      'mekdonaldsa': 'mcdonalds',
      'mcdonalds': 'mcdonalds',
      'mcdonaldsa': 'mcdonalds',
      'mcdonald': 'mcdonalds',
      'mac': 'mcdonalds',
      'maccas': 'mcdonalds',
      'hofer': 'hofer',
      'hofra': 'hofer',
      'hoferja': 'hofer',
      'lidl': 'lidl',
      'lidla': 'lidl',
      'spar': 'spar',
      'spara': 'spar',
      'interspar': 'spar',
      'interspara': 'spar',
      'mercator': 'mercator',
      'mercatorja': 'mercator',
      'merkator': 'mercator',
      'merkatorja': 'mercator',
      'lekarna': 'lekarna',
      'lekarne': 'lekarna',
      'lekarni': 'lekarna',
      'lekarno': 'lekarna',
      'pharmacy': 'lekarna',
      'gimnazija': 'gimnazija',
      'gimnazije': 'gimnazija',
      'gimnazijo': 'gimnazija',
      'faks': 'faks',
      'faksa': 'faks',
      'fakulteta': 'faks',
      'fakultete': 'faks',
      'fakulteto': 'faks',
    };

    String? matchedBrand;
    for (final tok in tokens) {
      final group = brandKeywordGroups[tok];
      if (group != null) {
        matchedBrand = group;
        break;
      }
    }
    if (matchedBrand == null) {
      // Also catch substring stems like "mekdonalds" or "interspar" in compound words.
      for (final entry in brandKeywordGroups.entries) {
        if (entry.key.length >= 4 && cleanQuery.contains(entry.key)) {
          matchedBrand = entry.value;
          break;
        }
      }
    }

    if (matchedBrand == null) {
      return const [];
    }

    final branchPlaces = allSearchablePlaces
        .where((p) => p.brandGroup == matchedBrand)
        .toList(growable: false);
    if (branchPlaces.length <= 1) {
      return const [];
    }

    // Check if the user already specified a specific branch (e.g. "mc europark",
    // "hofer pobrezje", "lidl titova").
    final specificMatches = <Place>[];
    final extraTokens = tokens
        .where((t) => brandKeywordGroups[t] != matchedBrand && t.length >= 2)
        .toList();
    if (extraTokens.isNotEmpty) {
      for (final p in branchPlaces) {
        final haystack = _foldDiacritics(
          '${p.name} ${p.address} ${p.aliases.join(' ')}',
        );
        if (extraTokens.every((t) => haystack.contains(t))) {
          specificMatches.add(p);
        }
      }
      if (specificMatches.length == 1) {
        return [
          _toCandidate(
            place: specificMatches.first,
            userLatLng: userLatLng,
            wheelchairOnly: wheelchairOnly,
          ),
        ];
      }
      if (specificMatches.length > 1) {
        final out = [
          for (final p in specificMatches)
            _toCandidate(
              place: p,
              userLatLng: userLatLng,
              wheelchairOnly: wheelchairOnly,
            ),
        ]..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        return out;
      }
    }

    // Return all branches for this brand sorted nearest-first!
    final candidates = [
      for (final p in branchPlaces)
        _toCandidate(
          place: p,
          userLatLng: userLatLng,
          wheelchairOnly: wheelchairOnly,
        ),
    ]..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return candidates;
  }

  static GeminiPlaceCandidate _toCandidate({
    required Place place,
    required LatLng userLatLng,
    required bool wheelchairOnly,
  }) {
    final stop = _nearestStopForPoint(
      place.position,
      preferredStopIds: place.nearestStopIds,
      wheelchairOnly: wheelchairOnly,
    );
    return GeminiPlaceCandidate(
      placeId: place.id,
      name: place.name,
      address: place.address,
      position: place.position,
      distanceMeters: GeoUtils.haversineMeters(userLatLng, place.position),
      nearestStopName: stop?.name,
      nearestStopId: stop?.id,
      lineIds: stop?.lineIds ?? const [],
    );
  }

  static BusStop? _nearestStopForPoint(
    LatLng point, {
    List<String> preferredStopIds = const [],
    bool wheelchairOnly = false,
  }) {
    final stopsById = {for (final s in seedStops) s.id: s};
    for (final id in preferredStopIds) {
      final s = stopsById[id];
      if (s != null && (!wheelchairOnly || s.isStepFree)) {
        return s;
      }
    }
    BusStop? best;
    var bestDist = double.infinity;
    for (final s in seedStops) {
      if (wheelchairOnly && !s.isStepFree) continue;
      final d = GeoUtils.haversineMeters(point, s.position);
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

  Future<List<GeminiPlaceCandidate>> _searchGooglePlacesInMaribor({
    required String query,
    required LatLng userLatLng,
    required bool wheelchairOnly,
  }) async {
    final out = <GeminiPlaceCandidate>[];
    if (WebDirectionsBridge.isSupported) {
      final jsPlaces = await WebDirectionsBridge.searchPlacesInMaribor(
        query: query,
        userLocation: userLatLng,
      );
      if (jsPlaces != null && jsPlaces.isNotEmpty) {
        for (var i = 0; i < jsPlaces.length; i++) {
          final raw = jsPlaces[i];
          final lat = (raw['lat'] as num?)?.toDouble();
          final lng = (raw['lng'] as num?)?.toDouble();
          if (lat == null || lng == null || !_isInsideMariborBounds(lat, lng)) {
            continue;
          }
          final pos = LatLng(lat, lng);
          final stop = _nearestStopForPoint(pos, wheelchairOnly: wheelchairOnly);
          out.add(
            GeminiPlaceCandidate(
              placeId: (raw['id'] as String?) ?? 'gplace_$i',
              name: (raw['name'] as String?) ?? query,
              address: (raw['address'] as String?) ?? 'Maribor',
              position: pos,
              distanceMeters: GeoUtils.haversineMeters(userLatLng, pos),
              nearestStopName: stop?.name,
              nearestStopId: stop?.id,
              lineIds: stop?.lineIds ?? const [],
            ),
          );
        }
      }
    }

    if (out.isEmpty && !kIsWeb && GoogleMapsConfig.webApiKey.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://places.googleapis.com/v1/places:searchText',
        );
        final res = await _client
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': GoogleMapsConfig.webApiKey,
                'X-Goog-FieldMask':
                    'places.id,places.displayName,places.formattedAddress,places.location',
              },
              body: jsonEncode({
                'textQuery': '$query Maribor, Slovenia',
                'maxResultCount': 8,
                'locationRestriction': {
                  'rectangle': {
                    'low': {'latitude': _minLat, 'longitude': _minLng},
                    'high': {'latitude': _maxLat, 'longitude': _maxLng},
                  },
                },
              }),
            )
            .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final list = (decoded['places'] as List?) ?? const [];
          for (var i = 0; i < list.length; i++) {
            final item = list[i] as Map<String, dynamic>;
            final loc = item['location'] as Map<String, dynamic>?;
            final lat = (loc?['latitude'] as num?)?.toDouble();
            final lng = (loc?['longitude'] as num?)?.toDouble();
            if (lat == null ||
                lng == null ||
                !_isInsideMariborBounds(lat, lng)) {
              continue;
            }
            final displayObj = item['displayName'];
            final name = displayObj is Map
                ? (displayObj['text'] as String?) ?? query
                : query;
            final pos = LatLng(lat, lng);
            final stop =
                _nearestStopForPoint(pos, wheelchairOnly: wheelchairOnly);
            out.add(
              GeminiPlaceCandidate(
                placeId: (item['id'] as String?) ?? 'rest_place_$i',
                name: name,
                address: (item['formattedAddress'] as String?) ?? 'Maribor',
                position: pos,
                distanceMeters: GeoUtils.haversineMeters(userLatLng, pos),
                nearestStopName: stop?.name,
                nearestStopId: stop?.id,
                lineIds: stop?.lineIds ?? const [],
              ),
            );
          }
        }
      } catch (_) {
        // Silently degrade to single-match Gemini flow.
      }
    }

    out.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return out;
  }

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

    final (originName, originPos, destQuery) = _extractOriginAndDestQuery(
      userQuery: userQuery,
      fallbackOrigin: fallbackOrigin,
      localeCode: localeCode,
    );

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

    for (final p in allSearchablePlaces) {
      consider(p.name, p.position);
      for (final alias in p.aliases) {
        final foldedAlias = _foldDiacritics(alias);
        if (foldedAlias.length >= 2 &&
            (q == foldedAlias || q.contains(foldedAlias))) {
          const aliasScore = 80;
          if (aliasScore > bestScore) {
            bestScore = aliasScore;
            bestMatch = (p.name, p.position);
          }
        }
      }
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

  static bool _isInsideMariborBounds(double lat, double lng) =>
      lat >= _minLat && lat <= _maxLat && lng >= _minLng && lng <= _maxLng;

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
