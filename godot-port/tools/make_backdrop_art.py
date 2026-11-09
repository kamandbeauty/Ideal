#!/usr/bin/env python3
"""Draws the five screen backdrops — the courtyard the game is set in — as pictures.

Why a generator and not a photograph or a paint file: the port may not ship anything but its own art,
and the same rule that made the panels PNGs applies to the thing behind them. A backdrop is not a flat
fill with a pattern on it, so this one is built in layers, the way a stage set is:

  sky        a vertical gradient, deep at the top, warm at the horizon
  stars      deterministic points in the upper half
  moon       a disc with a halo, low enough to sit behind the arcade
  skyline    onion domes and minarets on the horizon, the darkest thing in the frame
  arcade     a wall of pointed arches; each opening is lit from inside by a lantern, and each edge
             carries a thin gold rim light
  terrace    the floor, receding into the haze, with a pool that reflects the moon
  trees      cypresses, only in the garden variants
  finish     vignette, a touch of grain, so it reads as a painting and not as vector art

Every screen gets its own palette and dressing from the same scene code, so the game looks like one
place rather than five unrelated backgrounds.

    python3 godot-port/tools/make_backdrop_art.py

Deterministic: fixed seeds, so the same bytes come out of every run.
"""

from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "backdrops")
# Twice the design space, so a phone at 2x has the pixels it asks for and nothing is upscaled.
W, H = 1476, 830


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def shade(colour, factor, alpha=255):
    return (max(0, min(255, int(colour[0] * factor))),
            max(0, min(255, int(colour[1] * factor))),
            max(0, min(255, int(colour[2] * factor))), alpha)


def vertical_gradient(size, stops):
    """`stops` is [(position, colour)] with position in 0..1."""
    width, height = size
    column = Image.new("RGBA", (1, height))
    stops = sorted(stops, key=lambda pair: pair[0])
    for y in range(height):
        t = y / max(1, height - 1)
        lower, upper = stops[0], stops[-1]
        for index in range(len(stops) - 1):
            if stops[index][0] <= t <= stops[index + 1][0]:
                lower, upper = stops[index], stops[index + 1]
                break
        span = max(1e-6, upper[0] - lower[0])
        colour = mix(lower[1], upper[1], (t - lower[0]) / span)
        column.putpixel((0, y), colour + (255,))
    return column.resize((width, height), Image.NEAREST)


def radial_layer(size, centre, radius, colour, strength=1.0, power=2.4):
    """A soft halo, computed once and composited once.

    Drawing semi-transparent circles from the outside in looks like a glow on paper and like a disc
    with a hard edge on screen: the copies accumulate and the middle goes opaque. One alpha ramp,
    composited once, is the only version that is actually soft.
    """
    import numpy as np

    width, height = size
    yy, xx = np.mgrid[0:height, 0:width].astype(np.float32)
    distance = np.sqrt((xx - centre[0]) ** 2 + (yy - centre[1]) ** 2) / max(1.0, radius)
    alpha = np.clip(1.0 - distance, 0.0, 1.0) ** power * strength * 255.0
    layer = np.zeros((height, width, 4), dtype=np.uint8)
    layer[..., 0], layer[..., 1], layer[..., 2] = colour[0], colour[1], colour[2]
    layer[..., 3] = alpha.astype(np.uint8)
    return Image.fromarray(layer, "RGBA")


def mask_of(points, size):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask


def arch_points(x0, x1, spring_y, height, steps=26):
    """A pointed Persian arch: two quadratic curves from the springing line to the apex."""
    centre = (x0 + x1) * 0.5
    apex = (centre, spring_y - height)
    left = []
    control = (x0 + (x1 - x0) * 0.16, spring_y - height * 0.82)
    for index in range(steps + 1):
        t = index / steps
        x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * control[0] + t * t * apex[0]
        y = (1 - t) ** 2 * spring_y + 2 * (1 - t) * t * control[1] + t * t * apex[1]
        left.append((x, y))
    right = [(2 * centre - x, y) for x, y in reversed(left)]
    return left + right


def onion_dome(centre_x, base_y, width, height, steps=40):
    """A dome that swells and then tapers to a point — the profile a plain half ellipse does not have."""
    left = []
    for index in range(steps + 1):
        t = index / steps
        y = base_y - height * t
        half = width * 0.5 * math.sin(math.pi * min(1.0, 0.12 + t * 0.95)) ** 0.62 * (1.0 - t * 0.15)
        if t > 0.86:
            half *= (1.0 - t) / 0.14
        left.append((centre_x - half, y))
    right = [(2 * centre_x - x, y) for x, y in reversed(left)]
    return left + [(centre_x, base_y - height * 1.02)] + right


def cypress(centre_x, base_y, height, width, colour):
    points = []
    steps = 24
    for index in range(steps + 1):
        t = index / steps
        y = base_y - height * t
        half = width * 0.5 * (1.0 - t) ** 0.72 * (0.35 + 0.65 * min(1.0, t * 3.2))
        points.append((centre_x - half, y))
    for index in range(steps + 1):
        t = 1.0 - index / steps
        y = base_y - height * t
        half = width * 0.5 * (1.0 - t) ** 0.72 * (0.35 + 0.65 * min(1.0, t * 3.2))
        points.append((centre_x + half, y))
    return points


SCENES = {
    # The title screen: warm, open, the moon high over the garden.
    "garden_dusk": dict(
        sky=[(0.00, (9, 20, 38)), (0.42, (18, 44, 74)), (0.62, (58, 96, 120)), (0.70, (196, 138, 78))],
        horizon=0.70, moon=(0.70, 0.20, 46), arches=0, wall=0.0, trees=True, pool=True,
        lanterns=[(0.30, 0.66, 26), (0.62, 0.67, 20)], grain=5, vignette=0.62, seed=11,
    ),
    # The board: the same place at night, dimmer and quieter, because five colours of gem have to be
    # the brightest thing on the screen.
    "hall_night": dict(
        sky=[(0.00, (6, 14, 28)), (0.45, (11, 28, 50)), (0.66, (20, 46, 72)), (0.74, (46, 68, 84))],
        horizon=0.74, moon=(0.22, 0.14, 30), arches=5, wall=0.46, trees=False, pool=False,
        lanterns=[], grain=6, vignette=0.78,
        seed=23,
    ),
    # The districts map: a terrace in daylight, hedges instead of lanterns.
    "map_terrace": dict(
        sky=[(0.00, (22, 48, 62)), (0.35, (44, 84, 96)), (0.55, (108, 132, 118)), (0.68, (186, 168, 120))],
        horizon=0.68, moon=None, arches=3, wall=0.40, trees=True, pool=False,
        lanterns=[], grain=5, vignette=0.55, seed=37,
    ),
    # The bazaar: warm, close, lamps everywhere.
    "bazaar": dict(
        sky=[(0.00, (28, 16, 24)), (0.40, (62, 30, 34)), (0.62, (120, 62, 48)), (0.72, (188, 118, 66))],
        horizon=0.72, moon=None, arches=6, wall=0.52, trees=False, pool=False,
        lanterns=[(0.14, 0.62, 22), (0.34, 0.63, 26), (0.54, 0.63, 22), (0.74, 0.63, 26), (0.90, 0.62, 20)],
        grain=6, vignette=0.66, seed=51,
    ),
    # Settings: a quiet courtyard, nothing moving.
    "courtyard": dict(
        sky=[(0.00, (10, 24, 44)), (0.46, (20, 48, 80)), (0.66, (52, 92, 118)), (0.74, (128, 122, 110))],
        horizon=0.74, moon=(0.50, 0.16, 34), arches=4, wall=0.44, trees=True, pool=False,
        lanterns=[(0.26, 0.60, 22), (0.74, 0.60, 22)], grain=5, vignette=0.60, seed=67,
    ),
}


def build(name):
    scene = SCENES[name]
    random.seed(scene["seed"])
    horizon = scene["horizon"]
    horizon_y = H * horizon
    size = (W, H)

    image = vertical_gradient(size, scene["sky"]).convert("RGBA")

    # ---- stars: only where the sky is still dark ------------------------------------------------
    stars = Image.new("RGBA", size, (0, 0, 0, 0))
    star_draw = ImageDraw.Draw(stars, "RGBA")
    for _ in range(230):
        x = random.uniform(0, W)
        y = random.uniform(0, horizon_y * 0.80)
        fade = 1.0 - y / (horizon_y * 0.85)
        alpha = int(random.uniform(30, 165) * max(0.0, fade))
        r = random.choice([1, 1, 1, 2])
        star_draw.ellipse((x - r, y - r, x + r, y + r), fill=(255, 248, 226, alpha))
    image.alpha_composite(stars)

    # ---- moon ------------------------------------------------------------------------------------
    if scene["moon"] is not None:
        mx, my, mr = scene["moon"]
        centre = (W * mx, H * my)
        image.alpha_composite(radial_layer(size, centre, mr * 6.5, (206, 222, 244), 0.34, 3.0))
        disc = ImageDraw.Draw(image, "RGBA")
        disc.ellipse((centre[0] - mr, centre[1] - mr, centre[0] + mr, centre[1] + mr),
                     fill=(246, 240, 222, 255))
        disc.ellipse((centre[0] - mr * 0.62, centre[1] - mr * 0.60, centre[0] + mr * 0.30,
                      centre[1] + mr * 0.38), fill=(236, 229, 208, 255))

    # ---- haze along the horizon: what makes distant things sit behind near ones -------------------
    image.alpha_composite(radial_layer(size, (W * 0.5, horizon_y + H * 0.02), W * 0.72,
                                       scene["sky"][-1][1], 0.30, 1.9))

    # ---- skyline: domes, minarets and the wall of the palace, as one silhouette -------------------
    skyline = shade(mix(scene["sky"][-1][1], (5, 10, 20), 0.80), 1.0)
    skyline_layer = Image.new("RGBA", size, (0, 0, 0, 0))
    sky_draw = ImageDraw.Draw(skyline_layer, "RGBA")
    base = horizon_y + H * 0.016
    sky_draw.rectangle((0, base - H * 0.008, W, base + H * 0.05), fill=skyline)
    for dome in [(0.13, 0.105, 0.080), (0.50, 0.140, 0.058), (0.85, 0.095, 0.070)]:
        cx, width, height = W * dome[0], W * dome[1], H * dome[2]
        sky_draw.polygon(onion_dome(cx, base, width, height), fill=skyline)
        sky_draw.rectangle((cx - width * 0.46, base - H * 0.012, cx + width * 0.46, base), fill=skyline)
    for minaret in [(0.31, 0.026), (0.69, 0.023)]:
        cx, width = W * minaret[0], W * minaret[1]
        top = base - H * 0.185
        sky_draw.rectangle((cx - width * 0.5, top, cx + width * 0.5, base), fill=skyline)
        sky_draw.rectangle((cx - width * 1.1, top + H * 0.02, cx + width * 1.1, top + H * 0.035),
                           fill=skyline)
        sky_draw.polygon(onion_dome(cx, top + H * 0.004, width * 1.7, H * 0.042), fill=skyline)
    image.alpha_composite(skyline_layer)

    # ---- the arcade wall -------------------------------------------------------------------------
    if scene["arches"]:
        wall_top = horizon_y - H * 0.02
        wall_colour = shade(mix((7, 14, 26), scene["sky"][-1][1], 0.06), 1.0)
        wall = Image.new("RGBA", size, (0, 0, 0, 0))
        wall_draw = ImageDraw.Draw(wall, "RGBA")
        wall_draw.rectangle((0, wall_top, W, H), fill=wall_colour)
        # A little light from the top so the wall has a face and not just an edge.
        wall_light = vertical_gradient((W, max(1, H - int(wall_top))),
                                       [(0.0, (56, 78, 96)), (0.30, (22, 38, 56)),
                                        (1.0, (10, 18, 30))]).convert("RGBA")
        wall_light.putalpha(46)
        wall.paste(wall_light, (0, int(wall_top)), wall_light)
        # Tilework band: two hairlines and a row of diamonds, the same gold as the plates.
        wall_draw.rectangle((0, wall_top, W, wall_top + H * 0.007), fill=(46, 80, 106, 255))
        wall_draw.rectangle((0, wall_top + H * 0.026, W, wall_top + H * 0.030), fill=(64, 112, 130, 200))
        step = W / float(scene["arches"])
        for index in range(scene["arches"] + 1):
            x = step * index
            wall_draw.polygon([(x, wall_top + H * 0.004), (x + 9, wall_top + H * 0.014),
                               (x, wall_top + H * 0.024), (x - 9, wall_top + H * 0.014)],
                              fill=(206, 160, 78, 120))
        image.alpha_composite(wall)

        # The arches stop at a sill line instead of running into the bottom of the frame. Below the sill
        # is plain wall, which is where the HUD sits: an arch edge behind a row of buttons reads as a
        # glitch, not as architecture.
        sill_y = horizon_y + H * 0.135
        spring_y = horizon_y + H * 0.030
        arch_height = H * 0.315
        thickness = W * 0.011
        for index in range(scene["arches"]):
            x0 = step * index + step * 0.11
            x1 = step * (index + 1) - step * 0.11
            arch = arch_points(x0, x1, spring_y, arch_height)
            opening = arch + [(x1, sill_y), (x0, sill_y)]
            # The inside of the arch: darker at the top, warm at the floor where the lamp burns. It has
            # to start above the springing line, or the arch head stays sky-coloured and reads as an
            # outline drawn on the sky instead of an opening cut in a wall.
            arch_top = spring_y - arch_height
            inner = vertical_gradient((int(x1 - x0) + 2, int(sill_y - arch_top) + 2),
                                      [(0.0, (8, 14, 22)), (0.30, (26, 36, 42)),
                                       (0.66, (96, 82, 62)), (0.90, (168, 126, 78)),
                                       (1.0, (62, 54, 46))]).convert("RGBA")
            canvas = Image.new("RGBA", size, (0, 0, 0, 0))
            canvas.paste(inner, (int(x0), int(arch_top)), inner)
            image.alpha_composite(Image.composite(canvas, Image.new("RGBA", size, (0, 0, 0, 0)),
                                                  mask_of(opening, size)))
            # Lamp on the floor of the opening, and its halo.
            # The lamp hangs in the upper half of the opening: at the sill it sat on the ledge and read
            # as a speck of dirt on the wall rather than as light inside an arch.
            lamp = ((x0 + x1) * 0.5, sill_y - (sill_y - arch_top) * 0.42)
            image.alpha_composite(radial_layer(size, lamp, (x1 - x0) * 1.05, (250, 198, 120), 0.55, 2.6))
            draw = ImageDraw.Draw(image, "RGBA")
            draw.ellipse((lamp[0] - 6, lamp[1] - 8, lamp[0] + 6, lamp[1] + 8),
                         fill=(255, 231, 176, 240))
            draw.line((lamp[0], arch_top + 6, lamp[0], lamp[1] - 9), fill=(52, 62, 70, 220), width=3)
            # Rim light on the arch edge, then a gold hairline inside it.
            draw.line(arch + [arch[0]], fill=(104, 140, 156, 170), width=3)
            draw.line([(x0, spring_y), (x0, sill_y)], fill=(104, 140, 156, 110), width=3)
            draw.line([(x1, spring_y), (x1, sill_y)], fill=(104, 140, 156, 110), width=3)
            inset = arch_points(x0 + thickness, x1 - thickness, spring_y, arch_height - thickness * 1.4)
            draw.line(inset + [inset[0]], fill=(198, 152, 72, 130), width=2)

        # The sill line and its shadow: the wall now reads as a frieze above a dado.
        draw = ImageDraw.Draw(image, "RGBA")
        draw.rectangle((0, sill_y - 3, W, sill_y + 5), fill=(58, 92, 112, 235))
        draw.rectangle((0, sill_y + 5, W, sill_y + 9), fill=(6, 12, 20, 120))

    # ---- terrace ---------------------------------------------------------------------------------
    floor_top = horizon_y + H * 0.10
    floor = vertical_gradient((W, max(1, H - int(floor_top))),
                              [(0.0, mix(scene["sky"][-1][1], (44, 54, 52), 0.50)),
                               (0.30, (30, 40, 42)), (1.0, (13, 20, 26))]).convert("RGBA")
    image.paste(floor, (0, int(floor_top)), floor)
    draw = ImageDraw.Draw(image, "RGBA")
    for index in range(10):
        t = index / 9.0
        y = floor_top + (H - floor_top) * (t ** 1.7)
        draw.line((0, y, W, y), fill=(150, 170, 172, int(20 * (1.0 - t) + 5)), width=2)

    if scene["pool"]:
        px, py, prx, pry = W * 0.5, H * 0.905, W * 0.285, H * 0.072
        pool = Image.new("RGBA", size, (0, 0, 0, 0))
        pool_draw = ImageDraw.Draw(pool, "RGBA")
        pool_draw.ellipse((px - prx, py - pry, px + prx, py + pry), fill=(16, 38, 58, 255))
        pool_draw.ellipse((px - prx, py - pry, px + prx, py + pry), outline=(78, 116, 138, 150),
                          width=3)
        image.alpha_composite(pool)
        if scene["moon"] is not None:
            reflection = Image.new("RGBA", size, (0, 0, 0, 0))
            reflection_draw = ImageDraw.Draw(reflection, "RGBA")
            for index in range(26):
                t = index / 25.0
                y = py - pry * 0.85 + (pry * 1.7) * t
                half = prx * 0.26 * math.sin(math.pi * (0.15 + t * 0.7))
                reflection_draw.line((px - half, y, px + half, y),
                                     fill=(214, 224, 232, int(70 * (1.0 - abs(t - 0.4)))))
            image.alpha_composite(reflection.filter(ImageFilter.GaussianBlur(6)))

    # ---- lanterns hanging over the terrace -------------------------------------------------------
    for lx, ly, radius in scene["lanterns"]:
        centre = (W * lx, H * ly)
        image.alpha_composite(radial_layer(size, centre, radius * 4.2, (250, 198, 124), 0.42, 2.8))
        draw = ImageDraw.Draw(image, "RGBA")
        draw.ellipse((centre[0] - radius * 0.28, centre[1] - radius * 0.34,
                      centre[0] + radius * 0.28, centre[1] + radius * 0.34),
                     fill=(255, 228, 172, 235))

    # ---- cypresses -------------------------------------------------------------------------------
    if scene["trees"]:
        for tx, height, width in [(0.05, 0.36, 46), (0.12, 0.27, 32), (0.95, 0.34, 44), (0.885, 0.25, 30)]:
            draw.polygon(cypress(W * tx, H * 0.995, H * height, width, None), fill=(7, 20, 24, 255))
            draw.polygon(cypress(W * tx, H * 0.995, H * height * 0.97, width * 0.52, None),
                         fill=(15, 36, 32, 255))

    # ---- finish: vignette, then grain ------------------------------------------------------------
    vignette = Image.new("L", size, 0)
    vignette_draw = ImageDraw.Draw(vignette)
    steps = 60
    for index in range(steps):
        t = index / steps
        inset = -W * 0.20 + (W * 0.20 + W * 0.07) * t
        alpha = int(255 * scene["vignette"] * (t ** 2.6))
        vignette_draw.rectangle((inset, inset, W - inset, H - inset), outline=alpha,
                                width=max(2, int(W * 0.02)))
    vignette = vignette.filter(ImageFilter.GaussianBlur(W * 0.035))
    shade_layer = Image.new("RGBA", size, (0, 0, 0, 255))
    shade_layer.putalpha(vignette)
    image.alpha_composite(shade_layer)

    import numpy as np
    noise = np.random.default_rng(scene["seed"]).normal(0.0, scene["grain"], (H, W))
    grey = np.clip(128.0 + noise, 0, 255).astype(np.uint8)
    overlay = np.dstack([grey, grey, grey, np.full_like(grey, 18)])
    image.alpha_composite(Image.fromarray(overlay, "RGBA"))

    return image.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in SCENES:
        build(name).save(os.path.join(OUT, name + ".png"), optimize=True)
        print("%-16s %dx%d" % (name + ".png", W, H))


if __name__ == "__main__":
    main()
