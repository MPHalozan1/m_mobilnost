//**********************************************
// Time-dependent RAPTOR & Google Transit      *
//**********************************************

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/maps/google_web_views.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/network/google_routes_service.dart';
import 'package:m_mobilnost/core/network/marprom_route_fusion.dart';
import 'package:m_mobilnost/core/network/route_geometry_service.dart';
import 'package:m_mobilnost/core/utils/distance.dart';
import 'package:m_mobilnost/core/utils/geo.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/bus_position.dart';
import 'package:m_mobilnost/data/models/bus_stop.dart';
import 'package:m_mobilnost/data/models/departure.dart';
import 'package:m_mobilnost/data/models/trip_plan.dart';
import 'package:m_mobilnost/data/repositories/line_repository.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/repositories/timetable_repository.dart';
import 'package:m_mobilnost/data/seed/seed_stops.dart';

import 'route_planner_models.dart';

export 'route_planner_models.dart';

/// Provides the [RoutePlanner] wired to [LineRepository], [TimetableRepository],
/// and Google Routes API v2 (`TRANSIT` + `DRIVE`/`WALK` road geometry).
final routePlannerProvider = Provider<RoutePlanner>((ref) {
  final liveFleet =
      ref.watch(liveBusesStreamProvider).valueOrNull ?? const <BusPosition>[];
  return RoutePlanner(
    lineRepository: ref.watch(lineRepositoryProvider),
    timetableRepository: ref.watch(timetableRepositoryProvider),
    googleRoutesService: ref.watch(googleRoutesServiceProvider),
    liveFleetProvider: () => liveFleet,
    isSimulatedLiveEnabled: () => ref.read(a11ySettingsProvider).useSimulatedLive,
    isOfflineCheck: () => ref.read(isOfflineProvider),
  );
});

/// Solves multimodal Maribor bus trips using Google Routes API (`TRANSIT`)
/// with daytime Marprom RAPTOR P-line transfer resolution backed by live
/// Google Routes `WALK` and `DRIVE` road polylines.
class RoutePlanner {
  /// Creates a [RoutePlanner] querying [lineRepository] and [timetableRepository].
  RoutePlanner({
    required LineRepository lineRepository,
    required TimetableRepository timetableRepository,
    GoogleRoutesService? googleRoutesService,
    List<BusPosition> Function()? liveFleetProvider,
    bool Function()? isSimulatedLiveEnabled,
    bool Function()? isOfflineCheck,
    DateTime Function()? clock,
  })  : _lines = lineRepository,
        _timetables = timetableRepository,
        // ignore: prefer_initializing_formals
        _googleRoutesService = googleRoutesService,
        _liveFleetProvider = liveFleetProvider ?? (() => const []),
        _isSimulatedLiveEnabled = isSimulatedLiveEnabled ?? (() => true),
        _isOfflineCheck = isOfflineCheck ?? (() => false),
        _clock = clock ?? DateTime.now;

  /// Default maximum pedestrian walk distance in meters from origin/destination.
  static const double defaultMaxWalkMeters = 850.0;

  /// Maximum inter-stop walking distance in meters during a bus transfer.
  static const double defaultMaxTransferWalkMeters = 250.0;

  /// Transfer buffer threshold in minutes triggering a tight-transfer warning.
  static const int tightTransferThresholdMinutes = 4;

  final LineRepository _lines;
  final TimetableRepository _timetables;
  final GoogleRoutesService? _googleRoutesService;
  final List<BusPosition> Function() _liveFleetProvider;
  final bool Function() _isSimulatedLiveEnabled;
  final bool Function() _isOfflineCheck;
  final DateTime Function() _clock;

  /// Returns the current timestamp from the configured clock.
  DateTime currentTime() => _clock();

  /// Finds up to [maxResults] (default 3) ranked [TripOption]s between [origin]
  /// and [destination] using Google Routes v2 (`TRANSIT`) first and resolving
  /// local daytime Marprom P-lines with real Google `WALK`/`DRIVE` road polylines.
  Future<List<TripOption>> planTrip({
    required LatLng origin,
    required LatLng destination,
    String originLabel = '',
    String destinationLabel = '',
    TripTimeMode mode = TripTimeMode.leaveNow,
    DateTime? targetTime,
    bool accessibleOnly = false,
    bool fewerTransfers = false,
    TripSortMode sortMode = TripSortMode.fastest,
    double maxWalkMeters = defaultMaxWalkMeters,
    double maxTransferWalkMeters = defaultMaxTransferWalkMeters,
    bool? useSimulatedLive,
    bool isOffline = false,
    int maxResults = 3,
    String localeCode = 'sl',
  }) async {
    final anchorTime = targetTime ?? _clock();
    final effectiveLive =
        (useSimulatedLive ?? _isSimulatedLiveEnabled()) &&
            !isOffline &&
            !_isOfflineCheck();
    final effectiveFewerTransfers =
        fewerTransfers || sortMode == TripSortMode.fewestTransfers;

    final allStops = await _lines.getStops();
    final allLines = await _lines.getLines();
    final linesById = {for (final line in allLines) line.id: line};
    final marpromByCode = <String, BusLine>{
      for (final line in allLines) line.code.toUpperCase(): line,
      for (final line in allLines) line.id.toUpperCase(): line,
    };
    final liveFleet = _liveFleetProvider();

    final routesService = _googleRoutesService;
    final useLiveGoogleRoutes = routesService != null &&
        !isOffline &&
        !_isOfflineCheck() &&
        !isFlutterTestEnvironment;

    // 1. Primary path: Live Google Routes API v2 TRANSIT (BUS)
    final googleOptions = <TripOption>[];
    if (useLiveGoogleRoutes) {
      final enrichedRoutes = await routesService.computePassengerTransitRoutes(
        origin: origin,
        destination: destination,
        transitPreference: accessibleOnly
            ? 'LESS_WALKING'
            : (effectiveFewerTransfers ? 'FEWER_TRANSFERS' : 'LESS_WALKING'),
        languageCode: localeCode,
        departureTime: mode == TripTimeMode.arriveBy ? null : anchorTime,
        arrivalTime: mode == TripTimeMode.arriveBy ? anchorTime : null,
        marpromLinesByCode: marpromByCode,
        marpromStops: allStops,
        liveFleet: liveFleet,
        originLabel: originLabel,
        destinationLabel: destinationLabel,
      );

      for (final item in enrichedRoutes) {
        googleOptions.add(item.option);
      }

      if (googleOptions.isNotEmpty) {
        final filtered = MarpromRouteFusion.filterAccessibleOptions(
          googleOptions,
          wheelchairOnly: accessibleOnly,
          localeCode: localeCode,
        );
        if (filtered.isNotEmpty) {
          return _rankAndSelect(
            filtered,
            mode: mode,
            fewerTransfers: effectiveFewerTransfers,
            maxResults: maxResults,
          );
        }
      }
    }

    // 2. Local Marprom schedule search (for daytime P-lines missing from Google GTFS,
    //    plus headless unit tests). Late night (23:15 - 05:00) on live returns empty.
    final isLateNight =
        anchorTime.hour >= 23 && anchorTime.minute >= 15 || anchorTime.hour < 5;
    if (useLiveGoogleRoutes && isLateNight) {
      return const [];
    }

    final stopsById = {for (final s in allStops) s.id: s};
    final eligibleStops = allStops
        .where((s) => !accessibleOnly || s.isStepFree)
        .toList(growable: false);
    final eligibleLines = allLines
        .where((l) => !accessibleOnly || l.isWheelchairAccessible)
        .toList(growable: false);

    if (eligibleStops.isEmpty || eligibleLines.isEmpty) {
      return const [];
    }

    final originStops = _stopsWithinRadius(origin, eligibleStops, maxWalkMeters);
    final destStops = _stopsWithinRadius(
      destination,
      eligibleStops,
      maxWalkMeters,
    );
    if (originStops.isEmpty || destStops.isEmpty) {
      return const [];
    }

    final ctx = _PlannerContext(
      origin: origin,
      destination: destination,
      originLabel: originLabel,
      destinationLabel: destinationLabel,
      anchorTime: anchorTime,
      mode: mode,
      effectiveLive: effectiveLive,
      isOffline: isOffline,
      accessibleOnly: accessibleOnly,
      maxTransferWalkMeters:
          maxTransferWalkMeters < maxWalkMeters ? maxTransferWalkMeters : maxWalkMeters,
      stopsById: stopsById,
      eligibleStops: eligibleStops,
      eligibleLines: eligibleLines,
      originWalkMeters: {for (final e in originStops) e.$1.id: e.$2},
      destWalkMeters: {for (final e in destStops) e.$1.id: e.$2},
      timetables: _timetables,
    );

    final rawOptions = mode == TripTimeMode.arriveBy
        ? await _searchBackward(ctx)
        : await _searchForward(ctx);

    final selected = _rankAndSelect(
      rawOptions,
      mode: mode,
      fewerTransfers: effectiveFewerTransfers,
      maxResults: maxResults,
    );

    final enrichedFleetOptions = [
      for (final opt in selected)
        TripOption(
          id: opt.id,
          totalMinutes: opt.totalMinutes,
          walkMeters: opt.walkMeters,
          walkMinutes: opt.walkMinutes,
          transferCount: opt.transferCount,
          hasTightTransfer: opt.hasTightTransfer,
          tightTransferMinutes: opt.tightTransferMinutes,
          legs: [
            for (final leg in opt.legs)
              (effectiveLive && leg.type == TripLegType.bus)
                  ? MarpromRouteFusion.enrichExistingBusLeg(
                      leg,
                      linesById: linesById,
                      liveFleet: liveFleet,
                    )
                  : leg,
          ],
          freshness: opt.freshness,
          reliabilityNote: opt.reliabilityNote,
          isGoogleTransit: opt.isGoogleTransit,
        ),
    ];

    if (!useLiveGoogleRoutes || enrichedFleetOptions.isEmpty) {
      return enrichedFleetOptions;
    }

    // Fetch real Google Routes WALK & DRIVE polylines for every leg — zero straight lines
    return _hydrateGoogleRoadAndWalkPolylines(
      enrichedFleetOptions,
      routesService,
      linesById: linesById,
      stopsById: stopsById,
    );
  }

  /// Hydrates every WALK and BUS leg in [options] with live Google Routes v2
  /// road/sidewalk polylines (`travelMode: WALK` and `computeBusLineRoadPath`).
  Future<List<TripOption>> _hydrateGoogleRoadAndWalkPolylines(
    List<TripOption> options,
    GoogleRoutesService routesService, {
    required Map<String, BusLine> linesById,
    required Map<String, BusStop> stopsById,
  }) async {
    const roadOverrides = <String, LatLng>{
      'europark': LatLng(46.55451, 15.65147),
    };

    final hydrated = <TripOption>[];
    for (final opt in options) {
      final newLegs = <TripLeg>[];
      for (final leg in opt.legs) {
        if (leg.type == TripLegType.walk && leg.polyline.length >= 2) {
          final start = leg.polyline.first;
          final end = leg.polyline.last;
          if (GeoUtils.haversineMeters(start, end) > 25) {
            final walkPoly = await routesService.computeWalkPolyline(start, end);
            newLegs.add(
              walkPoly.length >= 2 ? leg.copyWith(polyline: walkPoly) : leg,
            );
            continue;
          }
          newLegs.add(leg);
        } else if (leg.type == TripLegType.bus) {
          final line = linesById[leg.lineId];
          final dir = line?.directionById(leg.directionId ?? '') ??
              line?.directions.firstOrNull;
          if (line != null && dir != null && dir.stopIds.length >= 2) {
            final ordered = [
              for (var i = 0; i < dir.stopIds.length; i++)
                roadOverrides[dir.stopIds[i]] ??
                    stopsById[dir.stopIds[i]]?.position ??
                    seedStopsById[dir.stopIds[i]]?.position ??
                    dir.polyline[i],
            ];
            final fullRoad = await routesService.computeBusLineRoadPath(
              lineId: line.id,
              orderedStops: ordered,
              line: line,
              cacheKey: '${line.id}|${dir.id}',
            );
            if (fullRoad.length >= 2) {
              final boardPos = stopsById[leg.fromStopId]?.position ??
                  (leg.polyline.isNotEmpty ? leg.polyline.first : fullRoad.first);
              final alightPos = stopsById[leg.toStopId]?.position ??
                  (leg.polyline.isNotEmpty ? leg.polyline.last : fullRoad.last);
              final sliced = slicePolylineBetweenPoints(
                fullRoad,
                boardPos,
                alightPos,
              );
              newLegs.add(leg.copyWith(polyline: sliced));
              continue;
            }
          }
          newLegs.add(leg);
        } else {
          newLegs.add(leg);
        }
      }
      hydrated.add(
        TripOption(
          id: opt.id,
          totalMinutes: opt.totalMinutes,
          walkMeters: opt.walkMeters,
          walkMinutes: opt.walkMinutes,
          transferCount: opt.transferCount,
          hasTightTransfer: opt.hasTightTransfer,
          tightTransferMinutes: opt.tightTransferMinutes,
          legs: newLegs,
          freshness: opt.freshness,
          reliabilityNote: opt.reliabilityNote,
          isGoogleTransit: true,
        ),
      );
    }
    return hydrated;
  }

  /// Finds nearby walkable stops that can reach [destination] (0 or 1 transfer),
  /// sorted strictly by **earliest total arrival time** rather than distance.
  Future<List<NearestStopResult>> findNearestStopsToDestination({
    required LatLng origin,
    required LatLng destination,
    String originLabel = '',
    String destinationLabel = '',
    DateTime? at,
    double maxWalkMeters = 1200.0,
    bool accessibleOnly = false,
    bool? useSimulatedLive,
    bool isOffline = false,
    int limit = 5,
    List<String> preferredDestinationStopIds = const [],
  }) async {
    final startTime = at ?? _clock();
    final effectiveLive =
        (useSimulatedLive ?? _isSimulatedLiveEnabled()) &&
            !isOffline &&
            !_isOfflineCheck();

    final allStops = await _lines.getStops();
    final allLines = await _lines.getLines();
    final stopsById = {for (final s in allStops) s.id: s};
    final linesById = {for (final l in allLines) l.id: l};

    final eligibleStops = allStops
        .where((s) => !accessibleOnly || s.isStepFree)
        .toList(growable: false);
    final eligibleLines = allLines
        .where((l) => !accessibleOnly || l.isWheelchairAccessible)
        .toList(growable: false);

    final nearbyOrigin = _stopsWithinRadius(origin, eligibleStops, maxWalkMeters);
    if (nearbyOrigin.isEmpty || eligibleLines.isEmpty) return const [];

    final destStopEntries = _stopsWithinRadius(
      destination,
      eligibleStops,
      maxWalkMeters,
    );
    final destWalkMap = <String, double>{
      for (final entry in destStopEntries) entry.$1.id: entry.$2,
    };
    for (final stopId in preferredDestinationStopIds) {
      final stop = stopsById[stopId];
      if (stop == null || (accessibleOnly && !stop.isStepFree)) continue;
      destWalkMap.putIfAbsent(
        stopId,
        () => GeoUtils.haversineMeters(stop.position, destination),
      );
    }
    if (destWalkMap.isEmpty) return const [];

    final results = <NearestStopResult>[];
    final sharedCache = <String, List<Departure>>{};

    for (final (oStop, oWalkMeters) in nearbyOrigin) {
      final ctx = _PlannerContext(
        origin: origin,
        destination: destination,
        originLabel: originLabel,
        destinationLabel: destinationLabel,
        anchorTime: startTime,
        mode: TripTimeMode.leaveNow,
        effectiveLive: effectiveLive,
        isOffline: isOffline,
        accessibleOnly: accessibleOnly,
        maxTransferWalkMeters: defaultMaxTransferWalkMeters,
        stopsById: stopsById,
        eligibleStops: eligibleStops,
        eligibleLines: eligibleLines,
        originWalkMeters: {oStop.id: oWalkMeters},
        destWalkMeters: destWalkMap,
        timetables: _timetables,
        departureCache: sharedCache,
      );

      final stopOptions = await _searchForward(ctx);
      if (stopOptions.isEmpty) continue;

      final rankedForStop = _rankAndSelect(
        stopOptions,
        mode: TripTimeMode.leaveNow,
        fewerTransfers: false,
        maxResults: 1,
      );
      if (rankedForStop.isEmpty) continue;

      final bestOpt = rankedForStop.first;
      final busLegs = bestOpt.legs
          .where((l) => l.type == TripLegType.bus)
          .toList(growable: false);
      if (busLegs.isEmpty) continue;

      final firstBus = busLegs.first;
      final lastBus = busLegs.last;
      final firstLine = linesById[firstBus.lineId];
      final firstDir = firstLine?.directionById(firstBus.directionId ?? '');
      final destStop = stopsById[lastBus.toStopId];
      if (firstLine == null || firstDir == null || destStop == null) continue;

      final depAtStop = await _findMatchingDeparture(
        ctx: ctx,
        line: firstLine,
        dir: firstDir,
        stopId: oStop.id,
        estimatedBoardTime: firstBus.startTime,
      );
      if (depAtStop == null) continue;

      BusStop? xferStop;
      BusLine? xferLine;
      if (busLegs.length > 1) {
        xferStop = stopsById[busLegs[1].fromStopId];
        xferLine = linesById[busLegs[1].lineId];
      }

      results.add(
        NearestStopResult(
          stop: oStop,
          walkMeters: oWalkMeters,
          walkMinutes: DistanceUtils.estimateWalkMinutes(oWalkMeters),
          line: firstLine,
          direction: firstDir,
          nextDeparture: depAtStop,
          destinationStop: destStop,
          estimatedArrivalTime: bestOpt.arrivalTime,
          totalMinutes: bestOpt.totalMinutes,
          transferCount: bestOpt.transferCount,
          transferStop: xferStop,
          transferLine: xferLine,
          tripOption: bestOpt,
        ),
      );
    }

    results.sort((a, b) {
      final arrCmp = a.estimatedArrivalTime.compareTo(b.estimatedArrivalTime);
      if (arrCmp != 0) return arrCmp;
      final xferCmp = a.transferCount.compareTo(b.transferCount);
      if (xferCmp != 0) return xferCmp;
      return a.walkMeters.compareTo(b.walkMeters);
    });

    return results.take(limit).toList(growable: false);
  }

  /// Returns the physically closest stop to [position] (optionally step-free).
  Future<BusStop?> findNearestStop(
    LatLng position, {
    bool accessibleOnly = false,
  }) async {
    final stops = await _lines.getStops();
    BusStop? best;
    var bestMeters = double.infinity;
    for (final stop in stops) {
      if (accessibleOnly && !stop.isStepFree) continue;
      final d = GeoUtils.haversineMeters(position, stop.position);
      if (d < bestMeters) {
        bestMeters = d;
        best = stop;
      }
    }
    return best;
  }

  /// Builds structured step-by-step instructions ("What do I do next?") for [option].
  List<TripStepInstruction> buildInstructions(
    TripOption option, {
    String? destinationLabel,
  }) {
    final steps = <TripStepInstruction>[];
    final legs = option.legs;
    if (legs.isEmpty) return steps;

    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      if (leg.type == TripLegType.walk) {
        final isFinalWalk = i == legs.length - 1;
        steps.add(
          TripStepInstruction(
            type: isFinalWalk
                ? TripStepType.walkToDestination
                : TripStepType.walkToStop,
            stopId: isFinalWalk ? leg.fromStopId : leg.toStopId,
            stopName: isFinalWalk
                ? (destinationLabel?.isNotEmpty == true
                    ? destinationLabel
                    : leg.toName)
                : leg.toName,
            durationMinutes: leg.durationMinutes,
            distanceMeters: leg.distanceMeters,
            startTime: leg.startTime,
            endTime: leg.endTime,
          ),
        );
        continue;
      }

      // Check if this bus leg follows a previous bus leg (directly or via transfer walk).
      TripLeg? prevBus;
      for (var j = i - 1; j >= 0; j--) {
        if (legs[j].type == TripLegType.bus) {
          prevBus = legs[j];
          break;
        }
      }
      if (prevBus != null) {
        final prevLeg = legs[i - 1];
        final waitStart = prevLeg.endTime;
        final waitMin = leg.startTime.difference(waitStart).inMinutes.clamp(0, 120);
        steps.add(
          TripStepInstruction(
            type: TripStepType.transferAt,
            stopId: leg.fromStopId,
            stopName: leg.fromName,
            durationMinutes: waitMin,
            isTightTransfer:
                option.hasTightTransfer &&
                waitMin <= tightTransferThresholdMinutes,
            startTime: waitStart,
            endTime: leg.startTime,
          ),
        );
      }

      steps.add(
        TripStepInstruction(
          type: TripStepType.boardBus,
          stopId: leg.fromStopId,
          stopName: leg.fromName,
          lineId: leg.lineId,
          lineCode: leg.lineCode,
          directionName: leg.directionName,
          startTime: leg.startTime,
          delaySeconds: leg.delaySeconds,
        ),
      );
      steps.add(
        TripStepInstruction(
          type: TripStepType.rideStops,
          stopId: leg.toStopId,
          stopName: leg.toName,
          lineId: leg.lineId,
          lineCode: leg.lineCode,
          stopCount: leg.stopCount,
          durationMinutes: leg.durationMinutes,
          startTime: leg.startTime,
          endTime: leg.endTime,
        ),
      );
      steps.add(
        TripStepInstruction(
          type: TripStepType.getOff,
          stopId: leg.toStopId,
          stopName: leg.toName,
          endTime: leg.endTime,
        ),
      );
    }

    steps.add(
      TripStepInstruction(
        type: TripStepType.arrived,
        stopName: destinationLabel?.isNotEmpty == true
            ? destinationLabel
            : legs.last.toName,
        endTime: option.arrivalTime,
      ),
    );
    return steps;
  }

  /// Forward round-based RAPTOR search for `leaveNow` and `departAt`.
  Future<List<TripOption>> _searchForward(_PlannerContext ctx) async {
    final options = <TripOption>[];

    // Round 1: record earliest Round-1 ride per (lineId, stopId) so Round 2
    // can evaluate both tight fastest paths and safer backup connections.
    final round1RidesByStop = <String, Map<String, _Leg1Arrival>>{};

    for (final line in ctx.eligibleLines) {
      for (final dir in line.directions) {
        final originIndices = <int>[];
        for (var i = 0; i < dir.stopIds.length; i++) {
          if (ctx.originWalkMeters.containsKey(dir.stopIds[i])) {
            originIndices.add(i);
          }
        }
        if (originIndices.isEmpty) continue;

        for (final oIdx in originIndices) {
          final oStopId = dir.stopIds[oIdx];
          final oStop = ctx.stopsById[oStopId];
          if (oStop == null) continue;
          final walk1Meters = ctx.originWalkMeters[oStopId]!;
          final walk1Min = DistanceUtils.estimateWalkMinutes(walk1Meters);
          final earliestBoard =
              ctx.anchorTime.add(Duration(minutes: walk1Min));

          for (var aIdx = oIdx + 1; aIdx < dir.stopIds.length; aIdx++) {
            final aStopId = dir.stopIds[aIdx];
            final aStop = ctx.stopsById[aStopId];
            if (aStop == null || (ctx.accessibleOnly && !aStop.isStepFree)) {
              continue;
            }

            final ride = await _earliestRideForward(
              ctx: ctx,
              line: line,
              dir: dir,
              fromIdx: oIdx,
              toIdx: aIdx,
              earliestBoard: earliestBoard,
            );
            if (ride == null) continue;

            // Direct 0-transfer destination check.
            if (ctx.destWalkMeters.containsKey(aStopId)) {
              options.add(
                _buildDirectOption(
                  ctx: ctx,
                  oStop: oStop,
                  dStop: aStop,
                  line: line,
                  dir: dir,
                  oIdx: oIdx,
                  dIdx: aIdx,
                  ride: ride,
                ),
              );
            }

            // Store earliest Round-1 arrival at intermediate stop per line.
            final byLine = round1RidesByStop.putIfAbsent(aStopId, () => {});
            final existing = byLine[line.id];
            final candidate = _Leg1Arrival(
              oStop: oStop,
              oIdx: oIdx,
              tStop: aStop,
              tIdx: aIdx,
              line: line,
              dir: dir,
              ride: ride,
              walk1Meters: walk1Meters,
            );
            if (existing == null ||
                candidate.ride.alightTime.isBefore(existing.ride.alightTime) ||
                (candidate.ride.alightTime == existing.ride.alightTime &&
                    candidate.walk1Meters < existing.walk1Meters)) {
              byLine[line.id] = candidate;
            }
          }
        }
      }
    }

    // Round 2: expand from every Round-1 reached stop (and short transfer footpaths).
    for (final entry in round1RidesByStop.entries) {
      final tStop1 = ctx.stopsById[entry.key];
      if (tStop1 == null) continue;
      final transferTargets = _transferStopsNear(ctx, tStop1);

      for (final leg1 in entry.value.values) {
        for (final (tStop2, xferWalkMeters) in transferTargets) {
          final xferWalkMin =
              xferWalkMeters <= 15 ? 0 : DistanceUtils.estimateWalkMinutes(xferWalkMeters);
          final arrivalAtT2 =
              leg1.ride.alightTime.add(Duration(minutes: xferWalkMin));
          final minBoard2 = arrivalAtT2.add(const Duration(minutes: 1));

          for (final l2 in ctx.eligibleLines) {
            if (l2.id == leg1.line.id) continue;
            for (final dir2 in l2.directions) {
              final tIdx2 = dir2.stopIds.indexOf(tStop2.id);
              if (tIdx2 == -1) continue;

              for (var dIdx = tIdx2 + 1; dIdx < dir2.stopIds.length; dIdx++) {
                final dStopId = dir2.stopIds[dIdx];
                if (!ctx.destWalkMeters.containsKey(dStopId)) continue;
                if (dStopId == leg1.oStop.id) continue;
                final dStop = ctx.stopsById[dStopId];
                if (dStop == null) continue;

                final rides2 = await _ridesForwardWithSaferBackup(
                  ctx: ctx,
                  line: l2,
                  dir: dir2,
                  fromIdx: tIdx2,
                  toIdx: dIdx,
                  earliestBoard: minBoard2,
                  transferArrival: arrivalAtT2,
                );

                for (final ride2 in rides2) {
                  options.add(
                    _buildTransferOption(
                      ctx: ctx,
                      leg1: leg1,
                      tStop2: tStop2,
                      xferWalkMeters: xferWalkMeters,
                      dStop: dStop,
                      l2: l2,
                      dir2: dir2,
                      tIdx2: tIdx2,
                      dIdx: dIdx,
                      ride2: ride2,
                    ),
                  );
                }
              }
            }
          }
        }
      }
    }

    // Round 3: 2-transfer fallback when 0 and 1 transfers yield no route.
    if (options.isEmpty && round1RidesByStop.isNotEmpty) {
      final round2ByStop = <String, _TwoTransferState>{};
      for (final entry in round1RidesByStop.entries) {
        final tStop1 = ctx.stopsById[entry.key];
        if (tStop1 == null) continue;
        final transferTargets = _transferStopsNear(ctx, tStop1);
        for (final leg1 in entry.value.values) {
          for (final (tStop2, xfer1WalkMeters) in transferTargets) {
            final xfer1WalkMin = xfer1WalkMeters <= 15
                ? 0
                : DistanceUtils.estimateWalkMinutes(xfer1WalkMeters);
            final arrivalAtT2 =
                leg1.ride.alightTime.add(Duration(minutes: xfer1WalkMin));
            final minBoard2 = arrivalAtT2.add(const Duration(minutes: 1));
            for (final l2 in ctx.eligibleLines) {
              if (l2.id == leg1.line.id) continue;
              for (final dir2 in l2.directions) {
                final tIdx2 = dir2.stopIds.indexOf(tStop2.id);
                if (tIdx2 == -1) continue;
                final ride2List = await _ridesForwardWithSaferBackup(
                  ctx: ctx,
                  line: l2,
                  dir: dir2,
                  fromIdx: tIdx2,
                  toIdx: (tIdx2 + 1).clamp(0, dir2.stopIds.length - 1),
                  earliestBoard: minBoard2,
                  transferArrival: arrivalAtT2,
                );
                if (ride2List.isEmpty && tIdx2 + 1 >= dir2.stopIds.length) {
                  continue;
                }
                for (var midIdx = tIdx2 + 1;
                    midIdx < dir2.stopIds.length;
                    midIdx++) {
                  final midStopId = dir2.stopIds[midIdx];
                  final midStop = ctx.stopsById[midStopId];
                  if (midStop == null) continue;
                  final rides2 = await _ridesForwardWithSaferBackup(
                    ctx: ctx,
                    line: l2,
                    dir: dir2,
                    fromIdx: tIdx2,
                    toIdx: midIdx,
                    earliestBoard: minBoard2,
                    transferArrival: arrivalAtT2,
                  );
                  if (rides2.isEmpty) continue;
                  final bestRide2 = rides2.first;
                  final prev = round2ByStop[midStopId];
                  if (prev == null ||
                      bestRide2.alightTime.isBefore(prev.ride2.alightTime)) {
                    round2ByStop[midStopId] = _TwoTransferState(
                      leg1: leg1,
                      tStop2: tStop2,
                      xfer1WalkMeters: xfer1WalkMeters,
                      line2: l2,
                      dir2: dir2,
                      tIdx2: tIdx2,
                      midStop: midStop,
                      midIdx: midIdx,
                      ride2: bestRide2,
                    );
                  }
                }
              }
            }
          }
        }
      }

      for (final state2 in round2ByStop.values) {
        final transferTargets2 = _transferStopsNear(ctx, state2.midStop);
        for (final (tStop3, xfer2WalkMeters) in transferTargets2) {
          final xfer2WalkMin = xfer2WalkMeters <= 15
              ? 0
              : DistanceUtils.estimateWalkMinutes(xfer2WalkMeters);
          final arrivalAtT3 =
              state2.ride2.alightTime.add(Duration(minutes: xfer2WalkMin));
          final minBoard3 = arrivalAtT3.add(const Duration(minutes: 1));
          for (final l3 in ctx.eligibleLines) {
            if (l3.id == state2.line2.id) continue;
            for (final dir3 in l3.directions) {
              final tIdx3 = dir3.stopIds.indexOf(tStop3.id);
              if (tIdx3 == -1) continue;
              for (var dIdx = tIdx3 + 1; dIdx < dir3.stopIds.length; dIdx++) {
                final dStopId = dir3.stopIds[dIdx];
                if (!ctx.destWalkMeters.containsKey(dStopId)) continue;
                final dStop = ctx.stopsById[dStopId];
                if (dStop == null) continue;
                final rides3 = await _ridesForwardWithSaferBackup(
                  ctx: ctx,
                  line: l3,
                  dir: dir3,
                  fromIdx: tIdx3,
                  toIdx: dIdx,
                  earliestBoard: minBoard3,
                  transferArrival: arrivalAtT3,
                );
                if (rides3.isEmpty) continue;
                final ride3 = rides3.first;
                options.add(
                  _buildTwoTransferOption(
                    ctx: ctx,
                    state2: state2,
                    tStop3: tStop3,
                    xfer2WalkMeters: xfer2WalkMeters,
                    dStop: dStop,
                    l3: l3,
                    dir3: dir3,
                    tIdx3: tIdx3,
                    dIdx: dIdx,
                    ride3: ride3,
                  ),
                );
                if (options.length >= 12) break;
              }
              if (options.length >= 12) break;
            }
            if (options.length >= 12) break;
          }
          if (options.length >= 12) break;
        }
        if (options.length >= 12) break;
      }
    }

    return options;
  }

  /// Backward time-dependent search for `arriveBy` ensuring arrival <= anchorTime.
  Future<List<TripOption>> _searchBackward(_PlannerContext ctx) async {
    final options = <TripOption>[];

    // Direct 0-transfer options arriving on or before deadline.
    for (final line in ctx.eligibleLines) {
      for (final dir in line.directions) {
        final destIndices = <int>[];
        for (var i = 0; i < dir.stopIds.length; i++) {
          if (ctx.destWalkMeters.containsKey(dir.stopIds[i])) {
            destIndices.add(i);
          }
        }
        if (destIndices.isEmpty) continue;

        for (final dIdx in destIndices) {
          final dStopId = dir.stopIds[dIdx];
          final dStop = ctx.stopsById[dStopId]!;
          final walk2Min =
              DistanceUtils.estimateWalkMinutes(ctx.destWalkMeters[dStopId]!);
          final latestAlight =
              ctx.anchorTime.subtract(Duration(minutes: walk2Min));

          for (var oIdx = 0; oIdx < dIdx; oIdx++) {
            final oStopId = dir.stopIds[oIdx];
            if (!ctx.originWalkMeters.containsKey(oStopId)) continue;
            final oStop = ctx.stopsById[oStopId]!;

            final ride = await _latestRideBefore(
              ctx: ctx,
              line: line,
              dir: dir,
              fromIdx: oIdx,
              toIdx: dIdx,
              latestAlight: latestAlight,
            );
            if (ride == null) continue;

            options.add(
              _buildDirectOption(
                ctx: ctx,
                oStop: oStop,
                dStop: dStop,
                line: line,
                dir: dir,
                oIdx: oIdx,
                dIdx: dIdx,
                ride: ride,
              ),
            );
          }
        }
      }
    }

    // 1-transfer options arriving on or before deadline.
    for (final l2 in ctx.eligibleLines) {
      for (final dir2 in l2.directions) {
        for (var dIdx = 1; dIdx < dir2.stopIds.length; dIdx++) {
          final dStopId = dir2.stopIds[dIdx];
          if (!ctx.destWalkMeters.containsKey(dStopId)) continue;
          final dStop = ctx.stopsById[dStopId]!;
          final walk2Min =
              DistanceUtils.estimateWalkMinutes(ctx.destWalkMeters[dStopId]!);
          final latestAlight2 =
              ctx.anchorTime.subtract(Duration(minutes: walk2Min));

          for (var tIdx2 = 0; tIdx2 < dIdx; tIdx2++) {
            final tStop2Id = dir2.stopIds[tIdx2];
            final tStop2 = ctx.stopsById[tStop2Id];
            if (tStop2 == null || (ctx.accessibleOnly && !tStop2.isStepFree)) {
              continue;
            }

            final candidateRides2 = await _latestRidesBefore(
              ctx: ctx,
              line: l2,
              dir: dir2,
              fromIdx: tIdx2,
              toIdx: dIdx,
              latestAlight: latestAlight2,
              count: 2,
            );
            if (candidateRides2.isEmpty) continue;

            final transferSources = _transferStopsNear(ctx, tStop2);
            for (final ride2 in candidateRides2) {
              for (final (tStop1, xferWalkMeters) in transferSources) {
                final xferWalkMin = xferWalkMeters <= 15
                    ? 0
                    : DistanceUtils.estimateWalkMinutes(xferWalkMeters);
                final maxAlight1 = ride2.boardDep.estimatedTime
                    .subtract(Duration(minutes: 1 + xferWalkMin));

                for (final l1 in ctx.eligibleLines) {
                  if (l1.id == l2.id) continue;
                  for (final dir1 in l1.directions) {
                    final tIdx1 = dir1.stopIds.indexOf(tStop1.id);
                    if (tIdx1 <= 0) continue;

                    for (var oIdx = 0; oIdx < tIdx1; oIdx++) {
                      final oStopId = dir1.stopIds[oIdx];
                      if (!ctx.originWalkMeters.containsKey(oStopId)) continue;
                      if (oStopId == dStopId) continue;
                      final oStop = ctx.stopsById[oStopId]!;

                      final rides1 = await _ridesBackwardWithSaferBackup(
                        ctx: ctx,
                        line: l1,
                        dir: dir1,
                        fromIdx: oIdx,
                        toIdx: tIdx1,
                        latestAlight: maxAlight1,
                        transferWalkMin: xferWalkMin,
                        board2Time: ride2.boardDep.estimatedTime,
                      );

                      for (final ride1 in rides1) {
                        final leg1 = _Leg1Arrival(
                          oStop: oStop,
                          oIdx: oIdx,
                          tStop: tStop1,
                          tIdx: tIdx1,
                          line: l1,
                          dir: dir1,
                          ride: ride1,
                          walk1Meters: ctx.originWalkMeters[oStopId]!,
                        );
                        options.add(
                          _buildTransferOption(
                            ctx: ctx,
                            leg1: leg1,
                            tStop2: tStop2,
                            xferWalkMeters: xferWalkMeters,
                            dStop: dStop,
                            l2: l2,
                            dir2: dir2,
                            tIdx2: tIdx2,
                            dIdx: dIdx,
                            ride2: ride2,
                          ),
                        );
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    return options;
  }

  /// Returns candidate transfer stops within transfer-walk distance of [stop].
  List<(BusStop, double)> _transferStopsNear(_PlannerContext ctx, BusStop stop) {
    final res = <(BusStop, double)>[(stop, 0.0)];
    if (ctx.maxTransferWalkMeters <= 0) return res;
    for (final other in ctx.eligibleStops) {
      if (other.id == stop.id) continue;
      final d = GeoUtils.haversineMeters(stop.position, other.position);
      if (d <= ctx.maxTransferWalkMeters) {
        res.add((other, d));
      }
    }
    return res;
  }

  Future<_RideSegment?> _earliestRideForward({
    required _PlannerContext ctx,
    required BusLine line,
    required LineDirection dir,
    required int fromIdx,
    required int toIdx,
    required DateTime earliestBoard,
  }) async {
    final segments = await _loadRideSegments(
      ctx: ctx,
      line: line,
      dir: dir,
      fromIdx: fromIdx,
      toIdx: toIdx,
    );
    for (final seg in segments) {
      if (!seg.boardDep.estimatedTime.isBefore(earliestBoard)) {
        return seg;
      }
    }
    return null;
  }

  /// Returns the earliest valid leg-2 ride, plus a safer (>= 5 min buffer) ride
  /// if the earliest ride has a tight connection (buffer <= 4 min).
  Future<List<_RideSegment>> _ridesForwardWithSaferBackup({
    required _PlannerContext ctx,
    required BusLine line,
    required LineDirection dir,
    required int fromIdx,
    required int toIdx,
    required DateTime earliestBoard,
    required DateTime transferArrival,
  }) async {
    final segments = await _loadRideSegments(
      ctx: ctx,
      line: line,
      dir: dir,
      fromIdx: fromIdx,
      toIdx: toIdx,
    );
    final chosen = <_RideSegment>[];
    for (final seg in segments) {
      final boardAt = seg.boardDep.estimatedTime;
      if (boardAt.isBefore(earliestBoard)) continue;
      final waitMin = boardAt.difference(transferArrival).inMinutes;
      if (waitMin > 45 && chosen.isNotEmpty) break;
      if (waitMin > 60) break;

      if (chosen.isEmpty) {
        chosen.add(seg);
        if (waitMin > tightTransferThresholdMinutes) {
          break;
        }
      } else if (waitMin > tightTransferThresholdMinutes) {
        chosen.add(seg);
        break;
      }
    }
    return chosen;
  }

  Future<_RideSegment?> _latestRideBefore({
    required _PlannerContext ctx,
    required BusLine line,
    required LineDirection dir,
    required int fromIdx,
    required int toIdx,
    required DateTime latestAlight,
  }) async {
    final list = await _latestRidesBefore(
      ctx: ctx,
      line: line,
      dir: dir,
      fromIdx: fromIdx,
      toIdx: toIdx,
      latestAlight: latestAlight,
      count: 1,
    );
    return list.isEmpty ? null : list.first;
  }

  Future<List<_RideSegment>> _latestRidesBefore({
    required _PlannerContext ctx,
    required BusLine line,
    required LineDirection dir,
    required int fromIdx,
    required int toIdx,
    required DateTime latestAlight,
    int count = 1,
  }) async {
    final segments = await _loadRideSegments(
      ctx: ctx,
      line: line,
      dir: dir,
      fromIdx: fromIdx,
      toIdx: toIdx,
    );
    final valid = <_RideSegment>[];
    for (var i = segments.length - 1; i >= 0; i--) {
      final seg = segments[i];
      if (!seg.alightTime.isAfter(latestAlight)) {
        valid.add(seg);
        if (valid.length >= count) break;
      }
    }
    return valid;
  }

  Future<List<_RideSegment>> _ridesBackwardWithSaferBackup({
    required _PlannerContext ctx,
    required BusLine line,
    required LineDirection dir,
    required int fromIdx,
    required int toIdx,
    required DateTime latestAlight,
    required int transferWalkMin,
    required DateTime board2Time,
  }) async {
    final segments = await _loadRideSegments(
      ctx: ctx,
      line: line,
      dir: dir,
      fromIdx: fromIdx,
      toIdx: toIdx,
    );
    final chosen = <_RideSegment>[];
    for (var i = segments.length - 1; i >= 0; i--) {
      final seg = segments[i];
      if (seg.alightTime.isAfter(latestAlight)) continue;
      final transferArrival =
          seg.alightTime.add(Duration(minutes: transferWalkMin));
      final bufferMin = board2Time.difference(transferArrival).inMinutes;
      if (bufferMin > 60 && chosen.isNotEmpty) break;

      if (chosen.isEmpty) {
        chosen.add(seg);
        if (bufferMin > tightTransferThresholdMinutes) {
          break;
        }
      } else if (bufferMin > tightTransferThresholdMinutes) {
        chosen.add(seg);
        break;
      }
    }
    return chosen;
  }

  /// Loads and caches all non-cancelled bus rides between [fromIdx] and [toIdx].
  Future<List<_RideSegment>> _loadRideSegments({
    required _PlannerContext ctx,
    required BusLine line,
    required LineDirection dir,
    required int fromIdx,
    required int toIdx,
  }) async {
    final fromStopId = dir.stopIds[fromIdx];
    final toStopId = dir.stopIds[toIdx];

    final daysToQuery = <DateTime>[
      ctx.anchorTime,
      if (ctx.mode != TripTimeMode.arriveBy && ctx.anchorTime.hour >= 22)
        ctx.anchorTime.add(const Duration(days: 1)),
    ];

    final allFromDeps = <Departure>[];
    final allToDeps = <Departure>[];
    for (final day in daysToQuery) {
      allFromDeps.addAll(
        await _getDeparturesCached(ctx, line.id, dir.id, fromStopId, day),
      );
      allToDeps.addAll(
        await _getDeparturesCached(ctx, line.id, dir.id, toStopId, day),
      );
    }

    final toByTripKey = <String, Departure>{};
    for (final dep in allToDeps) {
      final key = _extractTripKey(dep.id, toStopId, toIdx);
      if (key != null) {
        toByTripKey[key] = dep;
      }
    }

    final fallbackRideMin =
        _estimateSegmentMinutes(dir, fromIdx, toIdx, ctx.stopsById);
    final segments = <_RideSegment>[];

    for (var i = 0; i < allFromDeps.length; i++) {
      final fromDep = allFromDeps[i];
      if (fromDep.isCancelled) continue;

      Departure? toDep;
      final tripKey = _extractTripKey(fromDep.id, fromStopId, fromIdx);
      if (tripKey != null) {
        toDep = toByTripKey[tripKey];
      }
      if (toDep == null &&
          allToDeps.length == allFromDeps.length &&
          allToDeps[i].estimatedTime.isAfter(fromDep.estimatedTime)) {
        toDep = allToDeps[i];
      }

      var alightTime = toDep?.estimatedTime ??
          fromDep.estimatedTime.add(Duration(minutes: fallbackRideMin));
      if (!alightTime.isAfter(fromDep.estimatedTime)) {
        alightTime = fromDep.estimatedTime.add(Duration(minutes: fallbackRideMin));
      }

      segments.add(
        _RideSegment(
          boardDep: fromDep,
          alightTime: alightTime,
          rideMinutes: alightTime
              .difference(fromDep.estimatedTime)
              .inMinutes
              .clamp(1, 180),
        ),
      );
    }

    segments.sort(
      (a, b) => a.boardDep.estimatedTime.compareTo(b.boardDep.estimatedTime),
    );
    return segments;
  }

  Future<List<Departure>> _getDeparturesCached(
    _PlannerContext ctx,
    String lineId,
    String directionId,
    String stopId,
    DateTime day,
  ) async {
    final dayKey = '${day.year}-${day.month}-${day.day}';
    final cacheKey = '$lineId|$directionId|$stopId|$dayKey';
    final cached = ctx.departureCache[cacheKey];
    if (cached != null) return cached;

    final deps = await ctx.timetables.getDeparturesForLine(
      lineId,
      directionId,
      at: day,
      stopId: stopId,
      useSimulatedLive: ctx.effectiveLive,
      isOffline: ctx.isOffline,
    );
    ctx.departureCache[cacheKey] = deps;
    return deps;
  }

  Future<Departure?> _findMatchingDeparture({
    required _PlannerContext ctx,
    required BusLine line,
    required LineDirection dir,
    required String stopId,
    required DateTime estimatedBoardTime,
  }) async {
    final deps = await _getDeparturesCached(
      ctx,
      line.id,
      dir.id,
      stopId,
      estimatedBoardTime,
    );
    for (final dep in deps) {
      if (!dep.isCancelled && dep.estimatedTime == estimatedBoardTime) {
        return dep;
      }
    }
    return deps.where((d) => !d.isCancelled).firstOrNull;
  }

  String? _extractTripKey(String depId, String stopId, int stopIdx) {
    final suffix = '_${stopId}_$stopIdx';
    if (depId.endsWith(suffix)) {
      return depId.substring(0, depId.length - suffix.length);
    }
    return null;
  }

  TripOption _buildDirectOption({
    required _PlannerContext ctx,
    required BusStop oStop,
    required BusStop dStop,
    required BusLine line,
    required LineDirection dir,
    required int oIdx,
    required int dIdx,
    required _RideSegment ride,
  }) {
    final walk1Meters = ctx.originWalkMeters[oStop.id]!;
    final walk2Meters = ctx.destWalkMeters[dStop.id]!;
    final walk1Min =
        walk1Meters <= 15 ? 0 : DistanceUtils.estimateWalkMinutes(walk1Meters);
    final walk2Min =
        walk2Meters <= 15 ? 0 : DistanceUtils.estimateWalkMinutes(walk2Meters);

    final boardAt = ride.boardDep.estimatedTime;
    final alightAt = ride.alightTime;
    final start = boardAt.subtract(Duration(minutes: walk1Min));
    final end = alightAt.add(Duration(minutes: walk2Min));

    final legs = <TripLeg>[
      if (walk1Meters > 15)
        _walkLeg(
          fromName: ctx.originLabel,
          toName: oStop.name,
          toStopId: oStop.id,
          start: start,
          end: boardAt,
          minutes: walk1Min,
          meters: walk1Meters,
          fromPos: ctx.origin,
          toPos: oStop.position,
        ),
      _busLeg(
        fromStop: oStop,
        toStop: dStop,
        line: line,
        dir: dir,
        fromIdx: oIdx,
        toIdx: dIdx,
        ride: ride,
      ),
      if (walk2Meters > 15)
        _walkLeg(
          fromName: dStop.name,
          toName: ctx.destinationLabel,
          fromStopId: dStop.id,
          start: alightAt,
          end: end,
          minutes: walk2Min,
          meters: walk2Meters,
          fromPos: dStop.position,
          toPos: ctx.destination,
        ),
    ];

    final delayNote =
        ride.boardDep.delaySeconds > 120 ? 'simulated_delay' : null;

    return TripOption(
      id: 'direct_${line.id}_${oStop.id}_${dStop.id}_${boardAt.millisecondsSinceEpoch}',
      totalMinutes: end.difference(start).inMinutes.clamp(1, 360),
      walkMeters: walk1Meters + walk2Meters,
      walkMinutes: walk1Min + walk2Min,
      transferCount: 0,
      hasTightTransfer: false,
      legs: legs,
      freshness: ride.boardDep.freshness,
      reliabilityNote: delayNote,
    );
  }

  TripOption _buildTransferOption({
    required _PlannerContext ctx,
    required _Leg1Arrival leg1,
    required BusStop tStop2,
    required double xferWalkMeters,
    required BusStop dStop,
    required BusLine l2,
    required LineDirection dir2,
    required int tIdx2,
    required int dIdx,
    required _RideSegment ride2,
  }) {
    final walk1Meters = leg1.walk1Meters;
    final walk2Meters = ctx.destWalkMeters[dStop.id]!;
    final walk1Min =
        walk1Meters <= 15 ? 0 : DistanceUtils.estimateWalkMinutes(walk1Meters);
    final xferWalkMin = xferWalkMeters <= 15
        ? 0
        : DistanceUtils.estimateWalkMinutes(xferWalkMeters);
    final walk2Min =
        walk2Meters <= 15 ? 0 : DistanceUtils.estimateWalkMinutes(walk2Meters);

    final start = leg1.ride.boardDep.estimatedTime
        .subtract(Duration(minutes: walk1Min));
    final alight1 = leg1.ride.alightTime;
    final arriveT2 = alight1.add(Duration(minutes: xferWalkMin));
    final board2 = ride2.boardDep.estimatedTime;
    final alight2 = ride2.alightTime;
    final end = alight2.add(Duration(minutes: walk2Min));

    final bufferMin = board2.difference(arriveT2).inMinutes;
    final isTight = bufferMin <= tightTransferThresholdMinutes;

    final legs = <TripLeg>[
      if (walk1Meters > 15)
        _walkLeg(
          fromName: ctx.originLabel,
          toName: leg1.oStop.name,
          toStopId: leg1.oStop.id,
          start: start,
          end: leg1.ride.boardDep.estimatedTime,
          minutes: walk1Min,
          meters: walk1Meters,
          fromPos: ctx.origin,
          toPos: leg1.oStop.position,
        ),
      _busLeg(
        fromStop: leg1.oStop,
        toStop: leg1.tStop,
        line: leg1.line,
        dir: leg1.dir,
        fromIdx: leg1.oIdx,
        toIdx: leg1.tIdx,
        ride: leg1.ride,
      ),
      if (xferWalkMeters > 15 && leg1.tStop.id != tStop2.id)
        _walkLeg(
          fromName: leg1.tStop.name,
          toName: tStop2.name,
          fromStopId: leg1.tStop.id,
          toStopId: tStop2.id,
          start: alight1,
          end: arriveT2,
          minutes: xferWalkMin,
          meters: xferWalkMeters,
          fromPos: leg1.tStop.position,
          toPos: tStop2.position,
        ),
      _busLeg(
        fromStop: tStop2,
        toStop: dStop,
        line: l2,
        dir: dir2,
        fromIdx: tIdx2,
        toIdx: dIdx,
        ride: ride2,
      ),
      if (walk2Meters > 15)
        _walkLeg(
          fromName: dStop.name,
          toName: ctx.destinationLabel,
          fromStopId: dStop.id,
          start: alight2,
          end: end,
          minutes: walk2Min,
          meters: walk2Meters,
          fromPos: dStop.position,
          toPos: ctx.destination,
        ),
    ];

    final hasDelay =
        leg1.ride.boardDep.delaySeconds > 120 ||
        ride2.boardDep.delaySeconds > 120;

    return TripOption(
      id: 'xfer_${leg1.line.id}_${l2.id}_${leg1.tStop.id}_${tStop2.id}_'
          '${leg1.ride.boardDep.estimatedTime.millisecondsSinceEpoch}_'
          '${ride2.boardDep.estimatedTime.millisecondsSinceEpoch}',
      totalMinutes: end.difference(start).inMinutes.clamp(1, 360),
      walkMeters: walk1Meters + xferWalkMeters + walk2Meters,
      walkMinutes: walk1Min + xferWalkMin + walk2Min,
      transferCount: 1,
      hasTightTransfer: isTight,
      tightTransferMinutes: isTight ? bufferMin : null,
      legs: legs,
      freshness: leg1.ride.boardDep.freshness,
      reliabilityNote: isTight
          ? 'tight_transfer'
          : (hasDelay ? 'simulated_delay' : null),
    );
  }

  TripOption _buildTwoTransferOption({
    required _PlannerContext ctx,
    required _TwoTransferState state2,
    required BusStop tStop3,
    required double xfer2WalkMeters,
    required BusStop dStop,
    required BusLine l3,
    required LineDirection dir3,
    required int tIdx3,
    required int dIdx,
    required _RideSegment ride3,
  }) {
    final leg1 = state2.leg1;
    final walk1Meters = leg1.walk1Meters;
    final walk1Min = DistanceUtils.estimateWalkMinutes(walk1Meters);
    final xfer1WalkMin = state2.xfer1WalkMeters <= 15
        ? 0
        : DistanceUtils.estimateWalkMinutes(state2.xfer1WalkMeters);
    final xfer2WalkMin = xfer2WalkMeters <= 15
        ? 0
        : DistanceUtils.estimateWalkMinutes(xfer2WalkMeters);
    final walk2Meters = ctx.destWalkMeters[dStop.id]!;
    final walk2Min = DistanceUtils.estimateWalkMinutes(walk2Meters);

    final start =
        leg1.ride.boardDep.estimatedTime.subtract(Duration(minutes: walk1Min));
    final alight1 = leg1.ride.alightTime;
    final xfer1Arr = alight1.add(Duration(minutes: xfer1WalkMin));
    final buf1 = state2.ride2.boardDep.estimatedTime.difference(xfer1Arr).inMinutes;

    final alight2 = state2.ride2.alightTime;
    final xfer2Arr = alight2.add(Duration(minutes: xfer2WalkMin));
    final buf2 = ride3.boardDep.estimatedTime.difference(xfer2Arr).inMinutes;

    final alight3 = ride3.alightTime;
    final end = alight3.add(Duration(minutes: walk2Min));
    final minBuf = buf1 < buf2 ? buf1 : buf2;
    final isTight = minBuf <= tightTransferThresholdMinutes;

    final legs = <TripLeg>[
      if (walk1Meters > 15)
        _walkLeg(
          fromName: ctx.originLabel,
          toName: leg1.oStop.name,
          toStopId: leg1.oStop.id,
          start: start,
          end: leg1.ride.boardDep.estimatedTime,
          minutes: walk1Min,
          meters: walk1Meters,
          fromPos: ctx.origin,
          toPos: leg1.oStop.position,
        ),
      _busLeg(
        fromStop: leg1.oStop,
        toStop: leg1.tStop,
        line: leg1.line,
        dir: leg1.dir,
        fromIdx: leg1.oIdx,
        toIdx: leg1.tIdx,
        ride: leg1.ride,
      ),
      if (state2.xfer1WalkMeters > 15)
        _walkLeg(
          fromName: leg1.tStop.name,
          toName: state2.tStop2.name,
          fromStopId: leg1.tStop.id,
          toStopId: state2.tStop2.id,
          start: alight1,
          end: xfer1Arr,
          minutes: xfer1WalkMin,
          meters: state2.xfer1WalkMeters,
          fromPos: leg1.tStop.position,
          toPos: state2.tStop2.position,
        ),
      _busLeg(
        fromStop: state2.tStop2,
        toStop: state2.midStop,
        line: state2.line2,
        dir: state2.dir2,
        fromIdx: state2.tIdx2,
        toIdx: state2.midIdx,
        ride: state2.ride2,
      ),
      if (xfer2WalkMeters > 15)
        _walkLeg(
          fromName: state2.midStop.name,
          toName: tStop3.name,
          fromStopId: state2.midStop.id,
          toStopId: tStop3.id,
          start: alight2,
          end: xfer2Arr,
          minutes: xfer2WalkMin,
          meters: xfer2WalkMeters,
          fromPos: state2.midStop.position,
          toPos: tStop3.position,
        ),
      _busLeg(
        fromStop: tStop3,
        toStop: dStop,
        line: l3,
        dir: dir3,
        fromIdx: tIdx3,
        toIdx: dIdx,
        ride: ride3,
      ),
      if (walk2Meters > 15)
        _walkLeg(
          fromName: dStop.name,
          toName: ctx.destinationLabel,
          fromStopId: dStop.id,
          start: alight3,
          end: end,
          minutes: walk2Min,
          meters: walk2Meters,
          fromPos: dStop.position,
          toPos: ctx.destination,
        ),
    ];

    return TripOption(
      id: 'xfer2_${leg1.line.id}_${state2.line2.id}_${l3.id}_'
          '${leg1.ride.boardDep.estimatedTime.millisecondsSinceEpoch}',
      totalMinutes: end.difference(start).inMinutes.clamp(1, 360),
      walkMeters: walk1Meters + state2.xfer1WalkMeters + xfer2WalkMeters + walk2Meters,
      walkMinutes: walk1Min + xfer1WalkMin + xfer2WalkMin + walk2Min,
      transferCount: 2,
      hasTightTransfer: isTight,
      tightTransferMinutes: isTight ? minBuf : null,
      legs: legs,
      freshness: leg1.ride.boardDep.freshness,
      reliabilityNote: isTight ? 'tight_transfer' : null,
    );
  }

  List<TripOption> _rankAndSelect(
    List<TripOption> options, {
    required TripTimeMode mode,
    required bool fewerTransfers,
    required int maxResults,
  }) {
    if (options.isEmpty) return const [];

    // Deduplicate identical corridor + safety tier, keeping the superior timing.
    final bestByKey = <String, TripOption>{};
    for (final opt in options) {
      final corridor = opt.legs
          .where((l) => l.type == TripLegType.bus)
          .map((l) => '${l.lineId}:${l.directionId}')
          .join('|');
      final key = '$corridor|tight=${opt.hasTightTransfer}';
      final prev = bestByKey[key];
      if (prev == null || _isBetter(opt, prev, mode: mode, fewerTransfers: fewerTransfers)) {
        bestByKey[key] = opt;
      }
    }

    final ranked = bestByKey.values.toList();
    ranked.sort((a, b) => _compareOptions(a, b, mode: mode, fewerTransfers: fewerTransfers));

    if (ranked.length <= maxResults) {
      return ranked;
    }

    final selected = ranked.take(maxResults).toList();
    // Guarantee at least one non-tight safer option when the top option is tight.
    if (selected.first.hasTightTransfer &&
        selected.every((opt) => opt.hasTightTransfer)) {
      final safer = ranked
          .skip(maxResults)
          .where((opt) => !opt.hasTightTransfer)
          .firstOrNull;
      if (safer != null && selected.isNotEmpty) {
        selected[selected.length - 1] = safer;
      }
    }
    return List<TripOption>.unmodifiable(selected);
  }

  bool _isBetter(
    TripOption candidate,
    TripOption incumbent, {
    required TripTimeMode mode,
    required bool fewerTransfers,
  }) =>
      _compareOptions(
        candidate,
        incumbent,
        mode: mode,
        fewerTransfers: fewerTransfers,
      ) <
      0;

  int _compareOptions(
    TripOption a,
    TripOption b, {
    required TripTimeMode mode,
    required bool fewerTransfers,
  }) {
    if (fewerTransfers && a.transferCount != b.transferCount) {
      return a.transferCount.compareTo(b.transferCount);
    }

    final timeCmp = mode == TripTimeMode.arriveBy
        ? b.departureTime.compareTo(a.departureTime)
        : a.arrivalTime.compareTo(b.arrivalTime);
    if (timeCmp != 0) return timeCmp;

    final xferCmp = a.transferCount.compareTo(b.transferCount);
    if (xferCmp != 0) return xferCmp;

    final durCmp = a.totalMinutes.compareTo(b.totalMinutes);
    if (durCmp != 0) return durCmp;

    return a.walkMeters.compareTo(b.walkMeters);
  }

  List<(BusStop, double)> _stopsWithinRadius(
    LatLng point,
    List<BusStop> stops,
    double maxWalkMeters,
  ) {
    final matches = <(BusStop, double)>[];
    for (final stop in stops) {
      final dist = GeoUtils.haversineMeters(point, stop.position);
      if (dist <= maxWalkMeters) {
        matches.add((stop, dist));
      }
    }
    matches.sort((a, b) => a.$2.compareTo(b.$2));
    return matches;
  }

  int _estimateSegmentMinutes(
    LineDirection dir,
    int fromIdx,
    int toIdx,
    Map<String, BusStop> stopsById,
  ) {
    var totalSeconds = 0;
    for (var i = fromIdx; i < toIdx; i++) {
      final a = stopsById[dir.stopIds[i]]?.position;
      final b = stopsById[dir.stopIds[i + 1]]?.position;
      final meters = (a != null && b != null)
          ? GeoUtils.haversineMeters(a, b)
          : 550.0;
      final seg = (meters / 6.67).round() + 25;
      totalSeconds += seg < 60 ? 60 : seg;
    }
    return (totalSeconds / 60.0).ceil().clamp(1, 180);
  }

  TripLeg _walkLeg({
    required String fromName,
    required String toName,
    String? fromStopId,
    String? toStopId,
    required DateTime start,
    required DateTime end,
    required int minutes,
    required double meters,
    required LatLng fromPos,
    required LatLng toPos,
  }) {
    return TripLeg(
      type: TripLegType.walk,
      fromName: fromName,
      toName: toName,
      fromStopId: fromStopId,
      toStopId: toStopId,
      startTime: start,
      endTime: end,
      durationMinutes: minutes,
      distanceMeters: meters,
      polyline: [fromPos, toPos],
      isAccessible: true,
    );
  }

  TripLeg _busLeg({
    required BusStop fromStop,
    required BusStop toStop,
    required BusLine line,
    required LineDirection dir,
    required int fromIdx,
    required int toIdx,
    required _RideSegment ride,
  }) {
    final List<LatLng> poly;
    if (dir.polyline.length > toIdx && fromIdx < toIdx) {
      // Follow the bundled road geometry of this line between the two stops.
      poly = dir.roadPathBetween(fromIdx, toIdx);
    } else {
      poly = <LatLng>[fromStop.position, toStop.position];
    }
    final boardAt = ride.boardDep.estimatedTime;
    return TripLeg(
      type: TripLegType.bus,
      fromName: fromStop.name,
      toName: toStop.name,
      fromStopId: fromStop.id,
      toStopId: toStop.id,
      startTime: boardAt,
      endTime: ride.alightTime,
      durationMinutes: ride.rideMinutes,
      distanceMeters: GeoUtils.polylineLengthMeters(poly),
      lineId: line.id,
      lineCode: line.code,
      directionId: dir.id,
      directionName: dir.name,
      stopCount: toIdx - fromIdx,
      intermediateStopIds: dir.stopIds.sublist(fromIdx, toIdx + 1),
      polyline: poly,
      occupancy: ride.boardDep.occupancy,
      delaySeconds: ride.boardDep.delaySeconds,
      isAccessible:
          line.isWheelchairAccessible && fromStop.isStepFree && toStop.isStepFree,
    );
  }
}

class _PlannerContext {
  _PlannerContext({
    required this.origin,
    required this.destination,
    required this.originLabel,
    required this.destinationLabel,
    required this.anchorTime,
    required this.mode,
    required this.effectiveLive,
    required this.isOffline,
    required this.accessibleOnly,
    required this.maxTransferWalkMeters,
    required this.stopsById,
    required this.eligibleStops,
    required this.eligibleLines,
    required this.originWalkMeters,
    required this.destWalkMeters,
    required this.timetables,
    Map<String, List<Departure>>? departureCache,
  }) : departureCache = departureCache ?? <String, List<Departure>>{};

  final LatLng origin;
  final LatLng destination;
  final String originLabel;
  final String destinationLabel;
  final DateTime anchorTime;
  final TripTimeMode mode;
  final bool effectiveLive;
  final bool isOffline;
  final bool accessibleOnly;
  final double maxTransferWalkMeters;
  final Map<String, BusStop> stopsById;
  final List<BusStop> eligibleStops;
  final List<BusLine> eligibleLines;
  final Map<String, double> originWalkMeters;
  final Map<String, double> destWalkMeters;
  final TimetableRepository timetables;
  final Map<String, List<Departure>> departureCache;
}

class _RideSegment {
  const _RideSegment({
    required this.boardDep,
    required this.alightTime,
    required this.rideMinutes,
  });

  final Departure boardDep;
  final DateTime alightTime;
  final int rideMinutes;
}

class _TwoTransferState {
  const _TwoTransferState({
    required this.leg1,
    required this.tStop2,
    required this.xfer1WalkMeters,
    required this.line2,
    required this.dir2,
    required this.tIdx2,
    required this.midStop,
    required this.midIdx,
    required this.ride2,
  });

  final _Leg1Arrival leg1;
  final BusStop tStop2;
  final double xfer1WalkMeters;
  final BusLine line2;
  final LineDirection dir2;
  final int tIdx2;
  final BusStop midStop;
  final int midIdx;
  final _RideSegment ride2;
}

class _Leg1Arrival {
  const _Leg1Arrival({
    required this.oStop,
    required this.oIdx,
    required this.tStop,
    required this.tIdx,
    required this.line,
    required this.dir,
    required this.ride,
    required this.walk1Meters,
  });

  final BusStop oStop;
  final int oIdx;
  final BusStop tStop;
  final int tIdx;
  final BusLine line;
  final LineDirection dir;
  final _RideSegment ride;
  final double walk1Meters;
}
