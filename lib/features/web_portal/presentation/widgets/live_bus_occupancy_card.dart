// Compact live-bus occupancy card for the Marprom Web live page (`/live`).

import 'package:flutter/material.dart';

import '../../../../core/accessibility/semantics_helpers.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/occupancy_strip.dart';
import '../../../../data/models/bus_position.dart';
import '../../../../data/seed/seed_lines.dart';
import '../../../../data/simulation/occupancy_model.dart';
import '../marprom_web_strings.dart';

/// Occupancy level matching the displayed [BusPosition.loadPercent], so the
/// label, colour and `xx %` text can never disagree.
BusOccupancyLevel liveBusOccupancyLevel(BusPosition bus) =>
    OccupancyModel.levelFromLoadPercent(bus.loadPercent.clamp(0, 100));

/// Semantic occupancy colour for [level] from [MarpromStatusColors].
Color liveOccupancyColor(BuildContext context, BusOccupancyLevel level) {
  final colors = Theme.of(context).extension<MarpromStatusColors>() ??
      MarpromStatusColors.light;
  return switch (level) {
    BusOccupancyLevel.low => colors.occupancyLow,
    BusOccupancyLevel.medium => colors.occupancyMedium,
    BusOccupancyLevel.high => colors.occupancyHigh,
    BusOccupancyLevel.full => colors.occupancyFull,
    BusOccupancyLevel.unknown => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

/// Localized label for [level] (reuses the app's `occupancy*` l10n strings).
String liveOccupancyLabel(BuildContext context, BusOccupancyLevel level) {
  final l10n = context.l10n;
  return switch (level) {
    BusOccupancyLevel.low => l10n.occupancyLow,
    BusOccupancyLevel.medium => l10n.occupancyMedium,
    BusOccupancyLevel.high => l10n.occupancyHigh,
    BusOccupancyLevel.full => l10n.occupancyFull,
    BusOccupancyLevel.unknown => l10n.occupancyUnknown,
  };
}

/// `26 / 90 potnikov (29 %)` style passenger count text.
String livePassengerCountText(BusPosition bus, MarpromWebStrings ws) =>
    '${bus.passengerCount} / ${bus.vehicleCapacity} ${ws.passengersWord} (${bus.loadPercent} %)';

/// Small pill marking data produced by the fleet simulator.
class LiveSimulatedPill extends StatelessWidget {
  /// Creates a [LiveSimulatedPill].
  const LiveSimulatedPill({super.key, required this.ws});

  /// Localized web portal strings.
  final MarpromWebStrings ws;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<MarpromStatusColors>() ??
        MarpromStatusColors.light;
    return Tooltip(
      message: ws.simulatedTooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: colors.infoBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.infoFg.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined, size: 12, color: colors.infoFg),
            const SizedBox(width: 3),
            Text(
              ws.simulatedShort,
              style: TextStyle(
                color: colors.infoFg,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glanceable occupancy card of one live bus: line badge, vehicle, segmented
/// occupancy bar with text label, `passengers / capacity (xx %)`,
/// seated/standing split and a "simulated" marker. Tapping selects the bus.
class LiveBusOccupancyCard extends StatelessWidget {
  /// Creates a [LiveBusOccupancyCard] for [bus].
  const LiveBusOccupancyCard({
    super.key,
    required this.bus,
    required this.ws,
    this.isSimulated = true,
    this.selected = false,
    this.onTap,
  });

  /// Live (or simulated) bus snapshot.
  final BusPosition bus;

  /// Localized web portal strings.
  final MarpromWebStrings ws;

  /// Whether [bus] comes from the fleet simulator.
  final bool isSimulated;

  /// Whether this bus is the focused one on the map.
  final bool selected;

  /// Called when the card is activated.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final level = liveBusOccupancyLevel(bus);
    final accent = liveOccupancyColor(context, level);
    final lineColor = seedLinesById[bus.lineId]?.color ?? MarpromColors.marpromRed;
    final split = ws.seatedStanding(
      bus.seatedCount,
      bus.seatedCapacity,
      bus.standingCount,
      bus.standingCapacity,
    );
    final semanticsLabel = [
      '${bus.lineCode}, ${bus.vehicleId}, ${bus.vehicleModel}',
      liveOccupancyLabel(context, level),
      livePassengerCountText(bus, ws),
      split,
      if (isSimulated) ws.simulatedShort,
      if (selected) ws.selectedBus,
    ].join('. ');

    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      label: semanticsLabel,
      hint: onTap != null ? ws.showSeatDetail : null,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.08)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('live_occupancy_card_${bus.vehicleId}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? accent : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(6),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bus.vehicleId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            bus.vehicleModel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSimulated) ...[
                      const SizedBox(width: 6),
                      LiveSimulatedPill(ws: ws),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                OccupancyStrip(level: level, compact: true),
                const SizedBox(height: 8),
                Text(
                  livePassengerCountText(bus, ws),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.airline_seat_recline_normal_rounded,
                      size: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        split,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
