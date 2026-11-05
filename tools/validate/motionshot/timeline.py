"""Timeline composition and transitions (docs/MOTION_SPEC.md §6, §7.2)."""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import List, Optional, Sequence, Tuple

TRANSITION_TYPES: List[str] = [
    "crossDissolve", "fade", "fadeToBlack",
    "slideLeft", "slideRight", "zoomTransition",
    "blurTransition", "smoothZoom", "none",
]

DEFAULT_TRANSITION_SECONDS = 0.6


@dataclass
class TransitionSpec:
    type: str = "crossDissolve"
    duration: float = DEFAULT_TRANSITION_SECONDS

    def to_json(self) -> dict:
        return {"type": self.type, "duration": self.duration}

    @staticmethod
    def from_json(d: dict) -> "TransitionSpec":
        return TransitionSpec(d.get("type", "crossDissolve"),
                              float(d.get("duration", DEFAULT_TRANSITION_SECONDS)))


@dataclass
class Segment:
    """One photo on the timeline."""
    photo_id: str
    index: int
    start: float
    duration: float

    @property
    def end(self) -> float:
        return self.start + self.duration


def build_timeline(durations: Sequence[float],
                   transitions: Sequence[TransitionSpec]) -> List[Segment]:
    """spec §6.3 — starts are cumulative sums, NOT reduced by overlaps."""
    segs: List[Segment] = []
    t = 0.0
    for i, d in enumerate(durations):
        if d <= 0:
            raise ValueError("photo duration must be > 0")
        segs.append(Segment(photo_id="", index=i, start=t, duration=d))
        t += d
    return segs


def total_duration(durations: Sequence[float]) -> float:
    return float(sum(durations))


def clamped_transition(i: int, durations: Sequence[float],
                       transitions: Sequence[TransitionSpec]) -> float:
    """§6.2 — a transition can never consume more than either neighbour."""
    if i < 0 or i >= len(durations) - 1:
        return 0.0
    tr = transitions[i] if i < len(transitions) else TransitionSpec()
    if tr.type == "none":
        return 0.0
    return max(0.0, min(tr.duration, durations[i], durations[i + 1]))


@dataclass
class Layer:
    photo_index: int
    local_time: float
    role: str          # 'single' | 'out' | 'in'
    progress: float    # transition progress p; 0 for 'single'
    transition: str = "none"


def resolve_layers(t: float, durations: Sequence[float],
                   transitions: Sequence[TransitionSpec]) -> List[Layer]:
    """Which photo(s) are visible at time t (§6.4).

    Invariant: for a transition window the returned layers always include one
    'out' and one 'in' layer, and the transition renderer's alphas sum to 1.
    """
    n = len(durations)
    if n == 0:
        raise ValueError("empty timeline")
    total = total_duration(durations)
    if t < 0:
        t = 0.0
    if t >= total:
        return [Layer(n - 1, durations[n - 1], "single", 1.0)]

    # cumulative boundaries
    starts = []
    acc = 0.0
    for d in durations:
        starts.append(acc)
        acc += d

    # transition windows first (they straddle segment boundaries)
    for i in range(n - 1):
        D = clamped_transition(i, durations, transitions)
        if D <= 0:
            continue
        boundary = starts[i] + durations[i]
        half = D / 2.0
        if abs(t - boundary) < half:
            p = (t - (boundary - half)) / D
            out_local = min(durations[i], max(0.0, t - starts[i]))
            in_local = min(durations[i + 1], max(0.0, t - starts[i + 1]))
            tr = transitions[i].type if i < len(transitions) else "crossDissolve"
            return [
                Layer(i, out_local, "out", p, tr),
                Layer(i + 1, in_local, "in", p, tr),
            ]

    # single photo
    lo, hi = 0, n - 1
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if starts[mid] <= t:
            lo = mid
        else:
            hi = mid - 1
    local = min(durations[lo], max(0.0, t - starts[lo]))
    return [Layer(lo, local, "single", 0.0)]


# --------------------------------------------------------------------------
# transition visual parameters (§7.2)
# --------------------------------------------------------------------------

@dataclass
class DrawLayer:
    photo_index: int
    local_time: float
    alpha: float = 1.0
    offset_x: float = 0.0     # in viewport widths
    offset_y: float = 0.0     # in viewport heights
    zoom_mul: float = 1.0
    blur_px: float = 0.0      # at 1080p reference; scaled by outH/1080
    blend_hold: bool = False  # 'fade' freezes the outgoing motion


BLUR_REFERENCE_HEIGHT = 1080.0
BLUR_MAX_RADIUS = 12.0


def transition_draw_layers(layers: Sequence[Layer]) -> List[DrawLayer]:
    """Convert resolved layers into concrete draw parameters.

    Guarantees (checked by tests): alpha_out + alpha_in == 1.0 for every
    non-black transition type at every p.
    """
    if len(layers) == 1:
        L = layers[0]
        return [DrawLayer(L.photo_index, L.local_time, alpha=1.0)]

    out, inn = layers[0], layers[1]
    p = min(1.0, max(0.0, out.progress))
    tr = out.transition
    o = DrawLayer(out.photo_index, out.local_time)
    i = DrawLayer(inn.photo_index, inn.local_time)

    if tr in ("crossDissolve", "none"):
        o.alpha = 1.0 - p
        i.alpha = p

    elif tr == "fade":
        # Outgoing layer holds at full opacity, and fades out over the whole
        # window while the incoming fades in: identical alphas to crossDissolve
        # but the outgoing *motion* is frozen at the boundary state.
        o.alpha = 1.0 - p
        i.alpha = p
        o.blend_hold = True

    elif tr == "fadeToBlack":
        # Explicit black pass-through (documented, intentional — see §6.2).
        if p <= 0.5:
            o.alpha = max(0.0, 1.0 - 2.0 * p)
            i.alpha = 0.0
        else:
            o.alpha = 0.0
            i.alpha = min(1.0, 2.0 * p - 1.0)

    elif tr == "slideLeft":
        o.offset_x = -p
        i.offset_x = 1.0 - p
        o.alpha = 1.0
        i.alpha = 1.0

    elif tr == "slideRight":
        o.offset_x = p
        i.offset_x = p - 1.0
        o.alpha = 1.0
        i.alpha = 1.0

    elif tr == "zoomTransition":
        o.zoom_mul = 1.0 + 0.25 * p
        i.zoom_mul = 0.80 + 0.20 * p
        o.alpha = 1.0 - p
        i.alpha = p

    elif tr == "smoothZoom":
        o.zoom_mul = 1.0 + 0.12 * p
        i.zoom_mul = 0.94 + 0.06 * p
        o.alpha = 1.0 - p
        i.alpha = p

    elif tr == "blurTransition":
        o.blur_px = BLUR_MAX_RADIUS * p
        i.blur_px = BLUR_MAX_RADIUS * (1.0 - p)
        o.alpha = 1.0 - p
        i.alpha = p

    else:
        raise ValueError(f"unknown transition {tr!r}")

    return [o, i]


def transition_alpha_sum(layers: Sequence[Layer]) -> float:
    dl = transition_draw_layers(layers)
    return sum(d.alpha for d in dl)
