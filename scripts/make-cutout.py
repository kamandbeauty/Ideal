#!/usr/bin/env python3
"""Remove a near-white studio background from official Kamand product photos.

Flood-fills from the image borders, so interior white areas of the product (the
jar, the gel) are preserved. Writes a transparent PNG with a feathered alpha
edge. The original JPEGs stay untouched in assets/kamand/.

Usage: python3 scripts/make-cutout.py <input.jpg> <output.png> [--threshold 238]
Requires: Pillow
"""
import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


def background_like(px, threshold):
    r, g, b = px[:3]
    lo, hi = min(r, g, b), max(r, g, b)
    return lo >= threshold and (hi - lo) <= 22


def cutout(src, dst, threshold):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    pixels = im.load()
    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()

    seen = bytearray(w * h)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            i = y * w + x
            if not seen[i] and background_like(pixels[x, y], threshold):
                seen[i] = 1
                queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            i = y * w + x
            if not seen[i] and background_like(pixels[x, y], threshold):
                seen[i] = 1
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        ap[x, y] = 0
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                j = ny * w + nx
                if not seen[j] and background_like(pixels[nx, ny], threshold):
                    seen[j] = 1
                    queue.append((nx, ny))

    # Feather the cut edge without shrinking the product.
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.8))
    rgba = im.convert("RGBA")
    rgba.putalpha(alpha)
    bbox = alpha.getbbox()
    if bbox:
        pad = 12
        bbox = (
            max(0, bbox[0] - pad),
            max(0, bbox[1] - pad),
            min(w, bbox[2] + pad),
            min(h, bbox[3] + pad),
        )
        rgba = rgba.crop(bbox)
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    rgba.save(dst)
    print(f"{src} -> {dst}  {rgba.size[0]}x{rgba.size[1]}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--threshold", type=int, default=238)
    a = p.parse_args()
    cutout(a.src, a.dst, a.threshold)
