/// Motion Path Engine conformance tests (spec §12).
///
/// Replays `test/golden/motion_paths.json` (produced by `python3 -m
/// motionshot.verify`) so the Dart preview, the Kotlin exporter and the
/// Python reference cannot drift apart.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:motionshot/core/models/motion_path.dart';
import 'package:motionshot/core/models/motion_profile.dart';
import 'package:motionshot/features/motion/camera_math.dart';
import 'package:motionshot/features/motion/random.dart';
import 'package:motionshot/features/motion/random_motion.dart';
import 'package:motionshot/features/motion_path/motion_path_engine.dart';

/// dart:math has no hypot; mirror the reference sqrt(x*x + y*y).
double _hypot(double a, double b) => math.sqrt(a * a + b * b);

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

/// The exact setup verify.py uses for the path goldens.
Viewport get _vp => const Viewport(16 / 9);
ImageFit get _fit => ImageFit.make(4032, 3024, _vp);
const double _duration = 5.0;

MotionPathSpec _specFrom(Map<String, dynamic> json) =>
    MotionPathSpec.fromJson(Map<String, dynamic>.from(json));

/// Re-runs the 40-draw sequence from the golden (deterministic).
List<String> _runRandomPresets() {
  final rng = Xorshift128Plus(photoSeed(2026, 'path-gen', 0));
  String? prev;
  final seq = <String>[];
  for (var k = 0; k < 40; k++) {
    final preset = pickPathPreset(rng, prev);
    generatePathProfile(
      rng: rng,
      intensity: 0.7,
      duration: _duration,
      fit: _fit,
      vp: _vp,
      seed: 12345,
      preset: preset,
    );
    seq.add(preset);
    prev = preset;
  }
  return seq;
}

List<MotionProfile> _runRandomProfiles() {
  final rng = Xorshift128Plus(photoSeed(2026, 'path-gen', 0));
  String? prev;
  final out = <MotionProfile>[];
  for (var k = 0; k < 40; k++) {
    final preset = pickPathPreset(rng, prev);
    out.add(generatePathProfile(
      rng: rng,
      intensity: 0.7,
      duration: _duration,
      fit: _fit,
      vp: _vp,
      seed: 12345,
      preset: preset,
    ));
    prev = preset;
  }
  return out;
}

void main() {
  group('motion path engine', () {
    test('LUT size is fixed', () {
      final g = _golden('motion_paths');
      expect(g['lutSize'], 4096);
      expect(kLutSize, 4096);
    });

    test('spec samples match the reference', () {
      final g = _golden('motion_paths');
      final specs = g['specs'] as Map<String, dynamic>;
      specs.forEach((name, entry) {
        final e = entry as Map<String, dynamic>;
        final spec = _specFrom(e['spec'] as Map<String, dynamic>);
        // Sanitizing a sanitized spec is a no-op (idempotence).
        final resan = sanitizePath(spec, _fit, _vp);
        expect(resan.preset, spec.preset, reason: '$name preset');
        expectClose(resan.radiusX, spec.radiusX, '$name radiusX', tol: 1e-12);
        expectClose(resan.centerX, spec.centerX, '$name centerX', tol: 1e-12);

        final lut = buildArcLut(spec);
        expectClose(lut.total, (e['total'] as num).toDouble(), '$name total');

        final rows = e['samples'] as List<dynamic>;
        for (final row in rows) {
          final r = row as List<dynamic>;
          final t = (r[0] as num).toDouble();
          final st = evaluatePath(spec, _fit, _vp, t, _duration);
          expectClose(st.x, (r[1] as num).toDouble(), '$name x@$t', tol: 1e-8);
          expectClose(st.y, (r[2] as num).toDouble(), '$name y@$t', tol: 1e-8);
          expectClose(st.scale, (r[3] as num).toDouble(), '$name s@$t',
              tol: 1e-8);
          expectClose(st.rotation, (r[4] as num).toDouble(), '$name r@$t',
              tol: 1e-8);
        }

        final ts = e['tangentStart'] as List<dynamic>;
        final te = e['tangentEnd'] as List<dynamic>;
        final start = pathTangent(spec, 0.0);
        final end = pathTangent(spec, 1.0);
        expectClose(start.x, (ts[0] as num).toDouble(), '$name tangentStart.x',
            tol: 1e-8);
        expectClose(start.y, (ts[1] as num).toDouble(), '$name tangentStart.y',
            tol: 1e-8);
        expectClose(end.x, (te[0] as num).toDouble(), '$name tangentEnd.x',
            tol: 1e-8);
        expectClose(end.y, (te[1] as num).toDouble(), '$name tangentEnd.y',
            tol: 1e-8);

        // Cover safety at every time (spec §12.6).
        for (var i = 0; i <= 100; i++) {
          final t = _duration * i / 100;
          final st = evaluatePath(spec, _fit, _vp, t, _duration);
          final he = halfExtent(_vp, st.scale, st.rotation);
          final bw = he.bw;
          final bh = he.bh;
          expect(bw <= _fit.iw + 1e-9 && bh <= _fit.ih + 1e-9, isTrue,
              reason: '$name cover@$i');
        }
      });
    });

    test('arc-length reparameterization is uniform', () {
      final g = _golden('motion_paths');
      final uniformity = g['uniformity'] as Map<String, dynamic>;
      final specs = g['specs'] as Map<String, dynamic>;
      uniformity.forEach((name, entry) {
        final spec =
            _specFrom(specs[name]['spec'] as Map<String, dynamic>);
        final lut = buildArcLut(spec);
        final pts = <({double x, double y})>[
          for (var j = 0; j <= 400; j++)
            rawPathPoint(spec, paramAtArc(spec, lut, lut.total * j / 400)),
        ];
        var maxD = 0.0;
        var minD = double.infinity;
        for (var j = 0; j < 400; j++) {
          final d = _hypot(pts[j + 1].x - pts[j].x,
              pts[j + 1].y - pts[j].y);
          maxD = math.max(maxD, d);
          minD = math.min(minD, d);
        }
        final ratio = maxD / minD;
        final golden = entry as Map<String, dynamic>;
        expectClose(lut.total, (golden['total'] as num).toDouble(),
            '$name total');
        expect(ratio, lessThan(1.03), reason: '$name ratio $ratio');
      });
    });

    test('closed paths meet at the seam', () {
      final g = _golden('motion_paths');
      final seams = g['seams'] as Map<String, dynamic>;
      final specs = g['specs'] as Map<String, dynamic>;
      const e = 1e-3;
      seams.forEach((name, entry) {
        final spec =
            _specFrom(specs[name]['spec'] as Map<String, dynamic>);
        final a = rawPathPoint(spec, 0.0);
        final b = rawPathPoint(spec, 1.0);
        final posJump = _hypot(a.x - b.x, a.y - b.y);
        final ta = pathTangent(spec, 0.0);
        final tb = pathTangent(spec, 1.0);
        var ang =
            (math.atan2(ta.y, ta.x) - math.atan2(tb.y, tb.x)).abs();
        ang = math.min(ang, 2 * math.pi - ang);
        final bound = 2 * math.pi * e * spec.turns + 0.005;
        final golden = entry as Map<String, dynamic>;
        expectClose(posJump, (golden['posJump'] as num).toDouble(),
            '$name posJump',
            tol: 1e-9);
        expectClose(ang, (golden['angleJump'] as num).toDouble(),
            '$name angleJump');
        expect(posJump, lessThan(1e-9), reason: '$name pos $posJump');
        expect(ang, lessThan(bound), reason: '$name angle $ang');
      });
    });

    test('baked keyframes track the path', () {
      final g = _golden('motion_paths');
      final bake = g['bake'] as Map<String, dynamic>;
      final specs = g['specs'] as Map<String, dynamic>;
      bake.forEach((name, entry) {
        final spec =
            _specFrom(specs[name]['spec'] as Map<String, dynamic>);
        final kfs = bakePathToKeyframes(spec, _fit, _vp, _duration);
        var maxPos = 0.0;
        var maxS = 0.0;
        for (var i = 0; i <= 25; i++) {
          final t = _duration * i / 25;
          final st = evaluatePath(spec, _fit, _vp, t, _duration);
          final bk = sampleKeyframes(kfs, t);
          maxPos = math.max(maxPos, math.max((st.x - bk.x).abs(),
              (st.y - bk.y).abs()));
          maxS = math.max(maxS, (st.scale - bk.scale).abs());
        }
        final golden = entry as Map<String, dynamic>;
        expectClose(maxPos, (golden['maxPosErr'] as num).toDouble(),
            '$name maxPosErr');
        expectClose(maxS, (golden['maxScaleErr'] as num).toDouble(),
            '$name maxScaleErr');
        expect(maxPos, lessThan(5e-3), reason: '$name pos $maxPos');
        expect(maxS, lessThan(2e-3), reason: '$name scale $maxS');
      });
    });

    test('centripetal Catmull-Rom is C1 at the waypoints', () {
      final g = _golden('motion_paths');
      final c1 = g['c1'] as Map<String, dynamic>;
      final specs = g['specs'] as Map<String, dynamic>;
      c1.forEach((name, worstGolden) {
        final spec =
            _specFrom(specs[name]['spec'] as Map<String, dynamic>);
        final pts = spec.points;
        final n = pts.length;
        var worst = 0.0;
        for (var i = 1; i < n - 1; i++) {
          final pL0 = i - 2 >= 0 ? pts[i - 2] : pts[0];
          final pR2 = i + 1 < n ? pts[i + 1] : pts[n - 1];
          final pR3 = i + 2 < n ? pts[i + 2] : pts[n - 1];
          final left = crSegmentDerivative(pL0, pts[i - 1], pts[i], pR2, true);
          final right =
              crSegmentDerivative(pts[i - 1], pts[i], pR2, pR3, false);
          worst = math.max(worst,
              math.max((left.x - right.x).abs(), (left.y - right.y).abs()));
        }
        expectClose(worst, (worstGolden as num).toDouble(), '$name c1',
            tol: 1e-9);
        expect(worst, lessThan(1e-9), reason: '$name c1 $worst');
      });
    });

    test('freehand smoothing pipeline', () {
      final g = _golden('motion_paths');
      final stroke = g['stroke'] as Map<String, dynamic>;
      final raw = (stroke['input'] as List<dynamic>)
          .map((e) {
            final p = e as List<dynamic>;
            return MotionPoint(x: (p[0] as num).toDouble(),
                y: (p[1] as num).toDouble());
          })
          .toList();
      final out = smoothStroke(raw);
      expect(out.length, 24);
      expect(out, smoothStroke(raw), reason: 'deterministic');
      final outArr = stroke['output'] as List<dynamic>;
      for (var i = 0; i < out.length; i++) {
        final p = outArr[i] as List<dynamic>;
        expectClose(out[i].x, (p[0] as num).toDouble(), 'stroke x$i',
            tol: 1e-9);
        expectClose(out[i].y, (p[1] as num).toDouble(), 'stroke y$i',
            tol: 1e-9);
      }
      // Endpoints are (nearly) preserved by the pipeline.
      expect(
          _hypot(out[0].x - raw[0].x, out[0].y - raw[0].y), lessThan(0.01));
      expect(_hypot(out.last.x - raw.last.x, out.last.y - raw.last.y),
          lessThan(0.01));
    });

    test('random curved motion matches the reference', () {
      final g = _golden('motion_paths');
      final random = g['random'] as Map<String, dynamic>;
      final presetSeq = random['presets'] as List<dynamic>;
      final seq = _runRandomPresets();
      for (var k = 0; k < presetSeq.length; k++) {
        expect(seq[k], presetSeq[k], reason: 'preset[$k]');
      }

      // The stored profiles (first five distinct presets) must re-bake to
      // the golden keyframes and carry the same path.
      final profiles = random['profiles'] as Map<String, dynamic>;
      final run = _runRandomProfiles();
      profiles.forEach((name, entry) {
        final prof = entry as Map<String, dynamic>;
        final idx = seq.indexWhere((p) => p == name);
        expect(idx, greaterThanOrEqualTo(0), reason: 'missing profile $name');
        final t = run[idx];
        expect(t.motionType.id, prof['motionType']);
        expectClose(t.intensity, (prof['intensity'] as num).toDouble(),
            '$name intensity',
            tol: 1e-12);
        expect(t.seed, (prof['seed'] as num).toInt());
        final gPath = prof['path'] as Map<String, dynamic>;
        final myPath = t.path!.toJson();
        gPath.forEach((key, value) {
          if (key == 'points') return;
          final mine = myPath[key];
          if (value is bool) {
            expect(mine, value, reason: '$name path.$key');
          } else if (value is num) {
            expectClose((mine as num).toDouble(), value.toDouble(),
                '$name path.$key',
                tol: 1e-12);
          } else {
            expect(mine, value, reason: '$name path.$key');
          }
        });
        expect((myPath['points'] as List).length,
            (gPath['points'] as List).length);
        final gKfs = prof['keyframes'] as List<dynamic>;
        expect(t.keyframes.length, gKfs.length);
        for (var i = 0; i < t.keyframes.length; i++) {
          final k = gKfs[i] as Map<String, dynamic>;
          final kf = t.keyframes[i];
          expectClose(kf.time, (k['time'] as num).toDouble(), '$name kf$i.t',
              tol: 1e-9);
          expectClose(kf.x, (k['x'] as num).toDouble(), '$name kf$i.x',
              tol: 1e-9);
          expectClose(kf.y, (k['y'] as num).toDouble(), '$name kf$i.y',
              tol: 1e-9);
          expectClose(kf.scale, (k['scale'] as num).toDouble(),
              '$name kf$i.s',
              tol: 1e-9);
          expectClose(kf.rotation, (k['rotation'] as num).toDouble(),
              '$name kf$i.r',
              tol: 1e-9);
        }
      });
    });

    test('spec JSON round-trip and lenient load', () {
      final spec = MotionPathSpec(
        preset: 'sCurve',
        centerX: 0.1,
        radiusX: 0.3,
        radiusY: 0.2,
        turns: 2,
        points: const [
          MotionPoint(x: -0.3, y: -0.1),
          MotionPoint(x: 0.2, y: 0.15),
          MotionPoint(x: 0.35, y: -0.2),
        ],
        isUserEdited: true,
      );
      final back = MotionPathSpec.fromJson(spec.toJson());
      expect(back.preset, spec.preset);
      expectClose(back.centerX, spec.centerX, 'centerX', tol: 1e-12);
      expect(back.points.length, 3);
      expectClose(back.points[1].x, spec.points[1].x, 'pt1.x', tol: 1e-12);
      expect(back.isUserEdited, isTrue);
      expect(back.isProtected, isTrue);

      expect(() => MotionPathSpec.fromJson(
          <String, dynamic>{'preset': 'not-a-preset'}),
          throwsFormatException);
    });

    test('sanitize keeps the whole path cover-safe', () {
      // A deliberately reckless spec must come back inside the bounds.
      final spec = MotionPathSpec(
        preset: 'circularCw',
        centerX: 5.0,
        centerY: -5.0,
        radiusX: 9.0,
        radiusY: 9.0,
        speed: 50,
        curvature: 4,
        startZoom: 1.0,
        endZoom: 1.0,
        startRotation: 1.2,
        endRotation: -1.2,
        points: const [
          MotionPoint(x: 3, y: 3),
          MotionPoint(x: -3, y: -3),
        ],
      );
      final s = sanitizePath(spec, _fit, _vp);
      final rMax = math.max(s.startRotation.abs(), s.endRotation.abs());
      final lim = maxPan(_fit, _vp, math.max(s.startZoom, s.endZoom), rMax);
      expect(s.centerX.abs(), lessThanOrEqualTo(lim.mx + 1e-12));
      expect(s.centerY.abs(), lessThanOrEqualTo(lim.my + 1e-12));
      expect(s.radiusX, lessThanOrEqualTo(lim.mx + 1e-12));
      expect(s.speed, inInclusiveRange(0.25, 3.0));
      expect(s.curvature, inInclusiveRange(0.0, 1.0));
      expect(s.points[0].x.abs(), lessThanOrEqualTo(lim.mx + 1e-12));
      // And every evaluated sample stays cover-safe.
      for (var i = 0; i <= 50; i++) {
        final t = _duration * i / 50;
        final st = evaluatePath(s, _fit, _vp, t, _duration);
        final he = halfExtent(_vp, st.scale, st.rotation);
        final bw = he.bw;
        final bh = he.bh;
        expect(bw <= _fit.iw + 1e-9 && bh <= _fit.ih + 1e-9, isTrue,
            reason: 'cover@$i');
      }
    });

    test('path progress holds the end pose after completion', () {
      // speed > 1 finishes early: progress is 1.0 at the end and constant
      // over the holding tail.
      final spec = MotionPathSpec(preset: 'circularCw', speed: 1.8);
      expectClose(progressAt(spec, 0.0, _duration), 0.0, 'p(0)');
      expectClose(progressAt(spec, _duration, _duration), 1.0, 'p(end)');
      final atFinish = progressAt(spec, _duration / 1.8, _duration);
      expectClose(atFinish, 1.0, 'p(finish)', tol: 1e-9);
      for (var i = 0; i <= 10; i++) {
        final t = _duration / 1.8 + _duration * i / 10;
        expect(progressAt(spec, t, _duration), 1.0, reason: 'hold@$t');
      }
    });
  });
}
