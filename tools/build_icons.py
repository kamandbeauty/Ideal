#!/usr/bin/env python3
"""Derive every launcher icon from the single generated source artwork."""

from __future__ import annotations

import os
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "icons", "source-icon.png")
DESERT_BG = (232, 175, 98)


def artwork() -> Image.Image:
    """Flood-fill only the outer white rounded-corner margin, leaving clouds intact."""
    image = Image.open(SOURCE).convert("RGB")
    arr = np.asarray(image).copy()
    h, w, _ = arr.shape
    white = (
        arr[:, :, 0].astype(np.int16)
        + arr[:, :, 1].astype(np.int16)
        + arr[:, :, 2].astype(np.int16)
    ) > 725

    exterior = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        if white[0, x]:
            exterior[0, x] = True
            q.append((0, x))
        if white[h - 1, x]:
            exterior[h - 1, x] = True
            q.append((h - 1, x))
    for y in range(h):
        if white[y, 0] and not exterior[y, 0]:
            exterior[y, 0] = True
            q.append((y, 0))
        if white[y, w - 1] and not exterior[y, w - 1]:
            exterior[y, w - 1] = True
            q.append((y, w - 1))

    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < h and 0 <= nx < w and not exterior[ny, nx] and white[ny, nx]:
                exterior[ny, nx] = True
                q.append((ny, nx))

    sky_rgb = np.array([98, 180, 238], dtype=np.uint8)
    sand_rgb = np.array([214, 148, 78], dtype=np.uint8)
    for y in range(h):
        t = y / max(1, h - 1)
        fill = (sky_rgb * (1.0 - t) + sand_rgb * t).astype(np.uint8)
        arr[y, exterior[y]] = fill

    # Slight inset crop so the rounded border seam itself disappears cleanly.
    inset = int(min(w, h) * 0.045)
    side = min(w, h) - 2 * inset
    x0 = (w - side) // 2
    y0 = (h - side) // 2
    return Image.fromarray(arr).crop((x0, y0, x0 + side, y0 + side))


def save(image: Image.Image, relative: str, size: int) -> None:
    path = os.path.join(ROOT, relative)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print(f"  {relative:44s} {size}x{size}")


def main() -> None:
    art = artwork()
    save(art, "assets/icons/icon.png", 512)
    save(art, "assets/icons/launcher_192.png", 192)
    save(art, "documentation/qa/preview/icon.png", 256)

    foreground = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    inner = art.resize((300, 300), Image.LANCZOS).convert("RGBA")
    foreground.paste(inner, ((432 - 300) // 2, (432 - 300) // 2), inner)
    path = os.path.join(ROOT, "assets/icons/adaptive_foreground.png")
    foreground.save(path, optimize=True)
    print(f"  {'assets/icons/adaptive_foreground.png':44s} 432x432")

    background = Image.new("RGB", (432, 432), DESERT_BG)
    background.save(os.path.join(ROOT, "assets/icons/adaptive_background.png"))
    print(f"  {'assets/icons/adaptive_background.png':44s} 432x432")


if __name__ == "__main__":
    main()
