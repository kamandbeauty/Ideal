#!/usr/bin/env python3
"""Draw the game's logotype — «کاخِ شازده» — as a picture, not as a label.

The title screen used to set the name in the UI font at runtime, which means the most important piece
of branding in the game was a string the engine happened to have a font for. This bakes it: Vazir Bold,
shaped and reordered for Persian, filled with the same gold ramp the icon uses, bevelled, dropped onto a
soft shadow and finished with a rule and a small stone. The screen then shows one TextureRect.

Run: python3 godot-port/tools/make_title_art.py
"""

from __future__ import annotations

import os

import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(HERE, "assets", "branding")
FONT = os.path.join(HERE, "assets", "fonts", "Vazir-Bold.ttf")

W, H = 1024, 232          # the plate the home screen scales down; ~3.1x its on-screen 330x52
TITLE = "کاخِ شازده"

GOLD_DEEP = (108, 66, 12)
GOLD = (201, 152, 62)
GOLD_LIGHT = (252, 228, 162)
GOLD_PALE = (255, 246, 214)
INK = (9, 20, 40)


def _shape(text: str) -> str:
    """Join the letters and order them right-to-left, the way a text shaper would."""
    return get_display(arabic_reshaper.reshape(text))


def _gradient(size, top, bottom):
    """A vertical ramp, returned as a mask-friendly RGB image."""
    width, height = size
    ramp = Image.new("RGB", (1, height))
    for y in range(height):
        t = y / max(1, height - 1)
        ramp.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return ramp.resize((width, height), Image.BILINEAR)


def _text_mask(text: str, font: ImageFont.FreeTypeFont, size, offset=(0, 0)):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.text(offset, text, font=font, fill=255)
    return mask


def build() -> Image.Image:
    shaped = _shape(TITLE)

    # Fit the word to the plate with room for the flourish on either side.
    size = 150
    while size > 20:
        font = ImageFont.truetype(FONT, size)
        box = font.getbbox(shaped)
        if box[2] - box[0] <= W * 0.80 and box[3] - box[1] <= H * 0.60:
            break
        size -= 4
    font = ImageFont.truetype(FONT, size)
    box = font.getbbox(shaped)
    text_w, text_h = box[2] - box[0], box[3] - box[1]
    origin = ((W - text_w) // 2 - box[0], (H - text_h) // 2 - box[1] - 8)

    plate = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = _text_mask(shaped, font, (W, H), origin)

    # Shadow: the letters lifted off the sunset behind them.
    shadow = mask.filter(ImageFilter.GaussianBlur(7)).point(lambda v: int(v * 0.75))
    shadow_layer = Image.new("RGBA", (W, H), INK + (255,))
    shadow_layer.putalpha(shadow)
    plate.alpha_composite(shadow_layer, (0, 10))

    # Body: gold, darker at the foot of each letter so the letters look cast, not painted.
    ramp = _gradient((W, H), GOLD_PALE, GOLD_DEEP)
    ramp.putalpha(mask)
    plate.alpha_composite(ramp)

    # Bevel: a lighter copy lifted a couple of pixels and clipped to the letters above their midline,
    # which is what makes the top of every stroke catch the light.
    lift = Image.new("L", (W, H), 0)
    lift.paste(mask, (0, -5))
    upper_band = Image.new("L", (W, H), 0)
    ImageDraw.Draw(upper_band).rectangle((0, 0, W, int(H * 0.52)), fill=255)
    bevel = ImageChops.multiply(ImageChops.subtract(mask, lift), upper_band)
    bevel = bevel.filter(ImageFilter.GaussianBlur(1.2)).point(lambda v: int(v * 0.85))
    bevel_layer = Image.new("RGBA", (W, H), GOLD_LIGHT + (255,))
    bevel_layer.putalpha(bevel)
    plate.alpha_composite(bevel_layer)

    # A dark hairline under the letters gives them an edge against a bright sky without an outline
    # round the whole glyph, which would look like a sticker.
    rim = Image.new("L", (W, H), 0)
    rim.paste(mask, (0, 3))
    rim = ImageChops.subtract(rim, mask).filter(ImageFilter.GaussianBlur(1.0))
    rim_layer = Image.new("RGBA", (W, H), (74, 44, 8, 255))
    rim_layer.putalpha(rim.point(lambda v: int(v * 0.9)))
    plate.alpha_composite(rim_layer)

    # The flourish: a gold rule that fades out, pinned by a stone, under the word.
    flourish = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(flourish)
    y = H - 34
    span = int(W * 0.30)
    cx = W // 2
    for step in range(span):
        t = step / span
        alpha = int(215 * (1.0 - t) ** 1.6)
        colour = GOLD + (alpha,)
        draw.line((cx - 26 - step, y, cx - 26 - step, y), fill=colour)
        draw.line((cx + 26 + step, y, cx + 26 + step, y), fill=colour)
    stone = 11
    draw.ellipse((cx - stone, y - stone, cx + stone, y + stone), fill=GOLD + (240,))
    draw.ellipse((cx - stone + 4, y - stone + 3, cx + stone - 5, y + stone - 6), fill=(36, 174, 164, 255))
    draw.ellipse((cx - 4, y - 6, cx + 1, y - 1), fill=GOLD_PALE + (235,))
    plate.alpha_composite(flourish)
    return plate


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    plate = build()
    path = os.path.join(OUT_DIR, "title_plate.png")
    plate.save(path)
    print("%-24s %dx%d" % ("title_plate.png", plate.width, plate.height))
    # A small copy is what the screen actually draws; look at both before believing either.
    preview = Image.new("RGBA", (W, H + 120), (24, 44, 78, 255))
    preview.alpha_composite(plate, (0, 0))
    preview.alpha_composite(plate.resize((330, int(H * 330 / W)), Image.LANCZOS), (0, H + 24))
    preview.convert("RGB").save("/tmp/title_preview.png")


if __name__ == "__main__":
    main()
