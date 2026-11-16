import 'package:flutter/material.dart';

/// Brand palette: deep navy backgrounds with violet/indigo accents.
abstract final class AppColors {
  // Dark theme (primary experience)
  static const navy900 = Color(0xFF070B1A);
  static const navy800 = Color(0xFF0B1026);
  static const navy700 = Color(0xFF111834);
  static const navy600 = Color(0xFF18203F);

  // Accents
  static const violet = Color(0xFF7C5CFF);
  static const violetLight = Color(0xFFA78BFA);
  static const indigo = Color(0xFF4F6BFF);
  static const mint = Color(0xFF3DDC97);
  static const amber = Color(0xFFFFB74D);
  static const coral = Color(0xFFFF6B81);

  // Light theme
  static const surfaceLight = Color(0xFFF6F5FB);
  static const surfaceLightElevated = Color(0xFFFFFFFF);
  static const navyOnLight = Color(0xFF141A33);

  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, indigo],
  );

  static const gradientBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy800, navy900],
  );
}
