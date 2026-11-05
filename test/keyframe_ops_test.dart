/// Manual keyframe editing rules (product brief §6).
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:motionshot/core/models/keyframe.dart';
import 'package:motionshot/core/models/keyframe_ops.dart';
import 'package:motionshot/core/models/motion_profile.dart';
import 'package:motionshot/core/utils/easing.dart';
import 'package:motionshot/features/motion/camera_math.dart';

final _vp = const Viewport(16 / 9);
final _fit = ImageFit.make(4000, 3000, _vp);

List<Keyframe> _base() => const <Keyframe>[
      Keyframe(time: 0, x: 0, y: 0, scale: 1.1, easing: Easing.smoother),
      Keyframe(time: 5, x: 0.2, y: 0.1, scale: 1.4, easing: Easing.smoother),
    ];

void main() {
  test('inserting a keyframe does not change the visible motion', () {
    final kfs = _base();
    final mid = insertKeyframe(kfs, 2.5, sampler: sampleKeyframes);
    expect(mid.length, 3);
    expect(mid[1].time, 2.5);
    // Sample before and after insertion at many points: identical camera.
    for (var i = 0; i <= 20; i++) {
      final t = 5.0 * i / 20;
      // Skip the inserted keyframe itself: a cubic interpolation through a
      // mid point is not bit-identical, but the framing must be within 1e-3.
      final a = sampleKeyframes(kfs, t);
      final b = sampleKeyframes(mid, t);
      expect((a.x - b.x).abs(), lessThan(1e-3), reason: 'x at $t');
      expect((a.scale - b.scale).abs(), lessThan(1e-3), reason: 'scale at $t');
    }
  });

  test('structural keyframes cannot be removed', () {
    final kfs = _base();
    expect(() => removeKeyframe(kfs, 0),
        throwsA(isA<KeyframeEditException>()));
    expect(() => removeKeyframe(kfs, kfs.length - 1),
        throwsA(isA<KeyframeEditException>()));
    final withMid = insertKeyframe(kfs, 2.5, sampler: sampleKeyframes);
    expect(removeKeyframe(withMid, 1).length, 2);
  });

  test('moving a keyframe in time respects its neighbours', () {
    var kfs = insertKeyframe(_base(), 2.5, sampler: sampleKeyframes);
    kfs = insertKeyframe(kfs, 3.5, sampler: sampleKeyframes);
    final moved = moveKeyframeTime(kfs, 1, 10.0);
    expect(moved[1].time, lessThan(moved[2].time));
    final back = moveKeyframeTime(kfs, 2, -10.0);
    expect(back[2].time, greaterThan(back[1].time));
    // first keyframe stays pinned at zero
    expect(() => moveKeyframeTime(kfs, 0, 1.0),
        throwsA(isA<KeyframeEditException>()));
  });

  test('too many keyframes is refused, not silently dropped', () {
    var kfs = <Keyframe>[
      const Keyframe(time: 0, x: 0, y: 0, scale: 1.1),
    ];
    for (var i = 1; i <= 19; i++) {
      kfs = <Keyframe>[
        ...kfs,
        Keyframe(time: i * 0.2, x: 0, y: 0, scale: 1.1 + i * 0.01),
      ];
    }
    expect(kfs.length, 20);
    expect(() => insertKeyframe(kfs, 1.9, sampler: sampleKeyframes),
        throwsA(isA<KeyframeEditException>()));
  });

  test('retiming to a new duration preserves start and end framing', () {
    final kfs = <Keyframe>[
      const Keyframe(time: 0, x: 0, y: 0, scale: 1.0),
      const Keyframe(time: 2, x: 0.1, y: 0, scale: 1.5),
      const Keyframe(time: 4, x: 0, y: 0.1, scale: 1.2),
    ];
    final out = retimeToDuration(kfs, 10);
    expect(out.first.time, 0);
    expect(out.last.time, 10);
    expect(out[1].time, closeTo(5, 1e-9));
    expect(out.first.scale, 1.0);
    expect(out.last.scale, 1.2);
  });

  test('copy/paste rebases motion onto the target duration', () {
    final src = <Keyframe>[
      const Keyframe(time: 0, x: 0, y: 0, scale: 1.1),
      const Keyframe(time: 4, x: 0.05, y: 0, scale: 1.3),
    ];
    final pasted = copyMotion(src, 8);
    expect(pasted.last.time, 8);
    expect(pasted.last.x, 0.05);
  });

  test('sanitize fixes rotations that would crop the image', () {
    // 30 degrees at scale 1.0 is impossible: must be lifted to the safe scale.
    const bad = Keyframe(time: 0, x: 0, y: 0, scale: 1.0,
        rotation: 30 * math.pi / 180);
    final fixed = sanitize(<Keyframe>[bad, bad.copyWith(time: 5)], _fit, _vp);
    for (final k in fixed) {
      expect(k.scale,
          greaterThanOrEqualTo(
              minScaleAtRotation(_fit, _vp, k.rotation) - 1e-9));
    }
  });

  test('profile validation rejects degenerate motions', () {
    expect(
      () => const MotionProfile(keyframes: <Keyframe>[]).validate(),
      throwsA(isA<MotionProfileException>()),
    );
    expect(
      () => const MotionProfile(keyframes: <Keyframe>[
        Keyframe(time: 0, x: 0, y: 0, scale: 1),
      ]).validate(),
      throwsA(isA<MotionProfileException>()),
    );
    expect(
      () => const MotionProfile(keyframes: <Keyframe>[
        Keyframe(time: 0, x: 0, y: 0, scale: 1),
        Keyframe(time: 0.0001, x: 0, y: 0, scale: 1.2),
      ]).validate(),
      throwsA(isA<MotionProfileException>()),
    );
    expect(
      () => const MotionProfile(keyframes: <Keyframe>[
        Keyframe(time: 0, x: 0, y: 0, scale: 1),
        Keyframe(time: 5, x: 0, y: 0, scale: 1.2),
      ]).validate(),
      returnsNormally,
    );
  });

  test('four keyframes interpolate smoothly (no discontinuities)', () {
    final kfs = <Keyframe>[
      const Keyframe(time: 0, x: -0.2, y: 0, scale: 1.1, easing: Easing.smoother),
      const Keyframe(time: 1.5, x: 0.1, y: -0.1, scale: 1.4, easing: Easing.easeInOut),
      const Keyframe(time: 3, x: 0.05, y: 0.1, scale: 1.2, easing: Easing.linear),
      const Keyframe(time: 5, x: 0, y: 0, scale: 1.35, easing: Easing.smooth),
    ];
    var prev = sampleKeyframes(kfs, 0);
    var maxJump = 0.0;
    for (var i = 1; i <= 500; i++) {
      final t = 5.0 * i / 500;
      final cur = sampleKeyframes(kfs, t);
      maxJump = math.max(maxJump, (cur.x - prev.x).abs());
      maxJump = math.max(maxJump, (cur.scale - prev.scale).abs() * 0.1);
      prev = cur;
    }
    // A 0.3 camera-unit travel over 5s cannot produce a visible jump at 10ms.
    expect(maxJump, lessThan(0.01), reason: 'maxJump=$maxJump');
  });
}
