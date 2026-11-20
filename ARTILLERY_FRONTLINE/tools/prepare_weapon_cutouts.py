#!/usr/bin/env python3
"""Cut transparent turret previews from the existing studio renders.

Requires numpy, opencv-python-headless and Pillow. Run from the project root:
    python tools/prepare_weapon_cutouts.py
The original JPG renders remain a runtime fallback if a cutout is missing.
"""
from pathlib import Path
import cv2
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parent.parent / 'assets/textures/branding/weapons'
# These masks were designed for the five turret renders, not explosive portraits.
for path in [root / f'stand_{gun}.jpg' for gun in ('twin_hmg', 'rotary_gun', 'dual_mauler', 'bushmaster', 'gilded_minigun')]:
    image = cv2.imread(str(path))
    height, width = image.shape[:2]
    mask = np.full((height, width), cv2.GC_BGD, dtype=np.uint8)
    mask[55:height - 4, 45:width - 45] = cv2.GC_PR_BGD
    cv2.ellipse(mask, (int(width * .52), int(height * .81)), (int(width * .45), int(height * .16)), 0, 0, 360, cv2.GC_PR_FGD, -1)
    cv2.ellipse(mask, (int(width * .52), int(height * .43)), (int(width * .39), int(height * .32)), 0, 0, 360, cv2.GC_PR_FGD, -1)
    cv2.rectangle(mask, (int(width * .44), int(height * .32)), (int(width * .57), int(height * .51)), cv2.GC_FGD, -1)
    cv2.rectangle(mask, (int(width * .47), int(height * .68)), (int(width * .55), int(height * .77)), cv2.GC_FGD, -1)
    if path.stem == 'stand_dual_mauler':
        # Clear an empty patch of the old studio under the long barrel.
        mask[int(height * .34):int(height * .42), int(width * .29):int(width * .42)] = cv2.GC_BGD
    background = np.zeros((1, 65), dtype=np.float64)
    foreground = np.zeros((1, 65), dtype=np.float64)
    cv2.grabCut(image, mask, None, background, foreground, 5, cv2.GC_INIT_WITH_MASK)
    alpha = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
    alpha = cv2.GaussianBlur(alpha, (3, 3), .6)
    rgba = cv2.cvtColor(image, cv2.COLOR_BGR2RGBA)
    rgba[:, :, 3] = alpha
    output = path.with_name(path.stem + '_cutout.png')
    Image.fromarray(rgba).save(output, optimize=True)
    print(output)
