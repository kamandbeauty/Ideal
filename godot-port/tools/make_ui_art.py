#!/usr/bin/env python3
"""Draws the UI furniture as pictures instead of as code.

The rule for this port is that nothing on screen is a rectangle the engine painted at runtime: every
panel, button, pill, chip, slot, switch track and hairline is a PNG that ships in `assets/ui/`, drawn
here once and nine-sliced by Godot. The palette is the same token file the code reads, so a colour can
still be changed in one place — `StyleBoxTexture.modulate_color` tints the picture.

    python3 godot-port/tools/make_ui_art.py

Deterministic: no randomness, no timestamps, same bytes on every run. Requires Pillow.
"""

from __future__ import annotations

import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "ui")

BG = (11, 26, 47)
SURFACE = (20, 41, 74)
RAISED = (29, 58, 97)
BORDER = (44, 78, 120)
TEXT = (247, 242, 230)
MUTED = (191, 203, 219)
GOLD = (224, 169, 63)
GOLD_DARK = (154, 106, 26)
ACCENT = (35, 181, 176)
ACCENT_DARK = (18, 133, 127)
WHITE = (255, 255, 255)

SS = 4  # supersample factor: everything is drawn big and resampled, so the curves stay clean


def rounded(size, radius, fill, outline=None, width=0, ss=SS):
    w, h = size
    img = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(
        (0, 0, w * ss - 1, h * ss - 1),
        radius=radius * ss,
        fill=fill,
        outline=outline,
        width=int(width * ss),
    )
    return img.resize((w, h), Image.LANCZOS)


def vertical_gloss(size, radius, fill, top_light=0.10, bottom_shade=0.14, ss=SS):
    """A rounded plate with a smooth vertical gradient: light at the top edge, shadow at the bottom.
    Baked as a real gradient rather than two bands, because a hard seam reads as a seam."""
    w, h = size
    body = rounded((w, h), radius, fill, ss=ss)
    glow = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    for y in range(h * ss):
        t = y / max(1, h * ss - 1)
        if t < 0.5:
            a = top_light * (1.0 - t / 0.5)
            glow.paste((255, 255, 255, int(255 * a)), (0, y, w * ss, y + 1))
        else:
            a = bottom_shade * ((t - 0.5) / 0.5) ** 1.5
            glow.paste((0, 0, 0, int(255 * a)), (0, y, w * ss, y + 1))
    mask = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w * ss - 1, h * ss - 1), radius=radius * ss, fill=255)
    # Clip the gradient to the plate's shape, then composite it *over* the fill: pasting an alpha layer
    # with its own alpha as the mask would erase the middle of the plate instead of tinting it.
    glow.putalpha(ImageChops.multiply(glow.getchannel("A"), mask))
    body.alpha_composite(glow)
    return body.resize((w, h), Image.LANCZOS)


def inner_edge(size, radius, colour, inset=1, width=1, ss=SS):
    """A one pixel rim drawn just inside the border, which is what makes a flat plate look beveled."""
    w, h = size
    img = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        (inset * ss, inset * ss, w * ss - 1 - inset * ss, h * ss - 1 - inset * ss),
        radius=max(0, radius - inset) * ss,
        outline=colour,
        width=width * ss,
    )
    return img.resize((w, h), Image.LANCZOS)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.save(path, optimize=True)
    print("%-22s %s" % (name + ".png", "%dx%d" % img.size))


def plate(name, size, radius, fill, edge, gloss=True, rim=None):
    img = vertical_gloss(size, radius, fill) if gloss else rounded(size, radius, fill)
    if rim:
        img.alpha_composite(inner_edge(size, radius, rim, inset=2, width=1))
    img.alpha_composite(rounded(size, radius, None, outline=edge, width=2))
    save(img, name)


def main():
    # Panels and cards: border 24 so a nine-slice at any size keeps the corners round.
    plate("ui_panel", (96, 96), 22, SURFACE, BORDER, rim=(255, 255, 255, 26))
    plate("ui_panel_raised", (96, 96), 22, RAISED, BORDER, rim=(255, 255, 255, 30))
    plate("ui_button", (96, 64), 20, RAISED, BORDER, rim=(255, 255, 255, 34))
    plate("ui_button_gold", (96, 64), 20, GOLD, GOLD_DARK, rim=(255, 255, 255, 70))
    plate("ui_button_accent", (96, 64), 20, ACCENT, ACCENT_DARK, rim=(255, 255, 255, 60))
    plate("ui_button_danger", (96, 64), 20, (240, 115, 90), (179, 58, 36), rim=(255, 255, 255, 60))
    plate("ui_pill", (72, 44), 22, RAISED, BORDER, rim=(255, 255, 255, 26))
    plate("ui_chip", (64, 32), 16, RAISED, BORDER, rim=(255, 255, 255, 22))
    plate("ui_slot", (72, 72), 16, SURFACE, BORDER, rim=(255, 255, 255, 18))

    # A row in a list: same plate, a touch flatter, because rows are stacked shoulder to shoulder.
    plate("ui_row", (96, 72), 18, SURFACE, (58, 92, 136), gloss=False, rim=(255, 255, 255, 16))

    # The switch: a track that the knob slides in, and a knob that is a knob.
    track_off = vertical_gloss((64, 32), 16, (18, 32, 56), top_light=0.04, bottom_shade=0.10)
    track_off.alpha_composite(rounded((64, 32), 16, None, outline=(44, 78, 120), width=2))
    save(track_off, "ui_switch_off")
    track_on = vertical_gloss((64, 32), 16, ACCENT_DARK, top_light=0.18, bottom_shade=0.12)
    track_on.alpha_composite(rounded((64, 32), 16, None, outline=ACCENT, width=2))
    save(track_on, "ui_switch_on")
    knob = vertical_gloss((28, 28), 14, TEXT, top_light=0.25, bottom_shade=0.18)
    knob.alpha_composite(rounded((28, 28), 14, None, outline=(120, 130, 150), width=1))
    save(knob, "ui_knob")

    # Washes and hairlines: pictures too, so nothing full-screen is a ColorRect.
    veil = Image.new("RGBA", (8, 8), (255, 255, 255, 255))
    save(veil, "ui_veil")

    rule = Image.new("RGBA", (64, 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(rule)
    for x in range(64):
        t = 1.0 - abs(x - 32) / 32.0  # bright in the middle, transparent at the ends
        d.line((x, 0, x, 3), fill=GOLD + (int(255 * t),))
    save(rule, "ui_rule")

    # The scrollbar: the platform default is a grey rectangle, and grey rectangles are what we are
    # getting rid of.
    bar = rounded((8, 32), 4, (44, 78, 120, 220))
    save(bar, "ui_scrollbar")
    grabber = rounded((8, 32), 4, GOLD)
    save(grabber, "ui_scrollgrabber")

    # A soft shadow plate a panel can sit on, so depth is a picture and not a StyleBoxFlat shadow.
    shadow = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(shadow)
    d.rounded_rectangle((6, 8, 57, 57), radius=18, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(4))
    save(shadow, "ui_shadow")


if __name__ == "__main__":
    main()
