// Live bus tracker with map/list views, early/late advice cards, alerts, and TTS.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/accessibility/haptic_cues.dart';
import 'package:m_mobilnost/core/accessibility/read_aloud.dart';
import 'package:m_mobilnost/core/accessibility/semantics_helpers.dart';
import 'package:m_mobilnost/core/layout/breakpoints.dart';
import 'package:m_mobilnost/core/layout/responsive_builder.dart';
import 'package:m_mobilnost/core/maps/full_screen_transit_map.dart';
import 'package:m_mobilnost/core/maps/google_map_3d_widget.dart';
import 'package:m_mobilnost/core/maps/google_map_models.dart';
import 'package:m_mobilnost/core/maps/google_web_views.dart';
import 'package:m_mobilnost/core/network/route_geometry_service.dart';
import 'package:m_mobilnost/core/theme/colors.dart';
import 'package:m_mobilnost/core/utils/distance.dart';
import 'package:m_mobilnost/core/utils/geo.dart';
import 'package:m_mobilnost/core/utils/time_format.dart';
import 'package:m_mobilnost/core/widgets/big_button.dart';
import 'package:m_mobilnost/core/widgets/bus_occupancy_cutaway.dart';
import 'package:m_mobilnost/core/widgets/offline_banner.dart';
import 'package:m_mobilnost/core/widgets/state_views.dart';
import 'package:m_mobilnost/core/widgets/status_chip.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/bus_position.dart';
import 'package:m_mobilnost/data/models/bus_stop.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/features/lines/data/transit_providers.dart';
import 'package:m_mobilnost/features/lines/presentation/widgets/line_badge.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';

/// Tracks active Marprom buses live with advice cards, arrival alerts, and TTS.
class LiveTrackerScreen extends ConsumerStatefulWidget {
  /// Creates a [LiveTrackerScreen] optionally pre-filtering line, vehicle, or stop.
  const LiveTrackerScreen({
    super.key,
    this.initialLineId,
    this.initialVehicleId,
    this.initialStopId,
  });

  /// Optional initial line ID filter.
  final String? initialLineId;

  /// Optional initial vehicle ID to follow.
  final String? initialVehicleId;

  /// Optional initial stop ID filter/target.
  final String? initialStopId;

  @override
  ConsumerState<LiveTrackerScreen> createState() => _LiveTrackerScreenState();
}

class _LiveTrackerScreenState extends ConsumerState<LiveTrackerScreen> {
  String? _selectedLineId;
  String? _selectedStopId;
  String? _selectedVehicleId;
  bool _showMap = true;
  bool _accessibleOnly = false;
  int? _notifyThresholdMinutes;
  String? _firedAlertKey;

  @override
  void initState() {
    super.initState();
    _selectedLineId = widget.initialLineId;
    _selectedStopId = widget.initialStopId;
    _selectedVehicleId = widget.initialVehicleId;
    _accessibleOnly = ref.read(a11ySettingsProvider).wheelchairAccessibleOnly;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isFlutterTestEnvironment) return;
      final notifier = ref.read(googleLineRoutesProvider.notifier);
      if (_selectedLineId != null) {
        notifier.ensureLineLoaded(_selectedLineId!);
      } else {
        notifier.warmAllActiveLines();
      }
    });
  }

  BusPosition? _resolveTrackedBus({
    required List<BusPosition> allBuses,
    required Map<String, BusStop> stopsMap,
  }) {
    if (allBuses.isEmpty) return null;

    if (_selectedVehicleId != null) {
      for (final bus in allBuses) {
        if (bus.vehicleId == _selectedVehicleId) return bus;
      }
    }

    final filtered = _filterBuses(allBuses: allBuses, stopsMap: stopsMap);
    if (filtered.isNotEmpty) return filtered.first;
    return null;
  }

  List<BusPosition> _filterBuses({
    required List<BusPosition> allBuses,
    required Map<String, BusStop> stopsMap,
  }) {
    Iterable<BusPosition> candidates = allBuses;
    if (_accessibleOnly) {
      candidates = candidates.where((b) => b.isWheelchairAccessible);
    }
    if (_selectedLineId != null) {
      candidates = candidates.where((b) => b.lineId == _selectedLineId);
    } else if (_selectedStopId != null) {
      final stop = stopsMap[_selectedStopId];
      if (stop != null) {
        candidates = candidates.where((b) => stop.lineIds.contains(b.lineId));
      }
    }
    return candidates.toList(growable: false);
  }

  void _checkAndFireArrivalAlert({
    required BusPosition? bus,
    required int etaMinutes,
    required String targetStopName,
    required A11ySettings settings,
    required AppLocalizations l10n,
  }) {
    final threshold = _notifyThresholdMinutes;
    if (bus == null || threshold == null || etaMinutes > threshold) {
      return;
    }
    final key = '${bus.vehicleId}|$threshold|$targetStopName';
    if (_firedAlertKey == key) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _firedAlertKey = key);
      HapticCues.trigger(
        HapticCueType.arriving,
        enabled: settings.hapticAlertsEnabled,
        soundOptional: settings.soundAlertsOptional,
      );
      final bannerMsg = l10n.trackerAlertFiredBanner(
        bus.lineCode,
        etaMinutes,
        targetStopName,
      );
      announceForAccessibility(context, bannerMsg);
      if (settings.readAloudEnabled) {
        ref.read(readAloudProvider).speak(
              bannerMsg,
              enabled: true,
              localeCode: settings.localeCode,
            );
      }
    });
  }

  Future<void> _openNotifyPicker(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.trackerNotifyMe,
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.trackerNotifyPrompt,
                style: Theme.of(ctx).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              for (final mins in const [1, 3, 5, 10]) ...[
                BigButton(
                  icon: Icons.notifications_active_outlined,
                  label: l10n.trackerNotifyMinutesAway(mins),
                  variant: BigButtonVariant.secondary,
                  expanded: true,
                  onPressed: () => Navigator.of(ctx).pop(mins),
                ),
                const SizedBox(height: 10),
              ],
              BigButton(
                icon: Icons.close_rounded,
                label: l10n.commonCancel,
                variant: BigButtonVariant.outlined,
                expanded: true,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _notifyThresholdMinutes = picked;
      _firedAlertKey = null;
    });
  }

  Future<void> _openLinePicker(
    BuildContext context,
    List<BusLine> lines,
  ) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.linesTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(Icons.clear_all_rounded),
                      title: Text(l10n.stopAllLines),
                      onTap: () => Navigator.of(ctx).pop(''),
                    ),
                    const Divider(height: 1),
                    for (final line in lines) ...[
                      ListTile(
                        minTileHeight: 56,
                        leading: LineBadge(
                          code: line.code,
                          color: line.color,
                          compact: true,
                        ),
                        title: Text(line.name),
                        onTap: () => Navigator.of(ctx).pop(line.id),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _selectedLineId = picked.isEmpty ? null : picked;
      _selectedVehicleId = null;
      _firedAlertKey = null;
    });
  }

  Future<void> _openStopPicker(
    BuildContext context,
    List<BusStop> stops,
  ) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.stopTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(Icons.clear_all_rounded),
                      title: Text(l10n.commonAll),
                      onTap: () => Navigator.of(ctx).pop(''),
                    ),
                    const Divider(height: 1),
                    for (final stop in stops) ...[
                      ListTile(
                        minTileHeight: 56,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(stop.name),
                        onTap: () => Navigator.of(ctx).pop(stop.id),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _selectedStopId = picked.isEmpty ? null : picked;
      _selectedVehicleId = null;
      _firedAlertKey = null;
    });
  }

  void _speakTrackerSummary({
    required BuildContext context,
    required BusPosition bus,
    required String distanceText,
    required int etaMinutes,
    required String adviceText,
    required String targetStopName,
  }) {
    final l10n = context.l10n;
    final locale = ref.read(a11ySettingsProvider).localeCode;
    final statusLabel = localizedDelayStatusLabel(
      l10n,
      bus.status,
      bus.delaySeconds,
    );
    final summary =
        '${l10n.linesBadge(bus.lineCode)}. ${l10n.linesDirectionTo(bus.directionName)}. '
        '${l10n.trackerDistanceAndEta(distanceText, etaMinutes)}. '
        '$statusLabel. $adviceText '
        '${l10n.trackerGetOffNextStop(targetStopName)}.';
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
    final lines = ref.watch(allLinesProvider).valueOrNull ?? const <BusLine>[];
    final stops = ref.watch(allStopsProvider).valueOrNull ?? const <BusStop>[];
    final linesMap = {for (final l in lines) l.id: l};
    final stopsMap = {for (final s in stops) s.id: s};
    final settings = ref.watch(a11ySettingsProvider);
    final busesAsync = ref.watch(liveBusesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trackerTitle),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: busesAsync.when(
              loading: () => const LoadingStateView(),
              error: (_, _) => ErrorStateView(
                onRetry: () => ref.invalidate(liveBusesStreamProvider),
              ),
              data: (allBuses) {
                final matchingBuses = _filterBuses(
                  allBuses: allBuses,
                  stopsMap: stopsMap,
                );
                final trackedBus = _resolveTrackedBus(
                  allBuses: allBuses,
                  stopsMap: stopsMap,
                );

                final trackedLine = trackedBus != null
                    ? linesMap[trackedBus.lineId]
                    : (_selectedLineId != null
                        ? linesMap[_selectedLineId!]
                        : null);
                final trackedDirection = (trackedBus != null &&
                        trackedLine != null)
                    ? trackedLine.directionById(trackedBus.directionId)
                    : trackedLine?.directions.firstOrNull;

                final targetStop =
                    (_selectedStopId != null ? stopsMap[_selectedStopId!] : null) ??
                        (trackedBus != null
                            ? stopsMap[trackedBus.nextStopId]
                            : null);
                final targetStopName =
                    targetStop?.name ?? trackedBus?.nextStopName ?? '';
                final distanceMeters = (trackedBus != null && targetStop != null)
                    ? GeoUtils.haversineMeters(
                        trackedBus.position,
                        targetStop.position,
                      )
                    : 0.0;
                final distanceText =
                    DistanceUtils.formatMeters(distanceMeters, l10n);
                final etaMinutes = trackedBus != null
                    ? (trackedBus.etaToNextStopSeconds / 60).ceil().clamp(0, 120)
                    : 0;
                final alertTriggered = trackedBus != null &&
                    _notifyThresholdMinutes != null &&
                    etaMinutes <= _notifyThresholdMinutes!;

                _checkAndFireArrivalAlert(
                  bus: trackedBus,
                  etaMinutes: etaMinutes,
                  targetStopName: targetStopName,
                  settings: settings,
                  l10n: l10n,
                );

                return ResponsiveBuilder(
                  builder: (context, layoutSize, _) {
                    final selectorCard = _buildSelectorCard(
                      context: context,
                      l10n: l10n,
                      lines: lines,
                      stops: stops,
                      linesMap: linesMap,
                      stopsMap: stopsMap,
                      matchingBuses: matchingBuses,
                      trackedBus: trackedBus,
                      updatedAt: trackedBus?.updatedAt ?? DateTime.now(),
                      useSimulatedLive: settings.useSimulatedLive,
                    );

                    final trackerDetails = trackedBus == null
                        ? _buildNoBusCard(
                            context: context,
                            l10n: l10n,
                            useSimulatedLive: settings.useSimulatedLive,
                          )
                        : _buildTrackedDetailsColumn(
                            context: context,
                            l10n: l10n,
                            bus: trackedBus,
                            line: trackedLine,
                            direction: trackedDirection,
                            stopsMap: stopsMap,
                            distanceText: distanceText,
                            etaMinutes: etaMinutes,
                            targetStopName: targetStopName,
                            alertTriggered: alertTriggered,
                          );

                    final mapWidget = _buildTrackerMap(
                      context: context,
                      l10n: l10n,
                      bus: trackedBus,
                      line: trackedLine,
                      direction: trackedDirection,
                      stopsMap: stopsMap,
                    );

                    if (layoutSize == ScreenLayoutSize.expanded && _showMap) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 470,
                              child: ListView(
                                children: [
                                  selectorCard,
                                  const SizedBox(height: 16),
                                  trackerDetails,
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: mapWidget,
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
                              selectorCard,
                              const SizedBox(height: 16),
                              if (_showMap && trackedBus != null) ...[
                                SizedBox(
                                  height: 270,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: mapWidget,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              trackerDetails,
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
  }

  Widget _buildSelectorCard({
    required BuildContext context,
    required AppLocalizations l10n,
    required List<BusLine> lines,
    required List<BusStop> stops,
    required Map<String, BusLine> linesMap,
    required Map<String, BusStop> stopsMap,
    required List<BusPosition> matchingBuses,
    required BusPosition? trackedBus,
    required DateTime updatedAt,
    required bool useSimulatedLive,
  }) {
    final selectedLine =
        _selectedLineId != null ? linesMap[_selectedLineId!] : null;
    final selectedStop =
        _selectedStopId != null ? stopsMap[_selectedStopId!] : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.trackerSelectLineOrStop,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TransitFreshnessHeader(
              useSimulatedLive: useSimulatedLive,
              updatedAt: updatedAt,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                BigButton(
                  icon: Icons.directions_bus_rounded,
                  label: selectedLine != null
                      ? l10n.linesBadge(selectedLine.code)
                      : l10n.stopAllLines,
                  variant: BigButtonVariant.outlined,
                  onPressed:
                      lines.isEmpty ? null : () => _openLinePicker(context, lines),
                ),
                BigButton(
                  icon: Icons.place_outlined,
                  label: selectedStop != null
                      ? selectedStop.name
                      : l10n.stopTitle,
                  variant: BigButtonVariant.outlined,
                  onPressed:
                      stops.isEmpty ? null : () => _openStopPicker(context, stops),
                ),
                BigButton(
                  icon: _showMap
                      ? Icons.format_list_bulleted_rounded
                      : Icons.map_outlined,
                  label: _showMap
                      ? l10n.mapSwitchToList
                      : l10n.mapSwitchToMap,
                  variant: BigButtonVariant.secondary,
                  onPressed: () => setState(() => _showMap = !_showMap),
                ),
                FilterChip(
                  avatar: const Icon(Icons.accessible_rounded, size: 18),
                  label: Text(l10n.linesLowFloor),
                  selected: _accessibleOnly,
                  onSelected: (v) => setState(() {
                    _accessibleOnly = v;
                    _selectedVehicleId = null;
                  }),
                ),
              ],
            ),
            if (matchingBuses.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final bus in matchingBuses.take(6))
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: trackedBus?.vehicleId == bus.vehicleId
                          ? FilledButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.gps_fixed_rounded),
                              label: Text(
                                '${l10n.linesBadge(bus.lineCode)} • ${bus.directionName}',
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _selectedVehicleId = bus.vehicleId;
                                _firedAlertKey = null;
                              }),
                              icon: const Icon(Icons.directions_bus_outlined),
                              label: Text(
                                '${l10n.linesBadge(bus.lineCode)} • ${bus.directionName}',
                              ),
                            ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoBusCard({
    required BuildContext context,
    required AppLocalizations l10n,
    required bool useSimulatedLive,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: EmptyStateView(
          icon: Icons.directions_bus_outlined,
          title: useSimulatedLive
              ? l10n.trackerNoActiveBuses
              : l10n.freshnessLiveDisabledFallback,
          actionLabel: _selectedLineId != null ? l10n.linesTitle : null,
          onAction: _selectedLineId != null
              ? () => context.push(
                    '/lines/${Uri.encodeComponent(_selectedLineId!)}',
                  )
              : null,
        ),
      ),
    );
  }

  Widget _buildTrackedDetailsColumn({
    required BuildContext context,
    required AppLocalizations l10n,
    required BusPosition bus,
    required BusLine? line,
    required LineDirection? direction,
    required Map<String, BusStop> stopsMap,
    required String distanceText,
    required int etaMinutes,
    required String targetStopName,
    required bool alertTriggered,
  }) {
    final googleRoute = ref.watch(
      googleLineRoutesProvider,
    )['${bus.lineId}|${bus.directionId}'];
    final lineColor = line?.color ?? Theme.of(context).colorScheme.primary;
    final statusColors =
        Theme.of(context).extension<MarpromStatusColors>() ??
            MarpromStatusColors.light;
    final statusLabel = localizedDelayStatusLabel(
      l10n,
      bus.status,
      bus.delaySeconds,
    );
    final advice = _buildAdviceContent(l10n, bus, etaMinutes);
    final expectedTimeStr = TimeFormatUtils.formatTime24(
      DateTime.now().add(Duration(seconds: bus.etaToNextStopSeconds)),
    );
    final scheduledTimeStr = TimeFormatUtils.formatTime24(
      DateTime.now()
          .add(Duration(seconds: bus.etaToNextStopSeconds - bus.delaySeconds)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (alertTriggered) ...[
          Semantics(
            liveRegion: true,
            child: Card(
              color: statusColors.warningBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: statusColors.warningFg, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 28,
                      color: statusColors.warningFg,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.trackerAlertFiredBanner(
                          bus.lineCode,
                          etaMinutes,
                          targetStopName,
                        ),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: statusColors.warningFg,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Large visual "Next step on your trip" card for deaf / hard-of-hearing users.
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: statusColors.highContrastBorders ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.directions_walk_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.trackerNextStepCardTitle,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.trackerGetOffNextStop(targetStopName),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.trackerStopsRemaining}: ${l10n.commonStopsPlural(bus.remainingStopsCount)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Core live telemetry card.
        Card(
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
                      code: bus.lineCode,
                      color: lineColor,
                      showLineWord: true,
                    ),
                    StatusChip(type: bus.status, label: statusLabel),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.linesDirectionTo(bus.directionName),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${l10n.trackerNextStop}: ${bus.nextStopName}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.trackerDistanceAndEta(distanceText, etaMinutes),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${l10n.trackerEta}: $expectedTimeStr',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      l10n.trackerScheduledTime(scheduledTimeStr),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                BusOccupancyCutaway.fromBusPosition(bus),
                if (googleRoute != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.alt_route_rounded,
                        size: 16,
                        color: MarpromColors.marpromRed,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Google Routes trasa: ${googleRoute.formattedDistanceKm} (~${googleRoute.formattedDurationMinutes})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (_notifyThresholdMinutes == null)
                      BigButton(
                        icon: Icons.notifications_active_outlined,
                        label: l10n.trackerNotifyMe,
                        onPressed: () => _openNotifyPicker(context),
                      )
                    else
                      BigButton(
                        icon: Icons.notifications_off_outlined,
                        label: l10n.trackerNotifyCancel,
                        variant: BigButtonVariant.secondary,
                        onPressed: () => setState(() {
                          _notifyThresholdMinutes = null;
                          _firedAlertKey = null;
                        }),
                      ),
                    BigButton(
                      icon: Icons.volume_up_rounded,
                      label: l10n.a11yReadAloudButton,
                      variant: BigButtonVariant.outlined,
                      onPressed: () => _speakTrackerSummary(
                        context: context,
                        bus: bus,
                        distanceText: distanceText,
                        etaMinutes: etaMinutes,
                        adviceText: advice.$2,
                        targetStopName: targetStopName,
                      ),
                    ),
                  ],
                ),
                if (_notifyThresholdMinutes != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.trackerNotifyActive} (${l10n.trackerNotifyMinutesAway(_notifyThresholdMinutes!)})',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Explicit review-driven early / on-time / late advice card.
        _AdviceCard(
          status: bus.status,
          title: advice.$1,
          body: advice.$2,
          showAlternativeCta: bus.status != TransitStatusType.onTime,
          onReviewAlternatives: () => context.go('/plan'),
        ),

        if (direction != null) ...[
          const SizedBox(height: 14),
          _RemainingStopsListCard(
            direction: direction,
            bus: bus,
            stopsMap: stopsMap,
            lineColor: lineColor,
          ),
        ],
      ],
    );
  }

  (String, String) _buildAdviceContent(
    AppLocalizations l10n,
    BusPosition bus,
    int etaMinutes,
  ) {
    switch (bus.status) {
      case TransitStatusType.early:
        final earlyMinutes = ((-bus.delaySeconds) / 60).ceil().clamp(1, 30);
        final arriveEarlyMin = (earlyMinutes + 2).clamp(2, 30);
        return (
          l10n.trackerAdviceEarlyTitle,
          l10n.trackerEarlyActionTip(earlyMinutes, arriveEarlyMin),
        );
      case TransitStatusType.late:
        final lateMinutes = (bus.delaySeconds / 60).ceil().clamp(1, 60);
        final expected = TimeFormatUtils.formatTime24(
          DateTime.now().add(Duration(seconds: bus.etaToNextStopSeconds)),
        );
        return (
          l10n.trackerAdviceLateTitle,
          l10n.trackerLateActionTip(lateMinutes, expected),
        );
      case TransitStatusType.onTime:
      case TransitStatusType.info:
      case TransitStatusType.warning:
      case TransitStatusType.disruption:
        return (
          l10n.trackerAdviceOnTimeTitle,
          l10n.trackerAdviceOnTimeBody,
        );
    }
  }

  Widget _buildTrackerMap({
    required BuildContext context,
    required AppLocalizations l10n,
    required BusPosition? bus,
    required BusLine? line,
    required LineDirection? direction,
    required Map<String, BusStop> stopsMap,
  }) {
    final lineColor = line?.color ?? Theme.of(context).colorScheme.primary;
    final routeKey =
        line != null && direction != null ? '${line.id}|${direction.id}' : null;
    final googleRoute = routeKey != null
        ? ref.watch(googleLineRoutesProvider)[routeKey]
        : null;
    final resolvedPoints = routeKey != null
        ? (ref.watch(routeGeometryProvider(routeKey)).valueOrNull ??
            googleRoute?.polylinePoints ??
            direction?.roadPolyline ??
            direction?.polyline ??
            const <LatLng>[])
        : (direction?.polyline ?? const <LatLng>[]);
    final points = resolvedPoints;

    final polylines3D = <GoogleMap3DPolylineData>[
      if (points.length >= 2 && line != null && direction != null)
        GoogleMap3DPolylineData(
          id: '${line.id}_${direction.id}',
          points: points,
          color: lineColor,
          strokeWidth: 7,
        ),
    ];

    final markers3D = <GoogleMap3DMarkerData>[
      if (direction != null)
        for (final stopId in direction.stopIds)
          if (stopsMap[stopId] != null)
            GoogleMap3DMarkerData(
              id: stopId,
              position: stopsMap[stopId]!.position,
              label: stopsMap[stopId]!.name,
              isBus: false,
              isWheelchairAccessible: stopsMap[stopId]!.isStepFree,
              color: lineColor,
            ),
      if (bus != null)
        GoogleMap3DMarkerData(
          id: bus.vehicleId,
          position: bus.position,
          shortLabel: bus.lineCode,
          label:
              '${bus.lineCode} • ${bus.passengerCount}/${bus.vehicleCapacity} potnikov → ${bus.nextStopName}',
          isBus: true,
          isWheelchairAccessible: bus.isWheelchairAccessible,
          headingDegrees: bus.headingDegrees,
          color: lineColor,
        ),
    ];

    return GoogleMap3DWidget(
      key: ValueKey('tracker_3d_${line?.id ?? 'none'}_${direction?.id ?? 'none'}'),
      initialCenter: bus?.position ?? GeoUtils.mariborCenter,
      initialZoom: 14.0,
      initialUse3D: false,
      showPresets: false,
      showStatusPill: false,
      fitBounds: bus == null || points.length >= 2,
      fitSignature: '${line?.id}|${direction?.id}|${points.length}',
      activeBusCount: bus != null ? 1 : 0,
      totalPassengers: bus?.passengerCount,
      polylines3D: polylines3D,
      markers3D: markers3D,
      onFullScreenToggle: () => openFullScreenTransitMap(
        context,
        initialLineId: line?.id,
        initialDirectionId: direction?.id,
        initialVehicleId: bus?.vehicleId,
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({
    required this.status,
    required this.title,
    required this.body,
    required this.showAlternativeCta,
    required this.onReviewAlternatives,
  });

  final TransitStatusType status;
  final String title;
  final String body;
  final bool showAlternativeCta;
  final VoidCallback onReviewAlternatives;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusColors =
        Theme.of(context).extension<MarpromStatusColors>() ??
            MarpromStatusColors.light;

    final (fg, bg) = switch (status) {
      TransitStatusType.early => (statusColors.earlyFg, statusColors.earlyBg),
      TransitStatusType.late => (statusColors.lateFg, statusColors.lateBg),
      TransitStatusType.onTime => (statusColors.onTimeFg, statusColors.onTimeBg),
      TransitStatusType.info => (statusColors.infoFg, statusColors.infoBg),
      TransitStatusType.warning => (
          statusColors.warningFg,
          statusColors.warningBg,
        ),
      TransitStatusType.disruption => (
          statusColors.disruptionFg,
          statusColors.disruptionBg,
        ),
    };

    return Card(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: fg,
          width: statusColors.highContrastBorders ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusChip(type: status),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: fg),
            ),
            if (showAlternativeCta) ...[
              const SizedBox(height: 12),
              BigButton(
                icon: Icons.alt_route_rounded,
                label: l10n.trackerAdviceReviewAlternatives,
                variant: BigButtonVariant.outlined,
                onPressed: onReviewAlternatives,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RemainingStopsListCard extends StatelessWidget {
  const _RemainingStopsListCard({
    required this.direction,
    required this.bus,
    required this.stopsMap,
    required this.lineColor,
  });

  final LineDirection direction;
  final BusPosition bus;
  final Map<String, BusStop> stopsMap;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nextIdx = direction.stopIds.indexOf(bus.nextStopId);
    final startIdx = nextIdx >= 0 ? nextIdx : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.trackerStopsRemaining}: ${l10n.commonStopsPlural(bus.remainingStopsCount)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            for (var i = startIdx; i < direction.stopIds.length; i++) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 56,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: i == startIdx
                      ? lineColor
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: i == startIdx
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                title: Text(
                  stopsMap[direction.stopIds[i]]?.name ?? direction.stopIds[i],
                ),
                trailing: i == startIdx
                    ? StatusChip(
                        type: bus.status,
                        label: l10n.trackerNextStop,
                        compact: true,
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(
                  '/stops/${Uri.encodeComponent(direction.stopIds[i])}',
                ),
              ),
              if (i < direction.stopIds.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}
