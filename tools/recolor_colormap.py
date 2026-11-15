#!/usr/bin/env python3
"""Repaint the Kenney colour atlas into the retro 1950s palette.

The kit buildings share one 512x512 palette texture (`colormap.png`) that holds
long hue ramps, so an exact swatch table cannot cover it. Instead every pixel is
converted to HSV, its hue band decides which retro colour it becomes, and the
original brightness is kept as a multiplier - so shading ramps survive and the
whole kit repaints coherently.

    python3 tools/recolor_colormap.py

Edit `BANDS` to retune the town's look.
"""

from __future__ import annotations

import colorsys
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "..", "assets", "models", "Textures", "colormap.png")
TARGET = os.path.join(HERE, "..", "assets", "models", "Textures", "colormap-retro.png")

# hue range (degrees) -> retro colour, keyed by the top of the range
BANDS: list[tuple[float, tuple[float, float, float]]] = [
    (38.0, (0.78, 0.20, 0.20)),   # reds and oranges -> cherry
    (70.0, (0.93, 0.71, 0.24)),   # yellows         -> mustard
    (165.0, (0.16, 0.58, 0.55)),  # greens          -> teal
    (255.0, (0.31, 0.49, 0.58)),  # blues           -> dusty blue
    (330.0, (0.84, 0.44, 0.48)),  # purples, pinks  -> salmon
    (360.0, (0.78, 0.20, 0.20)),  # back to red     -> cherry
]

# Walls in the kit are pale tints; they become cream and sand instead of taking
# on the hue of whatever they used to be.
NEUTRAL_SATURATION = 0.22
PALE_SATURATION = 0.4
# Neutrals keep their value but pick up a touch of warm sun.
NEUTRAL_TINT = (1.0, 0.975, 0.93)


def target_for(hue_degrees: float) -> tuple[float, float, float]:
    for limit, color in BANDS:
        if hue_degrees <= limit:
            return color
    return BANDS[-1][1]


def recolor(pixel: tuple[int, int, int]) -> tuple[int, int, int]:
    r, g, b = (channel / 255.0 for channel in pixel)
    hue, saturation, value = colorsys.rgb_to_hsv(r, g, b)
    if saturation < NEUTRAL_SATURATION:
        out = (
            value * NEUTRAL_TINT[0],
            value * NEUTRAL_TINT[1],
            value * NEUTRAL_TINT[2],
        )
    elif saturation < PALE_SATURATION:
        # Pale tints: warm cream walls, no hue carried over.
        out = (value, value * 0.93, value * 0.8)
    else:
        target = target_for(hue * 360.0)
        target_value = max(target, key=lambda channel: channel)
        # Keep the pixel's own brightness so ramps and shadows stay readable.
        factor = max(0.45, min(1.25, value / max(target_value, 0.001)))
        out = tuple(min(1.0, channel * factor) for channel in target)
    return tuple(int(round(max(0.0, min(1.0, channel)) * 255)) for channel in out)


def main() -> None:
    image = Image.open(SOURCE).convert("RGB")
    out = Image.new("RGB", image.size)
    source_pixels = image.load()
    target_pixels = out.load()
    for y in range(image.size[1]):
        for x in range(image.size[0]):
            target_pixels[x, y] = recolor(source_pixels[x, y])
    out.save(TARGET)
    print(f"wrote {os.path.relpath(TARGET)} ({out.size[0]}x{out.size[1]})")


if __name__ == "__main__":
    main()
