// Live Maribor 3D Fleet Map + Exact Passenger Count & Ridership Analytics Dashboard.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/accessibility/a11y_settings.dart';
import '../../../../core/maps/full_screen_transit_map.dart';
import '../../../../core/maps/google_map_3d_widget.dart';
import '../../../../core/maps/google_map_models.dart';
import '../../../../core/maps/google_web_views.dart';
import '../../../../core/network/route_geometry_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/geo.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../data/models/bus_position.dart';
import '../../../../data/repositories/repository_providers.dart';
import '../../../../data/seed/seed_lines.dart';
import '../../../../data/seed/seed_stops.dart';
import '../../../live_tracker/domain/fleet_statistics_provider.dart';
import '../marprom_web_strings.dart';

/// Marprom Web Live Map & Fleet Statistics Portal (`/live`).
class WebLiveStatsPage extends ConsumerStatefulWidget {
  /// Creates a [WebLiveStatsPage] optionally focusing on [initialLineId] or [initialVehicleId].
  const WebLiveStatsPage({
    super.key,
    this.initialLineId,
    this.initialVehicleId,
  });

  /// Optional initial line filter (e.g. `G1` or `P7`).
  final String? initialLineId;

  /// Optional initial vehicle ID to highlight.
  final String? initialVehicleId;

  @override
  ConsumerState<WebLiveStatsPage> createState() => _WebLiveStatsPageState();
}

class _WebLiveStatsPageState extends ConsumerState<WebLiveStatsPage> {
  final MapController _mapController = MapController();
  String? _selectedLineFilter;
  String? _focusedVehicleId;
  int _tableFilter = 0; // 0: All, 1: G1-G6, 2: P7-P19, 3: Electric, 4: Crowded (>=65%)
  bool _showGoogleDirectionsEmbed = false;

  @override
  void initState() {
    super.initState();
    _selectedLineFilter = widget.initialLineId;
    _focusedVehicleId = widget.initialVehicleId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isFlutterTestEnvironment) return;
      final notifier = ref.read(googleLineRoutesProvider.notifier);
      if (_selectedLineFilter != null) {
        notifier.ensureLineLoaded(_selectedLineFilter!);
      } else {
        notifier.warmAllActiveLines();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(a11ySettingsProvider);
    final ws = MarpromWebStrings.of(settings.localeCode);
    final liveBuses =
        ref.watch(liveBusesStreamProvider).valueOrNull ??
            ref.watch(busSimulatorProvider).snapshotAt(DateTime.now());
    final googleRoutesMap = ref.watch(googleLineRoutesProvider);
    final stats = computeFleetStatistics(liveBuses);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1000;
    final scheme = Theme.of(context).colorScheme;

    // Filter buses for table & map highlight
    final visibleBuses = liveBuses.where((b) {
      if (_selectedLineFilter != null && b.lineId != _selectedLineFilter) {
        return false;
      }
      if (_tableFilter == 1 && !b.lineCode.startsWith('G')) return false;
      if (_tableFilter == 2 && !b.lineCode.startsWith('P')) return false;
      if (_tableFilter == 3 && !b.isElectric) return false;
      if (_tableFilter == 4 && b.loadPercent < 65) return false;
      return true;
    }).toList(growable: false);

    BusPosition? focusedBus;
    if (_focusedVehicleId != null) {
      for (final b in liveBuses) {
        if (b.vehicleId == _focusedVehicleId) {
          focusedBus = b;
          break;
        }
      }
    }

    final mapCenter = focusedBus?.position ?? GeoUtils.mariborCenter;
    final highlightedLineId = focusedBus?.lineId ?? _selectedLineFilter;
    final highlightedDirectionId = focusedBus?.directionId ??
        (highlightedLineId != null
            ? seedLinesById[highlightedLineId]?.directions.first.id
            : null);
    final focusedGoogleRoute =
        (highlightedLineId != null && highlightedDirectionId != null)
            ? googleRoutesMap['$highlightedLineId|$highlightedDirectionId']
            : null;
    final activeLinesInTraffic = {
      for (final b in liveBuses) b.lineId,
    };

    final polylines3D = <GoogleMap3DPolylineData>[
      for (final line in seedLines)
        if (_selectedLineFilter == null || _selectedLineFilter == line.id)
          GoogleMap3DPolylineData(
            id: line.id,
            points: googleRoutesMap[
                        '${line.id}|${line.directions.first.id}']
                    ?.polylinePoints ??
                line.directions.first.roadPolyline ??
                line.directions.first.polyline,
            color: line.color,
            strokeWidth: _selectedLineFilter == line.id ||
                    focusedBus?.lineId == line.id
                ? 8
                : (activeLinesInTraffic.contains(line.id) ? 5 : 3),
          ),
    ];

    final highlightedLine =
        highlightedLineId != null ? seedLinesById[highlightedLineId] : null;
    final highlightedDirection = (highlightedLine != null &&
            highlightedDirectionId != null)
        ? highlightedLine.directionById(highlightedDirectionId)
        : highlightedLine?.directions.firstOrNull;

    final markers3D = <GoogleMap3DMarkerData>[
      for (final bus in visibleBuses)
        GoogleMap3DMarkerData(
          id: bus.vehicleId,
          position: bus.position,
          shortLabel: bus.lineCode,
          label:
              '${bus.lineCode} (${bus.vehicleId}) • ${bus.passengerCount}/${bus.vehicleCapacity} ${ws.passengersWord} (${bus.loadPercent}%) → ${bus.nextStopName}',
          isBus: true,
          color: seedLinesById[bus.lineId]?.color ?? MarpromColors.marpromRed,
        ),
      if (highlightedDirection != null && highlightedLine != null)
        for (final stopId in highlightedDirection.stopIds)
          if (seedStopsById[stopId] != null)
            GoogleMap3DMarkerData(
              id: 'stop_$stopId',
              position: seedStopsById[stopId]!.position,
              label: seedStopsById[stopId]!.name,
              isBus: false,
              color: highlightedLine.color,
            ),
    ];

    final polylines2D = <Polyline>[
      for (final line in seedLines)
        if (_selectedLineFilter == null || _selectedLineFilter == line.id)
          Polyline(
            points: googleRoutesMap[
                        '${line.id}|${line.directions.first.id}']
                    ?.polylinePoints ??
                line.directions.first.roadPolyline ??
                line.directions.first.polyline,
            strokeWidth: _selectedLineFilter == line.id ||
                    focusedBus?.lineId == line.id
                ? 6.0
                : 3.5,
            color: line.color.withValues(
              alpha: _selectedLineFilter == line.id ||
                      focusedBus?.lineId == line.id
                  ? 0.95
                  : 0.72,
            ),
          ),
    ];

    final markers2D = <Marker>[
      for (final bus in visibleBuses)
        Marker(
          point: bus.position,
          width: 96,
          height: 44,
          child: GestureDetector(
            onTap: () => setState(() => _focusedVehicleId = bus.vehicleId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: seedLinesById[bus.lineId]?.color ??
                    MarpromColors.marpromRed,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focusedVehicleId == bus.vehicleId
                      ? Colors.amberAccent
                      : Colors.white,
                  width: _focusedVehicleId == bus.vehicleId ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bus.lineCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '${bus.passengerCount}/${bus.vehicleCapacity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 9.5,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avtobusi v živo, 3D zemljevid & statistika potnikov',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Spremljajte točno lokacijo vsakega mariborskega avtobusa, hitrost, točnost in število potnikov na krovu v realnem času.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (_selectedLineFilter != null)
                    ActionChip(
                      avatar: const Icon(Icons.clear_rounded, size: 16),
                      label: Text('Filter: $_selectedLineFilter (Počisti)'),
                      onPressed: () =>
                          setState(() => _selectedLineFilter = null),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Top Fleet KPIs
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 960
                      ? 4
                      : (constraints.maxWidth >= 560 ? 2 : 1);
                  final cardWidth =
                      (constraints.maxWidth - (14 * (cols - 1))) / cols;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _StatMetricBox(
                        width: cardWidth,
                        title: 'Skupaj potnikov na avtobusih',
                        value: '${stats.totalPassengers}',
                        detail:
                            'Povprečna zasedenost: ${stats.averageLoadPercent}% (${stats.totalCapacity} mest)',
                        icon: Icons.groups_rounded,
                        color: MarpromColors.marpromRed,
                      ),
                      _StatMetricBox(
                        width: cardWidth,
                        title: 'Aktivnih vozil v Mariboru',
                        value: '${stats.activeBusCount}',
                        detail:
                            'Najbolj obremenjena: ${stats.busiestLine?.line.code ?? '-'} (${stats.busiestLine?.totalPassengers ?? 0} potnikov)',
                        icon: Icons.directions_bus_rounded,
                        color: const Color(0xFF0057B8),
                      ),
                      _StatMetricBox(
                        width: cardWidth,
                        title: 'Točnost voznega parka',
                        value: '${stats.onTimePercent}%',
                        detail:
                            '${stats.onTimeCount} točnih • ${stats.earlyCount} zgodnjih • ${stats.lateCount} z zamudo',
                        icon: Icons.verified_rounded,
                        color: MarpromColors.mobilityGreen,
                      ),
                      _StatMetricBox(
                        width: cardWidth,
                        title: 'Električna flota v obratovanju',
                        value:
                            '${stats.electricBusCount} (${stats.electricSharePercent}%)',
                        detail:
                            'Iveco E-Way & MAN Lion\'s City 12E na linijah G1, G2, G5, G6',
                        icon: Icons.electric_bolt_rounded,
                        color: const Color(0xFF6D28D9),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),

              // 3D Google Map + Live Focus & Google Routes Embed Bar
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.38,
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Icon(
                                Icons.alt_route_rounded,
                                size: 18,
                                color: MarpromColors.marpromRed,
                              ),
                              Text(
                                focusedGoogleRoute != null
                                    ? 'Google Routes API v2 • ${highlightedLineId ?? ''} (${focusedGoogleRoute.formattedDistanceKm}, ${focusedGoogleRoute.formattedDurationMinutes})'
                                    : 'Google Routes API v2 • ${googleRoutesMap.values.where((r) => r.isLiveApi).length} živih cestnih tras sinhroniziranih',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          if (highlightedLineId != null)
                            OutlinedButton.icon(
                              onPressed: () => setState(
                                () => _showGoogleDirectionsEmbed =
                                    !_showGoogleDirectionsEmbed,
                              ),
                              icon: const Icon(Icons.directions_rounded, size: 16),
                              label: Text(
                                _showGoogleDirectionsEmbed
                                    ? 'Nazaj na 3D floto'
                                    : 'Google Maps trasa linije $highlightedLineId',
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 520,
                      child: _showGoogleDirectionsEmbed &&
                              highlightedLineId != null
                          ? GoogleDirectionsEmbedPlatformView(
                              origin: focusedBus != null
                                  ? '${focusedBus.position.latitude},${focusedBus.position.longitude}'
                                  : '${seedStopsById[seedLinesById[highlightedLineId]!.directions.first.stopIds.first]!.name}, Maribor, Slovenia',
                              destination:
                                  '${seedStopsById[seedLinesById[highlightedLineId]!.directions.first.terminalStopId]!.name}, Maribor, Slovenia',
                              mode: 'transit',
                            )
                          : GoogleMap3DWidget(
                              initialCenter: mapCenter,
                              mapController: _mapController,
                              initialUse3D: !kIsWeb,
                              showPresets: kIsWeb,
                              fitBounds: highlightedLineId != null,
                              fitSignature:
                                  '$highlightedLineId|$highlightedDirectionId|${focusedGoogleRoute?.polylinePoints.length ?? 0}',
                              polylines3D: polylines3D,
                              markers3D: markers3D,
                              polylines2D: polylines2D,
                              markers2D: markers2D,
                              activeBusCount: visibleBuses.length,
                              totalPassengers: visibleBuses.fold<int>(
                                0,
                                (sum, b) => sum + b.passengerCount,
                              ),
                              onFullScreenToggle: () => openFullScreenTransitMap(
                                context,
                                initialLineId: highlightedLineId,
                                initialDirectionId: highlightedDirectionId,
                                initialVehicleId: _focusedVehicleId,
                              ),
                            ),
                    ),
                    if (focusedBus != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: MarpromColors.marpromCharcoal,
                        child: Wrap(
                          spacing: 18,
                          runSpacing: 10,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MarpromColors.marpromRed,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    focusedBus.lineCode,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${focusedBus.vehicleId} • ${focusedBus.directionName}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Naslednja postaja: ${focusedBus.nextStopName} (${(focusedBus.etaToNextStopSeconds / 60).ceil()} min) • '
                                      '${focusedBus.passengerCount}/${focusedBus.vehicleCapacity} ${ws.passengersWord} (${focusedBus.loadPercent}%) • '
                                      '${focusedBus.speedKmh} km/h'
                                      '${focusedGoogleRoute != null ? ' • Trasa: ${focusedGoogleRoute.formattedDistanceKm}' : ''}',
                                      style: const TextStyle(
                                        color: Color(0xFFCBD5E1),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _focusedVehicleId = null;
                                _showGoogleDirectionsEmbed = false;
                              }),
                              child: const Text(
                                'Skrij fokus',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Charts Row: Passengers per Line + 24h Maribor Ridership Curve
              Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 6 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Število potnikov po linijah v tem trenutku',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kliknite vrstico za filtriranje linije na 3D zemljevidu in v tabeli',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 16),
                            _PassengersPerLineBarChart(
                              stats: stats.lineStats
                                  .where((s) => s.activeBuses > 0)
                                  .toList(growable: false),
                              selectedLineId: _selectedLineFilter,
                              onSelectLine: (id) => setState(() {
                                _selectedLineFilter =
                                    _selectedLineFilter == id ? null : id;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isWide ? 20 : 0, height: isWide ? 0 : 20),
                  Expanded(
                    flex: isWide ? 5 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dnevna krivulja povpraševanja (05:00–23:00)',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Jutranja (07:00–09:00) in popoldanska (14:00–16:30) konica v Mariboru',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 220,
                              child: _HourlyRidershipChart(
                                points: stats.hourlyRidership,
                                currentHour: DateTime.now().hour,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Live Fleet Vehicles Telemetry Table
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Vsi aktivni avtobusi v živo (${visibleBuses.length})',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ChoiceChip(
                                label: const Text('Vsi'),
                                selected: _tableFilter == 0,
                                onSelected: (_) =>
                                    setState(() => _tableFilter = 0),
                              ),
                              ChoiceChip(
                                label: const Text('G1–G6'),
                                selected: _tableFilter == 1,
                                onSelected: (_) =>
                                    setState(() => _tableFilter = 1),
                              ),
                              ChoiceChip(
                                label: const Text('P7–P19'),
                                selected: _tableFilter == 2,
                                onSelected: (_) =>
                                    setState(() => _tableFilter = 2),
                              ),
                              ChoiceChip(
                                label: const Text('Električni'),
                                selected: _tableFilter == 3,
                                onSelected: (_) =>
                                    setState(() => _tableFilter = 3),
                              ),
                              ChoiceChip(
                                label: const Text('Visoka zasedenost (65%+)'),
                                selected: _tableFilter == 4,
                                onSelected: (_) =>
                                    setState(() => _tableFilter = 4),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (visibleBuses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Trenutno ni aktivnih vozil za izbrani filter.',
                            ),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 44,
                            dataRowMinHeight: 58,
                            dataRowMaxHeight: 68,
                            columns: const [
                              DataColumn(label: Text('Linija & Vozilo')),
                              DataColumn(label: Text('Smer & Naslednja postaja')),
                              DataColumn(label: Text('Lokacija (GPS)')),
                              DataColumn(label: Text('Potniki na krovu')),
                              DataColumn(label: Text('Hitrost')),
                              DataColumn(label: Text('Točnost')),
                              DataColumn(label: Text('Zemljevid')),
                            ],
                            rows: [
                              for (final bus in visibleBuses)
                                DataRow(
                                  selected: _focusedVehicleId == bus.vehicleId,
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: seedLinesById[bus.lineId]
                                                      ?.color ??
                                                  MarpromColors.marpromRed,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              bus.lineCode,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                bus.vehicleId,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                              Text(
                                                bus.vehicleModel,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 240,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              bus.directionName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            Text(
                                              '→ ${bus.nextStopName} (${(bus.etaToNextStopSeconds / 60).ceil()} min)',
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
                                    ),
                                    DataCell(
                                      Text(
                                        '${bus.position.latitude.toStringAsFixed(4)}, ${bus.position.longitude.toStringAsFixed(4)}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 170,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '${bus.passengerCount} / ${bus.vehicleCapacity} ${ws.passengersWord} (${bus.loadPercent}%)',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              child: LinearProgressIndicator(
                                                value: (bus.loadPercent / 100)
                                                    .clamp(0.0, 1.0),
                                                minHeight: 6,
                                                color: bus.loadPercent >= 75
                                                    ? MarpromColors.marpromRed
                                                    : (bus.loadPercent >= 45
                                                        ? const Color(
                                                            0xFFD97706,
                                                          )
                                                        : MarpromColors
                                                            .mobilityGreen),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${bus.speedKmh.toStringAsFixed(0)} km/h',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      StatusChip(
                                        type: bus.status,
                                        label: bus.delaySeconds < -60
                                            ? 'Zgoden ${(-bus.delaySeconds / 60).round()}m'
                                            : (bus.delaySeconds > 120
                                                ? 'Zamuda ${(bus.delaySeconds / 60).round()}m'
                                                : 'Točen'),
                                        compact: true,
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        tooltip: 'Prikaži na 3D zemljevidu',
                                        icon: const Icon(
                                          Icons.my_location_rounded,
                                          color: MarpromColors.marpromRed,
                                        ),
                                        onPressed: () {
                                          setState(() => _focusedVehicleId =
                                              bus.vehicleId);
                                          if (!isFlutterTestEnvironment) {
                                            ref
                                                .read(
                                                  googleLineRoutesProvider
                                                      .notifier,
                                                )
                                                .ensureLineLoaded(bus.lineId);
                                          }
                                          try {
                                            _mapController.move(
                                              bus.position,
                                              15.0,
                                            );
                                          } catch (_) {}
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatMetricBox extends StatelessWidget {
  const _StatMetricBox({
    required this.width,
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final double width;
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassengersPerLineBarChart extends StatelessWidget {
  const _PassengersPerLineBarChart({
    required this.stats,
    required this.selectedLineId,
    required this.onSelectLine,
  });

  final List<FleetLineStat> stats;
  final String? selectedLineId;
  final ValueChanged<String> onSelectLine;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Trenutno ni aktivnih voženj za prikaz grafikona.'),
      );
    }

    final sorted = List<FleetLineStat>.from(stats)
      ..sort((a, b) => b.totalPassengers.compareTo(a.totalPassengers));
    final maxPassengers = sorted.first.totalPassengers.clamp(1, 10000);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (final item in sorted.take(10))
          InkWell(
            onTap: () => onSelectLine(item.line.id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.line.color,
                      borderRadius: BorderRadius.circular(6),
                      border: selectedLineId == item.line.id
                          ? Border.all(color: Colors.amber, width: 2)
                          : null,
                    ),
                    child: Text(
                      item.line.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (item.totalPassengers / maxPassengers)
                            .clamp(0.0, 1.0),
                        minHeight: 14,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: item.line.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 105,
                    child: Text(
                      '${item.totalPassengers} (${item.averageLoadPercent}%)',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HourlyRidershipChart extends StatelessWidget {
  const _HourlyRidershipChart({
    required this.points,
    required this.currentHour,
  });

  final List<HourlyRidershipPoint> points;
  final int currentHour;

  @override
  Widget build(BuildContext context) {
    final maxRiders = points
        .map((p) => p.riders)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final pt in points)
          Expanded(
            child: Tooltip(
              message: '${pt.hour.toString().padLeft(2, '0')}:00 — ~${pt.riders} potnikov',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (pt.riders / maxRiders).clamp(0.08, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: pt.hour == currentHour
                                  ? MarpromColors.marpromRed
                                  : MarpromColors.marpromRed
                                      .withValues(alpha: 0.35),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pt.hour % 3 == 0 ? '${pt.hour}' : '',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
