import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'caption_effect.dart';

/// A complete, self-contained caption look.
///
/// A preset is *data only*: the same object drives the Flutter renderer (live
/// preview and gallery) and, in Phase 6, the native renderer through its
/// `toMap()` JSON. There is no second style model, which is the rule that keeps
/// preview and export identical.
@immutable
class CaptionPreset {
  const CaptionPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.language,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontScale,
    required this.textColor,
    required this.accentColor,
    this.strokeWidth = 0,
    this.strokeColor = 0x000000,
    this.shadowBlur = 0,
    this.shadowColor = 0x000000,
    this.shadowOffsetY = 0,
    this.glowRadius = 0,
    this.glowColor = 0x000000,
    this.gradientEnd,
    this.boxBackground = false,
    this.backgroundColor = 0x000000,
    this.backgroundOpacity = 0,
    this.backgroundRadius = 0,
    this.letterSpacing = 0,
    this.lineHeight = 1.15,
    this.positionY = 0.82,
    this.widthFraction = 0.88,
    this.uppercase = false,
    this.effects = const CaptionEffects(),
  });

  final String id;
  final String name;
  final String category;

  /// `fa` or `en`; drives direction, sample text and the font picker filter.
  final String language;

  final String fontFamily;
  final int fontWeight;

  /// Font size as a fraction of the caption area's short edge, exactly like the
  /// ASS `PlayRes` relationship, so a phone preview and a 4K export agree.
  final double fontScale;

  final int textColor;
  final int accentColor;
  final double strokeWidth;
  final int strokeColor;
  final double shadowBlur;
  final int shadowColor;
  final double shadowOffsetY;
  final double glowRadius;
  final int glowColor;
  final int? gradientEnd;
  final bool boxBackground;
  final int backgroundColor;
  final double backgroundOpacity;
  final double backgroundRadius;
  final double letterSpacing;
  final double lineHeight;

  /// 0 = top edge, 1 = bottom edge of the frame.
  final double positionY;
  final double widthFraction;
  final bool uppercase;
  final CaptionEffects effects;

  bool get isPersian => language == 'fa';
  TextDirection get direction => isPersian ? TextDirection.rtl : TextDirection.ltr;
  bool get hasGradient => gradientEnd != null;
  Color get primary => Color(textColor);
  Color get accent => Color(accentColor);

  CaptionPreset copyWith({
    String? name,
    String? fontFamily,
    int? fontWeight,
    double? fontScale,
    int? textColor,
    int? accentColor,
    double? strokeWidth,
    int? strokeColor,
    double? shadowBlur,
    double? glowRadius,
    double? letterSpacing,
    double? positionY,
    double? widthFraction,
    CaptionEffects? effects,
    int? gradientEnd,
    bool clearGradient = false,
  }) {
    return CaptionPreset(
      id: id,
      name: name ?? this.name,
      category: category,
      language: language,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      fontScale: fontScale ?? this.fontScale,
      textColor: textColor ?? this.textColor,
      accentColor: accentColor ?? this.accentColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeColor: strokeColor ?? this.strokeColor,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowColor: shadowColor,
      shadowOffsetY: shadowOffsetY,
      glowRadius: glowRadius ?? this.glowRadius,
      glowColor: glowColor,
      gradientEnd: clearGradient ? null : (gradientEnd ?? this.gradientEnd),
      boxBackground: boxBackground,
      backgroundColor: backgroundColor,
      backgroundOpacity: backgroundOpacity,
      backgroundRadius: backgroundRadius,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineHeight: lineHeight,
      positionY: positionY ?? this.positionY,
      widthFraction: widthFraction ?? this.widthFraction,
      uppercase: uppercase,
      effects: effects ?? this.effects,
    );
  }

  /// Rebuilds a preset from [toMap]. Used by per-caption styles, which are
  /// stored as exactly this map: one serialiser, so a caption styled on one
  /// build reopens identically on the next.
  factory CaptionPreset.fromMap(Map<String, Object?> map) {
    double readDouble(String key, double fallback) {
      final Object? raw = map[key];
      return raw is num ? raw.toDouble() : fallback;
    }

    int readInt(String key, int fallback) {
      final Object? raw = map[key];
      return raw is num ? raw.toInt() : fallback;
    }

    bool readBool(String key, bool fallback) {
      final Object? raw = map[key];
      return raw is bool ? raw : fallback;
    }

    final Object? gradient = map['gradientEnd'];
    return CaptionPreset(
      id: map['id'] as String? ?? 'custom',
      name: map['name'] as String? ?? 'سبک سفارشی',
      category: map['category'] as String? ?? 'custom',
      language: map['language'] as String? ?? 'fa',
      fontFamily: map['fontFamily'] as String? ?? 'Vazirmatn',
      fontWeight: readInt('fontWeight', 700),
      fontScale: readDouble('fontScale', 0.062),
      textColor: readInt('textColor', 0xFFFFFFFF),
      accentColor: readInt('accentColor', 0xFF3B82F6),
      strokeWidth: readDouble('strokeWidth', 0),
      strokeColor: readInt('strokeColor', 0xFF000000),
      shadowBlur: readDouble('shadowBlur', 0),
      shadowColor: readInt('shadowColor', 0xFF000000),
      shadowOffsetY: readDouble('shadowOffsetY', 0),
      glowRadius: readDouble('glowRadius', 0),
      glowColor: readInt('glowColor', 0xFF000000),
      gradientEnd: gradient is num ? gradient.toInt() : null,
      boxBackground: readBool('boxBackground', false),
      backgroundColor: readInt('backgroundColor', 0xFF000000),
      backgroundOpacity: readDouble('backgroundOpacity', 0),
      backgroundRadius: readDouble('backgroundRadius', 0),
      letterSpacing: readDouble('letterSpacing', 0),
      lineHeight: readDouble('lineHeight', 1.15),
      positionY: readDouble('positionY', 0.82),
      widthFraction: readDouble('widthFraction', 0.88),
      uppercase: readBool('uppercase', false),
      effects: CaptionEffects.fromMap(
        map['effects'] as Map<String, Object?>? ?? const <String, Object?>{},
      ),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'category': category,
        'language': language,
        'fontFamily': fontFamily,
        'fontWeight': fontWeight,
        'fontScale': fontScale,
        'textColor': textColor,
        'accentColor': accentColor,
        'strokeWidth': strokeWidth,
        'strokeColor': strokeColor,
        'shadowBlur': shadowBlur,
        'shadowOffsetY': shadowOffsetY,
        'glowRadius': glowRadius,
        'glowColor': glowColor,
        'gradientEnd': gradientEnd,
        'boxBackground': boxBackground,
        'backgroundColor': backgroundColor,
        'backgroundOpacity': backgroundOpacity,
        'backgroundRadius': backgroundRadius,
        'letterSpacing': letterSpacing,
        'lineHeight': lineHeight,
        'positionY': positionY,
        'widthFraction': widthFraction,
        'uppercase': uppercase,
        'effects': effects.toMap(),
      };
}
