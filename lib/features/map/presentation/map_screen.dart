// Interactive Maribor transit map with safe GPS fallback, list toggle, and split view.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/accessibility/favorites_provider.dart';
import 'package:m_mobilnost/core/accessibility/haptic_cues.dart';
import 'package:m_mobilnost/core/accessibility/semantics_helpers.dart';
import 'package:m_mobilnost/core/layout/breakpoints.dart';
import 'package:m_mobilnost/core/layout/responsive_builder.dart';
import 'package:m_mobilnost/core/maps/full_screen_transit_map.dart';
import 'package:m_mobilnost/core/maps/google_map_3d_widget.dart';
import 'package:m_mobilnost/core/maps/google_map_models.dart';
import 'package:m_mobilnost/core/maps/google_web_views.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/network/route_geometry_service.dart';
import 'package:m_mobilnost/core/utils/distance.dart';
import 'package:m_mobilnost/core/utils/geo.dart';
import 'package:m_mobilnost/core/utils/time_format.dart';
import 'package:m_mobilnost/core/widgets/big_button.dart';
import 'package:m_mobilnost/core/widgets/state_views.dart';
import 'package:m_mobilnost/core/widgets/status_chip.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/bus_position.dart';
import 'package:m_mobilnost/data/models/bus_stop.dart';
import 'package:m_mobilnost/data/models/departure.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/seed/seed_timetables.dart';
import 'package:m_mobilnost/features/lines/data/transit_providers.dart';
import 'package:m_mobilnost/features/lines/presentation/widgets/line_badge.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';

import '../data/location_service.dart';
import 'widgets/maribor_transit_map.dart';

/// Displays Maribor bus stops, live buses, route polylines, and equivalent list view.
class MapScreen extends ConsumerStatefulWidget {
  /// Creates a [MapScreen] optionally focusing on [initialLineId] or [initialStopId].
  const MapScreen({
    super.key,
    this.initialLineId,
    this.initialStopId,
  });

  /// Optional line ID to highlight when opening the map.
  final String? initialLineId;

  /// Optional stop ID to focus when opening the map.
  final String? initialStopId;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  bool _showMap = true;
  bool _accessibleOnly = false;
  bool _showLiveBuses = true;
  String? _highlightedLineId;
  String? _highlightedDirectionId;
  String? _highlightedVehicleId;
  bool _appliedInitialStop = false;

  @override
  void initState() {
    super.initState();
    _highlightedLineId = widget.initialLineId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isFlutterTestEnvironment) return;
      final notifier = ref.read(googleLineRoutesProvider.notifier);
      if (widget.initialLineId != null) {
        notifier.ensureLineLoaded(widget.initialLineId!);
      } else {
        notifier.warmAllActiveLines();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _safeMoveMap(LatLng center, double zoom) {
    try {
      _mapController.move(center, zoom);
    } catch (_) {
      // MapController may not yet be attached when list view is active.
    }
  }

  void _selectLineOrBus({
    required BusLine line,
    String? directionId,
    BusPosition? bus,
  }) {
    final resolvedDirId = directionId ??
        bus?.directionId ??
        (line.directions.isNotEmpty ? line.directions.first.id : null);
    setState(() {
      _highlightedLineId = line.id;
      _highlightedDirectionId = resolvedDirId;
      _highlightedVehicleId = bus?.vehicleId;
    });
    if (!isFlutterTestEnvironment) {
      ref.read(googleLineRoutesProvider.notifier).ensureLineLoaded(line.id);
    }
    if (bus != null) {
      _safeMoveMap(bus.position, 14.2);
    } else {
      final dir = resolvedDirId != null
          ? line.directionById(resolvedDirId)
          : line.directions.firstOrNull;
      if (dir != null && dir.polyline.isNotEmpty) {
        _safeMoveMap(dir.polyline[dir.polyline.length ~/ 2], 13.4);
      }
    }
  }

  Future<void> _openStopBottomSheet(
    BuildContext context,
    BusStop stop,
    Map<String, BusLine> linesMap,
  ) async {
    _safeMoveMap(stop.position, 15.0);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _StopMapBottomSheet(
        stop: stop,
        linesMap: linesMap,
        onOpenStopPage: () {
          Navigator.of(ctx).pop();
          context.push('/stops/${Uri.encodeComponent(stop.id)}');
        },
        onSelectLine: (line) {
          Navigator.of(ctx).pop();
          _selectLineOrBus(line: line);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stopsAsync = ref.watch(allStopsProvider);
    final linesAsync = ref.watch(allLinesProvider);
    final locationAsync = ref.watch(userLocationProvider);
    final liveBusesAsync = ref.watch(liveBusesStreamProvider);
    final settings = ref.watch(a11ySettingsProvider);

    return stopsAsync.when(
      loading: () => const LoadingStateView(),
      error: (_, _) => ErrorStateView(
        onRetry: () => ref.invalidate(allStopsProvider),
      ),
      data: (stops) {
        final lines = linesAsync.valueOrNull ?? const <BusLine>[];
        final linesMap = {for (final l in lines) l.id: l};
        final stopsMap = {for (final s in stops) s.id: s};
        final location = locationAsync.valueOrNull ??
            const UserLocationState(
              kind: LocationAccessKind.unavailableOrDenied,
              effectivePosition: GeoUtils.mariborCenter,
            );

        if (!_appliedInitialStop && widget.initialStopId != null) {
          _appliedInitialStop = true;
          final target = stopsMap[widget.initialStopId];
          if (target != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _safeMoveMap(target.position, 15.2);
              _openStopBottomSheet(context, target, linesMap);
            });
          }
        }

        final filteredStops = _filterAndSortStops(
          stops: stops,
          referencePoint: location.effectivePosition,
        );
        final activeBuses = settings.useSimulatedLive && _showLiveBuses
            ? (liveBusesAsync.valueOrNull ?? const <BusPosition>[])
            : const <BusPosition>[];
        final highlightedLine =
            _highlightedLineId != null ? linesMap[_highlightedLineId!] : null;

        return ResponsiveBuilder(
          builder: (context, layoutSize, _) {
            final isExpanded = layoutSize == ScreenLayoutSize.expanded ||
                LayoutBreakpoints.fromWidth(
                      MediaQuery.sizeOf(context).width,
                    ) ==
                    ScreenLayoutSize.expanded;

            final controlsHeader = _buildControlsBar(
              context: context,
              l10n: l10n,
              isExpanded: isExpanded,
              location: location,
              hapticEnabled: settings.hapticAlertsEnabled,
            );

            final listContent = _buildListContent(
              context: context,
              l10n: l10n,
              allStops: stops,
              filteredStops: filteredStops,
              linesMap: linesMap,
              stopsMap: stopsMap,
              location: location,
              activeBuses: activeBuses,
              highlightedLine: highlightedLine,
              useSimulatedLive: settings.useSimulatedLive,
            );

            final mapContent = _buildMapWidget(
              context: context,
              l10n: l10n,
              filteredStops: filteredStops,
              linesMap: linesMap,
              stopsMap: stopsMap,
              location: location,
              activeBuses: activeBuses,
              highlightedLine: highlightedLine,
              useSimulatedLive: settings.useSimulatedLive,
            );

            if (isExpanded && _showMap) {
              return Column(
                children: [
                  controlsHeader,
                  const Divider(height: 1),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 430,
                          child: listContent,
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: mapContent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            if (!_showMap) {
              return Column(
                children: [
                  controlsHeader,
                  const Divider(height: 1),
                  Expanded(child: listContent),
                ],
              );
            }

            // Compact / Medium Map view with non-blocking bottom overlay & maximum map viewport.
            final isLargeText =
                MediaQuery.textScalerOf(context).scale(1.0) > 1.35;
            final mapStack = Stack(
              children: [
                mapContent,
                if (highlightedLine != null)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: _HighlightedLinePanel(
                      line: highlightedLine,
                      directionId: _highlightedDirectionId,
                      vehicleId: _highlightedVehicleId,
                      stopsMap: stopsMap,
                      activeBuses: activeBuses,
                      useSimulatedLive: settings.useSimulatedLive,
                      compactOverlay: true,
                      onDirectionSelected: (dirId) => setState(
                        () => _highlightedDirectionId = dirId,
                      ),
                      onClear: () => setState(() {
                        _highlightedLineId = null;
                        _highlightedDirectionId = null;
                        _highlightedVehicleId = null;
                      }),
                    ),
                  ),
              ],
            );

            if (isLargeText) {
              return ListView(
                children: [
                  controlsHeader,
                  if (location.showManualFallbackCard)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: ManualLocationFallbackCard(
                        stops: stops,
                        selectedStop: location.manualStop,
                        onManualStopChanged: (stop) =>
                            _safeMoveMap(stop.position, 14.5),
                      ),
                    ),
                  SizedBox(height: 360, child: mapStack),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      l10n.mapTapStopHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                controlsHeader,
                if (location.showManualFallbackCard)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                    child: ManualLocationFallbackCard(
                      stops: stops,
                      selectedStop: location.manualStop,
                      onManualStopChanged: (stop) =>
                          _safeMoveMap(stop.position, 14.5),
                    ),
                  ),
                Expanded(child: mapStack),
              ],
            );
          },
        );
      },
    );
  }

  List<_StopWithDistance> _filterAndSortStops({
    required List<BusStop> stops,
    required LatLng referencePoint,
  }) {
    final trimmed = _query.trim().toLowerCase();
    final result = <_StopWithDistance>[];
    for (final stop in stops) {
      if (_accessibleOnly && !stop.isStepFree) continue;
      if (trimmed.isNotEmpty) {
        final nameMatch = stop.name.toLowerCase().contains(trimmed);
        final lineMatch =
            stop.lineIds.any((id) => id.toLowerCase() == trimmed);
        if (!nameMatch && !lineMatch) continue;
      }
      final dist = GeoUtils.haversineMeters(referencePoint, stop.position);
      result.add(_StopWithDistance(stop: stop, meters: dist));
    }
    result.sort((a, b) => a.meters.compareTo(b.meters));
    return result;
  }

  Widget _buildControlsBar({
    required BuildContext context,
    required AppLocalizations l10n,
    required bool isExpanded,
    required UserLocationState location,
    required bool hapticEnabled,
  }) {
    final compact = !isExpanded;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 6 : 8, 16, compact ? 6 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.mapTitle,
                  style: compact
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: compact ? 44 : 56),
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        HapticCues.trigger(
                          HapticCueType.tap,
                          enabled: hapticEnabled,
                        );
                        setState(() => _showMap = !_showMap);
                      },
                      icon: Icon(
                        _showMap
                            ? Icons.format_list_bulleted_rounded
                            : Icons.map_outlined,
                      ),
                      label: Text(
                        _showMap ? l10n.mapSwitchToList : l10n.mapSwitchToMap,
                      ),
                    ),
                  ),
                  if (_showMap) ...[
                    const SizedBox(width: 6),
                    IconButton.outlined(
                      tooltip: 'Celozaslonski zemljevid',
                      constraints: BoxConstraints(
                        minWidth: compact ? 44 : 52,
                        minHeight: compact ? 44 : 52,
                      ),
                      icon: const Icon(Icons.fullscreen_rounded),
                      onPressed: () => openFullScreenTransitMap(
                        context,
                        initialLineId: _highlightedLineId,
                        initialDirectionId: _highlightedDirectionId,
                        initialVehicleId: _highlightedVehicleId,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Semantics(
            textField: true,
            label: l10n.a11ySearchField,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                isDense: compact,
                contentPadding: compact
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                    : null,
                hintText: l10n.mapSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        tooltip: l10n.commonClear,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          // One horizontally scrolling row of filters keeps the map tall.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _MapToggleChip(
                  icon: Icons.accessible_rounded,
                  label: l10n.mapFilterAccessible,
                  selected: _accessibleOnly,
                  onTap: () =>
                      setState(() => _accessibleOnly = !_accessibleOnly),
                ),
                const SizedBox(width: 8),
                _MapToggleChip(
                  icon: Icons.directions_bus_rounded,
                  label: l10n.mapFilterActiveBuses,
                  selected: _showLiveBuses,
                  onTap: () => setState(() => _showLiveBuses = !_showLiveBuses),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapWidget({
    required BuildContext context,
    required AppLocalizations l10n,
    required List<_StopWithDistance> filteredStops,
    required Map<String, BusLine> linesMap,
    required Map<String, BusStop> stopsMap,
    required UserLocationState location,
    required List<BusPosition> activeBuses,
    required BusLine? highlightedLine,
    required bool useSimulatedLive,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final googleRoutesMap = ref.watch(googleLineRoutesProvider);
    final highlightedDirection = highlightedLine != null
        ? (_highlightedDirectionId != null
            ? highlightedLine.directionById(_highlightedDirectionId!)
            : highlightedLine.directions.firstOrNull)
        : null;

    final routeGeometry = highlightedLine != null &&
            highlightedDirection != null
        ? ref.watch(
            routeGeometryProvider(
              '${highlightedLine.id}|${highlightedDirection.id}',
            ),
          )
        : const AsyncData<List<LatLng>>(<LatLng>[]);
    final roadPoints = (highlightedLine != null && highlightedDirection != null
            ? googleRoutesMap['${highlightedLine.id}|${highlightedDirection.id}']
                ?.polylinePoints
            : null) ??
        routeGeometry.valueOrNull ??
        highlightedDirection?.roadPolyline ??
        highlightedDirection?.polyline ??
        const <LatLng>[];
    final activeBusLineIds = {for (final b in activeBuses) b.lineId};

    final polylines = <Polyline>[
      if (highlightedLine != null &&
          highlightedDirection != null &&
          roadPoints.length >= 2)
        Polyline(
          points: roadPoints,
          strokeWidth: 6.5,
          borderStrokeWidth: 2,
          borderColor: Colors.white,
          color: highlightedLine.color,
        )
      else
        for (final line in linesMap.values)
          if (line.directions.isNotEmpty &&
              (googleRoutesMap.containsKey('${line.id}|${line.directions.first.id}') ||
                  activeBusLineIds.contains(line.id)))
            Polyline(
              points: googleRoutesMap['${line.id}|${line.directions.first.id}']
                      ?.polylinePoints ??
                  line.directions.first.roadPolyline ??
                  line.directions.first.polyline,
              strokeWidth: activeBusLineIds.contains(line.id) ? 4.2 : 3.0,
              color: line.color.withValues(alpha: 0.72),
            ),
    ];

    final markers = <Marker>[
      Marker(
        point: location.effectivePosition,
        width: 48,
        height: 48,
        child: Semantics(
          label: location.isGps ? l10n.mapCenterOnMe : l10n.mapManualCenter,
          child: Center(
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),
        ),
      ),
      for (final item in filteredStops)
        Marker(
          point: item.stop.position,
          width: 48,
          height: 48,
          child: Semantics(
            button: true,
            label: item.stop.name,
            child: GestureDetector(
              onTap: () => _openStopBottomSheet(context, item.stop, linesMap),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.primary, width: 2.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      for (final bus in activeBuses)
        Marker(
          point: bus.position,
          width: 46,
          height: 24,
          child: Semantics(
            button: true,
            label: '${l10n.linesBadge(bus.lineCode)}: ${bus.nextStopName}',
            child: GestureDetector(
              onTap: () {
                final line = linesMap[bus.lineId];
                if (line != null) {
                  _selectLineOrBus(
                    line: line,
                    directionId: bus.directionId,
                    bus: bus,
                  );
                }
              },
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: linesMap[bus.lineId]?.color ?? scheme.secondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.8),
                  ),
                  child: Text(
                    bus.lineCode,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];

    final polylines3D = <GoogleMap3DPolylineData>[
      if (highlightedLine != null &&
          highlightedDirection != null &&
          roadPoints.length >= 2)
        GoogleMap3DPolylineData(
          id: '${highlightedLine.id}_${highlightedDirection.id}',
          points: roadPoints,
          color: highlightedLine.color,
          strokeWidth: 7.0,
        )
      else
        for (final line in linesMap.values)
          if (line.directions.isNotEmpty &&
              (googleRoutesMap.containsKey('${line.id}|${line.directions.first.id}') ||
                  activeBusLineIds.contains(line.id)))
            GoogleMap3DPolylineData(
              id: line.id,
              points: googleRoutesMap['${line.id}|${line.directions.first.id}']
                      ?.polylinePoints ??
                  line.directions.first.roadPolyline ??
                  line.directions.first.polyline,
              color: line.color,
              strokeWidth: activeBusLineIds.contains(line.id) ? 4.5 : 3.2,
            ),
    ];

    final googleStops = <BusStop>[
      if (highlightedLine != null && highlightedDirection != null)
        for (final stopId in highlightedDirection.stopIds)
          if (stopsMap[stopId] != null) stopsMap[stopId]!
      else if (_query.trim().isNotEmpty)
        for (final item in filteredStops.take(15)) item.stop,
    ];

    final markers3D = <GoogleMap3DMarkerData>[
      for (final bus in activeBuses)
        GoogleMap3DMarkerData(
          id: bus.vehicleId,
          position: bus.position,
          shortLabel: bus.lineCode,
          label:
              '${bus.lineCode} • ${bus.passengerCount}/${bus.vehicleCapacity} potnikov (${bus.loadPercent}%) → ${bus.nextStopName}',
          isBus: true,
          color: linesMap[bus.lineId]?.color ?? scheme.secondary,
        ),
      for (final stop in googleStops)
        GoogleMap3DMarkerData(
          id: 'stop_${stop.id}',
          position: stop.position,
          label: stop.name,
          isBus: false,
          color: highlightedLine?.color ?? scheme.primary,
        ),
    ];

    final totalPassengers =
        activeBuses.fold<int>(0, (sum, b) => sum + b.passengerCount);

    return GoogleMap3DWidget(
      initialCenter: location.effectivePosition,
      mapController: _mapController,
      initialUse3D: false,
      showPresets: false,
      showStatusPill: false,
      fitBounds: highlightedLine != null,
      fitSignature: highlightedLine != null && highlightedDirection != null
          ? '${highlightedLine.id}|${highlightedDirection.id}|${roadPoints.length}'
          : '',
      polylines3D: polylines3D,
      markers3D: markers3D,
      polylines2D: polylines,
      markers2D: markers,
      activeBusCount: activeBuses.isNotEmpty ? activeBuses.length : null,
      totalPassengers: activeBuses.isNotEmpty ? totalPassengers : null,
      recenterLabel:
          location.isGps ? l10n.mapCenterOnMe : l10n.mapManualCenter,
      onRecenter2D: () {
        ref.invalidate(userLocationProvider);
        _safeMoveMap(location.effectivePosition, 14.5);
      },
      onFullScreenToggle: () => openFullScreenTransitMap(
        context,
        initialLineId: _highlightedLineId,
        initialDirectionId: _highlightedDirectionId,
        initialVehicleId: _highlightedVehicleId,
      ),
    );
  }

  Widget _buildListContent({
    required BuildContext context,
    required AppLocalizations l10n,
    required List<BusStop> allStops,
    required List<_StopWithDistance> filteredStops,
    required Map<String, BusLine> linesMap,
    required Map<String, BusStop> stopsMap,
    required UserLocationState location,
    required List<BusPosition> activeBuses,
    required BusLine? highlightedLine,
    required bool useSimulatedLive,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (location.showManualFallbackCard) ...[
          ManualLocationFallbackCard(
            stops: allStops,
            selectedStop: location.manualStop,
            onManualStopChanged: (stop) => _safeMoveMap(stop.position, 14.5),
          ),
          const SizedBox(height: 12),
        ],
        if (highlightedLine != null) ...[
          _HighlightedLinePanel(
            line: highlightedLine,
            directionId: _highlightedDirectionId,
            vehicleId: _highlightedVehicleId,
            stopsMap: stopsMap,
            activeBuses: activeBuses,
            useSimulatedLive: useSimulatedLive,
            compactOverlay: false,
            onDirectionSelected: (dirId) =>
                setState(() => _highlightedDirectionId = dirId),
            onClear: () => setState(() {
              _highlightedLineId = null;
              _highlightedDirectionId = null;
              _highlightedVehicleId = null;
            }),
          ),
          const SizedBox(height: 16),
        ],
        if (activeBuses.isNotEmpty) ...[
          Text(
            l10n.mapFilterActiveBuses,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final bus in activeBuses.take(6)) ...[
            _LiveBusListTile(
              bus: bus,
              lineColor: linesMap[bus.lineId]?.color ??
                  Theme.of(context).colorScheme.primary,
              onTap: () {
                final line = linesMap[bus.lineId];
                if (line != null) {
                  _selectLineOrBus(
                    line: line,
                    directionId: bus.directionId,
                    bus: bus,
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
        ],
        Text(
          l10n.homeNearbyStops,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (filteredStops.isEmpty)
          EmptyStateView(
            icon: Icons.location_off_outlined,
            title: l10n.mapNoNearbyStops,
          )
        else
          for (final item in filteredStops) ...[
            _StopDistanceCard(
              stop: item.stop,
              meters: item.meters,
              linesMap: linesMap,
              onTap: () => _openStopBottomSheet(context, item.stop, linesMap),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _StopWithDistance {
  const _StopWithDistance({required this.stop, required this.meters});

  final BusStop stop;
  final double meters;
}

class _MapToggleChip extends StatelessWidget {
  const _MapToggleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 42),
      child: selected
          ? FilledButton.tonalIcon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              icon: Icon(icon),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class _LiveBusListTile extends StatelessWidget {
  const _LiveBusListTile({
    required this.bus,
    required this.lineColor,
    required this.onTap,
  });

  final BusPosition bus;
  final Color lineColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etaMin = (bus.etaToNextStopSeconds / 60).ceil();
    final statusText = localizedDelayStatusLabel(
      l10n,
      bus.status,
      bus.delaySeconds,
    );

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  LineBadge(
                    code: bus.lineCode,
                    color: lineColor,
                    compact: true,
                  ),
                  StatusChip(
                    type: bus.status,
                    label: statusText,
                    compact: true,
                  ),
                  Text(
                    l10n.commonMinutesShort(etaMin),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${l10n.trackerNextStop}: ${bus.nextStopName}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                l10n.linesDirectionTo(bus.directionName),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopDistanceCard extends StatelessWidget {
  const _StopDistanceCard({
    required this.stop,
    required this.meters,
    required this.linesMap,
    required this.onTap,
  });

  final BusStop stop;
  final double meters;
  final Map<String, BusLine> linesMap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final distText = DistanceUtils.formatMeters(meters, l10n);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.mapListDistance(distText),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final lineId in stop.lineIds)
                    LineBadge(
                      code: linesMap[lineId]?.code ?? lineId,
                      color: linesMap[lineId]?.color ??
                          Theme.of(context).colorScheme.primary,
                      compact: true,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              BusStopAmenitiesWrap(stop: stop, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightedLinePanel extends StatelessWidget {
  const _HighlightedLinePanel({
    required this.line,
    required this.directionId,
    required this.vehicleId,
    required this.stopsMap,
    required this.activeBuses,
    required this.useSimulatedLive,
    required this.compactOverlay,
    required this.onDirectionSelected,
    required this.onClear,
  });

  final BusLine line;
  final String? directionId;
  final String? vehicleId;
  final Map<String, BusStop> stopsMap;
  final List<BusPosition> activeBuses;
  final bool useSimulatedLive;
  final bool compactOverlay;
  final ValueChanged<String> onDirectionSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final direction = (directionId != null
            ? line.directionById(directionId!)
            : null) ??
        line.directions.first;
    final matchingBus = activeBuses.cast<BusPosition?>().firstWhere(
          (b) =>
              b != null &&
              (vehicleId != null
                  ? b.vehicleId == vehicleId
                  : b.lineId == line.id && b.directionId == direction.id),
          orElse: () => null,
        );

    final now = DateTime.now();
    final arrivalEstimates = _computeStopArrivalTimes(
      line: line,
      direction: direction,
      now: now,
      delaySeconds: useSimulatedLive ? (matchingBus?.delaySeconds ?? 0) : 0,
    );

    final trackerUri =
        '/tracker?lineId=${Uri.encodeComponent(line.id)}'
        '${matchingBus != null ? '&vehicleId=${Uri.encodeComponent(matchingBus.vehicleId)}' : ''}';

    return Card(
      elevation: compactOverlay ? 4 : 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                LineBadge(code: line.code, color: line.color, compact: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.mapFollowingLine(line.code),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Semantics(
                  button: true,
                  label: l10n.a11yCloseButton,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.commonClose,
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 56,
                    ),
                    onPressed: onClear,
                  ),
                ),
              ],
            ),
            Text(
              l10n.linesDirectionTo(direction.name),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (line.directions.length > 1 && !compactOverlay) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final dir in line.directions)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: dir.id == direction.id
                          ? FilledButton(
                              onPressed: () {},
                              child: Text(dir.name),
                            )
                          : OutlinedButton(
                              onPressed: () => onDirectionSelected(dir.id),
                              child: Text(dir.name),
                            ),
                    ),
                ],
              ),
            ],
            if (!compactOverlay) ...[
              const SizedBox(height: 10),
              Column(
                children: [
                  for (var i = 0; i < arrivalEstimates.length; i++) ...[
                    _buildArrivalRow(context, arrivalEstimates[i]),
                    if (i < arrivalEstimates.length - 1)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 10),
            BigButton(
              icon: Icons.gps_fixed_rounded,
              label: l10n.linesFollowBusLive,
              expanded: true,
              onPressed: () => context.push(trackerUri),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalRow(BuildContext context, (String, DateTime) entry) {
    final stopName = stopsMap[entry.$1]?.name ?? entry.$1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              stopName,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            TimeFormatUtils.formatTime24(entry.$2),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }

  List<(String, DateTime)> _computeStopArrivalTimes({
    required BusLine line,
    required LineDirection direction,
    required DateTime now,
    required int delaySeconds,
  }) {
    final trips = generateTripsForDirection(
      line: line,
      direction: direction,
      date: now,
    );
    if (trips.isEmpty) return const [];
    final activeOrNext = trips.firstWhere(
      (t) => !t.endTime.add(Duration(seconds: delaySeconds)).isBefore(now),
      orElse: () => trips.last,
    );
    return [
      for (var i = 0; i < direction.stopIds.length; i++)
        (
          direction.stopIds[i],
          activeOrNext.stopTimes[i].add(Duration(seconds: delaySeconds)),
        ),
    ];
  }
}

class _StopMapBottomSheet extends ConsumerWidget {
  const _StopMapBottomSheet({
    required this.stop,
    required this.linesMap,
    required this.onOpenStopPage,
    required this.onSelectLine,
  });

  final BusStop stop;
  final Map<String, BusLine> linesMap;
  final VoidCallback onOpenStopPage;
  final ValueChanged<BusLine> onSelectLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favorites = ref.watch(favoritesProvider);
    final settings = ref.watch(a11ySettingsProvider);
    final isOffline = ref.watch(isOfflineProvider);
    final now = DateTime.now();
    final isFav = favorites.isStopFavorite(stop.id);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return FutureBuilder<List<Departure>>(
          future: ref.read(timetableRepositoryProvider).getDeparturesForStop(
                stop.id,
                at: now,
                limit: 5,
                useSimulatedLive: settings.useSimulatedLive,
                isOffline: isOffline,
              ),
          builder: (context, snapshot) {
            final departures = snapshot.data ?? const <Departure>[];
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stop.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Semantics(
                      button: true,
                      toggled: isFav,
                      label: l10n.a11yFavoriteToggle,
                      child: IconButton(
                        icon: Icon(
                          isFav
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                        ),
                        tooltip: isFav
                            ? l10n.stopRemoveFromFavorites
                            : l10n.stopAddToFavorites,
                        constraints: const BoxConstraints(
                          minWidth: 56,
                          minHeight: 56,
                        ),
                        onPressed: () => ref
                            .read(favoritesProvider.notifier)
                            .toggleStop(stop.id),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: l10n.a11yCloseButton,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: l10n.commonClose,
                        constraints: const BoxConstraints(
                          minWidth: 56,
                          minHeight: 56,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
                if (stop.platform != null) ...[
                  Text(
                    l10n.stopPlatform(stop.platform!),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                ],
                BusStopAmenitiesWrap(stop: stop, compact: true),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final lineId in stop.lineIds)
                      if (linesMap[lineId] != null)
                        InkWell(
                          onTap: () => onSelectLine(linesMap[lineId]!),
                          borderRadius: BorderRadius.circular(10),
                          child: LineBadge(
                            code: linesMap[lineId]!.code,
                            color: linesMap[lineId]!.color,
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 14),
                BigButton(
                  icon: Icons.departure_board_rounded,
                  label: l10n.mapStopDetailsOpen,
                  expanded: true,
                  onPressed: onOpenStopPage,
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.stopUpcomingDepartures,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    departures.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (departures.isEmpty)
                  Text(l10n.stopNoDepartures)
                else
                  for (final dep in departures) ...[
                    DepartureTileCard(
                      departure: dep,
                      now: now,
                      lineColor: linesMap[dep.lineId]?.color,
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            );
          },
        );
      },
    );
  }
}
