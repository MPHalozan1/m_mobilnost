// Interactive Marprom 7-day-of-week timetable portal for all 19 lines (G1-G6 & P7-P19).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/accessibility/a11y_settings.dart';
import '../../../../core/maps/full_screen_transit_map.dart';
import '../../../../core/maps/google_map_3d_widget.dart';
import '../../../../core/maps/google_map_models.dart';
import '../../../../core/maps/google_web_views.dart';
import '../../../../core/network/route_geometry_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/geo.dart';
import '../../../../core/widgets/bus_occupancy_cutaway.dart';
import '../../../../data/models/bus_line.dart';
import '../../../../data/models/bus_position.dart';
import '../../../../data/repositories/repository_providers.dart';
import '../../../../data/seed/seed_lines.dart';
import '../../../../data/seed/seed_stops.dart';
import '../../../../data/seed/seed_timetables.dart';
import '../marprom_web_strings.dart';

/// Marprom Web Schedules explorer (`/lines` & `/lines/:lineId`) inspired by `vozniredi.marprom.si`.
/// Supports all 19 official Marprom lines (`G1-G6`, `P7-P19`) and all 7 days of the week.
class WebSchedulesPage extends ConsumerStatefulWidget {
  /// Creates a [WebSchedulesPage] optionally pre-selecting [initialLineId].
  const WebSchedulesPage({super.key, this.initialLineId});

  /// Optional line code/ID from URL (`/lines/:lineId`).
  final String? initialLineId;

  @override
  ConsumerState<WebSchedulesPage> createState() => _WebSchedulesPageState();
}

class _WebSchedulesPageState extends ConsumerState<WebSchedulesPage> {
  String _searchQuery = '';
  int _groupFilter = 0; // 0: All 19, 1: G1-G6, 2: P7-P19
  bool _accessibleOnly = false;
  late String _selectedLineId;
  int _directionIndex = 0;
  int _selectedWeekday = DateTime.now().weekday;
  String? _selectedStopId;

  @override
  void initState() {
    super.initState();
    _accessibleOnly = ref.read(a11ySettingsProvider).wheelchairAccessibleOnly;
    final initial = widget.initialLineId != null
        ? seedLinesById[widget.initialLineId!]
        : null;
    _selectedLineId = initial?.id ?? seedLines.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isFlutterTestEnvironment) return;
      ref.read(googleLineRoutesProvider.notifier).ensureLineLoaded(_selectedLineId);
    });
  }

  @override
  void didUpdateWidget(covariant WebSchedulesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLineId != oldWidget.initialLineId &&
        widget.initialLineId != null) {
      final resolved = seedLinesById[widget.initialLineId!];
      if (resolved != null) {
        setState(() {
          _selectedLineId = resolved.id;
          _directionIndex = 0;
          _selectedStopId = null;
        });
        if (!isFlutterTestEnvironment) {
          ref
              .read(googleLineRoutesProvider.notifier)
              .ensureLineLoaded(resolved.id);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(a11ySettingsProvider);
    final ws = MarpromWebStrings.of(settings.localeCode);
    final liveBuses =
        ref.watch(liveBusesStreamProvider).valueOrNull ?? const <BusPosition>[];
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 980;
    final scheme = Theme.of(context).colorScheme;

    final filteredLines = seedLines.where((line) {
      if (_groupFilter == 1 && !line.isMainTrunk) return false;
      if (_groupFilter == 2 && line.isMainTrunk) return false;
      if (_accessibleOnly && !line.isWheelchairAccessible) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        return line.code.toLowerCase().contains(q) ||
            line.name.toLowerCase().contains(q);
      }
      return true;
    }).toList(growable: false);

    final activeLine = seedLinesById[_selectedLineId] ?? seedLines.first;
    final direction = activeLine.directions[
        _directionIndex.clamp(0, activeLine.directions.length - 1)];
    final activeStopId =
        (_selectedStopId != null && direction.stopIds.contains(_selectedStopId))
            ? _selectedStopId!
            : direction.stopIds.first;
    final stopIdx = direction.stopIds.indexOf(activeStopId);

    final scheduleDate = sampleDateForWeekday(_selectedWeekday);
    final selectedDayType = scheduleTypeForDate(scheduleDate);
    final operatesOnSelectedDay = doesLineOperateOn(activeLine.id, selectedDayType);
    final trips = generateTripsForDirection(
      line: activeLine,
      direction: direction,
      date: scheduleDate,
    );

    final routeKey = '${activeLine.id}|${direction.id}';
    final googleRoute = ref.watch(googleLineRoutesProvider)[routeKey];
    final routeAsync = ref.watch(routeGeometryProvider(routeKey));
    final routePoints = googleRoute?.polylinePoints ??
        routeAsync.valueOrNull ??
        direction.roadPolyline ??
        direction.polyline;

    final busesOnDirection = liveBuses
        .where(
          (b) =>
              b.lineId == activeLine.id && b.directionId == direction.id,
        )
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page heading
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interaktivni vozni redi Marprom (G1–G6 & P7–P19)',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Izberite linijo, smer vožnje, postajališče ter dan v tednu (ponedeljek–nedelja) za popoln pregled odhodov in zasedenosti.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: MarpromColors.marpromRed,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        context.go('/live?lineId=${activeLine.id}'),
                    icon: const Icon(Icons.view_in_ar_rounded),
                    label: Text('Prikaži ${activeLine.code} na 3D zemljevidu'),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left sidebar: Filterable list of all 19 Marprom lines
                  SizedBox(
                    width: isWide ? 340 : double.infinity,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                hintText: 'Išči linijo (npr. G1, P15, Tezno)...',
                                prefixIcon: Icon(Icons.search_rounded),
                                isDense: true,
                              ),
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ChoiceChip(
                                  label: const Text('Vse (19)'),
                                  selected: _groupFilter == 0,
                                  onSelected: (_) =>
                                      setState(() => _groupFilter = 0),
                                ),
                                ChoiceChip(
                                  label: const Text('G1–G6'),
                                  selected: _groupFilter == 1,
                                  onSelected: (_) =>
                                      setState(() => _groupFilter = 1),
                                ),
                                ChoiceChip(
                                  label: const Text('P7–P19'),
                                  selected: _groupFilter == 2,
                                  onSelected: (_) =>
                                      setState(() => _groupFilter = 2),
                                ),
                                FilterChip(
                                  avatar: const Icon(
                                    Icons.accessible_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Dostopne'),
                                  selected: _accessibleOnly,
                                  onSelected: (v) =>
                                      setState(() => _accessibleOnly = v),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 540),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: filteredLines.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final line = filteredLines[index];
                                  final selected = line.id == activeLine.id;
                                  final liveCount = liveBuses
                                      .where((b) => b.lineId == line.id)
                                      .length;
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedLineId = line.id;
                                        _directionIndex = 0;
                                        _selectedStopId = null;
                                      });
                                      if (!isFlutterTestEnvironment) {
                                        ref
                                            .read(
                                              googleLineRoutesProvider.notifier,
                                            )
                                            .ensureLineLoaded(line.id);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? line.color.withValues(alpha: 0.12)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selected
                                              ? line.color
                                              : scheme.outlineVariant,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 5,
                                            ),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: line.color,
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                            ),
                                            child: Text(
                                              line.code,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              line.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: selected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (liveCount > 0)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: MarpromColors
                                                    .mobilityGreen
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '$liveCount',
                                                style: const TextStyle(
                                                  color:
                                                      MarpromColors.mobilityGreen,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 24),

                  // Right main timetable & live route occupancy panel
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Line header + Direction + 7-day-of-week selector
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: activeLine.color,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        activeLine.code,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activeLine.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          Text(
                                            activeLine.isMainTrunk
                                                ? 'Glavna mestna linija Marprom'
                                                : 'Povezovalna / primestna linija Marprom',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Direction buttons
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    for (var i = 0;
                                        i < activeLine.directions.length;
                                        i++)
                                      ChoiceChip(
                                        avatar: const Icon(
                                          Icons.east_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          activeLine.directions[i].name,
                                        ),
                                        selected: _directionIndex == i,
                                        onSelected: (_) {
                                          setState(() {
                                            _directionIndex = i;
                                            _selectedStopId = null;
                                          });
                                          if (!isFlutterTestEnvironment) {
                                            ref
                                                .read(
                                                  googleLineRoutesProvider
                                                      .notifier,
                                                )
                                                .ensureLineLoaded(
                                                  activeLine.id,
                                                );
                                          }
                                        },
                                      ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Text(
                                  'Izberite dan v tednu (celotedenski vozni red)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (var day = DateTime.monday;
                                        day <= DateTime.sunday;
                                        day++)
                                      ChoiceChip(
                                        label: Text(ws.weekdayName(day)),
                                        selected: _selectedWeekday == day,
                                        selectedColor: MarpromColors.marpromRed
                                            .withValues(alpha: 0.16),
                                        onSelected: (_) => setState(
                                          () => _selectedWeekday = day,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Wrap(
                                    spacing: 18,
                                    runSpacing: 6,
                                    children: [
                                      Text(
                                        'Delavnik (Pon–Pet): ${formatLineOperatingHours(activeLine.id, directionIndex: _directionIndex, type: DayScheduleType.weekday)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        'Sobota: ${formatLineOperatingHours(activeLine.id, directionIndex: _directionIndex, type: DayScheduleType.saturday)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        'Nedelja / Praznik: ${formatLineOperatingHours(activeLine.id, directionIndex: _directionIndex, type: DayScheduleType.sundayHoliday)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: doesLineOperateOn(
                                                activeLine.id,
                                                DayScheduleType.sundayHoliday,
                                              )
                                                  ? null
                                                  : MarpromColors.marpromRed,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!operatesOnSelectedDay) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: scheme.errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.event_busy_rounded,
                                          color: scheme.onErrorContainer,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Linija ${activeLine.code} ob nedeljah in praznikih po uradnem voznem redu Marprom ne obratuje. Izberite delavnik, soboto ali glavne linije G1–G4 / G6.',
                                            style: TextStyle(
                                              color: scheme.onErrorContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Google Maps live route visualization for the selected line direction
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.route_rounded,
                                          color: activeLine.color,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Google Maps Routes trasa linije ${activeLine.code}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      googleRoute != null
                                          ? '${googleRoute.formattedDistanceKm} • ~${googleRoute.formattedDurationMinutes} (${googleRoute.isLiveApi ? 'Google Routes API v2' : 'Cestna ocena'})'
                                          : 'Priprava Google Routes cestne trase...',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 360,
                                child: GoogleMap3DWidget(
                                  initialCenter: routePoints.isNotEmpty
                                      ? routePoints[routePoints.length ~/ 2]
                                      : GeoUtils.mariborCenter,
                                  initialUse3D: false,
                                  showPresets: false,
                                  showStatusPill: false,
                                  fitBounds: true,
                                  fitSignature:
                                      '${activeLine.id}|${direction.id}|${routePoints.length}',
                                  activeBusCount: busesOnDirection.length,
                                  totalPassengers: busesOnDirection.fold<int>(
                                    0,
                                    (s, b) => s + b.passengerCount,
                                  ),
                                  polylines3D: [
                                    GoogleMap3DPolylineData(
                                      id: '${activeLine.id}_${direction.id}',
                                      points: routePoints,
                                      color: activeLine.color,
                                      strokeWidth: 7,
                                    ),
                                  ],
                                  markers3D: [
                                    for (final bus in busesOnDirection)
                                      GoogleMap3DMarkerData(
                                        id: bus.vehicleId,
                                        position: bus.position,
                                        shortLabel: bus.lineCode,
                                        label:
                                            '${bus.lineCode} • ${bus.passengerCount}/${bus.vehicleCapacity} ${ws.passengersWord} → ${bus.nextStopName}',
                                        isBus: true,
                                        isWheelchairAccessible:
                                            bus.isWheelchairAccessible,
                                        headingDegrees: bus.headingDegrees,
                                        color: activeLine.color,
                                      ),
                                    for (final stopId in direction.stopIds)
                                      if (seedStopsById[stopId] != null)
                                        GoogleMap3DMarkerData(
                                          id: stopId,
                                          position:
                                              seedStopsById[stopId]!.position,
                                          label: seedStopsById[stopId]!.name,
                                          isBus: false,
                                          isWheelchairAccessible:
                                              seedStopsById[stopId]!.isStepFree,
                                          color: activeLine.color,
                                        ),
                                  ],
                                  onFullScreenToggle: () =>
                                      openFullScreenTransitMap(
                                    context,
                                    initialLineId: activeLine.id,
                                    initialDirectionId: direction.id,
                                  ),
                                ),
                              ),
                              if (busesOnDirection.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: BusOccupancyCutaway.fromBusPosition(
                                    busesOnDirection.first,
                                    compact: true,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Stop sequence with live buses & passenger count + Departures matrix
                        if (width >= 1180)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Postajališča na trasi (${direction.stopIds.length})',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Kliknite postajališče za odhode',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        for (var i = 0;
                                            i < direction.stopIds.length;
                                            i++)
                                          _StopSequenceRow(
                                            stopId: direction.stopIds[i],
                                            lineColor: activeLine.color,
                                            isFirst: i == 0,
                                            isLast: i ==
                                                direction.stopIds.length - 1,
                                            isSelected: direction.stopIds[i] ==
                                                activeStopId,
                                            busesApproaching: busesOnDirection
                                                .where((b) =>
                                                    b.nextStopId ==
                                                    direction.stopIds[i])
                                                .toList(growable: false),
                                            passengersWord: ws.passengersWord,
                                            onTap: () => setState(() {
                                              _selectedStopId =
                                                  direction.stopIds[i];
                                            }),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                flex: 6,
                                child: _DepartureMatrixCard(
                                  line: activeLine,
                                  stopName: seedStopsById[activeStopId]?.name ??
                                      activeStopId,
                                  dayLabel: ws.weekdayName(_selectedWeekday),
                                  trips: trips,
                                  stopIndex: stopIdx < 0 ? 0 : stopIdx,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Postajališča na trasi (${direction.stopIds.length})',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Kliknite postajališče za odhode',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      for (var i = 0;
                                          i < direction.stopIds.length;
                                          i++)
                                        _StopSequenceRow(
                                          stopId: direction.stopIds[i],
                                          lineColor: activeLine.color,
                                          isFirst: i == 0,
                                          isLast:
                                              i == direction.stopIds.length - 1,
                                          isSelected: direction.stopIds[i] ==
                                              activeStopId,
                                          busesApproaching: busesOnDirection
                                              .where((b) =>
                                                  b.nextStopId ==
                                                  direction.stopIds[i])
                                              .toList(growable: false),
                                          passengersWord: ws.passengersWord,
                                          onTap: () => setState(() {
                                            _selectedStopId =
                                                direction.stopIds[i];
                                          }),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _DepartureMatrixCard(
                                line: activeLine,
                                stopName: seedStopsById[activeStopId]?.name ??
                                    activeStopId,
                                dayLabel: ws.weekdayName(_selectedWeekday),
                                trips: trips,
                                stopIndex: stopIdx < 0 ? 0 : stopIdx,
                              ),
                            ],
                          ),
                      ],
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

class _StopSequenceRow extends StatelessWidget {
  const _StopSequenceRow({
    required this.stopId,
    required this.lineColor,
    required this.isFirst,
    required this.isLast,
    required this.isSelected,
    required this.busesApproaching,
    required this.passengersWord,
    required this.onTap,
  });

  final String stopId;
  final Color lineColor;
  final bool isFirst;
  final bool isLast;
  final bool isSelected;
  final List<BusPosition> busesApproaching;
  final String passengersWord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stop = seedStopsById[stopId];
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? lineColor.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? lineColor : scheme.surface,
                        border: Border.all(color: lineColor, width: 3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stop?.name ?? stopId,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                if (isFirst)
                  const Chip(
                    label: Text('Začetek', style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                  )
                else if (isLast)
                  const Chip(
                    label: Text('Končna', style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            for (final bus in busesApproaching)
              Container(
                margin: const EdgeInsets.only(left: 26, top: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: MarpromColors.marpromRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MarpromColors.marpromRed.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.directions_bus_rounded,
                      size: 15,
                      color: MarpromColors.marpromRed,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${bus.vehicleId} • čez ${(bus.etaToNextStopSeconds / 60).ceil()} min • ${bus.passengerCount}/${bus.vehicleCapacity} $passengersWord (${bus.loadPercent}%)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: MarpromColors.marpromRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DepartureMatrixCard extends StatelessWidget {
  const _DepartureMatrixCard({
    required this.line,
    required this.stopName,
    required this.dayLabel,
    required this.trips,
    required this.stopIndex,
  });

  final BusLine line;
  final String stopName;
  final String dayLabel;
  final List<ScheduledTrip> trips;
  final int stopIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final byHour = <int, List<int>>{};
    for (final trip in trips) {
      if (stopIndex >= trip.stopTimes.length) continue;
      final t = trip.stopTimes[stopIndex];
      byHour.putIfAbsent(t.hour, () => <int>[]).add(t.minute);
    }
    final hours = byHour.keys.toList()..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_rounded, color: line.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Odhodi s postajališča $stopName — $dayLabel',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Skupaj ${trips.length} odhodov • Linija ${line.code}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Divider(height: 22),
            if (hours.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Na ta dan ni predvidenih odhodov.'),
              )
            else
              Column(
                children: [
                  for (final hour in hours)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}h',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: line.color,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (final minute in byHour[hour]!)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
