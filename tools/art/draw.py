#!/usr/bin/env python3
"""A small vector-ish drawing kit on top of Pillow, used by gen_art.py.

Everything is drawn at 4× and downsampled with LANCZOS, which is what gives clean edges without an
anti-aliasing renderer. Colours come from the design tokens; nothing here invents a palette.

Conventions, so the call sites stay readable:

  * every function takes a **final** size in pixels and multiplies by `SS` internally;
  * shapes are described in **fractions** of the canvas (0..1), so one drawing scales to any size;
  * masks are greyscale images at supersampled size; an image layer is composited with `paste(layer, mask)`.

Design rules this kit encodes, because they are the difference between "flat vector" and "clip art":

  * a shape gets a silhouette first, then one gradient along one light direction, then a rim, then a
    single highlight — in that order, never more;
  * outlines are dark, thin and consistent, and never pure black;
  * shadows are soft, offset down-right, and never inside a shape;
  * gold is a gradient, not a yellow fill.

Lint: this file is Python, so `python3 -m py_compile tools/art/draw.py` is the check that matters.
"""
from __future__ import annotations

import math
from typing import Iterable, Sequence

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

SS = 4  # supersample factor


# ------------------------------------------------------------------------------------------------
# colour


def rgba(hex_colour: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_colour.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def mix(a, b, t: float) -> tuple[int, int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def shade(colour, amount: float) -> tuple[int, int, int, int]:
    """amount > 0 lightens toward white, < 0 darkens toward the night background."""
    if amount >= 0:
        return mix(colour, (255, 255, 255, colour[3]), amount)
    return mix(colour, (6, 12, 24, colour[3]), -amount)


def with_alpha(colour, alpha: int) -> tuple[int, int, int, int]:
    return (colour[0], colour[1], colour[2], alpha)


# ---- the palette, mirrored from replica/design/tokens.json (gen_art.py checks it) --------------

PALETTE = {
    "bg": "#0B1A2F",
    "surface": "#14294A",
    "surface-raised": "#1D3A61",
    "border": "#2C4E78",
    "border-input": "#5A83B1",
    "text": "#F7F2E6",
    "text-muted": "#BFCBDB",
    "accent": "#23B5B0",
    "accent-strong": "#12857F",
    "gold": "#E0A93F",
    "danger": "#F0735A",
    "success": "#58C98A",
    "warning": "#F0B429",
    "piece-firouzeh": "#2EC4B6",
    "piece-lajvard": "#2F5FD0",
    "piece-aqiq": "#D2553F",
    "piece-zomorrod": "#2E9E5B",
    "piece-morvarid": "#EFE3C8",
}

INK = rgba("#0A1524")
INK_SOFT = rgba("#0A1524", 150)
GOLD_LIGHT = rgba("#F2CE7B")
GOLD_MID = rgba(PALETTE["gold"])
GOLD_DARK = rgba("#9C6B1E")
IVORY = rgba(PALETTE["text"])
NIGHT = rgba(PALETTE["bg"])
NIGHT_DEEP = rgba("#060F1D")


# ------------------------------------------------------------------------------------------------
# canvases and gradients


def new(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def mask(w: int, h: int) -> Image.Image:
    return Image.new("L", (w * SS, h * SS), 0)


def solid(w: int, h: int, colour) -> Image.Image:
    return Image.new("RGBA", (w * SS, h * SS), colour)


def linear(w: int, h: int, top, bottom) -> Image.Image:
    height = h * SS
    width = w * SS
    t = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None, None]
    a = np.array(top[:3], dtype=np.float32)[None, None, :]
    b = np.array(bottom[:3], dtype=np.float32)[None, None, :]
    rows = (a * (1 - t) + b * t).astype(np.uint8)
    rgb = np.repeat(rows, width, axis=1)
    alpha = np.full((height, width, 1), 255, dtype=np.uint8)
    return _to_image(np.concatenate([rgb, alpha], axis=2))


def linear_band(w: int, h: int, start: float, end: float, top, bottom) -> Image.Image:
    """Vertical gradient that only changes between `start` and `end` (fractions of the height)."""
    height = h * SS
    width = w * SS
    y = np.linspace(0.0, 1.0, height, dtype=np.float32)
    t = np.clip((y - start) / max(1e-6, end - start), 0.0, 1.0)[:, None, None]
    a = np.array(top[:3], dtype=np.float32)[None, None, :]
    b = np.array(bottom[:3], dtype=np.float32)[None, None, :]
    rows = (a * (1 - t) + b * t).astype(np.uint8)
    rgb = np.repeat(rows, width, axis=1)
    alpha = np.full((height, width, 1), 255, dtype=np.uint8)
    return _to_image(np.concatenate([rgb, alpha], axis=2))


def radial(w: int, h: int, centre: tuple[float, float], radius: float, inner, outer) -> Image.Image:
    """Radial gradient. centre is a fraction of (w, h); radius is a fraction of the width."""
    width, height = w * SS, h * SS
    cx, cy = centre[0] * width, centre[1] * height
    r = max(radius * width, 1e-6)
    yy, xx = np.mgrid[0:height, 0:width].astype(np.float32)
    d = np.clip(np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r, 0.0, 1.0)[:, :, None]
    a = np.array(inner[:3], dtype=np.float32)[None, None, :]
    b = np.array(outer[:3], dtype=np.float32)[None, None, :]
    rgb = (a * (1 - d) + b * d).astype(np.uint8)
    alpha = np.full((height, width, 1), 255, dtype=np.uint8)
    return _to_image(np.concatenate([rgb, alpha], axis=2))


def _to_image(array: np.ndarray) -> Image.Image:
    return Image.fromarray(array, mode="RGBA")


# ------------------------------------------------------------------------------------------------
# masks


def scale(points: Iterable[tuple[float, float]], w: int, h: int) -> list[tuple[float, float]]:
    return [(x * w * SS, y * h * SS) for x, y in points]


def polygon_mask(w: int, h: int, points: Sequence[tuple[float, float]]) -> Image.Image:
    m = mask(w, h)
    ImageDraw.Draw(m).polygon(scale(points, w, h), fill=255)
    return m


def ellipse_mask(w: int, h: int, box: tuple[float, float, float, float]) -> Image.Image:
    m = mask(w, h)
    x0, y0, x1, y1 = box
    ImageDraw.Draw(m).ellipse((x0 * w * SS, y0 * h * SS, x1 * w * SS, y1 * h * SS), fill=255)
    return m


def rounded_mask(w: int, h: int, inset: float, radius: float) -> Image.Image:
    m = mask(w, h)
    pad = inset * w * SS
    ImageDraw.Draw(m).rounded_rectangle(
        (pad, pad, w * SS - pad, h * SS - pad), radius=radius * w * SS, fill=255)
    return m


def grow(m: Image.Image, px: float) -> Image.Image:
    size = max(3, int(px * SS) * 2 + 1)
    return m.filter(ImageFilter.MaxFilter(size if size % 2 else size + 1))


def shrink(m: Image.Image, px: float) -> Image.Image:
    size = max(3, int(px * SS) * 2 + 1)
    return m.filter(ImageFilter.MinFilter(size if size % 2 else size + 1))


def blur(m: Image.Image, px: float) -> Image.Image:
    return m.filter(ImageFilter.GaussianBlur(max(0.1, px * SS)))


def ring(outer: Image.Image, inner: Image.Image) -> Image.Image:
    return ImageChops.subtract(outer, inner)


def add(a: Image.Image, b: Image.Image) -> Image.Image:
    return ImageChops.add(a, b)


# ------------------------------------------------------------------------------------------------
# layers


def fill_image(w: int, h: int, colour) -> Image.Image:
    return solid(w, h, colour)


def gradient_masked(w: int, h: int, top, bottom, m: Image.Image) -> Image.Image:
    layer = linear(w, h, top, bottom)
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.paste(layer, (0, 0), m)
    return out


def fill_masked(w: int, h: int, colour, m: Image.Image) -> Image.Image:
    layer = solid(w, h, colour)
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.paste(layer, (0, 0), m)
    return out


def soft_shadow(w: int, h: int, m: Image.Image, offset: tuple[float, float], softness: float, alpha: int) -> Image.Image:
    shifted = Image.new("L", m.size, 0)
    shifted.paste(m, (int(offset[0] * SS), int(offset[1] * SS)))
    soft = blur(shifted, softness).point(lambda v: int(v * alpha / 255))
    out = Image.new("RGBA", m.size, (4, 8, 16, 255))
    out.putalpha(soft)
    return out


def outline(w: int, h: int, m: Image.Image, colour, width: float = 2.0) -> Image.Image:
    return fill_masked(w, h, colour, ring(grow(m, width), m))


def rim_light(w: int, h: int, m: Image.Image, colour, width: float = 2.0) -> Image.Image:
    """Light on the upper-left edge: the cheapest way to make a flat shape read as lit."""
    band = ring(m, shrink(m, width))
    arr = np.array(band, dtype=np.float32)
    height, width_px = arr.shape
    yy, xx = np.mgrid[0:height, 0:width_px]
    keep = ((xx / max(1, width_px)) + (yy / max(1, height)) < 1.05).astype(np.float32)
    arr = (arr * keep).astype(np.uint8)
    return fill_masked(w, h, colour, Image.fromarray(arr, mode="L"))


def layering(*layers: Image.Image) -> Image.Image:
    """Alpha-composites layers in order onto a transparent canvas the size of the first."""
    out = Image.new("RGBA", layers[0].size, (0, 0, 0, 0))
    for layer in layers:
        if layer is not None:
            out.alpha_composite(layer)
    return out


def finish(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), Image.LANCZOS)


# ------------------------------------------------------------------------------------------------
# shape library (all coordinates are fractions of the canvas)


def regular_polygon(cx: float, cy: float, rx: float, ry: float, sides: int, rotation: float = 0.0):
    return [
        (cx + rx * math.cos(rotation + 2 * math.pi * i / sides),
         cy + ry * math.sin(rotation + 2 * math.pi * i / sides))
        for i in range(sides)
    ]


def star_points(cx: float, cy: float, outer: float, inner: float, points: int = 5, rotation: float = -math.pi / 2):
    out = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = rotation + math.pi * i / points
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def shield_points(cx: float, cy: float, w: float, h: float):
    return [
        (cx - w / 2, cy - h / 2),
        (cx + w / 2, cy - h / 2),
        (cx + w / 2, cy + h * 0.08),
        (cx, cy + h / 2),
        (cx - w / 2, cy + h * 0.08),
    ]


def drop_points(cx: float, cy: float, w: float, h: float):
    return [
        (cx, cy - h / 2),
        (cx + w * 0.44, cy - h * 0.02),
        (cx + w * 0.34, cy + h * 0.32),
        (cx, cy + h / 2),
        (cx - w * 0.34, cy + h * 0.32),
        (cx - w * 0.44, cy - h * 0.02),
    ]


def arch_points(cx: float, base_y: float, width: float, height: float, shoulder: float = 0.62):
    """A Persian pointed arch as a closed polygon (two shoulders, one point)."""
    half = width / 2
    top = base_y - height
    return [
        (cx - half, base_y),
        (cx - half, top + height * (1 - shoulder)),
        (cx - width * 0.16, top + height * 0.06),
        (cx, top),
        (cx + width * 0.16, top + height * 0.06),
        (cx + half, top + height * (1 - shoulder)),
        (cx + half, base_y),
    ]


def eight_point_star(cx: float, cy: float, outer: float, inner: float):
    return star_points(cx, cy, outer, inner, points=8, rotation=-math.pi / 2)


def lerp_points(a: Sequence[tuple[float, float]], b: Sequence[tuple[float, float]], t: float):
    return [(ax + (bx - ax) * t, ay + (by - ay) * t) for (ax, ay), (bx, by) in zip(a, b)]


def tile_band(w: int, h: int, y0: float, y1: float, colour, gap: float = 0.02, count: int = 12) -> Image.Image:
    """A row of little diamonds: the tile band that makes a wall read as Persian rather than generic."""
    m = mask(w, h)
    d = ImageDraw.Draw(m)
    step = 1.0 / count
    for i in range(count):
        cx = step * (i + 0.5)
        cy = (y0 + y1) / 2
        ry = (y1 - y0) / 2
        points = [(cx, cy - ry), (cx + step * 0.42, cy), (cx, cy + ry), (cx - step * 0.42, cy)]
        d.polygon(scale(points, w, h), fill=255)
    out = fill_masked(w, h, colour, m)
    del gap
    return out
