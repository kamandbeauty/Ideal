/// Easing curves — Dart port of docs/MOTION_SPEC.md §2.
///
/// Must stay bit-compatible with `tools/validate/motionshot/mathx.py` and
/// `android/.../motion/KeyframeEngine.kt`. Golden values live in
/// `tools/validate/motionshot/golden/easing.json`.
library;

import 'dart:math' as math;

/// Every easing supported by the editor. Serialized by [name].
enum Easing {
  linear,
  easeIn,
  easeOut,
  easeInOut,
  smooth,
  smoother,
  custom;

  /// Maps `t` (clamped to 0..1) to an eased 0..1 value.
  ///
  /// [curve] is only used for [Easing.custom]: four control points of a CSS
  /// style cubic-bezier `(x1, y1, x2, y2)`. Defaults to `(0.42, 0, 0.58, 1)`.
  double apply(double t, [List<double>? curve]) {
    final tt = t <= 0 ? 0.0 : (t >= 1 ? 1.0 : t);
    switch (this) {
      case Easing.linear:
        return tt;
      case Easing.easeIn:
        return tt * tt;
      case Easing.easeOut:
        return 1 - (1 - tt) * (1 - tt);
      case Easing.easeInOut:
        return tt < 0.5
            ? 2 * tt * tt
            : 1 - 2 * (1 - tt) * (1 - tt);
      case Easing.smooth:
        return tt * tt * (3 - 2 * tt);
      case Easing.smoother:
        return tt * tt * tt * (tt * (6 * tt - 15) + 10);
      case Easing.custom:
        final c = curve ?? const <double>[0.42, 0.0, 0.58, 1.0];
        return _cubicBezier(c[0], c[1], c[2], c[3], tt);
    }
  }

  static Easing parse(String? name) {
    if (name == null) return Easing.smoother;
    for (final e in Easing.values) {
      if (e.name == name) return e;
    }
    return Easing.smoother;
  }

  /// Human readable label key for localization.
  String get labelKey => 'easing_$name';
}

/// CSS `cubic-bezier` evaluation: solve x(u) = t, return y(u).
///
/// Newton-Raphson fast path with a bisection fallback, identical to the
/// reference implementation so that preview, export and golden vectors agree.
double _cubicBezier(double x1, double y1, double x2, double y2, double t) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  final cx1 = x1.clamp(0.0, 1.0);
  final cx2 = x2.clamp(0.0, 1.0);

  double xOf(double u) {
    final iu = 1 - u;
    return 3 * iu * iu * u * cx1 + 3 * iu * u * u * cx2 + u * u * u;
  }

  double yOf(double u) {
    final iu = 1 - u;
    return 3 * iu * iu * u * y1 + 3 * iu * u * u * y2 + u * u * u;
  }

  double dxOf(double u) {
    final iu = 1 - u;
    return 3 * iu * iu * cx1 + 6 * iu * u * (cx2 - cx1) + 3 * u * u * (1 - cx2);
  }

  var u = t;
  var ok = true;
  for (var i = 0; i < 8; i++) {
    final err = xOf(u) - t;
    if (err.abs() < 1e-9) return yOf(u);
    final d = dxOf(u);
    if (d.abs() < 1e-9) {
      ok = false;
      break;
    }
    u -= err / d;
    if (u < 0 || u > 1) {
      ok = false;
      break;
    }
  }
  if (ok) return yOf(u);

  var lo = 0.0;
  var hi = 1.0;
  u = t;
  for (var i = 0; i < 60; i++) {
    final v = xOf(u);
    if ((v - t).abs() < 1e-12) break;
    if (v < t) {
      lo = u;
    } else {
      hi = u;
    }
    u = (lo + hi) / 2;
  }
  return yOf(u);
}

/// Shortest signed angular distance from [a] to [b] (spec §3.1).
double shortestAngle(double a, double b) {
  var d = (b - a) % (2 * math.pi);
  if (d > math.pi) d -= 2 * math.pi;
  if (d < -math.pi) d += 2 * math.pi;
  return d;
}

/// Linear interpolation.
double lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// Perceptually uniform zoom interpolation (spec §3.1).
double logLerp(double a, double b, double t) {
  if (a <= 0 || b <= 0) return lerpDouble(a, b, t);
  return math.exp(lerpDouble(math.log(a), math.log(b), t));
}
