// Renders a selectable TripOption summary card with legs, delays, and warnings.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m_mobilnost/core/accessibility/semantics_helpers.dart';
import 'package:m_mobilnost/core/theme/brand_tokens.dart';
import 'package:m_mobilnost/core/theme/colors.dart';
import 'package:m_mobilnost/core/utils/distance.dart';
import 'package:m_mobilnost/core/utils/time_format.dart';
import 'package:m_mobilnost/core/widgets/occupancy_strip.dart';
import 'package:m_mobilnost/core/widgets/simulated_data_badge.dart';
import 'package:m_mobilnost/core/widgets/status_chip.dart';
import 'package:m_mobilnost/core/widgets/ui_kit.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/trip_plan.dart';

import 'trip_endpoint.dart';

/// Accessible card summarizing one [TripOption] with per-leg details and warnings.
class TripOptionCard extends StatelessWidget {
  /// Creates a [TripOptionCard] displaying [option] and selection state.
  const TripOptionCard({
    super.key,
    required this.option,
    required this.index,
    required this.isSelected,
    required this.onSelect,
    required this.linesById,
    required this.originLabel,
    required this.destinationLabel,
  });

  /// Itinerary option to render.
  final TripOption option;

  /// Zero-based rank index in the results list.
  final int index;

  /// Whether this option is currently active in the preview/steps panel.
  final bool isSelected;

  /// Callback triggered when the rider selects this card.
  final VoidCallback onSelect;

  /// Line metadata indexed by ID for line brand colors.
  final Map<String, BusLine> linesById;

  /// Localized origin label used when a walk leg starts at GPS/origin.
  final String originLabel;

  /// Localized destination label used when a walk leg ends at destination.
  final String destinationLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final statusColors =
        Theme.of(context).extension<MarpromStatusColors>() ??
            MarpromStatusColors.light;

    final depTime = TimeFormatUtils.formatTime24(option.departureTime);
    final arrTime = TimeFormatUtils.formatTime24(option.arrivalTime);
    final walkDistance = DistanceUtils.formatMeters(option.walkMeters, l10n);
    final summary = l10n.planOptionSummary(
      option.totalMinutes,
      l10n.commonTransfersPlural(option.transferCount),
      walkDistance,
    );
    final updatedHms = DateFormat('HH:mm:ss').format(option.freshness.updatedAt);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$depTime - $arrTime, $summary',
      child: SurfaceCard(
        selected: isSelected,
        onTap: onSelect,
        padding: const EdgeInsets.all(16),
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
                            '$depTime → $arrTime',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primaryContainer
                            : MarpromBrand.of(context).subtleFill,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
                            size: 18,
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${option.totalMinutes} min',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: isSelected
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SimulatedDataBadge(freshness: option.freshness),
                    if (option.hasTightTransfer)
                      StatusChip(
                        type: TransitStatusType.warning,
                        label: l10n.planTightTransferTitle,
                      ),
                    if (option.isAccessible)
                      StatusChip(
                        type: TransitStatusType.info,
                        label: l10n.stopAmenityStepFree,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.commonLastUpdatedAt(updatedHms)} • '
                  '${l10n.planDataReliability(option.freshness.localizedLabel(l10n))}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (option.hasTightTransfer &&
                    option.tightTransferMinutes != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColors.warningBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColors.warningFg,
                        width: statusColors.highContrastBorders ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: statusColors.warningFg,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.planTightTransferBody(
                              option.tightTransferMinutes!,
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: statusColors.warningFg,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 22),
                ..._buildLegs(context),
              ],
            ),
      ),
    );
  }

  List<Widget> _buildLegs(BuildContext context) {
    final l10n = context.l10n;
    final widgets = <Widget>[];
    TripLeg? previousBus;

    for (var i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      if (leg.type == TripLegType.walk) {
        final from = leg.fromName.isEmpty ? originLabel : leg.fromName;
        final to = leg.toName.isEmpty ? destinationLabel : leg.toName;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.directions_walk_rounded, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l10n.planWalkTimeAndDistance(leg.durationMinutes, DistanceUtils.formatMeters(leg.distanceMeters, l10n))} • $from → $to',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      if (previousBus != null) {
        final prevLeg = option.legs[i - 1];
        final waitMin =
            leg.startTime.difference(prevLeg.endTime).inMinutes.clamp(0, 120);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.transfer_within_a_station_rounded, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.planTransferWaitMinutes(waitMin, leg.fromName),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final lineColor = linesById[leg.lineId]?.color;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  LineBadgeChip(
                    lineCode: leg.lineCode ?? leg.lineId ?? '',
                    lineColor: lineColor,
                    compact: true,
                  ),
                  Text(
                    '${TimeFormatUtils.formatTime24(leg.startTime)} → '
                    '${TimeFormatUtils.formatTime24(leg.endTime)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  DepartureDelayChip(
                    delaySeconds: leg.delaySeconds,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${leg.fromName} → ${leg.toName}'
                '${leg.directionName != null ? ' (${leg.directionName})' : ''}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 6),
              OccupancyStrip(level: leg.occupancy, compact: true),
            ],
          ),
        ),
      );
      previousBus = leg;
    }

    return widgets;
  }
}
