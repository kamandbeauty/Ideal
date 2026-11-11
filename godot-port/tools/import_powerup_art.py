#!/usr/bin/env python3
"""Cut the three power-up icons out of one painted sheet and write the plates the board ships.

The power-up art in `assets/art/powerup_*.png` is the Unity project's, and it stays exactly as it is:
the migration has to ship every original pixel. But the board's special pieces are drawn with the new
look, so they need new pictures — a rocket, a hand fan and a kite.

Painting them on one sheet and splitting it here keeps the three on the same hand, the same outline
weight and the same light, which is the thing that is hard to get from three separate prompts. The
splitter finds the three blobs by connected components, sorts them left to right and writes one plate
each, so the result is reproducible from the committed sheet.

Run: python3 godot-port/tools/import_powerup_art.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(HERE, "assets", "powerups", "source", "powerups.png")
OUT = os.path.join(HERE, "assets", "powerups")

SIZE = 192           # the plate the board scales from
BOX = 176            # how much of the plate the icon fills
KEY_TOLERANCE = 26   # how near the field colour a pixel has to be to get filled
ORDER = ["rocket", "fan", "kite"]


def _keyed(image: Image.Image) -> Image.Image:
    pixels = np.asarray(image).astype(np.int16)
    border = np.concatenate([pixels[0], pixels[-1], pixels[:, 0], pixels[:, -1]])
    field = np.median(border, axis=0)
    distance = np.abs(pixels - field).max(axis=2)
    mask = np.where(distance <= KEY_TOLERANCE, 0, 255).astype(np.uint8)

    # frombytes, not fromarray: an image built on a numpy buffer is read-only in Pillow 13 and a flood
    # fill on it writes nothing at all.
    binary = Image.frombytes("L", image.size, mask.tobytes())
    from PIL import ImageDraw

    for seed in ((0, 0), (image.width - 1, 0), (0, image.height - 1),
                 (image.width - 1, image.height - 1)):
        ImageDraw.floodfill(binary, seed, 128, thresh=0)
    cut = image.convert("RGBA")
    alpha = Image.fromarray(np.where(np.asarray(binary) == 128, 0, 255).astype(np.uint8), "L")
    cut.putalpha(alpha.filter(ImageFilter.GaussianBlur(0.8)))
    return cut


def _blobs(cut: Image.Image) -> list:
    """The three icons, left to right, each cropped to its own box."""
    from scipy import ndimage

    alpha = np.asarray(cut.getchannel("A")) > 32
    labels, count = ndimage.label(alpha)
    boxes = []
    for index in range(1, count + 1):
        area = int((labels == index).sum())
        if area < 400:
            continue
        ys, xs = np.nonzero(labels == index)
        boxes.append((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1, area))
    # Three icons: take the three biggest, then read them in the order they were painted.
    boxes.sort(key=lambda box: box[4], reverse=True)
    boxes = sorted(boxes[:3], key=lambda box: box[0])
    return [cut.crop(box[:4]) for box in boxes]


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
    icons = _blobs(_keyed(Image.open(SHEET).convert("RGB")))
    if len(icons) != len(ORDER):
        raise SystemExit("the sheet has %d icons, expected %d" % (len(icons), len(ORDER)))
    for name, icon in zip(ORDER, icons):
        plate = _centred(icon)
        path = os.path.join(OUT, name + ".png")
        plate.save(path, optimize=True)
        print("%-10s %dx%d  %5.1f kB" % (name, plate.width, plate.height,
                                         os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
