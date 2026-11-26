//**********************************************
// Ultra-Clean Compact TripOptionCard          *
//**********************************************

import 'package:flutter/material.dart';
import 'package:m_mobilnost/core/accessibility/semantics_helpers.dart';
import 'package:m_mobilnost/core/theme/colors.dart';
import 'package:m_mobilnost/core/utils/distance.dart';
import 'package:m_mobilnost/core/utils/time_format.dart';
import 'package:m_mobilnost/core/widgets/bus_occupancy_cutaway.dart';
import 'package:m_mobilnost/core/widgets/status_chip.dart';
import 'package:m_mobilnost/core/widgets/ui_kit.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/trip_plan.dart';

import 'trip_endpoint.dart';

/// Compact main route card showing ONLY:
/// 1. Visual trip chain (`🚶 3 min -> [G1] -> 🔁 Glavni trg -> [P7]`)
/// 2. Total duration + departure -> arrival times
/// 3. Critical real-time alerts ONLY (`Early`, `Late`, `Full > 85%`)
/// All secondary info lives behind the `"Info / Podrobnosti"` drawer button.
class TripOptionCard extends StatelessWidget {
  /// Creates a compact [TripOptionCard].
  const TripOptionCard({
    super.key,
    required this.option,
    required this.index,
    required this.isSelected,
    required this.onSelect,
    required this.linesById,
    required this.originLabel,
    required this.destinationLabel,
    this.onOpen3DRoute,
  });

  /// Itinerary option to render.
  final TripOption option;

  /// Zero-based rank index in the results list.
  final int index;

  /// Whether this option is currently highlighted on the map.
  final bool isSelected;

  /// Callback triggered when the rider selects this route.
  final VoidCallback onSelect;

  /// Line metadata indexed by ID for line badge colors.
  final Map<String, BusLine> linesById;

  /// Localized origin label.
  final String originLabel;

  /// Localized destination label.
  final String destinationLabel;

  /// Optional callback to open 3D Route View (`3D trasa`) along this route.
  final VoidCallback? onOpen3DRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isSl = Localizations.localeOf(context).languageCode == 'sl';

    final depTime = TimeFormatUtils.formatTime24(option.departureTime);
    final arrTime = TimeFormatUtils.formatTime24(option.arrivalTime);
    final delaySec = option.primaryDelaySeconds;
    final maxLoad = option.maxBusLoadPercent;
    final isFull = option.hasFullBusAlert;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$depTime - $arrTime, ${option.totalMinutes} min',
      child: SurfaceCard(
        selected: isSelected,
        onTap: onSelect,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Departure -> Arrival times + Duration badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$depTime → $arrTime',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${option.totalMinutes} min',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurface,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: Visual Trip Chain (`🚶 3 min -> [G1] -> 🔁 Glavni trg -> [P7]`)
            _VisualTripChain(
              option: option,
              linesById: linesById,
            ),
            // Row 3: CRITICAL REAL-TIME ALERTS ONLY (Early, Late, Full) — NEVER hidden
            if (delaySec < -60 || delaySec > 120 || isFull) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (delaySec < -60)
                    _CriticalAlertPill(
                      icon: Icons.fast_forward_rounded,
                      label: isSl
                          ? 'Prezgodaj -${(-delaySec / 60).round()} min'
                          : 'Early -${(-delaySec / 60).round()} min',
                      bg: const Color(0xFF0E7490).withValues(alpha: 0.16),
                      fg: const Color(0xFF22D3EE),
                    ),
                  if (delaySec > 120)
                    _CriticalAlertPill(
                      icon: Icons.schedule_rounded,
                      label: isSl
                          ? 'Zamuda +${(delaySec / 60).round()} min'
                          : 'Late +${(delaySec / 60).round()} min',
                      bg: const Color(0xFFDC2626).withValues(alpha: 0.16),
                      fg: const Color(0xFFF87171),
                    ),
                  if (isFull)
                    _CriticalAlertPill(
                      icon: Icons.groups_rounded,
                      label: maxLoad != null
                          ? (isSl ? 'Polno $maxLoad%' : 'Full $maxLoad%')
                          : (isSl ? 'Polno' : 'Full'),
                      bg: MarpromColors.marpromRed,
                      fg: Colors.white,
                    ),
                ],
              ),
            ],
            if (isSelected) ...[
              const SizedBox(height: 10),
              _SelectedStepTimeline(
                option: option,
                linesById: linesById,
                originLabel: originLabel,
                destinationLabel: destinationLabel,
                isSl: isSl,
              ),
            ],
            const SizedBox(height: 8),
            // Row 4: Single clean "Info / Podrobnosti" drawer trigger + optional 3D shortcut
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _openDetailsSheet(context, l10n),
                  icon: const Icon(Icons.info_outline_rounded, size: 17),
                  label: Text(
                    isSl ? 'Info / Podrobnosti' : 'Info / Details',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (onOpen3DRoute != null)
                  TextButton.icon(
                    onPressed: onOpen3DRoute,
                    icon: const Icon(Icons.view_in_ar_rounded, size: 17),
                    label: const Text(
                      '3D trasa',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDetailsSheet(BuildContext context, dynamic l10n) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _RouteInfoDetailsSheet(
        option: option,
        linesById: linesById,
        originLabel: originLabel,
        destinationLabel: destinationLabel,
      ),
    );
  }
}

class _VisualTripChain extends StatelessWidget {
  const _VisualTripChain({
    required this.option,
    required this.linesById,
  });

  final TripOption option;
  final Map<String, BusLine> linesById;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <Widget>[];
    var busCount = 0;

    for (var i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      if (items.isNotEmpty) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      }
      if (leg.type == TripLegType.walk) {
        items.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_walk_rounded, size: 14),
                const SizedBox(width: 3),
                Text(
                  '${leg.durationMinutes}m',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        if (busCount > 0) {
          items.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.repeat_rounded, size: 13),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      leg.fromName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        busCount++;
        final color = linesById[leg.lineId]?.color ?? MarpromColors.marpromRed;
        items.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              leg.lineCode ?? leg.lineId ?? 'BUS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }
    }

    return Wrap(
      spacing: 2,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }
}

class _CriticalAlertPill extends StatelessWidget {
  const _CriticalAlertPill({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

//**********************************************
// Expandable "Info / Podrobnosti" Sheet       *
//**********************************************

class _RouteInfoDetailsSheet extends StatelessWidget {
  const _RouteInfoDetailsSheet({
    required this.option,
    required this.linesById,
    required this.originLabel,
    required this.destinationLabel,
  });

  final TripOption option;
  final Map<String, BusLine> linesById;
  final String originLabel;
  final String destinationLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isSl = Localizations.localeOf(context).languageCode == 'sl';
    final statusColors =
        Theme.of(context).extension<MarpromStatusColors>() ??
            MarpromStatusColors.light;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isSl ? 'Podrobnosti poti' : 'Route Info & Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Ticket / zone info & accessible status
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(
                  type: option.isAccessible
                      ? TransitStatusType.info
                      : TransitStatusType.warning,
                  label: option.isAccessible
                      ? (isSl
                          ? 'Nizkopodno + klančina'
                          : 'Low-floor + wheelchair ramp')
                      : (isSl
                          ? 'Brez zagotovljene klančine'
                          : 'Not guaranteed step-free'),
                ),
                StatusChip(
                  type: TransitStatusType.info,
                  label: isSl
                      ? 'Cona Maribor • 1 vozovnica'
                      : 'Maribor Zone • Single pass valid',
                ),
              ],
            ),
            if (option.accessibleAlternativeNote != null) ...[
              const SizedBox(height: 10),
              Card(
                color: statusColors.infoBg,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    option.accessibleAlternativeNote!,
                    style: TextStyle(
                      color: statusColors.infoFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            if (option.hasTightTransfer &&
                option.tightTransferMinutes != null) ...[
              const SizedBox(height: 10),
              Card(
                color: statusColors.warningBg,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
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
                          style: TextStyle(
                            color: statusColors.warningFg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            for (var i = 0; i < option.legs.length; i++) ...[
              _LegDetailCard(
                leg: option.legs[i],
                lineColor: linesById[option.legs[i].lineId]?.color,
                originLabel: originLabel,
                destinationLabel: destinationLabel,
                isSl: isSl,
                scheme: scheme,
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _LegDetailCard extends StatelessWidget {
  const _LegDetailCard({
    required this.leg,
    required this.lineColor,
    required this.originLabel,
    required this.destinationLabel,
    required this.isSl,
    required this.scheme,
  });

  final TripLeg leg;
  final Color? lineColor;
  final String originLabel;
  final String destinationLabel;
  final bool isSl;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (leg.type == TripLegType.walk) {
      final from = leg.fromName.isEmpty ? originLabel : leg.fromName;
      final to = leg.toName.isEmpty ? destinationLabel : leg.toName;
      return SurfaceCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.planWalkTimeAndDistance(leg.durationMinutes, DistanceUtils.formatMeters(leg.distanceMeters, l10n))} • $from → $to',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (leg.navigationInstructions.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final step in leg.navigationInstructions)
                Text(
                  '• $step',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      );
    }

    final color = lineColor ?? MarpromColors.marpromRed;
    final cap = (leg.vehicleCapacity ?? 90).clamp(1, 120);
    final pax = (leg.passengerCount ?? 32).clamp(0, cap);
    final seatedCap = leg.seatedCapacity ?? 30;
    final seated = leg.seatedCount ?? pax.clamp(0, seatedCap);
    final standingCap = leg.standingCapacity ?? (cap - seatedCap);
    final standing = leg.standingCount ?? (pax - seated).clamp(0, standingCap);

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  leg.lineCode ?? leg.lineId ?? 'BUS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${TimeFormatUtils.formatTime24(leg.startTime)} → '
                  '${TimeFormatUtils.formatTime24(leg.endTime)} (${leg.durationMinutes} min)',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              DepartureDelayChip(delaySeconds: leg.delaySeconds, compact: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${leg.fromName} → ${leg.toName}'
            '${leg.directionName != null ? ' (${leg.directionName})' : ''}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (leg.intermediateStopIds.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${leg.intermediateStopIds.length} ${isSl ? 'postajališč' : 'stops'}: '
              '${leg.intermediateStopIds.join(' • ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          BusOccupancyCutaway(
            passengerCount: pax,
            vehicleCapacity: cap,
            seatedCount: seated,
            seatedCapacity: seatedCap,
            standingCount: standing,
            standingCapacity: standingCap,
            vehicleClass: leg.vehicleClass,
            vehicleModel: leg.vehicleModel,
            isLowFloor: leg.isLowFloor,
            hasWheelchairRamp: leg.hasWheelchairRamp,
            hasWheelchairSpace: leg.hasWheelchairSpace,
            hasAudioAnnouncements: leg.hasAudioAnnouncements,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _SelectedStepTimeline extends StatelessWidget {
  const _SelectedStepTimeline({
    required this.option,
    required this.linesById,
    required this.originLabel,
    required this.destinationLabel,
    required this.isSl,
  });

  final TripOption option;
  final Map<String, BusLine> linesById;
  final String originLabel;
  final String destinationLabel;
  final bool isSl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1A73E8).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < option.legs.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildStepRow(context, scheme, l10n, option.legs[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(
    BuildContext context,
    ColorScheme scheme,
    dynamic l10n,
    TripLeg leg,
  ) {
    if (leg.type == TripLegType.walk) {
      final dist = DistanceUtils.formatMeters(leg.distanceMeters, l10n);
      final toName = leg.toName.trim().isNotEmpty ? leg.toName : destinationLabel;
      final text = isSl
          ? 'Peš $dist (${leg.durationMinutes} min) do $toName'
          : 'Walk $dist (${leg.durationMinutes} min) to $toName';
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              size: 14,
              color: Color(0xFF1A73E8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
              ),
            ),
          ),
        ],
      );
    }

    final lineColor = linesById[leg.lineId]?.color ?? MarpromColors.marpromRed;
    final code = leg.lineCode ?? leg.lineId ?? 'BUS';
    final startStr = TimeFormatUtils.formatTime24(leg.startTime);
    final endStr = TimeFormatUtils.formatTime24(leg.endTime);
    final dirSuffix =
        leg.directionName != null && leg.directionName!.trim().isNotEmpty
            ? ' → ${leg.directionName}'
            : '';
    final stopCount = leg.intermediateStopIds.length + 1;
    final headline = isSl
        ? 'Vstopi na postaji ${leg.fromName} ($startStr)'
        : 'Board at ${leg.fromName} ($startStr)';
    final subline = isSl
        ? 'Izstopi na ${leg.toName} ($endStr) • $stopCount postaj (${leg.durationMinutes} min)'
        : 'Get off at ${leg.toName} ($endStr) • $stopCount stops (${leg.durationMinutes} min)';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$headline$dirSuffix',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(height: 1),
              Text(
                subline,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
