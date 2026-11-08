import 'package:flutter/material.dart';

/// SubFlow palette: deep navy-black, violet-to-blue accents, gold for "pro".
///
/// Every colour the UI paints comes from here so a redesign is one file. The
/// names are the ones the rest of the app already uses; only the values (and a
/// few additions) changed when the shell was rebuilt to match the reference
/// layout.
class AppColors {
  const AppColors._();

  // Surfaces -------------------------------------------------------------
  static const Color base = Color(0xFF090C16);
  static const Color surface = Color(0xFF10141F);
  static const Color surfaceHigh = Color(0xFF171C2B);
  static const Color surfaceHigher = Color(0xFF1F2536);
  static const Color outline = Color(0xFF2A3145);

  /// The card tone from the reference: a touch lighter than the page.
  static const Color card = Color(0xFF141928);
  static const Color cardHigh = Color(0xFF1B2132);

  // Accents --------------------------------------------------------------
  static const Color primary = Color(0xFF8B5CF6); // violet
  static const Color primarySoft = Color(0xFFA78BFA);
  static const Color secondary = Color(0xFF4B7BFF); // electric blue
  static const Color secondarySoft = Color(0xFF7B9CFF);

  static const Color success = Color(0xFF2ED47A);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF5470);

  /// The crown in the header and the "pro" chips.
  static const Color gold = Color(0xFFFFC53D);

  /// Default caption highlight used by the karaoke word and the colour row.
  static const Color captionYellow = Color(0xFFFFD400);
  static const Color captionPink = Color(0xFFFF5C8A);
  static const Color captionGreen = Color(0xFF3DDC97);

  // Text -----------------------------------------------------------------
  static const Color textPrimary = Color(0xFFF4F6FF);
  static const Color textSecondary = Color(0xFFAAB3CA);
  static const Color textMuted = Color(0xFF6E7794);

  // Gradients ------------------------------------------------------------
  static const LinearGradient accentGradient = LinearGradient(
    colors: <Color>[primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// The app-icon tile: violet on the left, blue behind, like the reference.
  static const LinearGradient logoGradient = LinearGradient(
    colors: <Color>[Color(0xFF9B5CFF), Color(0xFF7C4DFF), Color(0xFF3C6DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient screenGradient = LinearGradient(
    colors: <Color>[Color(0xFF0B1020), base],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Purple glow behind the header; drawn once, cheap, and the thing that makes
  /// the flat navy look intentional rather than unbranded.
  static const RadialGradient headerGlow = RadialGradient(
    colors: <Color>[Color(0x558B5CF6), Color(0x00000000)],
    radius: 0.9,
  );

  static const LinearGradient rainbow = LinearGradient(
    colors: <Color>[
      Color(0xFFFF5C8A),
      Color(0xFFFFC53D),
      Color(0xFF3DDC97),
      Color(0xFF4B7BFF),
      Color(0xFF8B5CF6),
    ],
  );
}
