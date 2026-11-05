import 'dart:math' as math;

import '../../models/enums.dart';
import '../../models/subtitle_style.dart';
import 'caption_preset.dart';

/// Maps a [CaptionPreset] onto the `SubtitleStyle` row the database stores and
/// the native ASS writer consumes.
///
/// This is the bridge that keeps the promise "preview == export": the same
/// numbers the Flutter painter uses (font, colours, stroke, shadow, spacing,
/// position, width) are converted once, here, into the units ASS works in
/// (pixels at `PlayResY`, `&HBBGGRR` colours, alignment codes). A preset never
/// grows a second, existence-only style object.
class PresetStyleMapper {
  const PresetStyleMapper._();

  /// ASS alignment: 1-3 bottom, 4-6 middle, 7-9 top; 2 = bottom centre.
  static int alignmentFor(double positionY) {
    if (positionY < 0.34) return 8;
    if (positionY < 0.67) return 5;
    return 2;
  }

  /// Font size in ASS pixels: `fontScale` is a fraction of the frame's short
  /// edge (see `CaptionPreset.fontScale`), which is what the painter uses too.
  static double fontSizeFor(CaptionPreset preset, int playResX, int playResY) {
    final int shortEdge = math.min(playResX, playResY);
    return (preset.fontScale * shortEdge).toDouble();
  }

  static SubtitleStyle toStyle(
    CaptionPreset preset, {
    required String id,
    String? projectId,
    int playResX = 1080,
    int playResY = 1920,
    int? nowMs,
  }) {
    final int now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return SubtitleStyle(
      id: id,
      projectId: projectId,
      name: preset.name,
      fontFamily: preset.fontFamily,
      fontSize: fontSizeFor(preset, playResX, playResY),
      fontWeight: preset.fontWeight,
      textColor: preset.textColor,
      strokeColor: preset.strokeColor,
      strokeWidth: preset.strokeWidth,
      shadowColor: preset.shadowColor,
      shadowBlur: preset.shadowBlur,
      shadowOffsetX: 0,
      shadowOffsetY: preset.shadowOffsetY,
      characterSpacing: preset.letterSpacing,
      lineSpacing: preset.lineHeight - 1,
      align: CaptionAlign.center,
      direction: preset.isPersian ? CaptionDirection.rtl : CaptionDirection.ltr,
      rotation: 0,
      positionX: 0.5,
      positionY: preset.positionY,
      widthFraction: preset.widthFraction,
      padding: 0.02,
      backgroundEnabled: preset.boxBackground,
      backgroundColor: preset.backgroundColor,
      backgroundOpacity: preset.backgroundOpacity,
      backgroundRadius: preset.backgroundRadius,
      glowEnabled: preset.glowRadius > 0,
      glowColor: preset.glowColor,
      glowRadius: preset.glowRadius,
      shadowEnabled: preset.shadowBlur > 0,
      gradientEnabled: preset.hasGradient,
      gradientColor: preset.gradientEnd ?? preset.accentColor,
      createdAtMs: now,
      updatedAtMs: now,
    );
  }
}
