"""Deterministic math primitives shared by every MotionShot implementation.

This module is the executable form of docs/MOTION_SPEC.md sections 2 and 10.
The Dart (`lib/features/motion/easing.dart`, `random.dart`) and Kotlin
(`motion/KeyframeEngine.kt`, `motion/RandomMotion.kt`) ports must reproduce the
values in tools/validate/golden/*.json exactly.
"""
from __future__ import annotations

import math

M64 = 0xFFFFFFFFFFFFFFFF


def wrap64(v: int) -> int:
    return v & M64


def to_signed64(v: int) -> int:
    v &= M64
    return v - (1 << 64) if v >= (1 << 63) else v


# --------------------------------------------------------------------------
# Easing  (spec §2)
# --------------------------------------------------------------------------

def _bezier(x1: float, y1: float, x2: float, y2: float, t: float) -> float:
    if t <= 0.0:
        return 0.0
    if t >= 1.0:
        return 1.0
    x1 = min(max(x1, 0.0), 1.0)
    x2 = min(max(x2, 0.0), 1.0)

    def cx(u: float) -> float:
        return 3 * (1 - u) ** 2 * u * x1 + 3 * (1 - u) * u ** 2 * x2 + u ** 3

    def cy(u: float) -> float:
        return 3 * (1 - u) ** 2 * u * y1 + 3 * (1 - u) * u ** 2 * y2 + u ** 3

    def dcdx(u: float) -> float:
        return 3 * (1 - u) ** 2 * x1 + 6 * (1 - u) * u * (x2 - x1) + 3 * u ** 2 * (1 - x2)

    # Newton-Raphson (fast path), bisection fallback for flat regions.
    u = t
    for _ in range(8):
        err = cx(u) - t
        if abs(err) < 1e-9:
            return cy(u)
        d = dcdx(u)
        if abs(d) < 1e-9:
            break
        u -= err / d
        if u < 0 or u > 1:
            break
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
        u = (lo + hi) / 2
    return cy(u)


CUSTOM_DEFAULT = (0.42, 0.0, 0.58, 1.0)


def ease(kind: str, t: float, curve=None) -> float:
    t = 0.0 if t < 0 else (1.0 if t > 1 else t)
    if kind == "linear":
        return t
    if kind == "easeIn":
        return t * t
    if kind == "easeOut":
        return 1 - (1 - t) ** 2
    if kind == "easeInOut":
        return 2 * t * t if t < 0.5 else 1 - 2 * (1 - t) ** 2
    if kind == "smooth":
        return t * t * (3 - 2 * t)
    if kind == "smoother":
        return t * t * t * (t * (6 * t - 15) + 10)
    if kind == "custom":
        c = curve if curve is not None else CUSTOM_DEFAULT
        return _bezier(c[0], c[1], c[2], c[3], t)
    raise ValueError(f"unknown easing {kind!r}")


# --------------------------------------------------------------------------
# Hashing / PRNG  (spec §10)
# --------------------------------------------------------------------------

FNV_OFFSET = 0xCBF29CE484222325
FNV_PRIME = 0x100000001B3


def fnv1a64(text: str) -> int:
    h = FNV_OFFSET
    for b in text.encode("utf-8"):
        h ^= b
        h = wrap64(h * FNV_PRIME)
    return h


def splitmix64(state: int) -> tuple[int, int]:
    """Returns (new_state, value)."""
    state = wrap64(state + 0x9E3779B97F4A7C15)
    z = state
    z = wrap64((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9)
    z = wrap64((z ^ (z >> 27)) * 0x94D049BB133111EB)
    return state, wrap64(z ^ (z >> 31))


class Xorshift128Plus:
    """Bit-exact with the Dart and Kotlin ports."""

    def __init__(self, seed: int):
        s = wrap64(seed)
        s, v0 = splitmix64(s)
        s, v1 = splitmix64(s)
        # never allow an all-zero state
        if v0 == 0 and v1 == 0:
            v0 = 0x9E3779B97F4A7C15
        self.s0 = v0
        self.s1 = v1

    def next_u64(self) -> int:
        s1 = self.s0
        s0 = self.s1
        self.s0 = s0
        s1 ^= wrap64(s1 << 23)
        s1 ^= s1 >> 17
        s1 ^= s0
        s1 ^= s0 >> 26
        self.s1 = wrap64(s1)
        return wrap64(s0 + s1)

    def next_double(self) -> float:
        return (self.next_u64() >> 11) * (1.0 / (1 << 53))

    def range(self, lo: float, hi: float) -> float:
        return lo + (hi - lo) * self.next_double()

    def irange(self, lo: int, hi_inclusive: int) -> int:
        n = hi_inclusive - lo + 1
        return lo + int(self.next_u64() % n)

    def bool(self, p_true: float = 0.5) -> bool:
        return self.next_double() < p_true

    def sign(self) -> int:
        return 1 if (self.next_u64() & 1) else -1


def photo_seed(project_seed: int, photo_id: str, index: int) -> int:
    mixed = (wrap64(project_seed) ^ fnv1a64(photo_id) ^
             wrap64((index + 1) * 0x9E3779B97F4A7C15))
    return wrap64(mixed)


# --------------------------------------------------------------------------
# small numeric helpers
# --------------------------------------------------------------------------

def clamp(v: float, lo: float, hi: float) -> float:
    if hi < lo:
        return (lo + hi) / 2
    return lo if v < lo else (hi if v > hi else v)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def log_lerp(a: float, b: float, t: float) -> float:
    if a <= 0 or b <= 0:
        return lerp(a, b, t)
    return math.exp(lerp(math.log(a), math.log(b), t))


def shortest_angle(a: float, b: float) -> float:
    d = (b - a) % (2 * math.pi)
    if d > math.pi:
        d -= 2 * math.pi
    return d
