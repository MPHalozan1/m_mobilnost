//**********************************************
// P8-Style Live Bus Occupancy & Sensor View   *
//**********************************************

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/bus_line.dart';
import '../../data/models/bus_position.dart';

//**********************************************
// Animated boarding/alighting dot descriptor  *
//**********************************************

class _DoorTransitParticle {
  const _DoorTransitParticle({
    required this.inbound,
    required this.frontDoor,
    required this.targetXFraction,
    required this.targetIsTop,
  });

  final bool inbound;
  final bool frontDoor;
  final double targetXFraction;
  final bool targetIsTop;
}

//**********************************************
// BusOccupancyCutaway widget (P8 Schematic)   *
//**********************************************

/// Interactive top-down Marprom bus schematic inspired by the P8 live sensor
/// simulation: green free seats (`#2E9E57`), red occupied seats (`#D64545`),
/// aisle passenger silhouettes, dashed wheelchair bay, driver cab, front yellow
/// validator (`#C9A400`), and S1/S2 3D door sensors (`#2F6DB0`) animating `+1`/`-1`
/// boarding/alighting events automatically as live telemetry updates.
class BusOccupancyCutaway extends StatefulWidget {
  /// Creates a [BusOccupancyCutaway].
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
    this.statusLabel,
    this.statusColor,
  });

  /// Convenience constructor from a live [BusPosition] telemetry snapshot.
  factory BusOccupancyCutaway.fromBusPosition(
    BusPosition bus, {
    Key? key,
    bool compact = false,
    VoidCallback? onReportCrowd,
    String? statusLabel,
    Color? statusColor,
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
      statusLabel: statusLabel,
      statusColor: statusColor,
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

  /// Chassis class determining the cutaway layout.
  final MarpromVehicleClass vehicleClass;

  /// Optional fleet model label (e.g. `IVECO E-WAY 12m`).
  final String? vehicleModel;

  /// Whether the vehicle is low-floor (*nizkopodni*).
  final bool isLowFloor;

  /// Whether the vehicle has a wheelchair ramp (*klančina*).
  final bool hasWheelchairRamp;

  /// Whether the vehicle has a dedicated wheelchair bay.
  final bool hasWheelchairSpace;

  /// Whether the vehicle has audio stop announcements.
  final bool hasAudioAnnouncements;

  /// Tighter vertical padding when true.
  final bool compact;

  /// Optional callback triggered when the user taps crowd report.
  final VoidCallback? onReportCrowd;

  /// Optional semantic occupancy label override.
  final String? statusLabel;

  /// Optional accent colour override.
  final Color? statusColor;

  @override
  State<BusOccupancyCutaway> createState() => _BusOccupancyCutawayState();
}

class _BusOccupancyCutawayState extends State<BusOccupancyCutaway>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _hovered = false;
  late final AnimationController _sensorAnim;
  List<_DoorTransitParticle> _particles = const [];
  int _lastDelta = 0;
  double _roadPhase = 0.0;

  @override
  void initState() {
    super.initState();
    _sensorAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );
  }

  @override
  void didUpdateWidget(covariant BusOccupancyCutaway oldWidget) {
    super.didUpdateWidget(oldWidget);
    final delta = widget.passengerCount - oldWidget.passengerCount;
    if (delta != 0) {
      _lastDelta = delta;
      final rng = math.Random(widget.passengerCount * 31 + delta);
      final count = delta.abs().clamp(1, 3);
      _particles = [
        for (var i = 0; i < count; i++)
          _DoorTransitParticle(
            inbound: delta > 0,
            frontDoor: delta > 0 ? rng.nextDouble() < 0.85 : rng.nextDouble() < 0.25,
            targetXFraction: 0.18 + rng.nextDouble() * 0.60,
            targetIsTop: rng.nextBool(),
          ),
      ];
      _roadPhase = (_roadPhase + 0.35) % 1.0;
      _sensorAnim.forward(from: 0.0);
    } else if (oldWidget.seatedCount != widget.seatedCount ||
        oldWidget.standingCount != widget.standingCount) {
      _roadPhase = (_roadPhase + 0.25) % 1.0;
      _sensorAnim.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _sensorAnim.dispose();
    super.dispose();
  }

  Color _statusColor(double ratio) {
    if (ratio < 0.55) return const Color(0xFF2E9E57);
    if (ratio <= 0.82) return const Color(0xFFE0782A);
    return const Color(0xFFD64545);
  }

  String _statusLabel(double ratio, int freeSeats) {
    if (ratio > 0.82) return 'Skoraj polno / Polno';
    if (freeSeats == 0) return 'Samo stojišča';
    if (ratio < 0.55) return 'Prosti sedeži: $freeSeats';
    return 'Zmerno zaseden';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cap = widget.vehicleCapacity.clamp(1, 120);
    final pax = widget.passengerCount.clamp(0, cap);
    final ratio = (pax / cap).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    final freeSeats = math.max(0, widget.seatedCapacity - widget.seatedCount);
    final accent = widget.statusColor ?? _statusColor(ratio);
    final showBreakdown = _expanded || _hovered;

    return RepaintBoundary(
      child: Semantics(
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
                  // Header row: vehicle model + live passenger / free-seat badge
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
                          Flexible(
                            child: Text(
                              widget.vehicleModel ?? widget.vehicleClass.label,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
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
                          '$pax / $cap ($percent%) • ${widget.statusLabel ?? _statusLabel(ratio, freeSeats)}',
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
                  // P8 top-down schematic with animated S1/S2 sensors & seats
                  AnimatedBuilder(
                    animation: _sensorAnim,
                    builder: (_, _) {
                      return SizedBox(
                        height: widget.compact ? 74 : 90,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _P8BusCutawayPainter(
                            vehicleClass: widget.vehicleClass,
                            seatedCount: widget.seatedCount,
                            seatedCapacity: widget.seatedCapacity,
                            standingCount: widget.standingCount,
                            standingCapacity: widget.standingCapacity,
                            hasWheelchairSpace: widget.hasWheelchairSpace,
                            isDark: scheme.brightness == Brightness.dark,
                            outlineColor: scheme.outline,
                            animValue: _sensorAnim.value,
                            isAnimating: _sensorAnim.isAnimating,
                            particles: _particles,
                            lastDelta: _lastDelta,
                            roadPhase: _roadPhase,
                          ),
                        ),
                      );
                    },
                  ),
                  // Legend + expandable seated/standing & accessibility details
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
                                  spacing: 8,
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
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

//**********************************************
// CustomPainter replicating P8 HTML animation *
//**********************************************

class _P8BusCutawayPainter extends CustomPainter {
  const _P8BusCutawayPainter({
    required this.vehicleClass,
    required this.seatedCount,
    required this.seatedCapacity,
    required this.standingCount,
    required this.standingCapacity,
    required this.hasWheelchairSpace,
    required this.isDark,
    required this.outlineColor,
    required this.animValue,
    required this.isAnimating,
    required this.particles,
    required this.lastDelta,
    required this.roadPhase,
  });

  final MarpromVehicleClass vehicleClass;
  final int seatedCount;
  final int seatedCapacity;
  final int standingCount;
  final int standingCapacity;
  final bool hasWheelchairSpace;
  final bool isDark;
  final Color outlineColor;
  final double animValue;
  final bool isAnimating;
  final List<_DoorTransitParticle> particles;
  final int lastDelta;
  final double roadPhase;

  static const Color _seatFree = Color(0xFF2E9E57);
  static const Color _seatTaken = Color(0xFFD64545);
  static const Color _sensorBlue = Color(0xFF2F6DB0);
  static const Color _sensorOut = Color(0xFFE0782A);
  static const Color _validatorGold = Color(0xFFC9A400);
  static const Color _inkDark = Color(0xFF16212E);

  @override
  void paint(Canvas canvas, Size size) {
    final hullBottom = size.height - 14.0;
    final bodyRect = Rect.fromLTWH(4, 3, size.width - 8, hullBottom - 3);
    final bodyRRect = RRect.fromRectAndRadius(
      bodyRect,
      const Radius.circular(14),
    );

    // Road dashes scrolling along the bottom like the P8 HTML road strip
    final roadY = size.height - 5.0;
    final dashPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.45)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    const step = 20.0;
    final shift = ((roadPhase + animValue) % 1.0) * step;
    for (var x = -shift; x < size.width; x += step) {
      canvas.drawLine(Offset(x, roadY), Offset(x + 10, roadY), dashPaint);
    }

    // Outer bus hull (#FBFAF7 light / #1E1A1D dark)
    canvas.drawRRect(
      bodyRRect,
      Paint()..color = isDark ? const Color(0xFF1E1A1D) : const Color(0xFFFBFAF7),
    );
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = isDark ? outlineColor : _inkDark,
    );

    // Front windshield on the right side
    final windshieldRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bodyRect.right - 8,
        bodyRect.top + 8,
        5,
        bodyRect.height - 16,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      windshieldRect,
      Paint()..color = const Color(0xFFCFE0EF),
    );

    // Driver cab (voznik — grey square top right, never counted)
    final cabLeft = bodyRect.right - 26;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cabLeft, bodyRect.top + 6, 15, 15),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF9AA3AD),
    );

    // Articulation accordion joint for 18m buses
    if (vehicleClass == MarpromVehicleClass.articulated18m) {
      final midX = bodyRect.left + bodyRect.width * 0.47;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(midX, bodyRect.center.dy),
          width: 10,
          height: bodyRect.height - 2,
        ),
        Paint()
          ..color = isDark ? const Color(0xFF332D31) : const Color(0xFFE6E0D3),
      );
    }

    // Front validator (#C9A400) near front door S1, flashes bright yellow on boarding
    final frontDoorX = bodyRect.right - 24.0;
    final midDoorX = bodyRect.left + bodyRect.width * 0.50;
    final valFlash = isAnimating &&
        lastDelta > 0 &&
        animValue > 0.12 &&
        animValue < 0.45;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          frontDoorX - 18,
          bodyRect.bottom - 18,
          8,
          11,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = valFlash ? const Color(0xFFFFF06A) : _validatorGold,
    );

    // S2 (middle) & S1 (front) 3D door sensors + dynamic beams
    final doorXs = vehicleClass == MarpromVehicleClass.midibus9m
        ? [bodyRect.left + bodyRect.width * 0.34, frontDoorX]
        : [midDoorX, frontDoorX];

    for (var dIdx = 0; dIdx < doorXs.length; dIdx++) {
      final dx = doorXs[dIdx];
      final isFront = dIdx == doorXs.length - 1;
      // Door gap on bottom wall
      canvas.drawLine(
        Offset(dx - 11, bodyRect.bottom),
        Offset(dx + 11, bodyRect.bottom),
        Paint()
          ..color = isDark ? const Color(0xFF38BDF8) : const Color(0xFFDDD6C8)
          ..strokeWidth = 3.2,
      );
      // Blue 3D sensor box above doors (S1 / S2)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(dx, bodyRect.bottom - 4.5),
            width: 15,
            height: 5,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = _sensorBlue,
      );

      // Flash trapezoid sensor beam when particle crosses this door
      if (isAnimating && animValue < 0.65) {
        final matching = particles.any((p) => p.frontDoor == isFront);
        if (matching) {
          final beamAlpha = (0.55 * (1.0 - (animValue / 0.65))).clamp(0.0, 0.55);
          final beamPath = Path()
            ..moveTo(dx - 4, bodyRect.bottom - 3)
            ..lineTo(dx + 4, bodyRect.bottom - 3)
            ..lineTo(dx + 13, bodyRect.bottom + 8)
            ..lineTo(dx - 13, bodyRect.bottom + 8)
            ..close();
          canvas.drawPath(
            beamPath,
            Paint()
              ..color = (lastDelta > 0 ? _sensorBlue : _sensorOut)
                  .withValues(alpha: beamAlpha),
          );
        }
      }
    }

    // Individual seats: green (#2E9E57) free, red (#D64545) occupied with dark dot
    final seatCols = switch (vehicleClass) {
      MarpromVehicleClass.midibus9m => 8,
      MarpromVehicleClass.solo12m => 12,
      MarpromVehicleClass.articulated18m => 16,
    };
    final passengerAreaLeft = bodyRect.left + 8;
    final passengerAreaRight = cabLeft - 8;
    final areaWidth = math.max(24.0, passengerAreaRight - passengerAreaLeft);
    final colStep = areaWidth / seatCols;
    final seatW = math.max(6.0, colStep * 0.64);
    final seatH = math.max(7.0, bodyRect.height * 0.21);

    final totalSeatsVisual = seatCols * 2 - (hasWheelchairSpace ? 2 : 0);
    final seatRatio = seatedCapacity > 0
        ? (seatedCount / seatedCapacity).clamp(0.0, 1.0)
        : 0.0;
    final filledSeats = (totalSeatsVisual * seatRatio).round();

    var seatIdx = 0;
    for (var col = 0; col < seatCols; col++) {
      final x = passengerAreaLeft + col * colStep + (colStep - seatW) / 2;

      // Top bank seat
      final topTaken = seatIdx < filledSeats;
      _drawP8Seat(
        canvas,
        Rect.fromLTWH(x, bodyRect.top + 5, seatW, seatH),
        taken: topTaken,
      );
      seatIdx++;

      // Bottom bank seat (skip middle bay for wheelchair space)
      final wcCenterCol = (seatCols * 0.44).round();
      if (hasWheelchairSpace &&
          (col == wcCenterCol || col == wcCenterCol + 1)) {
        if (col == wcCenterCol) {
          final bayRect = Rect.fromLTWH(
            x,
            bodyRect.bottom - seatH - 6,
            colStep * 1.7,
            seatH,
          );
          _drawDashedRect(
            canvas,
            bayRect,
            color: const Color(0xFF0284C7).withValues(alpha: 0.65),
          );
        }
      } else {
        final bottomTaken = seatIdx < filledSeats;
        _drawP8Seat(
          canvas,
          Rect.fromLTWH(x, bodyRect.bottom - seatH - 6, seatW, seatH),
          taken: bottomTaken,
        );
        seatIdx++;
      }
    }

    // Standing passenger silhouettes along the aisle (#16212E dots)
    final aisleSlots = switch (vehicleClass) {
      MarpromVehicleClass.midibus9m => 9,
      MarpromVehicleClass.solo12m => 15,
      MarpromVehicleClass.articulated18m => 22,
    };
    final standingRatio = standingCapacity > 0
        ? (standingCount / standingCapacity).clamp(0.0, 1.0)
        : 0.0;
    final filledStanding = (aisleSlots * standingRatio).round();
    final aisleStep = areaWidth / aisleSlots;
    final dotR = math.min(3.5, bodyRect.height * 0.068);

    for (var i = 0; i < filledStanding; i++) {
      final cx = passengerAreaLeft + (i + 0.5) * aisleStep;
      final cy = bodyRect.center.dy + (i.isEven ? -2.5 : 2.5);
      canvas.drawCircle(
        Offset(cx, cy),
        dotR + 1.0,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        dotR,
        Paint()..color = isDark ? const Color(0xFFF8FAFC) : _inkDark,
      );
    }

    // Animated boarding/alighting passenger dots walking through doors S1/S2
    if (isAnimating && animValue > 0 && animValue < 1.0) {
      for (final p in particles) {
        final doorX = p.frontDoor ? doorXs.last : doorXs.first;
        final curbY = bodyRect.bottom + 8.0;
        final aisleY = bodyRect.center.dy;
        final seatX = passengerAreaLeft + p.targetXFraction * areaWidth;
        final seatY = p.targetIsTop
            ? bodyRect.top + 5 + seatH / 2
            : bodyRect.bottom - seatH / 2 - 6;

        final t = p.inbound ? animValue : (1.0 - animValue);
        final Offset pos;
        if (t < 0.35) {
          final k = t / 0.35;
          pos = Offset(doorX, curbY + (aisleY - curbY) * k);
        } else if (t < 0.78) {
          final k = (t - 0.35) / 0.43;
          pos = Offset(doorX + (seatX - doorX) * k, aisleY);
        } else {
          final k = (t - 0.78) / 0.22;
          pos = Offset(seatX, aisleY + (seatY - aisleY) * k);
        }

        canvas.drawCircle(
          pos,
          4.2,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          pos,
          3.1,
          Paint()..color = p.inbound ? _sensorBlue : _sensorOut,
        );
      }
    }
  }

  void _drawP8Seat(Canvas canvas, Rect rect, {required bool taken}) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(
      rrect,
      Paint()..color = taken ? _seatTaken : _seatFree,
    );
    if (taken) {
      canvas.drawCircle(
        rect.center,
        math.min(rect.width, rect.height) * 0.28,
        Paint()..color = _inkDark,
      );
    }
  }

  void _drawDashedRect(
    Canvas canvas,
    Rect rect, {
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    const dash = 4.0;
    const gap = 3.0;
    for (var x = rect.left; x < rect.right; x += dash + gap) {
      final end = math.min(x + dash, rect.right);
      canvas.drawLine(Offset(x, rect.top), Offset(end, rect.top), paint);
      canvas.drawLine(Offset(x, rect.bottom), Offset(end, rect.bottom), paint);
    }
    for (var y = rect.top; y < rect.bottom; y += dash + gap) {
      final end = math.min(y + dash, rect.bottom);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.left, end), paint);
      canvas.drawLine(Offset(rect.right, y), Offset(rect.right, end), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _P8BusCutawayPainter oldDelegate) {
    return oldDelegate.seatedCount != seatedCount ||
        oldDelegate.standingCount != standingCount ||
        oldDelegate.vehicleClass != vehicleClass ||
        oldDelegate.isDark != isDark ||
        oldDelegate.animValue != animValue ||
        oldDelegate.isAnimating != isAnimating;
  }
}
