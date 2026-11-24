// Dedicated full-screen Google Maps view of all 19 Marprom lines, street routes, and live buses.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/bus_position.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/seed/seed_lines.dart';
import '../../data/seed/seed_stops.dart';
import '../network/route_geometry_service.dart';
import '../theme/colors.dart';
import '../utils/geo.dart';
import 'google_map_3d_widget.dart';
import 'google_map_models.dart';
import 'google_web_views.dart';

/// Launches a true full-screen interactive Google Maps route & live fleet page over the root navigator.
Future<void> openFullScreenTransitMap(
  BuildContext context, {
  String? initialLineId,
  String? initialDirectionId,
  String? initialVehicleId,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => FullScreenTransitMapPage(
        initialLineId: initialLineId,
        initialDirectionId: initialDirectionId,
        initialVehicleId: initialVehicleId,
      ),
    ),
  );
}

/// Edge-to-edge interactive transit map displaying Google Routes street polylines and live Marprom buses.
class FullScreenTransitMapPage extends ConsumerStatefulWidget {
  /// Creates a [FullScreenTransitMapPage].
  const FullScreenTransitMapPage({
    super.key,
    this.initialLineId,
    this.initialDirectionId,
    this.initialVehicleId,
  });

  /// Optional line ID (`G1`..`P19`) focused when opening.
  final String? initialLineId;

  /// Optional direction ID focused when opening.
  final String? initialDirectionId;

  /// Optional vehicle ID centered when opening.
  final String? initialVehicleId;

  @override
  ConsumerState<FullScreenTransitMapPage> createState() =>
      _FullScreenTransitMapPageState();
}

class _FullScreenTransitMapPageState
    extends ConsumerState<FullScreenTransitMapPage> {
  final MapController _mapController = MapController();
  String? _selectedLineId;
  int _directionIndex = 0;
  bool _controlsCollapsed = false;

  @override
  void initState() {
    super.initState();
    _selectedLineId = widget.initialLineId;
    if (_selectedLineId != null && widget.initialDirectionId != null) {
      final line = seedLinesById[_selectedLineId!];
      if (line != null) {
        final idx = line.directions.indexWhere(
          (d) => d.id == widget.initialDirectionId,
        );
        if (idx >= 0) _directionIndex = idx;
      }
    }

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

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final liveBuses = ref.watch(liveBusesStreamProvider).valueOrNull ??
        ref.watch(busSimulatorProvider).snapshotAt(DateTime.now());
    final googleRoutesMap = ref.watch(googleLineRoutesProvider);

    final selectedLine =
        _selectedLineId != null ? seedLinesById[_selectedLineId!] : null;
    final selectedDirection = selectedLine != null
        ? selectedLine.directions[
            _directionIndex.clamp(0, selectedLine.directions.length - 1)]
        : null;

    final selectedKey = selectedLine != null && selectedDirection != null
        ? '${selectedLine.id}|${selectedDirection.id}'
        : null;
    final selectedRouteAsync = selectedKey != null
        ? ref.watch(routeGeometryProvider(selectedKey))
        : null;
    final selectedGoogleRoute =
        selectedKey != null ? googleRoutesMap[selectedKey] : null;

    final visibleBuses = selectedLine == null
        ? liveBuses
        : liveBuses
            .where((b) => b.lineId == selectedLine.id)
            .toList(growable: false);

    BusPosition? focusedVehicle;
    if (widget.initialVehicleId != null) {
      for (final b in liveBuses) {
        if (b.vehicleId == widget.initialVehicleId) {
          focusedVehicle = b;
          break;
        }
      }
    }

    final polylines3D = <GoogleMap3DPolylineData>[];
    final polylines2D = <Polyline>[];

    if (selectedLine != null && selectedDirection != null) {
      final pts = selectedGoogleRoute?.polylinePoints ??
          selectedRouteAsync?.valueOrNull ??
          selectedDirection.roadPolyline ??
          selectedDirection.polyline;
      if (pts.length >= 2) {
        polylines3D.add(
          GoogleMap3DPolylineData(
            id: '${selectedLine.id}_${selectedDirection.id}',
            points: pts,
            color: selectedLine.color,
            strokeWidth: 7,
          ),
        );
        polylines2D.add(
          Polyline(
            points: pts,
            color: selectedLine.color,
            strokeWidth: 6,
            borderColor: Colors.white,
            borderStrokeWidth: 2,
          ),
        );
      }
    } else {
      final activeLineIds = {for (final b in liveBuses) b.lineId};
      for (final line in seedLines) {
        final dir = line.directions.first;
        final routeKey = '${line.id}|${dir.id}';
        final googleRoute = googleRoutesMap[routeKey];
        if (googleRoute == null && !activeLineIds.contains(line.id)) {
          continue;
        }
        final pts =
            googleRoute?.polylinePoints ?? dir.roadPolyline ?? dir.polyline;
        if (pts.length < 2) continue;
        polylines3D.add(
          GoogleMap3DPolylineData(
            id: line.id,
            points: pts,
            color: line.color,
            strokeWidth: activeLineIds.contains(line.id) ? 5 : 3.5,
          ),
        );
        polylines2D.add(
          Polyline(
            points: pts,
            color: line.color.withValues(alpha: 0.8),
            strokeWidth: activeLineIds.contains(line.id) ? 4.5 : 3.0,
          ),
        );
      }
    }

    final markers3D = <GoogleMap3DMarkerData>[
      for (final bus in visibleBuses)
        GoogleMap3DMarkerData(
          id: bus.vehicleId,
          position: bus.position,
          shortLabel: bus.lineCode,
          label:
              '${bus.lineCode} (${bus.vehicleId}) • ${bus.passengerCount}/${bus.vehicleCapacity} potnikov → ${bus.nextStopName}',
          isBus: true,
          color: seedLinesById[bus.lineId]?.color ?? MarpromColors.marpromRed,
        ),
      if (selectedLine != null && selectedDirection != null)
        for (final stopId in selectedDirection.stopIds)
          if (seedStopsById[stopId] != null)
            GoogleMap3DMarkerData(
              id: 'stop_$stopId',
              position: seedStopsById[stopId]!.position,
              label: seedStopsById[stopId]!.name,
              isBus: false,
              color: selectedLine.color,
            ),
    ];

    final markers2D = <Marker>[
      if (selectedLine != null && selectedDirection != null)
        for (final stopId in selectedDirection.stopIds)
          if (seedStopsById[stopId] != null)
            Marker(
              point: seedStopsById[stopId]!.position,
              width: 24,
              height: 24,
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: selectedLine.color, width: 2.5),
                  ),
                ),
              ),
            ),
      for (final bus in visibleBuses)
        Marker(
          point: bus.position,
          width: 48,
          height: 26,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: seedLinesById[bus.lineId]?.color ?? MarpromColors.marpromRed,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              bus.lineCode,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
    ];

    final initialCenter = focusedVehicle?.position ??
        (polylines3D.isNotEmpty
            ? polylines3D.first.points[polylines3D.first.points.length ~/ 2]
            : GeoUtils.mariborCenter);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap3DWidget(
              key: const Key('fullscreen_google_map'),
              initialCenter: initialCenter,
              initialZoom: 13.6,
              mapController: _mapController,
              initialUse3D: false,
              showPresets: false,
              showStatusPill: true,
              isFullScreen: true,
              fitBounds: selectedLine != null,
              fitSignature:
                  '${selectedLine?.id}|${selectedDirection?.id}|${polylines3D.isNotEmpty ? polylines3D.first.points.length : 0}',
              polylines3D: polylines3D,
              markers3D: markers3D,
              polylines2D: polylines2D,
              markers2D: markers2D,
              activeBusCount: visibleBuses.length,
              totalPassengers: visibleBuses.fold<int>(
                0,
                (sum, b) => sum + b.passengerCount,
              ),
              onFullScreenToggle: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: SafeArea(
              top: false,
              child: _controlsCollapsed
                  ? Align(
                      alignment: Alignment.bottomLeft,
                      child: Material(
                        color: scheme.surface.withValues(alpha: 0.95),
                        elevation: 5,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () =>
                              setState(() => _controlsCollapsed = false),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.directions_bus_rounded,
                                  size: 18,
                                  color: MarpromColors.marpromRed,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  selectedLine != null
                                      ? 'Linija ${selectedLine.code}'
                                      : 'Linije G1–P19',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : Material(
                      color: scheme.surface.withValues(alpha: 0.95),
                      elevation: 6,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.alt_route_rounded,
                                  size: 18,
                                  color: selectedLine?.color ??
                                      MarpromColors.marpromRed,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        selectedLine != null &&
                                                selectedDirection != null
                                            ? '${selectedLine.code}: ${selectedDirection.name}'
                                            : 'Vse mariborske linije G1–G6 & P7–P19',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (selectedGoogleRoute != null)
                                        Text(
                                          '${selectedGoogleRoute.formattedDistanceKm} • ~${selectedGoogleRoute.formattedDurationMinutes} (${selectedGoogleRoute.isLiveApi ? 'Google Routes API' : 'Cestna ocena'})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (selectedLine != null &&
                                    selectedLine.directions.length > 1)
                                  IconButton(
                                    tooltip: 'Obrni smer',
                                    constraints: const BoxConstraints(
                                      minWidth: 38,
                                      minHeight: 38,
                                    ),
                                    icon: const Icon(
                                      Icons.swap_horiz_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() {
                                      _directionIndex = (_directionIndex + 1) %
                                          selectedLine.directions.length;
                                    }),
                                  ),
                                IconButton(
                                  tooltip: 'Skrij vrstico',
                                  constraints: const BoxConstraints(
                                    minWidth: 38,
                                    minHeight: 38,
                                  ),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 22,
                                  ),
                                  onPressed: () => setState(
                                    () => _controlsCollapsed = true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 36,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: const Text('Vse'),
                                      selected: _selectedLineId == null,
                                      onSelected: (_) => setState(() {
                                        _selectedLineId = null;
                                        _directionIndex = 0;
                                      }),
                                    ),
                                  ),
                                  for (final line in seedLines)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(line.code),
                                        selected: _selectedLineId == line.id,
                                        selectedColor: line.color.withValues(
                                          alpha: 0.20,
                                        ),
                                        onSelected: (_) {
                                          setState(() {
                                            _selectedLineId = line.id;
                                            _directionIndex = 0;
                                          });
                                          if (!isFlutterTestEnvironment) {
                                            ref
                                                .read(
                                                  googleLineRoutesProvider
                                                      .notifier,
                                                )
                                                .ensureLineLoaded(line.id);
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
