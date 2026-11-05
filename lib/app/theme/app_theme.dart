/// Material 3 theme: dark by default, light optional, violet-blue accent.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens. Kept in one place so screens never hard-code colours.
class AppColors {
  const AppColors._();

  static const Color violet = Color(0xFF7C5CFF);
  static const Color violetDeep = Color(0xFF5B3FD1);
  static const Color blue = Color(0xFF3D8BFF);
  static const Color mint = Color(0xFF35D6A4);
  static const Color amber = Color(0xFFFFB454);
  static const Color danger = Color(0xFFFF5A6E);

  static const Color darkBg = Color(0xFF0B0B12);
  static const Color darkSurface = Color(0xFF14141F);
  static const Color darkSurfaceHigh = Color(0xFF1D1D2B);
  static const Color darkOutline = Color(0xFF2C2C3D);

  static const Color lightBg = Color(0xFFF7F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOutline = Color(0xFFE2E2EC);

  /// Accent gradient used by the logo and primary actions.
  static const LinearGradient accentGradient = LinearGradient(
    colors: <Color>[violet, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  const AppTheme._();

  static const String fontFamily = 'Vazirmatn';

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.violet : AppColors.violetDeep,
      secondary: AppColors.blue,
      tertiary: AppColors.mint,
      error: AppColors.danger,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      outline: isDark ? AppColors.darkOutline : AppColors.lightOutline,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBg : AppColors.lightBg,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: isDark ? Colors.white : const Color(0xFF14141F),
        displayColor: isDark ? Colors.white : const Color(0xFF14141F),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurfaceHigh : AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
              fontFamily: fontFamily, fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outline),
        ),
        labelStyle: const TextStyle(fontFamily: fontFamily, fontSize: 13),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 4,
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
        inactiveTrackColor: scheme.outline.withValues(alpha: 0.5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? AppColors.darkSurfaceHigh : const Color(0xFF23232F),
        contentTextStyle: const TextStyle(
            fontFamily: fontFamily, color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurfaceHigh : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        showDragHandle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          const TextStyle(fontFamily: fontFamily, fontSize: 12),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outline.withValues(alpha: 0.4),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Spacing scale (4-based).
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  /// Standard page padding, responsive to width.
  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final horizontal = w >= 1200
        ? 48.0
        : w >= 840
            ? 32.0
            : 16.0;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: s16);
  }

  /// Maximum content width so the app looks right on tablets too.
  static const double maxContentWidth = 900;
}
