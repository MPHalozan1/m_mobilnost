// Builds the WCAG AAA (>= 7:1) black/white/yellow high-contrast theme.

import 'package:flutter/material.dart';

import 'brand_tokens.dart';
import 'colors.dart';
import 'text_styles.dart';

/// Provides a WCAG AAA high-contrast [ThemeData] using black, white, and yellow.
abstract final class HighContrastTheme {
  /// Builds the black/white/yellow high-contrast theme.
  static ThemeData build({bool reducedMotion = false}) {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: MarpromColors.hcYellow,
      onPrimary: MarpromColors.hcBlack,
      primaryContainer: MarpromColors.hcYellow,
      onPrimaryContainer: MarpromColors.hcBlack,
      secondary: MarpromColors.hcWhite,
      onSecondary: MarpromColors.hcBlack,
      secondaryContainer: Color(0xFF1F1F1F),
      onSecondaryContainer: MarpromColors.hcWhite,
      tertiary: Color(0xFF80D8FF),
      onTertiary: MarpromColors.hcBlack,
      error: Color(0xFFFF8A8A),
      onError: MarpromColors.hcBlack,
      errorContainer: Color(0xFF330000),
      onErrorContainer: Color(0xFFFFB3B3),
      surface: MarpromColors.hcBlack,
      onSurface: MarpromColors.hcWhite,
      surfaceContainerHighest: Color(0xFF1A1A1A),
      onSurfaceVariant: MarpromColors.hcWhite,
      outline: MarpromColors.hcWhite,
      outlineVariant: MarpromColors.hcYellow,
    );

    final textTheme = MarpromTextStyles.buildTextTheme(
      MarpromColors.hcWhite,
      MarpromColors.hcWhite,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: MarpromTextStyles.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: MarpromColors.hcBlack,
      textTheme: textTheme,
      extensions: const [
        MarpromStatusColors.highContrast,
        MarpromBrand.highContrast,
      ],
      focusColor: MarpromColors.hcYellow.withValues(alpha: 0.35),
      pageTransitionsTheme: reducedMotion
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _InstantTransitionsBuilder(),
                TargetPlatform.iOS: _InstantTransitionsBuilder(),
                TargetPlatform.windows: _InstantTransitionsBuilder(),
                TargetPlatform.macOS: _InstantTransitionsBuilder(),
                TargetPlatform.linux: _InstantTransitionsBuilder(),
              },
            )
          : const PageTransitionsTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: MarpromColors.hcBlack,
        foregroundColor: MarpromColors.hcWhite,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: MarpromColors.hcYellow, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: MarpromColors.hcBlack,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MarpromColors.hcWhite, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MarpromColors.hcYellow,
          foregroundColor: MarpromColors.hcBlack,
          minimumSize: const Size(56, 56),
          side: const BorderSide(color: MarpromColors.hcWhite, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MarpromColors.hcYellow,
          minimumSize: const Size(56, 56),
          side: const BorderSide(color: MarpromColors.hcYellow, width: 2.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: MarpromColors.hcBlack,
        indicatorColor: MarpromColors.hcYellow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? MarpromColors.hcBlack : MarpromColors.hcWhite,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? MarpromColors.hcYellow : MarpromColors.hcWhite,
            fontWeight: FontWeight.w700,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MarpromColors.hcBlack,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MarpromColors.hcWhite, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MarpromColors.hcWhite, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MarpromColors.hcYellow, width: 3),
        ),
      ),
    );
  }
}

class _InstantTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
