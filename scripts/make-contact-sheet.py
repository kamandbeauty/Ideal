#!/usr/bin/env python3
"""Build a labelled contact sheet from review stills of any story project.

Usage:
  python3 scripts/make-contact-sheet.py --dir projects/next/stills --cols 4
  python3 scripts/make-contact-sheet.py --dir motion/dance-1518/stills \
      --labels-file motion/dance-1518/stills/labels.txt

Requires: Pillow
"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DIR = ROOT / "projects" / "next" / "stills"
CELL_W, CELL_H = 360, 640
PAD, LABEL_H = 18, 40
BG, INK = (11, 9, 8), (243, 193, 121)
EXTS = {".jpg", ".jpeg", ".png", ".webp"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=str(DEFAULT_DIR))
    ap.add_argument("--cols", type=int, default=4)
    ap.add_argument("--labels-file")
    ap.add_argument("--out")
    a = ap.parse_args()

    stills = Path(a.dir)
    images = sorted(p for p in stills.iterdir() if p.suffix.lower() in EXTS)
    if not images:
        raise SystemExit(f"no stills found in {stills}")

    if a.labels_file:
        labels = [l.strip() for l in Path(a.labels_file).read_text().splitlines() if l.strip()]
    else:
        labels = [p.stem for p in images]

    cols = a.cols
    rows = (len(images) + cols - 1) // cols
    W = cols * CELL_W + (cols + 1) * PAD
    H = rows * (CELL_H + LABEL_H) + (rows + 1) * PAD
    sheet = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    for i, src in enumerate(images):
        im = Image.open(src).convert("RGB")
        im.thumbnail((CELL_W, CELL_H), Image.LANCZOS)
        col, row = i % cols, i // cols
        x = PAD + col * (CELL_W + PAD)
        y = PAD + row * (CELL_H + LABEL_H + PAD)
        sheet.paste(im, (x + (CELL_W - im.width) // 2, y))
        draw.text((x + 6, y + CELL_H + 10), labels[i] if i < len(labels) else src.stem,
                  fill=INK, font=font)

    out = Path(a.out) if a.out else stills / "contact-sheet.jpg"
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, quality=90)
    print(f"wrote {out} ({sheet.width}x{sheet.height})")


if __name__ == "__main__":
    main()
