// Shared visual building blocks so every screen speaks the same design language.

import 'package:flutter/material.dart';

import '../theme/brand_tokens.dart';
import '../theme/colors.dart';
import 'motion.dart';

/// Whether the active theme is the WCAG AAA high-contrast theme.
bool isHighContrastTheme(BuildContext context) =>
    Theme.of(context).extension<MarpromStatusColors>()?.highContrastBorders ??
    false;

/// Large screen title with optional subtitle, leading eyebrow and trailing action.
class ScreenTitle extends StatelessWidget {
  /// Creates a screen title block.
  const ScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 12),
  });

  /// Main heading.
  final String title;

  /// Optional supporting line below the title.
  final String? subtitle;

  /// Optional small uppercase label above the title.
  final String? eyebrow;

  /// Optional trailing widget (usually a button).
  final Widget? trailing;

  /// Outer padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineMedium),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );

    return Padding(
      padding: padding,
      child: trailing == null
          ? Align(alignment: Alignment.centerLeft, child: titleBlock)
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [titleBlock, trailing!],
            ),
    );
  }
}

/// Section heading used between groups of content.
class SectionHeader extends StatelessWidget {
  /// Creates a section header.
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(left: 2, bottom: 12),
  });

  /// Heading text.
  final String title;

  /// Optional trailing widget.
  final Widget? trailing;

  /// Outer padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Rounded square holding an icon on a soft tinted background.
class IconWell extends StatelessWidget {
  /// Creates an icon well.
  const IconWell({
    super.key,
    required this.icon,
    this.size = 44,
    this.tinted = true,
    this.color,
    this.background,
  });

  /// Icon to show.
  final IconData icon;

  /// Square edge length.
  final double size;

  /// Red-tinted (true) or neutral (false) background.
  final bool tinted;

  /// Optional explicit icon colour.
  final Color? color;

  /// Optional explicit background colour.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = MarpromBrand.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ??
            (tinted ? scheme.primaryContainer : brand.subtleFill),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.5,
        color: color ?? (tinted ? scheme.primary : scheme.onSurface),
      ),
    );
  }
}

/// Surface card with the brand's soft shadow, ink ripple and press feedback.
class SurfaceCard extends StatelessWidget {
  /// Creates a surface card.
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.selected = false,
    this.radius = MarpromRadii.lg,
  });

  /// Card content.
  final Widget child;

  /// Optional tap handler.
  final VoidCallback? onTap;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Draws a red selection ring.
  final bool selected;

  /// Corner radius.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = MarpromBrand.of(context);
    final hc = isHighContrastTheme(context);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: hc ? const [] : brand.cardShadow,
      ),
      child: Material(
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: selected
              ? BorderSide(color: scheme.primary, width: 2)
              : hc
                  ? BorderSide(color: scheme.outline, width: 2)
                  : BorderSide(color: brand.hairline.withValues(alpha: 0.7)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return onTap == null ? card : PressableScale(child: card);
  }
}

/// Visual state of a [TicketPass].
enum TicketPassTone {
  /// Valid right now: brand red.
  active,

  /// Valid later: deep ink.
  upcoming,

  /// No longer valid: muted grey.
  expired,
}

/// A transit pass drawn like a real ticket: coloured header, perforated tear
/// line with side notches, and a light stub.
class TicketPass extends StatelessWidget {
  /// Creates a ticket pass.
  const TicketPass({
    super.key,
    required this.header,
    required this.stub,
    this.tone = TicketPassTone.active,
    this.onTap,
    this.selected = false,
  });

  /// Content on the coloured upper part (use white text).
  final Widget header;

  /// Content on the lower stub.
  final Widget stub;

  /// Colour treatment.
  final TicketPassTone tone;

  /// Optional tap handler.
  final VoidCallback? onTap;

  /// Draws a selection ring.
  final bool selected;

  /// Gradient for a [tone].
  static Gradient gradientFor(BuildContext context, TicketPassTone tone) {
    final brand = MarpromBrand.of(context);
    return switch (tone) {
      TicketPassTone.active => brand.heroGradient,
      TicketPassTone.upcoming => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A3236), Color(0xFF1E191B)],
        ),
      TicketPassTone.expired => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8D8588), Color(0xFF6E676A)],
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = MarpromBrand.of(context);
    final hc = isHighContrastTheme(context);
    const notch = 11.0;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: hc ? null : gradientFor(context, tone),
            color: hc ? scheme.surface : null,
          ),
          child: Stack(
            children: [
              if (!hc)
                Positioned(
                  right: -40,
                  top: -50,
                  child: IgnorePointer(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: hc ? scheme.onSurface : Colors.white),
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: hc ? scheme.onSurface : Colors.white,
                    ),
                    child: header,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Perforated tear line.
        SizedBox(
          height: notch * 2,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: scheme.surface),
              ),
              Positioned.fill(
                left: notch + 6,
                right: notch + 6,
                child: CustomPaint(
                  painter: _DashedLinePainter(
                    color: hc ? scheme.outline : brand.hairline,
                  ),
                ),
              ),
            ],
          ),
        ),
        ColoredBox(
          color: scheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: stub,
          ),
        ),
      ],
    );

    final shape = _TicketShapeBorder(
      radius: MarpromRadii.lg,
      notchRadius: notch,
      // The notch sits on the tear line: after the header. We cannot know the
      // header height up front, so the clipper measures it at paint time.
      side: selected
          ? BorderSide(color: scheme.primary, width: 2)
          : hc
              ? BorderSide(color: scheme.outline, width: 2)
              : BorderSide.none,
    );

    Widget pass = _NotchedTicketLayout(
      shape: shape,
      shadow: hc ? const [] : brand.cardShadow,
      onTap: onTap,
      child: body,
    );
    if (onTap != null) pass = PressableScale(child: pass);
    return pass;
  }
}

/// Lays out the ticket so the notch lines up with the tear line, whose offset
/// is measured from the header's rendered height.
class _NotchedTicketLayout extends StatefulWidget {
  const _NotchedTicketLayout({
    required this.shape,
    required this.shadow,
    required this.child,
    this.onTap,
  });

  final _TicketShapeBorder shape;
  final List<BoxShadow> shadow;
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_NotchedTicketLayout> createState() => _NotchedTicketLayoutState();
}

class _NotchedTicketLayoutState extends State<_NotchedTicketLayout> {
  final GlobalKey _columnKey = GlobalKey();
  double? _notchY;

  void _measure() {
    final ctx = _columnKey.currentContext;
    if (ctx == null) return;
    final column = ctx.findRenderObject();
    if (column is! RenderBox) return;
    // First child of the column is the header.
    RenderBox? header;
    column.visitChildren((child) {
      header ??= child as RenderBox;
    });
    final h = header?.size.height;
    if (h == null) return;
    final y = h + widget.shape.notchRadius;
    if (_notchY != y) setState(() => _notchY = y);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    final shape = widget.shape.copyWithNotchY(_notchY);
    final child = KeyedSubtree(key: _columnKey, child: widget.child);
    return DecoratedBox(
      decoration: ShapeDecoration(shape: shape, shadows: widget.shadow),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: widget.onTap, child: child),
      ),
    );
  }
}

class _TicketShapeBorder extends ShapeBorder {
  const _TicketShapeBorder({
    required this.radius,
    required this.notchRadius,
    this.notchY,
    this.side = BorderSide.none,
  });

  final double radius;
  final double notchRadius;
  final double? notchY;
  final BorderSide side;

  _TicketShapeBorder copyWithNotchY(double? y) => _TicketShapeBorder(
        radius: radius,
        notchRadius: notchRadius,
        notchY: y,
        side: side,
      );

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect rect) {
    final outer = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final y = notchY;
    if (y == null || y <= radius || y >= rect.height - radius) return outer;
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.left, rect.top + y),
          radius: notchRadius,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.right, rect.top + y),
          radius: notchRadius,
        ),
      );
    return Path.combine(PathOperation.difference, outer, cut);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side == BorderSide.none || side.width == 0) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => _TicketShapeBorder(
        radius: radius * t,
        notchRadius: notchRadius * t,
        notchY: notchY == null ? null : notchY! * t,
        side: side.scale(t),
      );
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const dash = 6.0;
    const gap = 5.0;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Compact key/value pair used inside cards and ticket stubs.
class InfoPair extends StatelessWidget {
  /// Creates an info pair.
  const InfoPair({
    super.key,
    required this.label,
    required this.value,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  /// Small caption.
  final String label;

  /// Emphasised value.
  final String value;

  /// Alignment of the two lines.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
