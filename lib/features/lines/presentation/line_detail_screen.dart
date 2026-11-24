// Detailed bus line view with direction switcher, map/list toggle, segment crowding, and departures.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/accessibility/favorites_provider.dart';
import 'package:m_mobilnost/core/accessibility/haptic_cues.dart';
import 'package:m_mobilnost/core/accessibility/read_aloud.dart';
import 'package:m_mobilnost/core/accessibility/semantics_helpers.dart';
import 'package:m_mobilnost/core/layout/breakpoints.dart';
import 'package:m_mobilnost/core/layout/responsive_builder.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/network/route_geometry_service.dart';
import 'package:m_mobilnost/core/utils/time_format.dart';
import 'package:m_mobilnost/core/widgets/big_button.dart';
import 'package:m_mobilnost/core/widgets/occupancy_strip.dart';
import 'package:m_mobilnost/core/widgets/offline_banner.dart';
import 'package:m_mobilnost/core/widgets/state_views.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/bus_position.dart';
import 'package:m_mobilnost/data/models/bus_stop.dart';
import 'package:m_mobilnost/data/models/departure.dart';
import 'package:m_mobilnost/data/models/occupancy.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/seed/seed_timetables.dart';
import 'package:m_mobilnost/features/map/presentation/widgets/maribor_transit_map.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';

import '../data/transit_providers.dart';
import 'widgets/line_badge.dart';

/// Displays route stops, map/list toggle, segment occupancy, and departures for [lineId].
class LineDetailScreen extends ConsumerStatefulWidget {
  /// Creates a [LineDetailScreen] for [lineId].
  const LineDetailScreen({
    super.key,
    required this.lineId,
  });

  /// Identifier of the bus line to display.
  final String lineId;

  @override
  ConsumerState<LineDetailScreen> createState() => _LineDetailScreenState();
}

class _LineDetailScreenState extends ConsumerState<LineDetailScreen> {
  int _directionIndex = 0;
  bool _showMap = true;
  late DayScheduleType _scheduleType;
  int _selectedWeekday = DateTime.now().weekday;
  String? _selectedStopId;
  bool _showAllDepartures = false;

  @override
  void initState() {
    super.initState();
    _scheduleType = scheduleTypeForDate(DateTime.now());
  }

  void _speakLineSummary(
    BuildContext context,
    BusLine line,
    LineDirection direction,
    List<Departure> upcoming,
    DateTime now,
  ) {
    final l10n = context.l10n;
    final locale = ref.read(a11ySettingsProvider).localeCode;
    final nextText = upcoming.isEmpty
        ? l10n.linesNoDepartures
        : '${l10n.stopUpcomingDepartures}: ${TimeFormatUtils.formatTime24(upcoming.first.estimatedTime)}, '
            '${localizedDelayStatusLabel(l10n, upcoming.first.status, upcoming.first.delaySeconds, isCancelled: upcoming.first.isCancelled)}';
    final summary =
        '${l10n.linesBadge(line.code)}. ${line.name}. ${l10n.linesDirectionTo(direction.name)}. '
        '${l10n.commonStopsPlural(direction.stopIds.length)}. $nextText';
    announceForAccessibility(context, summary);
    ref.read(readAloudProvider).speak(
          summary,
          enabled: true,
          localeCode: locale,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lineAsync = ref.watch(lineByIdProvider(widget.lineId));
    final stopsAsync = ref.watch(allStopsProvider);
    final favorites = ref.watch(favoritesProvider);
    final settings = ref.watch(a11ySettingsProvider);
    final isOffline = ref.watch(isOfflineProvider);
    final liveBuses =
        ref.watch(liveBusesStreamProvider).valueOrNull ?? const <BusPosition>[];

    return lineAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.linesBadge(widget.lineId))),
        body: const LoadingStateView(),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.linesBadge(widget.lineId))),
        body: ErrorStateView(
          onRetry: () => ref.invalidate(lineByIdProvider(widget.lineId)),
        ),
      ),
      data: (line) {
        if (line == null || line.directions.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.linesTitle)),
            body: EmptyStateView(title: l10n.commonEmpty),
          );
        }

        final dirIdx = _directionIndex.clamp(0, line.directions.length - 1);
        final direction = line.directions[dirIdx];
        final isFavorite = favorites.isLineFavorite(line.id);
        final activeStopId =
            direction.stopIds.contains(_selectedStopId)
                ? _selectedStopId!
                : direction.stopIds.first;
        final stopsMap = {
          for (final s in stopsAsync.valueOrNull ?? const <BusStop>[]) s.id: s,
        };
        final now = DateTime.now();

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.linesBadge(line.code)),
            actions: [
              Semantics(
                button: true,
                toggled: isFavorite,
                label: l10n.a11yFavoriteToggle,
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFavorite
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  tooltip: isFavorite
                      ? l10n.linesFavoriteRemove
                      : l10n.linesFavoriteAdd,
                  constraints: const BoxConstraints(
                    minWidth: 56,
                    minHeight: 56,
                  ),
                  onPressed: () {
                    HapticCues.trigger(
                      HapticCueType.tap,
                      enabled: settings.hapticAlertsEnabled,
                    );
                    ref.read(favoritesProvider.notifier).toggleLine(line.id);
                  },
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: FutureBuilder<_LineDetailPayload>(
                  future: _loadDetailPayload(
                    line: line,
                    direction: direction,
                    stopId: activeStopId,
                    scheduleType: _scheduleType,
                    useSimulatedLive: settings.useSimulatedLive,
                    isOffline: isOffline,
                    at: now,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const LoadingStateView();
                    }
                    final payload = snapshot.data ??
                        _LineDetailPayload(
                          departures: const [],
                          segmentOccupancies: const [],
                          fetchedAt: now,
                        );
                    final todayType = scheduleTypeForDate(now);
                    final isTodaySchedule = _scheduleType == todayType;
                    final upcoming = isTodaySchedule
                        ? payload.departures
                            .where(
                              (d) => !d.estimatedTime.isBefore(
                                now.subtract(const Duration(minutes: 2)),
                              ),
                            )
                            .toList(growable: false)
                        : payload.departures;
                    final visibleDepartures = _showAllDepartures
                        ? upcoming
                        : upcoming.take(8).toList(growable: false);
                    final dirBuses = liveBuses
                        .where(
                          (b) =>
                              b.lineId == line.id &&
                              b.directionId == direction.id,
                        )
                        .toList(growable: false);

                    return ResponsiveBuilder(
                      builder: (context, layoutSize, _) {
                        final headerCard = _buildHeaderCard(
                          context: context,
                          l10n: l10n,
                          line: line,
                          direction: direction,
                          dirIdx: dirIdx,
                          upcoming: upcoming,
                          now: now,
                          hapticEnabled: settings.hapticAlertsEnabled,
                        );

                        final stopsAndSegments = _buildStopsAndSegments(
                          context: context,
                          l10n: l10n,
                          line: line,
                          direction: direction,
                          stopsMap: stopsMap,
                          activeStopId: activeStopId,
                          segments: payload.segmentOccupancies,
                        );

                        final departuresSection = _buildDeparturesSection(
                          context: context,
                          l10n: l10n,
                          line: line,
                          directionIndex: dirIdx,
                          stopsMap: stopsMap,
                          activeStopId: activeStopId,
                          allDepartures: payload.departures,
                          visibleDepartures: visibleDepartures,
                          totalUpcomingCount: upcoming.length,
                          fetchedAt: payload.fetchedAt,
                          useSimulatedLive: settings.useSimulatedLive,
                          now: now,
                        );

                        final mapSection = _buildRouteMap(
                          context: context,
                          line: line,
                          direction: direction,
                          stopsMap: stopsMap,
                          activeStopId: activeStopId,
                          buses: dirBuses,
                        );

                        if (layoutSize == ScreenLayoutSize.expanded &&
                            _showMap) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 460,
                                  child: ListView(
                                    children: [
                                      headerCard,
                                      const SizedBox(height: 16),
                                      stopsAndSegments,
                                      const SizedBox(height: 16),
                                      departuresSection,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: mapSection,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView(
                          children: [
                            ResponsiveContentContainer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  headerCard,
                                  const SizedBox(height: 16),
                                  if (_showMap) ...[
                                    SizedBox(
                                      height: 290,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: mapSection,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  stopsAndSegments,
                                  const SizedBox(height: 16),
                                  departuresSection,
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_LineDetailPayload> _loadDetailPayload({
    required BusLine line,
    required LineDirection direction,
    required String stopId,
    required DayScheduleType scheduleType,
    required bool useSimulatedLive,
    required bool isOffline,
    required DateTime at,
  }) async {
    final timetableRepo = ref.read(timetableRepositoryProvider);
    final liveRepo = ref.read(liveBusRepositoryProvider);

    final departuresFuture = timetableRepo.getDeparturesForLine(
      line.id,
      direction.id,
      at: sampleDateForWeekday(_selectedWeekday, anchor: at),
      scheduleType: _scheduleType,
      stopId: stopId,
      useSimulatedLive: useSimulatedLive,
      isOffline: isOffline,
    );

    final segmentFutures = <Future<SegmentOccupancy>>[];
    for (var i = 0; i < direction.stopIds.length - 1; i++) {
      segmentFutures.add(
        liveRepo.getSegmentOccupancy(
          lineId: line.id,
          directionId: direction.id,
          fromStopId: direction.stopIds[i],
          toStopId: direction.stopIds[i + 1],
          at: at,
        ),
      );
    }

    final departures = await departuresFuture;
    final segments = await Future.wait(segmentFutures);
    return _LineDetailPayload(
      departures: departures,
      segmentOccupancies: segments,
      fetchedAt: at,
    );
  }

  Widget _buildHeaderCard({
    required BuildContext context,
    required AppLocalizations l10n,
    required BusLine line,
    required LineDirection direction,
    required int dirIdx,
    required List<Departure> upcoming,
    required DateTime now,
    required bool hapticEnabled,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LineBadge(
                  code: line.code,
                  color: line.color,
                  showLineWord: true,
                ),
                if (line.isLowFloorDefault)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.accessible_rounded, size: 18),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l10n.linesLowFloor,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              line.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.linesDirectionTo(direction.name),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (line.directions.length > 1) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < line.directions.length; i++)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: i == dirIdx
                          ? FilledButton(
                              onPressed: () {},
                              child: Text(line.directions[i].name),
                            )
                          : OutlinedButton(
                              onPressed: () {
                                HapticCues.trigger(
                                  HapticCueType.tap,
                                  enabled: hapticEnabled,
                                );
                                setState(() {
                                  _directionIndex = i;
                                  _selectedStopId = null;
                                  _showAllDepartures = false;
                                });
                              },
                              child: Text(line.directions[i].name),
                            ),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(l10n.linesSwapDirection),
                      onPressed: () {
                        HapticCues.trigger(
                          HapticCueType.tap,
                          enabled: hapticEnabled,
                        );
                        setState(() {
                          _directionIndex =
                              (dirIdx + 1) % line.directions.length;
                          _selectedStopId = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                BigButton(
                  icon: Icons.gps_fixed_rounded,
                  label: l10n.linesFollowBusLive,
                  onPressed: () => context.push(
                    '/tracker?lineId=${Uri.encodeComponent(line.id)}',
                  ),
                ),
                BigButton(
                  icon: Icons.volume_up_rounded,
                  label: l10n.a11yReadAloudButton,
                  variant: BigButtonVariant.secondary,
                  onPressed: () => _speakLineSummary(
                    context,
                    line,
                    direction,
                    upcoming,
                    now,
                  ),
                ),
                BigButton(
                  icon: _showMap
                      ? Icons.format_list_bulleted_rounded
                      : Icons.map_outlined,
                  label: _showMap
                      ? l10n.mapSwitchToList
                      : l10n.mapSwitchToMap,
                  variant: BigButtonVariant.outlined,
                  onPressed: () => setState(() => _showMap = !_showMap),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteMap({
    required BuildContext context,
    required BusLine line,
    required LineDirection direction,
    required Map<String, BusStop> stopsMap,
    required String activeStopId,
    required List<BusPosition> buses,
  }) {
    final l10n = context.l10n;
    final routeGeometry = ref.watch(
      routeGeometryProvider('${line.id}|${direction.id}'),
    );
    final points = routeGeometry.valueOrNull ??
        direction.roadPolyline ??
        direction.polyline;
    final fit = points.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(36),
            maxZoom: 15.5,
          )
        : null;

    final markers = <Marker>[
      for (var i = 0; i < direction.stopIds.length; i++)
        if (stopsMap[direction.stopIds[i]] != null)
          Marker(
            point: stopsMap[direction.stopIds[i]]!.position,
            width: 56,
            height: 56,
            child: Semantics(
              button: true,
              label: stopsMap[direction.stopIds[i]]!.name,
              child: GestureDetector(
                onTap: () => setState(
                  () => _selectedStopId = direction.stopIds[i],
                ),
                child: Center(
                  child: Container(
                    width: direction.stopIds[i] == activeStopId ? 28 : 22,
                    height: direction.stopIds[i] == activeStopId ? 28 : 22,
                    decoration: BoxDecoration(
                      color: direction.stopIds[i] == activeStopId
                          ? line.color
                          : Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: direction.stopIds[i] == activeStopId
                            ? Colors.white
                            : line.color,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: direction.stopIds[i] == activeStopId
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      for (final bus in buses)
        Marker(
          point: bus.position,
          width: 56,
          height: 56,
          child: Semantics(
            button: true,
            label: '${l10n.linesBadge(bus.lineCode)} (${bus.nextStopName})',
            child: GestureDetector(
              onTap: () => context.push(
                '/tracker?lineId=${Uri.encodeComponent(bus.lineId)}'
                '&vehicleId=${Uri.encodeComponent(bus.vehicleId)}',
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: line.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];

    return MariborTransitMap(
      key: ValueKey('line_map_${line.id}_${direction.id}'),
      initialCenter: points.isNotEmpty
          ? points[points.length ~/ 2]
          : const LatLng(46.5547, 15.6459),
      initialCameraFit: fit,
      polylines: [
        if (points.length >= 2)
          Polyline(
            points: points,
            strokeWidth: 6,
            color: line.color,
          ),
      ],
      markers: markers,
    );
  }

  Widget _buildStopsAndSegments({
    required BuildContext context,
    required AppLocalizations l10n,
    required BusLine line,
    required LineDirection direction,
    required Map<String, BusStop> stopsMap,
    required String activeStopId,
    required List<SegmentOccupancy> segments,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.commonStopsPlural(direction.stopIds.length)} • ${l10n.linesOccupancyBySegment}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < direction.stopIds.length; i++) ...[
              Builder(
                builder: (context) {
                  final stopId = direction.stopIds[i];
                  final stop = stopsMap[stopId];
                  final stopName = stop?.name ?? stopId;
                  final isSelected = stopId == activeStopId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedStopId = stopId),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primaryContainer.withValues(alpha: 0.45)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: line.color,
                            foregroundColor:
                                ThemeData.estimateBrightnessForColor(
                                          line.color,
                                        ) ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stopName,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                if (stop?.platform != null ||
                                    (stop?.isStepFree ?? false))
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (stop?.platform != null)
                                        Text(
                                          l10n.stopPlatform(stop!.platform!),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      if (stop?.isStepFree ?? false)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.accessible_rounded,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.stopAmenityStepFree,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            tooltip: l10n.mapStopDetailsOpen,
                            constraints: const BoxConstraints(
                              minWidth: 56,
                              minHeight: 56,
                            ),
                            onPressed: () => context.push(
                              '/stops/${Uri.encodeComponent(stopId)}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (i < segments.length)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    top: 6,
                    bottom: 8,
                  ),
                  child: OccupancyStrip(
                    level: segments[i].level,
                    compact: true,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeparturesSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required BusLine line,
    required int directionIndex,
    required Map<String, BusStop> stopsMap,
    required String activeStopId,
    required List<Departure> allDepartures,
    required List<Departure> visibleDepartures,
    required int totalUpcomingCount,
    required DateTime fetchedAt,
    required bool useSimulatedLive,
    required DateTime now,
  }) {
    final activeStopName = stopsMap[activeStopId]?.name ?? activeStopId;
    final operatesOnSelectedDay = doesLineOperateOn(line.id, _scheduleType);
    final firstBus = allDepartures.isNotEmpty
        ? TimeFormatUtils.formatTime24(allDepartures.first.scheduledTime)
        : '--:--';
    final lastBus = allDepartures.isNotEmpty
        ? TimeFormatUtils.formatTime24(allDepartures.last.scheduledTime)
        : '--:--';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.stopUpcomingDepartures}: $activeStopName',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TransitFreshnessHeader(
              useSimulatedLive: useSimulatedLive,
              updatedAt: fetchedAt,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Obratovanje linije ${line.code} (Pon–Ned)',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        'Pon–Pet: ${formatLineOperatingHours(line.id, directionIndex: directionIndex, type: DayScheduleType.weekday)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Sobota: ${formatLineOperatingHours(line.id, directionIndex: directionIndex, type: DayScheduleType.saturday)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Nedelja/Praznik: ${formatLineOperatingHours(line.id, directionIndex: directionIndex, type: DayScheduleType.sundayHoliday)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in DayScheduleType.values)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: type == _scheduleType
                        ? FilledButton(
                            onPressed: () {},
                            child: Text(localizedDayScheduleLabel(l10n, type)),
                          )
                        : OutlinedButton(
                            onPressed: () => setState(() {
                              _scheduleType = type;
                              _selectedWeekday = switch (type) {
                                DayScheduleType.weekday => DateTime.monday,
                                DayScheduleType.saturday => DateTime.saturday,
                                DayScheduleType.sundayHoliday => DateTime.sunday,
                              };
                            }),
                            child: Text(localizedDayScheduleLabel(l10n, type)),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in const [
                    (DateTime.monday, 'Pon'),
                    (DateTime.tuesday, 'Tor'),
                    (DateTime.wednesday, 'Sre'),
                    (DateTime.thursday, 'Čet'),
                    (DateTime.friday, 'Pet'),
                    (DateTime.saturday, 'Sob'),
                    (DateTime.sunday, 'Ned'),
                  ]) ...[
                    ChoiceChip(
                      label: Text(entry.$2),
                      selected: _selectedWeekday == entry.$1,
                      onSelected: (_) => setState(() {
                        _selectedWeekday = entry.$1;
                        _scheduleType = entry.$1 == DateTime.saturday
                            ? DayScheduleType.saturday
                            : (entry.$1 == DateTime.sunday
                                ? DayScheduleType.sundayHoliday
                                : DayScheduleType.weekday);
                      }),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!operatesOnSelectedDay)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Linija ${line.code} ob nedeljah in praznikih ne obratuje (po uradnem voznem redu Marprom). Preverite glavne linije G1–G4 ali G6.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  Text(
                    '${l10n.linesFirstBus}: $firstBus',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${l10n.linesLastBus}: $lastBus',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (visibleDepartures.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    l10n.linesNoDepartures,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              else ...[
                for (final dep in visibleDepartures) ...[
                  DepartureTileCard(
                    departure: dep,
                    now: now,
                    lineColor: line.color,
                    showLineBadge: false,
                    showRelativeCountdown:
                        _scheduleType == scheduleTypeForDate(now),
                    onTap: () => context.push(
                      '/tracker?lineId=${Uri.encodeComponent(line.id)}'
                      '&stopId=${Uri.encodeComponent(activeStopId)}',
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (totalUpcomingCount > visibleDepartures.length ||
                    _showAllDepartures)
                  BigButton(
                    icon: _showAllDepartures
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    label: _showAllDepartures
                        ? l10n.commonShowLess
                        : l10n.commonShowMore,
                    variant: BigButtonVariant.outlined,
                    expanded: true,
                    onPressed: () =>
                        setState(() => _showAllDepartures = !_showAllDepartures),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LineDetailPayload {
  const _LineDetailPayload({
    required this.departures,
    required this.segmentOccupancies,
    required this.fetchedAt,
  });

  final List<Departure> departures;
  final List<SegmentOccupancy> segmentOccupancies;
  final DateTime fetchedAt;
}
