#!/usr/bin/env python3
"""Deterministic, tileable mobile surface maps (no runtime noise shaders)."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / "assets" / "textures"
SIZE = 256


def surface(name, base, grain, seed):
    rng = np.random.default_rng(seed)
    small = rng.normal(0, 1, (SIZE, SIZE))
    # Periodic, low-frequency stains keep all four edges seamless.
    y, x = np.mgrid[0:SIZE, 0:SIZE] * (2 * np.pi / SIZE)
    stains = np.zeros_like(x)
    for frequency, weight in [(1, 1.8), (3, 1.1), (7, 0.55), (17, 0.20)]:
        stains += weight * np.sin(x * frequency + rng.random() * 6.28) * np.cos(
            y * frequency + rng.random() * 6.28
        )
    shade = small * grain + stains * grain * 0.55
    colors = np.array(base)[None, None, :] + shade[..., None]
    if name == "asphalt":
        flecks = rng.random((SIZE, SIZE)) > 0.975
        colors[flecks] += 18
    image = Image.fromarray(np.uint8(np.clip(colors, 0, 255)), "RGB")
    image.save(ROOT / f"{name}.png", optimize=True)


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    surface("asphalt", (133, 143, 150), 4.2, 721)
    surface("concrete", (207, 203, 190), 2.2, 722)
    surface("sand", (219, 193, 150), 2.5, 723)
    surface("plaster", (236, 232, 219), 1.4, 724)
    y, x = np.mgrid[-1:1:complex(SIZE), -1:1:complex(SIZE)]
    alpha = np.clip((1 - (x * x + y * y)) * 0.8, 0, 1) ** 2
    shadow = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    shadow[:, :, 3] = (alpha * 115).astype(np.uint8)
    Image.fromarray(shadow, "RGBA").filter(ImageFilter.GaussianBlur(8)).save(
        ROOT / "contact-shadow.png", optimize=True
    )


if __name__ == "__main__":
    main()
