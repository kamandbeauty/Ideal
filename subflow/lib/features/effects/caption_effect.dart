import 'package:flutter/animation.dart';

/// Entry animation of a caption line. Every value here is rendered for real by
/// `CaptionRenderer` - the gallery previews are the same widget the editor uses,
/// so nothing in this list is decorative-only.
enum CaptionAnimation {
  none,
  fade,
  slideUp,
  slideDown,
  slideLeft,
  slideRight,
  zoomIn,
  zoomOut,
  pop,
  bounce,
  rotate,
  blurIn,
  typewriter,
  wordReveal,
  elastic,
  shake,
  glowPulse,
}

enum CaptionExit {
  none,
  fadeOut,
  zoomOut,
  slideDown,
  slideUp,
  zoomIn,
  rotateOut,
  popOut,
  blurOut,
}

/// Word-level behaviour. Word timings come from `subtitle_words` (whisper token
/// timestamps) in Phase 2/7; until a project has word timings the renderer
/// distributes words evenly across the line so the preview still animates.
enum CaptionWordEffect {
  none,
  karaokeFill,
  activeColor,
  activeScale,
  wordPop,
  activeBackground,
  activeUnderline,
  neighborDim,
}

enum CaptionEasing {
  linear,
  easeOut,
  easeInOut,
  easeOutBack,
  easeOutElastic,
  easeInQuad,
}

extension CaptionEasingCurve on CaptionEasing {
  Curve get curve => switch (this) {
        CaptionEasing.linear => Curves.linear,
        CaptionEasing.easeOut => Curves.easeOutCubic,
        CaptionEasing.easeInOut => Curves.easeInOutCubic,
        CaptionEasing.easeOutBack => Curves.easeOutBack,
        CaptionEasing.easeOutElastic => Curves.elasticOut,
        CaptionEasing.easeInQuad => Curves.easeInQuad,
      };

  String get label => switch (this) {
        CaptionEasing.linear => 'خطی',
        CaptionEasing.easeOut => 'نرم',
        CaptionEasing.easeInOut => 'نرم دوطرفه',
        CaptionEasing.easeOutBack => 'کشیدگی',
        CaptionEasing.easeOutElastic => 'الاستیك',
        CaptionEasing.easeInQuad => 'آرام شروع',
      };
}

/// Timing + motion parameters. Defaults are deliberately short: broadcast
/// captions read best when the entrance finishes in under 300 ms.
class CaptionEffects {
  const CaptionEffects({
    this.enter = CaptionAnimation.fade,
    this.exit = CaptionExit.fadeOut,
    this.wordEffect = CaptionWordEffect.none,
    this.durationMs = 260,
    this.delayMs = 0,
    this.easing = CaptionEasing.easeOut,
    this.intensity = 1.0,
    this.pulse = false,
  });

  final CaptionAnimation enter;
  final CaptionExit exit;
  final CaptionWordEffect wordEffect;
  final int durationMs;
  final int delayMs;
  final CaptionEasing easing;

  /// 0.3 .. 2.0 - scales travel distance, overshoot and blur amount together.
  final double intensity;
  final bool pulse;

  static const CaptionEffects none = CaptionEffects(enter: CaptionAnimation.none, exit: CaptionExit.none);

  factory CaptionEffects.fromMap(Map<String, Object?> map) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
      if (raw is! String) return fallback;
      for (final T value in values) {
        if (value.name == raw) return value;
      }
      return fallback;
    }

    // Persisted project data may come from an older or newer build, so every
    // field is read defensively: a wrong type falls back instead of throwing a
    // CastError halfway through opening a project.
    int readInt(String key, int fallback) {
      final Object? raw = map[key];
      return raw is num ? raw.toInt() : fallback;
    }

    double readDouble(String key, double fallback) {
      final Object? raw = map[key];
      return raw is num ? raw.toDouble() : fallback;
    }

    bool readBool(String key, bool fallback) {
      final Object? raw = map[key];
      return raw is bool ? raw : fallback;
    }

    return CaptionEffects(
      enter: pick(CaptionAnimation.values, map['enter'], CaptionAnimation.fade),
      exit: pick(CaptionExit.values, map['exit'], CaptionExit.fadeOut),
      wordEffect: pick(CaptionWordEffect.values, map['word'], CaptionWordEffect.none),
      durationMs: readInt('durationMs', 260),
      delayMs: readInt('delayMs', 0),
      easing: pick(CaptionEasing.values, map['easing'], CaptionEasing.easeOut),
      intensity: readDouble('intensity', 1.0),
      pulse: readBool('pulse', false),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'enter': enter.name,
        'exit': exit.name,
        'word': wordEffect.name,
        'durationMs': durationMs,
        'delayMs': delayMs,
        'easing': easing.name,
        'intensity': intensity,
        'pulse': pulse,
      };
}
