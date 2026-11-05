import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography is bundled (Vazirmatn, OFL): no runtime font download, and the
/// same family is used by the ASS exporter so preview and export match.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Vazirmatn';

  static TextTheme textTheme() {
    const TextTheme base = TextTheme(
      displaySmall: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.25),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.6),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.4),
    );
    return base.apply(
      fontFamily: fontFamily,
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
  }
}
