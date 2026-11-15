#!/usr/bin/env python3
"""Derive every launcher icon from the single generated source artwork.

    python3 tools/build_icons.py

``assets/icons/source-icon.png`` is the 1024x1024 master (a retro roadside pylon
at night). This script trims the white margin the generator leaves around the
artwork, squares it up and writes:

    assets/icons/icon.png                    512  project icon, Godot window icon
    assets/icons/launcher_192.png            192  Android legacy launcher icon
    assets/icons/adaptive_foreground.png     432  Android adaptive foreground (66 %)
    assets/icons/adaptive_background.png     432  Android adaptive background (navy)
    documentation/qa/preview/icon.png        256  for the docs
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "icons", "source-icon.png")
NAVY = (13, 20, 38)


def artwork() -> Image.Image:
    """The generated art without the white border, squared and full-bleed."""
    image = Image.open(SOURCE).convert("RGB")
    pixels = np.asarray(image).astype(np.int16)
    # "Not near-white" marks the artwork; the master has a white margin.
    mask = (pixels.sum(axis=2) < 735)
    rows = np.where(mask.any(axis=1))[0]
    cols = np.where(mask.any(axis=0))[0]
    top, bottom = int(rows[0]), int(rows[-1]) + 1
    left, right = int(cols[0]), int(cols[-1]) + 1
    # Inset a couple of pixels so the artwork's own rounded corners fall away.
    inset = 2
    box = (left + inset, top + inset, right - inset, bottom - inset)
    art = image.crop(box)

    # Fill the rounded corners with the artwork's own background colour.
    corner = art.getpixel((art.width // 2, 2))
    canvas = Image.new("RGB", art.size, corner)
    rounded = Image.new("L", art.size, 0)
    mask_image = Image.new("L", art.size, 255)
    rounded.paste(mask_image, (0, 0))
    canvas.paste(art, (0, 0))

    # Square it up around the centre.
    side = max(canvas.size)
    square = Image.new("RGB", (side, side), corner)
    square.paste(canvas, ((side - canvas.width) // 2, (side - canvas.height) // 2))
    return square


def save(image: Image.Image, relative: str, size: int) -> None:
    path = os.path.join(ROOT, relative)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print(f"  {relative:44s} {size}x{size}")


def main() -> None:
    art = artwork()
    save(art, "assets/icons/icon.png", 512)
    save(art, "assets/icons/launcher_192.png", 192)
    save(art, "documentation/qa/preview/icon.png", 256)

    # Adaptive icon: Android crops a 432 canvas to a 288 safe zone, so the art
    # sits at 66 % with a solid background showing through the mask.
    foreground = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    inner = art.resize((286, 286), Image.LANCZOS).convert("RGBA")
    foreground.paste(inner, ((432 - 286) // 2, (432 - 286) // 2), inner)
    path = os.path.join(ROOT, "assets/icons/adaptive_foreground.png")
    foreground.save(path, optimize=True)
    print(f"  {'assets/icons/adaptive_foreground.png':44s} 432x432")

    background = Image.new("RGB", (432, 432), NAVY)
    background.save(os.path.join(ROOT, "assets/icons/adaptive_background.png"))
    print(f"  {'assets/icons/adaptive_background.png':44s} 432x432")


if __name__ == "__main__":
    main()
