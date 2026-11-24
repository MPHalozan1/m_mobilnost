// Defines WCAG-compliant color palettes and status color extensions for M Mobilnost.

import 'package:flutter/material.dart';

/// Core brand and semantic color constants for Marprom M Mobilnost 2.0.
abstract final class MarpromColors {
  /// Authentic Marprom Maribor crimson red.
  static const Color marpromRed = Color(0xFFC8102E);

  /// Deep Marprom burgundy for headers, gradients, and active states.
  static const Color marpromBurgundy = Color(0xFF880D1E);

  /// Skupina JHMB dark slate charcoal for corporate strips, footers, and hero contrast.
  static const Color marpromCharcoal = Color(0xFF0F172A);

  /// Primary Marprom crimson, kept dark enough for WCAG AA contrast.
  static const Color transitBlue = marpromRed;

  /// Darker Marprom burgundy for containers and active states.
  static const Color transitBlueDark = marpromBurgundy;

  /// Lighter Marprom rose-coral for dark-mode surfaces.
  static const Color transitBlueLight = Color(0xFFFF8A9B);

  /// Secondary mobility green (WCAG AA on white: ~6.3:1).
  static const Color mobilityGreen = Color(0xFF0B6E4F);

  /// Lighter mobility green for dark mode.
  static const Color mobilityGreenLight = Color(0xFF5CE0B3);

  /// Brighter, slightly warmer red used for filled actions on dark surfaces.
  static const Color redOnDark = Color(0xFFE11D3F);

  /// Soft blush tint for selected states and quiet red containers.
  static const Color blush = Color(0xFFFCEBEE);

  /// Deepest wine tone, used only as the far end of hero gradients.
  static const Color wine = Color(0xFF5E0A17);

  /// Light mode background surface (warm, faintly neutral off-white).
  static const Color lightBackground = Color(0xFFF7F5F4);

  /// Light mode elevated card surface.
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Light mode primary text color (warm ink, not pure black).
  static const Color lightOnSurface = Color(0xFF1C1719);

  /// Light mode secondary text color (~7:1 on white).
  static const Color lightOnSurfaceVariant = Color(0xFF5B5457);

  /// Dark mode background surface (warm graphite).
  static const Color darkBackground = Color(0xFF121012);

  /// Dark mode card surface.
  static const Color darkSurface = Color(0xFF1C191B);

  /// Dark mode primary text color.
  static const Color darkOnSurface = Color(0xFFF4EFF0);

  /// Dark mode secondary text color.
  static const Color darkOnSurfaceVariant = Color(0xFFC9BFC2);

  /// High-contrast pure black canvas (WCAG AAA).
  static const Color hcBlack = Color(0xFF000000);

  /// High-contrast pure white foreground (21:1 on black).
  static const Color hcWhite = Color(0xFFFFFFFF);

  /// High-contrast transit yellow accent (14.7:1 on black).
  static const Color hcYellow = Color(0xFFFFD600);
}

/// Theme extension supplying semantic transit status and occupancy colors.
@immutable
class MarpromStatusColors extends ThemeExtension<MarpromStatusColors> {
  /// Creates a semantic status color bundle.
  const MarpromStatusColors({
    required this.earlyFg,
    required this.earlyBg,
    required this.onTimeFg,
    required this.onTimeBg,
    required this.lateFg,
    required this.lateBg,
    required this.infoFg,
    required this.infoBg,
    required this.warningFg,
    required this.warningBg,
    required this.disruptionFg,
    required this.disruptionBg,
    required this.occupancyLow,
    required this.occupancyMedium,
    required this.occupancyHigh,
    required this.occupancyFull,
    required this.highContrastBorders,
  });

  /// Light-theme semantic colors meeting WCAG AA (>= 4.5:1).
  static const MarpromStatusColors light = MarpromStatusColors(
    earlyFg: Color(0xFF075985),
    earlyBg: Color(0xFFE0F2FE),
    onTimeFg: Color(0xFF0B6E4F),
    onTimeBg: Color(0xFFDCFCE7),
    lateFg: Color(0xFF9A3412),
    lateBg: Color(0xFFFFEDD5),
    infoFg: Color(0xFF1E40AF),
    infoBg: Color(0xFFDBEAFE),
    warningFg: Color(0xFF78350F),
    warningBg: Color(0xFFFEF3C7),
    disruptionFg: Color(0xFF991B1B),
    disruptionBg: Color(0xFFFEE2E2),
    occupancyLow: Color(0xFF0B6E4F),
    occupancyMedium: Color(0xFF92400E),
    occupancyHigh: Color(0xFFC2410C),
    occupancyFull: Color(0xFF991B1B),
    highContrastBorders: false,
  );

  /// Dark-theme semantic colors meeting WCAG AA (>= 4.5:1).
  static const MarpromStatusColors dark = MarpromStatusColors(
    earlyFg: Color(0xFF7DD3FC),
    earlyBg: Color(0xFF0C2D48),
    onTimeFg: Color(0xFF6EE7B7),
    onTimeBg: Color(0xFF063325),
    lateFg: Color(0xFFFDBA74),
    lateBg: Color(0xFF431A07),
    infoFg: Color(0xFF93C5FD),
    infoBg: Color(0xFF172554),
    warningFg: Color(0xFFFCD34D),
    warningBg: Color(0xFF3D2306),
    disruptionFg: Color(0xFFFCA5A5),
    disruptionBg: Color(0xFF450A0A),
    occupancyLow: Color(0xFF6EE7B7),
    occupancyMedium: Color(0xFFFCD34D),
    occupancyHigh: Color(0xFFFDBA74),
    occupancyFull: Color(0xFFFCA5A5),
    highContrastBorders: false,
  );

  /// High-contrast semantic colors meeting WCAG AAA (>= 7:1).
  static const MarpromStatusColors highContrast = MarpromStatusColors(
    earlyFg: Color(0xFF80D8FF),
    earlyBg: Color(0xFF000000),
    onTimeFg: Color(0xFF69F0AE),
    onTimeBg: Color(0xFF000000),
    lateFg: Color(0xFFFFD600),
    lateBg: Color(0xFF000000),
    infoFg: Color(0xFFFFFFFF),
    infoBg: Color(0xFF000000),
    warningFg: Color(0xFFFFD600),
    warningBg: Color(0xFF000000),
    disruptionFg: Color(0xFFFF8A8A),
    disruptionBg: Color(0xFF000000),
    occupancyLow: Color(0xFF69F0AE),
    occupancyMedium: Color(0xFFFFD600),
    occupancyHigh: Color(0xFFFFAB40),
    occupancyFull: Color(0xFFFF8A8A),
    highContrastBorders: true,
  );

  /// Foreground color for early arrival indicators.
  final Color earlyFg;

  /// Background color for early arrival indicators.
  final Color earlyBg;

  /// Foreground color for on-time indicators.
  final Color onTimeFg;

  /// Background color for on-time indicators.
  final Color onTimeBg;

  /// Foreground color for delayed indicators.
  final Color lateFg;

  /// Background color for delayed indicators.
  final Color lateBg;

  /// Foreground color for informational chips.
  final Color infoFg;

  /// Background color for informational chips.
  final Color infoBg;

  /// Foreground color for warning chips.
  final Color warningFg;

  /// Background color for warning chips.
  final Color warningBg;

  /// Foreground color for disruption/alert chips.
  final Color disruptionFg;

  /// Background color for disruption/alert chips.
  final Color disruptionBg;

  /// Fill color for low bus occupancy.
  final Color occupancyLow;

  /// Fill color for medium bus occupancy.
  final Color occupancyMedium;

  /// Fill color for high bus occupancy.
  final Color occupancyHigh;

  /// Fill color for full bus occupancy.
  final Color occupancyFull;

  /// Whether cards and chips should draw crisp high-contrast borders.
  final bool highContrastBorders;

  @override
  MarpromStatusColors copyWith({
    Color? earlyFg,
    Color? earlyBg,
    Color? onTimeFg,
    Color? onTimeBg,
    Color? lateFg,
    Color? lateBg,
    Color? infoFg,
    Color? infoBg,
    Color? warningFg,
    Color? warningBg,
    Color? disruptionFg,
    Color? disruptionBg,
    Color? occupancyLow,
    Color? occupancyMedium,
    Color? occupancyHigh,
    Color? occupancyFull,
    bool? highContrastBorders,
  }) {
    return MarpromStatusColors(
      earlyFg: earlyFg ?? this.earlyFg,
      earlyBg: earlyBg ?? this.earlyBg,
      onTimeFg: onTimeFg ?? this.onTimeFg,
      onTimeBg: onTimeBg ?? this.onTimeBg,
      lateFg: lateFg ?? this.lateFg,
      lateBg: lateBg ?? this.lateBg,
      infoFg: infoFg ?? this.infoFg,
      infoBg: infoBg ?? this.infoBg,
      warningFg: warningFg ?? this.warningFg,
      warningBg: warningBg ?? this.warningBg,
      disruptionFg: disruptionFg ?? this.disruptionFg,
      disruptionBg: disruptionBg ?? this.disruptionBg,
      occupancyLow: occupancyLow ?? this.occupancyLow,
      occupancyMedium: occupancyMedium ?? this.occupancyMedium,
      occupancyHigh: occupancyHigh ?? this.occupancyHigh,
      occupancyFull: occupancyFull ?? this.occupancyFull,
      highContrastBorders: highContrastBorders ?? this.highContrastBorders,
    );
  }

  @override
  MarpromStatusColors lerp(ThemeExtension<MarpromStatusColors>? other, double t) {
    if (other is! MarpromStatusColors) return this;
    return MarpromStatusColors(
      earlyFg: Color.lerp(earlyFg, other.earlyFg, t)!,
      earlyBg: Color.lerp(earlyBg, other.earlyBg, t)!,
      onTimeFg: Color.lerp(onTimeFg, other.onTimeFg, t)!,
      onTimeBg: Color.lerp(onTimeBg, other.onTimeBg, t)!,
      lateFg: Color.lerp(lateFg, other.lateFg, t)!,
      lateBg: Color.lerp(lateBg, other.lateBg, t)!,
      infoFg: Color.lerp(infoFg, other.infoFg, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      disruptionFg: Color.lerp(disruptionFg, other.disruptionFg, t)!,
      disruptionBg: Color.lerp(disruptionBg, other.disruptionBg, t)!,
      occupancyLow: Color.lerp(occupancyLow, other.occupancyLow, t)!,
      occupancyMedium: Color.lerp(occupancyMedium, other.occupancyMedium, t)!,
      occupancyHigh: Color.lerp(occupancyHigh, other.occupancyHigh, t)!,
      occupancyFull: Color.lerp(occupancyFull, other.occupancyFull, t)!,
      highContrastBorders: t < 0.5 ? highContrastBorders : other.highContrastBorders,
    );
  }
}
