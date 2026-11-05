"""Model of the *Kotlin* motion engine, used to catch port drift without a JVM.

The Android renderer cannot be compiled in this environment, so the JVM unit
tests (`MotionConformanceTest`) are unverified. This module is a line-by-line
transcription of `android/.../motion/MotionTypes.kt` and
`KeyframeEngine.kt` (draw order included) and is compared against the same
golden vectors the Kotlin tests read. If the Kotlin source drifts away from
the Python reference, `verify` fails here.

This is a *checker*, not the reference: the reference of truth is
`profile.py`.
"""
from __future__ import annotations

import math
from typing import List, Optional, Sequence

from .camera import (CameraState, ImageFit, Viewport, clamp_camera, max_pan,
                     min_scale_at_rotation)
from .mathx import (Xorshift128Plus, clamp, lerp, log_lerp,
                    shortest_angle, wrap64)
from .profile import Keyframe

SCALE_PAD = 1.002
RAD = math.pi / 180.0


# --- MotionTypes.kt: RandomMotion.splitMix64 / Xorshift128Plus ---------------

def k_splitmix64(state_in: int):
    state = wrap64(state_in + 0x9E3779B97F4A7C15 - (1 << 64))
    z = state
    z = wrap64((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9)
    z = wrap64((z ^ (z >> 27)) * 0x94D049BB133111EB)
    return state, z ^ (z >> 31)


class KRandom:
    """Transcription of the Kotlin `Xorshift128Plus` after the ordering fix."""

    def __init__(self, seed: int):
        state = wrap64(seed)
        state, v0 = k_splitmix64(state)
        _, v1 = k_splitmix64(state)
        if v0 == 0 and v1 == 0:
            v0 = 0x9E3779B97F4A7C15
        self.s0 = v0
        self.s1 = v1

    def next_u64(self) -> int:
        old0, old1 = self.s0, self.s1
        self.s0 = old1
        x = old0 ^ wrap64(old0 << 23)
        x ^= x >> 17
        x ^= old1
        x ^= old1 >> 26
        self.s1 = wrap64(x)
        return wrap64(self.s0 + self.s1)

    def next_double(self) -> float:
        return (self.next_u64() >> 11) * (1.0 / 9007199254740992.0)

    def irange(self, lo: int, hi_inclusive: int) -> int:
        # Kotlin `Long.remainderUnsigned(nextU64(), n)` — `next_u64()` here
        # is already unsigned, so a plain `%` is the same operation.
        n = hi_inclusive - lo + 1
        return lo + (self.next_u64() % n)

    def bool(self, p_true: float = 0.5) -> bool:
        return self.next_double() < p_true

    def range(self, lo: float, hi: float) -> float:
        return lo + (hi - lo) * self.next_double()

    def sign(self) -> int:
        return 1 if (self.next_u64() & 1) == 1 else -1


# --- KeyframeEngine.kt: ease / sampleKeyframes -------------------------------

def k_ease(kind: str, t_raw: float, curve=None) -> float:
    t = 0.0 if t_raw <= 0.0 else (1.0 if t_raw >= 1.0 else t_raw)
    if kind == "linear":
        return t
    if kind == "easeIn":
        return t * t
    if kind == "easeOut":
        return 1.0 - (1.0 - t) * (1.0 - t)
    if kind == "easeInOut":
        return 2 * t * t if t < 0.5 else 1.0 - 2.0 * (1.0 - t) * (1.0 - t)
    if kind == "smooth":
        return t * t * (3.0 - 2.0 * t)
    if kind == "smoother":
        return t * t * t * (t * (6.0 * t - 15.0) + 10.0)
    if kind == "custom":
        x1, y1, x2, y2 = curve if curve else (0.42, 0.0, 0.58, 1.0)
        return _cubic_bezier(min(max(x1, 0.0), 1.0), y1,
                             min(max(x2, 0.0), 1.0), y2, t)
    raise ValueError(kind)


def _cubic_bezier(x1_raw: float, y1: float, x2_raw: float, y2: float,
                  t: float) -> float:
    """Transcription of Kotlin `cubicBezier` (itself a port of mathx._bezier)."""
    if t <= 0.0:
        return 0.0
    if t >= 1.0:
        return 1.0
    x1 = min(max(x1_raw, 0.0), 1.0)
    x2 = min(max(x2_raw, 0.0), 1.0)

    def cx(u):
        iu = 1.0 - u
        return 3.0 * iu * iu * u * x1 + 3.0 * iu * u * u * x2 + u * u * u

    def cy(u):
        iu = 1.0 - u
        return 3.0 * iu * iu * u * y1 + 3.0 * iu * u * u * y2 + u * u * u

    def dx(u):
        iu = 1.0 - u
        return 3.0 * iu * iu * x1 + 6.0 * iu * u * (x2 - x1) + 3.0 * u * u * (1.0 - x2)

    u = t
    newton_ok = True
    for _ in range(8):
        err = cx(u) - t
        if abs(err) < 1e-9:
            return cy(u)
        d = dx(u)
        if abs(d) < 1e-9:
            newton_ok = False
            break
        u -= err / d
        if u < 0.0 or u > 1.0:
            newton_ok = False
            break
    if newton_ok:
        return cy(u)

    lo, hi = 0.0, 1.0
    u = t
    for _ in range(60):
        v = cx(u)
        if abs(v - t) < 1e-12:
            break
        if v < t:
            lo = u
        else:
            hi = u
        u = (lo + hi) / 2.0
    return cy(u)


def k_shortest_angle(a: float, b: float) -> float:
    d = math.fmod(b - a, 2 * math.pi)
    if d > math.pi:
        d -= 2 * math.pi
    elif d < -math.pi:
        d += 2 * math.pi
    return d


def k_sample(kfs: Sequence[Keyframe], t: float) -> CameraState:
    if len(kfs) == 1 or t <= kfs[0].time:
        k = kfs[0]
        return CameraState(k.x, k.y, k.scale, k.rotation)
    if t >= kfs[-1].time:
        k = kfs[-1]
        return CameraState(k.x, k.y, k.scale, k.rotation)
    lo, hi = 0, len(kfs) - 1
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        if kfs[mid].time <= t:
            lo = mid
        else:
            hi = mid
    a, b = kfs[lo], kfs[hi]
    dt = b.time - a.time
    u = (t - a.time) / dt
    e = k_ease(a.easing, u, a.curve)
    return CameraState(
        a.x + (b.x - a.x) * e,
        a.y + (b.y - a.y) * e,
        math.exp(math.log(a.scale) + (math.log(b.scale) - math.log(a.scale)) * e),
        a.rotation + k_shortest_angle(a.rotation, b.rotation) * e,
    )


# --- MotionTypes.kt: MotionGenerator.generate -------------------------------

def _clip(state: CameraState, fit: ImageFit, vp: Viewport) -> CameraState:
    s_min = min_scale_at_rotation(fit, vp, state.rotation) * SCALE_PAD
    return clamp_camera(CameraState(state.x, state.y, max(state.scale, s_min), state.rotation), fit, vp)


def _kf(t: float, st: CameraState, easing: str = "smoother") -> Keyframe:
    return Keyframe(t, st.x, st.y, st.scale, st.rotation, easing)


def k_generate(motion_type: str, intensity_in: float, duration: float,
               fit: ImageFit, vp: Viewport, rng, seed: int) -> List[Keyframe]:
    i = min(max(intensity_in, 0.0), 1.0)
    base = 1.04 + 0.10 * i
    kfs: List[Keyframe] = []

    if motion_type == "zoomIn":
        s0, s1 = base, base * (1.16 + 0.26 * i)
        dx = rng.range(-0.05, 0.05) * 0.2
        dy = rng.range(-0.05, 0.05) * 0.2
        kfs = [_kf(0.0, _clip(CameraState(dx, dy, s0, 0.0), fit, vp)),
               _kf(duration, _clip(CameraState(dx, dy, s1, 0.0), fit, vp))]
    elif motion_type == "zoomOut":
        s1, s0 = base, base * (1.16 + 0.26 * i)
        dx = rng.range(-0.1, 0.1) * 0.2
        dy = rng.range(-0.1, 0.1) * 0.2
        kfs = [_kf(0.0, _clip(CameraState(dx, dy, s0, 0.0), fit, vp)),
               _kf(duration, _clip(CameraState(dx, dy, s1, 0.0), fit, vp))]
    elif motion_type in ("panLeft", "panRight", "panUp", "panDown"):
        s = base * (1.18 + 0.20 * i)
        mx, my = max_pan(fit, vp, s, 0.0)
        travel = 0.75 + 0.20 * i
        jitter = rng.range(-0.15, 0.15)
        end_zoom = rng.range(1.0, 1.05)
        if motion_type == "panLeft":
            a = CameraState(mx * travel, jitter * my, s, 0.0)
            b = CameraState(-mx * travel, a.y, s * end_zoom, 0.0)
        elif motion_type == "panRight":
            a = CameraState(-mx * travel, jitter * my, s, 0.0)
            b = CameraState(mx * travel, a.y, s * end_zoom, 0.0)
        elif motion_type == "panUp":
            a = CameraState(jitter * mx, my * travel, s, 0.0)
            b = CameraState(a.x, -my * travel, s * end_zoom, 0.0)
        else:
            a = CameraState(jitter * mx, -my * travel, s, 0.0)
            b = CameraState(a.x, my * travel, s * end_zoom, 0.0)
        kfs = [_kf(0.0, _clip(a, fit, vp)), _kf(duration, _clip(b, fit, vp))]
    elif motion_type in ("diagonalLeft", "diagonalRight"):
        s = base * (1.22 + 0.22 * i)
        mx, my = max_pan(fit, vp, s, 0.0)
        travel = 0.75 + 0.20 * i
        sx = 1 if motion_type == "diagonalRight" else -1
        sy = rng.sign()
        a = CameraState(-sx * mx * travel, -sy * my * travel * 0.8, s, 0.0)
        b = CameraState(sx * mx * travel, sy * my * travel * 0.8, s * 1.06, 0.0)
        kfs = [_kf(0.0, _clip(a, fit, vp)), _kf(duration, _clip(b, fit, vp))]
    elif motion_type in ("slowPush", "pullBack"):
        s_lo = 1.02 + 0.03 * i
        s_hi = s_lo * (1.10 + 0.10 * i)
        s0, s1 = (s_lo, s_hi) if motion_type == "slowPush" else (s_hi, s_lo)
        dx = rng.range(-0.12, 0.12)
        dy = rng.range(-0.12, 0.12)
        kfs = [_kf(0.0, _clip(CameraState(dx, dy, s0, 0.0), fit, vp)),
               _kf(duration, _clip(CameraState(-dx * 0.5, -dy * 0.5, s1, 0.0), fit, vp))]
    elif motion_type == "zoomPan":
        s0 = base * 1.02
        s1 = base * (1.22 + 0.24 * i)
        s_mid = max(s0, s1)
        mx, my = max_pan(fit, vp, s_mid, 0.0)
        sx = rng.sign()
        sy = rng.sign()
        a = CameraState(-sx * mx * 0.6, -sy * my * 0.6, s0, 0.0)
        b = CameraState(sx * mx * 0.6, sy * my * 0.6, s1, 0.0)
        kfs = [_kf(0.0, _clip(a, fit, vp)), _kf(duration, _clip(b, fit, vp))]
    elif motion_type == "subtleRotation":
        deg = (0.8 + 1.4 * i) * rng.sign()
        r1 = deg * RAD
        s = max(1.10 + 0.08 * i, min_scale_at_rotation(fit, vp, abs(r1)) * 1.02)
        mx, my = max_pan(fit, vp, s, r1)
        a = CameraState(-mx * 0.15, -my * 0.15, s, 0.0)
        b = CameraState(mx * 0.15, my * 0.15, s * 1.03, r1)
        kfs = [_kf(0.0, _clip(a, fit, vp)), _kf(duration, _clip(b, fit, vp))]
    elif motion_type == "drift":
        s = 1.06 + 0.10 * i
        mx, my = max_pan(fit, vp, s, 0.0)
        ang = rng.range(0.0, 2 * math.pi)
        r_end = (0.4 + 0.9 * i) * rng.sign() * RAD
        amp = 0.45 + 0.3 * i
        mid_ang = ang + math.pi / 2 * rng.sign()
        a = CameraState(-math.cos(ang) * mx * amp, -math.sin(ang) * my * amp, s, 0.0)
        mid = CameraState(math.cos(mid_ang) * mx * amp * 0.35,
                          math.sin(mid_ang) * my * amp * 0.35,
                          s * 1.04, r_end * 0.5)
        b = CameraState(math.cos(ang) * mx * amp, math.sin(ang) * my * amp,
                        s * 1.07, r_end)
        kfs = [_kf(0.0, _clip(a, fit, vp)),
               _kf(duration * 0.5, _clip(mid, fit, vp)),
               _kf(duration, _clip(b, fit, vp))]
    elif motion_type == "centerToCorner":
        s0 = 1.02 + 0.05 * i
        s1 = s0 * (1.12 + 0.18 * i)
        mx, my = max_pan(fit, vp, s1, 0.0)
        csx, csy = rng.sign(), rng.sign()
        kfs = [_kf(0.0, _clip(CameraState(0.0, 0.0, s0, 0.0), fit, vp)),
               _kf(duration, _clip(CameraState(csx * mx * (0.7 + 0.25 * i),
                                               csy * my * (0.7 + 0.25 * i),
                                               s1, 0.0), fit, vp))]
    elif motion_type == "combined":
        s0 = 1.03 + 0.04 * i
        s1 = s0 * (1.14 + 0.22 * i)
        s_mid = max(s0, s1)
        mx, my = max_pan(fit, vp, s_mid, 1.2 * RAD)
        r_end = (0.6 + 1.0 * i) * rng.sign() * RAD
        ang = rng.range(0.0, 2 * math.pi)
        amp = 0.55 + 0.25 * i
        a = CameraState(-math.cos(ang) * mx * amp, -math.sin(ang) * my * amp, s0, 0.0)
        mid = CameraState(0.0, 0.0, (s0 + s1) / 2, r_end * 0.5)
        b = CameraState(math.cos(ang) * mx * amp, math.sin(ang) * my * amp, s1, r_end)
        kfs = [_kf(0.0, _clip(a, fit, vp)),
               _kf(duration * 0.5, _clip(mid, fit, vp)),
               _kf(duration, _clip(b, fit, vp))]
    else:
        raise ValueError(motion_type)

    kfs[0].time = 0.0
    kfs[-1].time = duration
    return kfs


# --- TimelineEngine.kt: Timeline.layersAt (audio-critical exactness) ---------

def k_layers_at(t_raw: float, durations: Sequence[float],
                transitions: Sequence[dict]):
    """Transcription of the Kotlin `layersAt`. Mirrors `resolve_layers`."""
    total = float(sum(durations))
    t = min(max(t_raw, 0.0), total)
    n = len(durations)
    if t >= total:
        return [(n - 1, durations[n - 1], "single", 1.0)]

    starts, acc = [], 0.0
    for d in durations:
        starts.append(acc)
        acc += d

    for i in range(n - 1):
        tr = transitions[i] if i < len(transitions) else {"type": "crossDissolve",
                                                          "duration": 0.6}
        if tr["type"] == "none":
            d = 0.0
        else:
            d = max(0.0, min(tr["duration"], durations[i], durations[i + 1]))
        if d <= 0.0:
            continue
        boundary = starts[i] + durations[i]
        half = d / 2.0
        if abs(t - boundary) < half:
            p = min(max((t - (boundary - half)) / d, 0.0), 1.0)
            out_local = min(durations[i], max(0.0, t - starts[i]))
            in_local = min(durations[i + 1], max(0.0, t - starts[i + 1]))
            return [(i, out_local, "out", p), (i + 1, in_local, "in", p)]

    lo, hi = 0, n - 1
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if starts[mid] <= t:
            lo = mid
        else:
            hi = mid - 1
    return [(lo, min(durations[lo], max(0.0, t - starts[lo])), "single", 0.0)]


# --- MotionPathEngine.kt -----------------------------------------------------
#
# Line-by-line transcription of the Kotlin path engine (draw / op order
# included). The Kotlin code is itself a 1:1 port of motion_path.py, so the
# operations below match the reference; this exists to catch drift in the
# *Kotlin* file against the goldens the JVM tests read.

K_LUT_SIZE = 4096
K_REFINE_STEPS = 16
K_PATH_PRESET_WEIGHTS = [("circularCw", 1.2), ("circularCcw", 1.2),
                         ("elliptical", 1.0), ("sCurve", 1.1),
                         ("spiral", 0.8), ("figureEight", 0.7), ("arc", 1.0)]
K_SPIRAL_RHO0_MIN = 0.15
K_SPIRAL_RHO0_RANGE = 0.75
K_STROKE_DEDUPE_MIN_DIST = 0.004
K_STROKE_TARGET_POINTS = 24
K_CHAIKIN_ITERS = 2
K_SCALE_PAD = 1.002


class KSpec:
    """A MotionPathSpec as parsed from the golden JSON."""

    def __init__(self, d: dict):
        self.preset = str(d.get("preset", "circularCw"))
        self.centerX = float(d.get("centerX", 0.0))
        self.centerY = float(d.get("centerY", 0.0))
        self.radiusX = float(d.get("radiusX", 0.25))
        self.radiusY = float(d.get("radiusY", 0.25))
        self.turns = float(d.get("turns", 1.0))
        self.startAngle = float(d.get("startAngle", -math.pi / 2.0))
        self.sweep = float(d.get("sweep", 2.0 * math.pi))
        self.curvature = float(d.get("curvature", 0.5))
        self.speed = float(d.get("speed", 1.0))
        self.speedEase = float(d.get("speedEase", 0.0))
        self.startZoom = float(d.get("startZoom", 1.15))
        self.endZoom = float(d.get("endZoom", 1.30))
        self.startRotation = float(d.get("startRotation", 0.0))
        self.endRotation = float(d.get("endRotation", 0.0))
        self.direction = int(d.get("direction", 1))
        self.points = [(float(p["x"]), float(p["y"]))
                       for p in d.get("points", [])]
        self.isCustom = bool(d.get("isCustom", False))
        self.isUserEdited = bool(d.get("isUserEdited", False))


def k_linear_endpoints(spec: KSpec):
    if len(spec.points) >= 2:
        return spec.points[0], spec.points[1]
    return (spec.centerX - spec.radiusX, spec.centerY - spec.radiusY), \
           (spec.centerX + spec.radiusX, spec.centerY + spec.radiusY)


def k_scurve_waypoints(spec: KSpec):
    if len(spec.points) >= 3:
        return list(spec.points)
    bend = (2.0 * spec.curvature - 1.0) * spec.radiusY
    return [(spec.centerX - spec.radiusX, spec.centerY + bend),
            (spec.centerX, spec.centerY),
            (spec.centerX + spec.radiusX, spec.centerY - bend)]


def k_bezier_points(spec: KSpec):
    if len(spec.points) >= 4:
        return list(spec.points[:4])
    bend = (2.0 * spec.curvature - 1.0) * spec.radiusY
    return [(spec.centerX - spec.radiusX, spec.centerY),
            (spec.centerX - spec.radiusX * 0.5, spec.centerY + bend),
            (spec.centerX + spec.radiusX * 0.5, spec.centerY - bend),
            (spec.centerX + spec.radiusX, spec.centerY)]


def k_snap_turns(spec: KSpec) -> float:
    if spec.preset == "figureEight":
        return float(int(round(spec.turns)) if spec.turns >= 0.5 else 1)
    return spec.turns


def k_cr_segment(p0, p1, p2, p3, w: float):
    t0 = 0.0
    t1 = t0 + math.sqrt(math.hypot(p1[0] - p0[0], p1[1] - p0[1]))
    t2 = t1 + math.sqrt(math.hypot(p2[0] - p1[0], p2[1] - p1[1]))
    t3 = t2 + math.sqrt(math.hypot(p3[0] - p2[0], p3[1] - p2[1]))
    if t2 - t1 < 1e-12:
        return p1
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


def k_cr_segment_derivative(p0, p1, p2, p3, at_end: bool):
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


def k_catmull_rom(pts, u: float):
    n = len(pts) - 1
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
    return k_cr_segment(p0, p1, p2, p3, w)


def k_raw_point(spec: KSpec, u: float):
    u = 0.0 if u < 0.0 else (1.0 if u > 1.0 else u)
    cx, cy = spec.centerX, spec.centerY
    rx, ry = spec.radiusX, spec.radiusY
    d = spec.direction
    if spec.preset == "linear":
        a, b = k_linear_endpoints(spec)
        return lerp(a[0], b[0], u), lerp(a[1], b[1], u)
    if spec.preset in ("circularCw", "circularCcw", "elliptical"):
        theta = spec.startAngle + d * 2.0 * math.pi * spec.turns * u
        return cx + rx * math.cos(theta), cy + ry * math.sin(theta)
    if spec.preset == "arc":
        theta = spec.startAngle + d * spec.sweep * u
        return cx + rx * math.cos(theta), cy + ry * math.sin(theta)
    if spec.preset == "spiral":
        rho0 = K_SPIRAL_RHO0_MIN + K_SPIRAL_RHO0_RANGE * (1.0 - spec.curvature)
        rho = lerp(rho0, 1.0, u)
        theta = spec.startAngle + d * 2.0 * math.pi * spec.turns * u
        return cx + rx * rho * math.cos(theta), cy + ry * rho * math.sin(theta)
    if spec.preset == "figureEight":
        k = k_snap_turns(spec)
        a = 2.0 * math.pi * k * u
        return cx + rx * math.sin(a), cy + ry * math.sin(a) * math.cos(a)
    if spec.preset == "sCurve":
        return k_catmull_rom(k_scurve_waypoints(spec), u)
    if spec.preset == "cubicBezier":
        p0, p1, p2, p3 = k_bezier_points(spec)
        iu = 1.0 - u
        a = iu * iu * iu
        b = 3.0 * iu * iu * u
        c = 3.0 * iu * u * u
        dd = u * u * u
        return (a * p0[0] + b * p1[0] + c * p2[0] + dd * p3[0],
                a * p0[1] + b * p1[1] + c * p2[1] + dd * p3[1])
    if spec.preset == "custom":
        pts = spec.points
        if len(pts) <= 1:
            return (cx, cy) if len(pts) == 0 else pts[0]
        return k_catmull_rom(pts, u)
    raise ValueError(f"unknown path preset {spec.preset!r}")


def k_path_tangent(spec: KSpec, u: float):
    e = 1e-3
    if u <= e:
        a = k_raw_point(spec, 0.0)
        b = k_raw_point(spec, u + e)
    elif u >= 1.0 - e:
        a = k_raw_point(spec, u - e)
        b = k_raw_point(spec, 1.0)
    else:
        a = k_raw_point(spec, u - e)
        b = k_raw_point(spec, u + e)
    dx, dy = b[0] - a[0], b[1] - a[1]
    m = math.hypot(dx, dy)
    if m < 1e-12:
        return (0.0, 0.0)
    return dx / m, dy / m


class KMotionPathEvaluator:
    """Mirror of the Kotlin `MotionPathEvaluator` (per-spec LUT cache)."""

    def __init__(self, spec: KSpec):
        self.spec = spec
        self.cum: Optional[List[float]] = None
        self._total = 0.0

    def total(self) -> float:
        if self.cum is None:
            self.build_lut()
        return self._total

    def build_lut(self) -> List[float]:
        cum = [0.0] * (K_LUT_SIZE + 1)
        du = 1.0 / K_LUT_SIZE
        px, py = k_raw_point(self.spec, 0.0)
        for i in range(1, K_LUT_SIZE + 1):
            s = 0.0
            for k in range(1, K_REFINE_STEPS + 1):
                qx, qy = k_raw_point(self.spec, (i - 1) * du + du * k / K_REFINE_STEPS)
                s = s + math.hypot(qx - px, qy - py)
                px, py = qx, qy
            cum[i] = cum[i - 1] + s
        self.cum = cum
        self._total = cum[K_LUT_SIZE]
        return cum

    def lut(self) -> List[float]:
        if self.cum is None:
            self.build_lut()
        return self.cum

    def param_at_arc(self, target: float) -> float:
        cum = self.lut()
        total = self.total()
        if target <= 0.0 or total <= 1e-9:
            return 0.0
        if target >= total:
            return 1.0
        lo, hi = 0, K_LUT_SIZE
        while lo + 1 < hi:
            mid = (lo + hi) // 2
            if cum[mid] >= target:
                hi = mid
            else:
                lo = mid
        i0 = hi - 1
        d = cum[hi] - cum[i0]
        if d < 1e-12:
            return (i0 + 0.5) / K_LUT_SIZE
        u0 = i0 / K_LUT_SIZE
        du = 1.0 / K_LUT_SIZE
        n = K_REFINE_STEPS
        px, py = k_raw_point(self.spec, u0)
        c = [0.0] * (n + 1)
        for k in range(1, n + 1):
            qx, qy = k_raw_point(self.spec, u0 + du * k / n)
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

    def progress_at(self, t: float, duration: float) -> float:
        if duration <= 1e-9:
            return 1.0
        q = t / duration
        if q < 0.0:
            q = 0.0
        elif q > 1.0:
            q = 1.0
        p = q * self.spec.speed
        if p > 1.0:
            p = 1.0
        if self.spec.speedEase > 0.0:
            e = p * p * p * (p * (6.0 * p - 15.0) + 10.0)
            p = p + self.spec.speedEase * (e - p)
        if p < 0.0:
            p = 0.0
        return p

    def evaluate(self, fit: ImageFit, vp: Viewport, t: float,
                 duration: float) -> CameraState:
        p = self.progress_at(t, duration)
        u = self.param_at_arc(p * self.total())
        px, py = k_raw_point(self.spec, u)
        s = log_lerp(self.spec.startZoom, self.spec.endZoom, p)
        r = self.spec.startRotation + k_shortest_angle(
            self.spec.startRotation, self.spec.endRotation) * p
        return clamp_camera(CameraState(px, py, s, r), fit, vp)


def k_bake(spec: KSpec, fit: ImageFit, vp: Viewport, duration: float,
           samples: int = 128) -> List[Keyframe]:
    ev = KMotionPathEvaluator(spec)
    kfs: List[Keyframe] = []
    for i in range(samples + 1):
        t = duration * i / samples
        st = ev.evaluate(fit, vp, t, duration)
        kfs.append(Keyframe(t, st.x, st.y, st.scale, st.rotation, "linear"))
    if kfs:
        kfs[0].time = 0.0
        kfs[-1].time = duration
    return kfs


def k_sanitize(spec: KSpec, fit: ImageFit, vp: Viewport) -> KSpec:
    r_max = max(abs(spec.startRotation), abs(spec.endRotation))
    s_zoom = max(spec.startZoom, spec.endZoom)
    s_min = min_scale_at_rotation(fit, vp, r_max) * K_SCALE_PAD
    start_zoom = spec.startZoom if spec.startZoom >= s_min else s_min
    end_zoom = spec.endZoom if spec.endZoom >= s_min else s_min
    lim = max_pan(fit, vp, max(start_zoom, end_zoom), r_max)
    mx, my = lim
    pts = [(clamp(x, -mx, mx), clamp(y, -my, my)) for (x, y) in spec.points]
    out = KSpec({
        "preset": spec.preset,
        "centerX": clamp(spec.centerX, -mx, mx),
        "centerY": clamp(spec.centerY, -my, my),
        "radiusX": clamp(spec.radiusX, 0.0, mx),
        "radiusY": clamp(spec.radiusY, 0.0, my),
        "turns": clamp(spec.turns, 0.05, 4.0),
        "startAngle": spec.startAngle,
        "sweep": clamp(spec.sweep, 0.1, 2.0 * math.pi),
        "curvature": clamp(spec.curvature, 0.0, 1.0),
        "speed": clamp(spec.speed, 0.25, 3.0),
        "speedEase": clamp(spec.speedEase, 0.0, 1.0),
        "startZoom": start_zoom,
        "endZoom": end_zoom,
        "startRotation": spec.startRotation,
        "endRotation": spec.endRotation,
        "direction": spec.direction,
        "points": [{"x": x, "y": y} for (x, y) in pts],
        "isCustom": spec.isCustom,
        "isUserEdited": spec.isUserEdited,
    })
    return out


def k_resample_uniform(pts, n: int):
    if len(pts) <= 1:
        return list(pts)
    cum = [0.0]
    for i in range(1, len(pts)):
        cum.append(cum[-1] + math.hypot(pts[i][0] - pts[i - 1][0],
                                        pts[i][1] - pts[i - 1][1]))
    total = cum[-1]
    if total < 1e-12:
        return [pts[0]] * n
    out = []
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


def k_chaikin(pts):
    if len(pts) <= 2:
        return list(pts)
    out = [pts[0]]
    for i in range(len(pts) - 1):
        x1, y1 = pts[i]
        x2, y2 = pts[i + 1]
        out.append((0.75 * x1 + 0.25 * x2, 0.75 * y1 + 0.25 * y2))
        out.append((0.25 * x1 + 0.75 * x2, 0.25 * y1 + 0.75 * y2))
    out.append(pts[-1])
    return out


def k_smooth_stroke(raw):
    pts = []
    for p in raw:
        if pts and math.hypot(p[0] - pts[-1][0], p[1] - pts[-1][1]) < K_STROKE_DEDUPE_MIN_DIST:
            continue
        pts.append(p)
    if len(pts) < 2:
        return pts
    out = k_resample_uniform(pts, K_STROKE_TARGET_POINTS)
    for _ in range(K_CHAIKIN_ITERS):
        out = k_chaikin(out)
    return k_resample_uniform(out, K_STROKE_TARGET_POINTS)


def k_pick_path_preset(rng: KRandom, previous: Optional[str] = None) -> str:
    pool = [p for p, _ in K_PATH_PRESET_WEIGHTS]
    if previous is not None and len(pool) > 1:
        filtered = [p for p in pool if p != previous]
        if filtered:
            pool = filtered
    weights = [dict(K_PATH_PRESET_WEIGHTS)[p] for p in pool]
    total = sum(weights)
    r = rng.next_double() * total
    acc = 0.0
    for p, w in zip(pool, weights):
        acc += w
        if r <= acc:
            return p
    return pool[-1]


def k_generate_path_profile(rng: KRandom, intensity: float, duration: float,
                            fit: ImageFit, vp: Viewport, seed: int,
                            exclude_preset: Optional[str] = None,
                            preset: Optional[str] = None):
    i = clamp(intensity, 0.0, 1.0)
    chosen = preset if preset is not None else k_pick_path_preset(rng, exclude_preset)
    direction = rng.sign()
    start_angle = rng.range(0.0, 2.0 * math.pi)
    curvature = rng.range(0.15, 0.85)
    speed = rng.range(0.8, 1.4)
    speed_ease = rng.range(0.0, 0.5)
    turns = 1.0
    sweep = 2.0 * math.pi
    if chosen in ("circularCw", "circularCcw", "spiral") and rng.bool(0.25):
        turns = 2.0
    if chosen == "figureEight":
        turns = float(rng.irange(1, 2))
    if chosen == "arc":
        sweep = rng.range(0.6 * math.pi, 1.8 * math.pi)
    pattern = rng.irange(0, 4)
    base = 1.04 + 0.10 * i
    if pattern == 0:
        s0, s1 = base, base * (1.18 + 0.24 * i)
    elif pattern == 1:
        s0, s1 = base * (1.18 + 0.24 * i), base
    elif pattern == 2:
        s0 = base * (1.05 + 0.08 * i)
        s1 = s0 * rng.range(1.0, 1.06)
    elif pattern == 3:
        s0 = 1.03 + 0.04 * i
        s1 = s0 * (1.12 + 0.18 * i)
    else:
        s1 = 1.03 + 0.04 * i
        s0 = s1 * (1.12 + 0.18 * i)
    if rng.bool(0.5):
        r0 = 0.0
        r1 = math.radians(rng.range(0.4, 1.5) * rng.sign())
    else:
        r0 = 0.0
        r1 = 0.0
    s_max = max(s0, s1)
    lim = max_pan(fit, vp, s_max, abs(r1 - r0))
    margin = min(lim[0], lim[1])
    if margin < 0.02:
        margin = 0.02
    r = margin * (0.35 + 0.45 * i)
    if r < 0.03:
        r = 0.03
    radius_x = r
    if chosen in ("elliptical", "sCurve", "figureEight"):
        radius_y = r * rng.range(0.7, 1.0)
    else:
        radius_y = r
    if rng.bool(0.3):
        c_x = rng.range(-0.1, 0.1)
        c_y = rng.range(-0.1, 0.1)
    else:
        c_x = 0.0
        c_y = 0.0
    spec = k_sanitize(KSpec({
        "preset": chosen, "centerX": c_x, "centerY": c_y,
        "radiusX": radius_x, "radiusY": radius_y, "turns": turns,
        "startAngle": start_angle, "sweep": sweep, "curvature": curvature,
        "speed": speed, "speedEase": speed_ease, "startZoom": s0,
        "endZoom": s1, "startRotation": r0, "endRotation": r1,
        "direction": direction,
    }), fit, vp)
    kfs = k_bake(spec, fit, vp, duration)
    mtype = "zoomIn" if s1 >= s0 else ("zoomOut" if s0 > s1 else "drift")
    return mtype, i, kfs, seed, spec
