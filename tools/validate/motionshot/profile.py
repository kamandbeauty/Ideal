"""Motion profiles, the 15 motion types and the deterministic random engine.

Executable form of docs/MOTION_SPEC.md §3, §4, §5, §10.
Ports: Dart `lib/features/motion/motion_types.dart` + `random_motion.dart`,
       Kotlin `motion/MotionTypes.kt` + `motion/RandomMotion.kt`.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence

from .camera import (CameraState, ImageFit, Keyframe, Viewport, clamp_camera,
                     max_pan, min_scale_at_rotation, sample_keyframes)
from .mathx import Xorshift128Plus, clamp, photo_seed, to_signed64, wrap64
from .motion_path import (MotionPathSpec, PATH_PRESET_WEIGHTS, bake_path,
                          evaluate_path, sanitize_path)

# --------------------------------------------------------------------------
# the 15 motion types (spec §5 of the product brief)
# --------------------------------------------------------------------------

MOTION_TYPES: List[str] = [
    "zoomIn",          # 1
    "zoomOut",         # 2
    "panLeft",         # 3
    "panRight",        # 4
    "panUp",           # 5
    "panDown",         # 6
    "diagonalLeft",    # 7
    "diagonalRight",   # 8
    "slowPush",        # 9
    "pullBack",        # 10
    "zoomPan",         # 11
    "subtleRotation",  # 12
    "drift",           # 13
    "centerToCorner",  # 14
    "combined",        # 15
]

DIRECTIONAL = {"panLeft", "panRight", "panUp", "panDown",
               "diagonalLeft", "diagonalRight", "zoomPan", "centerToCorner"}

# Relative likelihood when auto-generating. Rotation-heavy moves are rarer
# because they are the easiest to make look wrong.
BASE_WEIGHTS: Dict[str, float] = {
    "zoomIn": 1.4, "zoomOut": 1.2,
    "panLeft": 1.0, "panRight": 1.0, "panUp": 0.9, "panDown": 0.9,
    "diagonalLeft": 0.8, "diagonalRight": 0.8,
    "slowPush": 1.1, "pullBack": 1.0,
    "zoomPan": 1.2, "subtleRotation": 0.45, "drift": 0.5,
    "centerToCorner": 0.8, "combined": 1.0,
}


@dataclass
class MotionProfile:
    motion_type: str = "zoomIn"
    intensity: float = 0.6
    keyframes: List[Keyframe] = field(default_factory=list)
    seed: int = 0
    is_locked: bool = False
    is_motion_type_pinned: bool = False
    path: Optional[MotionPathSpec] = None

    def duration(self) -> float:
        return self.keyframes[-1].time if self.keyframes else 0.0

    def sample(self, local_time: float, fit: ImageFit,
               vp: Viewport) -> CameraState:
        # A path-driven profile evaluates the path directly — the same
        # function the exporter runs (spec §12.6). Profiles without a path
        # use the classic keyframe pipeline.
        if self.path is not None:
            return evaluate_path(self.path, fit, vp, local_time, self.duration())
        return clamp_camera(sample_keyframes(self.keyframes, local_time), fit, vp)

    def to_json(self) -> dict:
        return {
            "motionType": self.motion_type,
            "intensity": self.intensity,
            "seed": to_signed64(self.seed),
            "isLocked": self.is_locked,
            "isMotionTypePinned": self.is_motion_type_pinned,
            "keyframes": [k.to_json() for k in self.keyframes],
            "path": self.path.to_json() if self.path is not None else None,
        }

    @staticmethod
    def from_json(d: dict) -> "MotionProfile":
        path = None
        raw = d.get("path")
        if isinstance(raw, dict):
            try:
                path = MotionPathSpec.from_json(raw)
            except (ValueError, TypeError, KeyError):
                path = None  # foreign path data: fall back to keyframes
        return MotionProfile(
            motion_type=d.get("motionType", "zoomIn"),
            intensity=float(d.get("intensity", 0.6)),
            seed=wrap64(int(d.get("seed", 0))),
            is_locked=bool(d.get("isLocked", False)),
            is_motion_type_pinned=bool(d.get("isMotionTypePinned", False)),
            keyframes=[Keyframe.from_json(k) for k in d.get("keyframes", [])],
            path=path,
        )


# --------------------------------------------------------------------------
# generator
# --------------------------------------------------------------------------

def _clip(state: CameraState, fit: ImageFit, vp: Viewport) -> CameraState:
    """Clamp AND lift the scale to the rotation-safe minimum (§4)."""
    s_min = min_scale_at_rotation(fit, vp, state.rotation) * 1.002
    if state.scale < s_min:
        state.scale = s_min
    return clamp_camera(state, fit, vp)


def _kf(t: float, st: CameraState, easing: str = "smoother") -> Keyframe:
    return Keyframe(time=t, x=st.x, y=st.y, scale=st.scale,
                    rotation=st.rotation, easing=easing)


def generate_profile(motion_type: str, intensity: float, duration: float,
                     fit: ImageFit, vp: Viewport, rng: Xorshift128Plus,
                     seed: int) -> MotionProfile:
    """Build a legal, cinematic motion of `motion_type` for one photo."""
    i = clamp(intensity, 0.0, 1.0)
    ease = "smoother"
    kfs: List[Keyframe] = []

    # A single base zoom that leaves room for movement without cropping hard.
    base = 1.04 + 0.10 * i

    if motion_type == "zoomIn":
        s0, s1 = base, base * (1.16 + 0.26 * i)
        d = CameraState(rng.range(-0.05, 0.05) * 0.2, rng.range(-0.05, 0.05) * 0.2, s0, 0)
        kfs = [_kf(0, _clip(d, fit, vp)),
               _kf(duration, _clip(CameraState(d.x, d.y, s1, 0), fit, vp))]

    elif motion_type == "zoomOut":
        s1, s0 = base, base * (1.16 + 0.26 * i)
        d = CameraState(rng.range(-0.1, 0.1) * 0.2, rng.range(-0.1, 0.1) * 0.2, s0, 0)
        kfs = [_kf(0, _clip(d, fit, vp)),
               _kf(duration, _clip(CameraState(d.x, d.y, s1, 0), fit, vp))]

    elif motion_type in ("panLeft", "panRight", "panUp", "panDown"):
        s = base * (1.18 + 0.20 * i)
        mx, my = max_pan(fit, vp, s, 0.0)
        travel = (0.75 + 0.20 * i)
        if motion_type == "panLeft":
            a = CameraState(+mx * travel, rng.range(-0.15, 0.15) * my, s, 0)
            b = CameraState(-mx * travel, a.y, s * rng.range(1.0, 1.05), 0)
        elif motion_type == "panRight":
            a = CameraState(-mx * travel, rng.range(-0.15, 0.15) * my, s, 0)
            b = CameraState(+mx * travel, a.y, s * rng.range(1.0, 1.05), 0)
        elif motion_type == "panUp":
            a = CameraState(rng.range(-0.15, 0.15) * mx, +my * travel, s, 0)
            b = CameraState(a.x, -my * travel, s * rng.range(1.0, 1.05), 0)
        else:
            a = CameraState(rng.range(-0.15, 0.15) * mx, -my * travel, s, 0)
            b = CameraState(a.x, +my * travel, s * rng.range(1.0, 1.05), 0)
        kfs = [_kf(0, _clip(a, fit, vp)), _kf(duration, _clip(b, fit, vp))]

    elif motion_type in ("diagonalLeft", "diagonalRight"):
        s = base * (1.22 + 0.22 * i)
        mx, my = max_pan(fit, vp, s, 0.0)
        travel = 0.75 + 0.20 * i
        sx = 1 if motion_type == "diagonalRight" else -1
        sy = rng.sign()
        a = CameraState(-sx * mx * travel, -sy * my * travel * 0.8, s, 0)
        b = CameraState(+sx * mx * travel, +sy * my * travel * 0.8, s * 1.06, 0)
        kfs = [_kf(0, _clip(a, fit, vp)), _kf(duration, _clip(b, fit, vp))]

    elif motion_type in ("slowPush", "pullBack"):
        # Long, gentle push. Low intensity by design; easing is smootherstep.
        s_lo = 1.02 + 0.03 * i
        s_hi = s_lo * (1.10 + 0.10 * i)
        s0, s1 = (s_lo, s_hi) if motion_type == "slowPush" else (s_hi, s_lo)
        dx = rng.range(-0.12, 0.12)
        dy = rng.range(-0.12, 0.12)
        kfs = [_kf(0, _clip(CameraState(dx, dy, s0, 0), fit, vp), "smoother"),
               _kf(duration, _clip(CameraState(-dx * 0.5, -dy * 0.5, s1, 0),
                                   fit, vp), "smoother")]

    elif motion_type == "zoomPan":
        s0 = base * 1.02
        s1 = base * (1.22 + 0.24 * i)
        s_mid = max(s0, s1)
        mx, my = max_pan(fit, vp, s_mid, 0.0)
        sx, sy = rng.sign(), rng.sign()
        a = CameraState(-sx * mx * 0.6, -sy * my * 0.6, s0, 0)
        b = CameraState(+sx * mx * 0.6, +sy * my * 0.6, s1, 0)
        kfs = [_kf(0, _clip(a, fit, vp)), _kf(duration, _clip(b, fit, vp))]

    elif motion_type == "subtleRotation":
        deg = (0.8 + 1.4 * i) * rng.sign()
        r1 = math.radians(deg)
        s = max(1.10 + 0.08 * i, min_scale_at_rotation(fit, vp, abs(r1)) * 1.02)
        mx, my = max_pan(fit, vp, s, r1)
        a = CameraState(-mx * 0.15, -my * 0.15, s, 0.0)
        b = CameraState(+mx * 0.15, +my * 0.15, s * 1.03, r1)
        kfs = [_kf(0, _clip(a, fit, vp)), _kf(duration, _clip(b, fit, vp))]

    elif motion_type == "drift":
        s = 1.06 + 0.10 * i
        m = max_pan(fit, vp, s, 0.0)
        ang = rng.range(0, 2 * math.pi)
        r_end = math.radians((0.4 + 0.9 * i) * rng.sign())
        amp = 0.45 + 0.3 * i
        mid_ang = ang + math.pi / 2 * rng.sign()
        a = CameraState(-math.cos(ang) * m[0] * amp, -math.sin(ang) * m[1] * amp, s, 0.0)
        mid = CameraState(math.cos(mid_ang) * m[0] * amp * 0.35,
                          math.sin(mid_ang) * m[1] * amp * 0.35,
                          s * 1.04, r_end * 0.5)
        b = CameraState(math.cos(ang) * m[0] * amp, math.sin(ang) * m[1] * amp, s * 1.07, r_end)
        kfs = [_kf(0, _clip(a, fit, vp)),
               _kf(duration * 0.5, _clip(mid, fit, vp)),
               _kf(duration, _clip(b, fit, vp))]

    elif motion_type == "centerToCorner":
        s0 = 1.02 + 0.05 * i
        s1 = s0 * (1.12 + 0.18 * i)
        mx, my = max_pan(fit, vp, s1, 0.0)
        csx, csy = rng.sign(), rng.sign()
        a = CameraState(0.0, 0.0, s0, 0)
        b = CameraState(csx * mx * (0.7 + 0.25 * i), csy * my * (0.7 + 0.25 * i), s1, 0)
        kfs = [_kf(0, _clip(a, fit, vp)), _kf(duration, _clip(b, fit, vp))]

    elif motion_type == "combined":
        s0 = 1.03 + 0.04 * i
        s1 = s0 * (1.14 + 0.22 * i)
        s_mid = max(s0, s1)
        mx, my = max_pan(fit, vp, s_mid, math.radians(1.2))
        r_end = math.radians((0.6 + 1.0 * i) * rng.sign())
        ang = rng.range(0, 2 * math.pi)
        amp = 0.55 + 0.25 * i
        a = CameraState(-math.cos(ang) * mx * amp, -math.sin(ang) * my * amp, s0, 0.0)
        mid = CameraState(0.0, 0.0, (s0 + s1) / 2, r_end * 0.5)
        b = CameraState(math.cos(ang) * mx * amp, math.sin(ang) * my * amp, s1, r_end)
        kfs = [_kf(0, _clip(a, fit, vp)),
               _kf(duration * 0.5, _clip(mid, fit, vp)),
               _kf(duration, _clip(b, fit, vp))]
    else:
        raise ValueError(f"unknown motion type {motion_type!r}")

    prof = MotionProfile(motion_type=motion_type, intensity=i,
                         keyframes=kfs, seed=seed)
    # Monotonic time safety: keep first at 0 and last exactly at duration.
    prof.keyframes[0].time = 0.0
    prof.keyframes[-1].time = duration
    return prof


def pick_motion_type(rng: Xorshift128Plus, previous: Optional[str],
                     pinned: Optional[List[str]] = None) -> str:
    """Deterministic weighted draw that NEVER repeats the previous type.

    The previous type is removed from the candidate pool outright (spec §10
    rule 1) rather than merely down-weighted, so the guarantee holds for every
    seed. If the pool has only one entry the exclusion is skipped.
    """
    pool = list(pinned) if pinned else list(MOTION_TYPES)
    if previous is not None and len(pool) > 1:
        filtered = [t for t in pool if t != previous]
        if filtered:
            pool = filtered
    weights = [BASE_WEIGHTS.get(t, 1.0) for t in pool]
    total = sum(weights)
    r = rng.next_double() * total
    acc = 0.0
    for t, w in zip(pool, weights):
        acc += w
        if r <= acc:
            return t
    return pool[-1]


@dataclass
class PhotoMotionInput:
    """Minimal photo description needed to build motion profiles."""
    photo_id: str
    src_w: int
    src_h: int
    duration: float = 5.0


def build_profiles(photos: Sequence[PhotoMotionInput], viewport: Viewport,
                   project_seed: int, intensity: float = 0.6,
                   existing: Optional[Dict[str, MotionProfile]] = None,
                   regenerate: bool = True) -> Dict[str, MotionProfile]:
    """Generate (or regenerate) a profile per photo, deterministically.

    Locked profiles are always preserved (product rule #6). When
    `regenerate` is False, existing profiles are kept as-is.
    """
    existing = existing or {}
    out: Dict[str, MotionProfile] = {}
    prev_type: Optional[str] = None
    for idx, p in enumerate(photos):
        cur = existing.get(p.photo_id)
        if cur is not None and (cur.is_locked or not regenerate):
            out[p.photo_id] = cur
            prev_type = cur.motion_type
            continue
        seed = photo_seed(project_seed, p.photo_id, idx)
        rng = Xorshift128Plus(seed)
        if cur is not None and cur.is_motion_type_pinned:
            mtype = cur.motion_type
        else:
            mtype = pick_motion_type(rng, prev_type)
        fit = ImageFit.make(p.src_w, p.src_h, viewport)
        prof = generate_profile(mtype, intensity, p.duration, fit, viewport,
                               rng, seed)
        if cur is not None:
            prof.is_locked = cur.is_locked
            prof.is_motion_type_pinned = cur.is_motion_type_pinned
        out[p.photo_id] = prof
        prev_type = mtype
    return out


def regenerate_one(photo: PhotoMotionInput, viewport: Viewport,
                   project_seed: int, index: int, intensity: float = 0.6,
                   previous_type: Optional[str] = None) -> MotionProfile:
    seed = photo_seed(project_seed, photo.photo_id, index)
    rng = Xorshift128Plus(seed)
    mtype = pick_motion_type(rng, previous_type)
    fit = ImageFit.make(photo.src_w, photo.src_h, viewport)
    return generate_profile(mtype, intensity, photo.duration, fit, viewport,
                            rng, seed)


def migrate_aspect(profiles: Dict[str, MotionProfile],
                   photos: Sequence[PhotoMotionInput],
                   old_vp: Viewport, new_vp: Viewport) -> Dict[str, MotionProfile]:
    """Re-scale stored camera offsets when the output aspect changes.

    Keeps the *visual intent* of each shot: the same fraction of the available
    pan range. Prevents a legal 16:9 move becoming a cropped 9:16 move.
    """
    by_id = {p.photo_id: p for p in photos}
    out: Dict[str, MotionProfile] = {}
    for pid, prof in profiles.items():
        p = by_id.get(pid)
        if p is None:
            out[pid] = prof
            continue
        old_fit = ImageFit.make(p.src_w, p.src_h, old_vp)
        new_fit = ImageFit.make(p.src_w, p.src_h, new_vp)
        new_kfs = []
        for k in prof.keyframes:
            s_min = min_scale_at_rotation(new_fit, new_vp, k.rotation) * 1.002
            scale = max(k.scale, s_min)
            ox, oy = max_pan(old_fit, old_vp, k.scale, k.rotation)
            nx, ny = max_pan(new_fit, new_vp, scale, k.rotation)
            fx = (k.x / ox) if ox > 1e-9 else 0.0
            fy = (k.y / oy) if oy > 1e-9 else 0.0
            st = clamp_camera(CameraState(fx * nx, fy * ny, scale, k.rotation),
                              new_fit, new_vp)
            new_kfs.append(Keyframe(k.time, st.x, st.y, st.scale, st.rotation,
                                    k.easing, k.curve))
        # Path-driven shots migrate their geometry the same way: keep the
        # fraction of available travel, then re-sanitize + re-bake.
        new_path = None
        if prof.path is not None:
            r_max = max(abs(prof.path.start_rotation),
                        abs(prof.path.end_rotation))
            s_zoom = max(prof.path.start_zoom, prof.path.end_zoom)
            ox, oy = max_pan(old_fit, old_vp, s_zoom, r_max)
            nx, ny = max_pan(new_fit, new_vp, s_zoom, r_max)
            fx = 0.0 if ox < 1e-9 else (prof.path.radius_x / ox)
            fy = 0.0 if oy < 1e-9 else (prof.path.radius_y / oy)
            cx = (prof.path.center_x / ox) if ox > 1e-9 else 0.0
            cy = (prof.path.center_y / oy) if oy > 1e-9 else 0.0
            new_path = MotionPathSpec(
                preset=prof.path.preset,
                center_x=cx * nx, center_y=cy * ny,
                radius_x=fx * nx, radius_y=fy * ny,
                turns=prof.path.turns, start_angle=prof.path.start_angle,
                sweep=prof.path.sweep, curvature=prof.path.curvature,
                speed=prof.path.speed, speed_ease=prof.path.speed_ease,
                start_zoom=prof.path.start_zoom, end_zoom=prof.path.end_zoom,
                start_rotation=prof.path.start_rotation,
                end_rotation=prof.path.end_rotation,
                direction=prof.path.direction,
                points=[(px * (nx / ox) if ox > 1e-9 else 0.0,
                         py * (ny / oy) if oy > 1e-9 else 0.0)
                        for (px, py) in prof.path.points],
                is_custom=prof.path.is_custom,
                is_user_edited=prof.path.is_user_edited,
            )
            new_path = sanitize_path(new_path, new_fit, new_vp)
            new_kfs = bake_path(new_path, new_fit, new_vp,
                                prof.keyframes[-1].time) if new_kfs else new_kfs
        out[pid] = MotionProfile(prof.motion_type, prof.intensity, new_kfs,
                                 prof.seed, prof.is_locked,
                                 prof.is_motion_type_pinned,
                                 path=new_path)
    return out


# --------------------------------------------------------------------------
# random curved motion (spec §12.7)
# --------------------------------------------------------------------------

def pick_path_preset(rng: Xorshift128Plus,
                     previous: Optional[str] = None) -> str:
    """Weighted draw from the curved-motion pool; the previous photo's path
    preset is removed outright, so adjacent photos never share a path style
    (same hard guarantee as `pick_motion_type`, spec §10 rule 1)."""
    pool = [p for p in PATH_PRESET_WEIGHTS]
    if previous is not None and len(pool) > 1:
        filtered = [p for p in pool if p != previous]
        if filtered:
            pool = filtered
    weights = [PATH_PRESET_WEIGHTS[p] for p in pool]
    total = sum(weights)
    r = rng.next_double() * total
    acc = 0.0
    for p, w in zip(pool, weights):
        acc += w
        if r <= acc:
            return p
    return pool[-1]


def generate_path_profile(rng: Xorshift128Plus, intensity: float,
                          duration: float, fit: ImageFit, vp: Viewport,
                          seed: int, exclude_preset: Optional[str] = None,
                          preset: Optional[str] = None) -> MotionProfile:
    """One deterministic curved-path motion (spec §12.7).

    The draw order below is part of the contract: the Dart and Kotlin ports
    must perform exactly these draws, in exactly this order.
    """
    i = clamp(intensity, 0.0, 1.0)
    chosen = preset if preset is not None else pick_path_preset(rng, exclude_preset)
    direction = rng.sign()                       # 1
    start_angle = rng.range(0.0, 2.0 * math.pi)  # 2
    curvature = rng.range(0.15, 0.85)            # 3
    speed = rng.range(0.8, 1.4)                  # 4
    speed_ease = rng.range(0.0, 0.5)             # 5
    turns = 1.0
    sweep = 2.0 * math.pi
    if chosen in ("circularCw", "circularCcw", "spiral") and rng.bool(0.25):
        turns = 2.0                              # 6
    if chosen == "figureEight":
        turns = float(rng.irange(1, 2))       # 7
    if chosen == "arc":
        sweep = rng.range(0.6 * math.pi, 1.8 * math.pi)  # 8
    pattern = rng.irange(0, 4)                # 9
    base = 1.04 + 0.10 * i
    if pattern == 0:                             # circle + zoom in
        s0, s1 = base, base * (1.18 + 0.24 * i)
    elif pattern == 1:                           # curved + zoom out
        s0, s1 = base * (1.18 + 0.24 * i), base
    elif pattern == 2:                           # gentle drift, near-constant zoom
        s0 = base * (1.05 + 0.08 * i)
        s1 = s0 * rng.range(1.0, 1.06)           # 10
    elif pattern == 3:                           # slow push while curving
        s0 = 1.03 + 0.04 * i
        s1 = s0 * (1.12 + 0.18 * i)
    else:                                        # pull back while curving
        s1 = 1.03 + 0.04 * i
        s0 = s1 * (1.12 + 0.18 * i)
    if rng.bool(0.5):                          # 11
        r0 = 0.0
        r1 = math.radians(rng.range(0.4, 1.5) * rng.sign())  # 12
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
        radius_y = r * rng.range(0.7, 1.0)       # 13
    else:
        radius_y = r
    if rng.bool(0.3):                          # 14
        c_x = rng.range(-0.1, 0.1)
        c_y = rng.range(-0.1, 0.1)               # 15
    else:
        c_x = 0.0
        c_y = 0.0
    spec = sanitize_path(MotionPathSpec(
        preset=chosen, center_x=c_x, center_y=c_y,
        radius_x=radius_x, radius_y=radius_y, turns=turns,
        start_angle=start_angle, sweep=sweep, curvature=curvature,
        speed=speed, speed_ease=speed_ease, start_zoom=s0, end_zoom=s1,
        start_rotation=r0, end_rotation=r1, direction=direction,
    ), fit, vp)
    kfs = bake_path(spec, fit, vp, duration)
    mtype = "zoomIn" if s1 >= s0 else ("zoomOut" if s0 > s1 else "drift")
    return MotionProfile(motion_type=mtype, intensity=i, keyframes=kfs,
                         seed=seed, path=spec)
