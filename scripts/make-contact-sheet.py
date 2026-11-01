#!/usr/bin/env python3
"""Build a 3x2 contact sheet from the six KAMAND review stills.

Usage: python3 scripts/make-contact-sheet.py
Requires: Pillow
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
STILLS = ROOT / "motion" / "kamand-eyebrow-gel" / "stills"
OUT = STILLS / "contact-sheet.jpg"

LABELS = [
    "01  PRODUCT REVEAL",
    "02  BOTANICAL FORMULA",
    "03  NO WHITE RESIDUE",
    "04  NATURAL STYLING",
    "05  HOW TO USE",
    "06  FINAL HERO",
]

CELL_W, CELL_H = 360, 640
PAD, LABEL_H = 18, 40
COLS, ROWS = 3, 2
W = COLS * CELL_W + (COLS + 1) * PAD
H = ROWS * (CELL_H + LABEL_H) + (ROWS + 1) * PAD

sheet = Image.new("RGB", (W, H), (9, 26, 20))
draw = ImageDraw.Draw(sheet)
font = ImageFont.load_default()

for i, label in enumerate(LABELS):
    src = STILLS / f"s{i + 1}.jpg"
    if not src.exists():
        print(f"missing {src}, skipping")
        continue
    im = Image.open(src).convert("RGB")
    im.thumbnail((CELL_W, CELL_H), Image.LANCZOS)
    col, row = i % COLS, i // COLS
    x = PAD + col * (CELL_W + PAD)
    y = PAD + row * (CELL_H + LABEL_H + PAD)
    sheet.paste(im, (x + (CELL_W - im.width) // 2, y))
    draw.text((x + 6, y + CELL_H + 10), label, fill=(217, 181, 107), font=font)

OUT.parent.mkdir(parents=True, exist_ok=True)
sheet.save(OUT, quality=90)
print(f"wrote {OUT} ({sheet.width}x{sheet.height})")
