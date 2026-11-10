#!/usr/bin/env python3
"""Grade the two painted plates the board sits in, and write the files the game ships.

Everything else on the board screen is a picture already; the tray and the case around it were the last
two surfaces drawn by code. They are painted once by an image model and graded here:

  ui_board_frame   the carved case, drawn *behind* the tray: stretched 1:1 (no nine-slice, because it is
                   always drawn square), so its corner bosses stay round.
  ui_board_tray    the velvet the stones lie on. Only the centre of the painted tray is kept: the ornate
                   band of that plate is the case, and if it stayed in the tray the eight-one cells would
                   sit on top of it.

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

# Draw sizes in the port: the tray is 306 dp and the case 366 dp, so the plates ship at twice that.
TRAY_SIZE = 612
FRAME_SIZE = 732
# The painted case has a band of empty background around its moulding. Left in, it eats most of the
# 30 dp ring the board has for it and covers the header — so it is trimmed off before the resize.
FRAME_TRIM = 0.035

# How much of the painted tray is velvet: the rest is the moulding, which becomes the case instead.
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


def build_frame() -> Image.Image:
    source = _load("frame")
    width, height = source.size
    trim_x = int(width * FRAME_TRIM)
    trim_y = int(height * FRAME_TRIM)
    source = source.crop((trim_x, trim_y, width - trim_x, height - trim_y))
    frame = source.resize((FRAME_SIZE, FRAME_SIZE), Image.LANCZOS)
    frame = frame.filter(ImageFilter.UnsharpMask(radius=2.2, percent=62, threshold=2))
    # Brighten slightly: this is the gold in the room, and the hall behind it is dark.
    pixels = np.asarray(frame).astype(np.float32)
    pixels = np.clip(pixels * 1.06 + 4.0, 0, 255)
    frame = Image.fromarray(pixels.astype(np.uint8), "RGB")
    return _grain(frame, 2.5, 23)


def main() -> None:
    for name, picture in (("ui_board_tray.png", build_tray()), ("ui_board_frame.png", build_frame())):
        path = os.path.join(OUT, name)
        picture.save(path, optimize=True)
        print("%-22s %dx%d  %6.1f kB" % (name, picture.width, picture.height,
                                         os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
