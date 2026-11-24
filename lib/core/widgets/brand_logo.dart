// M Mobilnost logo: a bus route drawn as an "M", with stops and a
// destination pin, on the brand red gradient.
//
// The same painter renders the in-app emblem and (via tool/export_icons_test.dart)
// every launcher / web / iOS icon, so the mark stays identical everywhere.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How the logo background is drawn.
enum LogoBackground {
  /// No background: only the white route mark (for adaptive foregrounds).
  none,

  /// Full-bleed square of the brand gradient.
  square,

  /// Gradient in a rounded square (app emblem, legacy launcher icon).
  rounded,

  /// Gradient in a circle (round launcher icon).
  circle,
}

/// Paints the M Mobilnost logo into any square canvas.
class MarpromLogoPainter extends CustomPainter {
  /// Creates the logo painter.
  const MarpromLogoPainter({
    this.background = LogoBackground.rounded,
    this.markScale = 1.0,
    this.monochrome = false,
  });

  /// Background treatment.
  final LogoBackground background;

  /// Scale of the white mark relative to the canvas (1.0 = default framing).
  final double markScale;

  /// Draw the mark as a single flat colour (Android themed icons).
  final bool monochrome;

  static const Color _red = Color(0xFFC8102E);
  static const Color _redBright = Color(0xFFEA2846);
  static const Color _wine = Color(0xFF6E0A19);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size(s, s);

    // ---- Background -------------------------------------------------------
    if (background != LogoBackground.none) {
      final clip = Path();
      switch (background) {
        case LogoBackground.square:
          clip.addRect(rect);
        case LogoBackground.rounded:
          clip.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * 0.27)));
        case LogoBackground.circle:
          clip.addOval(rect);
        case LogoBackground.none:
          break;
      }
      canvas.save();
      canvas.clipPath(clip);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_redBright, _red, _wine],
            stops: [0.0, 0.5, 1.0],
          ).createShader(rect),
      );
      // Soft light from the top-left gives the tile some depth.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.7, -0.8),
            radius: 0.9,
            colors: [
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(rect),
      );
      canvas.restore();
    }

    // ---- Mark -------------------------------------------------------------
    if (markScale <= 0) return; // background-only layer
    // Work in a unit box centred on the canvas.
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.scale(s * markScale);
    // Optical centring: the pin adds weight on the right and top.
    canvas.translate(-0.5 - 0.035, -0.5 - 0.025);

    const white = Colors.white;
    final ink = monochrome ? white : white;
    final stopCore = monochrome ? Colors.transparent : _red;

    // Route "M": stops at the feet and the middle valley, peaks between.
    const p1 = Offset(0.20, 0.72);
    const p2 = Offset(0.32, 0.31);
    const p3 = Offset(0.50, 0.57);
    const p4 = Offset(0.68, 0.31);
    const p5 = Offset(0.80, 0.72);
    const stroke = 0.088;

    // The last leg stops inside the pin body, so the pin reads as the end of
    // the route without a line cap peeking out under its tip.
    final routeEnd = Offset.lerp(p4, p5, 0.58)!;
    final route = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..lineTo(routeEnd.dx, routeEnd.dy);

    // Subtle shadow under the mark (skipped for monochrome / no background).
    if (!monochrome && background != LogoBackground.none) {
      canvas.drawPath(
        route.shift(const Offset(0, 0.018)),
        Paint()
          ..color = _wine.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.012),
      );
    }

    canvas.drawPath(
      route,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Stops: white discs with a red core, like on a line diagram.
    void stop(Offset c) {
      canvas.drawCircle(c, 0.072, Paint()..color = ink);
      if (monochrome) {
        canvas.drawCircle(
          c,
          0.032,
          Paint()..blendMode = BlendMode.clear,
        );
      } else {
        canvas.drawCircle(c, 0.034, Paint()..color = stopCore);
      }
    }

    stop(p1);
    stop(p3);

    // Destination pin standing on the last stop.
    _drawPin(canvas, tip: p5, ink: ink, monochrome: monochrome);

    canvas.restore();
  }

  void _drawPin(
    Canvas canvas, {
    required Offset tip,
    required Color ink,
    required bool monochrome,
  }) {
    const r = 0.105; // head radius
    final head = Offset(tip.dx, tip.dy - 0.205);
    // Teardrop: circle head + tangent lines to the tip.
    final d = (tip - head).distance;
    final theta = math.acos(r / d);
    final base = math.atan2(tip.dy - head.dy, tip.dx - head.dx);
    final a1 = base + theta;
    final a2 = base - theta;
    final t1 = head + Offset(math.cos(a1) * r, math.sin(a1) * r);
    // The arc below ends at the second tangent point by construction.

    final pin = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(t1.dx, t1.dy)
      ..arcTo(
        Rect.fromCircle(center: head, radius: r),
        a1,
        2 * math.pi - (a1 - a2),
        false,
      )
      ..lineTo(tip.dx, tip.dy)
      ..close();

    // Red outline separates the pin from the white route behind it.
    if (!monochrome) {
      canvas.drawPath(
        pin,
        Paint()
          ..color = _red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(pin, Paint()..color = ink);
    // Pin eye.
    if (monochrome) {
      canvas.drawCircle(head, 0.045, Paint()..blendMode = BlendMode.clear);
    } else {
      canvas.drawCircle(head, 0.045, Paint()..color = _red);
    }
  }

  @override
  bool shouldRepaint(covariant MarpromLogoPainter oldDelegate) =>
      oldDelegate.background != background ||
      oldDelegate.markScale != markScale ||
      oldDelegate.monochrome != monochrome;
}

/// The M Mobilnost logo as a widget.
class MarpromLogo extends StatelessWidget {
  /// Creates the logo at [size].
  const MarpromLogo({
    super.key,
    this.size = 40,
    this.background = LogoBackground.rounded,
  });

  /// Edge length.
  final double size;

  /// Background treatment.
  final LogoBackground background;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: MarpromLogoPainter(background: background),
      ),
    );
  }
}
