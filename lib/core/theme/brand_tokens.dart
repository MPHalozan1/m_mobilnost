// Brand-level design tokens (gradients, shadows, radii) shared across screens.

import 'package:flutter/material.dart';

import 'colors.dart';

/// Shared corner radii so every surface in the app speaks the same shape language.
abstract final class MarpromRadii {
  /// Small chips and badges.
  static const double sm = 10;

  /// Buttons, inputs, list tiles.
  static const double md = 16;

  /// Cards and tiles.
  static const double lg = 22;

  /// Hero cards and sheets.
  static const double xl = 28;
}

/// Theme extension carrying brand gradients and elevation shadows.
@immutable
class MarpromBrand extends ThemeExtension<MarpromBrand> {
  /// Creates a brand token bundle.
  const MarpromBrand({
    required this.heroGradient,
    required this.onHero,
    required this.onHeroMuted,
    required this.cardShadow,
    required this.raisedShadow,
    required this.subtleFill,
    required this.hairline,
  });

  /// Light theme tokens.
  static const MarpromBrand light = MarpromBrand(
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD3173A), MarpromColors.marpromRed, Color(0xFF8E0C20)],
      stops: [0.0, 0.45, 1.0],
    ),
    onHero: Colors.white,
    onHeroMuted: Color(0xE6FFFFFF),
    cardShadow: [
      BoxShadow(
        color: Color(0x0F1C1719),
        blurRadius: 18,
        offset: Offset(0, 6),
      ),
      BoxShadow(
        color: Color(0x0A1C1719),
        blurRadius: 3,
        offset: Offset(0, 1),
      ),
    ],
    raisedShadow: [
      BoxShadow(
        color: Color(0x40A50E26),
        blurRadius: 28,
        offset: Offset(0, 12),
        spreadRadius: -6,
      ),
    ],
    subtleFill: Color(0xFFF2EEEF),
    hairline: Color(0xFFEAE4E5),
  );

  /// Dark theme tokens.
  static const MarpromBrand dark = MarpromBrand(
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFC8183A), Color(0xFF9E0F27), MarpromColors.wine],
      stops: [0.0, 0.5, 1.0],
    ),
    onHero: Colors.white,
    onHeroMuted: Color(0xE6FFFFFF),
    cardShadow: [
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 16,
        offset: Offset(0, 6),
      ),
    ],
    raisedShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 28,
        offset: Offset(0, 12),
        spreadRadius: -6,
      ),
    ],
    subtleFill: Color(0xFF262224),
    hairline: Color(0xFF2E2A2C),
  );

  /// High-contrast tokens: flat black with white outlines, no gradients.
  static const MarpromBrand highContrast = MarpromBrand(
    heroGradient: LinearGradient(
      colors: [MarpromColors.hcBlack, MarpromColors.hcBlack],
    ),
    onHero: MarpromColors.hcWhite,
    onHeroMuted: MarpromColors.hcWhite,
    cardShadow: [],
    raisedShadow: [],
    subtleFill: Color(0xFF1A1A1A),
    hairline: MarpromColors.hcWhite,
  );

  /// Returns the active brand tokens, falling back to the light set.
  static MarpromBrand of(BuildContext context) =>
      Theme.of(context).extension<MarpromBrand>() ?? light;

  /// Signature red gradient for hero surfaces.
  final Gradient heroGradient;

  /// Foreground on hero surfaces.
  final Color onHero;

  /// Secondary foreground on hero surfaces.
  final Color onHeroMuted;

  /// Resting card shadow.
  final List<BoxShadow> cardShadow;

  /// Shadow for the single most important raised element on a screen.
  final List<BoxShadow> raisedShadow;

  /// Quiet neutral fill for icon wells and inactive tracks.
  final Color subtleFill;

  /// Very light divider/border tone.
  final Color hairline;

  @override
  MarpromBrand copyWith({
    Gradient? heroGradient,
    Color? onHero,
    Color? onHeroMuted,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? raisedShadow,
    Color? subtleFill,
    Color? hairline,
  }) {
    return MarpromBrand(
      heroGradient: heroGradient ?? this.heroGradient,
      onHero: onHero ?? this.onHero,
      onHeroMuted: onHeroMuted ?? this.onHeroMuted,
      cardShadow: cardShadow ?? this.cardShadow,
      raisedShadow: raisedShadow ?? this.raisedShadow,
      subtleFill: subtleFill ?? this.subtleFill,
      hairline: hairline ?? this.hairline,
    );
  }

  @override
  MarpromBrand lerp(ThemeExtension<MarpromBrand>? other, double t) {
    if (other is! MarpromBrand) return this;
    return MarpromBrand(
      heroGradient: Gradient.lerp(heroGradient, other.heroGradient, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      onHeroMuted: Color.lerp(onHeroMuted, other.onHeroMuted, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
      raisedShadow: BoxShadow.lerpList(raisedShadow, other.raisedShadow, t)!,
      subtleFill: Color.lerp(subtleFill, other.subtleFill, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
    );
  }
}
