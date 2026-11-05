"""Motion Path Engine — the executable form of docs/MOTION_SPEC.md §12.

A motion *path* is a parametric camera trajectory (circle, ellipse, spiral,
S-curve, figure eight, arc, cubic Bezier, straight line or a freehand drawn
stroke) plus a zoom / rotation envelope that is applied while travelling the
path. Every path is re-parameterized by arc length (chord-length lookup
table) so the camera moves at (nearly) constant speed, and every evaluated
camera state is passed through the §3.2 clamp, so a path can never reveal
pixels outside the image.

1:1 ports (operation order included — the same double arithmetic must be
performed in the same order, so that the preview, the exporter and the golden
vectors agree):

  Dart  : lib/core/models/motion_path.dart + lib/features/motion_path/
          motion_path_engine.dart
  Kotlin: android/.../motion/MotionPathEngine.kt
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import List, Optional, Sequence, Tuple

from .camera import (CameraState, ImageFit, Keyframe, Viewport, clamp_camera,
                     max_pan, min_scale_at_rotation)
from .mathx import Xorshift128Plus, clamp, lerp, log_lerp, shortest_angle

# ---------------------------------------------------------------------------
# constants (spec §12.2)
# ---------------------------------------------------------------------------

LUT_SIZE = 4096  # arc-length lookup table resolution (fixed, all runtimes)
REFINE_STEPS = 16  # local sub-chord refinement inside one LUT cell

PATH_PRESETS: List[str] = [
    "linear",        # 1  straight pan A -> B
    "circularCw",    # 2  full circle, clockwise on screen
    "circularCcw",   # 3  full circle, counter-clockwise on screen
    "elliptical",    # 4  full ellipse (rx != ry allowed)
    "spiral",        # 5  Archimedean spiral (tightness = curvature)
    "sCurve",        # 6  Catmull-Rom through 3..n waypoints (S shape)
    "figureEight",   # 7  closed Lissajous figure eight
    "arc",           # 8  partial circle (sweep < 2*pi)
    "cubicBezier",   # 9  cubic Bezier with two control points
    "custom",        # 10 freehand drawn, smoothed stroke
]

# Generation pool for random curved motion (spec §12.7). `linear` and
# `cubicBezier`/`custom` are excluded: a random straight pan is already
# covered by the classic 2-keyframe generators, and `custom` is reserved for
# the user's finger.
PATH_PRESET_WEIGHTS = {
    "circularCw": 1.2, "circularCcw": 1.2, "elliptical": 1.0,
    "sCurve": 1.1, "spiral": 0.8, "figureEight": 0.7, "arc": 1.0,
}

# Spiral start radius as a fraction of the full radius (spec §12.3):
#   rho(u) = lerp(rho0, 1, u),  rho0 = 0.15 + 0.75 * (1 - curvature)
SPIRAL_RHO0_MIN = 0.15
SPIRAL_RHO0_RANGE = 0.75

# Freehand stroke pipeline constants (spec §12.5).
STROKE_DEDUPE_MIN_DIST = 0.004  # normalized units
STROKE_TARGET_POINTS = 24       # stored points after smoothing
CHAIKIN_ITERS = 2

_SCALE_PAD = 1.002  # same pad as the keyframe generators (spec §4)


# ---------------------------------------------------------------------------
# spec model (spec §12.1)
# ---------------------------------------------------------------------------

@dataclass
class MotionPathSpec:
    preset: str = "circularCw"
    center_x: float = 0.0
    center_y: float = 0.0
    radius_x: float = 0.25
    radius_y: float = 0.25
    turns: float = 1.0            # figure eight snaps to int 1..3
    start_angle: float = -math.pi / 2   # radians, +x axis, y up
    sweep: float = 2.0 * math.pi        # `arc` only (radians, <= 2*pi)
    curvature: float = 0.5          # 0..1
    speed: float = 1.0              # 0.25..3 (path progress per clip)
    speed_ease: float = 0.0         # 0..1 (0 = constant speed)
    start_zoom: float = 1.15
    end_zoom: float = 1.30
    start_rotation: float = 0.0     # radians
    end_rotation: float = 0.0
    direction: int = 1              # +1 = counter-clockwise, -1 = clockwise
    points: List[Tuple[float, float]] = field(default_factory=list)
    is_custom: bool = False         # drawn with the finger
    is_user_edited: bool = False    # protected from randomize

    def __post_init__(self) -> None:
        if self.direction not in (-1, 1):
            self.direction = 1
        if self.preset not in PATH_PRESETS:
            raise ValueError(f"unknown path preset {self.preset!r}")

    # -- serialization (JSON keys are part of the project file contract) ----

    def to_json(self) -> dict:
        return {
            "preset": self.preset,
            "centerX": self.center_x, "centerY": self.center_y,
            "radiusX": self.radius_x, "radiusY": self.radius_y,
            "turns": self.turns,
            "startAngle": self.start_angle, "sweep": self.sweep,
            "curvature": self.curvature,
            "speed": self.speed, "speedEase": self.speed_ease,
            "startZoom": self.start_zoom, "endZoom": self.end_zoom,
            "startRotation": self.start_rotation,
            "endRotation": self.end_rotation,
            "direction": self.direction,
            "points": [{"x": p[0], "y": p[1]} for p in self.points],
            "isCustom": self.is_custom,
            "isUserEdited": self.is_user_edited,
        }

    @staticmethod
    def from_json(d: dict) -> "MotionPathSpec":
        try:
            preset = str(d.get("preset", "circularCw"))
            if preset not in PATH_PRESETS:
                raise ValueError(preset)
            pts = [(float(p["x"]), float(p["y"]))
                   for p in d.get("points", [])]
            return MotionPathSpec(
                preset=preset,
                center_x=float(d.get("centerX", 0.0)),
                center_y=float(d.get("centerY", 0.0)),
                radius_x=float(d.get("radiusX", 0.25)),
                radius_y=float(d.get("radiusY", 0.25)),
                turns=float(d.get("turns", 1.0)),
                start_angle=float(d.get("startAngle", -math.pi / 2)),
                sweep=float(d.get("sweep", 2.0 * math.pi)),
                curvature=float(d.get("curvature", 0.5)),
                speed=float(d.get("speed", 1.0)),
                speed_ease=float(d.get("speedEase", 0.0)),
                start_zoom=float(d.get("startZoom", 1.15)),
                end_zoom=float(d.get("endZoom", 1.30)),
                start_rotation=float(d.get("startRotation", 0.0)),
                end_rotation=float(d.get("endRotation", 0.0)),
                direction=int(d.get("direction", 1)),
                points=pts,
                is_custom=bool(d.get("isCustom", False)),
                is_user_edited=bool(d.get("isUserEdited", False)),
            )
        except (ValueError, TypeError, KeyError):
            # Unknown/foreign preset data: drop the path entirely; the baked
            # keyframes remain the source of truth (lenient load, spec §12.1).
            raise


# ---------------------------------------------------------------------------
# preset parameter resolution (shared by all runtimes)
# ---------------------------------------------------------------------------

def _linear_endpoints(spec: MotionPathSpec) -> Tuple[Tuple[float, float],
                                                     Tuple[float, float]]:
    if len(spec.points) >= 2:
        return spec.points[0], spec.points[1]
    return (spec.center_x - spec.radius_x, spec.center_y - spec.radius_y), \
           (spec.center_x + spec.radius_x, spec.center_y + spec.radius_y)


def _scurve_waypoints(spec: MotionPathSpec) -> List[Tuple[float, float]]:
    if len(spec.points) >= 3:
        return list(spec.points)
    bend = (2.0 * spec.curvature - 1.0) * spec.radius_y
    return [(spec.center_x - spec.radius_x, spec.center_y + bend),
            (spec.center_x, spec.center_y),
            (spec.center_x + spec.radius_x, spec.center_y - bend)]


def _bezier_points(spec: MotionPathSpec) -> List[Tuple[float, float]]:
    if len(spec.points) >= 4:
        return list(spec.points[:4])
    bend = (2.0 * spec.curvature - 1.0) * spec.radius_y
    return [(spec.center_x - spec.radius_x, spec.center_y),
            (spec.center_x - spec.radius_x * 0.5, spec.center_y + bend),
            (spec.center_x + spec.radius_x * 0.5, spec.center_y - bend),
            (spec.center_x + spec.radius_x, spec.center_y)]


def _snap_turns(spec: MotionPathSpec) -> float:
    """figure eight must close with a C1 seam: integer turns, at least 1.

    Half-up tie-breaking (floor(x + 0.5)), NOT Python's banker's round(),
    so the Dart (`roundToDouble`) and Kotlin (`roundToInt`) ports agree bit
    for bit at exact .5 values.
    """
    if spec.preset == "figureEight":
        return float(math.floor(spec.turns + 0.5)) if spec.turns >= 0.5 else 1.0
    return spec.turns


# ---------------------------------------------------------------------------
# centripetal Catmull-Rom (alpha = 0.5), spec §12.4
# ---------------------------------------------------------------------------

def _cr_segment(p0: Tuple[float, float], p1: Tuple[float, float],
                p2: Tuple[float, float], p3: Tuple[float, float],
                w: float) -> Tuple[float, float]:
    """One centripetal Catmull-Rom segment from p1 to p2, local parameter
    w in [0,1] (spec §12.4).

    Barry-Goldman non-uniform formulation with centripetal knots
    t_k = t_{k-1} + |p_k - p_{k-1}|^0.5, evaluated in the de Casteljau style
    *in the knot parameter* ts = t1 + (t2-t1)*w:

        a1 = (p0*(t1-ts) - p1*(t0-ts)) / (t1-t0)
        a2 = (p1*(t2-ts) - p2*(t1-ts)) / (t2-t1)
        a3 = (p2*(t3-ts) - p3*(t2-ts)) / (t3-t2)
        b1 = (a1*(t2-ts) - a2*(t0-ts)) / (t2-t0)
        b2 = (a2*(t3-ts) - a3*(t1-ts)) / (t3-t1)
        c  = (b1*(t2-ts) - b2*(t1-ts)) / (t2-t1)

    This is C1 at the waypoints (verified against the uniform-CR matrix form
    in the uniform-knot limit, max err ~1e-16) and cusp-free for the
    centripetal exponent. The Dart and Kotlin ports must reproduce every
    operation in this exact order.
    """
    t0 = 0.0
    t1 = t0 + math.sqrt(math.hypot(p1[0] - p0[0], p1[1] - p0[1]))
    t2 = t1 + math.sqrt(math.hypot(p2[0] - p1[0], p2[1] - p1[1]))
    t3 = t2 + math.sqrt(math.hypot(p3[0] - p2[0], p3[1] - p2[1]))
    if t2 - t1 < 1e-12:
        return p1  # degenerate segment: p1 == p2
    ts = t1 + (t2 - t1) * w
    t0s = t0 - ts
    t1s = t1 - ts
    t2s = t2 - ts
    t3s = t3 - ts
    if t1 - t0 < 1e-12:
        a1 = p1
    else:
        a1 = ((p0[0] * t1s - p1[0] * t0s) / (t1 - t0),
              (p0[1] * t1s - p1[1] * t0s) / (t1 - t0))
    a2 = ((p1[0] * t2s - p2[0] * t1s) / (t2 - t1),
          (p1[1] * t2s - p2[1] * t1s) / (t2 - t1))
    if t3 - t2 < 1e-12:
        a3 = p2
    else:
        a3 = ((p2[0] * t3s - p3[0] * t2s) / (t3 - t2),
              (p2[1] * t3s - p3[1] * t2s) / (t3 - t2))
    if t2 - t0 < 1e-12:
        b1 = a1
    else:
        b1 = ((a1[0] * t2s - a2[0] * t0s) / (t2 - t0),
              (a1[1] * t2s - a2[1] * t0s) / (t2 - t0))
    if t3 - t1 < 1e-12:
        b2 = a2
    else:
        b2 = ((a2[0] * t3s - a3[0] * t1s) / (t3 - t1),
              (a2[1] * t3s - a3[1] * t1s) / (t3 - t1))
    return ((b1[0] * t2s - b2[0] * t1s) / (t2 - t1),
            (b1[1] * t2s - b2[1] * t1s) / (t2 - t1))


def _cr_segment_derivative(p0: Tuple[float, float], p1: Tuple[float, float],
                           p2: Tuple[float, float], p3: Tuple[float, float],
                           at_end: bool) -> Tuple[float, float]:
    """Exact dc/dts at the segment start (at_end=False, ts=t1) or end
    (at_end=True, ts=t2), by differentiating the `_cr_segment` scheme:

        a1' = (p1-p0)/(t1-t0)          a2' = (p2-p1)/(t2-t1)
        a3' = (p3-p2)/(t3-t2)
        b1' = (a1'*(t2-ts) - a2'*(t0-ts) - a1 + a2) / (t2-t0)
        b2' = (a2'*(t3-ts) - a3'*(t1-ts) - a2 + a3) / (t3-t1)
        c'  = (b1'*(t2-ts) - b2'*(t1-ts) - b1 + b2) / (t2-t1)

    Used by the C1 continuity invariant only (the ported runtimes use
    `path_tangent` for UI arrows).
    """
    t0 = 0.0
    t1 = t0 + math.sqrt(math.hypot(p1[0] - p0[0], p1[1] - p0[1]))
    t2 = t1 + math.sqrt(math.hypot(p2[0] - p1[0], p2[1] - p1[1]))
    t3 = t2 + math.sqrt(math.hypot(p3[0] - p2[0], p3[1] - p2[1]))
    if t2 - t1 < 1e-12:
        return (0.0, 0.0)
    ts = t2 if at_end else t1
    t0s, t1s, t2s, t3s = t0 - ts, t1 - ts, t2 - ts, t3 - ts
    a1d = ((0.0, 0.0) if t1 - t0 < 1e-12 else
           ((p1[0] - p0[0]) / (t1 - t0), (p1[1] - p0[1]) / (t1 - t0)))
    a2d = ((p2[0] - p1[0]) / (t2 - t1), (p2[1] - p1[1]) / (t2 - t1))
    a3d = ((0.0, 0.0) if t3 - t2 < 1e-12 else
           ((p3[0] - p2[0]) / (t3 - t2), (p3[1] - p2[1]) / (t3 - t2)))
    a1 = p1 if t1 - t0 < 1e-12 else \
        ((p0[0] * t1s - p1[0] * t0s) / (t1 - t0),
         (p0[1] * t1s - p1[1] * t0s) / (t1 - t0))
    a2 = ((p1[0] * t2s - p2[0] * t1s) / (t2 - t1),
          (p1[1] * t2s - p2[1] * t1s) / (t2 - t1))
    a3 = p2 if t3 - t2 < 1e-12 else \
        ((p2[0] * t3s - p3[0] * t2s) / (t3 - t2),
         (p2[1] * t3s - p3[1] * t2s) / (t3 - t2))
    b1 = a1 if t2 - t0 < 1e-12 else \
        ((a1[0] * t2s - a2[0] * t0s) / (t2 - t0),
         (a1[1] * t2s - a2[1] * t0s) / (t2 - t0))
    b2 = a2 if t3 - t1 < 1e-12 else \
        ((a2[0] * t3s - a3[0] * t1s) / (t3 - t1),
         (a2[1] * t3s - a3[1] * t1s) / (t3 - t1))
    b1d = (0.0, 0.0) if t2 - t0 < 1e-12 else \
        ((a1d[0] * t2s - a2d[0] * t0s - a1[0] + a2[0]) / (t2 - t0),
         (a1d[1] * t2s - a2d[1] * t0s - a1[1] + a2[1]) / (t2 - t0))
    b2d = (0.0, 0.0) if t3 - t1 < 1e-12 else \
        ((a2d[0] * t3s - a3d[0] * t1s - a2[0] + a3[0]) / (t3 - t1),
         (a2d[1] * t3s - a3d[1] * t1s - a2[1] + a3[1]) / (t3 - t1))
    return ((b1d[0] * t2s - b2d[0] * t1s - b1[0] + b2[0]) / (t2 - t1),
            (b1d[1] * t2s - b2d[1] * t1s - b1[1] + b2[1]) / (t2 - t1))


def _catmull_rom(pts: Sequence[Tuple[float, float]],
                 u: float) -> Tuple[float, float]:
    """CR spline through `pts`, global parameter u in [0,1] (uniform per
    segment; the arc-length LUT corrects the resulting speed)."""
    n = len(pts) - 1  # number of segments
    if n <= 0:
        return pts[0]
    u = 0.0 if u < 0.0 else (1.0 if u > 1.0 else u)
    g = u * n
    seg = int(g)
    if seg >= n:
        seg = n - 1
    w = g - seg
    p0 = pts[seg - 1] if seg >= 1 else pts[0]
    p1 = pts[seg]
    p2 = pts[seg + 1]
    p3 = pts[seg + 2] if seg + 2 < len(pts) else pts[-1]
    return _cr_segment(p0, p1, p2, p3, w)


# ---------------------------------------------------------------------------
# raw parametric point, spec §12.3
# ---------------------------------------------------------------------------

def raw_point(spec: MotionPathSpec, u: float) -> Tuple[float, float]:
    """Camera position at path parameter u in [0,1] (BEFORE arc-length
    re-parameterization, BEFORE the safety clamp)."""
    u = 0.0 if u < 0.0 else (1.0 if u > 1.0 else u)
    cx, cy = spec.center_x, spec.center_y
    rx, ry = spec.radius_x, spec.radius_y
    d = spec.direction
    preset = spec.preset

    if preset == "linear":
        a, b = _linear_endpoints(spec)
        return lerp(a[0], b[0], u), lerp(a[1], b[1], u)

    if preset in ("circularCw", "circularCcw", "elliptical"):
        theta = spec.start_angle + d * 2.0 * math.pi * spec.turns * u
        return cx + rx * math.cos(theta), cy + ry * math.sin(theta)

    if preset == "arc":
        theta = spec.start_angle + d * spec.sweep * u
        return cx + rx * math.cos(theta), cy + ry * math.sin(theta)

    if preset == "spiral":
        rho0 = SPIRAL_RHO0_MIN + SPIRAL_RHO0_RANGE * (1.0 - spec.curvature)
        rho = lerp(rho0, 1.0, u)
        theta = spec.start_angle + d * 2.0 * math.pi * spec.turns * u
        return cx + rx * rho * math.cos(theta), cy + ry * rho * math.sin(theta)

    if preset == "figureEight":
        k = _snap_turns(spec)
        a = 2.0 * math.pi * k * u
        x = cx + rx * math.sin(a)
        y = cy + ry * math.sin(a) * math.cos(a)
        return x, y

    if preset == "sCurve":
        return _catmull_rom(_scurve_waypoints(spec), u)

    if preset == "cubicBezier":
        p0, p1, p2, p3 = _bezier_points(spec)
        iu = 1.0 - u
        a = iu * iu * iu
        b = 3.0 * iu * iu * u
        c = 3.0 * iu * u * u
        dd = u * u * u
        return (a * p0[0] + b * p1[0] + c * p2[0] + dd * p3[0],
                a * p0[1] + b * p1[1] + c * p2[1] + dd * p3[1])

    if preset == "custom":
        pts = spec.points
        if len(pts) <= 1:
            return (cx, cy) if len(pts) == 0 else pts[0]
        return _catmull_rom(pts, u)

    raise ValueError(f"unknown path preset {preset!r}")


def path_tangent(spec: MotionPathSpec, u: float) -> Tuple[float, float]:
    """Normalized tangent at u.

    One-sided differences at the ends (so the u=0 and u=1 tangents of a
    closed path are the true seam tangents), central difference otherwise.
    Editor direction arrows and the seam-continuity tests both use this.
    """
    e = 1e-3
    if u <= e:
        a = raw_point(spec, 0.0)
        b = raw_point(spec, u + e)
    elif u >= 1.0 - e:
        a = raw_point(spec, u - e)
        b = raw_point(spec, 1.0)
    else:
        a = raw_point(spec, u - e)
        b = raw_point(spec, u + e)
    dx, dy = b[0] - a[0], b[1] - a[1]
    m = math.hypot(dx, dy)
    if m < 1e-12:
        return (0.0, 0.0)
    return dx / m, dy / m


# ---------------------------------------------------------------------------
# arc-length re-parameterization, spec §12.2
# ---------------------------------------------------------------------------

_LUT_CACHE: dict[int, Tuple[List[float], float]] = {}


def build_arc_lut(spec: MotionPathSpec, use_cache: bool = True
                  ) -> Tuple[List[float], float]:
    """Chord-length lookup table over the raw parametric curve.

    `cum[i]` = arc length from u=0 to u=i/LUT_SIZE. Each cell is summed from
    LUT_SUBCHORDS sub-chords (a single chord would bias the cumulative arc in
    high-curvature regions), and the whole table is accumulated with *one
    sequential pass* (i = 1..LUT_SIZE) so every runtime sums the same doubles
    in the same order. The table depends only on the spec, so runtimes cache
    it per path (Python: module cache keyed by id; Dart/Kotlin: on the
    evaluator object).
    """
    if use_cache:
        hit = _LUT_CACHE.get(id(spec))
        if hit is not None:
            return hit
    cum = [0.0] * (LUT_SIZE + 1)
    du = 1.0 / LUT_SIZE
    px, py = raw_point(spec, 0.0)
    for i in range(1, LUT_SIZE + 1):
        s = 0.0
        for k in range(1, REFINE_STEPS + 1):
            qx, qy = raw_point(spec, (i - 1) * du + du * k / REFINE_STEPS)
            s = s + math.hypot(qx - px, qy - py)
            px, py = qx, qy
        cum[i] = cum[i - 1] + s
    out = (cum, cum[LUT_SIZE])
    if use_cache:
        _LUT_CACHE[id(spec)] = out
    return out


def param_at_arc(spec: MotionPathSpec, cum: Sequence[float],
                 target: float) -> float:
    """Inverse arc lookup: path parameter u for arc-length target.

    Two levels (identical in every runtime):
      1. coarse — binary search for the first i with cum[i] >= target;
      2. fine   — REFINE_STEPS sub-chords inside that single LUT cell,
                  binary search + linear interpolation again.
    Level 1 keeps per-frame cost tiny; level 2 removes the chord
    nonlinearity of the parametric curve (the Catmull-Rom spline is
    strongly non-uniform in u) so the camera speed is uniform to ~1e-8.
    """
    total = cum[LUT_SIZE]
    if target <= 0.0 or total <= 1e-9:
        return 0.0
    if target >= total:
        return 1.0
    lo, hi = 0, LUT_SIZE
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        if cum[mid] >= target:
            hi = mid
        else:
            lo = mid
    i0 = hi - 1
    d = cum[hi] - cum[i0]
    if d < 1e-12:
        return (i0 + 0.5) / LUT_SIZE
    u0 = i0 / LUT_SIZE
    du = 1.0 / LUT_SIZE
    n = REFINE_STEPS
    px, py = raw_point(spec, u0)
    c = [0.0] * (n + 1)
    for k in range(1, n + 1):
        qx, qy = raw_point(spec, u0 + du * k / n)
        c[k] = c[k - 1] + math.hypot(qx - px, qy - py)
        px, py = qx, qy
    c_total = c[n]
    if c_total < 1e-12:
        return u0 + du * (target - cum[i0]) / d
    local = (target - cum[i0]) * (c_total / d)
    lo2, hi2 = 0, n
    while lo2 + 1 < hi2:
        mid = (lo2 + hi2) // 2
        if c[mid] >= local:
            hi2 = mid
        else:
            lo2 = mid
    j0 = hi2 - 1
    dd = c[hi2] - c[j0]
    if dd < 1e-12:
        return u0 + du * (j0 + 0.5) / n
    return u0 + du * (j0 + (local - c[j0]) / dd) / n


# ---------------------------------------------------------------------------
# time -> progress -> camera state
# ---------------------------------------------------------------------------

def progress_at(spec: MotionPathSpec, t: float, duration: float) -> float:
    """Path progress p in [0,1] at local time t (spec §12.6).

    q = t/duration;  p = q * speed (capped at 1: the path completes early and
    the camera holds its end pose);  speedEase blends the raw linear progress
    towards a smootherstep velocity profile.
    """
    if duration <= 1e-9:
        return 1.0
    q = t / duration
    if q < 0.0:
        q = 0.0
    elif q > 1.0:
        q = 1.0
    p = q * spec.speed
    if p > 1.0:
        p = 1.0
    if spec.speed_ease > 0.0:
        e = p * p * p * (p * (6.0 * p - 15.0) + 10.0)
        p = p + spec.speed_ease * (e - p)
    if p < 0.0:
        p = 0.0
    return p


def evaluate_path(spec: MotionPathSpec, fit: ImageFit, vp: Viewport,
                  t: float, duration: float) -> CameraState:
    """The unified camera evaluation used by preview AND export (spec §12.6)."""
    cum, total = build_arc_lut(spec)
    p = progress_at(spec, t, duration)
    u = param_at_arc(spec, cum, p * total)
    px, py = raw_point(spec, u)
    s = log_lerp(spec.start_zoom, spec.end_zoom, p)
    r = spec.start_rotation + shortest_angle(spec.start_rotation,
                                             spec.end_rotation) * p
    return clamp_camera(CameraState(px, py, s, r), fit, vp)


def bake_path(spec: MotionPathSpec, fit: ImageFit, vp: Viewport,
              duration: float, samples: int = 128) -> List[Keyframe]:
    """High-resolution keyframes of the path (spec §12.8).

    The baked list is the *export fallback* and the editor's read-only
    sample strip; the renderer evaluates the path directly. Segment easing is
    `linear` because consecutive samples of a smooth path are connected by
    near-straight chords.
    """
    kfs: List[Keyframe] = []
    for i in range(samples + 1):
        t = duration * i / samples
        st = evaluate_path(spec, fit, vp, t, duration)
        kfs.append(Keyframe(t, st.x, st.y, st.scale, st.rotation, "linear"))
    kfs[0].time = 0.0
    kfs[-1].time = duration
    return kfs


# ---------------------------------------------------------------------------
# safety / authoring guards, spec §12.6 + §12.9
# ---------------------------------------------------------------------------

def sanitize_path(spec: MotionPathSpec, fit: ImageFit,
                  vp: Viewport) -> MotionPathSpec:
    """Clamp every authoring field so the whole path stays cover-safe even
    at the maximum zoom / rotation the envelope reaches."""
    r_max = max(abs(spec.start_rotation), abs(spec.end_rotation))
    s_zoom = max(spec.start_zoom, spec.end_zoom)
    s_min = min_scale_at_rotation(fit, vp, r_max) * _SCALE_PAD
    start_zoom = spec.start_zoom if spec.start_zoom >= s_min else s_min
    end_zoom = spec.end_zoom if spec.end_zoom >= s_min else s_min
    lim = max_pan(fit, vp, max(start_zoom, end_zoom), r_max)
    mx, my = lim
    pts = [(clamp(x, -mx, mx), clamp(y, -my, my)) for (x, y) in spec.points]
    return MotionPathSpec(
        preset=spec.preset,
        center_x=clamp(spec.center_x, -mx, mx),
        center_y=clamp(spec.center_y, -my, my),
        radius_x=clamp(spec.radius_x, 0.0, mx),
        radius_y=clamp(spec.radius_y, 0.0, my),
        turns=clamp(spec.turns, 0.05, 4.0),
        start_angle=spec.start_angle,
        sweep=clamp(spec.sweep, 0.1, 2.0 * math.pi),
        curvature=clamp(spec.curvature, 0.0, 1.0),
        speed=clamp(spec.speed, 0.25, 3.0),
        speed_ease=clamp(spec.speed_ease, 0.0, 1.0),
        start_zoom=start_zoom,
        end_zoom=end_zoom,
        start_rotation=spec.start_rotation,
        end_rotation=spec.end_rotation,
        direction=spec.direction,
        points=pts,
        is_custom=spec.is_custom,
        is_user_edited=spec.is_user_edited,
    )


# ---------------------------------------------------------------------------
# freehand stroke smoothing, spec §12.5
# ---------------------------------------------------------------------------

def _resample_uniform(pts: Sequence[Tuple[float, float]],
                      n: int) -> List[Tuple[float, float]]:
    """n points equally spaced by arc length along the polyline."""
    if len(pts) <= 1:
        return list(pts)
    cum = [0.0]
    for i in range(1, len(pts)):
        cum.append(cum[-1] + math.hypot(pts[i][0] - pts[i - 1][0],
                                        pts[i][1] - pts[i - 1][1]))
    total = cum[-1]
    if total < 1e-12:
        return [pts[0]] * n
    out: List[Tuple[float, float]] = []
    seg = 0
    for j in range(n):
        target = total * j / (n - 1)
        while seg < len(pts) - 2 and cum[seg + 1] < target:
            seg += 1
        d = cum[seg + 1] - cum[seg]
        w = 0.0 if d < 1e-12 else (target - cum[seg]) / d
        out.append((lerp(pts[seg][0], pts[seg + 1][0], w),
                    lerp(pts[seg][1], pts[seg + 1][1], w)))
    return out


def _chaikin(pts: Sequence[Tuple[float, float]]) -> List[Tuple[float, float]]:
    """One Chaikin corner-cutting pass (open curve; endpoints kept)."""
    if len(pts) <= 2:
        return list(pts)
    out: List[Tuple[float, float]] = [pts[0]]
    for i in range(len(pts) - 1):
        x1, y1 = pts[i]
        x2, y2 = pts[i + 1]
        out.append((0.75 * x1 + 0.25 * x2, 0.75 * y1 + 0.25 * y2))
        out.append((0.25 * x1 + 0.75 * x2, 0.25 * y1 + 0.75 * y2))
    out.append(pts[-1])
    return out


def smooth_stroke(raw: Sequence[Tuple[float, float]]) -> List[Tuple[float, float]]:
    """Raw finger points -> the stored `custom` path points.

    dedupe (min distance) -> arc-length resample to 24 -> Chaikin x2 ->
    arc-length resample to 24. Deterministic; identical in Dart/Kotlin.
    """
    pts: List[Tuple[float, float]] = []
    for p in raw:
        if pts and math.hypot(p[0] - pts[-1][0], p[1] - pts[-1][1]) < STROKE_DEDUPE_MIN_DIST:
            continue
        pts.append(p)
    if len(pts) < 2:
        return pts
    pts = _resample_uniform(pts, STROKE_TARGET_POINTS)
    for _ in range(CHAIKIN_ITERS):
        pts = _chaikin(pts)
    return _resample_uniform(pts, STROKE_TARGET_POINTS)
