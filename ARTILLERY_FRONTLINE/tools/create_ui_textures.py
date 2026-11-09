#!/usr/bin/env python3
"""Author the menu interface plates, scrims and ornaments.

Deterministic, dependency-light (numpy + pillow, already required by
create_textures.py) so CI regenerates byte-identical UI furniture. The painted
key art in this folder is generated separately and is not touched here.
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures", "ui")

INK = np.array([16.0, 22.0, 19.0])
OLIVE = np.array([38.0, 48.0, 38.0])
BRASS = np.array([214.0, 172.0, 99.0])


def save(name, array):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(np.clip(array, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name))
    print("UI", name, array.shape[1], "x", array.shape[0])


def grain(shape, amount, seed):
    rng = np.random.default_rng(seed)
    return rng.normal(0.0, amount, shape)


def plate(name, top, bottom, edge, seed, size=96, bevel=10, alpha=232):
    """Nine-patch plate: vertical gradient, brushed grain, lit top bevel."""
    y = np.linspace(0.0, 1.0, size)[:, None, None]
    row = np.array(top)[None, None, :] * (1 - y) + np.array(bottom)[None, None, :] * y
    body = np.repeat(row, size, axis=1)
    body = body + grain((size, size, 1), 2.2, seed)
    # Brushed horizontal streaks read as machined metal rather than flat colour.
    streak = grain((size, 1, 1), 3.0, seed + 1)
    body = body + streak
    yy, xx = np.mgrid[0:size, 0:size]
    dist = np.minimum.reduce([xx, yy, size - 1 - xx, size - 1 - yy]).astype(float)
    rim = np.clip(1.0 - dist / bevel, 0.0, 1.0)[:, :, None]
    lit = (yy < size * 0.5)[:, :, None].astype(float)
    body = body * (1 - rim * 0.55) + np.array(edge)[None, None, :] * rim * (0.35 + 0.45 * lit)
    border = (dist < 1.5)[:, :, None].astype(float)
    body = body * (1 - border) + np.array(edge)[None, None, :] * border
    a = np.full((size, size, 1), float(alpha))
    # Round the corners so the nine-patch does not show hard square edges.
    radius = 12.0
    cx = np.clip(xx, radius, size - 1 - radius)
    cy = np.clip(yy, radius, size - 1 - radius)
    corner = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    a[:, :, 0] *= np.clip(radius - corner + 0.5, 0.0, 1.0)
    save(name, np.concatenate([body, a], axis=2))


def scrim(name, horizontal=True, strength=0.92, size=512):
    """Transparent-to-opaque gradient used to keep text legible over key art."""
    t = np.linspace(0.0, 1.0, size)
    fade = (1.0 - t) ** 1.35 * strength
    if horizontal:
        alpha = np.repeat(fade[None, :], size, axis=0)
    else:
        alpha = np.repeat(fade[:, None], size, axis=1)
    body = np.zeros((size, size, 3)) + np.array([9.0, 13.0, 11.0])[None, None, :]
    save(name, np.concatenate([body, (alpha * 255)[:, :, None]], axis=2))


def vignette(name, size=512):
    yy, xx = np.mgrid[0:size, 0:size]
    d = np.sqrt(((xx - size / 2) / (size / 2)) ** 2 + ((yy - size / 2) / (size / 2)) ** 2)
    alpha = np.clip((d - 0.45) / 0.75, 0.0, 1.0) ** 1.6 * 0.72
    body = np.zeros((size, size, 3))
    save(name, np.concatenate([body, (alpha * 255)[:, :, None]], axis=2))


def divider(name, width=512, height=12):
    """Brass rule with a faded tail, used under Persian headings."""
    x = np.linspace(0.0, 1.0, width)
    fade = np.clip(1.0 - x, 0.0, 1.0) ** 0.7
    body = np.zeros((height, width, 3)) + BRASS[None, None, :]
    core = np.exp(-((np.arange(height) - height / 2) ** 2) / 2.2)
    alpha = (core[:, None] * fade[None, :]) * 235
    save(name, np.concatenate([body, alpha[:, :, None]], axis=2))


def main():
    plate("plate_panel.png", OLIVE * 0.62, INK * 0.95, [96, 108, 84], 11, alpha=236)
    plate("plate_card.png", OLIVE * 0.80, INK * 1.15, [112, 124, 96], 23, alpha=228)
    plate("plate_button.png", [46, 57, 46], [24, 32, 27], [104, 116, 90], 31, alpha=238)
    plate("plate_button_hover.png", [66, 80, 62], [34, 44, 36], BRASS * 0.85, 37, alpha=245)
    plate("plate_button_pressed.png", [30, 39, 31], [18, 24, 20], BRASS * 0.70, 41, alpha=245)
    plate("plate_button_accent.png", BRASS * 0.94, BRASS * 0.62, [255, 226, 168], 43, alpha=250)
    plate("plate_button_accent_hover.png", BRASS * 1.06, BRASS * 0.74, [255, 240, 200], 47, alpha=255)
    plate("plate_disabled.png", [30, 34, 30], [20, 23, 20], [58, 64, 54], 53, alpha=200)
    scrim("scrim_right.png", horizontal=True)
    scrim("scrim_bottom.png", horizontal=False, strength=0.88)
    vignette("vignette.png")
    divider("divider.png")


if __name__ == "__main__":
    main()
