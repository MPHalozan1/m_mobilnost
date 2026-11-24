// Accessible large-target button (>= 56x56dp) pairing icon and visible text.

import 'package:flutter/material.dart';

import '../theme/brand_tokens.dart';
import '../theme/colors.dart';
import 'motion.dart';

/// Visual emphasis variants for [BigButton].
enum BigButtonVariant {
  /// High-emphasis filled primary call to action.
  primary,

  /// Medium-emphasis tonal surface action.
  secondary,

  /// High-clarity bordered outline action.
  outlined,

  /// The chosen option in a group of toggles: soft red tint with a red ring,
  /// so a selected state never competes with the screen's primary action.
  selected,
}

/// Large accessible button (>= 56x56dp) displaying both an icon and text label.
class BigButton extends StatelessWidget {
  /// Creates a [BigButton] that enforces icon+text pairing and >= 56dp sizing.
  const BigButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.variant = BigButtonVariant.primary,
    this.expanded = false,
    this.loading = false,
    this.semanticLabel,
  });

  /// Leading icon paired with [label].
  final IconData icon;

  /// Visible localized button label.
  final String label;

  /// Tap callback; null disables the button.
  final VoidCallback? onPressed;

  /// Visual variant of the button.
  final BigButtonVariant variant;

  /// Whether the button expands horizontally to fill available width.
  final bool expanded;

  /// Shows a compact loading spinner while preserving button layout.
  final bool loading;

  /// Optional screen-reader override label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isHighContrast =
        theme.extension<MarpromStatusColors>()?.highContrastBorders ?? false;
    // Primary actions are always a true brand red with white text (except in
    // high-contrast mode, which keeps its own yellow-on-black palette).
    final Color? primaryBg = isHighContrast
        ? null
        : scheme.brightness == Brightness.dark
            ? MarpromColors.redOnDark
            : MarpromColors.marpromRed;
    final Color? primaryFg = isHighContrast ? null : Colors.white;
    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: variant == BigButtonVariant.primary
                  ? (primaryFg ?? scheme.onPrimary)
                  : scheme.primary,
            ),
          )
        else
          Icon(icon, size: 21),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    final minSize = Size(expanded ? double.infinity : 56, 56);
    const padding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MarpromRadii.md),
    );

    final Widget button;
    switch (variant) {
      case BigButtonVariant.primary:
        button = FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: primaryBg,
            foregroundColor: primaryFg,
            minimumSize: minSize,
            padding: padding,
            shape: shape,
          ),
          child: content,
        );
      case BigButtonVariant.secondary:
        button = FilledButton.tonal(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            minimumSize: minSize,
            padding: padding,
            shape: shape,
          ),
          child: content,
        );
      case BigButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: minSize,
            padding: padding,
            shape: shape,
          ),
          child: content,
        );
      case BigButtonVariant.selected:
        button = OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: minSize,
            padding: padding,
            shape: shape,
            backgroundColor:
                isHighContrast ? scheme.primary : scheme.primaryContainer,
            foregroundColor:
                isHighContrast ? scheme.onPrimary : scheme.onPrimaryContainer,
            side: BorderSide(color: scheme.primary, width: 1.6),
          ),
          child: content,
        );
    }

    return Semantics(
      button: true,
      selected: variant == BigButtonVariant.selected ? true : null,
      enabled: onPressed != null && !loading,
      label: semanticLabel ?? label,
      child: PressableScale(child: button),
    );
  }
}
