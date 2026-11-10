import 'package:flutter/foundation.dart';

/// Background music settings (docs/MOTION_SPEC.md §9).
@immutable
class AudioSettings {
  const AudioSettings({
    this.uri,
    this.displayName = '',
    this.volume = 1.0,
    this.fadeIn = 0.5,
    this.fadeOut = 1.0,
    this.trimStart = 0.0,
    this.trimEnd,
    this.startOffset = 0.0,
    this.loop = true,
    this.sourceDuration,
  });

  /// `content://` URI, or null for "no music".
  final String? uri;
  final String displayName;

  /// 0..1 in the engine. The UI exposes 0..200% with a limiter.
  final double volume;
  final double fadeIn;
  final double fadeOut;
  final double trimStart;
  final double? trimEnd;

  /// Video time (seconds) at which the track starts; the leading part of the
  /// video is silent. 0 = the track starts with the video.
  final double startOffset;

  final bool loop;

  /// Duration of the decoded source, when known (for the trim UI).
  final double? sourceDuration;

  bool get hasAudio => uri != null;

  AudioSettings copyWith({
    String? uri,
    String? displayName,
    double? volume,
    double? fadeIn,
    double? fadeOut,
    double? trimStart,
    double? trimEnd,
    double? startOffset,
    bool? loop,
    double? sourceDuration,
    bool clearUri = false,
  }) =>
      AudioSettings(
        uri: clearUri ? null : (uri ?? this.uri),
        displayName: clearUri ? '' : (displayName ?? this.displayName),
        volume: (volume ?? this.volume).clamp(0.0, 1.0),
        fadeIn: fadeIn ?? this.fadeIn,
        fadeOut: fadeOut ?? this.fadeOut,
        trimStart: trimStart ?? this.trimStart,
        trimEnd: trimEnd ?? this.trimEnd,
        startOffset: (startOffset ?? this.startOffset).clamp(0.0, 1e9),
        loop: loop ?? this.loop,
        sourceDuration: sourceDuration ?? this.sourceDuration,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uri': uri,
        'displayName': displayName,
        'volume': volume,
        'fadeIn': fadeIn,
        'fadeOut': fadeOut,
        'trimStart': trimStart,
        'trimEnd': trimEnd,
        'startOffset': startOffset,
        'loop': loop,
      };

  factory AudioSettings.fromJson(Map<String, dynamic> json) => AudioSettings(
        uri: json['uri'] as String?,
        displayName: json['displayName'] as String? ?? '',
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        fadeIn: (json['fadeIn'] as num?)?.toDouble() ?? 0.5,
        fadeOut: (json['fadeOut'] as num?)?.toDouble() ?? 1.0,
        trimStart: (json['trimStart'] as num?)?.toDouble() ?? 0.0,
        trimEnd: (json['trimEnd'] as num?)?.toDouble(),
        startOffset: (json['startOffset'] as num?)?.toDouble() ?? 0.0,
        loop: json['loop'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      other is AudioSettings && other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;
}
