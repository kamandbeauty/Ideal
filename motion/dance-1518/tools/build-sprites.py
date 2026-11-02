#!/usr/bin/env python3
"""Cut every painted pose out of its flat-grey studio background and register it.

For each pose we measure, in the source pixels:
  box  – the figure's bounding box
  ax   – horizontal centre of the feet (weighted to the bottom band, so an
         outstretched arm never drags the anchor sideways)
  ay   – the sole line
  ref  – the character's own standing height (from the idle pose)

engine/sprites.js scales every character by REF / ref, so a pose swap can never
change the size of the character on stage.

Writes assets/sprites/*.png and engine/sprites-data.js.
"""
import json
import os
from PIL import Image, ImageFilter
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")

CATALOG = {
    "hero": {
        "srcDir": "assets/hero",
        "height": 1.0,
        "poses": {
            "idle": "hero-front-raw.png",
            "dance-a": "pose-01.png",
            "dance-b": "pose-02.png",
            "dance-c": "pose-03.png",
            "tired": "pose-04.png",
            "fallen": "pose-05.png",
            "wave": "pose-06.png",
        },
        # poses painted at a different body scale need a correction factor
        "k": {"fallen": 0.62},
        # anchor overrides: (ax, ay) in trimmed sprite pixels
        "anchor": {"fallen": ("center", 402)},
    },
    "townsman": {
        "srcDir": "assets/cast",
        "height": 1.06,
        "poses": {
            "idle": "townsman-idle.png",
            "dance": "townsman-dance.png",
            "dance-2": "townsman-dance-2.png",
            "fallen": "townsman-fallen.png",
        },
        "k": {},
        "anchor": {},
    },
    "official": {
        "srcDir": "assets/cast",
        "height": 1.10,
        "poses": {"idle": "official.png"},
        "k": {},
        "anchor": {},
    },
    "musician": {
        "srcDir": "assets/cast",
        "height": 1.02,
        "poses": {"idle": "musician.png"},
        "k": {},
        "anchor": {},
    },
}


def build_mask(rgb: np.ndarray) -> np.ndarray:
    bg = np.median(np.concatenate([
        rgb[:6, :, :].reshape(-1, 3),
        rgb[-6:, :, :].reshape(-1, 3),
        rgb[:, :6, :].reshape(-1, 3),
        rgb[:, -6:, :].reshape(-1, 3),
    ]), axis=0)
    d = np.abs(rgb.astype(np.float32) - bg).max(axis=2)
    m = (d > 20).astype(np.uint8)
    im = Image.fromarray(m * 255, "L")
    im = im.filter(ImageFilter.MedianFilter(5))
    im = im.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    m = (np.asarray(im) > 127)
    return fill_holes(m)


def fill_holes(m: np.ndarray) -> np.ndarray:
    h, w = m.shape
    free = ~m
    seen = np.zeros_like(free)
    stack = [(y, x) for y in range(h) for x in (0, w - 1) if free[y, x]]
    stack += [(y, x) for x in range(w) for y in (0, h - 1) if free[y, x]]
    for y, x in stack:
        seen[y, x] = True
    while stack:
        y, x = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and free[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                stack.append((ny, nx))
    return m | ~seen


def anchors(m: np.ndarray, override):
    h = m.shape[0]
    rows = np.where(m.any(axis=1))[0]
    bottom = int(rows.max())
    if override and override[0] == "center":
        xs = np.where(m[bottom])[0]
        ax = int(round((xs.min() + xs.max()) / 2)) if len(xs) else m.shape[1] // 2
        return ax, int(override[1])
    band = m[max(0, bottom - 34): bottom + 1, :]
    xs = np.where(band)[1] if band.any() else np.where(m)[1]
    return int(round(float(xs.mean()))), bottom + 1


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    data = {}
    for char, cfg in CATALOG.items():
        poses = {}
        heights = {}
        for pose, src in cfg["poses"].items():
            path = os.path.join(ROOT, cfg["srcDir"], src)
            im = Image.open(path).convert("RGB")
            rgb = np.asarray(im)
            m = build_mask(rgb)

            ys, xs = np.where(m)
            box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
            alpha = Image.fromarray((m * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.1))
            sprite = im.convert("RGBA")
            sprite.putalpha(alpha)
            sprite = sprite.crop(box)
            name = f"{char}-{pose}.png"
            sprite.save(os.path.join(OUT, name))

            sub = m[box[1]:box[3], box[0]:box[2]]
            ax, ay = anchors(sub, cfg["anchor"].get(pose))
            heights[pose] = ay
            poses[pose] = {
                "file": name,
                "ax": ax,
                "ay": ay,
                "w": sprite.width,
                "h": sprite.height,
                "k": cfg["k"].get(pose, 1.0),
            }
            print(f"{char:9s} {pose:8s} {sprite.width}x{sprite.height}  anchor=({ax},{ay})")

        ref = poses["idle"]["ay"] if "idle" in poses else max(heights.values())
        data[char] = {"ref": ref, "height": cfg["height"], "poses": poses}

    header = (
        "// GENERATED by tools/build-sprites.py — do not edit by hand.\n"
        "// ref   : character standing height in sprite px (scale registration)\n"
        "// ax,ay : feet anchor inside the trimmed sprite; k: per-pose scale fix\n"
        "export const SPRITES = " + json.dumps(data, indent=2) + ";\n"
    )
    with open(os.path.join(ROOT, "engine", "sprites-data.js"), "w") as f:
        f.write(header)
    print("wrote engine/sprites-data.js")


if __name__ == "__main__":
    main()
