/// Motion Path Engine — Dart port of docs/MOTION_SPEC.md §12 and
/// `tools/validate/motionshot/motion_path.py`.
///
/// This is the *same* math the Kotlin renderer runs
/// (`MotionPathEngine.kt`), so the on-screen preview and the exported MP4
/// show the identical camera trajectory. Operation order is part of the
/// contract — do not "simplify" expressions without regenerating the golden
/// vectors (`python3 -m motionshot.verify`).
library;

import 'dart:math' as math;

import '../../core/models/motion_path.dart';
import '../motion/camera_math.dart';
import '../../core/models/keyframe.dart';
import '../../core/utils/easing.dart';

// ---------------------------------------------------------------------------
// constants (spec §12.2) — must match the Python reference and Kotlin.
// ---------------------------------------------------------------------------

/// Arc-length lookup table resolution (fixed, all runtimes).
const int kLutSize = 4096;

/// Local sub-chord refinement inside one LUT cell (and sub-chords used when
/// building each cell).
const int kRefineSteps = 16;

/// Spiral start radius as a fraction of the full radius:
/// rho(u) = lerp(rho0, 1, u), rho0 = 0.15 + 0.75 * (1 - curvature).
const double kSpiralRho0Min = 0.15;
const double kSpiralRho0Range = 0.75;

// freehand stroke pipeline (spec §12.5)
const double kStrokeDedupeMinDist = 0.004;
const int kStrokeTargetPoints = 24;
const int kChaikinIters = 2;

const double kScalePad = 1.002;

// ---------------------------------------------------------------------------
// preset parameter resolution (spec §12.3)
// ---------------------------------------------------------------------------

({MotionPoint a, MotionPoint b}) _linearEndpoints(MotionPathSpec spec) {
  if (spec.points.length >= 2) {
    return (a: spec.points[0], b: spec.points[1]);
  }
  return (
    a: MotionPoint(x: spec.centerX - spec.radiusX, y: spec.centerY - spec.radiusY),
    b: MotionPoint(x: spec.centerX + spec.radiusX, y: spec.centerY + spec.radiusY),
  );
}

List<MotionPoint> _sCurveWaypoints(MotionPathSpec spec) {
  if (spec.points.length >= 3) return List<MotionPoint>.of(spec.points);
  final bend = (2.0 * spec.curvature - 1.0) * spec.radiusY;
  return <MotionPoint>[
    MotionPoint(x: spec.centerX - spec.radiusX, y: spec.centerY + bend),
    MotionPoint(x: spec.centerX, y: spec.centerY),
    MotionPoint(x: spec.centerX + spec.radiusX, y: spec.centerY - bend),
  ];
}

List<MotionPoint> _bezierPoints(MotionPathSpec spec) {
  if (spec.points.length >= 4) return List<MotionPoint>.of(spec.points.sublist(0, 4));
  final bend = (2.0 * spec.curvature - 1.0) * spec.radiusY;
  return <MotionPoint>[
    MotionPoint(x: spec.centerX - spec.radiusX, y: spec.centerY),
    MotionPoint(x: spec.centerX - spec.radiusX * 0.5, y: spec.centerY + bend),
    MotionPoint(x: spec.centerX + spec.radiusX * 0.5, y: spec.centerY - bend),
    MotionPoint(x: spec.centerX + spec.radiusX, y: spec.centerY),
  ];
}

// Half-up tie-breaking (roundToDouble) so all three runtimes agree at
// exact .5 values; Python's banker's round() would differ.
double _snapTurns(MotionPathSpec spec) {
  if (spec.preset == 'figureEight') {
    return spec.turns >= 0.5 ? spec.turns.roundToDouble() : 1.0;
  }
  return spec.turns;
}

// ---------------------------------------------------------------------------
// centripetal Catmull-Rom (alpha = 0.5), spec §12.4
// ---------------------------------------------------------------------------

/// One centripetal CR segment from p1 to p2, local parameter w in [0,1].
///
/// Barry-Goldman non-uniform formulation with centripetal knots
/// t_k = t_{k-1} + |p_k - p_{k-1}|^0.5, evaluated in the de Casteljau style
/// in the knot parameter ts = t1 + (t2-t1)*w:
///
/// ```
/// a1 = (p0*(t1-ts) - p1*(t0-ts)) / (t1-t0)
/// a2 = (p1*(t2-ts) - p2*(t1-ts)) / (t2-t1)
/// a3 = (p2*(t3-ts) - p3*(t2-ts)) / (t3-t2)
/// b1 = (a1*(t2-ts) - a2*(t0-ts)) / (t2-t0)
/// b2 = (a2*(t3-ts) - a3*(t1-ts)) / (t3-t1)
/// c  = (b1*(t2-ts) - b2*(t1-ts)) / (t2-t1)
/// ```
///
/// C1 at the waypoints and cusp-free; the Python reference and the Kotlin
/// port reproduce every operation in this exact order.
({double x, double y}) _crSegment(MotionPoint p0, MotionPoint p1,
    MotionPoint p2, MotionPoint p3, double w) {
  final t0 = 0.0;
  final t1 = t0 +
      math.sqrt(math.hypot(p1.x - p0.x, p1.y - p0.y));
  final t2 = t1 + math.sqrt(math.hypot(p2.x - p1.x, p2.y - p1.y));
  final t3 = t2 + math.sqrt(math.hypot(p3.x - p2.x, p3.y - p2.y));
  if (t2 - t1 < 1e-12) {
    return (x: p1.x, y: p1.y); // degenerate segment: p1 == p2
  }
  final ts = t1 + (t2 - t1) * w;
  final t0s = t0 - ts;
  final t1s = t1 - ts;
  final t2s = t2 - ts;
  final t3s = t3 - ts;
  double a1x, a1y;
  if (t1 - t0 < 1e-12) {
    a1x = p1.x;
    a1y = p1.y;
  } else {
    a1x = (p0.x * t1s - p1.x * t0s) / (t1 - t0);
    a1y = (p0.y * t1s - p1.y * t0s) / (t1 - t0);
  }
  final a2x = (p1.x * t2s - p2.x * t1s) / (t2 - t1);
  final a2y = (p1.y * t2s - p2.y * t1s) / (t2 - t1);
  double a3x, a3y;
  if (t3 - t2 < 1e-12) {
    a3x = p2.x;
    a3y = p2.y;
  } else {
    a3x = (p2.x * t3s - p3.x * t2s) / (t3 - t2);
    a3y = (p2.y * t3s - p3.y * t2s) / (t3 - t2);
  }
  double b1x, b1y;
  if (t2 - t0 < 1e-12) {
    b1x = a1x;
    b1y = a1y;
  } else {
    b1x = (a1x * t2s - a2x * t0s) / (t2 - t0);
    b1y = (a1y * t2s - a2y * t0s) / (t2 - t0);
  }
  double b2x, b2y;
  if (t3 - t1 < 1e-12) {
    b2x = a2x;
    b2y = a2y;
  } else {
    b2x = (a2x * t3s - a3x * t1s) / (t3 - t1);
    b2y = (a2y * t3s - a3y * t1s) / (t3 - t1);
  }
  return (
    x: (b1x * t2s - b2x * t1s) / (t2 - t1),
    y: (b1y * t2s - b2y * t1s) / (t2 - t1),
  );
}

/// Exact dc/dts of [_crSegment] at the segment start (`atEnd == false`,
/// ts=t1) or end (`atEnd == true`, ts=t2), by differentiating the
/// Barry-Goldman scheme:
///
/// ```
/// a1' = (p1-p0)/(t1-t0)          a2' = (p2-p1)/(t2-t1)
/// a3' = (p3-p2)/(t3-t2)
/// b1' = (a1'*(t2-ts) - a2'*(t0-ts) - a1 + a2) / (t2-t0)
/// b2' = (a2'*(t3-ts) - a3'*(t1-ts) - a2 + a3) / (t3-t1)
/// c'  = (b1'*(t2-ts) - b2'*(t1-ts) - b1 + b2) / (t2-t1)
/// ```
///
/// Used by the C1 continuity invariant in the conformance tests.
({double x, double y}) crSegmentDerivative(
  MotionPoint p0,
  MotionPoint p1,
  MotionPoint p2,
  MotionPoint p3,
  bool atEnd,
) {
  final t0 = 0.0;
  final t1 = t0 + math.sqrt(math.hypot(p1.x - p0.x, p1.y - p0.y));
  final t2 = t1 + math.sqrt(math.hypot(p2.x - p1.x, p2.y - p1.y));
  final t3 = t2 + math.sqrt(math.hypot(p3.x - p2.x, p3.y - p2.y));
  if (t2 - t1 < 1e-12) return (x: 0.0, y: 0.0);
  final ts = atEnd ? t2 : t1;
  final t0s = t0 - ts;
  final t1s = t1 - ts;
  final t2s = t2 - ts;
  final t3s = t3 - ts;
  double a1dx, a1dy;
  if (t1 - t0 < 1e-12) {
    a1dx = 0.0;
    a1dy = 0.0;
  } else {
    a1dx = (p1.x - p0.x) / (t1 - t0);
    a1dy = (p1.y - p0.y) / (t1 - t0);
  }
  final a2dx = (p2.x - p1.x) / (t2 - t1);
  final a2dy = (p2.y - p1.y) / (t2 - t1);
  double a3dx, a3dy;
  if (t3 - t2 < 1e-12) {
    a3dx = 0.0;
    a3dy = 0.0;
  } else {
    a3dx = (p3.x - p2.x) / (t3 - t2);
    a3dy = (p3.y - p2.y) / (t3 - t2);
  }
  double a1x, a1y;
  if (t1 - t0 < 1e-12) {
    a1x = p1.x;
    a1y = p1.y;
  } else {
    a1x = (p0.x * t1s - p1.x * t0s) / (t1 - t0);
    a1y = (p0.y * t1s - p1.y * t0s) / (t1 - t0);
  }
  final a2x = (p1.x * t2s - p2.x * t1s) / (t2 - t1);
  final a2y = (p1.y * t2s - p2.y * t1s) / (t2 - t1);
  double a3x, a3y;
  if (t3 - t2 < 1e-12) {
    a3x = p2.x;
    a3y = p2.y;
  } else {
    a3x = (p2.x * t3s - p3.x * t2s) / (t3 - t2);
    a3y = (p2.y * t3s - p3.y * t2s) / (t3 - t2);
  }
  double b1x, b1y;
  if (t2 - t0 < 1e-12) {
    b1x = a1x;
    b1y = a1y;
  } else {
    b1x = (a1x * t2s - a2x * t0s) / (t2 - t0);
    b1y = (a1y * t2s - a2y * t0s) / (t2 - t0);
  }
  double b2x, b2y;
  if (t3 - t1 < 1e-12) {
    b2x = a2x;
    b2y = a2y;
  } else {
    b2x = (a2x * t3s - a3x * t1s) / (t3 - t1);
    b2y = (a2y * t3s - a3y * t1s) / (t3 - t1);
  }
  double b1dx, b1dy;
  if (t2 - t0 < 1e-12) {
    b1dx = 0.0;
    b1dy = 0.0;
  } else {
    b1dx = (a1dx * t2s - a2dx * t0s - a1x + a2x) / (t2 - t0);
    b1dy = (a1dy * t2s - a2dy * t0s - a1y + a2y) / (t2 - t0);
  }
  double b2dx, b2dy;
  if (t3 - t1 < 1e-12) {
    b2dx = 0.0;
    b2dy = 0.0;
  } else {
    b2dx = (a2dx * t3s - a3dx * t1s - a2x + a3x) / (t3 - t1);
    b2dy = (a2dy * t3s - a3dy * t1s - a2y + a3y) / (t3 - t1);
  }
  return (
    x: (b1dx * t2s - b2dx * t1s - b1x + b2x) / (t2 - t1),
    y: (b1dy * t2s - b2dy * t1s - b1y + b2y) / (t2 - t1),
  );
}

/// CR spline through [pts], global parameter u in [0,1] (uniform per
/// segment; the arc-length LUT corrects the resulting speed).
({double x, double y}) _catmullRom(List<MotionPoint> pts, double u) {
  final n = pts.length - 1; // number of segments
  if (n <= 0) return (x: pts[0].x, y: pts[0].y);
  final uu = u < 0.0 ? 0.0 : (u > 1.0 ? 1.0 : u);
  final g = uu * n;
  var seg = g.toInt();
  if (seg >= n) seg = n - 1;
  final w = g - seg;
  final p0 = seg >= 1 ? pts[seg - 1] : pts[0];
  final p1 = pts[seg];
  final p2 = pts[seg + 1];
  final p3 = seg + 2 < pts.length ? pts[seg + 2] : pts[pts.length - 1];
  return _crSegment(p0, p1, p2, p3, w);
}

// ---------------------------------------------------------------------------
// raw parametric point, spec §12.3
// ---------------------------------------------------------------------------

/// Camera position at path parameter u in [0,1] (BEFORE arc-length
/// re-parameterization, BEFORE the safety clamp).
({double x, double y}) rawPathPoint(MotionPathSpec spec, double u) {
  final uu = u < 0.0 ? 0.0 : (u > 1.0 ? 1.0 : u);
  final cx = spec.centerX;
  final cy = spec.centerY;
  final rx = spec.radiusX;
  final ry = spec.radiusY;
  final d = spec.direction;

  switch (spec.preset) {
    case 'linear':
      final e = _linearEndpoints(spec);
      return (
        x: lerpDouble(e.a.x, e.b.x, uu),
        y: lerpDouble(e.a.y, e.b.y, uu),
      );
    case 'circularCw':
    case 'circularCcw':
    case 'elliptical':
      final theta = spec.startAngle + d * 2.0 * math.pi * spec.turns * uu;
      return (x: cx + rx * math.cos(theta), y: cy + ry * math.sin(theta));
    case 'arc':
      final theta = spec.startAngle + d * spec.sweep * uu;
      return (x: cx + rx * math.cos(theta), y: cy + ry * math.sin(theta));
    case 'spiral':
      final rho0 = kSpiralRho0Min + kSpiralRho0Range * (1.0 - spec.curvature);
      final rho = lerpDouble(rho0, 1.0, uu);
      final theta = spec.startAngle + d * 2.0 * math.pi * spec.turns * uu;
      return (
        x: cx + rx * rho * math.cos(theta),
        y: cy + ry * rho * math.sin(theta),
      );
    case 'figureEight':
      final k = _snapTurns(spec);
      final a = 2.0 * math.pi * k * uu;
      final x = cx + rx * math.sin(a);
      final y = cy + ry * math.sin(a) * math.cos(a);
      return (x: x, y: y);
    case 'sCurve':
      return _catmullRom(_sCurveWaypoints(spec), uu);
    case 'cubicBezier':
      final p = _bezierPoints(spec);
      final iu = 1.0 - uu;
      final a = iu * iu * iu;
      final b = 3.0 * iu * iu * uu;
      final c = 3.0 * iu * uu * uu;
      final dd = uu * uu * uu;
      return (
        x: a * p[0].x + b * p[1].x + c * p[2].x + dd * p[3].x,
        y: a * p[0].y + b * p[1].y + c * p[2].y + dd * p[3].y,
      );
    case 'custom':
      final pts = spec.points;
      if (pts.isEmpty) return (x: cx, y: cy);
      if (pts.length == 1) return (x: pts[0].x, y: pts[0].y);
      return _catmullRom(pts, uu);
    default:
      throw ArgumentError('unknown path preset ${spec.preset}');
  }
}

/// Normalized tangent at u (one-sided at the ends so u=0 and u=1 give the
/// true seam tangents of closed paths). Used by the editor arrows.
({double x, double y}) pathTangent(MotionPathSpec spec, double u) {
  const e = 1e-3;
  ({double x, double y}) a, b;
  if (u <= e) {
    a = rawPathPoint(spec, 0.0);
    b = rawPathPoint(spec, u + e);
  } else if (u >= 1.0 - e) {
    a = rawPathPoint(spec, u - e);
    b = rawPathPoint(spec, 1.0);
  } else {
    a = rawPathPoint(spec, u - e);
    b = rawPathPoint(spec, u + e);
  }
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final m = math.hypot(dx, dy);
  if (m < 1e-12) return (x: 0.0, y: 0.0);
  return (x: dx / m, y: dy / m);
}

// ---------------------------------------------------------------------------
// arc-length re-parameterization, spec §12.2
// ---------------------------------------------------------------------------

class MotionPathLut {
  const MotionPathLut(this.cum, this.total);

  /// Cumulative chord-arc table: cum[i] for i in 0..kLutSize.
  final List<double> cum;
  final double total;
}

final Map<int, MotionPathLut> _lutCache = <int, MotionPathLut>{};

/// Chord-length lookup table over the raw parametric curve.
///
/// cum[i] = arc length from u=0 to u=i/kLutSize. Each cell is summed from
/// [kRefineSteps] sub-chords (a single chord would bias the cumulative arc
/// in high-curvature regions) and the whole table is accumulated with one
/// sequential pass so every runtime sums the same doubles in the same
/// order. The table depends only on the spec, so it is cached per path.
MotionPathLut buildArcLut(MotionPathSpec spec) {
  final hit = _lutCache[spec.hashCode];
  if (hit != null) return hit;
  final cum = List<double>.filled(kLutSize + 1, 0.0);
  final du = 1.0 / kLutSize;
  var p = rawPathPoint(spec, 0.0);
  for (var i = 1; i <= kLutSize; i++) {
    var s = 0.0;
    for (var k = 1; k <= kRefineSteps; k++) {
      final q = rawPathPoint(spec, (i - 1) * du + du * k / kRefineSteps);
      s = s + math.hypot(q.x - p.x, q.y - p.y);
      p = q;
    }
    cum[i] = cum[i - 1] + s;
  }
  final lut = MotionPathLut(cum, cum[kLutSize]);
  _lutCache[spec.hashCode] = lut;
  return lut;
}

/// Inverse arc lookup: path parameter u for arc-length [target].
///
/// Two levels (identical in every runtime):
///   1. coarse — binary search for the first i with cum[i] >= target;
///   2. fine   — kRefineSteps sub-chords inside that single LUT cell,
///               binary search + linear interpolation again.
/// Level 2 removes the chord nonlinearity of the parametric curve (the
/// Catmull-Rom spline is strongly non-uniform in u) so the camera speed is
/// uniform to ~1e-8.
double paramAtArc(MotionPathSpec spec, MotionPathLut lut, double target) {
  final total = lut.total;
  final cum = lut.cum;
  if (target <= 0.0 || total <= 1e-9) return 0.0;
  if (target >= total) return 1.0;
  var lo = 0;
  var hi = kLutSize;
  while (lo + 1 < hi) {
    final mid = (lo + hi) ~/ 2;
    if (cum[mid] >= target) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  final i0 = hi - 1;
  final d = cum[hi] - cum[i0];
  if (d < 1e-12) return (i0 + 0.5) / kLutSize;
  final u0 = i0 / kLutSize;
  final du = 1.0 / kLutSize;
  const n = kRefineSteps;
  var p = rawPathPoint(spec, u0);
  final c = List<double>.filled(n + 1, 0.0);
  for (var k = 1; k <= n; k++) {
    final q = rawPathPoint(spec, u0 + du * k / n);
    c[k] = c[k - 1] + math.hypot(q.x - p.x, q.y - p.y);
    p = q;
  }
  final cTotal = c[n];
  if (cTotal < 1e-12) return u0 + du * (target - cum[i0]) / d;
  final local = (target - cum[i0]) * (cTotal / d);
  var lo2 = 0;
  var hi2 = n;
  while (lo2 + 1 < hi2) {
    final mid = (lo2 + hi2) ~/ 2;
    if (c[mid] >= local) {
      hi2 = mid;
    } else {
      lo2 = mid;
    }
  }
  final j0 = hi2 - 1;
  final dd = c[hi2] - c[j0];
  if (dd < 1e-12) return u0 + du * (j0 + 0.5) / n;
  return u0 + du * (j0 + (local - c[j0]) / dd) / n;
}

// ---------------------------------------------------------------------------
// time -> progress -> camera state
// ---------------------------------------------------------------------------

/// Path progress p in [0,1] at local time t (spec §12.6).
///
/// q = t/duration; p = q*speed (capped at 1: the path completes early and
/// the camera holds its end pose); speedEase blends the raw linear progress
/// towards a smootherstep velocity profile.
double progressAt(MotionPathSpec spec, double t, double duration) {
  if (duration <= 1e-9) return 1.0;
  var q = t / duration;
  if (q < 0.0) {
    q = 0.0;
  } else if (q > 1.0) {
    q = 1.0;
  }
  var p = q * spec.speed;
  if (p > 1.0) p = 1.0;
  if (spec.speedEase > 0.0) {
    final e = p * p * p * (p * (6.0 * p - 15.0) + 10.0);
    p = p + spec.speedEase * (e - p);
  }
  if (p < 0.0) p = 0.0;
  return p;
}

/// The unified camera evaluation used by preview AND export (spec §12.6).
CameraState evaluatePath(MotionPathSpec spec, ImageFit fit, Viewport vp,
    double t, double duration) {
  final lut = buildArcLut(spec);
  final p = progressAt(spec, t, duration);
  final u = paramAtArc(spec, lut, p * lut.total);
  final pt = rawPathPoint(spec, u);
  final s = logLerp(spec.startZoom, spec.endZoom, p);
  final r =
      spec.startRotation + shortestAngle(spec.startRotation, spec.endRotation) * p;
  return clampCamera(
      CameraState(x: pt.x, y: pt.y, scale: s, rotation: r), fit, vp);
}

/// High-resolution keyframes of the path (spec §12.8). The baked list is
/// the export fallback and the editor's read-only sample strip; the
/// renderer evaluates the path directly. Segment easing is `linear`
/// because consecutive samples of a smooth path are connected by
/// near-straight chords.
List<Keyframe> bakePathToKeyframes(MotionPathSpec spec, ImageFit fit,
    Viewport vp, double duration,
    {int samples = 128}) {
  final kfs = <Keyframe>[];
  for (var i = 0; i <= samples; i++) {
    final t = duration * i / samples;
    final st = evaluatePath(spec, fit, vp, t, duration);
    kfs.add(Keyframe(
        time: t,
        x: st.x,
        y: st.y,
        scale: st.scale,
        rotation: st.rotation,
        easing: Easing.linear));
  }
  kfs[0] = kfs[0].copyWith(time: 0.0);
  kfs[kfs.length - 1] = kfs[kfs.length - 1].copyWith(time: duration);
  return kfs;
}

// ---------------------------------------------------------------------------
// safety / authoring guards, spec §12.6 + §12.9
// ---------------------------------------------------------------------------

double _clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Clamps every authoring field so the whole path stays cover-safe even at
/// the maximum zoom / rotation the envelope reaches.
MotionPathSpec sanitizePath(MotionPathSpec spec, ImageFit fit, Viewport vp) {
  final rMax =
      math.max(math.abs(spec.startRotation), math.abs(spec.endRotation));
  final sZoom = math.max(spec.startZoom, spec.endZoom);
  final sMin = minScaleAtRotation(fit, vp, rMax) * kScalePad;
  final startZoom = spec.startZoom >= sMin ? spec.startZoom : sMin;
  final endZoom = spec.endZoom >= sMin ? spec.endZoom : sMin;
  final lim = maxPan(fit, vp, math.max(startZoom, endZoom), rMax);
  final pts = spec.points
      .map((p) => MotionPoint(
          x: _clampD(p.x, -lim.mx, lim.mx), y: _clampD(p.y, -lim.my, lim.my)))
      .toList(growable: false);
  return MotionPathSpec(
    preset: spec.preset,
    centerX: _clampD(spec.centerX, -lim.mx, lim.mx),
    centerY: _clampD(spec.centerY, -lim.my, lim.my),
    radiusX: _clampD(spec.radiusX, 0.0, lim.mx),
    radiusY: _clampD(spec.radiusY, 0.0, lim.my),
    turns: _clampD(spec.turns, 0.05, 4.0),
    startAngle: spec.startAngle,
    sweep: _clampD(spec.sweep, 0.1, 2.0 * math.pi),
    curvature: _clampD(spec.curvature, 0.0, 1.0),
    speed: _clampD(spec.speed, 0.25, 3.0),
    speedEase: _clampD(spec.speedEase, 0.0, 1.0),
    startZoom: startZoom,
    endZoom: endZoom,
    startRotation: spec.startRotation,
    endRotation: spec.endRotation,
    direction: spec.direction == -1 ? -1 : 1,
    points: pts,
    isCustom: spec.isCustom,
    isUserEdited: spec.isUserEdited,
  );
}

// ---------------------------------------------------------------------------
// freehand stroke smoothing, spec §12.5
// ---------------------------------------------------------------------------

/// n points equally spaced by arc length along the polyline.
List<MotionPoint> _resampleUniform(List<MotionPoint> pts, int n) {
  if (pts.length <= 1) return List<MotionPoint>.of(pts);
  final cum = <double>[0.0];
  for (var i = 1; i < pts.length; i++) {
    cum.add(cum.last +
        math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y));
  }
  final total = cum.last;
  if (total < 1e-12) return List<MotionPoint>.filled(n, pts[0], growable: false);
  final out = <MotionPoint>[];
  var seg = 0;
  for (var j = 0; j < n; j++) {
    final target = total * j / (n - 1);
    while (seg < pts.length - 2 && cum[seg + 1] < target) {
      seg++;
    }
    final d = cum[seg + 1] - cum[seg];
    final w = d < 1e-12 ? 0.0 : (target - cum[seg]) / d;
    out.add(MotionPoint(
      x: lerpDouble(pts[seg].x, pts[seg + 1].x, w),
      y: lerpDouble(pts[seg].y, pts[seg + 1].y, w),
    ));
  }
  return out;
}

/// One Chaikin corner-cutting pass (open curve; endpoints kept).
List<MotionPoint> _chaikin(List<MotionPoint> pts) {
  if (pts.length <= 2) return List<MotionPoint>.of(pts);
  final out = <MotionPoint>[pts[0]];
  for (var i = 0; i < pts.length - 1; i++) {
    final x1 = pts[i].x;
    final y1 = pts[i].y;
    final x2 = pts[i + 1].x;
    final y2 = pts[i + 1].y;
    out.add(MotionPoint(x: 0.75 * x1 + 0.25 * x2, y: 0.75 * y1 + 0.25 * y2));
    out.add(MotionPoint(x: 0.25 * x1 + 0.75 * x2, y: 0.25 * y1 + 0.75 * y2));
  }
  out.add(pts[pts.length - 1]);
  return out;
}

/// Raw finger points -> the stored `custom` path points:
/// dedupe (min distance) -> arc-length resample to 24 -> Chaikin x2 ->
/// arc-length resample to 24. Deterministic; identical in Python/Kotlin.
List<MotionPoint> smoothStroke(Iterable<MotionPoint> raw) {
  final pts = <MotionPoint>[];
  for (final p in raw) {
    if (pts.isNotEmpty &&
        math.hypot(p.x - pts.last.x, p.y - pts.last.y) < kStrokeDedupeMinDist) {
      continue;
    }
    pts.add(p);
  }
  if (pts.length < 2) return pts;
  var out = _resampleUniform(pts, kStrokeTargetPoints);
  for (var i = 0; i < kChaikinIters; i++) {
    out = _chaikin(out);
  }
  return _resampleUniform(out, kStrokeTargetPoints);
}
