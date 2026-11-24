//**********************************************
// Web Route Planner with Multi-Bus Transfers  *
//**********************************************

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/accessibility/a11y_settings.dart';
import '../../../../core/firebase/firestore_transit_service.dart';
import '../../../../core/maps/google_map_3d_widget.dart';
import '../../../../core/maps/google_map_models.dart';
import '../../../../core/maps/google_web_views.dart';
import '../../../../core/network/google_routes_service.dart';
import '../../../../core/network/route_geometry_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/occupancy_strip.dart';
import '../../../../data/models/bus_stop.dart';
import '../../../../data/models/trip_plan.dart';
import '../../../../data/repositories/repository_providers.dart';
import '../../../../data/seed/seed_lines.dart';
import '../../../../data/seed/seed_stops.dart';
import '../../../trip_planner/domain/route_planner.dart';

/// Marprom Web Route Planner (`/plan`) powered by Google Routes API v2
/// (`TRANSIT` + `DRIVE`) and the multi-transfer Marprom G1–G6 & P7–P19 solver.
class WebRoutePlannerPage extends ConsumerStatefulWidget {
  /// Creates a [WebRoutePlannerPage].
  const WebRoutePlannerPage({
    super.key,
    this.initialFromStopId,
    this.initialToStopId,
    this.initialToName,
  });

  /// Optional initial origin stop ID from query parameters.
  final String? initialFromStopId;

  /// Optional initial destination stop ID from query parameters.
  final String? initialToStopId;

  /// Optional destination address/place label from query parameters.
  final String? initialToName;

  @override
  ConsumerState<WebRoutePlannerPage> createState() =>
      _WebRoutePlannerPageState();
}

class _WebRoutePlannerPageState extends ConsumerState<WebRoutePlannerPage> {
  final TextEditingController _originAddressController = TextEditingController(
    text: 'Avtobusna postaja Maribor, Mlinska ulica 1, Maribor',
  );
  final TextEditingController _destAddressController = TextEditingController(
    text: 'Pohorska vzpenjača, Pohorska ulica 60, Maribor',
  );

  String _fromStopId = 'glavna_postaja';
  String _toStopId = 'vzpenjaca';
  bool _useCustomAddress = false;
  bool _avoidTolls = false;
  bool _avoidHighways = false;
  bool _accessibleOnly = false;
  TripSortMode _sortMode = TripSortMode.fastest;

  bool _loading = false;
  GoogleRouteResult? _googleRoute;
  List<TripOption> _busOptions = const [];
  int _selectedOptionIndex = 0;

  @override
  void initState() {
    super.initState();
    _accessibleOnly = ref.read(a11ySettingsProvider).wheelchairAccessibleOnly;
    if (widget.initialFromStopId != null &&
        seedStopsById.containsKey(widget.initialFromStopId)) {
      _fromStopId = widget.initialFromStopId!;
    }
    if (widget.initialToStopId != null &&
        seedStopsById.containsKey(widget.initialToStopId)) {
      _toStopId = widget.initialToStopId!;
    }
    if (widget.initialToName != null && widget.initialToName!.isNotEmpty) {
      _destAddressController.text = widget.initialToName!;
    }
    _syncAddressControllersFromStops();
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateRoute());
  }

  @override
  void dispose() {
    _originAddressController.dispose();
    _destAddressController.dispose();
    super.dispose();
  }

  void _syncAddressControllersFromStops() {
    final from = seedStopsById[_fromStopId];
    final to = seedStopsById[_toStopId];
    if (from != null) {
      _originAddressController.text = '${from.name}, 2000 Maribor, Slovenia';
    }
    if (to != null) {
      _destAddressController.text = '${to.name}, 2000 Maribor, Slovenia';
    }
  }

  Future<void> _calculateRoute() async {
    setState(() => _loading = true);
    final routesService = ref.read(googleRoutesServiceProvider);
    final planner = ref.read(routePlannerProvider);

    final fromStop = seedStopsById[_fromStopId];
    final toStop = seedStopsById[_toStopId];

    GoogleRouteResult routeResult;
    List<TripOption> transitOptions = const [];

    if (_useCustomAddress) {
      routeResult = isFlutterTestEnvironment
          ? GoogleRoutesService.buildOfflineFallback(
              origin: const LatLng(46.5594, 15.6561),
              destination: const LatLng(46.5343, 15.6042),
            )
          : await routesService.computeRouteByAddresses(
              originAddress: _originAddressController.text.trim(),
              destinationAddress: _destAddressController.text.trim(),
              travelMode: 'DRIVE',
              avoidTolls: _avoidTolls,
              avoidHighways: _avoidHighways,
            );
    } else if (fromStop != null && toStop != null) {
      final results = await Future.wait([
        isFlutterTestEnvironment
            ? Future.value(
                GoogleRoutesService.buildOfflineFallback(
                  origin: fromStop.position,
                  destination: toStop.position,
                ),
              )
            : routesService.computeRouteByCoordinates(
                origin: fromStop.position,
                destination: toStop.position,
                travelMode: 'DRIVE',
                avoidTolls: _avoidTolls,
                avoidHighways: _avoidHighways,
              ),
        planner.planTrip(
          origin: fromStop.position,
          destination: toStop.position,
          originLabel: fromStop.name,
          destinationLabel: toStop.name,
          accessibleOnly: _accessibleOnly,
          sortMode: _sortMode,
          fewerTransfers: _sortMode == TripSortMode.fewestTransfers,
          targetTime: DateTime.now(),
        ),
      ]);
      routeResult = results[0] as GoogleRouteResult;
      transitOptions = results[1] as List<TripOption>;
    } else {
      routeResult = GoogleRoutesService.buildOfflineFallback(
        origin: const LatLng(46.5594, 15.6561),
        destination: const LatLng(46.5343, 15.6042),
      );
    }

    if (!mounted) return;
    setState(() {
      _googleRoute = routeResult;
      _busOptions = transitOptions;
      _selectedOptionIndex = 0;
      _loading = false;
    });
  }

  void _applyPreset({
    String? fromStop,
    String? toStop,
    String? customOrigin,
    String? customDest,
    bool avoidTolls = false,
    bool avoidHighways = false,
  }) {
    setState(() {
      _avoidTolls = avoidTolls;
      _avoidHighways = avoidHighways;
      if (customOrigin != null && customDest != null) {
        _useCustomAddress = true;
        _originAddressController.text = customOrigin;
        _destAddressController.text = customDest;
      } else if (fromStop != null && toStop != null) {
        _useCustomAddress = false;
        _fromStopId = fromStop;
        _toStopId = toStop;
        _syncAddressControllersFromStops();
      }
    });
    _calculateRoute();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1040;
    final scheme = Theme.of(context).colorScheme;
    final sortedStops = List<BusStop>.from(seedStops)
      ..sort((a, b) => a.name.compareTo(b.name));

    final embedOrigin = _originAddressController.text.trim().isNotEmpty
        ? _originAddressController.text.trim()
        : 'Maribor, Slovenia';
    final embedDest = _destAddressController.text.trim().isNotEmpty
        ? _destAddressController.text.trim()
        : 'Pohorska vzpenjaca, Maribor';

    final googleRoutesMap = ref.watch(googleLineRoutesProvider);
    final selectedBusOption = (!_useCustomAddress && _busOptions.isNotEmpty)
        ? _busOptions[_selectedOptionIndex.clamp(0, _busOptions.length - 1)]
        : null;

    final mapPolylines3D = <GoogleMap3DPolylineData>[];
    final mapMarkers3D = <GoogleMap3DMarkerData>[];
    final allMapPoints = <LatLng>[];

    if (selectedBusOption != null) {
      for (var i = 0; i < selectedBusOption.legs.length; i++) {
        final leg = selectedBusOption.legs[i];
        var pts = leg.polyline;
        if (leg.type == TripLegType.bus &&
            leg.lineId != null &&
            leg.directionId != null &&
            pts.length >= 2) {
          final full = googleRoutesMap['${leg.lineId}|${leg.directionId}']
              ?.polylinePoints;
          if (full != null && full.length >= 2) {
            pts = slicePolylineBetweenPoints(full, pts.first, pts.last);
          }
        }
        if (pts.isEmpty) continue;
        allMapPoints.addAll(pts);
        final isWalk = leg.type == TripLegType.walk;
        final lineColor =
            seedLinesById[leg.lineId]?.color ?? MarpromColors.marpromRed;
        if (pts.length >= 2) {
          mapPolylines3D.add(
            GoogleMap3DPolylineData(
              id: 'web_leg_${selectedBusOption.id}_$i',
              points: pts,
              color: isWalk ? scheme.outline : lineColor,
              strokeWidth: isWalk ? 4.0 : 6.5,
              isDashed: isWalk,
            ),
          );
        }
        if (i == 0) {
          mapMarkers3D.add(
            GoogleMap3DMarkerData(
              id: 'origin_pt',
              position: pts.first,
              label: leg.fromName,
              color: scheme.secondary,
            ),
          );
        }
        if (!isWalk) {
          mapMarkers3D.add(
            GoogleMap3DMarkerData(
              id: 'board_$i',
              position: pts.first,
              shortLabel: leg.lineCode,
              isBus: leg.lineCode != null,
              isWheelchairAccessible: leg.isAccessible,
              label: '${leg.lineCode ?? ''} • ${leg.fromName}',
              color: lineColor,
            ),
          );
          mapMarkers3D.add(
            GoogleMap3DMarkerData(
              id: 'alight_$i',
              position: pts.last,
              label: leg.toName,
              color: lineColor,
            ),
          );
        }
        if (i == selectedBusOption.legs.length - 1) {
          mapMarkers3D.add(
            GoogleMap3DMarkerData(
              id: 'dest_pt',
              position: pts.last,
              label: leg.toName,
              color: MarpromColors.marpromRed,
            ),
          );
        }
      }
    } else if (_googleRoute != null && _googleRoute!.polylinePoints.length >= 2) {
      allMapPoints.addAll(_googleRoute!.polylinePoints);
      mapPolylines3D.add(
        GoogleMap3DPolylineData(
          id: 'planned_route',
          points: _googleRoute!.polylinePoints,
          color: MarpromColors.marpromRed,
          strokeWidth: 7,
        ),
      );
      mapMarkers3D.addAll([
        GoogleMap3DMarkerData(
          id: 'origin',
          position: _googleRoute!.polylinePoints.first,
          label: embedOrigin,
        ),
        GoogleMap3DMarkerData(
          id: 'dest',
          position: _googleRoute!.polylinePoints.last,
          label: embedDest,
        ),
      ]);
    }

    final center3D = allMapPoints.isNotEmpty
        ? allMapPoints[allMapPoints.length ~/ 2]
        : (seedStopsById[_fromStopId]?.position ??
            const LatLng(46.5576, 15.6455));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Načrtovalec poti — Marprom & Google Routes API v2',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Izračunajte optimalno pot z avtobusi Marprom (G1–G6 & P7–P19) ter pridobite natančno razdaljo, trajanje in navodila prek Google Maps Directions & Routes API v2.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // Quick route presets
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.cable_rounded, size: 16),
                    label: const Text('AP Maribor → Pohorska vzpenjača'),
                    onPressed: () => _applyPreset(
                      fromStop: 'glavna_postaja',
                      toStop: 'vzpenjaca',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.local_hospital_rounded, size: 16),
                    label: const Text('Glavni trg → UKC Maribor'),
                    onPressed: () => _applyPreset(
                      fromStop: 'glavni_trg',
                      toStop: 'ukc_maribor',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.factory_rounded, size: 16),
                    label: const Text('Koroška vrata → Cona Tezno'),
                    onPressed: () => _applyPreset(
                      fromStop: 'koroska_vrata',
                      toStop: 'cona_tezno',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.transfer_within_a_station_rounded, size: 16),
                    label: const Text('Koroška vrata → Pohorska vzpenjača (Prestop)'),
                    onPressed: () => _applyPreset(
                      fromStop: 'koroska_vrata',
                      toStop: 'vzpenjaca',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Controls + Routes API Telemetry + Marprom Bus Itineraries
                  Expanded(
                    flex: isWide ? 5 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Postajališča Marprom'),
                                      selected: !_useCustomAddress,
                                      onSelected: (_) {
                                        setState(() {
                                          _useCustomAddress = false;
                                          _syncAddressControllersFromStops();
                                        });
                                        _calculateRoute();
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Poljubni naslov (Routes API)'),
                                      selected: _useCustomAddress,
                                      onSelected: (_) => setState(
                                        () => _useCustomAddress = true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (!_useCustomAddress) ...[
                                  DropdownButtonFormField<String>(
                                    initialValue: _fromStopId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Začetno postajališče',
                                      prefixIcon:
                                          Icon(Icons.my_location_rounded),
                                    ),
                                    items: [
                                      for (final stop in sortedStops)
                                        DropdownMenuItem(
                                          value: stop.id,
                                          child: Text(stop.name),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _fromStopId = v;
                                          _syncAddressControllersFromStops();
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _toStopId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Ciljno postajališče',
                                      prefixIcon: Icon(Icons.flag_rounded),
                                    ),
                                    items: [
                                      for (final stop in sortedStops)
                                        DropdownMenuItem(
                                          value: stop.id,
                                          child: Text(stop.name),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _toStopId = v;
                                          _syncAddressControllersFromStops();
                                        });
                                      }
                                    },
                                  ),
                                ] else ...[
                                  TextField(
                                    controller: _originAddressController,
                                    decoration: const InputDecoration(
                                      labelText: 'Izvor (naslov)',
                                      prefixIcon:
                                          Icon(Icons.my_location_rounded),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _destAddressController,
                                    decoration: const InputDecoration(
                                      labelText: 'Cilj (naslov)',
                                      prefixIcon: Icon(Icons.flag_rounded),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      avatar: const Icon(Icons.bolt_rounded, size: 16),
                                      label: const Text('Najhitrejša'),
                                      selected: _sortMode == TripSortMode.fastest,
                                      onSelected: (_) {
                                        setState(() => _sortMode = TripSortMode.fastest);
                                        _calculateRoute();
                                      },
                                    ),
                                    ChoiceChip(
                                      avatar: const Icon(Icons.transfer_within_a_station_rounded, size: 16),
                                      label: const Text('Najmanj prestopov'),
                                      selected:
                                          _sortMode == TripSortMode.fewestTransfers,
                                      onSelected: (_) {
                                        setState(() => _sortMode = TripSortMode.fewestTransfers);
                                        _calculateRoute();
                                      },
                                    ),
                                    FilterChip(
                                      avatar: const Icon(Icons.accessible_rounded, size: 16),
                                      label: const Text('Dostopno za voziček'),
                                      selected: _accessibleOnly,
                                      onSelected: (v) {
                                        setState(() => _accessibleOnly = v);
                                        _calculateRoute();
                                      },
                                    ),
                                    if (_useCustomAddress) ...[
                                      FilterChip(
                                        label: const Text('Brez cestnin'),
                                        selected: _avoidTolls,
                                        onSelected: (v) =>
                                            setState(() => _avoidTolls = v),
                                      ),
                                      FilterChip(
                                        label: const Text('Brez avtocest'),
                                        selected: _avoidHighways,
                                        onSelected: (v) =>
                                            setState(() => _avoidHighways = v),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: MarpromColors.marpromRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: _loading ? null : _calculateRoute,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.route_rounded),
                                  label: const Text(
                                    'Izračunaj pot (Routes API v2 + Marprom)',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Google Routes API v2 Output Card
                        if (_googleRoute != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.api_rounded,
                                        color: Color(0xFF0057B8),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Google Routes API v2 (computeRoutes)',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (_googleRoute!.isLiveApi
                                                  ? MarpromColors.mobilityGreen
                                                  : const Color(0xFFD97706))
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _googleRoute!.isLiveApi
                                              ? 'Google API v živo'
                                              : 'Lokalni izračun',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _googleRoute!.isLiveApi
                                                ? MarpromColors.mobilityGreen
                                                : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MetricTile(
                                          label: 'Razdalja (distanceMeters)',
                                          value:
                                              '${_googleRoute!.formattedDistanceKm} (${_googleRoute!.distanceMeters} m)',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _MetricTile(
                                          label: 'Čas vožnje (duration)',
                                          value:
                                              '${_googleRoute!.formattedDurationMinutes} (${_googleRoute!.rawDuration})',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: MarpromColors.marpromCharcoal,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: SelectableText(
                                      _googleRoute!.toPrettyJsonSummary(),
                                      style: const TextStyle(
                                        color: Color(0xFF93C5FD),
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Marprom Bus Route Options
                        if (!_useCustomAddress) ...[
                          Text(
                            'Priporočene povezave Marprom (${_busOptions.length})',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (_busOptions.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(18),
                                child: Text(
                                  'Izberite dve različni postajališči v Mariboru za prikaz odhodov linij G1–G6 in P7–P19.',
                                ),
                              ),
                            )
                          else
                            for (var i = 0; i < _busOptions.length; i++) ...[
                              _BusItineraryCard(
                                option: _busOptions[i],
                                isSelected: i == _selectedOptionIndex,
                                onTap: () =>
                                    setState(() => _selectedOptionIndex = i),
                              ),
                              const SizedBox(height: 10),
                            ],
                        ],
                      ],
                    ),
                  ),

                  SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 24),

                  // Right Map Panel: Real Google Maps Vector 2D & 3D Flyover
                  Expanded(
                    flex: isWide ? 6 : 0,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.route_rounded,
                                  size: 18,
                                  color: MarpromColors.marpromRed,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    selectedBusOption != null
                                        ? 'Google Maps trasa (${selectedBusOption.transferCount == 0 ? 'direktna linija' : '${selectedBusOption.transferCount} prestop'})'
                                        : 'Google Maps Routes API v2 trasa',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (selectedBusOption != null)
                                  TextButton.icon(
                                    onPressed: () async {
                                      final user = ref.read(currentUserProvider).valueOrNull;
                                      if (user == null) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Za shranjevanje poti se prijavite v račun.'),
                                            ),
                                          );
                                        }
                                        return;
                                      }
                                      final from = seedStopsById[_fromStopId];
                                      final to = seedStopsById[_toStopId];
                                      final lineIds = selectedBusOption.legs
                                          .where((l) => l.lineCode != null)
                                          .map((l) => l.lineCode!)
                                          .toSet()
                                          .toList(growable: false);
                                      final now = DateTime.now();
                                      await ref.read(firestoreTransitServiceProvider).saveRoute(
                                            SavedRouteRecord(
                                              id: 'route_${now.millisecondsSinceEpoch}',
                                              userId: user.id,
                                              originName: from?.name ?? embedOrigin,
                                              destinationName: to?.name ?? embedDest,
                                              originStopId: from?.id,
                                              destinationStopId: to?.id,
                                              originLat: from?.position.latitude,
                                              originLng: from?.position.longitude,
                                              destinationLat: to?.position.latitude,
                                              destinationLng: to?.position.longitude,
                                              lineIds: lineIds,
                                              accessibleOnly: _accessibleOnly,
                                              createdAt: now,
                                              updatedAt: now,
                                            ),
                                          );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Pot shranjena v račun.'),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                                    label: const Text('Shrani pot'),
                                  ),
                                if (selectedBusOption?.isAccessible == true)
                                  const Tooltip(
                                    message: 'Vsi avtobusi dostopni z vozičkom',
                                    child: Icon(
                                      Icons.accessible_rounded,
                                      size: 20,
                                      color: MarpromColors.mobilityGreen,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 540,
                            child: GoogleMap3DWidget(
                              initialCenter: center3D,
                              initialUse3D: false,
                              showPresets: true,
                              fitBounds: allMapPoints.length >= 2,
                              fitSignature:
                                  '${selectedBusOption?.id ?? 'raw'}|${allMapPoints.length}',
                              polylines3D: mapPolylines3D,
                              markers3D: mapMarkers3D,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _BusItineraryCard extends StatelessWidget {
  const _BusItineraryCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final TripOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busLegs = option.legs
        .where((l) => l.type == TripLegType.bus)
        .toList(growable: false);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? MarpromColors.marpromRed : scheme.outlineVariant,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${TimeFormatUtils.formatTime24(option.departureTime)} → ${TimeFormatUtils.formatTime24(option.arrivalTime)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (option.isAccessible) ...[
                    const Icon(
                      Icons.accessible_rounded,
                      size: 18,
                      color: MarpromColors.mobilityGreen,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Chip(
                    label: Text(
                      '${option.totalMinutes} min • ${option.transferCount == 0 ? 'Direktna' : '${option.transferCount} prestop'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (option.transfers.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final xfer in option.transfers)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Prestop: ${xfer.alightingStopName}'
                      '${xfer.boardingStopName != xfer.alightingStopName ? ' → ${xfer.boardingStopName}' : ''}'
                      ' (${xfer.fromLineCode} → ${xfer.toLineCode}) • čakanje ${xfer.waitMinutes} min'
                      '${xfer.walkMeters > 15 ? ' • hoja ${xfer.walkMeters.round()} m' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              for (final leg in busLegs) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: seedLinesById[leg.lineId]?.color ??
                            MarpromColors.marpromRed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        leg.lineCode ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${leg.fromName} → ${leg.toName} (${TimeFormatUtils.formatTime24(leg.startTime)})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${leg.stopCount ?? 0} postaj',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (leg.occupancy != BusOccupancyLevel.unknown) ...[
                  const SizedBox(height: 6),
                  OccupancyStrip(level: leg.occupancy, compact: true),
                ],
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
