#!/usr/bin/env python3
"""Build a labelled contact sheet from motion-graphic review stills.

Usage:
  python3 scripts/make-contact-sheet.py                       # first campaign (3x2)
  python3 scripts/make-contact-sheet.py --dir motion/kamand-eye/stills \
      --cols 5 --rows 2 --labels-file motion/kamand-eye/stills/labels.txt

Requires: Pillow
"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DIR = ROOT / "motion" / "kamand-eyebrow-gel" / "stills"
DEFAULT_LABELS = [
    "01  PRODUCT REVEAL", "02  BOTANICAL FORMULA", "03  NO WHITE RESIDUE",
    "04  NATURAL STYLING", "05  HOW TO USE", "06  FINAL HERO",
]

CELL_W, CELL_H = 360, 640
PAD, LABEL_H = 18, 40


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=str(DEFAULT_DIR))
    ap.add_argument("--cols", type=int, default=3)
    ap.add_argument("--rows", type=int, default=2)
    ap.add_argument("--labels-file")
    ap.add_argument("--out")
    a = ap.parse_args()

    stills = Path(a.dir)
    if a.labels_file:
        labels = [l.rstrip("\n") for l in Path(a.labels_file).read_text().splitlines() if l.strip()]
    else:
        labels = DEFAULT_LABELS
    out = Path(a.out) if a.out else stills / "contact-sheet.jpg"

    cols, rows = a.cols, a.rows
    W = cols * CELL_W + (cols + 1) * PAD
    H = rows * (CELL_H + LABEL_H) + (rows + 1) * PAD
    sheet = Image.new("RGB", (W, H), (9, 26, 20))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    for i, label in enumerate(labels[: cols * rows]):
        src = stills / f"s{i + 1}.jpg"
        if not src.exists():
            print(f"missing {src}, skipping")
            continue
        im = Image.open(src).convert("RGB")
        im.thumbnail((CELL_W, CELL_H), Image.LANCZOS)
        col, row = i % cols, i // cols
        x = PAD + col * (CELL_W + PAD)
        y = PAD + row * (CELL_H + LABEL_H + PAD)
        sheet.paste(im, (x + (CELL_W - im.width) // 2, y))
        draw.text((x + 6, y + CELL_H + 10), label, fill=(217, 181, 107), font=font)

    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, quality=90)
    print(f"wrote {out} ({sheet.width}x{sheet.height})")


if __name__ == "__main__":
    main()
