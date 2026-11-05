import 'package:flutter/material.dart';

/// SubFlow palette: near-black navy base, electric blue + violet accents.
/// Every colour the UI paints comes from here so a theme change is one file.
class AppColors {
  const AppColors._();

  static const Color base = Color(0xFF070A12);
  static const Color surface = Color(0xFF0E1424);
  static const Color surfaceHigh = Color(0xFF151D33);
  static const Color surfaceHigher = Color(0xFF1C2540);
  static const Color outline = Color(0xFF2A3552);

  static const Color primary = Color(0xFF7C4DFF); // violet
  static const Color primarySoft = Color(0xFF9E7BFF);
  static const Color secondary = Color(0xFF2F80FF); // electric blue
  static const Color secondarySoft = Color(0xFF63A4FF);

  static const Color success = Color(0xFF2ED47A);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF5470);

  static const Color textPrimary = Color(0xFFF3F5FB);
  static const Color textSecondary = Color(0xFFA7B0C8);
  static const Color textMuted = Color(0xFF6B7690);

  static const LinearGradient accentGradient = LinearGradient(
    colors: <Color>[primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient screenGradient = LinearGradient(
    colors: <Color>[Color(0xFF0A0F1E), base],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
