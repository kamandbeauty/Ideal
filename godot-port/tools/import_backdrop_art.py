#!/usr/bin/env python3
"""Grade the painted backdrops and write the files the game ships.

The five scenes are painted by an image model, once each, and then graded here: resized to the exact
landscape plate the port draws, given the scene's own exposure, a vignette and a little grain. Doing
the grade offline (not in a shader, not with a runtime gradient) keeps the promise that every surface
in the game is a picture, and keeps the result identical on every device.

The ungraded paintings live in `assets/backdrops/source/` and are committed, so this is reproducible:
run the script, get the same five PNGs, byte for byte.

Run: python3 godot-port/tools/import_backdrop_art.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(HERE, "assets", "backdrops", "source")
OUT = os.path.join(HERE, "assets", "backdrops")

W, H = 1476, 830

# exposure  — overall multiply; the board is the darkest because five colours of gem have to be the
#             brightest thing on that screen.
# centre    — extra darkening in the middle, again for the board.
# vignette  — how hard the corners fall off.
# warmth    — >0 pushes toward amber, <0 toward blue.
# grain     — amplitude of the noise, in 8-bit levels.
SCENES = {
    # These five are painted in daylight now: a soft, bright, rounded cartoon hand. The grade is only
    # there to hold the HUD at the edges, so it is a light vignette and a whisper of grain.
    #
    # Cartoon plates are already bright and flat, so the grade is gentle: a touch of vignette to hold
    # the HUD at the edges, a whisper of warmth, and grain fine enough to read as paper.
    "garden_dusk": dict(exposure=1.00, centre=0.00, vignette=0.16, warmth=0.02, grain=1.4, seed=11),
    "hall_night": dict(exposure=0.98, centre=0.06, vignette=0.22, warmth=0.02, grain=1.6, seed=23),
    "map_terrace": dict(exposure=1.00, centre=0.00, vignette=0.14, warmth=0.02, grain=1.4, seed=37),
    "bazaar": dict(exposure=0.99, centre=0.00, vignette=0.18, warmth=0.02, grain=1.5, seed=51),
    "courtyard": dict(exposure=1.00, centre=0.00, vignette=0.16, warmth=0.01, grain=1.4, seed=67),
}


def _graded(name: str, settings: dict) -> Image.Image:
    source = Image.open(os.path.join(SOURCE, name + ".png")).convert("RGB")
    # Cover, not fit: a backdrop must never letterbox, and the model's plates are already 16:9.
    scale = max(W / source.width, H / source.height)
    picture = source.resize((max(W, int(source.width * scale + 0.5)),
                             max(H, int(source.height * scale + 0.5))), Image.LANCZOS)
    left = (picture.width - W) // 2
    top = (picture.height - H) // 2
    picture = picture.crop((left, top, left + W, top + H))
    picture = picture.filter(ImageFilter.UnsharpMask(radius=2.2, percent=58, threshold=2))

    pixels = np.asarray(picture).astype(np.float32) / 255.0

    # Warmth: a gentle split-tone, amber in the highlights and blue in the shadow.
    luma = pixels @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    warm = settings["warmth"]
    pixels[..., 0] += warm * (luma - 0.5) * 0.9
    pixels[..., 2] -= warm * (luma - 0.5) * 1.4

    # Vignette and the optional centre wash, both as a soft radial field.
    ys = (np.arange(H, dtype=np.float32) / H - 0.5) * 2.0
    xs = (np.arange(W, dtype=np.float32) / W - 0.5) * 2.0
    radius = np.sqrt((xs[None, :] ** 2) * 0.82 + (ys[:, None] ** 2) * 0.62)
    corner = np.clip((radius - 0.55) / 0.95, 0.0, 1.0) ** 1.6
    field = 1.0 - settings["vignette"] * corner
    if settings["centre"] > 0.0:
        core = np.clip(1.0 - radius / 0.95, 0.0, 1.0) ** 1.5
        field = field * (1.0 - settings["centre"] * core)
    pixels *= field[:, :, None] * settings["exposure"]

    # Grain, seeded so the file is stable; it also hides the model's own smooth gradients at 1x.
    rng = np.random.default_rng(settings["seed"])
    pixels += rng.normal(0.0, settings["grain"] / 255.0, (H, W, 1)).astype(np.float32)

    return Image.fromarray(np.clip(pixels * 255.0, 0, 255).astype(np.uint8), "RGB")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, settings in SCENES.items():
        picture = _graded(name, settings)
        path = os.path.join(OUT, name + ".png")
        picture.save(path, optimize=True)
        print("%-16s %dx%d  %6.1f kB" % (name + ".png", picture.width, picture.height,
                                         os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
