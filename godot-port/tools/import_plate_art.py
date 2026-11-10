#!/usr/bin/env python3
"""Grade the painted plates the board sits on, and write the files the game ships.

Everything else on the board screen is a picture already; the tray and the two cards were the last
surfaces drawn by code. They are painted once by an image model and graded here:

  ui_board_tray    the velvet the stones lie on. Only the centre of the painted tray is kept — its
                   painted moulding is not shipped: the case that used to ring the board read as a
                   picture frame, so the tray is the board now.
  ui_card_frame    the wide plaque on the home screen.
  ui_card_tall     the portrait plaque on the districts screen.

The ungraded paintings live in `assets/ui/source/` (committed, with a .gdignore so the export does not
ship them twice), so this script reproduces both PNGs exactly.

Run: python3 godot-port/tools/import_plate_art.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(HERE, "assets", "ui", "source")
OUT = os.path.join(HERE, "assets", "ui")

# The tray is drawn at 330 dp, so the plate ships at twice that.
TRAY_SIZE = 660

# The two card plaques are authored at exactly the size the screens draw them (330x126 and 232x286) and
# stretched whole, because a card is a fixed size: nine-slicing a painted moulding at 40 dp corners
# would crop the ornament. The painted plate is 16:9; it is squashed to the card's shape, which is the
# only distortion it gets and is not visible in the moulding at this size.
CARD_TRIM = 0.032
CARDS = {
    "ui_card_frame.png": ("card_wide", (660, 252)),
    "ui_card_tall.png": ("card_tall", (464, 572)),
}

# How much of the painted tray is velvet: the painted moulding is not shipped.
TRAY_KEEP = 0.60


def _load(name: str) -> Image.Image:
    return Image.open(os.path.join(SOURCE, name + ".png")).convert("RGB")


def _grain(picture: Image.Image, amount: float, seed: int) -> Image.Image:
    pixels = np.asarray(picture).astype(np.float32) / 255.0
    rng = np.random.default_rng(seed)
    height, width = pixels.shape[:2]
    pixels = pixels + rng.normal(0.0, amount / 255.0, (height, width, 1)).astype(np.float32)
    return Image.fromarray(np.clip(pixels * 255.0, 0, 255).astype(np.uint8), "RGB")


def build_tray() -> Image.Image:
    source = _load("tray")
    width, height = source.size
    half_x = int(width * TRAY_KEEP * 0.5)
    half_y = int(height * TRAY_KEEP * 0.5)
    centre = source.crop((width // 2 - half_x, height // 2 - half_y,
                          width // 2 + half_x, height // 2 + half_y))
    tray = centre.resize((TRAY_SIZE, TRAY_SIZE), Image.LANCZOS)
    # A touch darker and cooler: the velvet is the floor of the board, not a light source.
    pixels = np.asarray(tray).astype(np.float32) * np.array([0.88, 0.90, 0.96], dtype=np.float32)
    tray = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    tray = tray.filter(ImageFilter.UnsharpMask(radius=2.0, percent=45, threshold=3))
    return _grain(tray, 3.0, 11)


def build_card(source_name: str, size: tuple) -> Image.Image:
    source = _load(source_name)
    width, height = source.size
    trim_x = int(width * CARD_TRIM)
    trim_y = int(height * CARD_TRIM)
    source = source.crop((trim_x, trim_y, width - trim_x, height - trim_y))
    plate = source.resize(size, Image.LANCZOS)
    plate = plate.filter(ImageFilter.UnsharpMask(radius=1.6, percent=55, threshold=2))
    # A touch darker: the captions on a card are small, and the lacquer is a face, not a light.
    pixels = np.asarray(plate).astype(np.float32) * np.array([0.94, 0.95, 0.98], dtype=np.float32)
    plate = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    return _grain(plate, 2.0, 37)


def main() -> None:
    plates = [("ui_board_tray.png", build_tray())]
    for name, (source_name, size) in CARDS.items():
        plates.append((name, build_card(source_name, size)))
    for name, picture in plates:
        path = os.path.join(OUT, name)
        picture.save(path, optimize=True)
        print("%-22s %dx%d  %6.1f kB" % (name, picture.width, picture.height,
                                         os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
