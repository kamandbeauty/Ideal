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

NOTE: the shipped backdrops are graded paintings — see tools/import_backdrop_art.py and
assets/backdrops/source/. This procedural generator is kept because it is the fallback and the
reference for the plate geometry (horizon, arcade sill, lantern height); running it overwrites the
shipped files, so run it deliberately.


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


def onion_dome(centre_x, base_y, width, height, steps=44):
    """The profile of a Persian dome: full width at the base, a bulge that leans out, then a point.

    A plain half ellipse reads as a hat. The bulge is the whole silhouette, so it is worth the maths.
    """
    left = []
    for index in range(steps + 1):
        t = index / steps
        y = base_y - height * t
        if t < 0.30:
            k = 1.0 - 0.05 * (t / 0.30) ** 2
        else:
            u = (t - 0.30) / 0.70
            k = math.cos(u * math.pi * 0.5) ** 0.80
        left.append((centre_x - width * 0.5 * k, y))
    right = [(2 * centre_x - x, y) for x, y in reversed(left)]
    return left + [(centre_x, base_y - height * 1.05)] + right


def cypress(centre_x, base_y, height, width, colour=None):
    """The outline of a cypress: a flame, wider at the foot, tapering to a point."""
    points = []
    steps = 26
    for index in range(steps + 1):
        t = index / steps
        y = base_y - height * t
        half = width * 0.5 * (1.0 - t) ** 0.62 * (0.55 + 0.45 * min(1.0, t * 4.0))
        points.append((centre_x - half, y))
    for index in range(steps + 1):
        t = 1.0 - index / steps
        y = base_y - height * t
        half = width * 0.5 * (1.0 - t) ** 0.62 * (0.55 + 0.45 * min(1.0, t * 4.0))
        points.append((centre_x + half, y))
    return points


def draw_cypress(image, centre_x, base_y, height, width, dark=(8, 22, 26), light=(20, 46, 42)):
    """A tree, not a line: silhouette, then overlapping tufts of foliage down both edges.

    The first pass drew these 46 px wide on a 1476 px canvas, which on a phone is a one-pixel scratch
    beside the frame. At this width they read as cypresses from the terrace.
    """
    draw = ImageDraw.Draw(image, "RGBA")
    draw.polygon(cypress(centre_x, base_y, height, width), fill=dark + (255,))
    tufts = 28
    for index in range(tufts):
        t = index / tufts
        y = base_y - height * t * 0.94
        half = width * 0.5 * (1.0 - t) ** 0.62 * (0.55 + 0.45 * min(1.0, t * 4.0))
        if half < 1.5:
            break
        offset = (index % 2) * 0.6 + 0.4
        r = max(1.2, half * 0.20)
        for sign in (-1, 1):
            x = centre_x + sign * half * offset
            draw.ellipse((x - r, y - r * 1.5, x + r, y + r * 1.5), fill=light + (95,))
    # The lit edge, on the side the sky is brighter.
    left = [(x, y) for x, y in cypress(centre_x, base_y, height, width) if x <= centre_x]
    draw.line(left, fill=(46, 78, 70, 150), width=2)


def draw_pavilion(image, centre_x, width, base_y, height, warm=(244, 190, 122)):
    """A small palace pavilion: three lit arches under a shaded dome, with a gold finial.

    The skyline alone reads as a town far away. A pavilion in the middle distance is what makes the
    backdrop a *place*. It is shaded rather than filled flat: a black cut-out with bright holes in it
    is the difference between a drawing and a template.
    """
    body_height = height * 0.58
    body_top = base_y - body_height
    half = width * 0.5
    body = [(centre_x - half, base_y), (centre_x - half * 0.95, body_top),
            (centre_x + half * 0.95, body_top), (centre_x + half, base_y)]
    drum_height = height * 0.055
    dome_top = body_top - drum_height
    dome = onion_dome(centre_x, dome_top + 2, width * 0.90, height * 0.46)

    silhouette = Image.new("L", image.size, 0)
    silhouette_draw = ImageDraw.Draw(silhouette)
    silhouette_draw.polygon(body, fill=255)
    silhouette_draw.polygon(dome, fill=255)

    drum = [(centre_x - width * 0.36, body_top + 2), (centre_x + width * 0.36, body_top + 2),
            (centre_x + width * 0.34, body_top - drum_height), (centre_x - width * 0.34, body_top - drum_height)]
    silhouette_draw.polygon(drum, fill=255)
    face = vertical_gradient(image.size, [(0.0, (52, 66, 84)), (0.45, (24, 34, 48)),
                                          (1.0, (10, 16, 26))]).convert("RGBA")
    face.putalpha(silhouette)
    image.alpha_composite(face)
    draw = ImageDraw.Draw(image, "RGBA")

    # Rim light down the lit side of the body and around the lit half of the dome.
    draw.line([(centre_x - half, base_y), (centre_x - half * 0.95, body_top)],
              fill=(150, 178, 190, 90), width=3)
    left_arc = [(x, y) for x, y in dome if x <= centre_x]
    draw.line(left_arc, fill=(160, 186, 196, 110), width=3)

    arch_width = width * 0.155
    for index in (-1, 0, 1):
        x0 = centre_x + index * width * 0.27 - arch_width * 0.5
        x1 = x0 + arch_width
        spring = base_y - body_height * 0.10
        arch = arch_points(x0, x1, spring, body_height * 0.44)
        opening = arch + [(x1, base_y), (x0, base_y)]
        top = spring - body_height * 0.44
        # The opening is lit from the floor, not flooded: a lamp pool at the bottom and a dark
        # head under the arch. Filling the whole opening with the warm colour is what turned these
        # pavilions into beige balloons on the first pass.
        gradient = vertical_gradient((max(2, int(x1 - x0)), max(2, int(base_y - top))),
                                     [(0.0, (18, 22, 30)), (0.52, mix(warm, (40, 30, 26), 0.70)),
                                      (0.86, mix(warm, (120, 74, 40), 0.35)), (1.0, warm)]).convert("RGBA")
        canvas = Image.new("RGBA", image.size, (0, 0, 0, 0))
        canvas.paste(gradient, (int(x0), int(top)), gradient)
        image.alpha_composite(Image.composite(canvas, Image.new("RGBA", image.size, (0, 0, 0, 0)),
                                              mask_of(opening, image.size)))
        draw.line(arch, fill=(198, 172, 128, 110), width=2)
        # A mullion down the middle of each opening, so it reads as a window and not a hole.
        draw.line([(centre_x + index * width * 0.27, top), (centre_x + index * width * 0.27, base_y)],
                  fill=(26, 24, 28, 130), width=2)

    draw.line([(centre_x - width * 0.45, body_top + 2), (centre_x + width * 0.45, body_top + 2)],
              fill=(120, 146, 156, 130), width=3)
    draw.line([(centre_x - width * 0.34, dome_top), (centre_x + width * 0.34, dome_top)],
              fill=(96, 124, 138, 110), width=3)
    draw.line((centre_x, dome_top - height * 0.46, centre_x, dome_top - height * 0.56),
              fill=(214, 170, 86, 230), width=3)
    draw.ellipse((centre_x - 4, dome_top - height * 0.60, centre_x + 4, dome_top - height * 0.55),
                 fill=(236, 196, 112, 240))



def draw_lantern_string(image, draw, samples, sag, colour=(255, 226, 170), radius=10):
    """A string of lamps slung across the courtyard: the line sags, the lamps hang under it.

    It is the detail that turns a sky into a *ceiling* — an outdoor room the player is standing in.
    """
    points = [(x, y + sag * (1.0 - ((2.0 * i / max(1, samples - 1)) - 1.0) ** 2))
              for i, (x, y) in enumerate([(W * (0.06 + 0.88 * i / (samples - 1)), H * 0.06)
                                          for i in range(samples)])]
    draw.line(points, fill=(26, 30, 40, 200), width=2)
    for index in range(2, samples - 1, 2):
        x, y = points[index]
        draw.line((x, y, x, y + radius * 1.6), fill=(26, 30, 40, 200), width=2)
        image.alpha_composite(radial_layer(image.size, (x, y + radius * 3.0), radius * 8.0,
                                           (250, 200, 128), 0.62, 2.4))
        ImageDraw.Draw(image, "RGBA").ellipse(
            (x - radius * 0.7, y + radius * 2.2, x + radius * 0.7, y + radius * 4.2),
            fill=colour + (240,))


def draw_path(image, draw, base_half, top_half, colour=(38, 44, 46)):
    """The garden path, running from the player's feet to the pavilion."""
    top_y = H * 0.86
    draw.polygon([(W * 0.5 - top_half, top_y), (W * 0.5 + top_half, top_y),
                  (W * 0.5 + base_half, H), (W * 0.5 - base_half, H)], fill=colour)
    for index in range(1, 9):
        t = index / 9.0
        y = top_y + (H - top_y) * (t ** 1.5)
        half = top_half + (base_half - top_half) * (t ** 1.5)
        draw.line((W * 0.5 - half, y, W * 0.5 + half, y), fill=(84, 96, 98, 90), width=2)


SCENES = {
    # The title screen: warm, open, the moon high over the garden.
    "garden_dusk": dict(
        sky=[(0.00, (9, 20, 38)), (0.38, (18, 44, 74)), (0.56, (46, 82, 108)),
             (0.66, (116, 104, 96)), (0.72, (172, 132, 92))],
        horizon=0.70, moon=(0.70, 0.20, 46), arches=0, wall=0.0, trees=True, pool=True,
        lanterns=[(0.30, 0.66, 26), (0.62, 0.67, 20)], grain=5, vignette=0.62, seed=11,
        pavilions=[(0.50, 0.34, 0.30), (0.135, 0.26, 0.24), (0.865, 0.24, 0.22)],
        fireflies=16, tilework=False,
        lantern_strings=[(13, 0.055 * H)], path=None, clouds=5, foreground=True,
    ),
    # The board: the same place at night, dimmer and quieter, because five colours of gem have to be
    # the brightest thing on the screen.
    "hall_night": dict(
        sky=[(0.00, (6, 14, 28)), (0.45, (11, 28, 50)), (0.66, (20, 46, 72)), (0.74, (46, 68, 84))],
        horizon=0.74, moon=(0.22, 0.14, 30), arches=5, wall=0.46, trees=False, pool=False,
        lanterns=[], grain=6, vignette=0.78, pavilions=[], fireflies=0, tilework=True,
        lantern_strings=[], path=None, clouds=0, floor_pools=True, foreground=False,
        seed=23,
    ),
    # The districts map: a terrace in daylight, hedges instead of lanterns.
    "map_terrace": dict(
        sky=[(0.00, (22, 48, 62)), (0.35, (44, 84, 96)), (0.55, (108, 132, 118)), (0.68, (186, 168, 120))],
        horizon=0.68, moon=None, arches=3, wall=0.40, trees=True, pool=False,
        lanterns=[], grain=5, vignette=0.55, seed=37,
        pavilions=[(0.20, 0.26, 0.22), (0.80, 0.24, 0.20)], fireflies=0, tilework=False,
        lantern_strings=[], path=None, clouds=3, foreground=True,
    ),
    # The bazaar: warm, close, lamps everywhere.
    "bazaar": dict(
        sky=[(0.00, (28, 16, 24)), (0.40, (62, 30, 34)), (0.62, (120, 62, 48)), (0.72, (188, 118, 66))],
        horizon=0.72, moon=None, arches=6, wall=0.52, trees=False, pool=False,
        lanterns=[(0.14, 0.62, 22), (0.34, 0.63, 26), (0.54, 0.63, 22), (0.74, 0.63, 26), (0.90, 0.62, 20)],
        grain=6, vignette=0.66, seed=51, pavilions=[], fireflies=0, tilework=False,
        lantern_strings=[(9, 0.045 * H)], path=None, clouds=0, foreground=False,
    ),
    # Settings: a quiet courtyard, nothing moving.
    "courtyard": dict(
        sky=[(0.00, (10, 24, 44)), (0.46, (20, 48, 80)), (0.66, (52, 92, 118)), (0.74, (128, 122, 110))],
        horizon=0.74, moon=(0.50, 0.16, 34), arches=4, wall=0.44, trees=True, pool=False,
        lanterns=[(0.26, 0.60, 22), (0.74, 0.60, 22)], grain=5, vignette=0.60, seed=67,
        pavilions=[(0.50, 0.34, 0.28)], fireflies=8, tilework=True,
        lantern_strings=[], path=None, clouds=2, foreground=False,
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

    # ---- thin cloud bands above the horizon -------------------------------------------------------
    for index in range(scene.get("clouds", 0)):
        cy = horizon_y * (0.42 + 0.12 * index)
        length = W * random.uniform(0.22, 0.46)
        cx = random.uniform(W * 0.1, W * 0.9)
        cloud = Image.new("RGBA", size, (0, 0, 0, 0))
        cloud_draw = ImageDraw.Draw(cloud, "RGBA")
        for puff in range(7):
            offset = (puff - 3) * length / 8.0
            puff_w = length * random.uniform(0.20, 0.34)
            puff_h = H * random.uniform(0.008, 0.020)
            cloud_draw.ellipse((cx + offset - puff_w, cy - puff_h, cx + offset + puff_w, cy + puff_h),
                               fill=mix(scene["sky"][-1][1], (255, 236, 210), 0.55) + (40,))
        image.alpha_composite(cloud.filter(ImageFilter.GaussianBlur(W * 0.012)))

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

    # ---- the pavilions in the middle distance ----------------------------------------------------
    for pv in scene.get("pavilions", []):
        px, pw, ph = pv
        draw_pavilion(image, W * px, W * pw, horizon_y + H * 0.02, H * ph)

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
        sill_y = horizon_y + H * 0.020
        spring_y = sill_y
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

        if scene.get("tilework"):
            # Glazed tilework on the dado: a diamond in a diamond, the pattern every courtyard wall has.
            for row in range(3):
                y = sill_y + H * 0.030 + row * H * 0.026
                for col in range(int(W / (W * 0.030)) + 1):
                    x = col * W * 0.030 + (W * 0.015 if row % 2 else 0.0)
                    half_d = W * 0.0075
                    draw.polygon([(x, y - half_d), (x + half_d, y), (x, y + half_d), (x - half_d, y)],
                                 fill=(58, 116, 132, 70))

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

    if scene.get("path") is not None:
        top_half, base_half = scene["path"]
        draw_path(image, ImageDraw.Draw(image, "RGBA"), W * base_half, W * top_half)

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

    # ---- fireflies: a few warm points that make the garden feel alive -----------------------------
    for _ in range(scene.get("fireflies", 0)):
        fx = random.uniform(W * 0.04, W * 0.96)
        fy = random.uniform(H * 0.52, H * 0.92)
        image.alpha_composite(radial_layer(size, (fx, fy), random.uniform(16, 34),
                                           (252, 226, 160), 0.55, 2.2))
        dot = ImageDraw.Draw(image, "RGBA")
        dot.ellipse((fx - 2, fy - 2, fx + 2, fy + 2), fill=(255, 244, 210, 230))

    # ---- cypresses -------------------------------------------------------------------------------
    if scene["trees"]:
        # Planted in two clusters of three, so the pair behind reads as a row and not as two marks.
        grove = [(0.035, 0.44, 118), (0.085, 0.58, 150), (0.132, 0.40, 104),
                 (0.965, 0.46, 124), (0.915, 0.60, 152), (0.868, 0.38, 100)]
        for tx, height, width in grove:
            draw_cypress(image, W * tx, H * 0.995, H * height, width)
        draw = ImageDraw.Draw(image, "RGBA")

    # ---- a string of lamps across the courtyard ---------------------------------------------------
    for count, sag in scene.get("lantern_strings", []):
        draw_lantern_string(image, ImageDraw.Draw(image, "RGBA"), count, sag)

    # ---- warm pools of light on the floor under each arch -----------------------------------------
    if scene.get("floor_pools"):
        for index in range(scene["arches"]):
            x = W * (index + 0.5) / scene["arches"]
            image.alpha_composite(radial_layer(size, (x, H * 0.93), W * 0.055, (240, 190, 120), 0.30, 2.0))

    # ---- foreground: the colonnade the player is standing in --------------------------------------
    # A dark near wall down each edge, its inner face curving out of the top of the frame. Without it
    # the courtyard is a picture of a place; with it, it is a place you are looking out of. (The first
    # version blacked out the whole frame around an arch that was mostly off-canvas, which is how it
    # ended up as a black rectangle with a line on it.)
    if scene.get("foreground"):
        for mirrored in (False, True):
            steps = 24
            curve = []
            for index in range(steps + 1):
                t = index / steps
                x = W * (0.045 + 0.085 * (t ** 1.6))
                y = H * (0.16 + 0.84 * t)
                curve.append((W - x, y) if mirrored else (x, y))
            outer = [(W, 0), (W, H)] if mirrored else [(0, 0), (0, H)]
            mask = Image.new("L", size, 0)
            ImageDraw.Draw(mask).polygon(curve + outer, fill=255)
            mask = mask.filter(ImageFilter.GaussianBlur(5))
            wall = Image.new("RGBA", size, (5, 9, 16, 255))
            wall.putalpha(mask.point(lambda v: int(v * 0.96)))
            image.alpha_composite(wall)

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
