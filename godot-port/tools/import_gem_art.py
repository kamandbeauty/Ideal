#!/usr/bin/env python3
"""Cut the painted stones out of their plates and write the five pieces the game ships.

The five stones are painted once each by an image model, on a pure black field so the field can be
keyed away. This script does the keying, the centring and the sizing:

  1. flood fill from the four corners over everything near-black — that is the field, and only the
     field: a stone's own dark facets are not connected to the edge, so they survive
  2. feather the cut by a pixel, so a stone does not carry a black halo onto the board
  3. crop to the stone, scale it to a common size and centre it on a square plate

Every piece ends up the same visual weight as the others, which is what a match-three board needs: the
player reads shape and colour, never size.

The ungraded plates live in `assets/gems/source/` (committed, with a .gdignore), so this reproduces the
five shipped PNGs exactly.

Run: python3 godot-port/tools/import_gem_art.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(HERE, "assets", "gems", "source")
OUT = os.path.join(HERE, "assets", "gems")

SIZE = 160          # the plate every screen scales from
PIECE_BOX = 158     # how much of the plate the fruit fills
KEY_TOLERANCE = 26  # how near-black the field has to be to get filled


def _keyed(path: str) -> Image.Image:
    plate = Image.open(path).convert("RGB")
    # Flood the field from all four corners; anything connected to the edge and near-black becomes 0.
    # Binarise first: flood fill only spreads through pixels that are *exactly* the value it started
    # with, so a bright specular inside the stone can never be mistaken for field. (Keying on the
    # brightness afterwards punched a black hole through the pearl's highlight.)
    grey = plate.convert("L")
    binary = grey.point(lambda value: 0 if value <= KEY_TOLERANCE else 255)
    for seed in ((0, 0), (plate.width - 1, 0), (0, plate.height - 1),
                 (plate.width - 1, plate.height - 1)):
        ImageDraw.floodfill(binary, seed, 128, thresh=0)
    # 128 marks the field the fill reached; everything else is stone.
    stone = np.where(np.asarray(binary) == 128, 0, 255).astype(np.uint8)

    alpha = Image.fromarray(stone, "L").filter(ImageFilter.GaussianBlur(0.9))
    cut = plate.convert("RGBA")
    cut.putalpha(alpha)
    return cut


def _centred(cut: Image.Image) -> Image.Image:
    box = cut.getbbox()
    if box is None:
        return cut
    stone = cut.crop(box)
    # Match the pieces by area, not by the longest side: a tall emerald cut and a square cushion with
    # the same width do not look like the same size of stone.
    alpha = np.asarray(stone.getchannel("A")).astype(np.float32) / 255.0
    area = float(alpha.sum())
    target = (PIECE_BOX ** 2) * 0.62
    scale = (target / area) ** 0.5 if area > 1.0 else 1.0
    scale = min(scale, PIECE_BOX / max(stone.width, stone.height))
    stone = stone.resize((max(1, int(stone.width * scale + 0.5)),
                          max(1, int(stone.height * scale + 0.5))), Image.LANCZOS)
    plate = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    plate.paste(stone, ((SIZE - stone.width) // 2, (SIZE - stone.height) // 2), stone)
    return plate


def main() -> None:
    for name in ("firouzeh", "lajvard", "aqiq", "zomorrod", "morvarid"):
        source = os.path.join(SOURCE, name + ".png")
        piece = _centred(_keyed(source))
        path = os.path.join(OUT, "piece_%s.png" % name)
        piece.save(path, optimize=True)
        print("piece_%-10s %dx%d  %5.1f kB" % (name, piece.width, piece.height,
                                               os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
