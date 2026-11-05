import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../utils/easing.dart';
import '../../features/motion/camera_math.dart';
import '../../features/motion_path/motion_path_engine.dart';
import 'keyframe.dart';
import 'motion_path.dart';
import 'motion_type.dart';

/// Everything the renderer needs to move the camera over one photo.
@immutable
class MotionProfile {
  const MotionProfile({
    required this.keyframes,
    this.motionType = MotionType.zoomIn,
    this.intensity = 0.6,
    this.seed = 0,
    this.isLocked = false,
    this.isMotionTypePinned = false,
    this.path,
  });

  final List<Keyframe> keyframes;
  final MotionType motionType;
  final double intensity;
  final int seed;

  /// Locked motions survive every randomize operation (product rule #6).
  final bool isLocked;

  /// When true, `regenerate all` keeps [motionType] but re-rolls the rest.
  final bool isMotionTypePinned;

  /// When non-null the camera travels this path; [keyframes] hold the baked
  /// (high-resolution) samples of the same trajectory and serve as the
  /// export fallback. The renderer evaluates the path directly, so preview
  /// and export stay identical by construction (spec §12.6).
  final MotionPathSpec? path;

  double get duration => keyframes.isEmpty ? 0.0 : keyframes.last.time;

  /// Samples the camera at [localTime] and clamps it inside the image.
  CameraState sample(double localTime, ImageFit fit, Viewport vp) {
    final p = path;
    if (p != null) {
      return evaluatePath(p, fit, vp, localTime, duration);
    }
    return clampCamera(sampleKeyframes(keyframes, localTime), fit, vp);
  }

  /// Raw (unclamped) sample — used by the editor so it can show exactly what
  /// the user authored while still warning about invalid states.
  CameraState sampleRaw(double localTime) {
    final p = path;
    if (p != null) {
      final lut = buildArcLut(p);
      final pr = progressAt(p, localTime, duration);
      final u = paramAtArc(p, lut, pr * lut.total);
      final pt = rawPathPoint(p, u);
      final s = logLerp(p.startZoom, p.endZoom, pr);
      final r = p.startRotation +
          shortestAngle(p.startRotation, p.endRotation) * pr;
      return CameraState(x: pt.x, y: pt.y, scale: s, rotation: r);
    }
    return sampleKeyframes(keyframes, localTime);
  }

  MotionProfile copyWith({
    List<Keyframe>? keyframes,
    MotionType? motionType,
    double? intensity,
    int? seed,
    bool? isLocked,
    bool? isMotionTypePinned,
    MotionPathSpec? path,
  }) =>
      MotionProfile(
        keyframes: keyframes ?? this.keyframes,
        motionType: motionType ?? this.motionType,
        intensity: intensity ?? this.intensity,
        seed: seed ?? this.seed,
        isLocked: isLocked ?? this.isLocked,
        isMotionTypePinned: isMotionTypePinned ?? this.isMotionTypePinned,
        path: path ?? this.path,
      );

  /// Replace the camera settings but keep identity (lock/pin/type/seed).
  MotionProfile withKeyframes(List<Keyframe> kfs) =>
      copyWith(keyframes: List<Keyframe>.unmodifiable(kfs));

  /// Replace the path and re-bake its keyframes (identity preserved).
  ///
  /// A null [spec] clears the path: the baked keyframes (the same
  /// trajectory, as plain keyframes) stay in place, so the visible motion
  /// does not change — only the high-resolution path parameterization is
  /// dropped.
  /// Re-attaches (or clears) the path, re-baking the high-resolution
  /// keyframes. [duration] overrides the profile's current duration —
  /// required when the photo's duration changes at the same time, since
  /// the path is duration-relative.
  MotionProfile withPath(MotionPathSpec? spec, ImageFit fit, Viewport vp,
          {double? duration}) =>
      spec == null
          ? MotionProfile(
              keyframes: keyframes,
              motionType: motionType,
              intensity: intensity,
              seed: seed,
              isLocked: isLocked,
              isMotionTypePinned: isMotionTypePinned,
              path: null,
            )
          : MotionProfile(
              keyframes: List<Keyframe>.unmodifiable(bakePathToKeyframes(
                  spec, fit, vp, duration ?? this.duration)),
              motionType: motionType,
              intensity: intensity,
              seed: seed,
              isLocked: isLocked,
              isMotionTypePinned: isMotionTypePinned,
              path: spec,
            );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'motionType': motionType.id,
        'intensity': intensity,
        'seed': seed,
        'isLocked': isLocked,
        'isMotionTypePinned': isMotionTypePinned,
        'keyframes': keyframes.map((k) => k.toJson()).toList(growable: false),
        if (path != null) 'path': path!.toJson(),
      };

  factory MotionProfile.fromJson(Map<String, dynamic> json) {
    final raw = (json['keyframes'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => Keyframe.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    MotionPathSpec? path;
    final rawPath = json['path'];
    if (rawPath is Map) {
      try {
        path = MotionPathSpec.fromJson(
            Map<String, dynamic>.from(rawPath.cast<String, dynamic>()));
      } on FormatException {
        path = null; // foreign path data: fall back to keyframes
      }
    }
    return MotionProfile(
      keyframes: List<Keyframe>.unmodifiable(sortKeyframes(raw)),
      motionType: MotionType.parse(json['motionType'] as String?),
      intensity: (json['intensity'] as num?)?.toDouble() ?? 0.6,
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      isLocked: json['isLocked'] as bool? ?? false,
      isMotionTypePinned: json['isMotionTypePinned'] as bool? ?? false,
      path: path,
    );
  }

  static List<Keyframe> sortKeyframes(List<Keyframe> input) {
    final kfs = List<Keyframe>.of(input)..sort((a, b) => a.time.compareTo(b.time));
    return kfs;
  }

  /// Throws [MotionProfileException] when the profile is not renderable.
  void validate() {
    if (keyframes.length < 2) {
      throw const MotionProfileException(
          'motion_need_two_keyframes', 'A motion needs at least 2 keyframes');
    }
    for (var i = 0; i < keyframes.length; i++) {
      final k = keyframes[i];
      if (k.scale <= 0) {
        throw const MotionProfileException(
            'motion_bad_scale', 'Keyframe scale must be greater than zero');
      }
      if (i > 0 && k.time - keyframes[i - 1].time < 1e-3) {
        throw const MotionProfileException('motion_kf_too_close',
            'Keyframes must be at least 1 ms apart');
      }
    }
    if (keyframes.first.time.abs() > 1e-6) {
      throw const MotionProfileException(
          'motion_first_kf', 'The first keyframe must start at 0 s');
    }
  }
}

/// Sampling shared by preview and (via the native port) the exporter.
///
/// Executable form of docs/MOTION_SPEC.md §3.1.
CameraState sampleKeyframes(List<Keyframe> kfs, double t) {
  if (kfs.isEmpty) {
    throw ArgumentError('empty keyframe list');
  }
  if (kfs.length == 1 || t <= kfs.first.time) {
    final k = kfs.first;
    return CameraState(
        x: k.x, y: k.y, scale: k.scale, rotation: k.rotation);
  }
  if (t >= kfs.last.time) {
    final k = kfs.last;
    return CameraState(
        x: k.x, y: k.y, scale: k.scale, rotation: k.rotation);
  }
  var lo = 0;
  var hi = kfs.length - 1;
  while (lo + 1 < hi) {
    final mid = (lo + hi) ~/ 2;
    if (kfs[mid].time <= t) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final a = kfs[lo];
  final b = kfs[hi];
  final dt = b.time - a.time;
  if (dt <= 1e-9) {
    return CameraState(x: b.x, y: b.y, scale: b.scale, rotation: b.rotation);
  }
  final u = (t - a.time) / dt;
  final e = a.easing.apply(u, a.curve);
  return CameraState(
    x: lerpDouble(a.x, b.x, e),
    y: lerpDouble(a.y, b.y, e),
    scale: logLerp(a.scale, b.scale, e),
    rotation: a.rotation + shortestAngle(a.rotation, b.rotation) * e,
  );
}

/// Error type for motion authoring problems, with a localized message key.
class MotionProfileException implements Exception {
  const MotionProfileException(this.code, this.debugMessage);
  final String code;
  final String debugMessage;

  @override
  String toString() => 'MotionProfileException($code): $debugMessage';
}

/// Convenience: total video length implied by a set of photo durations.
double timelineDuration(Iterable<double> durations) =>
    durations.fold(0.0, (a, b) => a + b);

/// Degrees -> radians.
double deg2rad(double d) => d * math.pi / 180;

/// Radians -> degrees.
double rad2deg(double r) => r * 180 / math.pi;
