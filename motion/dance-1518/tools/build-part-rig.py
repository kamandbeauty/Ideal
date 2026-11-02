#!/usr/bin/env python3
"""Turn the painted construction sheet into an articulated cutout rig.

The sheet (assets/parts/parts-b.png) holds each piece of the character as a
separate blob on flat grey: head, bodice, apron, skirt, upper arm, forearm+hand,
lower leg. Because the pieces never touch, they can be lifted out by connected
components — no hand-drawn masks, no bleed from a neighbouring limb.

For every piece we measure the joint it rotates around (a cap centre or the
waist band, as painted) and its true centreline (midpoint of the silhouette
extremes, so a bag or a scarf tail cannot drag it sideways).

Outputs:
  assets/parts/<name>.png   RGBA piece, trimmed
  engine/partrig-data.js    sizes, pivots, tilts, attach points
"""
import json
import math
import os
from collections import deque
from PIL import Image, ImageFilter
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "parts", "parts-b.png")
OUT = os.path.join(ROOT, "assets", "parts")

# name → (component index in left-to-right order, crop fraction of the piece's height)
SHEET = [
    ("head", 0, (0.0, 1.0)),
    ("bodice", 1, (0.0, 1.0)),
    ("apron", 2, (0.0, 1.0)),
    ("skirt", 3, (0.0, 1.0)),
    ("arm", 4, (0.0, 0.44)),      # the sheet draws upper arm + elbow sleeve in one blob
    ("fore", 5, (0.0, 1.0)),
    ("leg", 6, (0.0, 1.0)),
]


def mask_of(rgb):
    bg = np.median(np.concatenate([
        rgb[:5].reshape(-1, 3), rgb[-5:].reshape(-1, 3),
        rgb[:, :5].reshape(-1, 3), rgb[:, -5:].reshape(-1, 3),
    ]), axis=0)
    dist = np.abs(rgb.astype(np.float32) - bg).max(axis=2)
    mean = rgb.astype(np.int16).mean(axis=2)
    sat = rgb.astype(np.int16)
    greyish = (sat.max(axis=2) - sat.min(axis=2) < 6) & (np.abs(mean - 152) < 12)
    return (dist > 20) & ~greyish


def components(m):
    H, W = m.shape
    lab = np.zeros((H, W), np.int32)
    n = 0
    for y in range(H):
        for x in range(W):
            if m[y, x] and lab[y, x] == 0:
                n += 1
                q = deque([(y, x)])
                lab[y, x] = n
                while q:
                    cy, cx = q.popleft()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = n
                            q.append((ny, nx))
    return lab, n


def band_centre(sub, y0, y1):
    band = sub[y0:y1]
    ys, xs = np.where(band)
    if len(xs) == 0:
        return sub.shape[1] / 2.0, float(y0)
    return float((xs.min() + xs.max()) / 2), float(y0 + ys.mean())


def main():
    im = np.asarray(Image.open(SRC).convert("RGB"))
    m = mask_of(im)
    lab, n = components(m)

    comps = []
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if len(xs) < 900:
            continue
        comps.append((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1, i))
    comps.sort()

    src = Image.open(SRC).convert("RGBA")
    parts = {}
    for name, ci, (f0, f1) in SHEET:
        x0, y0, x1, y1, idx = comps[ci]
        piece = (lab[y0:y1, x0:x1] == idx)
        h = piece.shape[0]
        a, b = int(f0 * h), int(f1 * h)
        piece = piece[a:b]
        crop = src.crop((x0, y0 + a, x1, y0 + b))
        alpha = Image.fromarray((piece * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.0))
        crop.putalpha(alpha)
        crop.save(os.path.join(OUT, f"{name}.png"))

        ph, pw = piece.shape
        if name == "head":
            pivot = band_centre(piece, ph - 14, ph)
        elif name == "bodice":
            pivot = band_centre(piece, ph - 14, ph)      # the hip: the bottom of the torso
        else:
            pivot = band_centre(piece, 0, 12)

        tilt = 0.0
        if name in ("arm", "fore", "leg"):
            top = band_centre(piece, 0, 12)
            bot = band_centre(piece, ph - 12, ph)
            tilt = math.degrees(math.atan2(bot[0] - top[0], max(1.0, bot[1] - top[1])))

        parts[name] = {
            "w": pw, "h": ph,
            "px": [round(pivot[0], 1), round(pivot[1], 1)],
            "tilt": round(tilt, 2),
        }
        print(f"{name:7s} {pw}x{ph} pivot=({pivot[0]:.1f},{pivot[1]:.1f}) tilt={tilt:.1f}")

    # bodice: shoulder sockets and the neckline centre, in bodice-local px
    b = parts["bodice"]
    bx0, by0, bx1, by1, bidx = comps[1]
    bm = (lab[by0:by0 + b["h"], bx0:bx1] == bidx)
    top = bm[: int(b["h"] * 0.22)]
    cols = np.where(top.any(axis=0))[0]
    shoulders = [[float(cols.min()) + 12, 26.0], [float(cols.max()) - 12, 26.0]]
    neck = band_centre(bm, 0, 18)

    for side in ("", "R"):
        for name in ("arm", "fore", "leg"):
            img = Image.open(os.path.join(OUT, f"{name}.png"))
            if side == "R":
                img.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(OUT, f"{name}R.png"))

    data = {
        "parts": parts,
        "shoulders": shoulders,
        "neck": [round(neck[0], 1), round(neck[1], 1)],
    }
    with open(os.path.join(ROOT, "engine", "partrig-data.js"), "w") as f:
        f.write("// GENERATED by tools/build-part-rig.py — do not edit by hand.\n")
        f.write("// parts.<n>.{w,h} : trimmed size in px; px: joint the piece turns about (piece-local)\n")
        f.write("// parts.<n>.tilt   : the piece's own lean in the art; rest pose subtracts it\n")
        f.write("// shoulders / neck : in bodice-local px\n")
        f.write("export const PARTS_DATA = " + json.dumps(data, indent=2) + ";\n")
    print("shoulders", shoulders, "neck", neck)


if __name__ == "__main__":
    main()
