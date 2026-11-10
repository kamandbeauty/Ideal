#!/usr/bin/env python3
"""Draws the app's identity: the launcher icon, its adaptive layers, and the store icon.

The icon is the first picture anyone sees of this game, and until now it was a placeholder — a flat
arch with a gold border so thick it read as a picture frame. This draws it properly and from the same
palette as everything else: lapis, gold, turquoise.

The composition is one idea, because an icon is read at 48 dp before it is read at all:

    a pointed arch, in gold, standing for the palace
    a turquoise cabochon set in that arch, standing for the game
    a lattice of eight-point stars behind it, standing for the tilework of the place
    a finial and a crescent above, so the silhouette is a building and not a window

Three files come out of it, and they are not the same picture:

    icon_1024 / icon_512 / icon_192 / icon_128   the legacy icon, in a rounded square
    icon_foreground_432                          art only, inside the 66% safe circle, transparent
    icon_background_432                          the lapis ground on its own, full bleed

Android masks an adaptive icon and animates it; a legacy icon baked with rounded corners inside an
adaptive slot gets cropped twice, which is exactly what the old placeholder did.

    python3 godot-port/tools/make_brand_art.py
"""

from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "branding")
MASTER = 1024

LAPIS_DARK = (7, 20, 46)
LAPIS = (16, 40, 84)
LAPIS_LIGHT = (30, 64, 120)
GOLD_DARK = (124, 80, 20)
GOLD = (198, 150, 64)
GOLD_LIGHT = (250, 224, 156)
TURQUOISE = (36, 174, 164)
TURQUOISE_DEEP = (12, 96, 96)
TURQUOISE_LIGHT = (176, 248, 240)
WHITE = (255, 255, 255)


def _mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def _radial_ground(size, inner=(16, 40, 84), outer=(7, 20, 46), centre=(0.5, 0.46), radius=0.72):
    """A soft light falling from behind the crest onto a deep lapis field."""
    x0, y0 = int(centre[0] * size), int(centre[1] * size)
    reach = int(radius * size)
    layer = Image.new("RGBA", (size, size), outer + (255,))
    glow = Image.new("RGBA", (reach * 2, reach * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    steps = 42
    for index in range(steps, 0, -1):
        t = index / steps
        colour = _mix(inner, outer, t ** 0.85)
        r = int(reach * t)
        draw.ellipse((reach - r, reach - r, reach + r, reach + r), fill=colour + (255,))
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.03))
    layer.alpha_composite(glow, (x0 - reach, y0 - reach))
    return layer


def _lattice(size, step_ratio=0.085, alpha=26):
    """The eight-point star lattice of a tiled wall, quiet enough to sit behind the arch."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    step = int(size * step_ratio)
    half = step * 0.30
    for row in range(-1, int(size / step) + 2):
        for col in range(-1, int(size / step) + 2):
            cx = col * step + (step * 0.5 if row % 2 else 0.0)
            cy = row * step * 0.86
            draw.polygon([(cx, cy - half), (cx + half * 0.42, cy - half * 0.42),
                          (cx + half, cy), (cx + half * 0.42, cy + half * 0.42),
                          (cx, cy + half), (cx - half * 0.42, cy + half * 0.42),
                          (cx - half, cy), (cx - half * 0.42, cy - half * 0.42)],
                         outline=GOLD + (alpha,), width=max(1, int(size * 0.0035)))
    return layer


def _cabochon(size, body, deep, light, specular=1.0):
    """A domed stone with a tight specular — the same recipe the board's gems use."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    half = size * 0.5
    dx = (xx - half) / half
    dy = (yy - half) / half
    r2 = np.clip(dx * dx + dy * dy, 0.0, 1.0)
    r = np.sqrt(r2)
    z = (1.0 - r2) ** 0.55
    nx, ny, nz = dx, dy, z * 0.9
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length

    lx, ly, lz = -0.42, -0.56, 0.72
    ln = math.sqrt(lx * lx + ly * ly + lz * lz)
    lx, ly, lz = lx / ln, ly / ln, lz / ln
    diffuse = np.clip(nx * lx + ny * ly + nz * lz, 0.0, 1.0)

    hx, hy, hz = lx, ly, lz + 1.0
    hn = math.sqrt(hx * hx + hy * hy + hz * hz)
    hx, hy, hz = hx / hn, hy / hn, hz / hn
    facing = np.clip(nx * hx + ny * hy + nz * hz, 0.0, 1.0)
    tight = facing ** 48.0
    wide = facing ** 6.0

    body_c = np.array(body, dtype=np.float32)
    deep_c = np.array(deep, dtype=np.float32)
    light_c = np.array(light, dtype=np.float32)
    turn = np.clip((r - 0.22) / 0.80, 0.0, 1.0)[:, :, None]
    colour = deep_c * (1.0 - turn) + body_c * turn
    colour = colour + (light_c - colour) * (0.28 * diffuse[:, :, None])
    rgb = colour + 255.0 * (0.50 * wide + 0.85 * specular * tight)[:, :, None]
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    alpha = (np.clip(1.0 - (r - 0.985) / 0.015, 0.0, 1.0) * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def _arch_points(cx, base_y, width, height, steps=48):
    """A pointed arch: two curves from the springing line to an apex."""
    x0, x1 = cx - width * 0.5, cx + width * 0.5
    apex = (cx, base_y - height)
    left = []
    control = (x0 + width * 0.06, base_y - height * 0.86)
    for index in range(steps + 1):
        t = index / steps
        x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * control[0] + t * t * apex[0]
        y = (1 - t) ** 2 * base_y + 2 * (1 - t) * t * control[1] + t * t * apex[1]
        left.append((x, y))
    right = [(2 * cx - x, y) for x, y in reversed(left)]
    return left + right


def _gem_in_setting(diameter):
    """A turquoise cabochon inside a thin gold ring, with a dark seam between them."""
    stone = _cabochon(int(diameter * 1.06), TURQUOISE, TURQUOISE_DEEP, TURQUOISE_LIGHT)
    size = stone.size[0]
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    inset = size * 0.035
    draw.ellipse((inset, inset, size - inset, size - inset), fill=GOLD + (255,))
    draw.ellipse((inset * 1.5, inset * 1.5, size - inset * 1.5, size - inset * 1.5),
                 fill=GOLD_LIGHT + (255,))
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ring_draw = ImageDraw.Draw(ring)
    ring_draw.ellipse((inset, inset, size - inset, size - inset), fill=GOLD + (255,))
    stroke_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(stroke_mask).ellipse((inset, inset, size - inset, size - inset),
                                        outline=255, width=int(size * 0.055))
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(_gold_ring(size, inset))
    stone_size = int(size * 0.90)
    stone = stone.resize((stone_size, stone_size), Image.LANCZOS)
    canvas.alpha_composite(stone, (int((size - stone_size) * 0.5), int((size - stone_size) * 0.5)))
    seam = Image.new("L", (size, size), 0)
    ImageDraw.Draw(seam).ellipse((inset + size * 0.052, inset + size * 0.052,
                                 size - inset - size * 0.052, size - inset - size * 0.052),
                                outline=150, width=max(1, int(size * 0.006)))
    canvas.paste(Image.new("RGBA", (size, size), (0, 0, 0, 255)), (0, 0),
                 seam.filter(ImageFilter.GaussianBlur(size * 0.004)))
    return canvas


def _gold_ring(size, inset):
    """A gold ring lit from the upper left: bright arc up there, dark metal down there."""
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(ring)
    width = int(size * 0.055)
    draw.ellipse((inset, inset, size - inset, size - inset), fill=GOLD_DARK + (255,))
    draw.ellipse((inset + width * 0.35, inset + width * 0.35,
                  size - inset - width * 0.35, size - inset - width * 0.35), fill=GOLD + (255,))
    draw.arc((inset, inset, size - inset, size - inset), start=170, end=330,
             fill=GOLD_LIGHT + (255,), width=max(2, int(width * 0.55)))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((inset, inset, size - inset, size - inset), outline=255,
                                 width=width)
    inner = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner.paste(ring, (0, 0), mask)
    return inner


def _pavilion_layer(size):
    """The arch, its finial and its crescent — the part that says 'palace' and not 'shape'.

    The arch has straight jambs and curves only from the springing line. Drawing the curve all the way
    to the floor makes a tent, which is what the first version looked like. The moulding is three
    offset strokes rather than one flat band: a single gold fill reads as a sticker at icon sizes.
    """
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx = size * 0.5
    base = size * 0.840
    width = size * 0.46
    band = size * 0.052
    arch_height = size * 0.40
    spring = base - size * 0.145

    def contour(offset_x=0.0, offset_y=0.0, inset=0.0):
        w = width - inset * 2.0
        left = [(cx - w * 0.5, base), (cx - w * 0.5, spring)]
        curve = _arch_points(cx, spring, w, arch_height - inset)
        right = [(cx + w * 0.5, spring + 1.0), (cx + w * 0.5, base)]
        points = left + curve + right
        return [(x + offset_x, y + offset_y) for x, y in points]

    # The niche behind the moulding: floor light at the bottom, night sky at the top.
    niche = contour(inset=band * 0.55)
    draw.polygon(niche, fill=LAPIS_DARK + (255,))
    glow = _radial_ground(size, inner=(24, 78, 86), outer=(8, 22, 40), centre=(0.5, 0.76), radius=0.30)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).polygon(niche, fill=235)
    glow.putalpha(ImageChops.multiply(glow.getchannel("A"), mask))
    layer.alpha_composite(glow)

    # The moulding, layered: shadow, body, light, inner hairline.
    wide = max(2, int(band))
    draw.line(contour(0, size * 0.006), fill=GOLD_DARK + (255,), width=wide, joint="curve")
    draw.line(contour(), fill=GOLD + (255,), width=max(2, int(band * 0.86)), joint="curve")
    draw.line(contour(-size * 0.004, -size * 0.004), fill=GOLD_LIGHT + (235,),
              width=max(2, int(band * 0.34)), joint="curve")
    draw.line(contour(inset=band * 0.05), fill=_mix(GOLD_DARK, GOLD, 0.4) + (255,),
              width=max(1, int(band * 0.10)), joint="curve")

    # A sill under the opening, so the niche stands on the floor instead of floating.
    sill = (cx - width * 0.62, base, cx + width * 0.62, base + size * 0.030)
    draw.rounded_rectangle(sill, radius=int(size * 0.010), fill=GOLD + (255,))
    draw.rounded_rectangle((sill[0], sill[1], sill[2], sill[1] + size * 0.010),
                            radius=int(size * 0.005), fill=GOLD_LIGHT + (220,))

    # Finial: a small drum under a spike, the way a Persian pavilion is capped.
    apex = spring - arch_height
    spike_top = apex - size * 0.085
    draw.line((cx, apex - size * 0.010, cx, spike_top + size * 0.014),
              fill=GOLD_LIGHT + (240,), width=max(2, int(size * 0.0075)))
    draw.ellipse((cx - size * 0.016, spike_top - size * 0.004, cx + size * 0.016, spike_top + size * 0.028),
                 fill=GOLD + (255,))
    draw.ellipse((cx - size * 0.008, spike_top - size * 0.021, cx + size * 0.008, spike_top - size * 0.005),
                 fill=GOLD_LIGHT + (250,))

    # Crescent inside the sky of the niche, small enough to stay a moon.
    # The crescent is punched out of its own layer: filling the bite with the backdrop colour leaves a
    # dark disc pasted over the niche glow, which is exactly how the first pass looked.
    moon = size * 0.030
    moon_x, moon_y = cx + width * 0.17, apex + size * 0.070
    disc = Image.new("RGBA", (int(moon * 4), int(moon * 4)), (0, 0, 0, 0))
    disc_draw = ImageDraw.Draw(disc)
    disc_draw.ellipse((moon * 0.8, moon * 0.8, moon * 2.8, moon * 2.8), fill=GOLD_LIGHT + (225,))
    disc_draw.ellipse((moon * 1.45, moon * 0.45, moon * 3.45, moon * 2.45), fill=(0, 0, 0, 0))
    layer.alpha_composite(disc, (int(moon_x - moon * 2), int(moon_y - moon * 2)))
    return layer


def build_master(with_frame=True):
    image = _radial_ground(MASTER)
    image.alpha_composite(_lattice(MASTER))
    image.alpha_composite(_pavilion_layer(MASTER))

    # The stone sits inside the arch, not on top of it: an icon where the gem covers the apex reads as
    # a ball on a hill, which is what the first attempt looked like.
    gem_size = int(MASTER * 0.225)
    gem = _gem_in_setting(gem_size)
    image.alpha_composite(gem, (int(MASTER * 0.5 - gem_size * 0.5), int(MASTER * 0.615 - gem_size * 0.5)))

    if with_frame:
        # A thin gold frame. The old icon's frame was a quarter of the width, which turned the icon
        # into a picture of a picture frame.
        frame = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        inset = int(MASTER * 0.035)
        draw.rounded_rectangle((inset, inset, MASTER - inset, MASTER - inset),
                               radius=int(MASTER * 0.20), outline=GOLD + (230,),
                               width=int(MASTER * 0.012))
        image.alpha_composite(frame)
    return image


def main():
    os.makedirs(OUT, exist_ok=True)

    master = build_master(with_frame=True)
    for name, size in [("icon_1024", 1024), ("icon_512", 512), ("icon_192", 192), ("icon_128", 128)]:
        master.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + ".png"), optimize=True)
        print("%-18s %dx%d" % (name + ".png", size, size))

    # The adaptive layers. The foreground must live inside the 66% safe circle: Android crops and
    # animates the outer ring, so anything drawn there is thrown away or distorted.
    foreground = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    inner = build_master(with_frame=False)
    scaled = inner.resize((int(MASTER * 0.66), int(MASTER * 0.66)), Image.LANCZOS)
    foreground.alpha_composite(scaled, (int(MASTER * 0.17), int(MASTER * 0.17)))
    foreground.resize((432, 432), Image.LANCZOS).save(
        os.path.join(OUT, "icon_foreground_432.png"), optimize=True)
    print("%-18s %dx%d" % ("icon_foreground_432.png", 432, 432))

    background = _radial_ground(MASTER)
    background.alpha_composite(_lattice(MASTER, step_ratio=0.12, alpha=20))
    background.resize((432, 432), Image.LANCZOS).save(
        os.path.join(OUT, "icon_background_432.png"), optimize=True)
    print("%-18s %dx%d" % ("icon_background_432.png", 432, 432))


if __name__ == "__main__":
    main()
