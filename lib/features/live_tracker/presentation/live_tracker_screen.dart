//**********************************************
// All Buses Screen (Live Fleet + Google Roads)*
//**********************************************

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/accessibility/semantics_helpers.dart';
import 'package:m_mobilnost/core/maps/google_map_3d_widget.dart';
import 'package:m_mobilnost/core/maps/google_map_models.dart';
import 'package:m_mobilnost/core/maps/google_web_views.dart';
import 'package:m_mobilnost/core/network/route_geometry_service.dart';
import 'package:m_mobilnost/core/theme/colors.dart';
import 'package:m_mobilnost/core/utils/geo.dart';
import 'package:m_mobilnost/core/widgets/bus_occupancy_cutaway.dart';
import 'package:m_mobilnost/core/widgets/ui_kit.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/bus_position.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/seed/seed_lines.dart';
import 'package:m_mobilnost/features/lines/data/transit_providers.dart';
import 'package:m_mobilnost/features/lines/presentation/widgets/line_badge.dart';
import 'package:m_mobilnost/features/trip_planner/presentation/widgets/trip_endpoint.dart';
import 'package:m_mobilnost/features/map/data/location_service.dart';

/// Displays all active Marprom Maribor buses on Google Maps with rotated
/// directional markers, status rings, quick filters, P8 occupancy animation,
/// real Google Routes line trajectories, and 3D Route View launcher.
class LiveTrackerScreen extends ConsumerStatefulWidget {
  /// Creates a [LiveTrackerScreen].
  const LiveTrackerScreen({
    super.key,
    this.initialLineId,
    this.initialVehicleId,
    this.initialStopId,
  });

  /// Optional initial line filter (e.g. `G1` or `P7`).
  final String? initialLineId;

  /// Optional initial vehicle ID to inspect.
  final String? initialVehicleId;

  /// Optional initial stop ID context.
  final String? initialStopId;

  @override
  ConsumerState<LiveTrackerScreen> createState() => _LiveTrackerScreenState();
}

class _LiveTrackerScreenState extends ConsumerState<LiveTrackerScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final ValueNotifier<String> _lineQuery;
  late final ValueNotifier<String?> _selectedVehicleId;
  late final ValueNotifier<bool> _notFullOnly;
  late final ValueNotifier<bool> _nearestToMe;
  late final ValueNotifier<bool> _showRoutePolyline;
  late final ValueNotifier<bool> _use3DView;

  @override
  void initState() {
    super.initState();
    _lineQuery = ValueNotifier<String>(widget.initialLineId ?? '');
    _searchController.text = widget.initialLineId ?? '';
    _selectedVehicleId = ValueNotifier<String?>(widget.initialVehicleId);
    _notFullOnly = ValueNotifier<bool>(false);
    _nearestToMe = ValueNotifier<bool>(false);
    _showRoutePolyline = ValueNotifier<bool>(widget.initialLineId != null);
    _use3DView = ValueNotifier<bool>(false);

    if (widget.initialLineId != null && !isFlutterTestEnvironment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(googleLineRoutesProvider.notifier)
              .ensureLineLoaded(widget.initialLineId!);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _lineQuery.dispose();
    _selectedVehicleId.dispose();
    _notFullOnly.dispose();
    _nearestToMe.dispose();
    _showRoutePolyline.dispose();
    _use3DView.dispose();
    super.dispose();
  }

  void _selectBus(BusPosition bus) {
    _selectedVehicleId.value = bus.vehicleId;
    _showRoutePolyline.value = true;
    if (!isFlutterTestEnvironment) {
      ref.read(googleLineRoutesProvider.notifier).ensureLineLoaded(bus.lineId);
    }
  }

  Color _ringColorForBus(BusPosition bus) {
    if (bus.loadPercent > 85) return const Color(0xFFEF4444);
    if (bus.delaySeconds > 120) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  Color _occColorForBus(BusPosition bus) {
    if (bus.loadPercent < 55) return const Color(0xFF22C55E);
    if (bus.loadPercent <= 82) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  List<BusPosition> _applyFilters({
    required List<BusPosition> allBuses,
    required bool wheelchairOnly,
    required String query,
    required bool notFullOnly,
    required bool nearestToMe,
    required LatLng? userPos,
  }) {
    final cleanQ = query.trim().toLowerCase();
    final filtered = allBuses.where((b) {
      if (wheelchairOnly && !b.isWheelchairAccessible) return false;
      if (notFullOnly && b.loadPercent > 85) return false;
      if (cleanQ.isNotEmpty) {
        final codeMatch = b.lineCode.toLowerCase().contains(cleanQ);
        final dirMatch = b.directionName.toLowerCase().contains(cleanQ);
        final stopMatch = b.nextStopName.toLowerCase().contains(cleanQ);
        if (!codeMatch && !dirMatch && !stopMatch) return false;
      }
      return true;
    }).toList();

    if (nearestToMe && userPos != null) {
      filtered.sort(
        (a, b) => GeoUtils.haversineMeters(userPos, a.position)
            .compareTo(GeoUtils.haversineMeters(userPos, b.position)),
      );
    } else {
      filtered.sort((a, b) => a.lineCode.compareTo(b.lineCode));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(a11ySettingsProvider);
    final isSl = settings.localeCode == 'sl';
    final linesList = ref.watch(allLinesProvider).valueOrNull ?? const <BusLine>[];
    final linesMap = linesList.isEmpty
        ? seedLinesById
        : {for (final l in linesList) l.id: l};
    final liveBuses = ref.watch(liveBusesStreamProvider).valueOrNull ??
        ref.watch(busSimulatorProvider).snapshotAt(DateTime.now());
    final gpsNotifier = ref.watch(liveGpsPositionNotifierProvider);
    final googleRoutesMap = ref.watch(googleLineRoutesProvider);

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            _lineQuery,
            _selectedVehicleId,
            _notFullOnly,
            _nearestToMe,
            _showRoutePolyline,
            _use3DView,
            gpsNotifier,
          ]),
          builder: (context, _) {
            final userPos = gpsNotifier.value;
            final visibleBuses = _applyFilters(
              allBuses: liveBuses,
              wheelchairOnly: settings.wheelchairAccessibleOnly,
              query: _lineQuery.value,
              notFullOnly: _notFullOnly.value,
              nearestToMe: _nearestToMe.value,
              userPos: userPos,
            );

            BusPosition? focusedBus;
            if (_selectedVehicleId.value != null) {
              for (final b in liveBuses) {
                if (b.vehicleId == _selectedVehicleId.value) {
                  focusedBus = b;
                  break;
                }
              }
            } else if (widget.initialLineId != null && visibleBuses.isNotEmpty) {
              focusedBus = visibleBuses.first;
            }

            final mapPolylines = <GoogleMap3DPolylineData>[];
            if (focusedBus != null &&
                (_showRoutePolyline.value || _use3DView.value)) {
              final line = linesMap[focusedBus.lineId];
              final key = '${focusedBus.lineId}|${focusedBus.directionId}';
              final dir = line?.directionById(focusedBus.directionId);
              final googleRoad = googleRoutesMap[key]?.polylinePoints ??
                  dir?.roadPolyline ??
                  dir?.routePolyline;
              if (googleRoad != null && googleRoad.length >= 2) {
                mapPolylines.add(
                  GoogleMap3DPolylineData(
                    id: key,
                    points: googleRoad,
                    color: line?.color ?? MarpromColors.marpromRed,
                    strokeWidth: 6.5,
                  ),
                );
              }
            }

            final mapMarkers = <GoogleMap3DMarkerData>[
              if (userPos != null)
                GoogleMap3DMarkerData(
                  id: 'user_live_gps',
                  position: userPos,
                  label: isSl ? 'Moja lokacija' : 'My Location',
                  isUserLocation: true,
                ),
              for (final bus in visibleBuses)
                GoogleMap3DMarkerData(
                  id: bus.vehicleId,
                  position: bus.position,
                  shortLabel: bus.lineCode,
                  label:
                      '${bus.lineCode} → ${bus.nextStopName} (${bus.passengerCount}/${bus.vehicleCapacity})',
                  isBus: true,
                  isSelected: focusedBus?.vehicleId == bus.vehicleId,
                  isWheelchairAccessible: bus.isWheelchairAccessible,
                  headingDegrees: bus.headingDegrees,
                  color:
                      linesMap[bus.lineId]?.color ?? MarpromColors.marpromRed,
                  statusColor: _ringColorForBus(bus),
                  occupancyPercent: bus.loadPercent,
                  occupancyColor: _occColorForBus(bus),
                ),
            ];

            final mapView = GoogleMap3DWidget(
              key: const Key('all_buses_map'),
              initialCenter:
                  focusedBus?.position ?? userPos ?? GeoUtils.mariborCenter,
              initialZoom: 13.4,
              initialUse3D: _use3DView.value,
              polylines3D: mapPolylines,
              markers3D: mapMarkers,
              fitBounds: mapPolylines.isNotEmpty,
              fitSignature:
                  '${focusedBus?.vehicleId ?? ''}|${mapPolylines.length}|${_showRoutePolyline.value}',
              activeBusCount: visibleBuses.length,
              totalPassengers: visibleBuses.fold<int>(
                0,
                (sum, b) => sum + b.passengerCount,
              ),
              onMarkerTap: (markerId) {
                for (final b in liveBuses) {
                  if (b.vehicleId == markerId) {
                    _selectBus(b);
                    break;
                  }
                }
              },
            );

            final controlsAndList = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AllBusesFilterHeader(
                  searchController: _searchController,
                  isSl: isSl,
                  wheelchairOnly: settings.wheelchairAccessibleOnly,
                  notFullOnly: _notFullOnly.value,
                  nearestToMe: _nearestToMe.value,
                  hasGps: userPos != null,
                  onSearchChanged: (v) => _lineQuery.value = v,
                  onToggleWheelchair: () => ref
                      .read(a11ySettingsProvider.notifier)
                      .setWheelchairAccessibleOnly(
                        !settings.wheelchairAccessibleOnly,
                      ),
                  onToggleNotFull: () =>
                      _notFullOnly.value = !_notFullOnly.value,
                  onToggleNearest: () =>
                      _nearestToMe.value = !_nearestToMe.value,
                  onOpenSchedules: () => context.push('/lines'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    children: [
                      if (focusedBus != null) ...[
                        _SelectedBusDetailCard(
                          bus: focusedBus,
                          line: linesMap[focusedBus.lineId],
                          isSl: isSl,
                          showingRoadPath: _showRoutePolyline.value,
                          onClose: () {
                            _selectedVehicleId.value = '';
                            _use3DView.value = false;
                          },
                          onToggleRoadPath: () {
                            _showRoutePolyline.value =
                                !_showRoutePolyline.value;
                            if (_showRoutePolyline.value &&
                                !isFlutterTestEnvironment) {
                              ref
                                  .read(googleLineRoutesProvider.notifier)
                                  .ensureLineLoaded(focusedBus!.lineId);
                            }
                          },
                          onLaunch3D: () {
                            if (!isFlutterTestEnvironment) {
                              ref
                                  .read(googleLineRoutesProvider.notifier)
                                  .ensureLineLoaded(focusedBus!.lineId);
                            }
                            _showRoutePolyline.value = true;
                            _use3DView.value = true;
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (visibleBuses.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              isSl
                                  ? 'Trenutno ni aktivnih avtobusov za izbrane filtre.'
                                  : 'No active buses match the selected filters.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        for (final bus in visibleBuses)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CompactBusTile(
                              bus: bus,
                              lineColor: linesMap[bus.lineId]?.color ??
                                  MarpromColors.marpromRed,
                              selected: focusedBus?.vehicleId == bus.vehicleId,
                              userPos: userPos,
                              isSl: isSl,
                              onTap: () => _selectBus(bus),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            );

            if (isWide) {
              return Row(
                children: [
                  SizedBox(
                    width: 420,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 2,
                      child: controlsAndList,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: mapView),
                ],
              );
            }

            // Mobile responsive split: live map on top + smooth list/detail below
            return Column(
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.38,
                  child: mapView,
                ),
                Expanded(child: controlsAndList),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AllBusesFilterHeader extends StatelessWidget {
  const _AllBusesFilterHeader({
    required this.searchController,
    required this.isSl,
    required this.wheelchairOnly,
    required this.notFullOnly,
    required this.nearestToMe,
    required this.hasGps,
    required this.onSearchChanged,
    required this.onToggleWheelchair,
    required this.onToggleNotFull,
    required this.onToggleNearest,
    required this.onOpenSchedules,
  });

  final TextEditingController searchController;
  final bool isSl;
  final bool wheelchairOnly;
  final bool notFullOnly;
  final bool nearestToMe;
  final bool hasGps;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleWheelchair;
  final VoidCallback onToggleNotFull;
  final VoidCallback onToggleNearest;
  final VoidCallback onOpenSchedules;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;
    final searchField = TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        isDense: true,
        hintText: isSl
            ? 'Filter linije (G1, P7) ali postaje...'
            : 'Filter line (G1, P7) or stop...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
              )
            : null,
      ),
    );
    final schedulesBtn = FilledButton.tonalIcon(
      onPressed: onOpenSchedules,
      icon: const Icon(Icons.schedule_rounded, size: 18),
      label: Text(isSl ? 'Vozni redi' : 'Schedules'),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLargeText) ...[
            searchField,
            const SizedBox(height: 8),
            schedulesBtn,
          ] else
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                schedulesBtn,
              ],
            ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  avatar: Icon(
                    Icons.accessible_rounded,
                    size: 16,
                    color: wheelchairOnly ? scheme.onPrimaryContainer : null,
                  ),
                  label: Text(isSl ? 'Nizkopodni / voziček' : 'Wheelchair Only'),
                  selected: wheelchairOnly,
                  onSelected: (_) => onToggleWheelchair(),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  avatar: const Icon(Icons.event_seat_rounded, size: 16),
                  label: Text(isSl ? 'Ni poln' : 'Not Full'),
                  selected: notFullOnly,
                  onSelected: (_) => onToggleNotFull(),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  avatar: const Icon(Icons.near_me_rounded, size: 16),
                  label: Text(isSl ? 'Najbližji meni' : 'Nearest to Me'),
                  selected: nearestToMe,
                  onSelected: hasGps ? (_) => onToggleNearest() : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedBusDetailCard extends StatelessWidget {
  const _SelectedBusDetailCard({
    required this.bus,
    required this.line,
    required this.isSl,
    required this.showingRoadPath,
    required this.onClose,
    required this.onToggleRoadPath,
    required this.onLaunch3D,
  });

  final BusPosition bus;
  final BusLine? line;
  final bool isSl;
  final bool showingRoadPath;
  final VoidCallback onClose;
  final VoidCallback onToggleRoadPath;
  final VoidCallback onLaunch3D;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etaMin = (bus.etaToNextStopSeconds / 60).ceil().clamp(1, 60);

    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              LineBadge(
                code: bus.lineCode,
                color: line?.color ?? MarpromColors.marpromRed,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.directionName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${isSl ? 'Naslednja:' : 'Next:'} ${bus.nextStopName} ($etaMin min)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!isLargeText)
                DepartureDelayChip(delaySeconds: bus.delaySeconds, compact: true),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
          if (isLargeText) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: DepartureDelayChip(
                delaySeconds: bus.delaySeconds,
                compact: true,
              ),
            ),
          ],
          const SizedBox(height: 8),
          BusOccupancyCutaway.fromBusPosition(bus, compact: true),
          const SizedBox(height: 8),
          // Accessibility icons & Google Routes polyline + 3D View controls
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  if (bus.isLowFloor)
                    Tooltip(
                      message: isSl ? 'Nizkopodni' : 'Low-floor',
                      child: const Icon(Icons.directions_bus_filled_rounded, size: 18),
                    ),
                  if (bus.hasWheelchairRamp)
                    Tooltip(
                      message: isSl ? 'Izvlečna klančina' : 'Wheelchair ramp',
                      child: const Icon(Icons.accessible_rounded, size: 18),
                    ),
                  if (bus.hasAudioAnnouncements)
                    Tooltip(
                      message: isSl ? 'Zvočne najave' : 'Audio announcements',
                      child: const Icon(Icons.volume_up_rounded, size: 18),
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onToggleRoadPath,
                    icon: const Icon(Icons.route_rounded, size: 16),
                    label: Text(
                      showingRoadPath
                          ? (isSl ? 'Skrij traso' : 'Hide route')
                          : (isSl ? 'Trasa linije' : 'Show route'),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onLaunch3D,
                    icon: const Icon(Icons.view_in_ar_rounded, size: 16),
                    label: Text(l10n.appTitle.isEmpty ? '3D' : '3D trasa'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactBusTile extends StatelessWidget {
  const _CompactBusTile({
    required this.bus,
    required this.lineColor,
    required this.selected,
    required this.userPos,
    required this.isSl,
    required this.onTap,
  });

  final BusPosition bus;
  final Color lineColor;
  final bool selected;
  final LatLng? userPos;
  final bool isSl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final etaMin = (bus.etaToNextStopSeconds / 60).ceil().clamp(1, 60);
    final isFull = bus.loadPercent > 85;
    final distText = userPos != null
        ? ' • ${(GeoUtils.haversineMeters(userPos!, bus.position) / 1000).toStringAsFixed(1)} km'
        : '';

    final isTightScale = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;
    final delayChip = DepartureDelayChip(
      delaySeconds: bus.delaySeconds,
      compact: true,
    );
    final capText = Text(
      '${bus.passengerCount}/${bus.vehicleCapacity} ${isFull ? (isSl ? '• POLNO' : '• FULL') : ''}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: isFull ? MarpromColors.marpromRed : scheme.onSurfaceVariant,
      ),
    );

    return SurfaceCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          LineBadge(code: bus.lineCode, color: lineColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bus.directionName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${bus.nextStopName} ($etaMin min)$distText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (isTightScale) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [delayChip, capText],
                  ),
                ],
              ],
            ),
          ),
          if (!isTightScale) ...[
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                delayChip,
                const SizedBox(height: 4),
                capText,
              ],
            ),
          ],
        ],
      ),
    );
  }
}
