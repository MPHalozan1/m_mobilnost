// Builds WCAG AA light and dark Material 3 themes for M Mobilnost 2.0.
//
// Design intent: red is the brand signal, not the canvas. Surfaces stay warm
// neutral; red is reserved for primary actions, the selected navigation state,
// and one hero surface per screen. Everything else uses ink and soft greys.

import 'package:flutter/material.dart';

import 'brand_tokens.dart';
import 'colors.dart';
import 'text_styles.dart';

/// Provides WCAG AA compliant light and dark [ThemeData] configurations.
abstract final class AppTheme {
  /// Builds the standard Marprom light theme.
  static ThemeData light({bool reducedMotion = false}) {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: MarpromColors.marpromRed,
      onPrimary: Colors.white,
      primaryContainer: MarpromColors.blush,
      onPrimaryContainer: Color(0xFF7A0A1B),
      secondary: MarpromColors.mobilityGreen,
      onSecondary: Colors.white,
      // Tonal buttons and quiet containers stay neutral so red never floods.
      secondaryContainer: Color(0xFFF1ECED),
      onSecondaryContainer: MarpromColors.lightOnSurface,
      tertiary: Color(0xFF0369A1),
      onTertiary: Colors.white,
      error: Color(0xFFB42318),
      onError: Colors.white,
      errorContainer: Color(0xFFFEE4E2),
      onErrorContainer: Color(0xFF7A271A),
      surface: MarpromColors.lightSurface,
      onSurface: MarpromColors.lightOnSurface,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFBF9F9),
      surfaceContainer: Color(0xFFF5F2F2),
      surfaceContainerHigh: Color(0xFFF0ECEC),
      surfaceContainerHighest: Color(0xFFEAE5E6),
      onSurfaceVariant: MarpromColors.lightOnSurfaceVariant,
      outline: Color(0xFFCFC7C9),
      outlineVariant: Color(0xFFEAE4E5),
      inverseSurface: Color(0xFF2A2427),
      onInverseSurface: Color(0xFFF7F1F2),
      inversePrimary: MarpromColors.transitBlueLight,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    return _buildBaseTheme(
      scheme: scheme,
      scaffoldBg: MarpromColors.lightBackground,
      statusColors: MarpromStatusColors.light,
      brand: MarpromBrand.light,
      filledBg: MarpromColors.marpromRed,
      navIndicator: MarpromColors.blush,
      reducedMotion: reducedMotion,
    );
  }

  /// Builds the standard Marprom dark theme.
  static ThemeData dark({bool reducedMotion = false}) {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      // Rose accent is used for text/icons on dark surfaces (AA on #1C191B).
      primary: MarpromColors.transitBlueLight,
      onPrimary: Color(0xFF4A0410),
      primaryContainer: Color(0xFF3B1A21),
      onPrimaryContainer: Color(0xFFFFD9DF),
      secondary: MarpromColors.mobilityGreenLight,
      onSecondary: Color(0xFF033322),
      secondaryContainer: Color(0xFF2A2527),
      onSecondaryContainer: MarpromColors.darkOnSurface,
      tertiary: Color(0xFF7DD3FC),
      onTertiary: Color(0xFF082F49),
      error: Color(0xFFFDA29B),
      onError: Color(0xFF55160C),
      errorContainer: Color(0xFF7A271A),
      onErrorContainer: Color(0xFFFEE4E2),
      surface: MarpromColors.darkSurface,
      onSurface: MarpromColors.darkOnSurface,
      surfaceContainerLowest: Color(0xFF0D0B0C),
      surfaceContainerLow: Color(0xFF181517),
      surfaceContainer: Color(0xFF1F1B1D),
      surfaceContainerHigh: Color(0xFF262224),
      surfaceContainerHighest: Color(0xFF2E292B),
      onSurfaceVariant: MarpromColors.darkOnSurfaceVariant,
      outline: Color(0xFF5A5154),
      outlineVariant: Color(0xFF2E2A2C),
      inverseSurface: Color(0xFFF4EFF0),
      onInverseSurface: Color(0xFF1C191B),
      inversePrimary: MarpromColors.marpromRed,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    return _buildBaseTheme(
      scheme: scheme,
      scaffoldBg: MarpromColors.darkBackground,
      statusColors: MarpromStatusColors.dark,
      brand: MarpromBrand.dark,
      filledBg: MarpromColors.redOnDark,
      navIndicator: const Color(0xFF3B1A21),
      reducedMotion: reducedMotion,
    );
  }

  static ThemeData _buildBaseTheme({
    required ColorScheme scheme,
    required Color scaffoldBg,
    required MarpromStatusColors statusColors,
    required MarpromBrand brand,
    required Color filledBg,
    required Color navIndicator,
    required bool reducedMotion,
  }) {
    final textTheme = MarpromTextStyles.buildTextTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );
    final isDark = scheme.brightness == Brightness.dark;
    final typo = Typography.material2021();
    // Fully-resolved (inherit: false) styles so theme switches can animate.
    final t = typo.englishLike
        .merge(scheme.brightness == Brightness.dark ? typo.white : typo.black)
        .merge(textTheme)
        .apply(fontFamily: MarpromTextStyles.fontFamily);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MarpromRadii.md),
    );
    final buttonText = t.labelLarge!.copyWith(
      fontSize: 15.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: MarpromTextStyles.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
      textTheme: textTheme,
      extensions: [statusColors, brand],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      dividerColor: brand.hairline,
      pageTransitionsTheme: reducedMotion
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _NoMotionPageTransitionsBuilder(),
                TargetPlatform.iOS: _NoMotionPageTransitionsBuilder(),
                TargetPlatform.windows: _NoMotionPageTransitionsBuilder(),
                TargetPlatform.macOS: _NoMotionPageTransitionsBuilder(),
                TargetPlatform.linux: _NoMotionPageTransitionsBuilder(),
              },
            )
          : const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: SoftPageTransitionsBuilder(),
                TargetPlatform.iOS: SoftPageTransitionsBuilder(),
                TargetPlatform.windows: SoftPageTransitionsBuilder(),
                TargetPlatform.macOS: SoftPageTransitionsBuilder(),
                TargetPlatform.linux: SoftPageTransitionsBuilder(),
              },
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: t.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: isDark ? 0 : 1.5,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.lg),
          side: isDark
              ? BorderSide(color: brand.hairline)
              : BorderSide(color: brand.hairline.withValues(alpha: 0.6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(56, 54)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(buttonText),
          elevation: const WidgetStatePropertyAll(0),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.black.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: scheme.onSurface,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outline, width: 1.2),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: buttonText,
          minimumSize: const Size(48, 48),
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          shape: const CircleBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: filledBg,
        foregroundColor: Colors.white,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.md + 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: navIndicator,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12.5,
            letterSpacing: 0.1,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: navIndicator,
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: t.labelMedium!.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: t.labelMedium!.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        // Pill-style tabs: the selected tab sits on a soft rounded chip.
        labelColor: isDark ? scheme.onPrimaryContainer : scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: t.titleSmall!.copyWith(fontWeight: FontWeight.w800, fontSize: 14.5),
        unselectedLabelStyle:
            t.titleSmall!.copyWith(fontWeight: FontWeight.w600, fontSize: 14.5),
        indicator: ShapeDecoration(
          color: isDark ? navIndicator : scheme.surface,
          shape: const StadiumBorder(),
          shadows: isDark ? null : brand.cardShadow,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorAnimation: TabIndicatorAnimation.elastic,
        dividerHeight: 0,
        dividerColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: navIndicator,
        checkmarkColor: scheme.primary,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.sm + 2),
        ),
        labelStyle: t.labelLarge!.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outline.withValues(alpha: 0.8)),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? navIndicator
                : Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? (isDark ? scheme.onPrimaryContainer : scheme.onPrimaryContainer)
                : scheme.onSurface;
          }),
          textStyle: WidgetStatePropertyAll(
            t.labelLarge!.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? const Color(0xFF9A8F92) : const Color(0xFF8A8184);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return filledBg;
          return brand.subtleFill;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return scheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return filledBg;
          return Colors.transparent;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.onSurfaceVariant;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: filledBg,
        thumbColor: filledBg,
        inactiveTrackColor: brand.subtleFill,
        overlayColor: filledBg.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: brand.subtleFill,
        circularTrackColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: t.titleSmall,
        subtitleTextStyle: t.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.md),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.md),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.md),
        ),
        iconColor: scheme.primary,
      ),
      dividerTheme: DividerThemeData(
        color: brand.hairline,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.xl),
        ),
        titleTextStyle: t.titleLarge,
        contentTextStyle: t.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MarpromRadii.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: t.bodyMedium!.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: isDark ? MarpromColors.marpromRed : scheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.md),
        ),
        elevation: 3,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(MarpromRadii.sm),
        ),
        textStyle: t.bodyMedium!.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.md),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.md),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
    );
  }
}

/// Calm page transition: a short fade with a slight upward drift.
///
/// Deliberately small (16px, 280ms) so navigation feels smooth without
/// drawing attention to itself.
class SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Creates the soft fade-through page transition builder.
  const SoftPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.92).animate(outgoing),
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

class _NoMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoMotionPageTransitionsBuilder();

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
