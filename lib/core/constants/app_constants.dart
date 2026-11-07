/// Product-wide constants, presets and the bitrate/aspect rules of
/// docs/MOTION_SPEC.md §6, §8. No magic numbers anywhere else in the app.
library;

import 'dart:math' as math;

/// Output resolution presets. Values are the *short side* in pixels.
enum ResolutionPreset {
  p720('720p', 720),
  p1080('1080p', 1080),
  p1440('1440p', 1440),
  p2160('2160p', 2160);

  const ResolutionPreset(this.label, this.shortSide);
  final String label;
  final int shortSide;

  static ResolutionPreset parse(String? v) => ResolutionPreset.values.firstWhere(
        (e) => e.label == v,
        orElse: () => ResolutionPreset.p1080,
      );
}

/// Frame-rate presets.
enum FpsPreset {
  f24(24),
  f30(30),
  f60(60);

  const FpsPreset(this.value);
  final int value;

  static FpsPreset parse(int? v) => FpsPreset.values.firstWhere(
        (e) => e.value == v,
        orElse: () => FpsPreset.f30,
      );
}

/// Video codecs. HEVC is only offered when MediaCodec reports support.
enum VideoCodecPreset {
  h264('h264', 'H.264', 'video/avc'),
  hevc('hevc', 'H.265 / HEVC', 'video/hevc');

  const VideoCodecPreset(this.id, this.label, this.mime);
  final String id;
  final String label;
  final String mime;

  static VideoCodecPreset parse(String? v) => VideoCodecPreset.values.firstWhere(
        (e) => e.id == v,
        orElse: () => VideoCodecPreset.h264,
      );
}

/// Quality presets -> bits-per-pixel-per-second factors (spec §8.2).
enum QualityPreset {
  standard('standard', 0.10),
  high('high', 0.16),
  maximum('maximum', 0.24),
  custom('custom', 0.0);

  const QualityPreset(this.id, this.bpp);
  final String id;
  final double bpp;

  static QualityPreset parse(String? v) => QualityPreset.values.firstWhere(
        (e) => e.id == v,
        orElse: () => QualityPreset.high,
      );
}

/// Output aspect ratio presets. `original` follows the first photo.
enum AspectPreset {
  r9x16('9:16', 9 / 16),
  r16x9('16:9', 16 / 9),
  r1x1('1:1', 1.0),
  r4x5('4:5', 4 / 5),
  original('original', 0.0);

  const AspectPreset(this.id, this.ratio);
  final String id;
  final double ratio;

  static AspectPreset parse(String? v) => AspectPreset.values.firstWhere(
        (e) => e.id == v,
        orElse: () => AspectPreset.r9x16,
      );
}

/// Bitrate derivation, mirroring `tools/validate/motionshot/encode.py`.
int deriveBitrate({
  required int width,
  required int height,
  required int fps,
  required QualityPreset quality,
  required VideoCodecPreset codec,
  int customBitrate = 0,
}) {
  if (quality == QualityPreset.custom && customBitrate > 0) {
    return customBitrate.clamp(1500000, 100000000);
  }
  final hevcFactor = codec == VideoCodecPreset.hevc ? 0.70 : 1.0;
  // The spec defines the bitrate as an integer expression, so truncate rather
  // than round: `int(b)` in the reference. Rounding would make the two
  // languages disagree by 1 bit/s on ~11% of combinations.
  final b = width * height * fps * quality.bpp * hevcFactor;
  return b.toInt().clamp(1500000, 100000000);
}

/// Output pixel dimensions for an aspect + short side.
///
/// Rounds to an even value (4:2:0 chroma requirement, spec §8.1). Further
/// encoder-specific alignment is negotiated by the native encoder.
({int width, int height}) outputDimensions(double aspect, int shortSide) {
  double w;
  double h;
  if (aspect >= 1) {
    h = shortSide.toDouble();
    w = shortSide * aspect;
  } else {
    w = shortSide.toDouble();
    h = shortSide / aspect;
  }
  return (width: _roundEven(w), height: _roundEven(h));
}

int _roundEven(double v) {
  final i = v.round();
  return math.max(2, (i ~/ 2) * 2);
}

/// Aspect ratio of a photo, clamped to a sane video range for `original` mode.
double effectiveAspect(AspectPreset preset, double firstPhotoAspect) {
  if (preset != AspectPreset.original) return preset.ratio;
  if (firstPhotoAspect <= 0) return 16 / 9;
  return firstPhotoAspect.clamp(9 / 16, 16 / 9);
}

/// Global limits. Deliberately *not* a fixed photo count: capacity is decided
/// by the device (spec §4 of the brief — no artificial limits).
class AppLimits {
  const AppLimits._();

  static const double minPhotoDuration = 1.0;
  static const double maxPhotoDuration = 60.0;
  static const double defaultPhotoDuration = 5.0;

  /// Default camera-motion intensity: deliberately gentle, so a fresh
  /// Auto Motion feels calm; users can push individual shots harder.
  static const double defaultMotionIntensity = 0.35;

  static const double minTransition = 0.0;
  static const double maxTransition = 3.0;
  static const double defaultTransition = 0.6;

  static const int minKeyframes = 2;
  static const int maxKeyframes = 20;

  static const double minScalePad = 1.002;

  /// Free storage required before an export starts, as a multiple of the
  /// estimated output size.
  static const double storageHeadroomFactor = 1.25;
  static const int storageHeadroomFloorMb = 120;
}

/// Supported audio containers (spec §9).
const List<String> kSupportedAudioExtensions = <String>[
  'mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'flac',
];

/// Supported image formats (spec §4).
const List<String> kSupportedImageExtensions = <String>[
  'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif',
];
