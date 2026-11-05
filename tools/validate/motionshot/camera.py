"""Camera math — the executable form of docs/MOTION_SPEC.md §1, §3, §4, §5.

Every function here has a 1:1 port in:
  * Dart  : lib/features/motion/camera_math.dart   (preview + editing)
  * Kotlin: android/.../motion/CameraMath.kt       (native render + export)
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import List, Optional, Sequence, Tuple

from .mathx import clamp, ease, lerp, log_lerp, shortest_angle


# ---------------------------------------------------------------- viewport

@dataclass(frozen=True)
class Viewport:
    """Normalized viewport: shorter side == 1.0 (spec §1.2)."""
    aspect: float  # outW / outH

    @property
    def vw(self) -> float:
        return self.aspect if self.aspect >= 1.0 else 1.0

    @property
    def vh(self) -> float:
        return 1.0 if self.aspect >= 1.0 else 1.0 / self.aspect


# ---------------------------------------------------------------- cover fit

@dataclass(frozen=True)
class ImageFit:
    """Cover-fit of a source image into the viewport (spec §1.4)."""
    iw: float
    ih: float

    @staticmethod
    def make(src_w: int, src_h: int, vp: Viewport) -> "ImageFit":
        if src_w <= 0 or src_h <= 0:
            raise ValueError("image dimensions must be positive")
        cover = max(vp.vw / src_w, vp.vh / src_h)
        return ImageFit(iw=src_w * cover / 2.0, ih=src_h * cover / 2.0)


# ---------------------------------------------------------------- camera state

@dataclass
class CameraState:
    x: float = 0.0
    y: float = 0.0
    scale: float = 1.0
    rotation: float = 0.0

    def copy(self) -> "CameraState":
        return CameraState(self.x, self.y, self.scale, self.rotation)

    def as_tuple(self) -> Tuple[float, float, float, float]:
        return (self.x, self.y, self.scale, self.rotation)

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return (f"Cam(x={self.x:.5f}, y={self.y:.5f}, "
                f"s={self.scale:.5f}, r={math.degrees(self.rotation):.3f}deg)")


# ---------------------------------------------------------------- footprint

def half_extent(vp: Viewport, scale: float, rotation: float) -> Tuple[float, float]:
    """Visible viewport half-extents in normalized image units (spec §1.3)."""
    if scale <= 0:
        scale = 1e-6
    hw = vp.vw / (2.0 * scale)
    hh = vp.vh / (2.0 * scale)
    if rotation == 0.0:
        return hw, hh
    c = abs(math.cos(rotation))
    s = abs(math.sin(rotation))
    return hw * c + hh * s, hw * s + hh * c


def min_scale_at_rotation(fit: ImageFit, vp: Viewport, rotation: float) -> float:
    """Smallest scale that still covers the viewport at this rotation (§4)."""
    c = abs(math.cos(rotation))
    s = abs(math.sin(rotation))
    sx = (vp.vw * c + vp.vh * s) / (2.0 * fit.iw)
    sy = (vp.vw * s + vp.vh * c) / (2.0 * fit.ih)
    return max(sx, sy)


def max_pan(fit: ImageFit, vp: Viewport, scale: float,
            rotation: float) -> Tuple[float, float]:
    """Largest legal camera offset from center at this scale/rotation (§5)."""
    bw, bh = half_extent(vp, scale, rotation)
    return max(0.0, fit.iw - bw), max(0.0, fit.ih - bh)


def clamp_camera(state: CameraState, fit: ImageFit, vp: Viewport) -> CameraState:
    """Guarantee the viewport never reveals pixels outside the image (§3.2)."""
    if state.scale <= 0:
        raise ValueError("scale must be > 0")
    bw, bh = half_extent(vp, state.scale, state.rotation)
    out = CameraState(state.x, state.y, state.scale, state.rotation)
    if bw >= fit.iw:
        out.x = 0.0
    else:
        out.x = clamp(state.x, -fit.iw + bw, fit.iw - bw)
    if bh >= fit.ih:
        out.y = 0.0
    else:
        out.y = clamp(state.y, -fit.ih + bh, fit.ih - bh)
    return out


# ---------------------------------------------------------------- keyframes

@dataclass
class Keyframe:
    time: float
    x: float
    y: float
    scale: float
    rotation: float = 0.0
    easing: str = "smoother"
    curve: Optional[Sequence[float]] = None

    def to_json(self) -> dict:
        d = {
            "time": self.time, "x": self.x, "y": self.y,
            "scale": self.scale, "rotation": self.rotation,
            "easing": self.easing,
        }
        if self.curve is not None:
            d["curve"] = list(self.curve)
        return d

    @staticmethod
    def from_json(d: dict) -> "Keyframe":
        return Keyframe(
            time=float(d["time"]), x=float(d["x"]), y=float(d["y"]),
            scale=float(d["scale"]), rotation=float(d.get("rotation", 0.0)),
            easing=d.get("easing", "smoother"),
            curve=d.get("curve"),
        )


def sort_and_validate(keyframes: List[Keyframe]) -> List[Keyframe]:
    if len(keyframes) < 2:
        raise ValueError("a motion profile needs at least 2 keyframes")
    kfs = sorted(keyframes, key=lambda k: k.time)
    for a, b in zip(kfs, kfs[1:]):
        if b.time - a.time < 1e-3:
            raise ValueError("keyframes must be at least 1ms apart")
    for k in kfs:
        if k.scale <= 0:
            raise ValueError("keyframe scale must be > 0")
    return kfs


def sample_keyframes(kfs: Sequence[Keyframe], t: float) -> CameraState:
    """Spec §3.1."""
    if not kfs:
        raise ValueError("empty keyframe list")
    if t <= kfs[0].time:
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
    if dt <= 1e-9:
        return CameraState(b.x, b.y, b.scale, b.rotation)
    u = (t - a.time) / dt
    e = ease(a.easing, u, a.curve)
    return CameraState(
        x=lerp(a.x, b.x, e),
        y=lerp(a.y, b.y, e),
        scale=log_lerp(a.scale, b.scale, e),
        rotation=a.rotation + shortest_angle(a.rotation, b.rotation) * e,
    )
