import 'enums.dart';

/// Every visual parameter of a caption line.
///
/// This single object is the contract between the Dart preview and the native
/// renderer: the preview paints it in Flutter, `WriteAss` maps it into an ASS
/// style with the same numbers. There is no second "export style" model on
/// purpose - that is how preview/export drift starts.
class SubtitleStyle {
  const SubtitleStyle({
    required this.id,
    required this.name,
    required this.fontFamily,
    required this.fontSize,
    required this.fontWeight,
    required this.textColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.shadowColor,
    required this.shadowBlur,
    required this.shadowOffsetX,
    required this.shadowOffsetY,
    required this.characterSpacing,
    required this.lineSpacing,
    required this.align,
    required this.direction,
    required this.rotation,
    required this.positionX,
    required this.positionY,
    required this.widthFraction,
    required this.padding,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.projectId,
    this.isTemplate = false,
    this.gradientEnabled = false,
    this.gradientColor = 0x7C4DFF,
    this.shadowEnabled = false,
    this.glowEnabled = false,
    this.glowColor = 0x2F80FF,
    this.glowRadius = 0,
    this.backgroundEnabled = false,
    this.backgroundColor = 0x000000,
    this.backgroundOpacity = 0,
    this.backgroundRadius = 0,
  });

  final String id;
  final String? projectId;
  final String name;
  final bool isTemplate;
  final String fontFamily;

  /// Font size in *script pixels* against the video's short edge, exactly like
  /// ASS PlayRes. A 64 px caption on a 1080-wide video is 64/1080 of the width.
  final double fontSize;
  final int fontWeight;
  final int textColor;
  final bool gradientEnabled;
  final int gradientColor;
  final int strokeColor;
  final double strokeWidth;
  final bool shadowEnabled;
  final int shadowColor;
  final double shadowBlur;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final bool glowEnabled;
  final int glowColor;
  final double glowRadius;
  final bool backgroundEnabled;
  final int backgroundColor;
  final double backgroundOpacity;
  final double backgroundRadius;
  final double characterSpacing;
  final double lineSpacing;
  final CaptionAlign align;
  final CaptionDirection direction;
  final double rotation;
  final double positionX;
  final double positionY;
  final double widthFraction;
  final double padding;
  final int createdAtMs;
  final int updatedAtMs;

  static const SubtitleStyle fallback = SubtitleStyle(
    id: 'builtin-default',
    name: 'پیش‌فرض',
    fontFamily: 'Vazirmatn',
    fontSize: 64,
    fontWeight: 700,
    textColor: 0xFFFFFF,
    strokeColor: 0x000000,
    strokeWidth: 4,
    shadowColor: 0x000000,
    shadowBlur: 8,
    shadowOffsetX: 0,
    shadowOffsetY: 3,
    characterSpacing: 0,
    lineSpacing: 1.1,
    align: CaptionAlign.center,
    direction: CaptionDirection.auto,
    rotation: 0,
    positionX: 0.5,
    positionY: 0.86,
    widthFraction: 0.86,
    padding: 8,
    createdAtMs: 0,
    updatedAtMs: 0,
    shadowEnabled: true,
    backgroundEnabled: false,
  );

  factory SubtitleStyle.fromMap(Map<String, Object?> map) => SubtitleStyle(
        id: map['id']! as String,
        projectId: map['project_id'] as String?,
        name: map['name']! as String,
        isTemplate: ((map['is_template'] as int?) ?? 0) == 1,
        fontFamily: (map['font_family'] as String?) ?? 'Vazirmatn',
        fontSize: ((map['font_size'] as num?) ?? 64).toDouble(),
        fontWeight: (map['font_weight'] as int?) ?? 400,
        textColor: (map['text_color'] as int?) ?? 0xFFFFFF,
        gradientEnabled: ((map['gradient_enabled'] as int?) ?? 0) == 1,
        gradientColor: (map['gradient_color'] as int?) ?? 0,
        strokeColor: (map['stroke_color'] as int?) ?? 0,
        strokeWidth: ((map['stroke_width'] as num?) ?? 0).toDouble(),
        shadowEnabled: ((map['shadow_enabled'] as int?) ?? 0) == 1,
        shadowColor: (map['shadow_color'] as int?) ?? 0,
        shadowBlur: ((map['shadow_blur'] as num?) ?? 0).toDouble(),
        shadowOffsetX: ((map['shadow_offset_x'] as num?) ?? 0).toDouble(),
        shadowOffsetY: ((map['shadow_offset_y'] as num?) ?? 0).toDouble(),
        glowEnabled: ((map['glow_enabled'] as int?) ?? 0) == 1,
        glowColor: (map['glow_color'] as int?) ?? 0,
        glowRadius: ((map['glow_radius'] as num?) ?? 0).toDouble(),
        backgroundEnabled: ((map['background_enabled'] as int?) ?? 0) == 1,
        backgroundColor: (map['background_color'] as int?) ?? 0,
        backgroundOpacity: ((map['background_opacity'] as num?) ?? 0).toDouble(),
        backgroundRadius: ((map['background_radius'] as num?) ?? 0).toDouble(),
        characterSpacing: ((map['character_spacing'] as num?) ?? 0).toDouble(),
        lineSpacing: ((map['line_spacing'] as num?) ?? 1).toDouble(),
        align: CaptionAlign.fromDb(map['text_align'] as String?),
        direction: CaptionDirection.fromDb(map['text_direction'] as String?),
        rotation: ((map['rotation'] as num?) ?? 0).toDouble(),
        positionX: ((map['position_x'] as num?) ?? 0.5).toDouble(),
        positionY: ((map['position_y'] as num?) ?? 0.86).toDouble(),
        widthFraction: ((map['width_fraction'] as num?) ?? 0.86).toDouble(),
        padding: ((map['padding'] as num?) ?? 8).toDouble(),
        createdAtMs: map['created_at_ms']! as int,
        updatedAtMs: map['updated_at_ms']! as int,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'project_id': projectId,
        'name': name,
        'is_template': isTemplate ? 1 : 0,
        'font_family': fontFamily,
        'font_size': fontSize,
        'font_weight': fontWeight,
        'text_color': textColor,
        'gradient_enabled': gradientEnabled ? 1 : 0,
        'gradient_color': gradientColor,
        'stroke_color': strokeColor,
        'stroke_width': strokeWidth,
        'shadow_enabled': shadowEnabled ? 1 : 0,
        'shadow_color': shadowColor,
        'shadow_blur': shadowBlur,
        'shadow_offset_x': shadowOffsetX,
        'shadow_offset_y': shadowOffsetY,
        'glow_enabled': glowEnabled ? 1 : 0,
        'glow_color': glowColor,
        'glow_radius': glowRadius,
        'background_enabled': backgroundEnabled ? 1 : 0,
        'background_color': backgroundColor,
        'background_opacity': backgroundOpacity,
        'background_radius': backgroundRadius,
        'character_spacing': characterSpacing,
        'line_spacing': lineSpacing,
        'text_align': align.dbValue,
        'text_direction': direction.dbValue,
        'rotation': rotation,
        'position_x': positionX,
        'position_y': positionY,
        'width_fraction': widthFraction,
        'padding': padding,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };
}
