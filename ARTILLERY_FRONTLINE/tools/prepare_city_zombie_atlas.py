#!/usr/bin/env python3
"""Recolour the CC0 city-zombie albedo atlas for a standard mobile material.

Usage: python tools/prepare_city_zombie_atlas.py upstream-albedo.webp
Requires Pillow and numpy. The upstream renderer tints this unusually dark red
atlas in a custom shader; baking the tint here avoids a shader per zombie.
"""
from pathlib import Path
import sys
import numpy as np
from PIL import Image

img = Image.open(sys.argv[1]).convert('RGB').resize((1024, 512), Image.Resampling.LANCZOS)
srgb = np.asarray(img, dtype=np.float32) / 255.0
linear = np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)
lum = linear @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
h, w = lum.shape
x = np.arange(w)[None, :] / w
y = np.arange(h)[:, None] / h
# The left upper atlas is cloth; the right is skin. Lower-left swatches
# encode eyes and mouth and must not be recoloured.
cloth = (x < 0.5) & (y < 0.68)
swatch = (x < 0.5) & (y >= 0.68)
relative = np.clip(lum / np.where(cloth, 0.0094, 0.0485), 0.0, 1.9) ** 1.35
skin = np.array([0.25, 0.27, 0.22], dtype=np.float32)
fabric = np.array([0.07, 0.085, 0.08], dtype=np.float32)
base = np.where(cloth[..., None], fabric, skin) * relative[..., None]
red = np.clip((linear[..., 0] - np.maximum(linear[..., 1], linear[..., 2])) / np.maximum(linear[..., 0], 0.001), 0, 1)
blood = np.clip((red - 0.90) / 0.08, 0, 1)[..., None] * 0.65
base = base * (1 - blood) + np.array([0.075, 0.009, 0.006], dtype=np.float32) * blood
base = np.where(swatch[..., None], linear, base)
out = np.where(base <= 0.0031308, 12.92 * base, 1.055 * np.maximum(base, 0) ** (1 / 2.4) - 0.055)
path = Path(__file__).resolve().parent.parent / 'assets/textures/zombies/zombie_city.png'
Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(path, optimize=True)
print(path)
