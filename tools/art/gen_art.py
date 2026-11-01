#!/usr/bin/env python3
"""Draw the game's artwork, deterministically, from code.

Why code rather than files: this project may not ship AI-generated imagery (art/manifest.json, rule
`no_ai`) and has no commissioned art yet. What it can have today — reviewable, diffable, free of
licence questions, reproducible byte for byte — is a vector set drawn by our own tool, in the palette
and the Persian-royal direction the design already fixed.

This is a deliberately strong flat-vector set, not a commissioned art pass: `docs/art.md` says so in
plain words and lists what a human artist should replace first. Every sprite is composed from shapes
and gradients, so an artist can replace one PNG and delete nothing.

Output goes where Unity loads it — client/Assets/Game/Resources/art/<id>.png — at exactly the size
art/manifest.json asks for. `python3 tools/art/art.py --check --strict` validates the result.

Usage:
    python3 tools/art/gen_art.py                  # draw everything
    python3 tools/art/gen_art.py --only piece_aqiq icon_coin
    python3 tools/art/gen_art.py --sheet          # + art/preview/contact-sheet.png
    python3 tools/art/gen_art.py --check          # redraw to temp and compare with the repo
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import draw as _draw  # noqa: E402  (SS is patched per asset below)
from draw import (  # noqa: E402
    GOLD_DARK, GOLD_LIGHT, GOLD_MID, INK, INK_SOFT, IVORY, NIGHT_DEEP, PALETTE, SS, add, arch_points,
    blur, drop_points, eight_point_star, ellipse_mask, fill_masked, finish, gradient_masked, grow, layering,
    linear_band, mask, new, outline, polygon_mask, radial, regular_polygon, rgba, ring, rim_light, rounded_mask,
    scale, shade, soft_shadow, star_points, tile_band, with_alpha,
)

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "art" / "manifest.json"
OUT = ROOT / "client" / "Assets" / "Game" / "Resources" / "art"
PREVIEW = ROOT / "art" / "preview"
TOKENS = ROOT / "replica" / "design" / "tokens.json"

# Material colours the design tokens do not name, because they are materials and not roles.
WOOD = rgba("#8A5A2B")
WOOD_DARK = rgba("#5E3B1B")
TERRACOTTA = rgba("#B4643C")
WATER = rgba("#2A7E9E")
GLASS = rgba("#BFE8E4")
STONE = rgba("#8FA3B8")
STONE_DARK = rgba("#5C6F84")
SILVER = rgba("#CBD6E3")


# ------------------------------------------------------------------------------------------------
# helpers shared by several assets


def clip(m: Image.Image, container: Image.Image) -> Image.Image:
    """Mask a mask."""
    return ImageChops.multiply(m, container)


def masked(img: Image.Image, m: Image.Image) -> Image.Image:
    """Mask a painted layer (gradient, glow) with a shape."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), m)
    return out


def glow(w, h, shape, colour, softness=6, alpha=190) -> Image.Image:
    soft = blur(shape, softness).point(lambda v: int(v * alpha / 255))
    return fill_masked(w, h, with_alpha(colour, 255), soft)


def starfield(w, h, count, seed, min_y=0.0, max_y=1.0, max_x=1.0, alpha=210) -> Image.Image:
    layer = mask(w, h)
    d = ImageDraw.Draw(layer)
    rng = random.Random(seed)
    for _ in range(count):
        x = rng.random() * max_x
        y = min_y + rng.random() * (max_y - min_y)
        r = rng.choice([0.6, 0.8, 1.0, 1.3]) * (w / 512)
        a = int(alpha * (0.40 + rng.random() * 0.60))
        d.ellipse(((x * w - r) * SS, (y * h - r) * SS, (x * w + r) * SS, (y * h + r) * SS),
                  fill=a)
    return fill_masked(w, h, IVORY, layer)


def crescent(w, h, cx, cy, r) -> Image.Image:
    full = ellipse_mask(w, h, (cx - r, cy - r * (w / h), cx + r, cy + r * (w / h)))
    bite = ellipse_mask(w, h, (cx - r + r * 0.5, cy - r * (w / h) - r * 0.3,
                               cx + r + r * 0.5, cy + r * (w / h) - r * 0.3))
    return ImageChops.subtract(full, bite)


def brick(w, h, container, row=0.030, col=0.055, weight=1) -> Image.Image:
    m = mask(w, h)
    d = ImageDraw.Draw(m)
    y, i = 0.0, 0
    while y <= 1.0:
        d.line([(0, y * h * SS), (w * SS, y * h * SS)], fill=255, width=weight * 2)
        x = (col / 2 if i % 2 else 0.0)
        while x <= 1.0:
            d.line([(x * w * SS, y * h * SS), (x * w * SS, min(1.0, y + row) * h * SS)], fill=255, width=weight)
            x += col
        y += row
        i += 1
    return clip(m, container)


def column(w, h, cx, top, bottom, width, colour, base=True, capital=True) -> Image.Image:
    body = polygon_mask(w, h, [(cx - width / 2, top), (cx + width / 2, top),
                               (cx + width / 2, bottom), (cx - width / 2, bottom)])
    layers = [gradient_masked(w, h, shade(colour, 0.20), shade(colour, -0.30), body)]
    if capital:
        cap = polygon_mask(w, h, [(cx - width * 0.78, top), (cx + width * 0.78, top),
                                  (cx + width * 0.78, top + 0.016), (cx - width * 0.78, top + 0.016)])
        layers.append(fill_masked(w, h, shade(colour, 0.06), cap))
    if base:
        foot = polygon_mask(w, h, [(cx - width * 0.78, bottom - 0.018), (cx + width * 0.78, bottom - 0.018),
                                   (cx + width * 0.78, bottom), (cx - width * 0.78, bottom)])
        layers.append(fill_masked(w, h, shade(colour, -0.12), foot))
    return layering(*layers)


def oval(cx, cy, rx, ry, angle=0.0, n=24):
    """A rotatable ellipse expressed as polygon points (fractions of the canvas)."""
    ca, sa = math.cos(angle), math.sin(angle)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    return pts


def parapet(w, h, x0, x1, y_top, y_bottom, count, merlon=0.010) -> Image.Image:
    """A crenellated parapet as ONE polygon: a solid band with merlons rising out of it.

    Drawn as a path rather than as a mask to be clipped, so it can never leak past the wall it
    belongs to — which is exactly what a clipped mask did at 4× supersampling.
    """
    pitch = (x1 - x0) / count
    band_top = y_bottom - (y_bottom - y_top) * 0.30
    points = [(x0, y_bottom), (x0, band_top)]
    for i in range(count):
        a = x0 + i * pitch + pitch * 0.18
        b = a + pitch * 0.64
        points += [(a, band_top), (a, y_top), (b, y_top), (b, band_top)]
    points += [(x1, band_top), (x1, y_bottom)]
    return polygon_mask(w, h, points)


def oval(cx, cy, rx, ry, angle=0.0, n=24):
    """A rotatable ellipse expressed as polygon points (fractions of the canvas)."""
    ca, sa = math.cos(angle), math.sin(angle)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    return pts


def merlons(w, h, top, bottom, count) -> Image.Image:
    """The crenellations along a wall top, as a mask."""
    m = mask(w, h)
    d = ImageDraw.Draw(m)
    for i in range(count):
        cx = (i + 0.5) / count
        d.rectangle((cx * w * SS - 0.010 * w * SS, top * h * SS,
                     cx * w * SS + 0.010 * w * SS, bottom * h * SS), fill=255)
    return m


# ------------------------------------------------------------------------------------------------
# pieces: five stones, one bezel language, silhouettes that survive 48 px and greyscale


def scalloped(cx, cy, r, lobes=16, depth=0.055):
    """A fluted cabochon outline: a circle whose edge undulates, so it differs from the pearl."""
    pts = []
    for i in range(lobes * 2):
        angle = 2 * math.pi * i / (lobes * 2)
        radius = r * (1.0 if i % 2 == 0 else 1.0 - depth)
        pts.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return pts


PIECE_SHAPE = {
    # manifest: firouzeh = ridged cabochon, lajvard = hexagon, aqiq = teardrop,
    #           zomorrod = octagon, morvarid = circle
    "piece_firouzeh": lambda: scalloped(0.5, 0.5, 0.450, 8, 0.175),
    "piece_lajvard": lambda: regular_polygon(0.5, 0.5, 0.435, 0.435, 6, math.pi / 2),
    "piece_aqiq": lambda: drop_points(0.5, 0.53, 0.72, 0.86),
    "piece_zomorrod": lambda: regular_polygon(0.5, 0.5, 0.415, 0.415, 8, math.pi / 8),
    "piece_morvarid": lambda: regular_polygon(0.5, 0.5, 0.415, 0.415, 48),
}

PIECE_COLOUR = {
    "piece_firouzeh": PALETTE["piece-firouzeh"],
    "piece_lajvard": PALETTE["piece-lajvard"],
    "piece_aqiq": PALETTE["piece-aqiq"],
    "piece_zomorrod": PALETTE["piece-zomorrod"],
    "piece_morvarid": PALETTE["piece-morvarid"],
}

PIECE_EMBLEM = {
    "piece_firouzeh": "ring",
    "piece_lajvard": "diamond",
    "piece_aqiq": "chevron",
    "piece_zomorrod": "square",
    "piece_morvarid": None,
}


def emblem(w, h, kind, size=0.30) -> Image.Image:
    if kind == "ring":
        return ring(ellipse_mask(w, h, (0.5 - size / 2, 0.5 - size / 2, 0.5 + size / 2, 0.5 + size / 2)),
                    ellipse_mask(w, h, (0.5 - size / 3.2, 0.5 - size / 3.2,
                                        0.5 + size / 3.2, 0.5 + size / 3.2)))
    if kind == "diamond":
        return polygon_mask(w, h, [(0.5, 0.5 - size * 0.62), (0.5 + size * 0.52, 0.5),
                                   (0.5, 0.5 + size * 0.62), (0.5 - size * 0.52, 0.5)])
    if kind == "chevron":
        m = mask(w, h)
        ImageDraw.Draw(m).line([(0.38 * w * SS, 0.60 * h * SS), (0.5 * w * SS, 0.42 * h * SS),
                                (0.62 * w * SS, 0.60 * h * SS)],
                               fill=255, width=int(0.048 * w * SS), joint="curve")
        return m
    if kind == "square":
        return polygon_mask(w, h, [(0.5 - 0.13, 0.5 - 0.13), (0.5 + 0.13, 0.5 - 0.13),
                                   (0.5 + 0.13, 0.5 + 0.13), (0.5 - 0.13, 0.5 + 0.13)])
    return polygon_mask(w, h, drop_points(0.5, 0.5, 0.20, 0.28))


def piece(w, h, asset_id):
    """A stone in a gold bezel.

    The order is fixed and never grows: silhouette, bezel, stone gradient, one soft light, one
    table stroke, one facet set, one rim. Anything else reads as clip art at 128 px.
    """
    shape = PIECE_SHAPE[asset_id]()
    base = rgba(PIECE_COLOUR[asset_id])
    pearl = asset_id == "piece_morvarid"
    body = polygon_mask(w, h, shape)
    bezel = grow(body, 8.0)
    bezel_light, bezel_dark = (
        (rgba("#FFFDF6"), rgba("#D6C6A2")) if pearl
        else (rgba("#FFF3CC"), rgba("#C08A2A")))

    table = [(0.5 + (x - 0.5) * 0.58 - 0.020, 0.5 + (y - 0.5) * 0.58 - 0.035) for x, y in shape]
    table_stroke = outline(w, h, polygon_mask(w, h, table), with_alpha(IVORY, 52), 1.0)

    facets = mask(w, h)
    fd = ImageDraw.Draw(facets)
    for angle in (140, 200):
        rad = math.radians(angle)
        fd.line([((0.48 + 0.31 * math.cos(rad)) * w * SS, (0.465 + 0.31 * math.sin(rad)) * h * SS),
                 ((0.5 + 0.47 * math.cos(rad)) * w * SS, (0.5 + 0.47 * math.sin(rad)) * h * SS)],
                fill=255, width=max(1, int(0.006 * w * SS)))
    facets = clip(facets, body)

    # a crisp top-edge highlight, not a blurred blob: blurred white over a saturated stone greys it out
    top_light = clip(ring(grow(body, -2.0), grow(body, -7.0)),
                     polygon_mask(w, h, [(0, 0), (1, 0), (1, 0.34), (0, 0.34)]))
    sparkle = ellipse_mask(w, h, (0.320, 0.235, 0.368, 0.283))

    top, bottom = (shade(base, 0.42), shade(base, -0.12)) if pearl else (shade(base, 0.30), shade(base, -0.24))

    layers = [
        soft_shadow(w, h, bezel, (0, 5), 5, 130),
        gradient_masked(w, h, bezel_light, bezel_dark, bezel),
        fill_masked(w, h, with_alpha((255, 255, 255, 255), 120),
                    clip(ring(bezel, grow(body, 5.0)),
                         polygon_mask(w, h, [(0, 0), (0.64, 0), (0.34, 0.44), (0, 0.66)]))),
        fill_masked(w, h, with_alpha(shade(bezel_dark, -0.25), 140), ring(bezel, grow(body, 1.0))),
        gradient_masked(w, h, top, bottom, body),
        fill_masked(w, h, with_alpha(shade(bottom, -0.35), 70), ring(body, grow(body, -4.0))),
        fill_masked(w, h, with_alpha((255, 255, 255, 255), 65), top_light),
        fill_masked(w, h, with_alpha(INK, 30), facets),
        table_stroke,
        fill_masked(w, h, with_alpha((255, 255, 255, 255), 210), sparkle),
        rim_light(w, h, body, with_alpha((255, 255, 255, 255), 60), 1.6),
    ]

    if asset_id == "piece_firouzeh":
        ridges = mask(w, h)
        rd = ImageDraw.Draw(ridges)
        for i in range(16):
            angle = 2 * math.pi * i / 16
            rd.line([((0.5 + 0.26 * math.cos(angle)) * w * SS, (0.5 + 0.26 * math.sin(angle)) * h * SS),
                     ((0.5 + 0.45 * math.cos(angle)) * w * SS, (0.5 + 0.45 * math.sin(angle)) * h * SS)],
                    fill=255, width=max(1, int(0.007 * w * SS)))
        layers.append(fill_masked(w, h, with_alpha((255, 255, 255, 255), 30), clip(ridges, body)))

    if asset_id == "piece_aqiq":
        bands = mask(w, h)
        bd = ImageDraw.Draw(bands)
        for t, off in ((0.33, 0.025), (0.50, 0.035), (0.67, 0.025)):
            bd.line([(0.14 * w * SS, t * h * SS), (0.86 * w * SS, (t + off) * h * SS)],
                    fill=255, width=max(1, int(0.012 * w * SS)))
        layers.append(fill_masked(w, h, with_alpha(IVORY, 40), clip(bands, body)))

    if asset_id == "piece_lajvard":
        layers.append(fill_masked(w, h, with_alpha(IVORY, 45), clip(ring(grow(body, -3.0), grow(body, -5.0)), body)))

    if asset_id == "piece_zomorrod":
        centre = polygon_mask(w, h, eight_point_star(0.5, 0.5, 0.20, 0.10))
        layers.append(fill_masked(w, h, with_alpha((255, 255, 255, 255), 45), clip(centre, body)))
        layers.append(fill_masked(w, h, with_alpha(INK, 40),
                                  clip(ring(polygon_mask(w, h, eight_point_star(0.5, 0.5, 0.22, 0.11)), centre), body)))

    layers.append(outline(w, h, bezel, with_alpha(INK, 200), 1.2))
    return finish(layering(*layers), w, h)


# ------------------------------------------------------------------------------------------------
# power-ups: read as an object sitting on top of a stone, in any colour


def powerup(w, h, asset_id):
    """A small object that must read on top of any of the five stones."""
    if asset_id == "powerup_dynamite":
        body = mask(w, h)
        bd = ImageDraw.Draw(body)
        bd.rounded_rectangle((0.30 * w * SS, 0.32 * h * SS, 0.70 * w * SS, 0.82 * h * SS),
                             radius=0.05 * w * SS, fill=255)
        bands = mask(w, h)
        dd = ImageDraw.Draw(bands)
        for top in (0.44, 0.66):
            dd.rectangle((0.30 * w * SS, top * h * SS, 0.70 * w * SS, (top + 0.055) * h * SS), fill=255)
        fuse = mask(w, h)
        ImageDraw.Draw(fuse).line(
            [(0.50 * w * SS, 0.33 * h * SS), (0.60 * w * SS, 0.24 * h * SS),
             (0.56 * w * SS, 0.17 * h * SS), (0.62 * w * SS, 0.12 * h * SS)],
            fill=255, width=int(0.026 * w * SS), joint="curve")
        spark = polygon_mask(w, h, star_points(0.63, 0.10, 0.075, 0.030, points=4))
        return finish(layering(
            soft_shadow(w, h, body, (0, 5), 4, 125),
            gradient_masked(w, h, shade(rgba(PALETTE["danger"]), 0.22),
                            shade(rgba(PALETTE["danger"]), -0.48), body),
            fill_masked(w, h, with_alpha(GOLD_MID, 255), clip(bands, body)),
            fill_masked(w, h, with_alpha(shade(GOLD_MID, 0.35), 255),
                        clip(polygon_mask(w, h, [(0.32, 0.34), (0.40, 0.34), (0.36, 0.80), (0.30, 0.80)]), body)),
            fill_masked(w, h, with_alpha(INK, 210),
                        clip(polygon_mask(w, h, [(0.30, 0.32), (0.70, 0.32), (0.70, 0.375), (0.30, 0.375)]), body)),
            fill_masked(w, h, WOOD_DARK, fuse),
            glow(w, h, spark, GOLD_LIGHT, 5, 235),
            fill_masked(w, h, GOLD_LIGHT, spark),
            fill_masked(w, h, IVORY, ellipse_mask(w, h, (0.605, 0.082, 0.645, 0.120))),
            rim_light(w, h, body, with_alpha((255, 255, 255, 255), 70), 1.8),
            outline(w, h, body, with_alpha(INK, 205), 1.5)), w, h)

    if asset_id == "powerup_spinner":
        # two arcs with an arrowhead on each end: instantly "rotate", and symmetric enough to spin
        def arc_mask(start_deg, end_deg):
            m = mask(w, h)
            ImageDraw.Draw(m).arc((0.14 * w * SS, 0.14 * h * SS, 0.86 * w * SS, 0.86 * h * SS),
                                  start_deg, end_deg, fill=255, width=int(0.095 * w * SS))
            return m

        arcs = add(arc_mask(208, 330), arc_mask(28, 150))
        heads = mask(w, h)
        hd = ImageDraw.Draw(heads)
        for angle_deg in (150, 330):
            a = math.radians(angle_deg)
            cx, cy = 0.5 + 0.36 * math.cos(a), 0.5 + 0.36 * math.sin(a)
            tangent = a + math.pi / 2
            tip = (cx + 0.10 * math.cos(tangent), cy + 0.10 * math.sin(tangent))
            left = (cx + 0.085 * math.cos(tangent - 2.1), cy + 0.085 * math.sin(tangent - 2.1))
            right = (cx + 0.085 * math.cos(tangent + 2.1), cy + 0.085 * math.sin(tangent + 2.1))
            hd.polygon(scale([tip, left, right], w, h), fill=255)
        whole = add(arcs, heads)
        return finish(layering(
            soft_shadow(w, h, whole, (0, 4), 4, 110),
            gradient_masked(w, h, GOLD_LIGHT, GOLD_DARK, whole),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 90),
                        clip(whole, polygon_mask(w, h, [(0, 0), (1, 0), (1, 0.45), (0, 0.55)]))),
            outline(w, h, whole, with_alpha(INK, 205), 1.4)), w, h)

    if asset_id == "powerup_electro":
        bolt = polygon_mask(w, h, [(0.58, 0.06), (0.26, 0.56), (0.45, 0.56),
                                   (0.38, 0.94), (0.74, 0.40), (0.52, 0.40)])
        core = polygon_mask(w, h, [(0.545, 0.16), (0.36, 0.50), (0.46, 0.50), (0.42, 0.76)])
        return finish(layering(
            glow(w, h, bolt, GOLD_LIGHT, 8, 220),
            gradient_masked(w, h, (255, 252, 226, 255), GOLD_MID, bolt),
            fill_masked(w, h, with_alpha(IVORY, 210), clip(core, bolt)),
            outline(w, h, bolt, with_alpha(INK, 130), 1.2)), w, h)

    if asset_id in ("powerup_rocket_row", "powerup_rocket_col"):
        horizontal = asset_id == "powerup_rocket_row"

        def turn(x, y):
            return (x, y) if horizontal else (y, 1 - x)

        shell = polygon_mask(w, h, [turn(*p) for p in
                                    [(0.14, 0.40), (0.62, 0.40), (0.92, 0.50), (0.62, 0.60), (0.14, 0.60)]])
        fin_top = polygon_mask(w, h, [turn(*p) for p in [(0.26, 0.40), (0.12, 0.22), (0.36, 0.40)]])
        fin_bottom = polygon_mask(w, h, [turn(*p) for p in [(0.26, 0.60), (0.12, 0.78), (0.36, 0.60)]])
        window = ellipse_mask(w, h, (0.44, 0.44, 0.58, 0.58)) if horizontal else \
            ellipse_mask(w, h, (0.42, 0.42, 0.56, 0.56))
        exhaust = polygon_mask(w, h, [turn(*p) for p in
                                      [(0.15, 0.44), (0.02, 0.50), (0.15, 0.56)]])
        return finish(layering(
            soft_shadow(w, h, shell, (0, 5), 4, 125),
            glow(w, h, exhaust, GOLD_LIGHT, 4, 200),
            fill_masked(w, h, with_alpha(shade(GOLD_MID, -0.50), 255), fin_top),
            fill_masked(w, h, with_alpha(shade(GOLD_MID, -0.50), 255), fin_bottom),
            gradient_masked(w, h, GOLD_LIGHT, GOLD_DARK, shell),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 110),
                        clip(polygon_mask(w, h, [turn(*p) for p in
                                                 [(0.18, 0.42), (0.60, 0.42), (0.60, 0.46), (0.18, 0.46)]]), shell)),
            fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 255), window),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 120),
                        clip(ellipse_mask(w, h, (0.47, 0.455, 0.51, 0.49)) if horizontal
                             else ellipse_mask(w, h, (0.455, 0.455, 0.49, 0.48)), window)),
            outline(w, h, shell, with_alpha(INK, 205), 1.5)), w, h)

    raise SystemExit(f"gen_art: unknown power-up {asset_id}")


# ------------------------------------------------------------------------------------------------
# obstacles: overlays, so they stay thin and never hide the piece colour


def obstacle(w, h, asset_id):
    if asset_id == "obstacle_crate":
        body = rounded_mask(w, h, 0.055, 0.05)
        planks = mask(w, h)
        pd = ImageDraw.Draw(planks)
        for t in (0.34, 0.50, 0.66):
            pd.line([(0.06 * w * SS, t * h * SS), (0.94 * w * SS, t * h * SS)],
                    fill=255, width=max(1, int(0.014 * w * SS)))
        pd.line([(0.10 * w * SS, 0.10 * h * SS), (0.90 * w * SS, 0.90 * h * SS)],
                fill=255, width=max(1, int(0.022 * w * SS)))
        pd.line([(0.90 * w * SS, 0.10 * h * SS), (0.10 * w * SS, 0.90 * h * SS)],
                fill=255, width=max(1, int(0.022 * w * SS)))
        return finish(layering(
            soft_shadow(w, h, body, (0, 5), 5, 120),
            gradient_masked(w, h, shade(WOOD, 0.20), shade(WOOD_DARK, -0.15), body),
            fill_masked(w, h, with_alpha(shade(WOOD_DARK, -0.35), 255), clip(planks, body)),
            fill_masked(w, h, with_alpha(shade(WOOD, 0.45), 60),
                        clip(polygon_mask(w, h, [(0.06, 0.06), (0.94, 0.06), (0.94, 0.10), (0.06, 0.10)]), body)),
            rim_light(w, h, body, with_alpha((255, 255, 255, 255), 55), 2),
            outline(w, h, body, with_alpha(INK, 200), 1.6)), w, h)

    if asset_id == "obstacle_frost":
        # a translucent film plus crystals: semi-transparent, the piece underneath stays readable
        film = rounded_mask(w, h, 0.03, 0.14)
        layer = layering(
            fill_masked(w, h, with_alpha(rgba("#DCEEFF"), 46), film),
            outline(w, h, film, with_alpha(rgba("#EAF6FF"), 90), 1.0))
        for cx, cy, r in [(0.30, 0.30, 0.20), (0.64, 0.50, 0.24), (0.36, 0.74, 0.16)]:
            flake = polygon_mask(w, h, star_points(cx, cy, r, r * 0.40, points=6, rotation=0.4))
            core = polygon_mask(w, h, star_points(cx, cy, r * 0.45, r * 0.18, points=6, rotation=0.4))
            layer = layering(layer,
                             fill_masked(w, h, with_alpha(rgba("#D6EDFF"), 130), flake),
                             fill_masked(w, h, with_alpha(IVORY, 210), core),
                             outline(w, h, flake, with_alpha(IVORY, 150), 1.0))
        return finish(layer, w, h)

    if asset_id == "obstacle_ivy":
        # thin vines with leaves, no cast shadow: it must never hide the piece colour
        stems = mask(w, h)
        sd = ImageDraw.Draw(stems)
        paths = [
            [(0.12, 0.06), (0.30, 0.26), (0.26, 0.48), (0.40, 0.68), (0.32, 0.94)],
            [(0.88, 0.10), (0.72, 0.30), (0.78, 0.52), (0.66, 0.72), (0.72, 0.94)],
        ]
        for path in paths:
            sd.line([(x * w * SS, y * h * SS) for x, y in path], fill=255,
                    width=int(0.022 * w * SS), joint="curve")

        leaves = mask(w, h)
        ld = ImageDraw.Draw(leaves)
        leaf_spots = [
            (0.22, 0.16, -40), (0.36, 0.30, 25), (0.24, 0.42, -20), (0.42, 0.56, 35),
            (0.30, 0.72, -30), (0.38, 0.86, 20),
            (0.78, 0.20, 40), (0.68, 0.36, -25), (0.80, 0.50, 30), (0.64, 0.64, -35),
            (0.76, 0.82, 25), (0.66, 0.92, -20),
        ]
        for cx, cy, deg in leaf_spots:
            ld.polygon(scale(oval(cx, cy, 0.062, 0.030, math.radians(deg)), w, h), fill=255)

        leaf_colour = rgba(PALETTE["success"])
        return finish(layering(
            fill_masked(w, h, with_alpha(shade(leaf_colour, -0.70), 255), grow(leaves, 1.0)),
            fill_masked(w, h, with_alpha(shade(leaf_colour, -0.10), 255), leaves),
            fill_masked(w, h, with_alpha(shade(leaf_colour, 0.35), 130),
                        clip(leaves, polygon_mask(w, h, [(0, 0), (1, 0), (1, 0.45), (0, 0.55)]))),
            fill_masked(w, h, with_alpha(shade(leaf_colour, -0.55), 255), stems)), w, h)

    if asset_id == "obstacle_vial":
        glass = polygon_mask(w, h, [(0.41, 0.20), (0.59, 0.20), (0.59, 0.32), (0.69, 0.44),
                                    (0.69, 0.84), (0.31, 0.84), (0.31, 0.44), (0.41, 0.32)])
        liquid = polygon_mask(w, h, [(0.34, 0.52), (0.66, 0.52), (0.66, 0.82), (0.34, 0.82)])
        return finish(layering(
            soft_shadow(w, h, glass, (0, 5), 5, 115),
            fill_masked(w, h, with_alpha(GLASS, 175), glass),
            fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 235), clip(liquid, glass)),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 110),
                        clip(polygon_mask(w, h, [(0.38, 0.40), (0.42, 0.40), (0.42, 0.80), (0.38, 0.80)]), glass)),
            fill_masked(w, h, WOOD_DARK, polygon_mask(w, h, [(0.39, 0.13), (0.61, 0.13), (0.61, 0.21), (0.39, 0.21)])),
            rim_light(w, h, glass, with_alpha((255, 255, 255, 255), 120), 1.8),
            outline(w, h, glass, with_alpha(INK, 190), 1.4)), w, h)

    if asset_id == "obstacle_samovar":
        # silhouette first: wide body, dome lid, spout, tap — it must read at 48 px
        body = polygon_mask(w, h, [(0.32, 0.34), (0.68, 0.34), (0.72, 0.46), (0.72, 0.72),
                                   (0.64, 0.82), (0.36, 0.82), (0.28, 0.72), (0.28, 0.46)])
        lid = mask(w, h)
        ImageDraw.Draw(lid).pieslice((0.30 * w * SS, 0.20 * h * SS, 0.70 * w * SS, 0.48 * h * SS),
                                     180, 360, fill=255)
        lid = clip(lid, polygon_mask(w, h, [(0.28, 0.20), (0.72, 0.20), (0.72, 0.36), (0.28, 0.36)]))
        knob = ellipse_mask(w, h, (0.455, 0.135, 0.545, 0.215))
        spout = mask(w, h)
        ImageDraw.Draw(spout).line([(0.30 * w * SS, 0.44 * h * SS), (0.17 * w * SS, 0.31 * h * SS)],
                                   fill=255, width=int(0.040 * w * SS))
        handles = mask(w, h)
        hd2 = ImageDraw.Draw(handles)
        for side in (-1, 1):
            cx = 0.5 + side * 0.20
            hd2.arc(((cx - 0.06) * w * SS, 0.42 * h * SS, (cx + 0.06) * w * SS, 0.66 * h * SS),
                    90 if side > 0 else 270, -90 if side > 0 else 90,
                    fill=255, width=int(0.022 * w * SS))
        tap = mask(w, h)
        td = ImageDraw.Draw(tap)
        td.line([(0.50 * w * SS, 0.64 * h * SS), (0.50 * w * SS, 0.74 * h * SS)],
                fill=255, width=int(0.030 * w * SS))
        td.ellipse((0.455 * w * SS, 0.735 * h * SS, 0.545 * w * SS, 0.775 * h * SS), fill=255)
        foot = polygon_mask(w, h, [(0.34, 0.82), (0.66, 0.82), (0.62, 0.88), (0.38, 0.88)])
        return finish(layering(
            soft_shadow(w, h, body, (0, 5), 5, 130),
            fill_masked(w, h, with_alpha(shade(GOLD_MID, -0.45), 255), handles),
            fill_masked(w, h, with_alpha(shade(GOLD_MID, -0.30), 255), spout),
            gradient_masked(w, h, GOLD_LIGHT, GOLD_DARK, body),
            gradient_masked(w, h, shade(GOLD_MID, 0.28), shade(GOLD_MID, -0.22), lid),
            fill_masked(w, h, GOLD_LIGHT, knob),
            fill_masked(w, h, with_alpha(rgba(PALETTE["accent-strong"]), 245),
                        clip(polygon_mask(w, h, [(0.29, 0.55), (0.71, 0.55),
                                                 (0.71, 0.60), (0.29, 0.60)]), body)),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 95),
                        clip(polygon_mask(w, h, [(0.34, 0.36), (0.39, 0.36), (0.36, 0.80), (0.31, 0.78)]), body)),
            fill_masked(w, h, GOLD_MID, tap),
            fill_masked(w, h, shade(GOLD_DARK, -0.10), foot),
            outline(w, h, body, with_alpha(INK, 205), 1.4),
            outline(w, h, lid, with_alpha(INK, 190), 1.2)), w, h)

    if asset_id == "obstacle_flowerpot":
        pot = polygon_mask(w, h, [(0.31, 0.52), (0.69, 0.52), (0.61, 0.86), (0.39, 0.86)])
        rim = polygon_mask(w, h, [(0.28, 0.45), (0.72, 0.45), (0.72, 0.54), (0.28, 0.54)])
        plant = mask(w, h)
        pd = ImageDraw.Draw(plant)
        for cx, cy, rx, ry in [(0.50, 0.30, 0.11, 0.09), (0.38, 0.38, 0.07, 0.055), (0.62, 0.38, 0.07, 0.055)]:
            pd.ellipse(((cx - rx) * w * SS, (cy - ry) * h * SS, (cx + rx) * w * SS, (cy + ry) * h * SS), fill=255)
        return finish(layering(
            soft_shadow(w, h, pot, (0, 5), 5, 115),
            fill_masked(w, h, with_alpha(rgba(PALETTE["success"]), 255), plant),
            fill_masked(w, h, with_alpha(shade(rgba(PALETTE["success"]), -0.35), 255),
                        clip(plant, polygon_mask(w, h, [(0.5, 0), (1, 0), (1, 1), (0.5, 1)]))),
            gradient_masked(w, h, shade(TERRACOTTA, 0.22), shade(TERRACOTTA, -0.32), pot),
            fill_masked(w, h, shade(TERRACOTTA, 0.06), rim),
            outline(w, h, pot, with_alpha(INK, 190), 1.4)), w, h)

    if asset_id == "obstacle_chain":
        # three links across the piece, each lapping the next: draw the links, not a bar
        links = [(0.25, 0.50, 0.155, 0.105), (0.50, 0.50, 0.115, 0.145), (0.75, 0.50, 0.155, 0.105)]
        metal = mask(w, h)
        md = ImageDraw.Draw(metal)
        for cx, cy, rx, ry in links:
            md.ellipse(((cx - rx) * w * SS, (cy - ry) * h * SS,
                        (cx + rx) * w * SS, (cy + ry) * h * SS),
                       outline=255, width=int(0.052 * w * SS))
        holes = mask(w, h)
        hd = ImageDraw.Draw(holes)
        for cx, cy, rx, ry in links:
            hd.ellipse(((cx - rx * 0.66) * w * SS, (cy - ry * 0.66) * h * SS,
                        (cx + rx * 0.66) * w * SS, (cy + ry * 0.66) * h * SS), fill=255)
        chain = ImageChops.subtract(metal, holes)
        return finish(layering(
            soft_shadow(w, h, chain, (0, 4), 4, 110),
            fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.55), 255), grow(chain, 1.0)),
            gradient_masked(w, h, shade(STONE, 0.42), shade(STONE_DARK, -0.35), chain),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 120),
                        clip(chain, polygon_mask(w, h, [(0, 0), (1, 0), (0.35, 0.50), (0, 1)]))),
        ), w, h)

    # obstacle_seal: the royal lock, the one obstacle allowed to look expensive
    seal = ellipse_mask(w, h, (0.17, 0.17, 0.83, 0.83))
    return finish(layering(
        soft_shadow(w, h, seal, (0, 5), 5, 125),
        fill_masked(w, h, with_alpha(rgba("#B33A24"), 255), seal),
        fill_masked(w, h, with_alpha(shade(rgba("#B33A24"), 0.22), 255),
                    clip(ellipse_mask(w, h, (0.20, 0.19, 0.62, 0.55)), seal)),
        fill_masked(w, h, with_alpha(GOLD_MID, 255),
                    ring(ellipse_mask(w, h, (0.23, 0.23, 0.77, 0.77)),
                         ellipse_mask(w, h, (0.28, 0.28, 0.72, 0.72)))),
        fill_masked(w, h, with_alpha(GOLD_LIGHT, 255), emblem(w, h, "diamond", 0.34)),
        fill_masked(w, h, with_alpha(INK, 90), emblem(w, h, "ring", 0.56)),
        outline(w, h, seal, with_alpha(INK, 190), 1.6)), w, h)


# ------------------------------------------------------------------------------------------------
# HUD icons: drawn for a dark pill, one colour each


def hud_icon(w, h, asset_id):
    if asset_id == "icon_coin":
        disc = ellipse_mask(w, h, (0.06, 0.06, 0.94, 0.94))
        return finish(layering(
            fill_masked(w, h, with_alpha(GOLD_MID, 255), disc),
            fill_masked(w, h, with_alpha(shade(GOLD_MID, -0.22), 255),
                        ring(ellipse_mask(w, h, (0.16, 0.16, 0.84, 0.84)),
                             ellipse_mask(w, h, (0.26, 0.26, 0.74, 0.74)))),
            fill_masked(w, h, with_alpha(shade(GOLD_MID, 0.30), 255),
                        clip(polygon_mask(w, h, eight_point_star(0.5, 0.5, 0.26, 0.11)),
                             ellipse_mask(w, h, (0.2, 0.2, 0.8, 0.8)))),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 60),
                        clip(ellipse_mask(w, h, (0.20, 0.18, 0.44, 0.36)), disc))), w, h)

    if asset_id == "icon_potion":
        bottle = polygon_mask(w, h, [(0.37, 0.10), (0.63, 0.10), (0.63, 0.26), (0.78, 0.40),
                                     (0.78, 0.90), (0.22, 0.90), (0.22, 0.40), (0.37, 0.26)])
        liquid = polygon_mask(w, h, [(0.26, 0.47), (0.74, 0.47), (0.74, 0.87), (0.26, 0.87)])
        return finish(layering(
            fill_masked(w, h, with_alpha(GLASS, 160), bottle),
            fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 245), clip(liquid, bottle)),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 90),
                        clip(ellipse_mask(w, h, (0.35, 0.55, 0.40, 0.66)), bottle)),
            fill_masked(w, h, WOOD_DARK, polygon_mask(w, h, [(0.35, 0.03), (0.65, 0.03), (0.65, 0.13), (0.35, 0.13)])),
            rim_light(w, h, bottle, with_alpha((255, 255, 255, 255), 130), 1.6),
            outline(w, h, bottle, with_alpha(INK, 195), 1.3)), w, h)

    if asset_id == "icon_life":
        heart = mask(w, h)
        d = ImageDraw.Draw(heart)
        d.ellipse((0.11 * w * SS, 0.13 * h * SS, 0.53 * w * SS, 0.55 * h * SS), fill=255)
        d.ellipse((0.47 * w * SS, 0.13 * h * SS, 0.89 * w * SS, 0.55 * h * SS), fill=255)
        d.polygon(scale([(0.09, 0.40), (0.91, 0.40), (0.50, 0.93)], w, h), fill=255)
        return finish(layering(
            soft_shadow(w, h, heart, (0, 3), 3, 105),
            gradient_masked(w, h, shade(rgba(PALETTE["danger"]), 0.18), shade(rgba(PALETTE["danger"]), -0.40), heart),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 105), ellipse_mask(w, h, (0.24, 0.23, 0.39, 0.35))),
            rim_light(w, h, heart, with_alpha((255, 255, 255, 255), 115), 1.8),
            outline(w, h, heart, with_alpha(INK, 195), 1.3)), w, h)

    # icon_star: no baked glow, three sizes come from one sprite
    star = polygon_mask(w, h, star_points(0.5, 0.53, 0.45, 0.19))
    return finish(layering(
        soft_shadow(w, h, star, (0, 3), 3, 100),
        gradient_masked(w, h, GOLD_LIGHT, GOLD_DARK, star),
        fill_masked(w, h, with_alpha((255, 255, 255, 255), 110),
                    clip(polygon_mask(w, h, [(0.5, 0.10), (0.62, 0.42), (0.34, 0.42)]), star)),
        rim_light(w, h, star, with_alpha((255, 255, 255, 255), 115), 1.8),
        outline(w, h, star, with_alpha(INK, 195), 1.3)), w, h)


# ------------------------------------------------------------------------------------------------
# nine-slice frames: the middle is flat so it tiles without a seam


def nine_slice(w, h, asset_id):
    if asset_id == "panel_frame":
        body = rounded_mask(w, h, 0.020, 0.17)
        keyline = ring(body, rounded_mask(w, h, 0.055, 0.13))
        return finish(layering(
            fill_masked(w, h, with_alpha(rgba(PALETTE["surface"]), 245), body),
            fill_masked(w, h, with_alpha(GOLD_MID, 200), keyline),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 26),
                        ring(rounded_mask(w, h, 0.020, 0.17), rounded_mask(w, h, 0.038, 0.155)))), w, h)

    if asset_id == "button_primary":
        # flat firouzeh enamel, one 2 px inner highlight, no gradient banding
        body = rounded_mask(w, h, 0.020, 0.16)
        return finish(layering(
            fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 255), body),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 58),
                        clip(rounded_mask(w, h, 0.020, 0.16),
                             polygon_mask(w, h, [(0.0, 0.0), (1.0, 0.0), (1.0, 0.115), (0.0, 0.115)]))),
            fill_masked(w, h, with_alpha(shade(rgba(PALETTE["accent-strong"]), -0.35), 120),
                        clip(rounded_mask(w, h, 0.020, 0.16),
                             polygon_mask(w, h, [(0.0, 0.88), (1.0, 0.88), (1.0, 1.0), (0.0, 1.0)]))),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 40),
                        ring(body, rounded_mask(w, h, 0.038, 0.145)))), w, h)

    # board_frame: dark lapis, one gold keyline, quiet enough not to compete with the pieces
    body = rounded_mask(w, h, 0.014, 0.055)
    return finish(layering(
        fill_masked(w, h, with_alpha(shade(rgba(PALETTE["bg"]), 0.06), 242), body),
        fill_masked(w, h, with_alpha(rgba(PALETTE["border"]), 90),
                    ring(body, rounded_mask(w, h, 0.040, 0.045))),
        fill_masked(w, h, with_alpha(GOLD_MID, 165),
                    ring(rounded_mask(w, h, 0.026, 0.050), rounded_mask(w, h, 0.034, 0.048))),
        fill_masked(w, h, with_alpha((255, 255, 255, 255), 18),
                    ring(body, rounded_mask(w, h, 0.020, 0.053)))), w, h)


# ------------------------------------------------------------------------------------------------
# the palace plate and the three district plates: one sky, one light, one camera


def vfade(w, h, y0, y1, colour, a0=0, a1=255) -> Image.Image:
    """A layer whose alpha ramps from a0 at y0 to a1 at y1 (fractions of the height)."""
    height, width = h * SS, w * SS
    y = np.linspace(0.0, 1.0, height, dtype=np.float32)
    t = np.clip((y - y0) / max(1e-6, y1 - y0), 0.0, 1.0)
    alpha = (a0 + (a1 - a0) * t).astype(np.uint8)[:, None]
    a = np.repeat(alpha, width, axis=1)
    rgb = np.zeros((height, width, 3), dtype=np.uint8)
    rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2] = colour[0], colour[1], colour[2]
    return Image.fromarray(np.concatenate([rgb, a[:, :, None]], axis=2), mode="RGBA")


def sky(w, h, horizon=0.66):
    layers = [linear_band(w, h, 0.0, horizon, NIGHT_DEEP, rgba("#26456A"))]
    layers.append(starfield(w, h, 150, seed=3, min_y=0.02, max_y=horizon * 0.80, max_x=0.97, alpha=185))
    moon = crescent(w, h, 0.155, 0.155, 0.040)
    layers.append(glow(w, h, grow(moon, 5), IVORY, 10, 90))
    layers.append(fill_masked(w, h, with_alpha(IVORY, 240), moon))
    return layering(*layers)


def dome_mask(w, h, cx, base, rx, ry):
    """A Persian onion dome: a squashed half-ellipse with an ogee crown above it."""
    lower = mask(w, h)
    ImageDraw.Draw(lower).pieslice(((cx - rx) * w * SS, (base - ry * 0.95) * h * SS,
                                    (cx + rx) * w * SS, (base + ry * 0.35) * h * SS), 180, 360, fill=255)
    crown = polygon_mask(w, h, [(cx - rx, base - ry * 0.46), (cx - rx * 0.52, base - ry * 0.95),
                                (cx, base - ry * 1.28), (cx + rx * 0.52, base - ry * 0.95),
                                (cx + rx, base - ry * 0.46)])
    return add(lower, crown)


def cypress(w, h, tx, base, height, width, colour):
    """The chapter's signature silhouette, used in all scene plates."""
    tree = polygon_mask(w, h, [(tx, base - height), (tx + width * 0.34, base - height * 0.62),
                               (tx + width * 0.24, base - height * 0.20), (tx + width * 0.14, base),
                               (tx - width * 0.14, base), (tx - width * 0.24, base - height * 0.20),
                               (tx - width * 0.34, base - height * 0.62)])
    return layering(
        fill_masked(w, h, with_alpha(shade(colour, -0.86), 255), tree),
        fill_masked(w, h, with_alpha(shade(colour, -0.55), 120),
                    clip(polygon_mask(w, h, [(tx - width * 0.4, 0), (tx, 0), (tx, 1), (tx - width * 0.4, 1)]), tree)))


def home_palace(w, h):
    horizon = 0.640
    layers = [sky(w, h, horizon)]

    # hills behind the wall
    layers.append(fill_masked(w, h, with_alpha(rgba("#12253D"), 255), polygon_mask(w, h, [
        (0.0, 0.64), (0.12, 0.585), (0.26, 0.625), (0.42, 0.575), (0.58, 0.620),
        (0.74, 0.570), (0.88, 0.610), (1.0, 0.575), (1.0, 1.0), (0.0, 1.0)][:-2] + [(1.0, 0.72), (0.0, 0.72)])))

    wall_light, wall_dark = rgba("#2E4E71"), rgba("#152740")
    # the facade: everything sits on this block, so the scene reads as one building
    facade = polygon_mask(w, h, [(0.345, 0.452), (0.985, 0.452), (0.985, 0.672), (0.345, 0.672)])
    layers.append(gradient_masked(w, h, wall_light, wall_dark, facade))
    layers.append(fill_masked(w, h, with_alpha(rgba("#0F2033"), 90),
                              brick(w, h, facade, row=0.028, col=0.046)))
    layers.append(fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 165),
                              polygon_mask(w, h, [(0.345, 0.454), (0.985, 0.454),
                                                  (0.985, 0.466), (0.345, 0.466)])))
    layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 150),
                              polygon_mask(w, h, [(0.345, 0.474), (0.985, 0.474),
                                                  (0.985, 0.478), (0.345, 0.478)])))
    layers.append(fill_masked(w, h, with_alpha(shade(wall_light, -0.08), 255),
                              parapet(w, h, 0.345, 0.985, 0.424, 0.452, 30)))
    layers.append(fill_masked(w, h, with_alpha(shade(wall_light, 0.20), 200),
                              polygon_mask(w, h, [(0.345, 0.450), (0.985, 0.450),
                                                  (0.985, 0.454), (0.345, 0.454)])))

    # the iwan: a framed arch with muqarnas above it and a warm interior
    cx, arch_base, arch_w, arch_h = 0.635, 0.672, 0.150, 0.245
    frame = polygon_mask(w, h, arch_points(cx, 0.672, arch_w * 1.42, arch_h * 1.14, 0.62))
    layers.append(gradient_masked(w, h, shade(wall_light, 0.16), shade(wall_dark, 0.10), frame))
    layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 150), ring(grow(frame, 2.0), frame)))
    # muqarnas: three nested arches stepping up out of the frame — a corbel, not three floating bars
    # muqarnas: three nested arch crowns stepping up out of the frame, widening as they rise
    for i, (half_w, y0, height) in enumerate([(0.060, 0.378, 0.030), (0.082, 0.366, 0.036),
                                              (0.104, 0.354, 0.042)]):
        crown = polygon_mask(w, h, arch_points(cx, y0 + height, half_w * 2, height, 0.72))
        crown = clip(crown, polygon_mask(w, h, [(cx - half_w, 0), (cx + half_w, 0),
                                                 (cx + half_w, y0 + height), (cx - half_w, y0 + height)]))
        layers.append(fill_masked(w, h, with_alpha(shade(GOLD_MID, 0.30 - i * 0.09), 240), crown))
        layers.append(fill_masked(w, h, with_alpha(shade(GOLD_DARK, -0.30), 130),
                                  polygon_mask(w, h, [(cx - half_w, y0 + height - 0.004),
                                                      (cx + half_w, y0 + height - 0.004),
                                                      (cx + half_w, y0 + height),
                                                      (cx - half_w, y0 + height)])))
    opening = polygon_mask(w, h, arch_points(cx, arch_base, arch_w, arch_h, 0.60))
    layers.append(fill_masked(w, h, with_alpha(rgba("#08131F"), 255), opening))
    layers.append(fill_masked(w, h, with_alpha(GOLD_LIGHT, 55),
                              polygon_mask(w, h, arch_points(cx, arch_base, arch_w * 0.62, arch_h * 0.42, 0.6))))
    layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 170), ring(grow(opening, 2.5), opening)))
    layers.append(fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 120), ring(grow(opening, 8), grow(opening, 4))))

    # the dome over the iwan, tiled turquoise, with a gold finial
    drum = polygon_mask(w, h, [(cx - 0.062, 0.300), (cx + 0.062, 0.300), (cx + 0.062, 0.360), (cx - 0.062, 0.360)])
    layers.append(gradient_masked(w, h, shade(wall_light, 0.10), wall_dark, drum))
    layers.append(fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 170),
                              clip(polygon_mask(w, h, [(cx - 0.062, 0.300), (cx + 0.062, 0.300),
                                                       (cx + 0.062, 0.312), (cx - 0.062, 0.312)]), drum)))
    dome = dome_mask(w, h, cx, 0.302, 0.082, 0.100)
    layers.append(gradient_masked(w, h, with_alpha(shade(rgba(PALETTE["accent"]), 0.18), 255),
                                 with_alpha(shade(rgba(PALETTE["accent"]), -0.62), 255), dome))
    layers.append(fill_masked(w, h, with_alpha(rgba("#0E2C3E"), 90),
                              clip(brick(w, h, dome, row=0.016, col=0.022, weight=1), dome)))
    layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 220),
                              polygon_mask(w, h, [(cx - 0.003, 0.192), (cx + 0.003, 0.192),
                                                  (cx + 0.003, 0.166), (cx - 0.003, 0.166)])))
    layers.append(fill_masked(w, h, with_alpha(GOLD_LIGHT, 255), ellipse_mask(w, h, (cx - 0.009, 0.156, cx + 0.009, 0.174))))

    # two minarets flanking the iwan
    for mx, mtop in [(0.455, 0.250), (0.815, 0.250)]:
        layers.append(column(w, h, mx, mtop + 0.055, 0.672, 0.020, shade(wall_light, 0.05)))
        balcony = polygon_mask(w, h, [(mx - 0.026, mtop + 0.062), (mx + 0.026, mtop + 0.062),
                                      (mx + 0.026, mtop + 0.078), (mx - 0.026, mtop + 0.078)])
        layers.append(fill_masked(w, h, with_alpha(shade(wall_light, 0.18), 255), balcony))
        for k in range(4):
            ry = mtop + 0.115 + k * 0.060
            layers.append(fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 110),
                                      polygon_mask(w, h, [(mx - 0.010, ry), (mx + 0.010, ry),
                                                          (mx + 0.010, ry + 0.010), (mx - 0.010, ry + 0.010)])))
        mdome = dome_mask(w, h, mx, mtop + 0.060, 0.026, 0.048)
        layers.append(gradient_masked(w, h, with_alpha(shade(rgba(PALETTE["accent"]), 0.22), 255),
                                     with_alpha(shade(rgba(PALETTE["accent"]), -0.60), 255), mdome))
        layers.append(fill_masked(w, h, GOLD_LIGHT,
                                  polygon_mask(w, h, [(mx - 0.0025, mtop + 0.006), (mx + 0.0025, mtop + 0.006),
                                                      (mx + 0.0025, mtop - 0.012), (mx - 0.0025, mtop - 0.012)])))

    # side doors and lit windows: the warm light is what makes it a palace and not a wall
    for dx, dw in [(0.392, 0.045), (0.878, 0.048)]:
        door = polygon_mask(w, h, arch_points(dx, 0.672, dw, 0.115, 0.58))
        layers.append(fill_masked(w, h, with_alpha(rgba("#0A1622"), 255), door))
        lamp = ellipse_mask(w, h, (dx - dw * 0.16, 0.596, dx + dw * 0.16, 0.618))
        layers.append(glow(w, h, lamp, GOLD_LIGHT, 6, 170))
        layers.append(fill_masked(w, h, with_alpha(GOLD_LIGHT, 220), lamp))
        layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 150), ring(grow(door, 2.0), door)))
        layers.append(fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 70), ring(grow(door, 2.6), grow(door, 1.4))))
    for wx, wy in [(0.560, 0.560), (0.710, 0.560), (0.520, 0.512), (0.750, 0.512)]:
        window = polygon_mask(w, h, arch_points(wx, wy + 0.030, 0.018, 0.030, 0.8))
        layers.append(glow(w, h, window, GOLD_LIGHT, 6, 165))
        layers.append(fill_masked(w, h, with_alpha(GOLD_LIGHT, 240), window))

    # a studded wooden door inside the arch: it gives the gate a human scale
    door = polygon_mask(w, h, arch_points(cx, arch_base, arch_w * 0.78, arch_h * 0.74, 0.6))
    layers.append(gradient_masked(w, h, shade(WOOD, 0.10), shade(WOOD_DARK, -0.20), door))
    for i in range(4):
        x = cx - arch_w * 0.30 + i * arch_w * 0.20
        layers.append(fill_masked(w, h, with_alpha(shade(WOOD_DARK, -0.35), 150),
                                  clip(polygon_mask(w, h, [(x, 0.40), (x + 0.003, 0.40),
                                                           (x + 0.003, arch_base), (x, arch_base)]), door)))
    layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 230),
                             clip(ring(door, grow(door, -1.6)), door)))

    # the courtyard: a reflecting pool in front of the gate
    ground = polygon_mask(w, h, [(0.0, 0.672), (1.0, 0.672), (1.0, 1.0), (0.0, 1.0)])
    layers.append(gradient_masked(w, h, rgba("#1B3049"), rgba("#0A1421"), ground))
    layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 70),
                              polygon_mask(w, h, [(0.345, 0.670), (0.985, 0.670),
                                                  (0.985, 0.676), (0.345, 0.676)])))
    for i in range(3):
        y = 0.672 + i * 0.012
        step = polygon_mask(w, h, [(0.44 - i * 0.02, y), (0.83 + i * 0.02, y),
                                   (0.83 + i * 0.02, y + 0.012), (0.44 - i * 0.02, y + 0.012)])
        layers.append(fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.30 + i * 0.08), 255), step))
        layers.append(fill_masked(w, h, with_alpha((255, 255, 255, 255), 34),
                                  polygon_mask(w, h, [(0.44 - i * 0.02, y), (0.83 + i * 0.02, y),
                                                      (0.83 + i * 0.02, y + 0.003), (0.44 - i * 0.02, y + 0.003)])))
    basin = ellipse_mask(w, h, (0.395, 0.742, 0.885, 0.842))
    layers.append(fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.35), 255), basin))
    layers.append(fill_masked(w, h, with_alpha(shade(WATER, -0.25), 235), ellipse_mask(w, h, (0.410, 0.752, 0.870, 0.832))))
    layers.append(fill_masked(w, h, with_alpha(IVORY, 80), ellipse_mask(w, h, (0.700, 0.772, 0.760, 0.782))))
    layers.append(fill_masked(w, h, with_alpha(GOLD_LIGHT, 32), ellipse_mask(w, h, (0.560, 0.778, 0.700, 0.806))))
    layers.append(fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 28), ellipse_mask(w, h, (0.470, 0.788, 0.545, 0.812))))
    layers.append(fill_masked(w, h, with_alpha(shade(STONE_DARK, 0.15), 235),
                              ring(ellipse_mask(w, h, (0.395, 0.742, 0.885, 0.842)),
                                   ellipse_mask(w, h, (0.402, 0.748, 0.878, 0.837)))))

    # cypresses at the edges only: the left third stays calm for the level card
    for tx, th, tw in [(0.075, 0.145, 0.030), (0.115, 0.115, 0.024), (0.955, 0.130, 0.028)]:
        layers.append(cypress(w, h, tx, 0.672, th, tw, rgba(PALETTE["success"])))

    layers.append(vfade(w, h, 0.84, 1.0, NIGHT_DEEP, 0, 225))
    layers.append(vfade(w, h, 0.0, 0.30, shade(NIGHT_DEEP, 0), 120, 0))
    return finish(layering(*layers), w, h)


def district_plate(w, h, asset_id):
    horizon = 0.560
    layers = [sky(w, h, horizon)]
    layers.append(fill_masked(w, h, with_alpha(rgba("#12253D"), 255), polygon_mask(w, h, [
        (0.0, 0.560), (0.15, 0.520), (0.32, 0.555), (0.55, 0.512), (0.78, 0.550),
        (0.92, 0.518), (1.0, 0.545), (1.0, 0.66), (0.0, 0.66)])))

    wall_light, wall_dark = rgba("#2A4867"), rgba("#152740")
    ground = polygon_mask(w, h, [(0.0, 0.560), (1.0, 0.560), (1.0, 1.0), (0.0, 1.0)])
    layers.append(gradient_masked(w, h, rgba("#22384F"), rgba("#101C2C"), ground))

    wall = polygon_mask(w, h, [(0.03, 0.330), (0.97, 0.330), (0.97, 0.585), (0.03, 0.585)])
    layers.append(gradient_masked(w, h, wall_light, wall_dark, wall))
    layers.append(fill_masked(w, h, with_alpha(rgba("#0F2033"), 90), brick(w, h, wall, row=0.042, col=0.070)))
    layers.append(fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 200),
                              polygon_mask(w, h, [(0.03, 0.330), (0.97, 0.330),
                                                  (0.97, 0.362), (0.03, 0.362)])))
    layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 130),
                              polygon_mask(w, h, [(0.03, 0.362), (0.97, 0.362),
                                                  (0.97, 0.366), (0.03, 0.366)])))
    layers.append(fill_masked(w, h, with_alpha(shade(wall_light, -0.10), 255),
                              parapet(w, h, 0.03, 0.97, 0.272, 0.300, 24)))
    for i in range(5):
        nx = 0.13 + i * 0.185
        niche = polygon_mask(w, h, arch_points(nx, 0.560, 0.105, 0.150, 0.62))
        layers.append(fill_masked(w, h, with_alpha(shade(wall_dark, -0.20), 210), niche))
        layers.append(fill_masked(w, h, with_alpha(wall_light, 120), ring(grow(niche, 1.6), niche)))
    layers.append(gradient_masked(w, h, shade(STONE_DARK, -0.20), shade(STONE_DARK, -0.55),
                                  polygon_mask(w, h, [(0.03, 0.585), (0.97, 0.585),
                                                      (0.97, 0.615), (0.03, 0.615)])))

    if asset_id == "district_ch01_d1":
        # Firouzeh Square: paving, a dry octagonal pool, two column stumps
        for i in range(7):
            y = 0.60 + i * 0.055
            layers.append(fill_masked(w, h, with_alpha(shade(rgba("#1B3049"), 0.10), 70),
                                      polygon_mask(w, h, [(0, y), (1, y), (1, y + 0.004), (0, y + 0.004)])))
        for i in range(9):
            x = 0.03 + i * 0.115
            layers.append(fill_masked(w, h, with_alpha(shade(rgba("#1B3049"), 0.10), 55),
                                      polygon_mask(w, h, [(x, 0.60), (x + 0.004, 0.60),
                                                          (x + 0.012, 1.0), (x + 0.006, 1.0)])))
        pool = regular_polygon(0.66, 0.815, 0.185, 0.085, 8, math.pi / 8)
        layers.append(soft_shadow(w, h, polygon_mask(w, h, pool), (0, 6), 6, 110))
        layers.append(fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.42), 255), polygon_mask(w, h, pool)))
        layers.append(fill_masked(w, h, with_alpha(shade(STONE, 0.02), 255),
                                  ring(polygon_mask(w, h, pool),
                                       polygon_mask(w, h, regular_polygon(0.66, 0.815, 0.158, 0.068, 8, math.pi / 8)))))
        layers.append(fill_masked(w, h, with_alpha(shade(WATER, -0.45), 235),
                                  polygon_mask(w, h, regular_polygon(0.66, 0.815, 0.150, 0.062, 8, math.pi / 8))))
        layers.append(fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.70), 200),
                                  polygon_mask(w, h, regular_polygon(0.66, 0.815, 0.090, 0.035, 8, math.pi / 8))))
        for sx in (0.17, 0.30):
            stub = polygon_mask(w, h, [(sx, 0.610), (sx + 0.036, 0.610), (sx + 0.036, 0.740), (sx, 0.740)])
            layers.append(soft_shadow(w, h, stub, (6, 4), 5, 100))
            layers.append(gradient_masked(w, h, shade(wall_light, 0.12), shade(wall_light, -0.35), stub))
            layers.append(fill_masked(w, h, with_alpha(shade(STONE, 0.10), 235),
                                      polygon_mask(w, h, [(sx - 0.008, 0.600), (sx + 0.044, 0.600),
                                                          (sx + 0.044, 0.614), (sx - 0.008, 0.614)])))

    elif asset_id == "district_ch01_d2":
        # Lapis Garden: bare earth, a broken canal, one cypress stump
        earth = polygon_mask(w, h, [(0.02, 0.600), (0.72, 0.600), (0.80, 0.980), (0.0, 0.980)])
        layers.append(fill_masked(w, h, with_alpha(shade(WOOD_DARK, -0.72), 235), earth))
        canal = polygon_mask(w, h, [(0.06, 0.660), (0.50, 0.660), (0.57, 0.880), (0.0, 0.880)])
        layers.append(soft_shadow(w, h, canal, (0, 5), 5, 100))
        layers.append(fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.28), 255), canal))
        layers.append(fill_masked(w, h, with_alpha(shade(WATER, -0.28), 230),
                                  polygon_mask(w, h, [(0.085, 0.690), (0.475, 0.690), (0.525, 0.855), (0.035, 0.855)])))
        layers.append(fill_masked(w, h, with_alpha(IVORY, 60),
                                  polygon_mask(w, h, [(0.13, 0.716), (0.42, 0.716),
                                                      (0.425, 0.723), (0.128, 0.723)])))
        layers.append(fill_masked(w, h, with_alpha(IVORY, 55),
                                  polygon_mask(w, h, [(0.14, 0.700), (0.44, 0.700),
                                                      (0.45, 0.706), (0.13, 0.706)])))
        stump = polygon_mask(w, h, [(0.655, 0.585), (0.700, 0.585), (0.700, 0.645), (0.655, 0.645)])
        layers.append(fill_masked(w, h, with_alpha(shade(WOOD_DARK, -0.20), 255), stump))
        layers.append(fill_masked(w, h, with_alpha(shade(WOOD, -0.10), 255),
                                  ellipse_mask(w, h, (0.655, 0.578, 0.700, 0.596))))
        for bx, by, br in [(0.80, 0.640, 0.045), (0.87, 0.665, 0.035)]:
            layers.append(fill_masked(w, h, with_alpha(shade(rgba(PALETTE["success"]), -0.72), 255),
                                      ellipse_mask(w, h, (bx - br, by - br * 0.6, bx + br, by + br * 0.6))))
        for tx, th, tw in [(0.90, 0.150, 0.028)]:
            layers.append(cypress(w, h, tx, 0.600, th, tw, rgba(PALETTE["success"])))

    else:  # district_ch01_d3: the Prince's Gate, half built, with scaffolding
        opening = polygon_mask(w, h, arch_points(0.50, 0.980, 0.560, 0.560, 0.58))
        layers.append(fill_masked(w, h, with_alpha(rgba("#08131F"), 255), opening))
        layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 150), ring(grow(opening, 3), opening)))
        layers.append(fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 100), ring(grow(opening, 9), grow(opening, 5))))
        for i in range(3):
            y = 0.395 + i * 0.030
            inset = i * 0.045
            layers.append(fill_masked(w, h, with_alpha(shade(GOLD_MID, 0.30 - i * 0.14), 225),
                                      polygon_mask(w, h, [(0.5 - 0.28 + inset, y), (0.5 + 0.28 - inset, y),
                                                          (0.5 + 0.28 - inset, y + 0.014),
                                                          (0.5 - 0.28 + inset, y + 0.014)])))
        pole = shade(WOOD, -0.30)
        for x in (0.245, 0.360, 0.640, 0.755):
            layers.append(fill_masked(w, h, with_alpha(pole, 245),
                                      polygon_mask(w, h, [(x, 0.300), (x + 0.010, 0.300),
                                                          (x + 0.010, 0.880), (x, 0.880)])))
        for y in (0.420, 0.620):
            layers.append(fill_masked(w, h, with_alpha(pole, 235),
                                      polygon_mask(w, h, [(0.235, y), (0.765, y), (0.765, y + 0.009), (0.235, y + 0.009)])))
        for rx, ry, rw, rh in [(0.10, 0.900, 0.09, 0.045), (0.20, 0.925, 0.07, 0.035),
                               (0.80, 0.905, 0.10, 0.050), (0.90, 0.930, 0.06, 0.030)]:
            layers.append(fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.35), 255),
                                      polygon_mask(w, h, [(rx, ry), (rx + rw, ry - rh * 0.6),
                                                          (rx + rw, ry), (rx, ry + rh * 0.5)])))

    layers.append(vfade(w, h, 0.86, 1.0, NIGHT_DEEP, 0, 210))
    return finish(layering(*layers), w, h)


# ------------------------------------------------------------------------------------------------
# props: one object per district task, flat, same light from the upper left


def prop(w, h, asset_id):
    layers = []

    if asset_id == "prop_ch01_pool":
        # the square's fountain pool: an octagonal stone rim, water inside, a paving apron
        apron = regular_polygon(0.5, 0.60, 0.47, 0.34, 8, math.pi / 8)
        rim_outer = regular_polygon(0.5, 0.57, 0.38, 0.26, 8, math.pi / 8)
        rim_inner = regular_polygon(0.5, 0.57, 0.30, 0.19, 8, math.pi / 8)
        water = regular_polygon(0.5, 0.57, 0.285, 0.175, 8, math.pi / 8)
        layers = [
            soft_shadow(w, h, polygon_mask(w, h, apron), (0, 9), 9, 115),
            fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.55), 255), polygon_mask(w, h, apron)),
            fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.25), 255), polygon_mask(w, h, apron)),
            gradient_masked(w, h, with_alpha(shade(STONE, 0.16), 255),
                            with_alpha(shade(STONE_DARK, -0.30), 255), polygon_mask(w, h, rim_outer)),
            fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.62), 255), polygon_mask(w, h, rim_inner)),
            gradient_masked(w, h, with_alpha(shade(WATER, 0.22), 255),
                            with_alpha(shade(WATER, -0.55), 255), polygon_mask(w, h, water)),
            fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 70),
                        clip(polygon_mask(w, h, [(0.24, 0.53), (0.76, 0.53), (0.76, 0.545), (0.24, 0.545)]),
                             polygon_mask(w, h, water))),
            fill_masked(w, h, with_alpha(IVORY, 60),
                        clip(polygon_mask(w, h, [(0.30, 0.61), (0.62, 0.61), (0.62, 0.618), (0.30, 0.618)]),
                             polygon_mask(w, h, water))),
            fill_masked(w, h, with_alpha(GOLD_MID, 110),
                        ring(polygon_mask(w, h, rim_outer), polygon_mask(w, h, rim_inner))),
        ]

    elif asset_id == "prop_ch01_wall":
        body = polygon_mask(w, h, [(0.10, 0.40), (0.90, 0.40), (0.90, 0.86), (0.10, 0.86)])
        layers = [
            soft_shadow(w, h, body, (0, 8), 8, 115),
            gradient_masked(w, h, shade(rgba(PALETTE["surface-raised"]), 0.08),
                            shade(rgba(PALETTE["surface-raised"]), -0.55), body),
            fill_masked(w, h, with_alpha(shade(rgba(PALETTE["surface"]), -0.28), 110),
                        brick(w, h, body, row=0.040, col=0.070)),
        ]
        for i in range(5):
            x = 0.10 + i * 0.152
            layers.append(fill_masked(w, h, shade(rgba(PALETTE["surface"]), -0.05),
                                      polygon_mask(w, h, [(x, 0.34), (x + 0.022, 0.34),
                                                          (x + 0.022, 0.42), (x, 0.42)])))
        layers.append(tile_band(w, h, 0.46, 0.54, with_alpha(rgba(PALETTE["accent"]), 245), count=10))
        layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 120),
                                  polygon_mask(w, h, [(0.10, 0.545), (0.90, 0.545), (0.90, 0.552), (0.10, 0.552)])))
        layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 70),
                                  polygon_mask(w, h, [(0.10, 0.405), (0.90, 0.405), (0.90, 0.411), (0.10, 0.411)])))

    elif asset_id == "prop_ch01_portico":
        block = polygon_mask(w, h, [(0.14, 0.28), (0.86, 0.28), (0.86, 0.86), (0.14, 0.86)])
        opening = polygon_mask(w, h, arch_points(0.5, 0.86, 0.42, 0.44, 0.62))
        layers = [
            soft_shadow(w, h, block, (0, 8), 8, 115),
            gradient_masked(w, h, shade(rgba(PALETTE["surface-raised"]), 0.14),
                            shade(rgba(PALETTE["surface-raised"]), -0.48), block),
            fill_masked(w, h, with_alpha(NIGHT_DEEP, 255), opening),
            fill_masked(w, h, with_alpha(GOLD_MID, 150), ring(grow(opening, 3), opening)),
            fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 110), ring(grow(opening, 8), grow(opening, 4))),
            tile_band(w, h, 0.29, 0.35, with_alpha(rgba(PALETTE["accent"]), 215), count=14),
            fill_masked(w, h, with_alpha(GOLD_MID, 90),
                        polygon_mask(w, h, [(0.14, 0.355), (0.86, 0.355), (0.86, 0.361), (0.14, 0.361)])),
        ]

    elif asset_id == "prop_ch01_bazaar":
        # three stalls, one colour family: accent and its two shades
        family = [rgba(PALETTE["accent"]), shade(rgba(PALETTE["accent"]), -0.28),
                  shade(rgba(PALETTE["accent"]), 0.18)]
        layers = [soft_shadow(w, h, polygon_mask(w, h, [(0.06, 0.80), (0.94, 0.80), (0.94, 0.90), (0.06, 0.90)]),
                              (0, 6), 6, 95)]
        for i, colour in enumerate(family):
            x = 0.05 + i * 0.30
            layers += [
                fill_masked(w, h, shade(WOOD_DARK, -0.15),
                            polygon_mask(w, h, [(x + 0.02, 0.54), (x + 0.24, 0.54),
                                                (x + 0.24, 0.86), (x + 0.02, 0.86)])),
                fill_masked(w, h, with_alpha(shade(colour, -0.5), 255),
                            polygon_mask(w, h, [(x + 0.04, 0.60), (x + 0.22, 0.60),
                                                (x + 0.22, 0.86), (x + 0.04, 0.86)])),
                fill_masked(w, h, with_alpha(colour, 255),
                            polygon_mask(w, h, [(x, 0.54), (x + 0.26, 0.54), (x + 0.22, 0.40), (x + 0.04, 0.40)])),
                fill_masked(w, h, with_alpha(shade(colour, -0.35), 255),
                            polygon_mask(w, h, [(x + 0.04, 0.50), (x + 0.26, 0.50), (x + 0.24, 0.54), (x + 0.02, 0.54)])),
                fill_masked(w, h, with_alpha(GOLD_MID, 200),
                            polygon_mask(w, h, [(x + 0.05, 0.44), (x + 0.21, 0.44), (x + 0.21, 0.455), (x + 0.05, 0.455)])),
            ]

    elif asset_id == "prop_ch01_canal":
        # brick banks on both sides, flat water between them, one ripple line
        bank_top = polygon_mask(w, h, [(0.06, 0.34), (0.94, 0.34), (0.97, 0.46), (0.03, 0.46)])
        water = polygon_mask(w, h, [(0.03, 0.46), (0.97, 0.46), (0.97, 0.68), (0.03, 0.68)])
        bank_bottom = polygon_mask(w, h, [(0.03, 0.68), (0.97, 0.68), (0.94, 0.80), (0.06, 0.80)])
        layers = [
            soft_shadow(w, h, bank_bottom, (0, 7), 7, 105),
            fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.20), 255), bank_top),
            fill_masked(w, h, with_alpha(shade(STONE_DARK, -0.20), 255), bank_bottom),
            fill_masked(w, h, with_alpha(shade(rgba("#0F2033"), 0.10), 150), brick(w, h, bank_top, row=0.05, col=0.08)),
            fill_masked(w, h, with_alpha(shade(rgba("#0F2033"), 0.10), 150), brick(w, h, bank_bottom, row=0.05, col=0.08)),
            gradient_masked(w, h, with_alpha(shade(WATER, 0.15), 255), with_alpha(shade(WATER, -0.55), 255), water),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 70),
                        clip(polygon_mask(w, h, [(0.12, 0.53), (0.86, 0.53), (0.86, 0.542), (0.12, 0.542)]), water)),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 34),
                        clip(polygon_mask(w, h, [(0.20, 0.61), (0.72, 0.61), (0.72, 0.62), (0.20, 0.62)]), water)),
            fill_masked(w, h, with_alpha(shade(STONE, 0.10), 235),
                        polygon_mask(w, h, [(0.03, 0.455), (0.97, 0.455), (0.97, 0.470), (0.03, 0.470)])),
        ]

    elif asset_id == "prop_ch01_cypress":
        # a short row: three cypresses, silhouette first
        layers = []
        for tx, th, tw in [(0.30, 0.66, 0.115), (0.50, 0.80, 0.135), (0.70, 0.62, 0.110)]:
            tree = polygon_mask(w, h, [(tx, 0.90 - th), (tx + tw * 0.45, 0.90 - th * 0.55),
                                       (tx + tw * 0.35, 0.90 - th * 0.18), (tx + tw * 0.22, 0.90),
                                       (tx - tw * 0.22, 0.90), (tx - tw * 0.35, 0.90 - th * 0.18),
                                       (tx - tw * 0.45, 0.90 - th * 0.55)])
            layers += [
                soft_shadow(w, h, tree, (0, 6), 6, 90),
                gradient_masked(w, h, with_alpha(shade(rgba(PALETTE["success"]), -0.30), 255),
                                with_alpha(shade(rgba(PALETTE["success"]), -0.82), 255), tree),
                rim_light(w, h, tree, with_alpha(rgba(PALETTE["success"]), 120), 2),
                fill_masked(w, h, shade(WOOD_DARK, -0.15),
                            polygon_mask(w, h, [(tx - 0.012, 0.86), (tx + 0.012, 0.86),
                                                (tx + 0.012, 0.94), (tx - 0.012, 0.94)])),
            ]

    elif asset_id == "prop_ch01_pavilion":
        # chahar-taq: four arches, one dome
        base = polygon_mask(w, h, [(0.12, 0.60), (0.88, 0.60), (0.88, 0.88), (0.12, 0.88)])
        dome = mask(w, h)
        ImageDraw.Draw(dome).pieslice((0.22 * w * SS, 0.14 * h * SS, 0.78 * w * SS, 0.66 * h * SS),
                                      180, 360, fill=255)
        layers = [
            soft_shadow(w, h, base, (0, 8), 8, 110),
            fill_masked(w, h, shade(rgba(PALETTE["surface-raised"]), -0.20), base),
            gradient_masked(w, h, with_alpha(shade(rgba(PALETTE["accent"]), 0.05), 255),
                            with_alpha(shade(rgba(PALETTE["accent"]), -0.60), 255), dome),
            fill_masked(w, h, with_alpha(GOLD_MID, 220),
                        polygon_mask(w, h, [(0.22, 0.585), (0.78, 0.585), (0.78, 0.605), (0.22, 0.605)])),
            fill_masked(w, h, GOLD_LIGHT, ellipse_mask(w, h, (0.475, 0.075, 0.525, 0.125))),
        ]
        for ax in (0.20, 0.40, 0.60, 0.80):
            opening = polygon_mask(w, h, arch_points(ax + 0.05, 0.86, 0.10, 0.20, 0.55))
            layers += [
                fill_masked(w, h, with_alpha(NIGHT_DEEP, 255), opening),
                fill_masked(w, h, with_alpha(GOLD_MID, 120), ring(grow(opening, 1.5), opening)),
            ]

    elif asset_id == "prop_ch01_fountain":
        basin = ellipse_mask(w, h, (0.16, 0.66, 0.84, 0.88))
        pool = ellipse_mask(w, h, (0.21, 0.69, 0.79, 0.85))
        bowl = ellipse_mask(w, h, (0.28, 0.36, 0.72, 0.48))
        layers = [
            soft_shadow(w, h, basin, (0, 8), 8, 115),
            fill_masked(w, h, shade(STONE, -0.08), basin),
            fill_masked(w, h, with_alpha(WATER, 225), pool),
            fill_masked(w, h, with_alpha((255, 255, 255, 255), 55),
                        clip(ellipse_mask(w, h, (0.30, 0.73, 0.50, 0.78)), pool)),
            gradient_masked(w, h, shade(STONE, 0.16), shade(STONE, -0.42),
                            polygon_mask(w, h, [(0.465, 0.30), (0.535, 0.30), (0.535, 0.72), (0.465, 0.72)])),
            fill_masked(w, h, shade(STONE, 0.10), bowl),
            fill_masked(w, h, with_alpha(WATER, 200), ellipse_mask(w, h, (0.31, 0.39, 0.69, 0.46))),
            fill_masked(w, h, shade(STONE, 0.16), ellipse_mask(w, h, (0.46, 0.20, 0.54, 0.30))),
            fill_masked(w, h, with_alpha(WATER, 170), ellipse_mask(w, h, (0.475, 0.24, 0.525, 0.32))),
        ]

    elif asset_id == "prop_ch01_arch":
        outer = polygon_mask(w, h, arch_points(0.5, 0.90, 0.74, 0.70, 0.58))
        inner = polygon_mask(w, h, arch_points(0.5, 0.90, 0.46, 0.52, 0.58))
        layers = [
            soft_shadow(w, h, outer, (0, 8), 8, 115),
            gradient_masked(w, h, shade(rgba(PALETTE["surface-raised"]), 0.16),
                            shade(rgba(PALETTE["surface-raised"]), -0.48), outer),
            fill_masked(w, h, with_alpha(NIGHT_DEEP, 255), inner),
            fill_masked(w, h, with_alpha(GOLD_MID, 140), ring(grow(inner, 3), inner)),
        ]
        # muqarnas suggested with three bands, not modelled
        for i in range(3):
            y = 0.345 + i * 0.045
            inset = 0.06 + i * 0.05
            layers.append(fill_masked(w, h, with_alpha(shade(rgba(PALETTE["surface-raised"]), 0.26 - i * 0.10), 255),
                                      polygon_mask(w, h, [(0.5 - 0.30 + inset, y), (0.5 + 0.30 - inset, y),
                                                          (0.5 + 0.30 - inset, y + 0.014),
                                                          (0.5 - 0.30 + inset, y + 0.014)])))
        layers.append(fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 120),
                                  ring(grow(inner, 10), grow(inner, 5))))

    elif asset_id == "prop_ch01_gate":
        door = polygon_mask(w, h, arch_points(0.5, 0.90, 0.56, 0.70, 0.72))
        seam = polygon_mask(w, h, [(0.495, 0.24), (0.505, 0.24), (0.505, 0.90), (0.495, 0.90)])
        layers = [
            soft_shadow(w, h, door, (0, 8), 8, 115),
            gradient_masked(w, h, shade(WOOD, 0.20), shade(WOOD_DARK, -0.25), door),
            fill_masked(w, h, with_alpha(shade(WOOD_DARK, -0.40), 255), clip(seam, door)),
        ]
        for i in range(6):  # vertical boards
            x = 0.245 + i * 0.086
            layers.append(fill_masked(w, h, with_alpha(shade(WOOD_DARK, -0.20), 110),
                                      clip(polygon_mask(w, h, [(x, 0.20), (x + 0.004, 0.20),
                                                               (x + 0.004, 0.90), (x, 0.90)]), door)))
        for band in (0.52, 0.72):
            layers.append(fill_masked(w, h, with_alpha(shade(GOLD_MID, -0.15), 255),
                                      clip(polygon_mask(w, h, [(0.20, band), (0.80, band),
                                                               (0.80, band + 0.025), (0.20, band + 0.025)]), door)))
        for sx in (0.545, 0.455):
            layers.append(fill_masked(w, h, GOLD_LIGHT,
                                      ellipse_mask(w, h, (sx - 0.018, 0.615, sx + 0.018, 0.650))))
        layers.append(outline(w, h, door, with_alpha(INK, 195), 2))

    elif asset_id == "prop_ch01_naghareh":
        platform = polygon_mask(w, h, [(0.08, 0.62), (0.92, 0.62), (0.86, 0.86), (0.14, 0.86)])
        layers = [soft_shadow(w, h, platform, (0, 8), 8, 105),
                  gradient_masked(w, h, shade(WOOD, 0.10), shade(WOOD_DARK, -0.25), platform),
                  fill_masked(w, h, with_alpha(GOLD_MID, 180),
                              polygon_mask(w, h, [(0.08, 0.62), (0.92, 0.62), (0.92, 0.635), (0.14, 0.635)]))]
        for cx, rx, ry, top in [(0.30, 0.105, 0.055, 0.50), (0.50, 0.125, 0.065, 0.455),
                                (0.70, 0.105, 0.055, 0.50)]:
            drum = mask(w, h)
            ImageDraw.Draw(drum).rectangle(((cx - rx) * w * SS, top * h * SS,
                                            (cx + rx) * w * SS, (top + ry * 2) * h * SS), fill=255)
            ImageDraw.Draw(drum).ellipse(((cx - rx) * w * SS, (top + ry * 2 - ry) * h * SS,
                                          (cx + rx) * w * SS, (top + ry * 2 + ry) * h * SS), fill=255)
            layers += [
                fill_masked(w, h, shade(GOLD_MID, -0.10), drum),
                fill_masked(w, h, with_alpha(IVORY, 235),
                            ellipse_mask(w, h, (cx - rx, top - ry * 0.55, cx + rx, top + ry * 0.55))),
                fill_masked(w, h, with_alpha(shade(GOLD_MID, -0.45), 120),
                            clip(polygon_mask(w, h, [(cx - rx, top + ry * 0.55), (cx + rx, top + ry * 0.55),
                                                      (cx + rx, top + ry * 1.2), (cx - rx, top + ry * 1.2)]), drum)),
                outline(w, h, drum, with_alpha(INK, 170), 1.2),
            ]

    else:  # prop_ch01_banner: emblem only, no readable text
        pole = polygon_mask(w, h, [(0.455, 0.10), (0.500, 0.10), (0.500, 0.90), (0.455, 0.90)])
        flag = polygon_mask(w, h, [(0.50, 0.13), (0.90, 0.19), (0.86, 0.31), (0.90, 0.43), (0.50, 0.40)])
        layers = [
            soft_shadow(w, h, pole, (0, 6), 6, 95),
            fill_masked(w, h, shade(WOOD, -0.24), pole),
            gradient_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 255),
                            with_alpha(shade(rgba(PALETTE["accent"]), -0.50), 255), flag),
            fill_masked(w, h, with_alpha(GOLD_MID, 240),
                        clip(polygon_mask(w, h, [(0.50, 0.135), (0.90, 0.19), (0.90, 0.205), (0.50, 0.150)]), flag)),
            fill_masked(w, h, with_alpha(GOLD_LIGHT, 230), emblem(w, h, "diamond", 0.26)),
            fill_masked(w, h, GOLD_LIGHT, ellipse_mask(w, h, (0.435, 0.06, 0.520, 0.125))),
        ]

    return finish(layering(*layers), w, h)


# ------------------------------------------------------------------------------------------------
# reward chest and the store icon


def chest(w, h):
    body = rounded_mask(w, h, 0.055, 0.075)
    lid = mask(w, h)
    ld = ImageDraw.Draw(lid)
    ld.pieslice((0.055 * w * SS, 0.14 * h * SS, 0.945 * w * SS, 0.56 * h * SS), 180, 360, fill=255)
    ld.rectangle((0.055 * w * SS, 0.35 * h * SS, 0.945 * w * SS, 0.475 * h * SS), fill=255)
    lid = clip(lid, body)
    lock = polygon_mask(w, h, [(0.425, 0.415), (0.575, 0.415), (0.575, 0.585), (0.425, 0.585)])
    layers = [
        soft_shadow(w, h, body, (0, 10), 9, 125),
        gradient_masked(w, h, shade(WOOD, 0.22), shade(WOOD_DARK, -0.30), body),
        gradient_masked(w, h, shade(WOOD, 0.34), shade(WOOD, -0.25), lid),
        fill_masked(w, h, with_alpha(shade(WOOD_DARK, -0.35), 120),
                    clip(polygon_mask(w, h, [(0.055, 0.455), (0.945, 0.455), (0.945, 0.478), (0.055, 0.478)]), body)),
        fill_masked(w, h, with_alpha(GOLD_MID, 255),
                    clip(polygon_mask(w, h, [(0.055, 0.445), (0.945, 0.445), (0.945, 0.470), (0.055, 0.470)]), body)),
    ]
    for x in (0.165, 0.790):
        layers.append(fill_masked(w, h, with_alpha(GOLD_MID, 235),
                                  clip(polygon_mask(w, h, [(x, 0.06), (x + 0.045, 0.06),
                                                           (x + 0.045, 0.94), (x, 0.94)]), body)))
        layers.append(fill_masked(w, h, with_alpha(GOLD_LIGHT, 90),
                                  clip(polygon_mask(w, h, [(x, 0.06), (x + 0.014, 0.06),
                                                           (x + 0.014, 0.94), (x, 0.94)]), body)))
    layers += [
        gradient_masked(w, h, GOLD_LIGHT, GOLD_DARK, lock),
        fill_masked(w, h, with_alpha(INK, 240), ellipse_mask(w, h, (0.485, 0.455, 0.515, 0.500))),
        fill_masked(w, h, with_alpha(INK, 200), polygon_mask(w, h, [(0.492, 0.500), (0.508, 0.500),
                                                                   (0.504, 0.545), (0.496, 0.545)])),
        outline(w, h, body, with_alpha(INK, 210), 2),
        rim_light(w, h, body, with_alpha((255, 255, 255, 255), 45), 3),
    ]
    return finish(layering(*layers), w, h)


def app_icon(w, h):
    disc = rounded_mask(w, h, 0.0, 0.20)
    inner_round = rounded_mask(w, h, 0.018, 0.19)
    layers = [
        fill_masked(w, h, with_alpha(NIGHT_DEEP, 255), disc),
        masked(radial(w, h, (0.5, 0.42), 0.75, rgba("#1E3A63"), NIGHT_DEEP), inner_round),
        starfield(w, h, 46, seed=11, min_y=0.05, max_y=0.55, max_x=0.95),
    ]
    # the gate, centred, with two minarets and a tiled dome
    gate = polygon_mask(w, h, arch_points(0.5, 0.82, 0.40, 0.42, 0.62))
    layers += [
        fill_masked(w, h, with_alpha(shade(rgba(PALETTE["surface-raised"]), 0.06), 255), gate),
        fill_masked(w, h, with_alpha(NIGHT_DEEP, 255), polygon_mask(w, h, arch_points(0.5, 0.82, 0.22, 0.28, 0.60))),
        fill_masked(w, h, with_alpha(GOLD_MID, 255), ring(grow(gate, 5), gate)),
    ]
    for cx, top in [(0.245, 0.40), (0.755, 0.40)]:
        layers += [
            fill_masked(w, h, with_alpha(shade(rgba(PALETTE["surface-raised"]), 0.10), 255),
                        polygon_mask(w, h, [(cx - 0.030, top), (cx + 0.030, top),
                                            (cx + 0.030, 0.84), (cx - 0.030, 0.84)])),
            gradient_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 255),
                            with_alpha(shade(rgba(PALETTE["accent"]), -0.55), 255),
                            polygon_mask(w, h, [(cx - 0.040, top), (cx + 0.040, top),
                                                (cx + 0.008, top - 0.085), (cx - 0.008, top - 0.085)])),
            fill_masked(w, h, with_alpha(GOLD_MID, 255),
                        polygon_mask(w, h, [(cx - 0.004, top - 0.095), (cx + 0.004, top - 0.095),
                                            (cx + 0.004, top - 0.078), (cx - 0.004, top - 0.078)])),
        ]
    layers.append(fill_masked(w, h, with_alpha(rgba(PALETTE["accent"]), 220),
                              tile_band(w, h, 0.615, 0.645, with_alpha(rgba(PALETTE["accent"]), 255), count=9)))
    layers += [
        fill_masked(w, h, with_alpha(GOLD_MID, 255),
                    ring(inner_round, rounded_mask(w, h, 0.062, 0.155))),
        fill_masked(w, h, with_alpha((255, 255, 255, 255), 30),
                    ring(rounded_mask(w, h, 0.030, 0.185), rounded_mask(w, h, 0.040, 0.180))),
    ]
    return finish(layering(*layers), w, h)


# ------------------------------------------------------------------------------------------------
# dispatch


def draw_asset(asset: dict) -> Image.Image:
    asset_id = asset["id"]
    width, height = asset["size"]

    # Scenes are drawn with the same kit as the sprites, but at 2× supersampling instead of 4×:
    # 1024×768 at 4× means 50 MB per layer and a hundred layers, which is how this process runs out
    # of memory. At 2× a flat illustration loses nothing that a LANCZOS downsample keeps.
    big = width * height >= 512 * 512
    previous = globals()["SS"]
    if big:
        # `SS` is a module-level name in both modules: draw.py's shapes and this file's coordinate
        # maths must agree, or a dome lands at twice its intended position. Patch both.
        _draw.SS = globals()["SS"] = 2
    try:
        return _draw_asset(asset_id, width, height)
    finally:
        _draw.SS = globals()["SS"] = previous


def _draw_asset(asset_id: str, width: int, height: int) -> Image.Image:
    if asset_id.startswith("piece_"):
        return piece(width, height, asset_id)
    if asset_id.startswith("powerup_"):
        return powerup(width, height, asset_id)
    if asset_id.startswith("obstacle_"):
        return obstacle(width, height, asset_id)
    if asset_id.startswith("icon_"):
        return hud_icon(width, height, asset_id)
    if asset_id in ("panel_frame", "button_primary", "board_frame"):
        return nine_slice(width, height, asset_id)
    if asset_id == "home_palace":
        return home_palace(width, height)
    if asset_id.startswith("district_"):
        return district_plate(width, height, asset_id)
    if asset_id.startswith("prop_"):
        return prop(width, height, asset_id)
    if asset_id == "reward_chest":
        return chest(width, height)
    if asset_id == "app_icon":
        return app_icon(width, height)

    raise SystemExit(f"gen_art: no drawing for {asset_id} — write one before adding it to the manifest")


def check_palette() -> list[str]:
    """This file mirrors replica/design/tokens.json; a token change must not pass silently."""
    if not TOKENS.exists():
        return ["replica/design/tokens.json is missing"]
    tokens = json.loads(TOKENS.read_text(encoding="utf-8"))
    colours = tokens["color"]
    pieces = tokens["piece"]
    problems = []
    for key in ("bg", "surface", "surface-raised", "border", "border-input", "text", "text-muted",
                "accent", "accent-strong", "gold", "danger", "success", "warning"):
        if PALETTE.get(key, "").lower() != colours.get(key, "").lower():
            problems.append(f"palette drift: {key} = {PALETTE.get(key)!r}, tokens.json says {colours.get(key)!r}")
    for stone in ("firouzeh", "lajvard", "aqiq", "zomorrod", "morvarid"):
        if PALETTE.get(f"piece-{stone}", "").lower() != pieces.get(stone, "").lower():
            problems.append(f"palette drift: piece-{stone} = {PALETTE.get(f'piece-{stone}')!r}, "
                            f"tokens.json says {pieces.get(stone)!r}")
    return problems


def contact_sheet(drawn: list[tuple[str, Image.Image]], path: Path) -> None:
    cell, pad, cols = 200, 14, 6
    rows = (len(drawn) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (cell + pad) + pad, rows * (cell + pad) + pad),
                      rgba(PALETTE["bg"]))
    for i, (_asset_id, image) in enumerate(drawn):
        preview = image.copy()
        preview.thumbnail((cell, cell), Image.LANCZOS)
        x = pad + (i % cols) * (cell + pad)
        y = pad + (i // cols) * (cell + pad)
        sheet.alpha_composite(preview, (x + (cell - preview.width) // 2, y + (cell - preview.height) // 2))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(path, "PNG", optimize=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="*", default=None, help="draw only these ids")
    parser.add_argument("--sheet", action="store_true", help="also write art/preview/contact-sheet.png")
    parser.add_argument("--check", action="store_true", help="redraw to a temp dir and compare with the repo")
    args = parser.parse_args(argv)

    for problem in check_palette():
        print("  ! " + problem)

    assets = json.loads(MANIFEST.read_text(encoding="utf-8"))["assets"]
    if args.only:
        wanted = set(args.only)
        unknown = wanted - {a["id"] for a in assets}
        if unknown:
            print(f"gen_art: not in the manifest: {', '.join(sorted(unknown))}", file=sys.stderr)
            return 1
        assets = [a for a in assets if a["id"] in wanted]

    target = Path(tempfile.mkdtemp()) if args.check else OUT
    target.mkdir(parents=True, exist_ok=True)

    drawn: list[tuple[str, Image.Image]] = []
    stale = 0
    for asset in assets:
        image = draw_asset(asset)
        drawn.append((asset["id"], image))
        path = target / f"{asset['id']}.png"
        image.save(path, "PNG", optimize=True)

        if args.check:
            committed = OUT / f"{asset['id']}.png"
            if not committed.exists():
                print(f"  x {asset['id']}.png is missing from the repo", file=sys.stderr)
                stale += 1
            elif hashlib.sha256(committed.read_bytes()).digest() != hashlib.sha256(path.read_bytes()).digest():
                print(f"  x {asset['id']}.png is not what gen_art.py draws now", file=sys.stderr)
                stale += 1

    if args.sheet:
        contact_sheet(drawn, PREVIEW / "contact-sheet.png")
        print(f"wrote {PREVIEW.relative_to(ROOT)}/contact-sheet.png")

    print(f"gen_art: drew {len(drawn)} asset(s) into {target}")
    if args.check:
        if stale:
            print(f"gen_art: {stale} sprite(s) stale — run python3 tools/art/gen_art.py", file=sys.stderr)
            return 1
        print("gen_art: every committed sprite matches the generator")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
