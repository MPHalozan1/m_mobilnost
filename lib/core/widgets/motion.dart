// Small, restrained motion primitives used across the app.
//
// Every animation here is short (<= 450ms), plays once, and is skipped when the
// platform or the in-app "reduced motion" setting asks for no animation.

import 'package:flutter/material.dart';

/// Whether animations should be skipped for the current context.
bool motionDisabled(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fades and slightly lifts [child] into place once, after an optional [delay].
///
/// Use [FadeSlideIn.staggered] for lists so items arrive in a gentle cascade.
class FadeSlideIn extends StatefulWidget {
  /// Creates a one-shot entrance animation.
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = 14,
  });

  /// Convenience constructor that derives the delay from a list [index].
  factory FadeSlideIn.staggered({
    Key? key,
    required int index,
    required Widget child,
    Duration step = const Duration(milliseconds: 55),
    int maxSteps = 8,
  }) {
    final clamped = index.clamp(0, maxSteps);
    return FadeSlideIn(
      key: key,
      delay: step * clamped,
      child: child,
    );
  }

  /// Animated content.
  final Widget child;

  /// Wait before starting.
  final Duration delay;

  /// Animation length.
  final Duration duration;

  /// Vertical travel in logical pixels.
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionDisabled(context)) {
      _controller.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final t = _curve.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: child,
          ),
        );
      },
    );
  }
}

/// Gives [child] a subtle press-down scale (to [pressedScale]) while touched.
///
/// It does not consume taps; wrap an [InkWell]/button inside it.
class PressableScale extends StatefulWidget {
  /// Creates a press feedback wrapper.
  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.975,
  });

  /// Wrapped interactive content.
  final Widget child;

  /// Scale applied while a pointer is down.
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = motionDisabled(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !disabled ? widget.pressedScale : 1,
        duration: Duration(milliseconds: _down ? 90 : 180),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
