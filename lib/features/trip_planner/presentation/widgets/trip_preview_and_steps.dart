// Displays selected trip Map/List preview, "What do I do next?" steps, and TTS.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/accessibility/read_aloud.dart';
import 'package:m_mobilnost/core/accessibility/semantics_helpers.dart';
import 'package:m_mobilnost/core/maps/full_screen_transit_map.dart';
import 'package:m_mobilnost/core/maps/google_map_3d_widget.dart';
import 'package:m_mobilnost/core/maps/google_map_models.dart';
import 'package:m_mobilnost/core/network/route_geometry_service.dart';
import 'package:m_mobilnost/core/theme/colors.dart';
import 'package:m_mobilnost/core/utils/distance.dart';
import 'package:m_mobilnost/core/utils/geo.dart';
import 'package:m_mobilnost/core/utils/time_format.dart';
import 'package:m_mobilnost/core/widgets/big_button.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/bus_stop.dart';
import 'package:m_mobilnost/data/models/trip_plan.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';

import '../../domain/route_planner.dart';
import 'trip_endpoint.dart';

/// Displays the route map/list preview and "What do I do next?" steps for [option].
class TripPreviewAndSteps extends ConsumerStatefulWidget {
  /// Creates a [TripPreviewAndSteps] panel for the active [option].
  const TripPreviewAndSteps({
    super.key,
    required this.option,
    required this.planner,
    required this.linesById,
    required this.stopsById,
    required this.originLabel,
    required this.destinationLabel,
  });

  /// Selected [TripOption] to inspect.
  final TripOption option;

  /// Domain [RoutePlanner] used to extract structured steps.
  final RoutePlanner planner;

  /// Line metadata indexed by ID.
  final Map<String, BusLine> linesById;

  /// Stop metadata indexed by ID.
  final Map<String, BusStop> stopsById;

  /// Localized origin label.
  final String originLabel;

  /// Localized destination label.
  final String destinationLabel;

  @override
  ConsumerState<TripPreviewAndSteps> createState() =>
      _TripPreviewAndStepsState();
}

class _TripPreviewAndStepsState extends ConsumerState<TripPreviewAndSteps> {
  bool _showListView = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(a11ySettingsProvider);
    final steps = widget.planner.buildInstructions(
      widget.option,
      destinationLabel: widget.destinationLabel,
    );
    final firstBus = widget.option.legs
        .where((l) => l.type == TripLegType.bus)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    BigButton(
                      icon: Icons.map_outlined,
                      label: l10n.mapSwitchToMap,
                      variant: !_showListView
                          ? BigButtonVariant.selected
                          : BigButtonVariant.outlined,
                      onPressed: () => setState(() => _showListView = false),
                    ),
                    BigButton(
                      icon: Icons.view_list_rounded,
                      label: l10n.mapSwitchToList,
                      variant: _showListView
                          ? BigButtonVariant.selected
                          : BigButtonVariant.outlined,
                      onPressed: () => setState(() => _showListView = true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_showListView)
                  _RouteListPreview(
                    option: widget.option,
                    linesById: widget.linesById,
                    stopsById: widget.stopsById,
                    originLabel: widget.originLabel,
                    destinationLabel: widget.destinationLabel,
                  )
                else
                  _RouteMapPreview(
                    option: widget.option,
                    linesById: widget.linesById,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.planWhatDoINextTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                BigButton(
                  icon: Icons.volume_up_rounded,
                  label: l10n.a11yReadAloudButton,
                  variant: BigButtonVariant.secondary,
                  expanded: true,
                  onPressed: () {
                    final speech = _buildSpeechSummary(l10n, steps);
                    ref.read(readAloudProvider).speak(
                          speech,
                          enabled: true,
                          localeCode: settings.localeCode,
                        );
                  },
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < steps.length; i++)
                  _StepInstructionRow(
                    stepNumber: i + 1,
                    step: steps[i],
                    linesById: widget.linesById,
                    destinationLabel: widget.destinationLabel,
                  ),
                if (firstBus != null &&
                    (firstBus.lineId != null || firstBus.fromStopId != null)) ...[
                  const Divider(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (firstBus.lineId != null)
                        BigButton(
                          icon: Icons.gps_fixed_rounded,
                          label: l10n.linesFollowBusLive,
                          variant: BigButtonVariant.outlined,
                          onPressed: () => context.push(
                            '/tracker?lineId=${Uri.encodeComponent(firstBus.lineId!)}',
                          ),
                        ),
                      if (firstBus.fromStopId != null)
                        BigButton(
                          icon: Icons.schedule_rounded,
                          label: l10n.mapStopDetailsOpen,
                          variant: BigButtonVariant.outlined,
                          onPressed: () => context.push(
                            '/stops/${Uri.encodeComponent(firstBus.fromStopId!)}',
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _buildSpeechSummary(
    AppLocalizations l10n,
    List<TripStepInstruction> steps,
  ) {
    final parts = <String>[
      l10n.planOptionSummary(
        widget.option.totalMinutes,
        l10n.commonTransfersPlural(widget.option.transferCount),
        DistanceUtils.formatMeters(widget.option.walkMeters, l10n),
      ),
    ];
    for (final step in steps) {
      parts.add(_describeStep(l10n, step, widget.destinationLabel));
    }
    return parts.join('. ');
  }
}

class _RouteMapPreview extends ConsumerWidget {
  const _RouteMapPreview({
    required this.option,
    required this.linesById,
  });

  final TripOption option;
  final Map<String, BusLine> linesById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final googleRoutesMap = ref.watch(googleLineRoutesProvider);

    final legPaths = <int, List<LatLng>>{};
    final allPoints = <LatLng>[];
    for (var i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      if (leg.polyline.isEmpty) continue;
      List<LatLng> resolved = leg.polyline;
      if (leg.type == TripLegType.bus &&
          leg.lineId != null &&
          leg.directionId != null &&
          leg.polyline.length >= 2) {
        final key = '${leg.lineId}|${leg.directionId}';
        final asyncRoad = ref.watch(routeGeometryProvider(key));
        final fullRoad =
            googleRoutesMap[key]?.polylinePoints ?? asyncRoad.valueOrNull;
        if (fullRoad != null && fullRoad.length >= 2) {
          resolved = slicePolylineBetweenPoints(
            fullRoad,
            leg.polyline.first,
            leg.polyline.last,
          );
        }
      }
      legPaths[i] = resolved;
      allPoints.addAll(resolved);
    }

    final hasSpan = _hasCoordinateSpan(allPoints);
    final polylines3D = <GoogleMap3DPolylineData>[];
    final markers3D = <GoogleMap3DMarkerData>[];

    for (var i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      final legPoints = legPaths[i];
      if (legPoints == null || legPoints.isEmpty) continue;

      final isWalk = leg.type == TripLegType.walk;
      final lineMeta = linesById[leg.lineId];
      final busColor = lineMeta?.color ?? scheme.primary;
      if (legPoints.length >= 2) {
        polylines3D.add(
          GoogleMap3DPolylineData(
            id: 'leg_${option.id}_$i',
            points: legPoints,
            color: isWalk ? scheme.outline : busColor,
            strokeWidth: isWalk ? 4.0 : 6.5,
            isDashed: isWalk,
          ),
        );
      }

      if (i == 0) {
        markers3D.add(
          GoogleMap3DMarkerData(
            id: 'origin_${option.id}',
            position: legPoints.first,
            label: leg.fromName,
            color: scheme.secondary,
          ),
        );
      }
      if (!isWalk) {
        final lineCode = lineMeta?.code ?? leg.lineCode;
        final isAcc = leg.isAccessible && (lineMeta?.isWheelchairAccessible ?? true);
        markers3D.add(
          GoogleMap3DMarkerData(
            id: 'board_${option.id}_$i',
            position: legPoints.first,
            shortLabel: lineCode,
            isBus: lineCode != null,
            isWheelchairAccessible: isAcc,
            label: '${lineCode ?? ''} • ${leg.fromName}',
            color: busColor,
          ),
        );
        markers3D.add(
          GoogleMap3DMarkerData(
            id: 'alight_${option.id}_$i',
            position: legPoints.last,
            label: leg.toName,
            color: busColor,
          ),
        );
      }
      if (i == option.legs.length - 1) {
        markers3D.add(
          GoogleMap3DMarkerData(
            id: 'dest_${option.id}',
            position: legPoints.last,
            label: leg.toName,
            color: scheme.primary,
          ),
        );
      }
    }

    final firstBusLeg =
        option.legs.where((l) => l.lineId != null).firstOrNull;

    return SizedBox(
      height: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GoogleMap3DWidget(
          key: ValueKey('trip_google_map_${option.id}'),
          initialCenter: allPoints.isNotEmpty
              ? allPoints[allPoints.length ~/ 2]
              : GeoUtils.mariborCenter,
          initialUse3D: false,
          showPresets: false,
          showStatusPill: false,
          fitBounds: hasSpan,
          fitSignature: '${option.id}|${allPoints.length}',
          polylines3D: polylines3D,
          markers3D: markers3D,
          onFullScreenToggle: () => openFullScreenTransitMap(
            context,
            initialLineId: firstBusLeg?.lineId,
            initialDirectionId: firstBusLeg?.directionId,
          ),
        ),
      ),
    );
  }

  static bool _hasCoordinateSpan(List<LatLng> points) {
    if (points.length < 2) return false;
    final first = points.first;
    for (final p in points.skip(1)) {
      if ((p.latitude - first.latitude).abs() > 1e-5 ||
          (p.longitude - first.longitude).abs() > 1e-5) {
        return true;
      }
    }
    return false;
  }
}

class _RouteListPreview extends StatelessWidget {
  const _RouteListPreview({
    required this.option,
    required this.linesById,
    required this.stopsById,
    required this.originLabel,
    required this.destinationLabel,
  });

  final TripOption option;
  final Map<String, BusLine> linesById;
  final Map<String, BusStop> stopsById;
  final String originLabel;
  final String destinationLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final leg in option.legs) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: leg.type == TripLegType.walk
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.directions_walk_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.planWalkTimeAndDistance(
                                leg.durationMinutes,
                                DistanceUtils.formatMeters(
                                  leg.distanceMeters,
                                  l10n,
                                ),
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${leg.fromName.isEmpty ? originLabel : leg.fromName} → '
                              '${leg.toName.isEmpty ? destinationLabel : leg.toName}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          LineBadgeChip(
                            lineCode: leg.lineCode ?? leg.lineId ?? '',
                            lineColor: linesById[leg.lineId]?.color,
                            compact: true,
                          ),
                          Text(
                            '${TimeFormatUtils.formatTime24(leg.startTime)} → '
                            '${TimeFormatUtils.formatTime24(leg.endTime)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...() {
                        final stopNames = leg.intermediateStopIds.isNotEmpty
                            ? [
                                for (final id in leg.intermediateStopIds)
                                  stopsById[id]?.name ?? id,
                              ]
                            : [leg.fromName, leg.toName];
                        return [
                          for (var i = 0; i < stopNames.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    i == 0 || i == stopNames.length - 1
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.circle,
                                    size: i == 0 || i == stopNames.length - 1
                                        ? 14
                                        : 8,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      stopNames[i],
                                      style: (i == 0 ||
                                              i == stopNames.length - 1)
                                          ? Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              )
                                          : Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ];
                      }(),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

class _StepInstructionRow extends StatelessWidget {
  const _StepInstructionRow({
    required this.stepNumber,
    required this.step,
    required this.linesById,
    required this.destinationLabel,
  });

  final int stepNumber;
  final TripStepInstruction step;
  final Map<String, BusLine> linesById;
  final String destinationLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final statusColors =
        Theme.of(context).extension<MarpromStatusColors>() ??
            MarpromStatusColors.light;

    final description = _describeStep(l10n, step, destinationLabel);
    final icon = switch (step.type) {
      TripStepType.walkToStop ||
      TripStepType.walkToDestination =>
        Icons.directions_walk_rounded,
      TripStepType.boardBus => Icons.directions_bus_rounded,
      TripStepType.rideStops => Icons.route_rounded,
      TripStepType.transferAt => Icons.transfer_within_a_station_rounded,
      TripStepType.getOff => Icons.logout_rounded,
      TripStepType.arrived => Icons.flag_rounded,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: step.isTightTransfer
            ? statusColors.warningBg
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: step.isTightTransfer
              ? statusColors.warningFg
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Text(
              '$stepNumber',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: scheme.onPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
                if (step.type == TripStepType.boardBus &&
                    step.startTime != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (step.lineCode != null)
                        LineBadgeChip(
                          lineCode: step.lineCode!,
                          lineColor: linesById[step.lineId]?.color,
                          compact: true,
                        ),
                      Text(
                        TimeFormatUtils.formatTime24(step.startTime!),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      DepartureDelayChip(
                        delaySeconds: step.delaySeconds,
                        compact: true,
                      ),
                    ],
                  ),
                ],
                if (step.type == TripStepType.transferAt &&
                    step.isTightTransfer &&
                    step.durationMinutes != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.planTightTransferBody(step.durationMinutes!),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: statusColors.warningFg,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _describeStep(
  AppLocalizations l10n,
  TripStepInstruction step,
  String destinationLabel,
) {
  switch (step.type) {
    case TripStepType.walkToStop:
      final dist = DistanceUtils.formatMeters(step.distanceMeters ?? 0, l10n);
      return l10n.planStepWalkTo(step.stopName ?? '', dist);
    case TripStepType.boardBus:
      return l10n.planStepBoardLine(
        step.lineCode ?? '',
        step.directionName ?? '',
      );
    case TripStepType.rideStops:
      final stopsText = l10n.commonStopsPlural(step.stopCount ?? 1);
      return l10n.planStepRideStops(stopsText, step.stopName ?? '');
    case TripStepType.transferAt:
      final wait = step.durationMinutes ?? 0;
      final stop = step.stopName ?? '';
      return '${l10n.planStepTransferAt(stop)} — '
          '${l10n.planTransferWaitMinutes(wait, stop)}';
    case TripStepType.getOff:
      return l10n.planStepGetOffAt(step.stopName ?? '');
    case TripStepType.walkToDestination:
      final dist = DistanceUtils.formatMeters(step.distanceMeters ?? 0, l10n);
      return l10n.planStepWalkTo(destinationLabel, dist);
    case TripStepType.arrived:
      final time = step.endTime != null
          ? ' (${TimeFormatUtils.formatTime24(step.endTime!)})'
          : '';
      return '${l10n.planStepArrived}$time';
  }
}
