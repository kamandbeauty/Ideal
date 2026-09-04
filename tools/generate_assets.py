#!/usr/bin/env python3
"""
T-Shirt Designer — sample design-asset generator.

Draws original, license-free vector-style artwork (transparent PNGs) for the
plugin's starter design library, across the categories the plugin ships with:
logo, text, sport, animal, nature, kids, fantasy, other.

Everything is drawn at 4x and downsampled for clean anti-aliasing.

Usage: python3 tools/generate_assets.py <output-dir>
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

S = 4          # supersample factor
SZ = 512       # output size
W = SZ * S     # working size

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def canvas():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img = img.resize((SZ, SZ), Image.LANCZOS)
    img.save(path)
    print(f"  {path.name}  {path.stat().st_size // 1024} KB")


def font(size):
    return ImageFont.truetype(FONT_BOLD, size)


def text_center(d, xy, txt, f, fill):
    d.text(xy, txt, font=f, fill=fill, anchor="mm")


def star_points(cx, cy, r_out, r_in, points=5, rot=-90):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180.0 / points)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# ------------------------------------------------------------------ assets

def a_logo_ring():
    img, d = canvas()
    c = (255, 255, 255, 255)
    d.ellipse([W*0.12, W*0.12, W*0.88, W*0.88], outline=c, width=int(W*0.05))
    d.ellipse([W*0.30, W*0.30, W*0.70, W*0.70], fill=c)
    d.line([W*0.30, W*0.78, W*0.70, W*0.78], fill=c, width=int(W*0.05))
    return img


def a_logo_shield():
    img, d = canvas()
    c = (255, 255, 255, 255)
    ac = (220, 38, 38, 255)
    pts = [(W*0.2, W*0.12), (W*0.8, W*0.12), (W*0.8, W*0.55),
           (W*0.5, W*0.9), (W*0.2, W*0.55)]
    d.polygon(pts, fill=c)
    d.polygon([(W*0.30, W*0.22), (W*0.70, W*0.22), (W*0.70, W*0.50),
               (W*0.5, W*0.74), (W*0.30, W*0.50)], fill=ac)
    return img


def a_text_legend():
    img, d = canvas()
    c = (255, 255, 255, 255)
    f1 = font(int(W*0.24))
    f2 = font(int(W*0.13))
    d.text((W/2, W*0.32), "LEGEND", font=f1, fill=c, anchor="mm")
    d.text((W/2, W*0.58), "SINCE 2024", font=f2, fill=(200, 200, 200, 255),
           anchor="mm")
    d.line([W*0.15, W*0.75, W*0.85, W*0.75], fill=c, width=int(W*0.02))
    return img


def a_text_number():
    img, d = canvas()
    c = (255, 255, 255, 255)
    f = font(int(W*0.72))
    d.text((W/2, W*0.42), "01", font=f, fill=c, anchor="mm")
    d.line([W*0.18, W*0.78, W*0.82, W*0.78], fill=c, width=int(W*0.035))
    return img


def a_sport_ball():
    img, d = canvas()
    c = (255, 255, 255, 255)
    d.ellipse([W*0.08, W*0.08, W*0.92, W*0.92], fill=c)
    # soccer pattern: center pentagon + radial lines
    pent = star_points(W/2, W/2, W*0.16, W*0.16*0.82, points=5, rot=-90)
    d.polygon(pent, fill=(20, 20, 20, 255))
    for i in range(5):
        a = math.radians(-90 + i * 72)
        x2 = W/2 + math.cos(a) * W * 0.42
        y2 = W/2 + math.sin(a) * W * 0.42
        d.line([W/2 + math.cos(a)*W*0.16, W/2 + math.sin(a)*W*0.16, x2, y2],
               fill=(20, 20, 20, 255), width=int(W*0.02))
    return img


def a_sport_basketball():
    img, d = canvas()
    c = (234, 88, 32, 255)
    d.ellipse([W*0.08, W*0.08, W*0.92, W*0.92], fill=c)
    k = (30, 30, 30, 255)
    d.line([W*0.08, W/2, W*0.92, W/2], fill=k, width=int(W*0.025))
    d.line([W/2, W*0.08, W/2, W*0.92], fill=k, width=int(W*0.025))
    d.arc([W*0.08, W*0.08, W*0.92, W*0.92], 200, 340, fill=k, width=int(W*0.025))
    d.arc([W*0.08, W*0.08, W*0.92, W*0.92], 20, 160, fill=k, width=int(W*0.025))
    return img


def a_animal_cat():
    img, d = canvas()
    c = (255, 255, 255, 255)
    # head
    d.ellipse([W*0.22, W*0.30, W*0.78, W*0.86], fill=c)
    # ears
    d.polygon([(W*0.24, W*0.40), (W*0.28, W*0.10), (W*0.46, W*0.32)], fill=c)
    d.polygon([(W*0.76, W*0.40), (W*0.72, W*0.10), (W*0.54, W*0.32)], fill=c)
    # eyes + nose + whiskers
    k = (20, 20, 20, 255)
    d.ellipse([W*0.36, W*0.48, W*0.43, W*0.56], fill=k)
    d.ellipse([W*0.57, W*0.48, W*0.64, W*0.56], fill=k)
    d.polygon([(W*0.46, W*0.63), (W*0.54, W*0.63), (W*0.5, W*0.70)], fill=k)
    for dy in (-0.02, 0.0, 0.02):
        d.line([W*0.44, W*(0.65+dy), W*0.20, W*(0.60+dy)], fill=k, width=int(W*0.008))
        d.line([W*0.56, W*(0.65+dy), W*0.80, W*(0.60+dy)], fill=k, width=int(W*0.008))
    return img


def a_animal_paw():
    img, d = canvas()
    c = (255, 255, 255, 255)
    d.ellipse([W*0.28, W*0.42, W*0.72, W*0.88], fill=c)
    for cx, cy, r in ((0.24, 0.34, 0.10), (0.41, 0.22, 0.11),
                      (0.59, 0.22, 0.11), (0.76, 0.34, 0.10)):
        d.ellipse([W*(cx-r), W*(cy-r*1.25), W*(cx+r), W*(cy+r*1.25)], fill=c)
    return img


def a_nature_mountain():
    img, d = canvas()
    c = (255, 255, 255, 255)
    d.polygon([(W*0.05, W*0.85), (W*0.38, W*0.22), (W*0.58, W*0.60),
               (W*0.70, W*0.42), (W*0.95, W*0.85)], fill=c)
    d.polygon([(W*0.30, W*0.38), (W*0.38, W*0.22), (W*0.46, W*0.38),
               (W*0.38, W*0.50)], fill=(120, 160, 220, 255))
    return img


def a_nature_sun():
    img, d = canvas()
    c = (250, 200, 60, 255)
    d.ellipse([W*0.28, W*0.28, W*0.72, W*0.72], fill=c)
    for i in range(12):
        a = math.radians(i * 30)
        x1 = W/2 + math.cos(a) * W * 0.26
        y1 = W/2 + math.sin(a) * W * 0.26
        x2 = W/2 + math.cos(a) * W * 0.46
        y2 = W/2 + math.sin(a) * W * 0.46
        d.line([x1, y1, x2, y2], fill=c, width=int(W*0.03))
    return img


def a_kids_rocket():
    img, d = canvas()
    c = (255, 255, 255, 255)
    r = (220, 60, 60, 255)
    # body
    d.polygon([(W*0.5, W*0.06), (W*0.64, W*0.42), (W*0.60, W*0.72),
               (W*0.40, W*0.72), (W*0.36, W*0.42)], fill=c)
    # fins
    d.polygon([(W*0.36, W*0.50), (W*0.20, W*0.78), (W*0.38, W*0.72)], fill=r)
    d.polygon([(W*0.64, W*0.50), (W*0.80, W*0.78), (W*0.62, W*0.72)], fill=r)
    # window
    d.ellipse([W*0.435, W*0.26, W*0.565, W*0.39], fill=(90, 150, 220, 255))
    # flame
    d.polygon([(W*0.42, W*0.74), (W*0.5, W*0.96), (W*0.58, W*0.74)],
              fill=(250, 180, 60, 255))
    return img


def a_kids_smilestar():
    img, d = canvas()
    y = (250, 210, 70, 255)
    d.polygon(star_points(W/2, W/2, W*0.46, W*0.20), fill=y)
    k = (40, 30, 10, 255)
    d.ellipse([W*0.36, W*0.42, W*0.41, W*0.48], fill=k)
    d.ellipse([W*0.59, W*0.42, W*0.64, W*0.48], fill=k)
    d.arc([W*0.40, W*0.48, W*0.60, W*0.64], 20, 160, fill=k, width=int(W*0.02))
    return img


def a_fantasy_bolt():
    img, d = canvas()
    c = (250, 210, 70, 255)
    d.polygon([(W*0.58, W*0.04), (W*0.24, W*0.56), (W*0.46, W*0.56),
               (W*0.38, W*0.96), (W*0.76, W*0.42), (W*0.52, W*0.42)],
              fill=c)
    return img


def a_fantasy_flame():
    img, d = canvas()
    c = (235, 90, 40, 255)
    d.polygon([(W*0.5, W*0.04), (W*0.66, W*0.34), (W*0.62, W*0.66),
               (W*0.5, W*0.96), (W*0.38, W*0.66), (W*0.34, W*0.34)], fill=c)
    d.polygon([(W*0.5, W*0.34), (W*0.58, W*0.56), (W*0.5, W*0.82),
               (W*0.42, W*0.56)], fill=(250, 200, 80, 255))
    return img


def a_fantasy_crown():
    img, d = canvas()
    c = (250, 200, 60, 255)
    d.polygon([(W*0.12, W*0.72), (W*0.12, W*0.28), (W*0.30, W*0.50),
               (W*0.50, W*0.16), (W*0.70, W*0.50), (W*0.88, W*0.28),
               (W*0.88, W*0.72)], fill=c)
    for cx in (0.22, 0.5, 0.78):
        d.ellipse([W*(cx-0.045), W*(0.78-0.045), W*(cx+0.045), W*(0.78+0.045)],
                  fill=(220, 60, 60, 255))
    return img


def a_other_heart():
    img, d = canvas()
    c = (225, 50, 80, 255)
    d.polygon([(W*0.5, W*0.88), (W*0.10, W*0.48), (W*0.10, W*0.30),
               (W*0.24, W*0.16), (W*0.40, W*0.16), (W*0.5, W*0.30),
               (W*0.60, W*0.16), (W*0.76, W*0.16), (W*0.90, W*0.30),
               (W*0.90, W*0.48)], fill=c)
    return img


def a_other_skull():
    img, d = canvas()
    c = (255, 255, 255, 255)
    d.ellipse([W*0.20, W*0.10, W*0.80, W*0.72], fill=c)
    d.rectangle([W*0.34, W*0.62, W*0.66, W*0.86], fill=c)
    k = (20, 20, 20, 255)
    d.ellipse([W*0.30, W*0.32, W*0.44, W*0.47], fill=k)
    d.ellipse([W*0.56, W*0.32, W*0.70, W*0.47], fill=k)
    d.polygon([(W*0.475, W*0.50), (W*0.525, W*0.50), (W*0.5, W*0.58)], fill=k)
    for i in range(4):
        x = W * (0.38 + i * 0.08)
        d.line([x, W*0.66, x, W*0.82], fill=k, width=int(W*0.016))
    return img


ASSETS = [
    ("logo-ring", "logo", a_logo_ring),
    ("logo-shield", "logo", a_logo_shield),
    ("text-legend", "text", a_text_legend),
    ("text-number-01", "text", a_text_number),
    ("sport-soccer", "sport", a_sport_ball),
    ("sport-basketball", "sport", a_sport_basketball),
    ("animal-cat", "animal", a_animal_cat),
    ("animal-paw", "animal", a_animal_paw),
    ("nature-mountains", "nature", a_nature_mountain),
    ("nature-sun", "nature", a_nature_sun),
    ("kids-rocket", "kids", a_kids_rocket),
    ("kids-smile-star", "kids", a_kids_smilestar),
    ("fantasy-bolt", "fantasy", a_fantasy_bolt),
    ("fantasy-flame", "fantasy", a_fantasy_flame),
    ("fantasy-crown", "fantasy", a_fantasy_crown),
    ("other-heart", "other", a_other_heart),
    ("other-skull", "other", a_other_skull),
]


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("assets")
    out.mkdir(parents=True, exist_ok=True)
    print(f"Generating {len(ASSETS)} sample assets into {out}")
    for name, cat, fn in ASSETS:
        save(fn(), out / f"{name}.png")
    print("done")


if __name__ == "__main__":
    main()
