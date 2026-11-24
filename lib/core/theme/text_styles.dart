// Defines the accessible typographic scale for M Mobilnost 2.0.

import 'package:flutter/material.dart';

/// Builds a readable, confident typographic scale tuned for transit legibility.
///
/// Headings use heavier weights with slightly tightened tracking so they read
/// as a modern product, while body copy keeps generous line height.
abstract final class MarpromTextStyles {
  /// Bundled brand typeface (Plus Jakarta Sans, SIL OFL 1.1).
  static const String fontFamily = 'PlusJakartaSans';

  /// Returns a [TextTheme] tuned for transit legibility in the given [foreground].
  static TextTheme buildTextTheme(Color foreground, Color secondary) {
    return TextTheme(
      displayMedium: TextStyle(
        fontSize: 40,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: foreground,
      ),
      displaySmall: TextStyle(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: foreground,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: foreground,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: foreground,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: foreground,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.35,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        color: foreground,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: foreground,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: foreground,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: secondary,
      ),
    );
  }
}
