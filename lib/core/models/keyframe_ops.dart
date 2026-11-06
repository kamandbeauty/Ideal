/// Pure keyframe editing operations.
///
/// Kept free of Flutter imports and of any provider so it is fully unit
/// testable, and so the editor's undo stack only ever stores data.
library;

import 'dart:math' as math;

import '../utils/easing.dart';
import '../../features/motion/camera_math.dart';
import 'keyframe.dart';

class KeyframeEditException implements Exception {
  const KeyframeEditException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'KeyframeEditException($code): $message';
}

/// Inserts a keyframe at [time], sampling the curve so the visible motion is
/// unchanged (the standard "insert on a curve" behaviour).
List<Keyframe> insertKeyframe(
  List<Keyframe> kfs,
  double time, {
  required CameraState Function(List<Keyframe>, double) sampler,
  Easing easing = Easing.smoother,
}) {
  if (kfs.length >= 20) {
    throw const KeyframeEditException(
        'kf_limit', 'This build supports at most 20 keyframes per photo');
  }
  final clamped = time.clamp(kfs.first.time, kfs.last.time);
  for (final k in kfs) {
    if ((k.time - clamped).abs() < 0.05) {
      throw const KeyframeEditException(
          'kf_too_close', 'There is already a keyframe at this position');
    }
  }
  final st = sampler(kfs, clamped);
  final inserted = Keyframe(
    time: clamped,
    x: st.x,
    y: st.y,
    scale: st.scale,
    rotation: st.rotation,
    easing: easing,
  );
  final out = <Keyframe>[...kfs, inserted]
    ..sort((a, b) => a.time.compareTo(b.time));
  return out;
}

/// Removes a keyframe. The first and last keyframes are structural: removing
/// them is refused instead of silently collapsing the motion.
List<Keyframe> removeKeyframe(List<Keyframe> kfs, int index) {
  if (index <= 0 || index >= kfs.length - 1) {
    throw const KeyframeEditException('kf_structural',
        'The first and last keyframes define the shot and cannot be removed');
  }
  final out = List<Keyframe>.of(kfs)..removeAt(index);
  return out;
}

/// Moves a keyframe in time, keeping neighbours' ordering intact.
List<Keyframe> moveKeyframeTime(List<Keyframe> kfs, int index, double time,
    {double minGap = 0.05}) {
  if (index < 0 || index >= kfs.length) {
    throw const KeyframeEditException('kf_missing', 'Keyframe not found');
  }
  if (index == 0) {
    throw const KeyframeEditException(
        'kf_structural', 'The first keyframe is pinned to 0 s');
  }
  final lo = kfs[index - 1].time + minGap;
  final hi = index == kfs.length - 1
      ? math.max(lo, kfs[index].time)
      : kfs[index + 1].time - minGap;
  // clamp() on a double returns num; copyWith(time:) wants a double.
  final t = time.clamp(lo, math.max(lo, hi)).toDouble();
  final out = List<Keyframe>.of(kfs);
  out[index] = out[index].copyWith(time: t);
  return out;
}

/// The last keyframe time follows the photo duration (product rule: changing
/// duration changes speed, not framing).
List<Keyframe> retimeToDuration(List<Keyframe> kfs, double duration) {
  if (duration <= 0) {
    throw const KeyframeEditException(
        'duration', 'Duration must be greater than zero');
  }
  if (kfs.length < 2) {
    throw const KeyframeEditException(
        'kf_count', 'A motion needs at least 2 keyframes');
  }
  final oldEnd = kfs.last.time;
  final out = <Keyframe>[];
  for (final k in kfs) {
    double t;
    if (oldEnd <= 1e-9) {
      t = 0;
    } else if (k.time == oldEnd) {
      t = duration;
    } else {
      t = k.time / oldEnd * duration;
    }
    out.add(k.copyWith(time: t));
  }
  out[0] = out[0].copyWith(time: 0);
  out[out.length - 1] = out.last.copyWith(time: duration);
  return out;
}

/// Copies motion between photos, rebased onto the target duration.
List<Keyframe> copyMotion(List<Keyframe> source, double targetDuration) =>
    retimeToDuration(source, targetDuration);

/// Detects whether a keyframe is safe (spec §4) and returns the minimum scale.
double requiredMinScale(Keyframe k, ImageFit fit, Viewport vp) =>
    minScaleAtRotation(fit, vp, k.rotation);

/// Clamps every keyframe into the legal area without changing the intent.
List<Keyframe> sanitize(List<Keyframe> kfs, ImageFit fit, Viewport vp,
    {double pad = 1.002}) {
  return kfs.map((k) {
    final sMin = minScaleAtRotation(fit, vp, k.rotation) * pad;
    final scale = math.max(k.scale, sMin);
    final st = clampCamera(
        CameraState(x: k.x, y: k.y, scale: scale, rotation: k.rotation),
        fit,
        vp);
    return k.copyWith(
        x: st.x, y: st.y, scale: st.scale, rotation: st.rotation);
  }).toList(growable: false);
}
