#!/usr/bin/env python3
"""Draw the juice-splash sprites the board bursts a fruit into.

A cleared piece used to throw the Unity project's `fx_spark` — a four-point star — tinted with the
piece colour. That reads as a spark, not as juice: the reference the player judges this by splats.
A splat is a picture, so it is painted here, offline, the same way every other plate is: no runtime
shape drawing, no shader, one PNG per variant.

Three variants so two neighbouring cells never burst identically. They are drawn white with an alpha
channel and tinted per fruit at run time, which is what keeps one set of three files enough for five
colours.

  splash_1..3.png   the splat: an irregular juicy blob with flung droplets    512 x 512
  splash_drop.png   one droplet, for the streak that flies out of the splat     64 x 64
  splash_drip.png   one hanging drip, for juice that runs down after the burst  64 x 96
  fx_streak.png     the rocket's beam: a long soft light bar, tapered at both ends  512 x 64

Run: python3 godot-port/tools/make_fx_art.py
"""

from __future__ import annotations

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "assets", "fx")

SPLAT_SIZE = 512
DROP_SIZE = 64
SUPERSAMPLE = 4          # everything is drawn 4x and shrunk, so no edge is a staircase
VARIANTS = 3


def _radial_blob(center: tuple, radius: float, rng: random.Random, wobble: float) -> list:
    """A closed polygon whose radius wobbles with two frequencies: never a circle, never a star."""
    phase_a = rng.uniform(0.0, math.tau)
    phase_b = rng.uniform(0.0, math.tau)
    points = []
    steps = 96
    for step in range(steps):
        angle = math.tau * step / steps
        r = radius * (1.0
                      + wobble * math.sin(3.0 * angle + phase_a)
                      + wobble * 0.55 * math.sin(5.0 * angle + phase_b))
        points.append((center[0] + math.cos(angle) * r, center[1] + math.sin(angle) * r))
    return points


def build_splat(seed: int) -> Image.Image:
    rng = random.Random(seed)
    size = SPLAT_SIZE * SUPERSAMPLE
    picture = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(picture)

    middle = (size * 0.5, size * 0.5)
    core = size * 0.30
    # The body of the splash, then a second, smaller lobe beside it: juice on a tile is never a disc.
    draw.polygon(_radial_blob(middle, core, rng, 0.20), fill=(255, 255, 255, 236))
    offset = (middle[0] + rng.uniform(-0.16, 0.16) * size,
              middle[1] + rng.uniform(-0.16, 0.16) * size)
    draw.polygon(_radial_blob(offset, core * rng.uniform(0.45, 0.62), rng, 0.26),
                 fill=(255, 255, 255, 228))

    # A few punched-out specks inside the body: juice with air in it catches the light, and a flat
    # silhouette of one colour is what makes a splat look like a sticker instead of a splash.
    for _ in range(rng.randint(5, 8)):
        angle = rng.uniform(0.0, math.tau)
        distance = core * rng.uniform(0.15, 0.75)
        radius = core * rng.uniform(0.05, 0.13)
        x = middle[0] + math.cos(angle) * distance
        y = middle[1] + math.sin(angle) * distance
        draw.ellipse((x - radius, y - radius, x + radius, y + radius),
                     fill=(255, 255, 255, rng.randint(30, 80)))

    # Flung droplets: a small ellipse each, thrown out of the body with an uneven spread.
    for _ in range(rng.randint(7, 10)):
        angle = rng.uniform(0.0, math.tau)
        distance = core * rng.uniform(1.15, 1.62)
        radius = core * rng.uniform(0.055, 0.15)
        x = middle[0] + math.cos(angle) * distance
        y = middle[1] + math.sin(angle) * distance
        draw.ellipse((x - radius, y - radius * rng.uniform(0.75, 1.15),
                      x + radius, y + radius * rng.uniform(0.75, 1.15)),
                     fill=(255, 255, 255, rng.randint(200, 245)))
        # A tail back towards the body: a droplet that has just left is a streak.
        tail_len = radius * rng.uniform(1.2, 2.4)
        draw.line((x, y, x - math.cos(angle) * tail_len, y - math.sin(angle) * tail_len),
                  fill=(255, 255, 255, 150),
                  width=max(2, int(radius * 0.7)))

    picture = picture.resize((SPLAT_SIZE, SPLAT_SIZE), Image.LANCZOS)
    # A single soft pass: a hard white edge on a tinted splat reads as a sticker.
    alpha = picture.getchannel("A").filter(ImageFilter.GaussianBlur(1.1))
    # Juice thins out as it spreads. A flat silhouette of one opacity is a paint blob; the same shape
    # with the middle dense and the rim nearly clear reads as liquid on a tile.
    falloff = Image.new("L", (SPLAT_SIZE, SPLAT_SIZE), 0)
    ImageDraw.Draw(falloff).ellipse((SPLAT_SIZE * 0.16, SPLAT_SIZE * 0.16,
                                     SPLAT_SIZE * 0.84, SPLAT_SIZE * 0.84), fill=255)
    falloff = falloff.filter(ImageFilter.GaussianBlur(SPLAT_SIZE * 0.16))
    solid = np.asarray(alpha).astype(np.float32) / 255.0
    centre = np.asarray(falloff).astype(np.float32) / 255.0
    picture.putalpha(Image.fromarray(
        np.clip(solid * (0.52 + 0.48 * centre) * 255.0, 0, 255).astype(np.uint8), "L"))
    return picture


def build_drop() -> Image.Image:
    size = DROP_SIZE * SUPERSAMPLE
    picture = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(picture)
    inset = size * 0.16
    draw.ellipse((inset, inset, size - inset, size - inset), fill=(255, 255, 255, 240))
    picture = picture.resize((DROP_SIZE, DROP_SIZE), Image.LANCZOS)
    alpha = picture.getchannel("A").filter(ImageFilter.GaussianBlur(0.6))
    picture.putalpha(alpha)
    return picture


def build_drip() -> Image.Image:
    """A drip: round at the top where it is still attached, drawn to a point at the bottom."""
    width, height = 64, 96
    scale = SUPERSAMPLE
    picture = Image.new("RGBA", (width * scale, height * scale), (255, 255, 255, 0))
    draw = ImageDraw.Draw(picture)
    head = width * scale * 0.40
    centre_x = width * scale * 0.5
    draw.ellipse((centre_x - head, height * scale * 0.06, centre_x + head, height * scale * 0.06 + head * 2),
                 fill=(255, 255, 255, 245))
    draw.polygon([(centre_x - head * 0.92, height * scale * 0.30),
                  (centre_x + head * 0.92, height * scale * 0.30),
                  (centre_x, height * scale * 0.97)], fill=(255, 255, 255, 245))
    picture = picture.resize((width, height), Image.LANCZOS)
    picture.putalpha(picture.getchannel("A").filter(ImageFilter.GaussianBlur(0.7)))
    return picture


def build_streak() -> Image.Image:
    """The rocket's beam: bright in the middle, feathered to nothing at both ends and both edges."""
    width, height = 512, 64
    picture = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    pixels = picture.load()
    for x in range(width):
        across = 1.0 - abs(x - width / 2.0) / (width / 2.0)
        taper = across ** 0.55
        for y in range(height):
            down = 1.0 - abs(y - height / 2.0) / (height / 2.0)
            alpha = int(255 * taper * (down ** 1.6))
            if alpha > 0:
                pixels[x, y] = (255, 255, 255, alpha)
    return picture.filter(ImageFilter.GaussianBlur(1.2))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    written = []
    for index in range(VARIANTS):
        written.append(("splash_%d.png" % (index + 1), build_splat(index + 1)))
    written.append(("splash_drop.png", build_drop()))
    written.append(("splash_drip.png", build_drip()))
    written.append(("fx_streak.png", build_streak()))
    for name, picture in written:
        path = os.path.join(OUT, name)
        picture.save(path, optimize=True)
        print("%-18s %dx%d  %6.1f kB" % (name, picture.width, picture.height,
                                        os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
