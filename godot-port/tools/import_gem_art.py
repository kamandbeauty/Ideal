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
# How much of the plate a fruit is allowed to fill. The fruit sits inside a board cell with room around
# it, so it is deliberately smaller than the cell: a piece that touches its neighbours reads as a wall
# of colour instead of a board of pieces.
PIECE_BOX = 132
KEY_TOLERANCE = 26  # how near the field colour a pixel has to be to get filled


def _field_colour(plate: Image.Image) -> tuple:
    """The colour the plate was painted on, read off its border.

    Not every painting comes back on black — one lemon plate arrived on white. Keying is always "fill
    what is connected to the edge and close to the field colour", so the colour just has to be read
    rather than assumed.
    """
    # The median of the whole border, not the mean of four corners: one plate came back with a stray UI
    # collage in a corner, and a corner sample then reported the collage's colours as the field.
    pixels = np.asarray(plate).astype(np.float32)
    border = np.concatenate([pixels[0], pixels[-1], pixels[:, 0], pixels[:, -1]])
    return tuple(np.median(border, axis=0))


def _keyed(path: str) -> Image.Image:
    plate = Image.open(path).convert("RGB")
    field = _field_colour(plate)
    # Binarise on the distance to the field colour, then flood from the corners: flood fill only spreads
    # through pixels that are *exactly* the value it started with, so a white highlight *inside* a fruit
    # can never be mistaken for the field. (Keying on brightness afterwards punched a hole through the
    # pearl's highlight once already.)
    pixels = np.asarray(plate).astype(np.int16)
    distance = np.abs(pixels - np.array(field, dtype=np.int16)).max(axis=2)
    # frombytes, not fromarray: an image built on a numpy buffer is read-only in Pillow 13, and a flood
    # fill on it writes nothing at all — the keying silently became a no-op and every piece shipped with
    # its black field still attached.
    field_mask = np.where(distance <= KEY_TOLERANCE, 0, 255).astype(np.uint8)
    binary = Image.frombytes("L", plate.size, field_mask.tobytes())
    for seed in ((0, 0), (plate.width - 1, 0), (0, plate.height - 1),
                 (plate.width - 1, plate.height - 1)):
        ImageDraw.floodfill(binary, seed, 128, thresh=0)
    stone = np.where(np.asarray(binary) == 128, 0, 255).astype(np.uint8)

    # Keep the piece and drop the rest: an image model that slips a couple of letters into the corner
    # of a plate leaves them connected to nothing, and a piece is one object.
    stone = _largest_object(stone)
    # Close the outline and fill the inside. One plate came back with its outline drawn as dashes, and a
    # piece whose edge is dashed reads as a sticker with a cut line around it.
    stone = _solid(stone)

    alpha = Image.fromarray(stone, "L").filter(ImageFilter.GaussianBlur(0.9))
    cut = plate.convert("RGBA")
    cut.putalpha(alpha)
    return cut


def _largest_object(mask: np.ndarray, keep_ratio: float = 0.02) -> np.ndarray:
    """Zero every connected blob except the biggest one (and anything nearly as big as it)."""
    from scipy import ndimage

    labels, count = ndimage.label(mask > 0)
    if count <= 1:
        return mask
    sizes = ndimage.sum(mask > 0, labels, range(1, count + 1))
    biggest = float(sizes.max())
    keep = np.zeros(count + 1, dtype=bool)
    keep[1:] = sizes >= biggest * keep_ratio
    return np.where(keep[labels], mask, 0).astype(np.uint8)


def _solid(mask: np.ndarray, radius: int = 4) -> np.ndarray:
    """Bridge gaps along an outline and fill any hole enclosed by it."""
    from scipy import ndimage

    solid = ndimage.binary_closing(mask > 0, structure=np.ones((radius * 2, radius * 2)))
    # ...and shave anything thin that came with it. A broken outline that closes into a ring leaves its
    # stray dashes as bumps, and a speck of a stray UI collage hanging off a stem is a bump too: both are
    # thinner than the piece, so an opening removes them and leaves the silhouette.
    solid = ndimage.binary_opening(solid, structure=np.ones((radius + 2, radius + 2)))
    solid = ndimage.binary_fill_holes(solid)
    return np.where(solid, 255, 0).astype(np.uint8)


def _centred(cut: Image.Image) -> Image.Image:
    box = cut.getbbox()
    if box is None:
        return cut
    stone = cut.crop(box)
    # Match the pieces by area, not by the longest side: a tall emerald cut and a square cushion with
    # the same width do not look like the same size of stone.
    alpha = np.asarray(stone.getchannel("A")).astype(np.float32) / 255.0
    area = float(alpha.sum())
    target = (PIECE_BOX ** 2) * 0.58
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
