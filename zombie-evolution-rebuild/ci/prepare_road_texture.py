#!/usr/bin/env python3
"""Prepare the generated road image as a small, edge-blended repeating tile.

Requires Pillow; the source image remains untouched. The runtime uses only the
prepared PNG, not Pillow or this script.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'assets/environment/road_asphalt.png'
target = ROOT / 'assets/environment/road_asphalt_tile.png'
image = Image.open(source).convert('RGB').resize((512, 512), Image.Resampling.LANCZOS)
pixels = image.load()
size = image.width
margin = 40

# Match opposite edges while gradually fading the correction toward the tile
# interior. Both rows/columns in a pair receive the same average at the edge.
for offset in range(margin):
    weight = 0.5 * (1.0 - offset / margin)
    opposite = size - 1 - offset
    for y in range(size):
        a, b = pixels[offset, y], pixels[opposite, y]
        pixels[offset, y] = tuple(round(x * (1 - weight) + z * weight) for x, z in zip(a, b))
        pixels[opposite, y] = tuple(round(z * (1 - weight) + x * weight) for x, z in zip(a, b))
for offset in range(margin):
    weight = 0.5 * (1.0 - offset / margin)
    opposite = size - 1 - offset
    for x in range(size):
        a, b = pixels[x, offset], pixels[x, opposite]
        pixels[x, offset] = tuple(round(v * (1 - weight) + w * weight) for v, w in zip(a, b))
        pixels[x, opposite] = tuple(round(w * (1 - weight) + v * weight) for v, w in zip(a, b))
image.save(target, optimize=True)
print(f'Wrote {target}: {image.size}')
