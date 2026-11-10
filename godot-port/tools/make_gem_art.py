#!/usr/bin/env python3
"""Draws the five board stones, in the style of a jewelled Persian inlay.

The reference this follows is a tray of set stones: a turquoise cabochon in a thin gold setting, a lapis
eight-point star, a carnelian drop, an emerald octagon, a pearl. What makes those read as stones and not
as icons is a short list, and every one of them is a layer here:

  setting    a thin gold ring, not a chunky frame: the metal is what holds the stone, it does not
             compete with it. Lit on the upper left, dark on the lower right.
  body       a cabochon is a dome: the diffuse term falls to zero at the limb. A faceted stone is flat
             with a bevel along each edge, and the bevels facing the light are bright.
  polish     one big soft specular across the upper left, and a small hard one where the surface turns
             — a single highlight is what a glossy mineral actually shows.
  refraction a little of the stone's own light near the girdle, so the colour is deepest in the middle
             and glows at the edge, the way a real stone does.

Everything is drawn at four times the final size and resampled, so the curves and the specular stay
clean at 36 dp, which is the size a phone actually shows them at.

    python3 godot-port/tools/make_gem_art.py
"""

from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "gems")
SIZE = 160
SS = 4
CX = CY = SIZE * 0.5

GOLD_DARK = (128, 82, 22)
GOLD = (196, 148, 62)
GOLD_LIGHT = (248, 220, 150)
WHITE = (255, 255, 255)

GEMS = {
    # Turquoise cushion: the square a tile is polished into, cut like a stone rather than domed.
    "firouzeh": dict(shape="cushion", cut="faceted", body=(36, 174, 164), deep=(12, 96, 96),
                     light=(168, 246, 238)),
    # Lapis hexagon: six flat faces, the shape of a glazed tile, not a star and not a dome.
    "lajvard": dict(shape="hexagon", cut="faceted", body=(38, 74, 168), deep=(16, 34, 96),
                    light=(146, 180, 246)),
    # Carnelian drop: the deep orange red of a seal stone.
    "aqiq": dict(shape="drop", cut="faceted", body=(190, 62, 44), deep=(104, 24, 20),
                 light=(250, 168, 140)),
    # Emerald cut: a tall rectangle with clipped corners, step-faceted.
    "zomorrod": dict(shape="emerald", cut="faceted", body=(28, 128, 74), deep=(10, 62, 38),
                     light=(150, 236, 176)),
    # Pearl: a sphere, lit once.
    "morvarid": dict(shape="round", cut="sphere", body=(226, 214, 192), deep=(150, 138, 120),
                     light=(255, 252, 244)),
}


# ---- geometry -----------------------------------------------------------------------------------


def _circle(radius, steps=96):
    return [(CX + math.cos(i * 2 * math.pi / steps) * radius,
             CY + math.sin(i * 2 * math.pi / steps) * radius) for i in range(steps)]


def _star(points, outer, inner):
    out = []
    for index in range(points * 2):
        angle = -math.pi / 2 + index * math.pi / points
        r = outer if index % 2 == 0 else inner
        out.append((CX + math.cos(angle) * r, CY + math.sin(angle) * r))
    return out


def _drop(width, height, steps=64):
    """A seal-stone drop: round at the top, tapering to a point at the bottom.

    The first version parametrised it by angle and came out a kidney. Half-width against height is the
    only parametrisation that gives a symmetric drop with one point.
    """
    left = []
    for index in range(steps + 1):
        t = index / steps
        y = -1.0 + 2.0 * t
        half = math.sqrt(max(0.0, 1.0 - y * y)) * (1.0 - 0.42 * max(0.0, y) ** 1.35)
        left.append((CX - half * width, CY + y * height))
    right = [(2 * CX - x, y) for x, y in reversed(left)]
    return left + right


def _cushion(radius):
    """A rounded square with twelve corners — a cushion cut, not a circle and not a plain box."""
    points = []
    corners = [(1, -1), (1, 1), (-1, 1), (-1, -1)]
    for index, (sx, sy) in enumerate(corners):
        base = -math.pi / 4 + index * math.pi / 2
        for step in (-0.20, 0.0, 0.20):
            angle = base + step
            points.append((CX + math.cos(angle) * radius, CY + math.sin(angle) * radius))
    return points


def _hexagon(radius):
    return [(CX + math.cos(-math.pi / 2 + index * math.pi / 3) * radius,
             CY + math.sin(-math.pi / 2 + index * math.pi / 3) * radius) for index in range(6)]


def _emerald(width, height, cut):
    """An emerald cut: a tall rectangle with its corners clipped and no curve anywhere."""
    hw, hh = width * 0.5, height * 0.5
    return [(CX - hw + cut, CY - hh), (CX + hw - cut, CY - hh), (CX + hw, CY - hh + cut),
            (CX + hw, CY + hh - cut), (CX + hw - cut, CY + hh), (CX - hw + cut, CY + hh),
            (CX - hw, CY + hh - cut), (CX - hw, CY - hh + cut)]


def _octagon(radius):
    return [(CX + math.cos(math.pi / 8 + i * math.pi / 4) * radius,
             CY + math.sin(math.pi / 8 + i * math.pi / 4) * radius) for i in range(8)]


def _polygon_area(points):
    total = 0.0
    for index in range(len(points)):
        x0, y0 = points[index]
        x1, y1 = points[(index + 1) % len(points)]
        total += x0 * y1 - x1 * y0
    return abs(total) * 0.5


def _balance(points, target_area, max_extent):
    """Give every silhouette the same visual weight, and keep it inside the plate.

    A square inscribed in the same radius as a circle has two thirds of its area, so the cut stones read
    smaller than the round ones and the board looks like it holds two different sizes of piece.
    """
    area = _polygon_area(points)
    factor = math.sqrt(target_area / area) if area > 1.0 else 1.0
    balanced = scale_points(points, factor)
    xs = [x for x, _ in balanced]
    ys = [y for _, y in balanced]
    extent = max(max(xs) - min(xs), max(ys) - min(ys))
    if extent > max_extent:
        balanced = scale_points(balanced, max_extent / extent)
    return balanced


def silhouette(spec):
    radius = SIZE * 0.45
    shape = spec["shape"]
    if shape == "round":
        return _balance(_circle(radius), math.pi * radius * radius * 0.98, SIZE * 0.90)
    if shape == "cushion":
        return _balance(_cushion(radius), math.pi * radius * radius * 0.98, SIZE * 0.90)
    if shape == "hexagon":
        return _balance(_hexagon(radius), math.pi * radius * radius * 0.98, SIZE * 0.90)
    if shape == "emerald":
        return _balance(_emerald(radius * 1.16, radius * 1.92, radius * 0.24),
                        math.pi * radius * radius * 0.98, SIZE * 0.90)
    if shape == "drop":
        return _balance(_drop(radius * 0.78, radius * 1.12), math.pi * radius * radius * 0.98, SIZE * 0.90)
    return _balance(_octagon(radius), math.pi * radius * radius * 0.98, SIZE * 0.90)


def scale_points(points, factor, centre=(CX, CY)):
    return [(centre[0] + (x - centre[0]) * factor, centre[1] + (y - centre[1]) * factor)
            for x, y in points]


def mask_of(points):
    mask = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    ImageDraw.Draw(mask).polygon([(x * SS, y * SS) for x, y in points], fill=255)
    return mask


def clip_to(layer, mask):
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.paste(layer, (0, 0), mask)
    return out


# ---- shading ------------------------------------------------------------------------------------


def _grid():
    size = SIZE * SS
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    dx = (xx - CX * SS) / (SIZE * 0.5 * SS)
    dy = (yy - CY * SS) / (SIZE * 0.5 * SS)
    return dx, dy


def _light(xx=None):
    lx, ly, lz = -0.42, -0.56, 0.72
    length = math.sqrt(lx * lx + ly * ly + lz * lz)
    return lx / length, ly / length, lz / length


def _to_image(rgb):
    rgb = np.clip(rgb, 0.0, 255.0).astype(np.uint8)
    alpha = np.full(rgb.shape[:2], 255, dtype=np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def cabochon(spec, radius):
    """A domed stone: deep in the middle, glowing at the girdle, one tight specular."""
    dx, dy = _grid()
    r2 = np.clip(dx * dx + dy * dy, 0.0, 1.0)
    r = np.sqrt(r2)
    z = (1.0 - r2) ** 0.55
    nx, ny, nz = dx, dy, z * 0.9
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length

    lx, ly, lz = _light()
    diffuse = np.clip(nx * lx + ny * ly + nz * lz, 0.0, 1.0)

    hx, hy, hz = lx, ly, lz + 1.0
    hn = math.sqrt(hx * hx + hy * hy + hz * hz)
    hx, hy, hz = hx / hn, hy / hn, hz / hn
    spec_amount = np.clip(nx * hx + ny * hy + nz * hz, 0.0, 1.0) ** 40.0
    spec_wide = np.clip(nx * hx + ny * hy + nz * hz, 0.0, 1.0) ** 6.0

    body = np.array(spec["body"], dtype=np.float32)
    deep = np.array(spec["deep"], dtype=np.float32)
    light = np.array(spec["light"], dtype=np.float32)

    # Colour: deep where the surface faces the viewer, lighter where it turns away from the middle.
    turn = np.clip((r - 0.25) / 0.80, 0.0, 1.0)[:, :, None]
    colour = deep * (1.0 - turn) + body * turn
    colour = colour + (light - colour) * (0.30 * diffuse[:, :, None])
    rgb = colour + 255.0 * (0.55 * spec_wide + 0.85 * spec_amount)[:, :, None]
    return _to_image(rgb)


def faceted(spec, points, bevel=0.16):
    """A flat stone with a bevel along each edge: bright where the edge faces the light."""
    body = np.array(spec["body"], dtype=np.float32)
    deep = np.array(spec["deep"], dtype=np.float32)
    light = np.array(spec["light"], dtype=np.float32)

    # Base: a flat plate with a hair of falloff towards its edge — not a dome. Scaling the radius by the
    # stone's own size matters: normalised against the whole canvas the middle of the plate came out as
    # the deep colour and the star looked like a hole in the board.
    dx, dy = _grid()
    r = np.clip(np.sqrt(dx * dx + dy * dy) / 0.46, 0.0, 1.0)
    base = body[None, None, :] * (1.02 - 0.16 * (r ** 2))[:, :, None]
    base = base + (light - body)[None, None, :] * (0.10 * (1.0 - r) ** 2)[:, :, None]
    canvas = _to_image(base)

    lx, ly, _ = _light()
    inset = scale_points(points, 1.0 - bevel)
    count = len(points)
    for index in range(count):
        a = points[index]
        b = points[(index + 1) % count]
        a_in = inset[index]
        b_in = inset[(index + 1) % count]
        quad = [a, b, b_in, a_in]
        mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        nx, ny = mid[0] - CX, mid[1] - CY
        length = max(1e-6, math.hypot(nx, ny))
        facing = (nx / length) * lx + (ny / length) * ly
        if facing > 0.0:
            blend = 0.10 + 0.34 * facing
            colour = body * (1.0 - blend) + light * blend
        else:
            colour = body * (1.0 + facing * 0.45)
        facet = Image.new("RGBA", (SIZE * SS, SIZE * SS), tuple(int(v) for v in np.clip(colour, 0, 255)) + (255,))
        canvas.alpha_composite(_crop(facet, mask_of(quad)))
        # The crease itself, a hair darker, so the bevel reads as a cut and not as a wash.
        crease = ImageDraw.Draw(canvas)
        crease.line([(a_in[0] * SS, a_in[1] * SS), (b_in[0] * SS, b_in[1] * SS)],
                    fill=(0, 0, 0, 46), width=max(1, SS // 2))

    # Facet lines from the centre to each point of the star. A cut stone is a table with edges running
    # out to the girdle; without them the star is a shape with a bevel, not a stone.
    facet_draw = ImageDraw.Draw(canvas, "RGBA")
    if len(points) <= 8:
        # A cut stone is a table with edges running out to the girdle. Only true polygons get them: on a
        # twelve-sided cushion the fan of lines reads as a splash, not as facets.
        table = scale_points(points, 0.54)
        facet_draw.line(table + [table[0]], fill=(255, 255, 255, 46), width=max(1, SS // 2))
        for x, y in points:
            facet_draw.line([(CX * SS, CY * SS), (x * SS, y * SS)], fill=(255, 255, 255, 30),
                            width=max(1, SS // 2))
        for index in range(0, len(points), 2):
            a = points[index]
            b = points[(index + 1) % len(points)]
            wedge = [(CX, CY), a, b]
            shade_layer = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
            ImageDraw.Draw(shade_layer).polygon([(x * SS, y * SS) for x, y in wedge],
                                                fill=(255, 255, 255, 22))
            canvas.alpha_composite(_crop(shade_layer, mask_of(points)))

    # Specular: one soft pass over the upper left of the plate.
    spec_layer = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    spec_draw = ImageDraw.Draw(spec_layer)
    # Small and off-centre: a wide soft ellipse over a faceted plate reads as a cloud sitting on the
    # stone, which is what the first pass looked like on the lapis star.
    spec_draw.ellipse((CX * SS - SIZE * SS * 0.24, CY * SS - SIZE * SS * 0.30,
                       CX * SS - SIZE * SS * 0.02, CY * SS - SIZE * SS * 0.12),
                      fill=WHITE + (46,))
    # Only on the dome-cut stones: over a faceted plate a soft ellipse reads as a smudge, so those
    # keep just the sharp spark below.
    if spec["cut"] != "faceted":
        canvas.alpha_composite(clip_to(spec_layer.filter(ImageFilter.GaussianBlur(SS * 1.1)),
                                       mask_of(points)))
    spark = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    ImageDraw.Draw(spark).ellipse((CX * SS - SIZE * SS * 0.125, CY * SS - SIZE * SS * 0.170,
                                   CX * SS - SIZE * SS * 0.085, CY * SS - SIZE * SS * 0.130),
                                  fill=WHITE + (185,))
    canvas.alpha_composite(clip_to(spark.filter(ImageFilter.GaussianBlur(SS * 0.5)), mask_of(points)))
    return canvas


def sphere(spec):
    dx, dy = _grid()
    r2 = np.clip(dx * dx + dy * dy, 0.0, 1.0)
    z = np.sqrt(np.clip(1.0 - r2, 0.0, 1.0))
    nx, ny, nz = dx, dy, z
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length
    lx, ly, lz = _light()
    diffuse = np.clip(nx * lx + ny * ly + nz * lz, 0.0, 1.0)
    hx, hy, hz = lx, ly, lz + 1.0
    hn = math.sqrt(hx * hx + hy * hy + hz * hz)
    spec_amount = np.clip(nx * (hx / hn) + ny * (hy / hn) + nz * (hz / hn), 0.0, 1.0) ** 90.0
    body = np.array(spec["body"], dtype=np.float32)
    deep = np.array(spec["deep"], dtype=np.float32)
    rgb = body * (0.45 + 0.70 * diffuse)[:, :, None] + deep * (0.55 * (1.0 - diffuse))[:, :, None]
    rgb = rgb + 255.0 * (0.85 * spec_amount)[:, :, None]
    return _to_image(rgb)


def _crop(layer, mask):
    return clip_to(layer, mask)


# ---- the stone ----------------------------------------------------------------------------------


def build(name):
    spec = GEMS[name]
    points = silhouette(spec)
    canvas = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))

    # 0. A shadow: the stone sits in a tray, it does not float over it.
    shadow = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon(
        [(x * SS, y * SS + SIZE * SS * 0.028) for x, y in points], fill=(0, 0, 0, 110))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(SS * 2.6)))

    # 1. The setting: gold, lit from the upper left, only as wide as it needs to be.
    setting = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    setting_draw = ImageDraw.Draw(setting)
    setting_draw.polygon([(x * SS, y * SS) for x, y in points], fill=GOLD + (255,))
    gold_light = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    ImageDraw.Draw(gold_light).polygon(
        [(x * SS, y * SS) for x, y in points], fill=GOLD_LIGHT + (255,))
    grad = Image.linear_gradient("L").resize((SIZE * SS, SIZE * SS))
    grad = grad.point(lambda v: int(255 * (v / 255.0) ** 0.9))
    setting = Image.composite(setting, gold_light, grad.rotate(-35, expand=False))
    setting.putalpha(mask_of(points))
    canvas.alpha_composite(setting)

    # 2. The stone, inset by the width of the setting. A star needs a wider band than a round stone:
    # at 0.955 the gold disappears into the points, and the lapis looked loose in the tray next to the
    # other four, which all sit in a visible ring.
    inset_factor = 0.905 if spec["shape"] == "star8" else 0.955
    stone_points = scale_points(points, inset_factor)
    stone_mask = mask_of(stone_points)
    if spec["cut"] == "cabochon":
        stone = cabochon(spec, SIZE * 0.5)
    elif spec["cut"] == "sphere":
        stone = sphere(spec)
    else:
        stone = faceted(spec, stone_points)
    canvas.alpha_composite(clip_to(stone, stone_mask))

    # 3. A dark seam where the stone meets the setting, so the gold does not look pasted on.
    seam = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    ImageDraw.Draw(seam).polygon([(x * SS, y * SS) for x, y in stone_points],
                                 outline=120, width=SS)
    canvas.paste(Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 255)), (0, 0),
                 seam.filter(ImageFilter.GaussianBlur(SS * 0.4)))

    # 4. A hard specular dot on the lit shoulder: the one thing every glossy mineral shows.
    dot = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    ImageDraw.Draw(dot).ellipse((CX * SS - SIZE * SS * 0.105, CY * SS - SIZE * SS * 0.125,
                                 CX * SS + SIZE * SS * 0.030, CY * SS - SIZE * SS * 0.045),
                                fill=WHITE + (170,))
    dot = dot.rotate(-32, resample=Image.BICUBIC, center=(CX * SS, CY * SS))
    canvas.alpha_composite(clip_to(dot.filter(ImageFilter.GaussianBlur(SS * 1.6)), stone_mask))

    # 5. An outline around the whole setting, so the stone separates from any background.
    edge = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    ImageDraw.Draw(edge).polygon([(x * SS, y * SS) for x, y in points],
                                 outline=(6, 10, 18, 120), width=SS)
    canvas.alpha_composite(edge)

    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in GEMS:
        image = build(name)
        image.save(os.path.join(OUT, "piece_%s.png" % name), optimize=True)
        print("piece_%s.png %dx%d" % (name, image.width, image.height))


if __name__ == "__main__":
    main()
