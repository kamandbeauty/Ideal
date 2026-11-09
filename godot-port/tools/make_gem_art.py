#!/usr/bin/env python3
"""Draws the five board gems (and their bevels) as pictures.

Why this file exists: the ported Unity sprites are honest but flat — a coloured polygon with a gold
outline and one white dot, which at 36 dp on a phone reads as "no graphics at all". The port's rule is
that nothing is drawn at runtime, so the upgrade has to happen here: the same five gems are re-cut as
pictures with a real bezel, crown facets, a table, a specular and a sparkle, and shipped as PNGs.

Every gem is built the way a lapidary would describe one, because that is what the eye is checking:

  silhouette   the outer shape of the stone, one per colour, so the board is readable by shape too
  bezel        the gold ring holding the stone, with light on its upper-left and shadow lower-right
  crown        a ring of facets between the bezel and the table, each shaded by the angle of its
               face to a fixed light above and left of the board
  table        the flat top in the middle, with a radial falloff instead of a flat fill
  specular     a soft highlight over the upper-left, and a small four-point sparkle

Deterministic, and drawn at 4x then resampled, so the facets stay crisp at any tile size.

    python3 godot-port/tools/make_gem_art.py
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "gems")
SIZE = 160
SS = 4
CX = CY = SIZE * 0.5

GOLD = (214, 163, 74)
GOLD_LIGHT = (250, 219, 150)
GOLD_DARK = (128, 82, 20)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

# Silhouette, body colour and accent for each stone. The shapes are deliberately different — a
# matching board is scanned by shape first and colour second.
GEMS = {
    "firouzeh": dict(shape="star8", body=(52, 186, 178), accent=(168, 246, 232), points=8, rot=0.0),
    "lajvard": dict(shape="ngon", body=(62, 104, 196), accent=(168, 198, 255), points=6, rot=math.pi / 2),
    "aqiq": dict(shape="kite", body=(196, 72, 62), accent=(255, 176, 160), points=6, rot=0.0),
    "zomorrod": dict(shape="ngon", body=(44, 152, 98), accent=(158, 240, 190), points=8,
                     rot=math.pi / 8),
    "morvarid": dict(shape="round", body=(232, 220, 198), accent=(255, 252, 242), points=32, rot=0.0),
}


# ---- helpers ------------------------------------------------------------------------------------


def _scale(colour, factor):
    return tuple(max(0, min(255, int(round(channel * factor)))) for channel in colour)


def _mask(points):
    mask = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    ImageDraw.Draw(mask).polygon([(x * SS, y * SS) for x, y in points], fill=255)
    return mask


def _down(mask):
    return mask.resize((SIZE, SIZE), Image.LANCZOS)


def _ring_mask(outer_mask, inner_mask):
    return ImageChops.subtract(outer_mask, inner_mask)


def _gradient_fill(mask, top, bottom):
    """A vertical two-stop gradient clipped to `mask` (already at supersample size)."""
    column = Image.new("RGBA", (1, SIZE * SS))
    for y in range(SIZE * SS):
        t = y / max(1, SIZE * SS - 1)
        colour = tuple(int(round(top[c] + (bottom[c] - top[c]) * t)) for c in range(3))
        column.putpixel((0, y), colour + (255,))
    body = column.resize((SIZE * SS, SIZE * SS), Image.NEAREST)
    shape = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    shape.paste(body, (0, 0), mask)
    return shape


def _solid_fill(mask, colour):
    shape = Image.new("RGBA", (SIZE * SS, SIZE * SS), tuple(colour) + (255,))
    out = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    out.paste(shape, (0, 0), mask)
    return out


def _radial(colour, centre, radius, inner_factor=1.55, outer_factor=0.72):
    """A round falloff painted onto the canvas, used for the table and for pearls."""
    layer = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    steps = 96
    for index in range(steps, 0, -1):
        t = index / steps
        factor = outer_factor + (inner_factor - outer_factor) * (1.0 - t) ** 1.5
        r = radius * t
        draw.ellipse((centre[0] - r, centre[1] - r, centre[0] + r, centre[1] + r),
                     fill=_scale(colour, factor) + (255,))
    return layer.filter(ImageFilter.GaussianBlur(SS * 0.8))


def rotate(points, angle, centre=(CX, CY)):
    cos_a, sin_a = math.cos(angle), math.sin(angle)
    out = []
    for x, y in points:
        dx, dy = x - centre[0], y - centre[1]
        out.append((centre[0] + dx * cos_a - dy * sin_a, centre[1] + dx * sin_a + dy * cos_a))
    return out


def scale_points(points, factor, centre=(CX, CY)):
    return [(centre[0] + (x - centre[0]) * factor, centre[1] + (y - centre[1]) * factor)
            for x, y in points]


def silhouette(kind):
    radius = SIZE * 0.5
    if kind == "round":
        return [(CX + math.cos(a) * radius * 0.98, CY + math.sin(a) * radius * 0.98)
                for a in [i * 2 * math.pi / 48 for i in range(48)]]
    if kind == "star8":
        points = []
        for index in range(16):
            angle = index * math.pi / 8 - math.pi / 2
            r = radius * (0.99 if index % 2 == 0 else 0.74)
            points.append((CX + math.cos(angle) * r, CY + math.sin(angle) * r))
        return points
    if kind == "kite":
        # A carnelian cabochon: hexagonal, taller than wide, with a decided point at the bottom.
        template = [(0.0, -1.0), (0.86, -0.34), (0.62, 0.62), (0.0, 1.0), (-0.62, 0.62), (-0.86, -0.34)]
        return [(CX + x * radius * 0.95, CY + y * radius * 1.02) for x, y in template]
    count = 6
    return [(CX + math.cos(-math.pi / 2 + i * 2 * math.pi / count) * radius * 0.98,
             CY + math.sin(-math.pi / 2 + i * 2 * math.pi / count) * radius * 0.98)
            for i in range(count)]


# ---- the gem ------------------------------------------------------------------------------------


def build(name):
    spec = GEMS[name]
    body, accent = spec["body"], spec["accent"]
    outer = silhouette(spec["shape"])
    if spec["rot"]:
        outer = rotate(outer, spec["rot"])

    canvas = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))

    # 1. The bezel: solid gold, lit from the upper left, and the silhouette's own dark edge so the
    #    stone keeps a crisp outline against a dark tile.
    outer_mask = _mask(outer)
    bezel = _gradient_fill(outer_mask, _scale(GOLD_LIGHT, 1.0), GOLD_DARK)
    canvas.alpha_composite(bezel)

    # 2. The stone, inset far enough that the ring reads as metal and not as an outline.
    cut = scale_points(outer, 0.855)
    cut_mask = _mask(cut)
    canvas.alpha_composite(_gradient_fill(cut_mask, _scale(body, 1.22), _scale(body, 0.66)))

    # A dark seam where stone meets bezel: without it the gold looks pasted on.
    seam = _down(_ring_mask(cut_mask, _mask(scale_points(outer, 0.825)))).point(lambda v: int(v * 0.55))
    canvas.paste(Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255)), (0, 0), seam)

    # 3. Crown facets: quads from the girdle to the table, each shaded by how far its face turns
    #    away from the light. The light sits above and to the left.
    light = (-0.62, -0.78)
    table = scale_points(cut, 0.60)
    count = len(cut)
    for index in range(count if spec["shape"] != "round" else 0):
        quad = [cut[index], cut[(index + 1) % count], table[(index + 1) % count], table[index]]
        mid = ((quad[0][0] + quad[1][0]) * 0.5, (quad[0][1] + quad[1][1]) * 0.5)
        nx, ny = mid[0] - CX, mid[1] - CY
        length = max(1e-6, math.hypot(nx, ny))
        facing = (nx / length) * light[0] + (ny / length) * light[1]
        factor = 0.92 + 0.30 * facing
        facet = Image.new("RGBA", (SIZE * SS, SIZE * SS), _scale(body, factor) + (255,))
        canvas.alpha_composite(_clip(facet, _mask(quad)))

    if spec["shape"] != "round":
        # Facet seams: a hairline along each girdle-to-table edge, brightest on the lit side.
        seam_layer = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
        seam_draw = ImageDraw.Draw(seam_layer)
        for index in range(count):
            a = cut[index]
            b = table[index]
            seam_draw.line([(a[0] * SS, a[1] * SS), (b[0] * SS, b[1] * SS)],
                           fill=(255, 255, 255, 46), width=max(1, SS // 2))
        canvas.alpha_composite(_clip(seam_layer, cut_mask))

        # 4. The table: a radial falloff, plus its own bright edge where it meets the crown.
        table_image = _radial(body, (CX - SIZE * 0.06, CY - SIZE * 0.08), SIZE * 0.42,
                              inner_factor=1.62, outer_factor=0.94)
        canvas.alpha_composite(_clip(table_image, _mask(table)))
        table_edge = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
        ImageDraw.Draw(table_edge).polygon([(x * SS, y * SS) for x, y in table],
                                           outline=(255, 255, 255, 70), width=SS)
        canvas.alpha_composite(_clip(table_edge, _mask(table)))

    if spec["shape"] == "round":
        # A pearl is a cabochon, not a cut stone: a smooth dome, one broad specular, no facets.
        dome = _radial(body, (CX - SIZE * 0.10, CY - SIZE * 0.12), SIZE * 0.52,
                       inner_factor=1.26, outer_factor=0.58)
        canvas.alpha_composite(_clip(dome, cut_mask))

    # 5. Specular: a soft highlight over the upper-left of the table and a four-point sparkle.
    spec_img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    spec_draw = ImageDraw.Draw(spec_img)
    spec_draw.ellipse((CX - SIZE * 0.30, CY - SIZE * 0.34, CX + SIZE * 0.02, CY - SIZE * 0.06),
                      fill=WHITE + (110,))
    spec_img = spec_img.filter(ImageFilter.GaussianBlur(SIZE * 0.05 * SS))
    canvas.alpha_composite(_clip(spec_img, cut_mask))

    sparkle = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    sparkle_draw = ImageDraw.Draw(sparkle)
    sx, sy = CX - SIZE * 0.20, CY - SIZE * 0.22
    long_r, short_r = SIZE * 0.075 * SS, SIZE * 0.020 * SS
    sparkle_draw.polygon([(sx * SS, sy * SS - long_r), (sx * SS + short_r, sy * SS),
                          (sx * SS, sy * SS + long_r), (sx * SS - short_r, sy * SS)],
                         fill=WHITE + (235,))
    sparkle_draw.polygon([(sx * SS - long_r, sy * SS), (sx * SS, sy * SS + short_r),
                          (sx * SS + long_r, sy * SS), (sx * SS, sy * SS - short_r)],
                         fill=WHITE + (215,))
    sparkle = sparkle.filter(ImageFilter.GaussianBlur(SS * 0.35))
    canvas.alpha_composite(sparkle)

    # 6. A gold glint along the lit half of the bezel, so the ring has a direction.
    glint = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    glint_draw = ImageDraw.Draw(glint)
    glint_draw.arc((0, 0, SIZE * SS - 1, SIZE * SS - 1), start=186, end=318,
                   fill=_scale(accent, 1.05) + (190,), width=int(SS * 1.6))
    canvas.alpha_composite(_clip(glint, _ring_mask(outer_mask, _mask(scale_points(outer, 0.90)))))

    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def _clip(layer, mask):
    """Crops `layer` to `mask` and returns it transparent everywhere else."""
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.paste(layer, (0, 0), mask)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in GEMS:
        image = build(name)
        image.save(os.path.join(OUT, "piece_%s.png" % name), optimize=True)
        print("piece_%s.png %dx%d" % (name, image.width, image.height))


if __name__ == "__main__":
    main()
