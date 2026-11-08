import 'package:flutter/foundation.dart';

/// A text watermark shown over the video between [start] and [end].
///
/// Layout contract (shared with the native renderer — keep in sync with
/// `ExportRequest.kt` / `WatermarkTexture.kt`):
///  * [fontScale] is the text height as a fraction of the OUTPUT height
///    (0.055 ≈ 5.5%), so the watermark scales with the export resolution
///  * [position] is a 3×3 grid, row-major: 0 = top-left … 8 = bottom-right
///  * the text is drawn in white over a soft dark chip for readability, at
///    [opacity]
@immutable
class WatermarkSpec {
  const WatermarkSpec({
    this.text = '',
    this.fontScale = 0.055,
    this.opacity = 0.85,
    this.position = 8,
    this.start = 0.0,
    this.end = 0.0,
  });

  final String text;

  /// Text height / output height (clamped 0.01..0.25 at render time).
  final double fontScale;

  /// 0..1 overall watermark opacity.
  final double opacity;

  /// 3×3 anchor grid, row-major (0..8).
  final int position;

  /// Timeline seconds (clamped to the project length at render time).
  final double start;
  final double end;

  bool get hasText => text.trim().isNotEmpty;

  /// Whether the watermark is on screen at timeline time [t].
  bool visibleAt(double t) => hasText && t >= start && t <= end;

  int get row => (position ~/ 3).clamp(0, 2);
  int get col => (position % 3).clamp(0, 2);

  WatermarkSpec copyWith({
    String? text,
    double? fontScale,
    double? opacity,
    int? position,
    double? start,
    double? end,
  }) =>
      WatermarkSpec(
        text: text ?? this.text,
        fontScale: fontScale ?? this.fontScale,
        opacity: opacity ?? this.opacity,
        position: position ?? this.position,
        start: start ?? this.start,
        end: end ?? this.end,
      );

  WatermarkSpec clampedTo(double totalDuration) {
    final s = start.clamp(0.0, totalDuration).toDouble();
    final e = end.clamp(s, totalDuration).toDouble();
    return copyWith(start: s, end: e);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'fontScale': fontScale,
        'opacity': opacity,
        'position': position,
        'start': start,
        'end': end,
      };

  factory WatermarkSpec.fromJson(Map<String, dynamic> json) => WatermarkSpec(
        text: json['text'] as String? ?? '',
        fontScale: (json['fontScale'] as num?)?.toDouble() ?? 0.055,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 0.85,
        position: (json['position'] as num?)?.toInt() ?? 8,
        start: (json['start'] as num?)?.toDouble() ?? 0.0,
        end: (json['end'] as num?)?.toDouble() ?? 0.0,
      );
}
