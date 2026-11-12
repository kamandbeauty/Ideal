#!/usr/bin/env python3
"""Draw the app icon: a gun sight over the wall and the ruined skyline.

    python3 tools/build_icon.py

Requires pillow. Output: assets/textures/icon.png (512 px).
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE, SCALE = 512, 4


def main():
    w = SIZE * SCALE
    img = Image.new("RGB", (w, w), (12, 12, 14))
    draw = ImageDraw.Draw(img)
    for y in range(w):
        f = y / w
        red = int(46 + 150 * max(0.0, f - 0.25) ** 1.2 * 1.3)
        green = int(34 + 70 * max(0.0, f - 0.3) ** 1.3 * 1.3)
        blue = int(40 + 20 * max(0.0, f - 0.4))
        draw.line([(0, y), (w, y)], fill=(min(red, 235), min(green, 130), min(blue, 70)))
    rng = random.Random(7)
    x = 0
    while x < w:
        width = rng.randint(90, 220)
        height = rng.randint(380, 900)
        top = w - 560 - height
        draw.rectangle([x, top, x + width, w], fill=(20, 18, 20))
        for _ in range(3):
            nx = x + rng.randint(0, max(1, width - 60))
            draw.rectangle([nx, top - 2, nx + rng.randint(30, 70), top + rng.randint(30, 110)], fill=img.getpixel((min(w - 1, nx), max(0, top - 6))))
        x += width + rng.randint(4, 30)
    base = w - 620
    draw.rectangle([0, base, w, w], fill=(58, 58, 60))
    merlon = 150
    for i in range(-1, w // (merlon * 2) + 2):
        x0 = i * merlon * 2 + 40
        draw.rectangle([x0, base - 120, x0 + merlon, base], fill=(58, 58, 60))
    draw.rectangle([0, base + 40, w, base + 70], fill=(36, 36, 38))
    for i in range(0, w, 260):
        draw.line([(i, base + 70), (i, w)], fill=(44, 44, 46), width=6)
    cx, cy, radius = w // 2, w // 2 - 60, 620
    amber = (248, 176, 50)
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], outline=amber, width=64)
    draw.ellipse([cx - radius + 150, cy - radius + 150, cx + radius - 150, cy + radius - 150], outline=amber, width=14)
    for angle in (0, 90, 180, 270):
        dx, dy = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        draw.line([(cx + dx * 250, cy + dy * 250), (cx + dx * (radius + 110), cy + dy * (radius + 110))], fill=amber, width=56)
    for offset in (-105, 105):
        glow = Image.new("RGB", (w, w), (0, 0, 0))
        ImageDraw.Draw(glow).ellipse([cx + offset - 70, cy - 40, cx + offset + 70, cy + 40], fill=(230, 40, 24))
        mask = glow.filter(ImageFilter.GaussianBlur(40)).convert("L").point(lambda v: min(255, v * 2))
        img = Image.composite(Image.new("RGB", (w, w), (240, 60, 30)), img, mask)
        draw = ImageDraw.Draw(img)
        draw.ellipse([cx + offset - 52, cy - 26, cx + offset + 52, cy + 26], fill=(255, 96, 50))
        draw.ellipse([cx + offset - 20, cy - 12, cx + offset + 20, cy + 12], fill=(255, 226, 170))
    img.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(PROJECT, "assets", "textures", "icon.png"))
    print("icon.png", SIZE)


if __name__ == "__main__":
    main()
