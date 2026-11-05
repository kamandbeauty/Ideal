/// Auto motion generator — Dart port of docs/MOTION_SPEC.md §10 and
/// `tools/validate/motionshot/profile.py`.
///
/// Every value produced here is reproducible from `(projectSeed, photoIndex,
/// photoId)`. The Kotlin renderer re-uses the *stored* keyframes, so preview and
/// export are identical by construction.
library;

import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/models/keyframe.dart';
import '../../core/models/motion_path.dart';
import '../../core/models/motion_profile.dart';
import '../../core/models/motion_type.dart';
import '../../core/utils/easing.dart';
import '../motion_path/motion_path_engine.dart';
import 'camera_math.dart';
import 'random.dart';

/// A photo description sufficient to generate a legal motion for it.
class MotionSource {
  const MotionSource({
    required this.photoId,
    required this.srcWidth,
    required this.srcHeight,
    required this.duration,
    this.existing,
  });

  final String photoId;
  final int srcWidth;
  final int srcHeight;
  final double duration;
  final MotionProfile? existing;
}

/// Chooses the next motion type, never repeating [previous] (spec §10 rule 1).
MotionType pickMotionType(
  Xorshift128Plus rng,
  MotionType? previous, {
  List<MotionType>? allowed,
}) {
  var pool = allowed == null || allowed.isEmpty
      ? List<MotionType>.of(MotionType.values)
      : List<MotionType>.of(allowed);
  if (previous != null && pool.length > 1) {
    final filtered = pool.where((t) => t != previous).toList(growable: false);
    if (filtered.isNotEmpty) pool = List<MotionType>.of(filtered);
  }
  final weights = pool.map((t) => t.generationWeight).toList(growable: false);
  final total = weights.fold<double>(0, (a, b) => a + b);
  final r = rng.nextDouble() * total;
  var acc = 0.0;
  for (var i = 0; i < pool.length; i++) {
    acc += weights[i];
    if (r <= acc) return pool[i];
  }
  return pool.last;
}

// ---------------------------------------------------------------------------
// random curved motion (spec §12.7)
// ---------------------------------------------------------------------------

/// Generation pool for random curved motion. `linear`, `cubicBezier` and
/// `custom` are excluded: a random straight pan is already covered by the
/// classic 2-keyframe generators, and `custom` is reserved for the user's
/// finger. Must match `PATH_PRESET_WEIGHTS` in the Python reference and
/// `RandomMotion.kt`.
const Map<String, double> kPathPresetWeights = <String, double>{
  'circularCw': 1.2,
  'circularCcw': 1.2,
  'elliptical': 1.0,
  'sCurve': 1.1,
  'spiral': 0.8,
  'figureEight': 0.7,
  'arc': 1.0,
};

/// Probability that a randomize roll produces a curved path motion.
const double kCurvedPathChance = 0.40;

/// Weighted draw from the curved-motion pool; the previous photo's path
/// preset is removed outright, so adjacent photos never share a path style
/// (same hard guarantee as [pickMotionType], spec §10 rule 1).
String pickPathPreset(Xorshift128Plus rng, [String? previous]) {
  var pool = kPathPresetWeights.keys.toList(growable: false);
  if (previous != null && pool.length > 1) {
    final filtered = pool.where((p) => p != previous).toList(growable: false);
    if (filtered.isNotEmpty) pool = filtered;
  }
  final weights = pool.map((p) => kPathPresetWeights[p]!).toList(growable: false);
  final total = weights.fold<double>(0, (a, b) => a + b);
  final r = rng.nextDouble() * total;
  var acc = 0.0;
  for (var i = 0; i < pool.length; i++) {
    acc += weights[i];
    if (r <= acc) return pool[i];
  }
  return pool.last;
}

/// One deterministic curved-path motion (spec §12.7).
///
/// The draw order below is part of the contract: the Python reference
/// (`generate_path_profile`) and the Kotlin port perform exactly these
/// draws, in exactly this order.
MotionProfile generatePathProfile({
  required Xorshift128Plus rng,
  required double intensity,
  required double duration,
  required ImageFit fit,
  required Viewport vp,
  required int seed,
  String? preset,
}) {
  final i = intensity.clamp(0.0, 1.0);
  final chosen = preset ?? pickPathPreset(rng);
  final direction = rng.sign(); // 1
  final startAngle = rng.range(0, 2 * math.pi); // 2
  final curvature = rng.range(0.15, 0.85); // 3
  final speed = rng.range(0.8, 1.4); // 4
  final speedEase = rng.range(0.0, 0.5); // 5
  var turns = 1.0;
  var sweep = 2.0 * math.pi;
  if ((chosen == 'circularCw' ||
          chosen == 'circularCcw' ||
          chosen == 'spiral') &&
      rng.chance(0.25)) {
    turns = 2.0; // 6
  }
  if (chosen == 'figureEight') {
    turns = rng.rangeInt(1, 2).toDouble(); // 7
  }
  if (chosen == 'arc') {
    sweep = rng.range(0.6 * math.pi, 1.8 * math.pi); // 8
  }
  final pattern = rng.rangeInt(0, 4); // 9
  final base = 1.04 + 0.10 * i;
  double s0, s1;
  if (pattern == 0) {
    // circle + zoom in
    s0 = base;
    s1 = base * (1.18 + 0.24 * i);
  } else if (pattern == 1) {
    // curved + zoom out
    s0 = base * (1.18 + 0.24 * i);
    s1 = base;
  } else if (pattern == 2) {
    // gentle drift, near-constant zoom
    s0 = base * (1.05 + 0.08 * i);
    s1 = s0 * rng.range(1.0, 1.06); // 10
  } else if (pattern == 3) {
    // slow push while curving
    s0 = 1.03 + 0.04 * i;
    s1 = s0 * (1.12 + 0.18 * i);
  } else {
    // pull back while curving
    s1 = 1.03 + 0.04 * i;
    s0 = s1 * (1.12 + 0.18 * i);
  }
  double r0, r1;
  if (rng.chance(0.5)) { // 11
    r0 = 0.0;
    r1 = deg2rad(rng.range(0.4, 1.5) * rng.sign()); // 12
  } else {
    r0 = 0.0;
    r1 = 0.0;
  }
  final sMax = math.max(s0, s1);
  final lim = maxPan(fit, vp, sMax, (r1 - r0).abs());
  var margin = math.min(lim.mx, lim.my);
  if (margin < 0.02) margin = 0.02;
  var r = margin * (0.35 + 0.45 * i);
  if (r < 0.03) r = 0.03;
  final radiusX = r;
  final radiusY = (chosen == 'elliptical' ||
          chosen == 'sCurve' ||
          chosen == 'figureEight')
      ? r * rng.range(0.7, 1.0) // 13
      : r;
  double cX, cY;
  if (rng.chance(0.3)) { // 14
    cX = rng.range(-0.1, 0.1);
    cY = rng.range(-0.1, 0.1); // 15
  } else {
    cX = 0.0;
    cY = 0.0;
  }
  final spec = sanitizePath(
    MotionPathSpec(
      preset: chosen,
      centerX: cX,
      centerY: cY,
      radiusX: radiusX,
      radiusY: radiusY,
      turns: turns,
      startAngle: startAngle,
      sweep: sweep,
      curvature: curvature,
      speed: speed,
      speedEase: speedEase,
      startZoom: s0,
      endZoom: s1,
      startRotation: r0,
      endRotation: r1,
      direction: direction,
    ),
    fit,
    vp,
  );
  final kfs = bakePathToKeyframes(spec, fit, vp, duration);
  final mtype = s1 >= s0
      ? MotionType.zoomIn
      : (s0 > s1 ? MotionType.zoomOut : MotionType.drift);
  return MotionProfile(
    keyframes: List<Keyframe>.unmodifiable(kfs),
    motionType: mtype,
    intensity: i,
    seed: seed,
    path: spec,
  );
}

CameraState _clip(CameraState st, ImageFit fit, Viewport vp) {
  final sMin =
      minScaleAtRotation(fit, vp, st.rotation) * AppLimits.minScalePad;
  final scale = math.max(st.scale, sMin);
  return clampCamera(
      CameraState(x: st.x, y: st.y, scale: scale, rotation: st.rotation),
      fit,
      vp);
}

Keyframe _kf(double t, CameraState st, [Easing easing = Easing.smoother]) =>
    Keyframe(
        time: t,
        x: st.x,
        y: st.y,
        scale: st.scale,
        rotation: st.rotation,
        easing: easing);

/// Builds a legal, cinematic motion of [type] for one photo (spec §10).
MotionProfile generateProfile({
  required MotionType type,
  required double intensity,
  required double duration,
  required ImageFit fit,
  required Viewport vp,
  required Xorshift128Plus rng,
  required int seed,
}) {
  if (duration <= 0) {
    throw ArgumentError('duration must be positive');
  }
  final i = intensity.clamp(0.0, 1.0);
  final base = 1.04 + 0.10 * i;
  final kfs = <Keyframe>[];

  switch (type) {
    case MotionType.zoomIn:
      final s0 = base;
      final s1 = base * (1.16 + 0.26 * i);
      final dx = rng.range(-0.05, 0.05) * 0.2;
      final dy = rng.range(-0.05, 0.05) * 0.2;
      kfs
        ..add(_kf(0, _clip(CameraState(x: dx, y: dy, scale: s0), fit, vp)))
        ..add(_kf(
            duration, _clip(CameraState(x: dx, y: dy, scale: s1), fit, vp)));

    case MotionType.zoomOut:
      final s1 = base;
      final s0 = base * (1.16 + 0.26 * i);
      final dx = rng.range(-0.1, 0.1) * 0.2;
      final dy = rng.range(-0.1, 0.1) * 0.2;
      kfs
        ..add(_kf(0, _clip(CameraState(x: dx, y: dy, scale: s0), fit, vp)))
        ..add(_kf(
            duration, _clip(CameraState(x: dx, y: dy, scale: s1), fit, vp)));

    case MotionType.panLeft:
    case MotionType.panRight:
    case MotionType.panUp:
    case MotionType.panDown:
      final s = base * (1.18 + 0.20 * i);
      final lim = maxPan(fit, vp, s, 0.0);
      final travel = 0.75 + 0.20 * i;
      final jitter = rng.range(-0.15, 0.15);
      final endZoomMul = rng.range(1.0, 1.05);
      late CameraState a;
      late CameraState b;
      switch (type) {
        case MotionType.panLeft:
          a = CameraState(x: lim.mx * travel, y: jitter * lim.my, scale: s);
          b = CameraState(
              x: -lim.mx * travel, y: a.y, scale: s * endZoomMul);
        case MotionType.panRight:
          a = CameraState(x: -lim.mx * travel, y: jitter * lim.my, scale: s);
          b = CameraState(
              x: lim.mx * travel, y: a.y, scale: s * endZoomMul);
        case MotionType.panUp:
          a = CameraState(x: jitter * lim.mx, y: lim.my * travel, scale: s);
          b = CameraState(
              x: a.x, y: -lim.my * travel, scale: s * endZoomMul);
        default: // panDown
          a = CameraState(x: jitter * lim.mx, y: -lim.my * travel, scale: s);
          b = CameraState(
              x: a.x, y: lim.my * travel, scale: s * endZoomMul);
      }
      kfs
        ..add(_kf(0, _clip(a, fit, vp)))
        ..add(_kf(duration, _clip(b, fit, vp)));

    case MotionType.diagonalLeft:
    case MotionType.diagonalRight:
      final s = base * (1.22 + 0.22 * i);
      final lim = maxPan(fit, vp, s, 0.0);
      final travel = 0.75 + 0.20 * i;
      final sx = type == MotionType.diagonalRight ? 1 : -1;
      final sy = rng.sign();
      final a = CameraState(
          x: -sx * lim.mx * travel, y: -sy * lim.my * travel * 0.8, scale: s);
      final b = CameraState(
          x: sx * lim.mx * travel,
          y: sy * lim.my * travel * 0.8,
          scale: s * 1.06);
      kfs
        ..add(_kf(0, _clip(a, fit, vp)))
        ..add(_kf(duration, _clip(b, fit, vp)));

    case MotionType.slowPush:
    case MotionType.pullBack:
      final sLo = 1.02 + 0.03 * i;
      final sHi = sLo * (1.10 + 0.10 * i);
      final s0 = type == MotionType.slowPush ? sLo : sHi;
      final s1 = type == MotionType.slowPush ? sHi : sLo;
      final dx = rng.range(-0.12, 0.12);
      final dy = rng.range(-0.12, 0.12);
      kfs
        ..add(_kf(0, _clip(CameraState(x: dx, y: dy, scale: s0), fit, vp)))
        ..add(_kf(
            duration,
            _clip(CameraState(x: -dx * 0.5, y: -dy * 0.5, scale: s1), fit, vp)));

    case MotionType.zoomPan:
      final s0 = base * 1.02;
      final s1 = base * (1.22 + 0.24 * i);
      final sMid = math.max(s0, s1);
      final lim = maxPan(fit, vp, sMid, 0.0);
      final sx = rng.sign();
      final sy = rng.sign();
      final a = CameraState(
          x: -sx * lim.mx * 0.6, y: -sy * lim.my * 0.6, scale: s0);
      final b = CameraState(
          x: sx * lim.mx * 0.6, y: sy * lim.my * 0.6, scale: s1);
      kfs
        ..add(_kf(0, _clip(a, fit, vp)))
        ..add(_kf(duration, _clip(b, fit, vp)));

    case MotionType.subtleRotation:
      final deg = (0.8 + 1.4 * i) * rng.sign();
      final r1 = deg2rad(deg);
      final s = math.max(
          1.10 + 0.08 * i, minScaleAtRotation(fit, vp, r1.abs()) * 1.02);
      final lim = maxPan(fit, vp, s, r1);
      final a = CameraState(
          x: -lim.mx * 0.15, y: -lim.my * 0.15, scale: s, rotation: 0.0);
      final b = CameraState(
          x: lim.mx * 0.15, y: lim.my * 0.15, scale: s * 1.03, rotation: r1);
      kfs
        ..add(_kf(0, _clip(a, fit, vp)))
        ..add(_kf(duration, _clip(b, fit, vp)));

    case MotionType.drift:
      final s = 1.06 + 0.10 * i;
      final lim = maxPan(fit, vp, s, 0.0);
      final ang = rng.range(0, 2 * math.pi);
      final rEnd = deg2rad((0.4 + 0.9 * i) * rng.sign());
      final amp = 0.45 + 0.3 * i;
      final midAng = ang + math.pi / 2 * rng.sign();
      final a = CameraState(
          x: -math.cos(ang) * lim.mx * amp,
          y: -math.sin(ang) * lim.my * amp,
          scale: s);
      final mid = CameraState(
          x: math.cos(midAng) * lim.mx * amp * 0.35,
          y: math.sin(midAng) * lim.my * amp * 0.35,
          scale: s * 1.04,
          rotation: rEnd * 0.5);
      final b = CameraState(
          x: math.cos(ang) * lim.mx * amp,
          y: math.sin(ang) * lim.my * amp,
          scale: s * 1.07,
          rotation: rEnd);
      kfs
        ..add(_kf(0, _clip(a, fit, vp)))
        ..add(_kf(duration * 0.5, _clip(mid, fit, vp)))
        ..add(_kf(duration, _clip(b, fit, vp)));

    case MotionType.centerToCorner:
      final s0 = 1.02 + 0.05 * i;
      final s1 = s0 * (1.12 + 0.18 * i);
      final lim = maxPan(fit, vp, s1, 0.0);
      final csx = rng.sign();
      final csy = rng.sign();
      final a = CameraState(scale: s0);
      final b = CameraState(
          x: csx * lim.mx * (0.7 + 0.25 * i),
          y: csy * lim.my * (0.7 + 0.25 * i),
          scale: s1);
      kfs
        ..add(_kf(0, _clip(a, fit, vp)))
        ..add(_kf(duration, _clip(b, fit, vp)));

    case MotionType.combined:
      final s0 = 1.03 + 0.04 * i;
      final s1 = s0 * (1.14 + 0.22 * i);
      final sMid = math.max(s0, s1);
      final lim = maxPan(fit, vp, sMid, deg2rad(1.2));
      final rEnd = deg2rad((0.6 + 1.0 * i) * rng.sign());
      final ang = rng.range(0, 2 * math.pi);
      final amp = 0.55 + 0.25 * i;
      final a = CameraState(
          x: -math.cos(ang) * lim.mx * amp,
          y: -math.sin(ang) * lim.my * amp,
          scale: s0);
      final mid = CameraState(
          scale: (s0 + s1) / 2, rotation: rEnd * 0.5);
      final b = CameraState(
          x: math.cos(ang) * lim.mx * amp,
          y: math.sin(ang) * lim.my * amp,
          scale: s1,
          rotation: rEnd);
      kfs
        ..add(_kf(0, _clip(a, fit, vp)))
        ..add(_kf(duration * 0.5, _clip(mid, fit, vp)))
        ..add(_kf(duration, _clip(b, fit, vp)));
  }

  kfs.first = kfs.first.copyWith(time: 0.0);
  kfs.last = kfs.last.copyWith(time: duration);
  return MotionProfile(
    keyframes: List<Keyframe>.unmodifiable(kfs),
    motionType: type,
    intensity: i,
    seed: seed,
  );
}

/// Generates a profile for a single photo, from scratch, deterministically.
///
/// With probability [kCurvedPathChance] the shot becomes a curved-motion
/// path (spec §12.7) instead of a classic 2/3-keyframe move; the previous
/// photo's path preset is excluded so adjacent photos never share a path
/// style.
MotionProfile generateForPhoto({
  required String photoId,
  required int srcWidth,
  required int srcHeight,
  required double duration,
  required int index,
  required int projectSeed,
  required Viewport viewport,
  required double intensity,
  MotionType? previousType,
  List<MotionType>? allowed,
  String? previousPathPreset,
}) {
  final seed = photoSeed(projectSeed, photoId, index);
  final rng = Xorshift128Plus(seed);
  final type = pickMotionType(rng, previousType, allowed: allowed);
  final fit = ImageFit.make(srcWidth, srcHeight, viewport);
  if (rng.chance(kCurvedPathChance)) {
    return generatePathProfile(
      rng: rng,
      intensity: intensity,
      duration: duration,
      fit: fit,
      vp: viewport,
      seed: seed,
      preset: pickPathPreset(rng, previousPathPreset),
    );
  }
  return generateProfile(
    type: type,
    intensity: intensity,
    duration: duration,
    fit: fit,
    vp: viewport,
    rng: rng,
    seed: seed,
  );
}

/// Runs "Auto Motion" / "Regenerate all" over the whole project.
///
/// * locked profiles are preserved untouched (product rule #6)
/// * when [regenerate] is false (first-time Auto Motion) only photos without
///   a motion are generated
/// * when [regenerate] is true every photo is re-rolled — except protected
///   ones when [protectManual] is true: user-drawn or user-edited paths are
///   never replaced by a plain Randomize; only an explicit "Regenerate all"
///   (which warns in the UI) passes [protectManual] == false
Map<String, MotionProfile> buildProfiles({
  required List<MotionSource> photos,
  required Viewport viewport,
  required int projectSeed,
  required double intensity,
  bool regenerate = true,
  List<MotionType>? allowed,
  bool protectManual = true,
}) {
  final out = <String, MotionProfile>{};
  MotionType? prev;
  String? prevPathPreset;
  for (var idx = 0; idx < photos.length; idx++) {
    final p = photos[idx];
    final cur = p.existing;
    final manualPath = protectManual && (cur?.path?.isProtected ?? false);
    if (cur != null && (cur.isLocked || !regenerate || manualPath)) {
      out[p.photoId] = cur;
      prev = cur.motionType;
      prevPathPreset = cur.path?.preset;
      continue;
    }
    final seed = photoSeed(projectSeed, p.photoId, idx);
    final rng = Xorshift128Plus(seed);
    final type = (cur != null && cur.isMotionTypePinned)
        ? cur.motionType
        : pickMotionType(rng, prev, allowed: allowed);
    final fit = ImageFit.make(p.srcWidth, p.srcHeight, viewport);
    final prof = rng.chance(kCurvedPathChance)
        ? generatePathProfile(
            rng: rng,
            intensity: intensity,
            duration: p.duration,
            fit: fit,
            vp: viewport,
            seed: seed,
            preset: pickPathPreset(rng, prevPathPreset),
          )
        : generateProfile(
            type: type,
            intensity: intensity,
            duration: p.duration,
            fit: fit,
            vp: viewport,
            rng: rng,
            seed: seed,
          );
    out[p.photoId] = cur == null
        ? prof
        : prof.copyWith(
            isLocked: cur.isLocked,
            isMotionTypePinned: cur.isMotionTypePinned,
          );
    prev = type;
    prevPathPreset = prof.path?.preset;
  }
  return out;
}

/// "Regenerate selected photo" — re-rolls exactly one photo.
///
/// [protectManual] (default true) keeps user-drawn / user-edited paths
/// untouched: a plain Randomize must never overwrite the user's own camera
/// path. Only an explicit full "Regenerate all" passes false.
MotionProfile regenerateOne({
  required MotionSource photo,
  required int index,
  required Viewport viewport,
  required int projectSeed,
  required double intensity,
  MotionType? previousType,
  List<MotionType>? allowed,
  bool respectLock = true,
  bool protectManual = true,
  String? previousPathPreset,
}) {
  final cur = photo.existing;
  if (respectLock && cur != null && cur.isLocked) {
    return cur;
  }
  if (protectManual && cur != null && cur.path?.isProtected == true) {
    return cur;
  }
  final seed = photoSeed(projectSeed, photo.photoId, index);
  final rng = Xorshift128Plus(seed);
  final type = (cur != null && cur.isMotionTypePinned)
      ? cur.motionType
      : pickMotionType(rng, previousType, allowed: allowed);
  final fit = ImageFit.make(photo.srcWidth, photo.srcHeight, viewport);
  final prof = rng.chance(kCurvedPathChance)
      ? generatePathProfile(
          rng: rng,
          intensity: intensity,
          duration: photo.duration,
          fit: fit,
          vp: viewport,
          seed: seed,
          preset: pickPathPreset(rng, previousPathPreset),
        )
      : generateProfile(
          type: type,
          intensity: intensity,
          duration: photo.duration,
          fit: fit,
          vp: viewport,
          rng: rng,
          seed: seed,
        );
  return cur == null
      ? prof
      : prof.copyWith(
          isLocked: cur.isLocked, isMotionTypePinned: cur.isMotionTypePinned);
}

/// Re-maps camera offsets when the output aspect changes (spec §5 note).
///
/// Keeps each shot's *proportion* of available travel so a 16:9 move stays
/// legal and similarly framed in 9:16.
Map<String, MotionProfile> migrateAspect({
  required Map<String, MotionProfile> profiles,
  required List<MotionSource> photos,
  required Viewport oldVp,
  required Viewport newVp,
}) {
  final byId = {for (final p in photos) p.photoId: p};
  final out = <String, MotionProfile>{};
  profiles.forEach((pid, prof) {
    final p = byId[pid];
    if (p == null) {
      out[pid] = prof;
      return;
    }
    final oldFit = ImageFit.make(p.srcWidth, p.srcHeight, oldVp);
    final newFit = ImageFit.make(p.srcWidth, p.srcHeight, newVp);
    final kfs = <Keyframe>[];
    for (final k in prof.keyframes) {
      final sMin =
          minScaleAtRotation(newFit, newVp, k.rotation) * AppLimits.minScalePad;
      final scale = math.max(k.scale, sMin);
      final oldLim = maxPan(oldFit, oldVp, k.scale, k.rotation);
      final newLim = maxPan(newFit, newVp, scale, k.rotation);
      final fx = oldLim.mx > 1e-9 ? k.x / oldLim.mx : 0.0;
      final fy = oldLim.my > 1e-9 ? k.y / oldLim.my : 0.0;
      final st = clampCamera(
          CameraState(
              x: fx * newLim.mx,
              y: fy * newLim.my,
              scale: scale,
              rotation: k.rotation),
          newFit,
          newVp);
      kfs.add(k.copyWith(
          x: st.x, y: st.y, scale: st.scale, rotation: st.rotation));
    }
    // Path-driven shots migrate their geometry the same way: keep the
    // fraction of available travel, then re-sanitize + re-bake.
    MotionPathSpec? newPath;
    final oldPath = prof.path;
    if (oldPath != null) {
      final rMax = math.max(oldPath.startRotation.abs(),
          oldPath.endRotation.abs());
      final sZoom = math.max(oldPath.startZoom, oldPath.endZoom);
      final ox = maxPan(oldFit, oldVp, sZoom, rMax);
      final nx = maxPan(newFit, newVp, sZoom, rMax);
      final fx = ox.mx > 1e-9 ? oldPath.radiusX / ox.mx : 0.0;
      final fy = ox.my > 1e-9 ? oldPath.radiusY / ox.my : 0.0;
      final cx = ox.mx > 1e-9 ? oldPath.centerX / ox.mx : 0.0;
      final cy = ox.my > 1e-9 ? oldPath.centerY / ox.my : 0.0;
      newPath = sanitizePath(
        oldPath.copyWith(
          centerX: cx * nx.mx,
          centerY: cy * nx.my,
          radiusX: fx * nx.mx,
          radiusY: fy * nx.my,
          points: <MotionPoint>[
            for (final pt in oldPath.points)
              MotionPoint(
                  x: pt.x * (ox.mx > 1e-9 ? nx.mx / ox.mx : 0.0),
                  y: pt.y * (ox.my > 1e-9 ? nx.my / ox.my : 0.0)),
          ],
        ),
        newFit,
        newVp,
      );
      kfs.clear();
      kfs.addAll(bakePathToKeyframes(newPath, newFit, newVp, prof.duration));
    }
    out[pid] = newPath == null
        ? prof.withKeyframes(kfs)
        : prof.copyWith(keyframes: List<Keyframe>.unmodifiable(kfs),
            path: newPath);
  });
  return out;
}
