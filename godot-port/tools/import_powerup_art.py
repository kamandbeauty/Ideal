#!/usr/bin/env python3
"""Cut the three power-up icons off their plates and write the files the board ships.

The power-up art in `assets/art/powerup_*.png` is the Unity project's, and it stays exactly as it is:
the migration ships every original pixel. The board's special pieces are drawn with the new look, so
they get their own pictures — a rocket, a fan and a kite — painted one plate each and keyed here.

Run: python3 godot-port/tools/import_powerup_art.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(HERE, "assets", "powerups", "source")
OUT = os.path.join(HERE, "assets", "powerups")

SIZE = 192           # the plate the board scales from
BOX = 176            # how much of the plate the icon fills
KEY_TOLERANCE = 26   # how near the field colour a pixel has to be to get filled
ICONS = ("rocket", "fan", "kite")


def _field_colour(plate: Image.Image) -> tuple:
    pixels = np.asarray(plate).astype(np.float32)
    border = np.concatenate([pixels[0], pixels[-1], pixels[:, 0], pixels[:, -1]])
    return tuple(np.median(border, axis=0))


def _keyed(plate: Image.Image) -> Image.Image:
    pixels = np.asarray(plate).astype(np.int16)
    distance = np.abs(pixels - np.array(_field_colour(plate), dtype=np.int16)).max(axis=2)
    mask = np.where(distance <= KEY_TOLERANCE, 0, 255).astype(np.uint8)
    # frombytes, not fromarray: an image built on a numpy buffer is read-only in Pillow 13, and a flood
    # fill on it writes nothing at all.
    binary = Image.frombytes("L", plate.size, mask.tobytes())
    for seed in ((0, 0), (plate.width - 1, 0), (0, plate.height - 1),
                 (plate.width - 1, plate.height - 1)):
        ImageDraw.floodfill(binary, seed, 128, thresh=0)
    cut = plate.convert("RGBA")
    alpha = Image.fromarray(np.where(np.asarray(binary) == 128, 0, 255).astype(np.uint8), "L")
    cut.putalpha(alpha.filter(ImageFilter.GaussianBlur(0.8)))
    return _largest(cut)


def _largest(cut: Image.Image) -> Image.Image:
    """Keep the icon and drop whatever else the painting picked up."""
    from scipy import ndimage

    alpha = np.asarray(cut.getchannel("A")) > 32
    labels, count = ndimage.label(alpha)
    if count <= 1:
        return cut
    sizes = ndimage.sum(alpha, labels, range(1, count + 1))
    keep = np.zeros(count + 1, dtype=bool)
    keep[1:] = sizes >= float(sizes.max()) * 0.05
    alpha = np.where(keep[labels], 255, 0).astype(np.uint8)
    cut.putalpha(Image.fromarray(alpha, "L"))
    return cut


def _centred(icon: Image.Image) -> Image.Image:
    box = icon.getbbox()
    if box is None:
        return icon
    icon = icon.crop(box)
    scale = BOX / max(icon.width, icon.height)
    icon = icon.resize((max(1, int(icon.width * scale + 0.5)),
                        max(1, int(icon.height * scale + 0.5))), Image.LANCZOS)
    plate = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    plate.paste(icon, ((SIZE - icon.width) // 2, (SIZE - icon.height) // 2), icon)
    return plate


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name in ICONS:
        plate = _centred(_keyed(Image.open(os.path.join(SOURCE, name + ".png")).convert("RGB")))
        path = os.path.join(OUT, name + ".png")
        plate.save(path, optimize=True)
        print("%-8s %dx%d  %5.1f kB" % (name, plate.width, plate.height,
                                        os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
