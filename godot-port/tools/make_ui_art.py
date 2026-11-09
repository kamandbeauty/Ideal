#!/usr/bin/env python3
"""Draws the UI furniture as pictures instead of as code.

The rule for this port is that nothing on screen is a rectangle the engine painted at runtime: every
panel, button, pill, chip, slot, switch track, tile frame and hairline is a PNG that ships in
`assets/ui/`, drawn here once and nine-sliced by Godot. The palette is the same token file the code
reads, so a colour can still be changed in one place — `StyleBoxTexture.modulate_color` tints the
picture.

A plate is not a rounded rectangle with a gradient in it. What makes one read as a physical object is
the stack, in this order: a multi-stop vertical gradient, a bright bevel along the top inside edge, a
dark bevel along the bottom, a gold rim just outside that, a hairline of shadow outside the rim, a
faint grain so the fill is not a flat vector colour, and small corner marks inside the nine-slice's
corner regions so the ornament survives being stretched.

    python3 godot-port/tools/make_ui_art.py

Deterministic: the grain uses a fixed seed, so the same bytes come out on every run. Requires Pillow.
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
GOLD_LIGHT = (247, 214, 140)
ACCENT = (35, 181, 176)
ACCENT_DARK = (18, 133, 127)
DANGER = (240, 115, 90)
DANGER_DARK = (179, 58, 36)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

SS = 4  # supersample factor: everything is drawn big and resampled, so the curves stay clean


# ---- primitives ---------------------------------------------------------------------------------


def _rounded_mask(size, radius, ss=SS):
    w, h = size
    mask = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w * ss - 1, h * ss - 1), radius=radius * ss, fill=255)
    return mask


def _scale(colour, factor):
    """Lighten (factor > 1) or darken (factor < 1) a colour, clamped."""
    return tuple(max(0, min(255, int(round(channel * factor)))) for channel in colour)


def _with_alpha(colour, alpha):
    return (colour[0], colour[1], colour[2], max(0, min(255, int(alpha))))


def gradient(size, radius, stops, ss=SS):
    """A rounded plate filled with a vertical gradient.

    `stops` is a list of (position, colour) with position in 0..1, so the fill is a real curve rather
    than two bands with a seam at the middle.
    """
    w, h = size
    height = h * ss
    column = Image.new("RGBA", (1, height))
    stops = sorted(stops, key=lambda pair: pair[0])
    for y in range(height):
        t = y / max(1, height - 1)
        lower = stops[0]
        upper = stops[-1]
        for index in range(len(stops) - 1):
            if stops[index][0] <= t <= stops[index + 1][0]:
                lower, upper = stops[index], stops[index + 1]
                break
        span = max(1e-6, upper[0] - lower[0])
        mix = (t - lower[0]) / span
        colour = tuple(
            int(round(lower[1][channel] + (upper[1][channel] - lower[1][channel]) * mix))
            for channel in range(3)
        )
        column.putpixel((0, y), colour + (255,))
    body = column.resize((w * ss, height), Image.NEAREST)
    body.putalpha(_rounded_mask(size, radius, ss))
    return body.resize((w, h), Image.LANCZOS)


def bevel(img, radius, top_alpha=90, bottom_alpha=110, inset=1, width=1, ss=SS):
    """A bright line just inside the top edge and a dark one just inside the bottom.

    Both are drawn with a soft vertical falloff, which is what makes a flat plate read as raised.
    """
    w, h = img.size
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    box = (inset * ss, inset * ss, w * ss - 1 - inset * ss, h * ss - 1 - inset * ss)
    r = max(0, radius - inset) * ss
    draw.rounded_rectangle(box, radius=r, outline=_with_alpha(WHITE, top_alpha), width=width * ss)
    dark = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    ImageDraw.Draw(dark).rounded_rectangle(
        box, radius=r, outline=_with_alpha(BLACK, bottom_alpha), width=width * ss
    )
    # Keep the light half of the bright line and the dark half of the shadow: the top of the shape
    # catches light, its bottom sits in shadow.
    fade = Image.new("L", (w * ss, h * ss), 0)
    fade_draw = ImageDraw.Draw(fade)
    for y in range(h * ss):
        t = y / max(1, h * ss - 1)
        fade_draw.line((0, y, w * ss, y), fill=int(255 * max(0.0, 1.0 - t * 1.6)))
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), fade))
    fade_draw.rectangle((0, 0, w * ss, h * ss), fill=0)
    for y in range(h * ss):
        t = y / max(1, h * ss - 1)
        fade_draw.line((0, y, w * ss, y), fill=int(255 * max(0.0, (t - 0.45) * 1.8)))
    dark.putalpha(ImageChops.multiply(dark.getchannel("A"), fade))
    out = img.copy()
    out.alpha_composite(layer.resize((w, h), Image.LANCZOS))
    out.alpha_composite(dark.resize((w, h), Image.LANCZOS))
    return out


def rim(img, radius, colour, width=2, inset=0, ss=SS):
    w, h = img.size
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        (inset * ss, inset * ss, w * ss - 1 - inset * ss, h * ss - 1 - inset * ss),
        radius=max(0, radius - inset) * ss,
        outline=colour + (255,) if len(colour) == 3 else colour,
        width=width * ss,
    )
    out = img.copy()
    out.alpha_composite(layer.resize((w, h), Image.LANCZOS))
    return out


def hairline(img, radius, colour, inset=1, alpha=120, ss=SS):
    w, h = img.size
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        (inset * ss, inset * ss, w * ss - 1 - inset * ss, h * ss - 1 - inset * ss),
        radius=max(0, radius - inset) * ss,
        outline=_with_alpha(colour, alpha),
        width=1 * ss,
    )
    out = img.copy()
    out.alpha_composite(layer.resize((w, h), Image.LANCZOS))
    return out


def gloss_band(img, radius, alpha=54, extent=0.52, ss=SS):
    """The wet-looking highlight across the upper half of a button.

    A flat gradient alone still reads as a vector shape; the moment a soft lighter band fades out
    around the middle, the eye reads enamel over metal.
    """
    w, h = img.size
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    band = int(h * ss * extent)
    steps = 40
    for index in range(steps):
        y0 = int(band * index / steps)
        y1 = int(band * (index + 1) / steps) + 1
        t = index / max(1, steps - 1)
        draw.rectangle((0, y0, w * ss, y1), fill=_with_alpha(WHITE, alpha * (1.0 - t) ** 1.6))
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), _rounded_mask((w, h), radius, ss)))
    out = img.copy()
    out.alpha_composite(layer.resize((w, h), Image.LANCZOS))
    out.putalpha(img.getchannel("A"))
    return out


def grain(img, strength=5, seed=20261109, ss=SS):
    """Deterministic noise, so the fill is a surface and not a vector colour.

    It is clipped to the plate's own alpha, which keeps the corners clean.
    """
    w, h = img.size
    noise = Image.new("L", (w * ss, h * ss))
    pixels = noise.load()
    state = seed
    for y in range(h * ss):
        for x in range(w * ss):
            state = (1103515245 * state + 12345) & 0x7FFFFFFF
            pixels[x, y] = 128 + ((state >> 16) % (2 * strength + 1)) - strength
    noise = noise.resize((w, h), Image.LANCZOS)
    overlay = Image.merge("RGBA", (noise, noise, noise, Image.new("L", (w, h), 26)))
    out = img.copy()
    out.alpha_composite(overlay)
    out.putalpha(img.getchannel("A"))
    return out


def corner_marks(img, radius, colour, inset=5, size=2, alpha=200, ss=SS):
    """A diamond in each corner, drawn inside the corner region of a nine-slice.

    Nine-slicing keeps the corner blocks intact, so these survive being stretched to any size; that is
    what turns a plate into something that looks drawn rather than computed.
    """
    w, h = img.size
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    reach = max(2, size + radius // 2)
    for cx, cy in ((inset + reach // 2, inset + reach // 2),
                   (w - inset - reach // 2, inset + reach // 2),
                   (inset + reach // 2, h - inset - reach // 2),
                   (w - inset - reach // 2, h - inset - reach // 2)):
        x, y = cx * ss, cy * ss
        s = size * ss
        draw.polygon([(x, y - s), (x + s, y), (x, y + s), (x - s, y)],
                     fill=_with_alpha(colour, alpha))
    out = img.copy()
    out.alpha_composite(layer.resize((w, h), Image.LANCZOS))
    out.putalpha(img.getchannel("A"))
    return out


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.save(path, optimize=True)
    print("%-22s %s" % (name + ".png", "%dx%d" % img.size))


# ---- the plate ----------------------------------------------------------------------------------


def plate(name, size, radius, base, edge, rim_colour=None, marks=None, gloss=0.55, grain_strength=5):
    """One plate, built from the same six layers every other plate uses."""
    top = _scale(base, 1.0 + 0.34 * gloss)
    middle = _scale(base, 1.0 + 0.06 * gloss)
    bottom = _scale(base, 1.0 - 0.30 * gloss)
    img = gradient(size, radius, [(0.0, top), (0.46, middle), (1.0, bottom)])
    img = bevel(img, radius, top_alpha=150, bottom_alpha=165)
    img = gloss_band(img, radius, alpha=int(64 * gloss * 2.0))
    img = grain(img, strength=grain_strength)
    img = rim(img, radius, _scale(edge, 0.55), width=1)
    img = rim(img, radius, edge, width=2, inset=1)
    if rim_colour:
        img = hairline(img, radius, rim_colour, inset=4, alpha=210)
    if marks:
        img = corner_marks(img, radius, marks, inset=max(4, radius // 3), size=2)
    save(img, name)


def main():
    # Small plates: 48 dp with a 6 dp nine-slice border, for anything up to 56 dp tall.
    plate("ui_panel_sm", (48, 48), 12, SURFACE, BORDER, rim_colour=GOLD, gloss=0.45)
    plate("ui_panel_raised_sm", (48, 48), 12, RAISED, BORDER, rim_colour=GOLD, gloss=0.6)
    plate("ui_button_sm", (48, 48), 12, RAISED, BORDER, rim_colour=GOLD, gloss=0.6, marks=GOLD)
    plate("ui_button_gold_sm", (48, 48), 12, GOLD, GOLD_DARK, rim_colour=GOLD_LIGHT, gloss=0.7,
          marks=WHITE)
    plate("ui_button_accent_sm", (48, 48), 12, ACCENT, ACCENT_DARK, rim_colour=GOLD, gloss=0.7,
          marks=WHITE)
    plate("ui_button_danger_sm", (48, 48), 12, DANGER, DANGER_DARK, rim_colour=GOLD_LIGHT, gloss=0.7,
          marks=WHITE)

    # Panels and cards: 96 dp with a 20 dp border, so a nine-slice at any size keeps its corners.
    plate("ui_panel", (96, 96), 22, SURFACE, BORDER, rim_colour=GOLD, gloss=0.4, marks=GOLD)
    plate("ui_panel_raised", (96, 96), 22, RAISED, BORDER, rim_colour=GOLD, gloss=0.55, marks=GOLD)
    plate("ui_button", (96, 64), 20, RAISED, BORDER, rim_colour=GOLD, gloss=0.55)
    plate("ui_button_gold", (96, 64), 20, GOLD, GOLD_DARK, rim_colour=GOLD_LIGHT, gloss=0.65,
          marks=WHITE)
    plate("ui_button_accent", (96, 64), 20, ACCENT, ACCENT_DARK, rim_colour=GOLD, gloss=0.65,
          marks=WHITE)
    plate("ui_button_danger", (96, 64), 20, DANGER, DANGER_DARK, rim_colour=GOLD_LIGHT, gloss=0.65,
          marks=WHITE)
    plate("ui_pill", (72, 44), 22, RAISED, BORDER, rim_colour=GOLD, gloss=0.55)
    plate("ui_chip", (64, 32), 16, RAISED, BORDER, rim_colour=GOLD, gloss=0.5)
    plate("ui_slot", (72, 72), 16, SURFACE, BORDER, rim_colour=None, gloss=0.35, marks=BORDER)

    # A row in a list: same plate, a touch flatter, because rows are stacked shoulder to shoulder.
    plate("ui_row", (96, 72), 18, SURFACE, (58, 92, 136), rim_colour=None, gloss=0.25, marks=BORDER)

    # The board's tile: a carved square the gem sits in, with a gold rim and a dark well.
    tile = gradient((72, 72), 14, [(0.0, _scale(SURFACE, 1.45)), (0.5, SURFACE), (1.0, _scale(BG, 1.2))])
    tile = bevel(tile, 14, top_alpha=120, bottom_alpha=150)
    tile = grain(tile, strength=6)
    tile = rim(tile, 14, (58, 96, 140), width=2)
    tile = hairline(tile, 14, GOLD, inset=4, alpha=110)
    tile = corner_marks(tile, 14, GOLD, inset=5, size=2, alpha=150)
    save(tile, "ui_tile_frame")

    # The switch: a track the knob slides in, and a knob that is a knob.
    track_off = gradient((64, 32), 16, [(0.0, (26, 44, 72)), (1.0, (12, 22, 40))])
    track_off = bevel(track_off, 16, top_alpha=60, bottom_alpha=120)
    track_off = grain(track_off, strength=4)
    track_off = rim(track_off, 16, (58, 92, 136), width=2)
    save(track_off, "ui_switch_off")
    track_on = gradient((64, 32), 16, [(0.0, _scale(ACCENT, 1.2)), (1.0, ACCENT_DARK)])
    track_on = bevel(track_on, 16, top_alpha=110, bottom_alpha=110)
    track_on = grain(track_on, strength=4)
    track_on = rim(track_on, 16, GOLD, width=2)
    save(track_on, "ui_switch_on")
    knob = gradient((28, 28), 14, [(0.0, WHITE), (0.55, TEXT), (1.0, (206, 200, 188))])
    knob = bevel(knob, 14, top_alpha=150, bottom_alpha=90)
    knob = rim(knob, 14, (120, 130, 150), width=1)
    save(knob, "ui_knob")

    # Washes and hairlines: pictures too, so nothing full-screen is a ColorRect.
    save(Image.new("RGBA", (8, 8), (255, 255, 255, 255)), "ui_veil")

    rule = Image.new("RGBA", (64, 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(rule)
    for x in range(64):
        t = 1.0 - abs(x - 32) / 32.0  # bright in the middle, transparent at the ends
        d.line((x, 0, x, 3), fill=GOLD + (int(255 * t),))
    save(rule, "ui_rule")

    # The scrollbar: the platform default is a grey rectangle, and grey rectangles are what we are
    # getting rid of.
    bar = gradient((8, 32), 4, [(0.0, (44, 78, 120)), (1.0, (24, 46, 74))])
    save(bar, "ui_scrollbar")
    grabber = gradient((8, 32), 4, [(0.0, GOLD_LIGHT), (1.0, GOLD_DARK)])
    save(grabber, "ui_scrollgrabber")

    # A soft shadow plate a panel can sit on, so depth is a picture and not a StyleBoxFlat shadow.
    shadow = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(shadow)
    d.rounded_rectangle((6, 8, 57, 57), radius=18, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(4))
    save(shadow, "ui_shadow")


if __name__ == "__main__":
    main()
