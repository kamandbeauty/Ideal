#!/usr/bin/env python3
"""Grade the painted plates the board sits on, and write the files the game ships.

Everything else on the board screen is a picture already; the tray and the two cards were the last
surfaces drawn by code. They are painted once by an image model and graded here:

  ui_board_tray    the Persian carpet the stones lie on, painted whole and shipped whole: the board is
                   the playfield, and the carpet's own border is the only frame it gets.
  ui_rail          the capsule panel down each side of the board — goals and the purse on the left,
                   the tools on the right. Both rails are the same painted panel.
  ui_orb           the round tool button: a turquoise sphere in a gold ring, keyed out of its plate.
  ui_tile_frame    the cell a stone rests in: a soft cream square with an amber rim.
  ui_card_frame    the wide plaque on the home screen.
  ui_card_tall     the portrait plaque on the districts screen.

The ungraded paintings live in `assets/ui/source/` (committed, with a .gdignore so the export does not
ship them twice), so this script reproduces both PNGs exactly.

Run: python3 godot-port/tools/import_plate_art.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(HERE, "assets", "ui", "source")
OUT = os.path.join(HERE, "assets", "ui")

# The tray is drawn at 408 dp, so the plate ships at twice that.
TRAY_SIZE = 816
# The two rails are drawn at 118x388 dp; the orb and the cell at 64 and 42 dp. Everything ships at two
# times the size it is drawn, so a 3x screen still has pixels to spend.
RAIL_SIZE = (236, 776)
ORB_SIZE = 128
TILE_SIZE = 128
# How near-black a plate's field has to be before the key fills it.
KEY_TOLERANCE = 26

# The two card plaques are painted 16:9-ish and the cards are 2.6:1 and 0.81:1, so a plain stretch would
# turn the painted corner medallions into ellipses. They are nine-sliced here, in the tool, at the size
# the screens draw them (330x126 and 232x286 dp, doubled): the corners keep their shape, the plain bands
# between them take up the difference, and the shipped plate is already the card's exact shape, so the
# screens still stretch it whole and never slice it at runtime.
CARD_MARGINS = {
    "card_wide": (0.20, 0.42),
    "card_tall": (0.22, 0.34),
}
CARDS = {
    "ui_card_frame.png": ("card_wide", (660, 252)),
    "ui_card_tall.png": ("card_tall", (464, 572)),
}

# How much of the painted carpet is kept: the centre only. The painting's border is a wide geometric
# band — beautiful, and 60 dp of playfield if shipped whole. Keeping the middle 68% thins it to about
# 18 dp at the size the board is drawn, which frames the grid instead of competing with it.
TRAY_KEEP = 0.68


def _load(name: str) -> Image.Image:
    return Image.open(os.path.join(SOURCE, name + ".png")).convert("RGB")


def _grain(picture: Image.Image, amount: float, seed: int) -> Image.Image:
    pixels = np.asarray(picture).astype(np.float32) / 255.0
    rng = np.random.default_rng(seed)
    height, width = pixels.shape[:2]
    pixels = pixels + rng.normal(0.0, amount / 255.0, (height, width, 1)).astype(np.float32)
    return Image.fromarray(np.clip(pixels * 255.0, 0, 255).astype(np.uint8), "RGB")


def _field_keyed(source: Image.Image) -> Image.Image:
    """Cut a plate off its black field.

    Binarise first: flood fill only spreads through pixels *exactly* equal to the value it started
    with, so a bright highlight inside the painted object can never be mistaken for background.
    """
    grey = source.convert("L")
    binary = grey.point(lambda value: 0 if value <= KEY_TOLERANCE else 255)
    for seed in ((0, 0), (source.width - 1, 0), (0, source.height - 1),
                 (source.width - 1, source.height - 1)):
        ImageDraw.floodfill(binary, seed, 128, thresh=0)
    keep = np.where(np.asarray(binary) == 128, 0, 255).astype(np.uint8)
    alpha = Image.fromarray(keep, "L").filter(ImageFilter.GaussianBlur(0.7))
    cut = source.convert("RGBA")
    cut.putalpha(alpha)
    box = cut.getbbox()
    return cut.crop(box) if box is not None else cut


def build_tray() -> Image.Image:
    """The carpet. Shipped whole: the board is the playfield and the weave is its only frame."""
    source = _load("tray")
    width, height = source.size
    half_x = int(width * TRAY_KEEP * 0.5)
    half_y = int(height * TRAY_KEEP * 0.5)
    source = source.crop((width // 2 - half_x, height // 2 - half_y,
                          width // 2 + half_x, height // 2 + half_y))
    tray = source.resize((TRAY_SIZE, TRAY_SIZE), Image.LANCZOS)
    # A touch warmer and a touch darker than the painted plate: the stones sit on it, so it must not
    # compete with them.
    # A step darker and warmer than the cells that sit on it: the carpet is the floor of the board and
    # the cells are its furniture, so the cells have to read as raised.
    pixels = np.asarray(tray).astype(np.float32) * np.array([0.92, 0.89, 0.82], dtype=np.float32)
    tray = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    tray = tray.filter(ImageFilter.UnsharpMask(radius=1.8, percent=45, threshold=3))
    return _grain(tray, 2.0, 11)


def build_rail() -> Image.Image:
    """The capsule panel both rails use, cut off its field and set to the size the rails are drawn."""
    cut = _field_keyed(_load("rail"))
    plate = cut.resize(RAIL_SIZE, Image.LANCZOS)
    plate = plate.filter(ImageFilter.UnsharpMask(radius=1.4, percent=45, threshold=2))
    return plate


def build_round_plate(name: str, size: int) -> Image.Image:
    """A plate that is keyed out and drawn at its own size: the orb and the cell."""
    cut = _field_keyed(_load(name))
    plate = cut.resize((size, size), Image.LANCZOS)
    return plate.filter(ImageFilter.UnsharpMask(radius=1.2, percent=50, threshold=2))


def _nine_slice(cut: Image.Image, size: tuple, margins: tuple) -> Image.Image:
    """Stretch the plain bands of a painted plaque, never its corners.

    Each of the nine regions is scaled separately: the four corners are placed at one common scale, so
    a painted medallion keeps its circle, and the four edge bands and the middle take up the rest of
    the target. Without this a 16:9 plaque drawn into a 2.6:1 card turns every ornament oval.
    """
    target_w, target_h = size
    width, height = cut.size
    scale = min(target_w / float(width), target_h / float(height))
    source_x = max(1, int(width * margins[0]))
    source_y = max(1, int(height * margins[1]))
    corner_x = min(target_w // 2, max(1, int(source_x * scale)))
    corner_y = min(target_h // 2, max(1, int(source_y * scale)))
    columns = [(0, source_x, 0, corner_x),
               (source_x, width - source_x, corner_x, target_w - corner_x),
               (width - source_x, width, target_w - corner_x, target_w)]
    rows = [(0, source_y, 0, corner_y),
            (source_y, height - source_y, corner_y, target_h - corner_y),
            (height - source_y, height, target_h - corner_y, target_h)]
    plate = Image.new("RGBA", size, (0, 0, 0, 0))
    for top, bottom, out_top, out_bottom in rows:
        for left, right, out_left, out_right in columns:
            if right <= left or out_right <= out_left or bottom <= top or out_bottom <= out_top:
                continue
            tile = cut.crop((left, top, right, bottom)).resize(
                (out_right - out_left, out_bottom - out_top), Image.LANCZOS)
            plate.paste(tile, (out_left, out_top))
    return plate


def build_card(source_name: str, size: tuple) -> Image.Image:
    cut = _field_keyed(_load(source_name))
    plate = _nine_slice(cut, size, CARD_MARGINS[source_name])
    # The frame is painted cream; keep its alpha, grade only the colour, or the keyed field would be
    # multiplied back into a black card.
    pixels = np.asarray(plate).astype(np.float32)
    pixels[..., :3] = pixels[..., :3] * np.array([0.97, 0.96, 0.93], dtype=np.float32)
    card = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGBA")
    card = card.filter(ImageFilter.UnsharpMask(radius=1.4, percent=45, threshold=2))
    graded = np.asarray(card).astype(np.float32)
    graded[..., :3] = np.asarray(_grain(card.convert("RGB"), 2.0, 37)).astype(np.float32)
    return Image.fromarray(np.clip(graded, 0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    plates = [("ui_board_tray.png", build_tray()),
              ("ui_rail.png", build_rail()),
              ("ui_orb.png", build_round_plate("orb", ORB_SIZE)),
              ("ui_tile_frame.png", build_round_plate("tile", TILE_SIZE))]
    for name, (source_name, size) in CARDS.items():
        plates.append((name, build_card(source_name, size)))
    for name, picture in plates:
        path = os.path.join(OUT, name)
        picture.save(path, optimize=True)
        print("%-22s %dx%d  %6.1f kB" % (name, picture.width, picture.height,
                                         os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
