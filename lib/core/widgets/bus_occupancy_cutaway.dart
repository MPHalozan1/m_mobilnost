//**********************************************
// Interactive Bus Cutaway Occupancy Widget    *
//**********************************************

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/bus_line.dart';
import '../../data/models/bus_position.dart';
import '../theme/colors.dart';

//**********************************************
// BusOccupancyCutaway widget                  *
//**********************************************

/// Interactive top-down Marprom bus cutaway graphic displaying animated
/// seated and standing passenger silhouettes, wheelchair bay status, and
/// exact `current / max` occupancy breakdown on tap or hover.
class BusOccupancyCutaway extends StatefulWidget {
  /// Creates a [BusOccupancyCutaway] from explicit counts and vehicle attributes.
  const BusOccupancyCutaway({
    super.key,
    required this.passengerCount,
    required this.vehicleCapacity,
    required this.seatedCount,
    required this.seatedCapacity,
    required this.standingCount,
    required this.standingCapacity,
    required this.vehicleClass,
    this.vehicleModel,
    this.isLowFloor = true,
    this.hasWheelchairRamp = true,
    this.hasWheelchairSpace = true,
    this.hasAudioAnnouncements = true,
    this.compact = false,
    this.onReportCrowd,
  });

  /// Convenience constructor from a live [BusPosition] snapshot.
  factory BusOccupancyCutaway.fromBusPosition(
    BusPosition bus, {
    Key? key,
    bool compact = false,
    VoidCallback? onReportCrowd,
  }) {
    return BusOccupancyCutaway(
      key: key,
      passengerCount: bus.passengerCount,
      vehicleCapacity: bus.vehicleCapacity,
      seatedCount: bus.seatedCount,
      seatedCapacity: bus.seatedCapacity,
      standingCount: bus.standingCount,
      standingCapacity: bus.standingCapacity,
      vehicleClass: bus.vehicleClass,
      vehicleModel: bus.vehicleModel,
      isLowFloor: bus.isLowFloor,
      hasWheelchairRamp: bus.hasWheelchairRamp,
      hasWheelchairSpace: bus.hasWheelchairSpace,
      hasAudioAnnouncements: bus.hasAudioAnnouncements,
      compact: compact,
      onReportCrowd: onReportCrowd,
    );
  }

  /// Current total passengers aboard (<= [vehicleCapacity] <= 120).
  final int passengerCount;

  /// Maximum passenger capacity (64 midibus, 85-95 solo, 120 articulated).
  final int vehicleCapacity;

  /// Current seated passengers.
  final int seatedCount;

  /// Maximum seated capacity.
  final int seatedCapacity;

  /// Current standing passengers.
  final int standingCount;

  /// Maximum standing capacity.
  final int standingCapacity;

  /// Chassis class determining the bus cutaway layout.
  final MarpromVehicleClass vehicleClass;

  /// Optional fleet model label (e.g. `IVECO E-WAY 12m`).
  final String? vehicleModel;

  /// Whether the vehicle is low-floor.
  final bool isLowFloor;

  /// Whether the vehicle has a deployable wheelchair ramp.
  final bool hasWheelchairRamp;

  /// Whether the vehicle has a dedicated wheelchair bay.
  final bool hasWheelchairSpace;

  /// Whether the vehicle has audio stop announcements.
  final bool hasAudioAnnouncements;

  /// Renders a tighter vertical footprint when true.
  final bool compact;

  /// Optional callback triggered when the user taps "Prijavi zasedenost".
  final VoidCallback? onReportCrowd;

  @override
  State<BusOccupancyCutaway> createState() => _BusOccupancyCutawayState();
}

class _BusOccupancyCutawayState extends State<BusOccupancyCutaway> {
  bool _expanded = false;
  bool _hovered = false;

  Color _statusColor(double ratio) {
    if (ratio < 0.50) return MarpromColors.mobilityGreen;
    if (ratio < 0.80) return const Color(0xFFD97706);
    return MarpromColors.marpromRed;
  }

  String _statusLabel(double ratio) {
    if (ratio < 0.50) return 'Veliko prostora';
    if (ratio < 0.80) return 'Zmerno zaseden';
    return 'Skoraj poln';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cap = widget.vehicleCapacity.clamp(1, 120);
    final pax = widget.passengerCount.clamp(0, cap);
    final ratio = (pax / cap).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    final accent = _statusColor(ratio);
    final showBreakdown = _expanded || _hovered;

    return Semantics(
      container: true,
      button: true,
      label:
          'Zasedenost ${widget.vehicleClass.label}: $pax od $cap potnikov ($percent%), '
          'sedeži ${widget.seatedCount} od ${widget.seatedCapacity}, '
          'stojišča ${widget.standingCount} od ${widget.standingCapacity}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.all(widget.compact ? 10 : 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: showBreakdown
                    ? accent.withValues(alpha: 0.7)
                    : scheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top summary row: vehicle class + total current / max badge
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          widget.vehicleModel ?? widget.vehicleClass.label,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '$pax / $cap ($percent%) • ${_statusLabel(ratio)}',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.compact ? 8 : 10),
                // Animated top-down cutaway schematic
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: ratio),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedRatio, _) {
                    return SizedBox(
                      height: widget.compact ? 58 : 72,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _BusCutawayPainter(
                          vehicleClass: widget.vehicleClass,
                          seatedCount: widget.seatedCount,
                          seatedCapacity: widget.seatedCapacity,
                          standingCount: widget.standingCount,
                          standingCapacity: widget.standingCapacity,
                          accentColor: accent,
                          hasWheelchairSpace: widget.hasWheelchairSpace,
                          isDark: scheme.brightness == Brightness.dark,
                          outlineColor: scheme.outline,
                          surfaceColor: scheme.surface,
                        ),
                      ),
                    );
                  },
                ),
                // Expandable seated / standing & accessibility breakdown
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: showBreakdown || !widget.compact
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  _MiniCountPill(
                                    icon: Icons
                                        .airline_seat_recline_normal_rounded,
                                    label:
                                        'Sedeži: ${widget.seatedCount}/${widget.seatedCapacity}',
                                    color: accent,
                                  ),
                                  _MiniCountPill(
                                    icon: Icons.accessibility_new_rounded,
                                    label:
                                        'Stojišča: ${widget.standingCount}/${widget.standingCapacity}',
                                    color: accent,
                                  ),
                                  if (widget.isLowFloor &&
                                      widget.hasWheelchairRamp &&
                                      widget.hasWheelchairSpace)
                                    const _MiniCountPill(
                                      icon: Icons.accessible_rounded,
                                      label: 'Nizkopodni + klančina',
                                      color: Color(0xFF0284C7),
                                    ),
                                  if (widget.hasAudioAnnouncements)
                                    const _MiniCountPill(
                                      icon: Icons.volume_up_rounded,
                                      label: 'Zvočne najave',
                                      color: Color(0xFF64748B),
                                    ),
                                ],
                              ),
                              if (widget.onReportCrowd != null &&
                                  showBreakdown) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: widget.onReportCrowd,
                                    icon: const Icon(
                                      Icons.campaign_outlined,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Prijavi zasedenost v živo',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniCountPill extends StatelessWidget {
  const _MiniCountPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

//**********************************************
// CustomPainter for chassis cutaway schematic *
//**********************************************

class _BusCutawayPainter extends CustomPainter {
  const _BusCutawayPainter({
    required this.vehicleClass,
    required this.seatedCount,
    required this.seatedCapacity,
    required this.standingCount,
    required this.standingCapacity,
    required this.accentColor,
    required this.hasWheelchairSpace,
    required this.isDark,
    required this.outlineColor,
    required this.surfaceColor,
  });

  final MarpromVehicleClass vehicleClass;
  final int seatedCount;
  final int seatedCapacity;
  final int standingCount;
  final int standingCapacity;
  final Color accentColor;
  final bool hasWheelchairSpace;
  final bool isDark;
  final Color outlineColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = 3.0;
    final bodyRect = Rect.fromLTWH(
      pad,
      pad,
      size.width - pad * 2,
      size.height - pad * 2,
    );
    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: const Radius.circular(10),
      bottomLeft: const Radius.circular(10),
      topRight: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );

    // Outer bus hull
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E1A1D) : const Color(0xFFF8FAFC);
    canvas.drawRRect(bodyRRect, bgPaint);

    // Subtle occupancy aisle tint
    final floorPaint = Paint()..color = accentColor.withValues(alpha: 0.08);
    canvas.drawRRect(bodyRRect, floorPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = outlineColor;
    canvas.drawRRect(bodyRRect, borderPaint);

    // Windshield & driver cab on right (front of bus)
    final cabX = bodyRect.right - 22;
    canvas.drawLine(
      Offset(cabX, bodyRect.top + 3),
      Offset(cabX, bodyRect.bottom - 3),
      Paint()
        ..color = outlineColor.withValues(alpha: 0.5)
        ..strokeWidth = 1.2,
    );
    // Headlights
    final headlightPaint = Paint()..color = const Color(0xFFFDE047);
    canvas.drawCircle(
      Offset(bodyRect.right - 3, bodyRect.top + 10),
      2.3,
      headlightPaint,
    );
    canvas.drawCircle(
      Offset(bodyRect.right - 3, bodyRect.bottom - 10),
      2.3,
      headlightPaint,
    );

    // Articulation accordion joint in center for 18m "zgibni" bus
    if (vehicleClass == MarpromVehicleClass.articulated18m) {
      final midX = bodyRect.left + bodyRect.width * 0.47;
      final jointRect = Rect.fromCenter(
        center: Offset(midX, bodyRect.center.dy),
        width: 12,
        height: bodyRect.height - 2,
      );
      canvas.drawRect(
        jointRect,
        Paint()
          ..color =
              isDark ? const Color(0xFF332D31) : const Color(0xFFE2E8F0),
      );
      for (var dx = -3.0; dx <= 3.0; dx += 3.0) {
        canvas.drawLine(
          Offset(midX + dx, bodyRect.top + 2),
          Offset(midX + dx, bodyRect.bottom - 2),
          Paint()
            ..color = outlineColor.withValues(alpha: 0.7)
            ..strokeWidth = 1,
        );
      }
    }

    // Door openings along bottom side
    final doorFractions = switch (vehicleClass) {
      MarpromVehicleClass.midibus9m => const [0.32, 0.80],
      MarpromVehicleClass.solo12m => const [0.16, 0.52, 0.84],
      MarpromVehicleClass.articulated18m => const [0.12, 0.36, 0.64, 0.86],
    };
    final doorPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final f in doorFractions) {
      final dx = bodyRect.left + bodyRect.width * f;
      canvas.drawLine(
        Offset(dx - 6, bodyRect.bottom),
        Offset(dx + 6, bodyRect.bottom),
        doorPaint,
      );
    }

    // Seat rows (top & bottom banks)
    final seatCols = switch (vehicleClass) {
      MarpromVehicleClass.midibus9m => 8,
      MarpromVehicleClass.solo12m => 12,
      MarpromVehicleClass.articulated18m => 16,
    };
    final totalSeatsVisual = seatCols * 2;
    final seatFillRatio =
        seatedCapacity > 0 ? (seatedCount / seatedCapacity).clamp(0.0, 1.0) : 0.0;
    final filledSeats = (totalSeatsVisual * seatFillRatio).round();

    final passengerAreaLeft = bodyRect.left + 8;
    final passengerAreaRight = cabX - 6;
    final areaWidth = math.max(20.0, passengerAreaRight - passengerAreaLeft);
    final colStep = areaWidth / seatCols;
    final seatW = math.max(5.0, colStep * 0.62);
    final seatH = math.max(6.0, bodyRect.height * 0.21);

    var seatIndex = 0;
    for (var col = 0; col < seatCols; col++) {
      final x = passengerAreaLeft + col * colStep + (colStep - seatW) / 2;

      // Top row seat
      final topOccupied = seatIndex < filledSeats;
      _drawSeat(
        canvas,
        Rect.fromLTWH(x, bodyRect.top + 5, seatW, seatH),
        occupied: topOccupied,
      );
      seatIndex++;

      // Bottom row seat (leave middle wheelchair bay open if accessible)
      final isWheelchairSlot = hasWheelchairSpace &&
          (col == (seatCols * 0.45).round() ||
              col == (seatCols * 0.45).round() + 1);
      if (isWheelchairSlot) {
        if (col == (seatCols * 0.45).round()) {
          final bayRect = Rect.fromLTWH(
            x,
            bodyRect.bottom - seatH - 5,
            colStep * 1.7,
            seatH,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(bayRect, const Radius.circular(3)),
            Paint()..color = const Color(0xFF0284C7).withValues(alpha: 0.24),
          );
          canvas.drawCircle(
            bayRect.center,
            math.min(seatH * 0.28, 3.2),
            Paint()..color = const Color(0xFF0284C7),
          );
        }
      } else {
        final bottomOccupied = seatIndex < filledSeats;
        _drawSeat(
          canvas,
          Rect.fromLTWH(x, bodyRect.bottom - seatH - 5, seatW, seatH),
          occupied: bottomOccupied,
        );
      }
      seatIndex++;
    }

    // Central standing aisle silhouettes
    final aisleSlots = switch (vehicleClass) {
      MarpromVehicleClass.midibus9m => 10,
      MarpromVehicleClass.solo12m => 16,
      MarpromVehicleClass.articulated18m => 22,
    };
    final standingRatio = standingCapacity > 0
        ? (standingCount / standingCapacity).clamp(0.0, 1.0)
        : 0.0;
    final filledStanding = (aisleSlots * standingRatio).round();
    final aisleStep = areaWidth / aisleSlots;
    final radius = math.min(3.8, bodyRect.height * 0.075);

    for (var i = 0; i < aisleSlots; i++) {
      final cx = passengerAreaLeft + (i + 0.5) * aisleStep;
      final cy = bodyRect.center.dy + (i.isEven ? -3.0 : 3.0);
      final occupied = i < filledStanding;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = occupied
              ? accentColor
              : outlineColor.withValues(alpha: isDark ? 0.25 : 0.18),
      );
    }
  }

  void _drawSeat(Canvas canvas, Rect rect, {required bool occupied}) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = occupied
            ? accentColor
            : (isDark ? const Color(0xFF332D30) : const Color(0xFFE2E8F0)),
    );
  }

  @override
  bool shouldRepaint(covariant _BusCutawayPainter oldDelegate) {
    return oldDelegate.seatedCount != seatedCount ||
        oldDelegate.standingCount != standingCount ||
        oldDelegate.vehicleClass != vehicleClass ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
