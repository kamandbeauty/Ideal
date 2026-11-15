#!/usr/bin/env python3
"""Create a subtle, seamless brushed-steel modulation for the gun materials.

Original seeded texture. Requires numpy and Pillow; no external source assets.
"""
from pathlib import Path
import numpy as np
from PIL import Image

out = Path(__file__).resolve().parents[1] / 'assets/textures/weapons/gunmetal.png'
rng = np.random.default_rng(17)
n = 256
# Periodic noise, so triplanar tiling has no hard edge. Fine longitudinal
# abrasion is deliberately restrained, leaving the weapon's base colour.
freq = np.fft.fftfreq(n)
fx, fy = np.meshgrid(freq, freq)
raw = rng.normal(size=(n, n))
blur = np.fft.ifft2(np.fft.fft2(raw) * np.exp(-(fx*fx + fy*fy) / (2 * 0.045**2))).real
blur /= max(blur.std(), 1e-6)
rows = rng.normal(0.0, 1.0, n)
rows = (np.roll(rows, 1) + 2*rows + np.roll(rows, -1)) / 4
scratches = np.sin(np.arange(n) * 2*np.pi / 17) * 0.6 + rows * 0.6
value = np.clip(222 + 5.5 * blur + 2.0 * scratches[:, None] + rng.normal(0, 1.8, (n, n)), 196, 241).astype('uint8')
out.parent.mkdir(parents=True, exist_ok=True)
Image.fromarray(value, mode='L').save(out, optimize=True)
print(out)
