/// Cross-runtime conformance tests.
///
/// The JSON here is produced by `tools/validate` (the executable form of
/// docs/MOTION_SPEC.md). If these tests pass, the Dart preview shows exactly
/// what the Kotlin exporter will write — the core promise of the product.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:motionshot/core/constants/app_constants.dart';
import 'package:motionshot/core/models/keyframe.dart';
import 'package:motionshot/core/models/motion_profile.dart';
import 'package:motionshot/core/models/motion_type.dart';
import 'package:motionshot/core/utils/easing.dart';
import 'package:motionshot/features/motion/camera_math.dart';
import 'package:motionshot/features/motion/random.dart';
import 'package:motionshot/features/motion/random_motion.dart';
import 'package:motionshot/features/transitions/timeline_engine.dart';
import 'package:motionshot/core/models/transition.dart';

Map<String, dynamic> _golden(String name) {
  final f = File('test/golden/$name.json');
  if (!f.existsSync()) {
    fail('missing golden file test/golden/$name.json — '
        'run: python3 -m motionshot.verify inside tools/validate');
  }
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

void expectClose(double actual, double expected, String why,
    {double tol = 1e-6}) {
  expect((actual - expected).abs(), lessThanOrEqualTo(tol),
      reason: '$why: got $actual, expected $expected');
}

void main() {
  group('easing matches golden vectors', () {
    final golden = _golden('easing');
    for (final entry in golden.entries) {
      test(entry.key, () {
        final rows = (entry.value as List<dynamic>)
            .map((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
            .toList();
        final kind = entry.key == 'custom'
            ? Easing.custom
            : entry.key == 'custom_ez'
                ? Easing.custom
                : Easing.values.firstWhere((e) => e.name == entry.key);
        final curve = entry.key == 'custom'
            ? const <double>[0.25, 0.1, 0.25, 1.0]
            : entry.key == 'custom_ez'
                ? const <double>[0.42, 0.0, 0.58, 1.0]
                : null;
        for (final row in rows) {
          final t = row[0];
          final expected = row[1];
          expectClose(kind.apply(t, curve), expected, 'easing ${entry.key} at $t',
              tol: 1e-9);
        }
      });
    }
  });

  group('PRNG matches golden vectors', () {
    final golden = _golden('prng');

    test('fnv1a64', () {
      for (final row in (golden['fnv_positions'] as List<dynamic>)) {
        final pair = row as List<dynamic>;
        expect(fnv1a64(pair[0] as String), pair[1] as int,
            reason: 'fnv1a64("${pair[0]}")');
      }
    });

    test('photoSeed', () {
      for (var i = 0; i < 6; i++) {
        final seed = photoSeed(1, 'p$i', i);
        final expected =
            ((golden['photo_seeds'] as List<dynamic>)[i] as List<dynamic>)[0];
        expect(seed.toSigned(64), (expected as int).toSigned(64),
            reason: 'photoSeed(1, p$i, $i)');
      }
    });

    test('xorshift128+ stream', () {
      final rng = Xorshift128Plus(photoSeed(42, 'photo-a', 0));
      final expected = (golden['seed_42_photo_a'] as List<dynamic>)
          .map((e) => (e as int).toSigned(64))
          .toList();
      for (var i = 0; i < expected.length; i++) {
        expect(rng.nextU64().toSigned(64), expected[i], reason: 'draw $i');
      }
    });

    test('doubles', () {
      final rng = Xorshift128Plus(fnv1a64('MotionShot'));
      final expected = (golden['doubles'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      for (var i = 0; i < expected.length; i++) {
        expectClose(rng.nextDouble(), expected[i], 'double $i', tol: 1e-15);
      }
    });
  });

  group('keyframe sampling matches golden vectors', () {
    final golden = _golden('keyframes');
    final kfs = (golden['keyframes'] as List<dynamic>)
        .map((e) => Keyframe.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final rows = (golden['samples'] as List<dynamic>)
        .map((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
        .toList();

    test('51 samples across 4 keyframes', () {
      for (final row in rows) {
        final st = sampleKeyframes(kfs, row[0]);
        expectClose(st.x, row[1], 'x at ${row[0]}');
        expectClose(st.y, row[2], 'y at ${row[0]}');
        expectClose(st.scale, row[3], 'scale at ${row[0]}');
        expectClose(st.rotation, row[4], 'rotation at ${row[0]}');
      }
    });

    test('clamps outside the keyframe range', () {
      final before = sampleKeyframes(kfs, -5);
      final after = sampleKeyframes(kfs, 50);
      expectClose(before.x, kfs.first.x, 'before start');
      expectClose(after.x, kfs.last.x, 'after end');
      expectClose(after.rotation, kfs.last.rotation, 'end rotation');
    });

    test('scale interpolates in log space', () {
      // Halfway between 1.0 and 4.0 with linear easing must be 2.0, not 2.5.
      final lin = <Keyframe>[
        const Keyframe(time: 0, x: 0, y: 0, scale: 1.0, easing: Easing.linear),
        const Keyframe(time: 2, x: 0, y: 0, scale: 4.0, easing: Easing.linear),
      ];
      expectClose(sampleKeyframes(lin, 1).scale, 2.0, 'log-space zoom', tol: 1e-12);
    });

    test('rotation takes the shortest path', () {
      final kfs2 = <Keyframe>[
        const Keyframe(time: 0, x: 0, y: 0, scale: 1, rotation: 3.0,
            easing: Easing.linear),
        const Keyframe(time: 1, x: 0, y: 0, scale: 1, rotation: -3.0,
            easing: Easing.linear),
      ];
      final mid = sampleKeyframes(kfs2, 0.5).rotation;
      // 3.0 -> -3.0 must go through pi (3.14), not through 0.
      expect(mid.abs(), greaterThan(3.0), reason: 'mid=$mid');
      expect(mid.abs(), lessThan(math.pi + 0.01), reason: 'mid=$mid');
    });
  });

  group('camera math matches golden vectors', () {
    final golden = _golden('camera');
    final vp = Viewport(16 / 9);
    final fit = ImageFit.make(4000, 3000, vp);

    test('viewport and fit', () {
      expectClose(vp.vw, (golden['viewport16x9'] as Map)['vw'] as double, 'vw');
      expectClose(vp.vh, (golden['viewport16x9'] as Map)['vh'] as double, 'vh');
      expectClose(fit.iw, (golden['fit4000x3000'] as Map)['iw'] as double, 'iw');
      expectClose(fit.ih, (golden['fit4000x3000'] as Map)['ih'] as double, 'ih');
    });

    test('footprint, min scale, pan limits and clamping', () {
      for (final row in (golden['rows'] as List<dynamic>)) {
        final m = row as Map<String, dynamic>;
        final rot = (m['rotation'] as num).toDouble();
        final e = halfExtent(vp, 1.5, rot);
        expectClose(e.bw, (m['bw'] as num).toDouble(), 'bw @$rot');
        expectClose(e.bh, (m['bh'] as num).toDouble(), 'bh @$rot');
        expectClose(minScaleAtRotation(fit, vp, rot),
            (m['minScale'] as num).toDouble(), 'minScale @$rot');
        final lim = maxPan(fit, vp, 1.5, rot);
        expectClose(lim.mx, (m['maxPanX'] as num).toDouble(), 'maxPanX @$rot');
        expectClose(lim.my, (m['maxPanY'] as num).toDouble(), 'maxPanY @$rot');
        final clamped = clampCamera(
            CameraState(x: 0.9, y: -0.9, scale: 1.5, rotation: rot), fit, vp);
        final exp = (m['clamped'] as List<dynamic>)
            .map((v) => (v as num).toDouble())
            .toList();
        expectClose(clamped.x, exp[0], 'clamped x');
        expectClose(clamped.y, exp[1], 'clamped y');
      }
    });

    test('cover fit is exact for every aspect', () {
      for (final aspect in <double>[9 / 16, 1.0, 4 / 5, 16 / 9, 2.39]) {
        final v = Viewport(aspect);
        final f = ImageFit.make(3000, 4000, v);
        expectClose(minScaleAtRotation(f, v, 0.0), 1.0, 'cover $aspect');
      }
    });

    test('viewport corners invert the render transform', () {
      // The four corners of the visible area, converted to UV, must land inside
      // the image for a legal camera (the guarantee that there is no black).
      const cam = CameraState(x: 0.05, y: -0.02, scale: 1.3,
          rotation: 0.03);
      final corners = viewportCorners(cam, vp);
      expect(corners.length, 4);
      for (final c in corners) {
        final uv = imageToUv(c.x, c.y, fit);
        expect(uv.u, inInclusiveRange(-1e-9, 1 + 1e-9), reason: 'u=${uv.u}');
        expect(uv.v, inInclusiveRange(-1e-9, 1 + 1e-9), reason: 'v=${uv.v}');
      }
    });
  });

  group('generated profiles match the reference implementation', () {
    final golden = _golden('profiles');
    final vp = Viewport(16 / 9);
    final fit = ImageFit.make(4032, 3024, vp);

    test('all fifteen motion types', () {
      final types = golden['types'] as Map<String, dynamic>;
      expect(types.length, MotionType.values.length);
      for (final entry in types.entries) {
        final reference = MotionProfile.fromJson(
            Map<String, dynamic>.from(entry.value as Map));
        final rng = Xorshift128Plus(photoSeed(99, 'photo-x', 3));
        final mine = generateProfile(
          type: MotionType.parse(entry.key),
          intensity: 0.7,
          duration: 5.0,
          fit: fit,
          vp: vp,
          rng: rng,
          seed: 12345,
        );
        expect(mine.keyframes.length, reference.keyframes.length,
            reason: 'keyframe count for ${entry.key}');
        for (var i = 0; i < mine.keyframes.length; i++) {
          expect(mine.keyframes[i].time, reference.keyframes[i].time,
              reason: '${entry.key} kf$i time');
          expectClose(mine.keyframes[i].x, reference.keyframes[i].x,
              '${entry.key} kf$i x', tol: 1e-9);
          expectClose(mine.keyframes[i].y, reference.keyframes[i].y,
              '${entry.key} kf$i y', tol: 1e-9);
          expectClose(mine.keyframes[i].scale, reference.keyframes[i].scale,
              '${entry.key} kf$i scale', tol: 1e-9);
          expectClose(mine.keyframes[i].rotation, reference.keyframes[i].rotation,
              '${entry.key} kf$i rotation', tol: 1e-9);
        }
        expect(mine.motionType.id, reference.motionType.id);
      }
    });

    test('auto motion sequence is reproducible', () {
      final expected = (golden['auto_types'] as List<dynamic>).cast<String>();
      final photos = <MotionSource>[
        for (var i = 0; i < 8; i++)
          MotionSource(
            photoId: 'p$i',
            srcWidth: 4032,
            srcHeight: 3024,
            duration: 5.0,
          ),
      ];
      final built = buildProfiles(
        photos: photos,
        viewport: vp,
        projectSeed: 2024,
        intensity: 0.65,
        regenerate: true,
      );
      final got = [for (final p in photos) built[p.photoId]!.motionType.id];
      expect(got, expected);
      // No two neighbours share a motion type (spec §10 rule 1).
      for (var i = 1; i < got.length; i++) {
        expect(got[i], isNot(got[i - 1]));
      }
    });

    test('locked photos survive regeneration', () {
      final reference = golden['locked_after_regen'] as Map<String, dynamic>;
      final photos = <MotionSource>[
        for (var i = 0; i < 8; i++)
          MotionSource(
            photoId: 'p$i',
            srcWidth: 4032,
            srcHeight: 3024,
            duration: 5.0,
            existing: i == 0
                ? MotionProfile.fromJson(Map<String, dynamic>.from(
                        (golden['auto'] as Map<String, dynamic>)['p0'] as Map))
                    .copyWith(isLocked: true)
                : null,
          ),
      ];
      final built = buildProfiles(
        photos: photos,
        viewport: vp,
        projectSeed: 9999,
        intensity: 0.9,
        regenerate: true,
      );
      final expected = MotionProfile.fromJson(
          Map<String, dynamic>.from(reference['p0'] as Map));
      expect(built['p0']!.motionType, expected.motionType);
      expect(built['p0']!.isLocked, isTrue);
      for (var i = 0; i < built['p0']!.keyframes.length; i++) {
        expectClose(built['p0']!.keyframes[i].x, expected.keyframes[i].x,
            'locked kf x');
      }
    });

    test('every generated motion stays inside the image', () {
      for (final type in MotionType.values) {
        for (final intensity in <double>[0.0, 0.5, 1.0]) {
          for (final aspect in <double>[9 / 16, 1.0, 16 / 9]) {
            final v = Viewport(aspect);
            final f = ImageFit.make(4032, 3024, v);
            final rng = Xorshift128Plus(photoSeed(5, type.id, 1));
            final prof = generateProfile(
              type: type,
              intensity: intensity,
              duration: 6.0,
              fit: f,
              vp: v,
              rng: rng,
              seed: 5,
            );
            for (var i = 0; i <= 40; i++) {
              final st = prof.sample(6.0 * i / 40, f, v);
              final e = halfExtent(v, st.scale, st.rotation);
              expect(e.bw, lessThanOrEqualTo(f.iw + 1e-9),
                  reason: '${type.id} @$intensity aspect=$aspect sample $i');
              expect(e.bh, lessThanOrEqualTo(f.ih + 1e-9),
                  reason: '${type.id} @$intensity aspect=$aspect sample $i');
            }
          }
        }
      }
    });
  });

  group('transitions match golden vectors', () {
    final golden = _golden('transitions');

    test('nine types, coverage invariant', () {
      for (final type in TransitionType.values) {
        final rows = (golden[type.id] as List<dynamic>)
            .map((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
            .toList();
        for (final row in rows) {
          final p = row[0];
          final layers = <TimelineLayer>[
            TimelineLayer(
                photoIndex: 0,
                localTime: 1,
                role: LayerRole.outPhoto,
                progress: p,
                transitionType: type),
            TimelineLayer(
                photoIndex: 1,
                localTime: 0.5,
                role: LayerRole.inPhoto,
                progress: p,
                transitionType: type),
          ];
          final draw = transitionDrawLayers(layers);
          expectClose(draw[0].alpha, row[1], '${type.id} out alpha @$p');
          expectClose(draw[1].alpha, row[2], '${type.id} in alpha @$p');
          expectClose(draw[0].offsetX, row[3], '${type.id} out offset @$p');
          expectClose(draw[1].offsetX, row[4], '${type.id} in offset @$p');
          if (type != TransitionType.fadeToBlack) {
            if (type == TransitionType.slideLeft ||
                type == TransitionType.slideRight) {
              final span = (draw[1].offsetX - draw[0].offsetX).abs();
              expectClose(span, 1.0, '${type.id} tiling @$p');
            } else {
              expectClose(draw[0].alpha + draw[1].alpha, 1.0,
                  '${type.id} alpha sum @$p');
            }
          }
        }
      }
    });

    test('timeline layer resolution matches the reference', () {
      final tl = golden['timeline'] as Map<String, dynamic>;
      final durs = (tl['durations'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      final trans = (tl['transitions'] as List<dynamic>)
          .map((e) => TransitionSpec.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      for (final row in (tl['rows'] as List<dynamic>)) {
        final r = row as List<dynamic>;
        final t = (r[0] as num).toDouble();
        final expected = (r[1] as List<dynamic>);
        final got = resolveLayers(t, durs, trans);
        expect(got.length, expected.length, reason: 'layer count at $t');
        for (var i = 0; i < got.length; i++) {
          final e = expected[i] as List<dynamic>;
          expect(got[i].photoIndex, e[0], reason: 'photoIndex at $t');
          expectClose(got[i].localTime, (e[2] as num).toDouble(),
              'localTime at $t');
          expectClose(got[i].progress, (e[3] as num).toDouble(),
              'progress at $t');
        }
      }
    });

    test('a transition never exceeds either neighbour', () {
      final durs = <double>[1.0, 4.0];
      final trans = <TransitionSpec>[
        const TransitionSpec(type: TransitionType.crossDissolve, duration: 3.0),
      ];
      expectClose(clampedTransitionSeconds(0, durs, trans), 1.0, 'clamped');
      final layers = resolveLayers(0.6, durs, trans);
      expect(layers.length, 1, reason: 'window is 0.5s wide around 1.0s');
      expect(layers, isNotEmpty);
    });

    test('no transitions means exactly one layer everywhere', () {
      final durs = <double>[2.0, 2.0, 2.0];
      final trans = <TransitionSpec>[
        const TransitionSpec(type: TransitionType.none),
        const TransitionSpec(type: TransitionType.none),
      ];
      for (var t = 0.0; t < 6.0; t += 0.05) {
        expect(resolveLayers(t, durs, trans).length, 1,
            reason: 't=$t must be a hard cut');
      }
    });
  });

  group('encoding math matches golden vectors', () {
    final golden = _golden('encoding');

    test('all 108 bitrate combinations', () {
      for (final raw in (golden['bitrates'] as List<dynamic>)) {
        final row = raw as List<dynamic>;
        final w = (row[0] as num).toInt();
        final h = (row[1] as num).toInt();
        final fps = (row[2] as num).toInt();
        final q = QualityPreset.values.firstWhere((e) => e.id == row[3]);
        final c = VideoCodecPreset.values.firstWhere((e) => e.id == row[4]);
        final expected = (row[5] as num).toInt();
        expect(
          deriveBitrate(width: w, height: h, fps: fps, quality: q, codec: c),
          expected,
          reason: '${w}x$h@$fps ${q.id}/${c.id}',
        );
      }
    });

    test('even-dimension rounding', () {
      for (final raw in (golden['roundEven'] as List<dynamic>)) {
        final pair = raw as List<dynamic>;
        final v = (pair[0] as num).toInt();
        final expected = (pair[1] as num).toInt();
        expect(outputDimensions(1.0, v).width, expected, reason: 'roundEven($v)');
      }
    });
  });
}
