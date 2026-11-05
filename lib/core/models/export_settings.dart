import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// Everything on the Export screen (product brief §10).
@immutable
class ExportSettings {
  const ExportSettings({
    this.resolution = ResolutionPreset.p1080,
    this.fps = FpsPreset.f30,
    this.codec = VideoCodecPreset.h264,
    this.quality = QualityPreset.high,
    this.customBitrate = 0,
    this.aspect = AspectPreset.r16x9,
  });

  final ResolutionPreset resolution;
  final FpsPreset fps;
  final VideoCodecPreset codec;
  final QualityPreset quality;

  /// Only used when [quality] is custom.
  final int customBitrate;

  final AspectPreset aspect;

  ExportSettings copyWith({
    ResolutionPreset? resolution,
    FpsPreset? fps,
    VideoCodecPreset? codec,
    QualityPreset? quality,
    int? customBitrate,
    AspectPreset? aspect,
  }) =>
      ExportSettings(
        resolution: resolution ?? this.resolution,
        fps: fps ?? this.fps,
        codec: codec ?? this.codec,
        quality: quality ?? this.quality,
        customBitrate: customBitrate ?? this.customBitrate,
        aspect: aspect ?? this.aspect,
      );

  /// Resolved output dimensions for a project whose first photo has
  /// [firstPhotoAspect].
  ({int width, int height}) dimensions(double firstPhotoAspect) {
    final a = effectiveAspect(aspect, firstPhotoAspect);
    return outputDimensions(a, resolution.shortSide);
  }

  int bitrateFor(int width, int height) => deriveBitrate(
        width: width,
        height: height,
        fps: fps.value,
        quality: quality,
        codec: codec,
        customBitrate: customBitrate,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'resolution': resolution.label,
        'fps': fps.value,
        'codec': codec.id,
        'quality': quality.id,
        'customBitrate': customBitrate,
        'aspect': aspect.id,
      };

  factory ExportSettings.fromJson(Map<String, dynamic> json) => ExportSettings(
        resolution: ResolutionPreset.parse(json['resolution'] as String?),
        fps: FpsPreset.parse((json['fps'] as num?)?.toInt()),
        codec: VideoCodecPreset.parse(json['codec'] as String?),
        quality: QualityPreset.parse(json['quality'] as String?),
        customBitrate: (json['customBitrate'] as num?)?.toInt() ?? 0,
        aspect: AspectPreset.parse(json['aspect'] as String?),
      );

  @override
  bool operator ==(Object other) =>
      other is ExportSettings &&
      other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;
}

/// Compact string encoding used by the preferences store.
extension ExportSettingsCodec on ExportSettings {
  String encode() => '${resolution.label};${fps.value};${codec.id};'
      '${quality.id};$customBitrate;${aspect.id}';
}

/// Parses the compact preference string, falling back to defaults on any
/// malformed value instead of throwing at startup.
ExportSettings exportSettingsFromPreferences(String raw) {
  final parts = raw.split(';');
  if (parts.length < 6) return const ExportSettings();
  return ExportSettings(
    resolution: ResolutionPreset.parse(parts[0]),
    fps: FpsPreset.parse(int.tryParse(parts[1])),
    codec: VideoCodecPreset.parse(parts[2]),
    quality: QualityPreset.parse(parts[3]),
    customBitrate: int.tryParse(parts[4]) ?? 0,
    aspect: AspectPreset.parse(parts[5]),
  );
}

extension on ExportSettings {
  /// Internal helper kept next to the codec so both live in one file.
  ExportSettings fromJsonMap(String raw) => exportSettingsFromPreferences(raw);
}
