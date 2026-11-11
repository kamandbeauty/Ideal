#!/usr/bin/env python3
"""Give the five tools a face that reads at 36 dp: the reference's cream glyph on a royal orb.

The tools shipped with the port are the Unity medallions — a navy disc, a gold ring and a tool painted
on top in browns and steel. On the tool rail they are drawn inside the blue orb, so the player sees a
navy disc in a gold ring on a blue sphere: three circles, and a glyph that is darker than the thing
under it. At 36 dp that is a smudge, which is exactly how they read in the last capture.

The medallions themselves are pinned art (they are part of the 85 plates and are md5-checked), so this
tool does not touch them. It reads each one, keeps the tool's own silhouette — the part of the picture
that is not the navy field — and paints that silhouette in cream on a royal face with a feathered edge,
so the plate drops onto the orb and reads as one lit sphere. The result is the reference's booster: a
blue button with a pale tool on it, and the gold ring belongs to the orb underneath.

Run: python3 godot-port/tools/import_booster_glyphs.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(HERE, "assets", "art")
OUT = os.path.join(HERE, "assets", "ui")

# The orb plate is 128 px; the glyph plate is drawn at the same size so the two are one picture.
SIZE = 128

# The palette, the same four values `import_plate_art.py` uses. The face is a shade brighter than the
# orb's own sphere, so a lit glyph plate reads as the front of the ball rather than a pasted disc.
ROYAL = (22, 108, 194)
ROYAL_LIGHT = (56, 142, 220)
IVORY_BRIGHT = (255, 249, 235)
CREAM_DARK = (188, 158, 112)

GLYPHS = ["mallet", "ram", "auger", "whirlwind", "falcon"]


def _field_colour(pixels: np.ndarray, inside: np.ndarray) -> np.ndarray:
    """The navy the tool is painted on: the most common colour well inside the disc."""
    sample = pixels[inside]
    # A median is enough here — the field is most of the disc and the tool never is.
    return np.median(sample, axis=0)


def build_glyph(name: str) -> Image.Image:
    source = Image.open(os.path.join(SOURCE, "booster_%s.png" % name)).convert("RGBA")
    source = source.resize((SIZE, SIZE), Image.LANCZOS)
    pixels = np.asarray(source).astype(np.float32)

    alpha = pixels[..., 3] / 255.0
    coords = np.linspace(-1.0, 1.0, SIZE, dtype=np.float32)
    across, down = coords[None, :], coords[:, None]
    radius = np.sqrt(across ** 2 + down ** 2)
    # Only the inner 74 % is read: the medallion's own gold ring is furniture, not part of the tool.
    disc = (radius < 0.80) & (alpha > 0.5)

    field = _field_colour(pixels[..., :3], disc)
    distance = np.linalg.norm(pixels[..., :3] - field[None, None, :], axis=2)
    # The field is flat navy, so anything at all different from it is the tool or its shading.
    tool = (distance > 34.0) & disc
    # Feather the mask so the glyph's own antialiasing survives the recolour.
    mask = Image.fromarray((tool.astype(np.float32) * 255.0).astype(np.uint8), "L")
    mask = mask.filter(ImageFilter.GaussianBlur(0.6))
    coverage = np.asarray(mask).astype(np.float32) / 255.0

    # Cream, by the tool's own luminance: the mallet's gold head stays the brightest part and its
    # brown handle becomes the deepest cream, so the drawing keeps its internal shading.
    luminance = (pixels[..., 0] * 0.30 + pixels[..., 1] * 0.55 + pixels[..., 2] * 0.15) / 255.0
    if tool.any():
        low, high = float(np.percentile(luminance[tool], 4)), float(np.percentile(luminance[tool], 96))
    else:
        low, high = 0.0, 1.0
    span = max(1e-3, high - low)
    graded = np.clip((luminance - low) / span, 0.0, 1.0) ** 0.85
    cream = (np.array(CREAM_DARK, dtype=np.float32)[None, None, :]
             + (np.array(IVORY_BRIGHT, dtype=np.float32) - np.array(CREAM_DARK, dtype=np.float32))[None, None, :] * graded[..., None])

    # The face: royal blue, lit from the upper left, so the plate is the front of the same sphere the
    # orb plate draws rather than a flat coin laid over it.
    # Exactly the orb plate's own sphere field, so the two pictures are one lit ball rather than a
    # disc laid on a ball: the same direction of light, the same two colours.
    light = np.clip(0.62 - 0.46 * (0.50 * across + 0.88 * down), 0.0, 1.0) ** 1.15
    face = (np.array((7, 60, 120), dtype=np.float32)[None, None, :]
            + (np.array((86, 170, 238), dtype=np.float32) - np.array((7, 60, 120), dtype=np.float32))[None, None, :] * light[..., None])

    # The edge fades out past 84 % of the radius, so the plate has no visible rim of its own and the
    # orb's gold ring is the only ring in the picture.
    edge = np.clip((0.95 - radius) / 0.26, 0.0, 1.0)
    face_alpha = np.clip(edge, 0.0, 1.0) * 0.97

    out_rgb = face * (1.0 - coverage[..., None]) + cream * coverage[..., None]
    out_alpha = np.maximum(face_alpha, coverage * edge)
    plate = np.dstack([np.clip(out_rgb, 0, 255), np.clip(out_alpha * 255.0, 0, 255)])
    return Image.fromarray(np.clip(plate, 0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    for name in GLYPHS:
        plate = build_glyph(name)
        path = os.path.join(OUT, "ui_glyph_%s.png" % name)
        plate.save(path, optimize=True)
        print("ui_glyph_%-10s %5.1f kB" % (name, os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
