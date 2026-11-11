#!/usr/bin/env python3
"""Paint the plates the board sits on, and write the files the game ships.

Everything on the board screen is a picture. The four board plates are drawn here, offline, in the
palette the rest of the game uses — royal blue, gold, turquoise and warm ivory — so they can be
re-tuned by editing a constant rather than by repainting a plate:

  ui_board_tray    the table the stones lie on: a royal blue frame with a gold rim, and one bright
                   ivory tile per playfield cell, each with its own depth and shadow.
  ui_rail          the capsule panel down each side of the board — a royal blue shell with a gold rim,
                   a turquoise inlay and a warm ivory face. Both rails are the same plate.
  ui_orb           the round tool button: a turquoise-to-royal sphere in a gold metallic ring.
  ui_tile_frame    the cell a stone rests in: a bright ivory square with a gold rim.

The two card plaques on the home and district screens are still the painted source image, graded here
into the same ivory.

Run: python3 godot-port/tools/import_plate_art.py
"""

from __future__ import annotations

import os

import math

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(HERE, "assets", "ui", "source")
OUT = os.path.join(HERE, "assets", "ui")

# The tray is drawn at 408 dp, so the plate ships at twice that.
TRAY_SIZE = 816
# The two rails are drawn at 118x388 dp; the orb and the cell at 64 and 42 dp. Everything ships at two
# times the size it is drawn, so a 3x screen still has pixels to spend.
RAIL_SIZE = (236, 776)
ORB_SIZE = 128
TILE_SIZE = 128
# How near-black a plate's field has to be before the key fills it.
KEY_TOLERANCE = 26

# ---- palette ------------------------------------------------------------------------------------
# One palette for every plate in the game, and it is the one the design tokens name: royal blue for
# structure, gold for every edge, turquoise for the second line a Persian frame always carries, warm
# ivory for the face a player reads on. No brown: a warm shadow under a warm plate is the one thing
# that turns cartoon chrome into a photograph of brass.
ROYAL = (18, 99, 181)
ROYAL_DARK = (7, 60, 120)
ROYAL_LIGHT = (58, 148, 226)
TURQUOISE = (32, 198, 196)
TURQUOISE_DARK = (14, 130, 130)
GOLD = (245, 190, 67)
GOLD_DARK = (176, 120, 28)
GOLD_LIGHT = (255, 226, 150)
WHITE = (255, 255, 255)
TEAL = (42, 176, 200)
TEAL_DARK = (18, 120, 146)
IVORY = (255, 241, 212)
IVORY_BRIGHT = (255, 249, 235)
IVORY_SHADE = (233, 217, 183)

# The two card plaques are painted 16:9-ish and the cards are 2.6:1 and 0.81:1, so a plain stretch would
# turn the painted corner medallions into ellipses. They are nine-sliced here, in the tool, at the size
# the screens draw them (330x126 and 232x286 dp, doubled): the corners keep their shape, the plain bands
# between them take up the difference, and the shipped plate is already the card's exact shape, so the
# screens still stretch it whole and never slice it at runtime.
CARD_MARGINS = {
    "card_wide": (0.20, 0.42),
    "card_tall": (0.22, 0.34),
}
CARDS = {
    "ui_card_frame.png": ("card_wide", (660, 252)),
    "ui_card_tall.png": ("card_tall", (464, 572)),
}

# How much of the painted carpet is kept: the centre only. The painting's border is a wide geometric
# band — beautiful, and 60 dp of playfield if shipped whole. Keeping the middle 68% thins it to about
# 18 dp at the size the board is drawn, which frames the grid instead of competing with it.
# Where the 9 x 9 grid starts inside the board plate, as a fraction of the plate: BoardScreen puts the
# grid 15 dp into a 408 dp plate.
BOARD_INSET = 15.0 / 408.0


def _load(name: str) -> Image.Image:
    return Image.open(os.path.join(SOURCE, name + ".png")).convert("RGB")


def _grain(picture: Image.Image, amount: float, seed: int) -> Image.Image:
    pixels = np.asarray(picture).astype(np.float32) / 255.0
    rng = np.random.default_rng(seed)
    height, width = pixels.shape[:2]
    pixels = pixels + rng.normal(0.0, amount / 255.0, (height, width, 1)).astype(np.float32)
    return Image.fromarray(np.clip(pixels * 255.0, 0, 255).astype(np.uint8), "RGB")


def _field_keyed(source: Image.Image) -> Image.Image:
    """Cut a plate off its black field.

    Binarise first: flood fill only spreads through pixels *exactly* equal to the value it started
    with, so a bright highlight inside the painted object can never be mistaken for background.
    """
    grey = source.convert("L")
    binary = grey.point(lambda value: 0 if value <= KEY_TOLERANCE else 255)
    for seed in ((0, 0), (source.width - 1, 0), (0, source.height - 1),
                 (source.width - 1, source.height - 1)):
        ImageDraw.floodfill(binary, seed, 128, thresh=0)
    keep = np.where(np.asarray(binary) == 128, 0, 255).astype(np.uint8)
    alpha = Image.fromarray(keep, "L").filter(ImageFilter.GaussianBlur(0.7))
    cut = source.convert("RGBA")
    cut.putalpha(alpha)
    box = cut.getbbox()
    return cut.crop(box) if box is not None else cut


def _mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def _column(stops, height):
    """A one-pixel-wide vertical gradient, `stops` being [(position, colour)]."""
    column = Image.new("RGBA", (1, height))
    stops = sorted(stops, key=lambda pair: pair[0])
    for y in range(height):
        t = y / max(1, height - 1)
        low, high = stops[0], stops[-1]
        for index in range(len(stops) - 1):
            if stops[index][0] <= t <= stops[index + 1][0]:
                low, high = stops[index], stops[index + 1]
                break
        span = max(1e-6, high[0] - low[0])
        column.putpixel((0, y), _mix(low[1], high[1], (t - low[0]) / span) + (255,))
    return column


def _plate(size, radius, stops, ss=3):
    """A rounded plate filled with a smooth vertical gradient, drawn big and resampled."""
    width, height = size
    body = _column(stops, height * ss).resize((width * ss, height * ss), Image.NEAREST)
    mask = Image.new("L", (width * ss, height * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width * ss - 1, height * ss - 1),
                                           radius=radius * ss, fill=255)
    body.putalpha(mask)
    return body.resize((width, height), Image.LANCZOS)


def _rim(picture, radius, colour, width=2, inset=0):
    """A crisp line just inside the edge of the picture's own shape."""
    ss = 3
    w, h = picture.size
    layer = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        (inset * ss, inset * ss, w * ss - 1 - inset * ss, h * ss - 1 - inset * ss),
        radius=max(0, radius - inset) * ss, outline=colour + (255,), width=width * ss)
    layer = layer.resize((w, h), Image.LANCZOS)
    out = picture.copy()
    out.alpha_composite(layer)
    return out


def build_tray() -> Image.Image:
    """The board's table: a royal frame, and one bright ivory tile per playfield cell.

    A cell has to read as a socket at 42 dp, which is where the last version failed: the face and the
    field were four values apart and the fruits floated. Here every tile carries its own drop shadow,
    a bright top edge and a warmer bottom edge, so the grid is legible even under a full board, and the
    gold rim round the frame is the only ornament that competes with the fruit.

    Every measurement below is in the plate's own pixels: TRAY_SIZE is 2x the 408 dp the board draws it
    at, so `size * 0.03` is 12 dp of painting.
    """
    size = TRAY_SIZE
    radius = int(size * 0.075)
    # A cream frame with one gold line, like the reference: the board is the brightest thing on the
    # screen, and a blue frame round it made the grid look like a panel on a dashboard.
    picture = _plate((size, size), radius, [(0.0, (255, 250, 234)), (0.42, IVORY),
                                            (1.0, _mix(IVORY, (243, 220, 176), 0.5))])
    picture = _rim(picture, radius, _mix(GOLD_DARK, (168, 124, 52), 0.4), width=3)
    picture = _rim(picture, radius, GOLD, width=2, inset=int(size * 0.009))

    # The bed the tiles sit in: a shade darker than the tiles, so the gaps read as gaps. It stops at the
    # grid (which starts 15 dp in), so the royal frame keeps a band of its own all the way round.
    inner = int(size * 0.022)
    bed = _plate((size - inner * 2, size - inner * 2), int(size * 0.050),
                 [(0.0, (232, 210, 172)), (1.0, (246, 231, 200))])
    bed = _rim(bed, int(size * 0.050), _mix(GOLD, IVORY_SHADE, 0.35), width=2)
    picture.alpha_composite(bed, (inner, inner))

    inset = size * BOARD_INSET
    pitch = (size - inset * 2) / 9.0
    # Tighter gaps and a squarer corner: the reference's cells read as a grid of shallow trays, and a
    # wide gap with a round corner reads as a scatter of pebbles.
    gap = max(2.0, pitch * 0.055)
    cell_radius = int(pitch * 0.17)
    tile_side = int(pitch - gap)

    # Bright at the top and only a shade warmer at the bottom: a tile that goes brown by its lower edge
    # is what made the last board look dusty under a full grid of fruit.
    face = _plate((tile_side, tile_side), cell_radius,
                  [(0.0, (255, 254, 250)), (0.50, (255, 250, 238)), (1.0, (250, 236, 208))])
    # A bright bevel along the top edge: the one line that makes a flat square read as a socket.
    bevel = Image.new("RGBA", (tile_side, tile_side), (0, 0, 0, 0))
    ImageDraw.Draw(bevel).rounded_rectangle((2, 2, tile_side - 3, tile_side - 3),
                                            radius=cell_radius, outline=(255, 255, 255, 165), width=2)
    face.alpha_composite(bevel.filter(ImageFilter.GaussianBlur(0.5)))
    warm = Image.new("RGBA", (tile_side, tile_side), (0, 0, 0, 0))
    ImageDraw.Draw(warm).rounded_rectangle((2, int(tile_side * 0.72), tile_side - 3, tile_side - 3),
                                           radius=cell_radius, fill=(*_mix(GOLD_DARK, IVORY_SHADE, 0.5), 40))
    face.alpha_composite(warm.filter(ImageFilter.GaussianBlur(1.6)))
    face = _rim(face, cell_radius, _mix(GOLD, GOLD_LIGHT, 0.45), width=2)

    shadow = Image.new("RGBA", (tile_side + 12, tile_side + 12), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((6, 7, tile_side + 5, tile_side + 6), radius=cell_radius,
                                             fill=(*ROYAL_DARK, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(2.4))

    for row in range(9):
        for column in range(9):
            x = int(round(inset + column * pitch + gap * 0.5))
            y = int(round(inset + row * pitch + gap * 0.5))
            picture.alpha_composite(shadow, (x - 6, y - 6))
            picture.alpha_composite(face, (x, y))

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    picture.putalpha(mask)
    return _grain(picture.convert("RGB"), 2.0, 11)


def _ornament(size, centre, radius, petal=(TEAL, GOLD, TEAL_DARK)):
    """The gold-and-turquoise flower the reference puts on the crest and the foot of a rail."""
    picture = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(picture)
    cx, cy = centre
    for index in range(6):
        angle = math.tau * index / 6.0
        px = cx + math.cos(angle) * radius * 0.62
        py = cy + math.sin(angle) * radius * 0.62
        draw.ellipse((px - radius * 0.46, py - radius * 0.46, px + radius * 0.46, py + radius * 0.46),
                     fill=petal[0] + (255,), outline=petal[1] + (255,), width=max(1, int(radius * 0.09)))
    draw.ellipse((cx - radius * 0.42, cy - radius * 0.42, cx + radius * 0.42, cy + radius * 0.42),
                 fill=petal[2] + (255,), outline=petal[1] + (255,), width=max(1, int(radius * 0.10)))
    return picture.filter(ImageFilter.SMOOTH)


def build_rail() -> Image.Image:
    """The capsule panel both rails use, dressed like the reference.

    Out: a turquoise band with a gold line on either side of it. In: a warm ivory face. On the crest
    and at the foot: the flower the reference hangs on both. The royal blue tab is a separate plate —
    it carries a Persian word, so it is drawn whole and placed over the top of this one.
    """
    width, height = RAIL_SIZE
    radius = width // 2
    band = _plate((width, height), radius, [(0.0, _mix(TEAL, WHITE, 0.25)), (0.35, TEAL),
                                            (1.0, TEAL_DARK)])
    band = _rim(band, radius, GOLD_DARK, width=3)
    band = _rim(band, radius, GOLD, width=2, inset=5)

    margin = 24
    face_radius = radius - margin
    face = _plate((width - margin * 2, height - margin * 2), face_radius,
                  [(0.0, (255, 250, 236)), (0.30, IVORY), (1.0, _mix(IVORY, (247, 226, 186), 0.55))])
    face = _rim(face, face_radius, GOLD, width=2)
    face = _rim(face, face_radius, (255, 236, 176), width=1, inset=4)
    band.alpha_composite(face, (margin, margin))

    # The foot: a flower that overhangs the band, drawn last so it sits on top of the frame.
    foot = _ornament((width, width), (width // 2, width // 2), int(width * 0.17))
    band.alpha_composite(foot, (0, height - width - 6))
    return band.filter(ImageFilter.UnsharpMask(radius=1.2, percent=40, threshold=2))


def build_header_tab() -> Image.Image:
    """The royal blue tab a rail's heading is written on: a rounded shield with a peaked top.

    Drawn whole at the size the screens place it (104 x 34 dp), because a nine-slice would smear the
    peak. The two rails are the same width, so one plate serves both.
    """
    width, height = 208, 76
    picture = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    body = _plate((width, height - 10), 26, [(0.0, _mix(ROYAL_LIGHT, ROYAL, 0.15)),
                                             (0.45, ROYAL), (1.0, ROYAL_DARK)])
    body = _rim(body, 26, GOLD_DARK, width=3)
    body = _rim(body, 26, GOLD, width=2, inset=4)
    picture.alpha_composite(body, (0, 10))
    # The peak: a triangle sitting on the body's top edge, gold-rimmed, with the gem in its middle.
    draw = ImageDraw.Draw(picture)
    peak = [(width // 2, 0), (width // 2 + 46, 24), (width // 2 - 46, 24)]
    draw.polygon(peak, fill=_mix(ROYAL_LIGHT, ROYAL, 0.55) + (255,), outline=GOLD + (255,))
    draw.line(peak + [peak[0]], fill=GOLD_DARK + (255,), width=3)
    draw.polygon([(width // 2, 6), (width // 2 + 30, 22), (width // 2 - 30, 22)],
                 outline=GOLD_LIGHT + (200,), width=2)
    draw.ellipse((width // 2 - 10, 3, width // 2 + 10, 23), fill=(150, 60, 190, 255),
                 outline=GOLD_LIGHT + (255,), width=3)
    return picture.filter(ImageFilter.UnsharpMask(radius=1.2, percent=40, threshold=2))


def build_piece_shadow(size: int = 128) -> Image.Image:
    """The soft pool of shadow a fruit sits in, so the board has depth and not a wall of stickers."""
    picture = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    painter = ImageDraw.Draw(picture)
    painter.ellipse((size * 0.16, size * 0.30, size * 0.84, size * 0.86), fill=(150, 96, 30, 110))
    return picture.filter(ImageFilter.GaussianBlur(size * 0.055))


def build_booster_disc(size: int = 128) -> Image.Image:
    """The light disc a tool's dark glyph sits on, inside the blue orb."""
    disc = _plate((size, size), size // 2, [(0.0, (255, 253, 246)), (0.62, IVORY_BRIGHT),
                                            (1.0, _mix(IVORY_BRIGHT, (244, 227, 190), 0.7))])
    disc = _rim(disc, size // 2, (255, 235, 175), width=2, inset=2)
    return disc


def build_round_plate(name: str, size: int) -> Image.Image:
    """The two round plates: the tool button and the cell frame, both drawn and both real circles."""
    if name == "orb":
        picture = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        radius = size / 2.0
        ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(ring)
        # A metallic band, bright at the top left and deep at the bottom right: that falloff is the only
        # cue that says gold rather than yellow.
        # A metal band, not a pale halo: the ring only occupies the outer eighth of the plate, so the
        # gold lives there and the gradient runs across that band alone.
        ring_outer = radius
        ring_inner = radius * 0.78
        for step in range(int(ring_inner), int(ring_outer)):
            t = max(0.0, min(1.0, (step - ring_inner) / max(1.0, ring_outer - ring_inner)))
            colour = _mix((255, 226, 150), (150, 96, 18), t ** 0.8)
            draw.ellipse((step, step, size - 1 - step, size - 1 - step), outline=colour + (255,))
        draw.ellipse((int(ring_inner) - 2, int(ring_inner) - 2, size - 1 - int(ring_inner) + 2,
                      size - 1 - int(ring_inner) + 2), outline=(90, 56, 10, 210), width=2)
        draw.ellipse((1, 1, size - 2, size - 2), outline=(120, 78, 16, 200), width=2)
        picture.alpha_composite(ring)
        sphere_size = int(size * 0.78)
        sphere = Image.new("RGBA", (sphere_size, sphere_size), (0, 0, 0, 0))
        paint = ImageDraw.Draw(sphere)
        half = sphere_size / 2.0
        for step in range(int(half), 0, -1):
            t = 1.0 - step / half  # 0 at the rim, 1 at the centre
            # Royal blue with a turquoise rim light: the reference's boosters are blue buttons, and the
            # turquoise belongs to the frame around them.
            paint.ellipse((half - step, half - step, half + step, half + step),
                          fill=_mix(ROYAL_LIGHT, ROYAL_DARK, t) + (255,))
        # One small, sharp highlight and one thin rim light at the bottom: a big soft blob in the
        # middle of the sphere reads as a smudge on a blue marble.
        shine = Image.new("RGBA", (sphere_size, sphere_size), (0, 0, 0, 0))
        ImageDraw.Draw(shine).ellipse((sphere_size * 0.22, sphere_size * 0.14,
                                      sphere_size * 0.46, sphere_size * 0.30),
                                     fill=(255, 255, 255, 190))
        sphere.alpha_composite(shine.filter(ImageFilter.GaussianBlur(sphere_size * 0.022)))
        rim = Image.new("RGBA", (sphere_size, sphere_size), (0, 0, 0, 0))
        ImageDraw.Draw(rim).ellipse((sphere_size * 0.12, sphere_size * 0.34,
                                     sphere_size * 0.88, sphere_size * 0.94),
                                    outline=(140, 235, 240, 90), width=max(2, int(sphere_size * 0.03)))
        sphere.alpha_composite(rim.filter(ImageFilter.GaussianBlur(sphere_size * 0.02)))
        picture.alpha_composite(sphere, (int((size - sphere_size) / 2), int((size - sphere_size) / 2)))
        return _rim(picture, int(radius), GOLD_LIGHT, width=2, inset=int(size * 0.09))

    plate = _plate((size, size), int(size * 0.22), [(0.0, IVORY_BRIGHT), (0.6, IVORY),
                                                    (1.0, _mix(IVORY, IVORY_SHADE, 0.5))])
    plate = _rim(plate, int(size * 0.22), GOLD, width=3, inset=1)
    plate = _rim(plate, int(size * 0.22), _mix(GOLD_LIGHT, IVORY, 0.35), width=1,
                 inset=int(size * 0.07))
    return plate


def _nine_slice(cut: Image.Image, size: tuple, margins: tuple) -> Image.Image:
    """Stretch the plain bands of a painted plaque, never its corners.

    Each of the nine regions is scaled separately: the four corners are placed at one common scale, so
    a painted medallion keeps its circle, and the four edge bands and the middle take up the rest of
    the target. Without this a 16:9 plaque drawn into a 2.6:1 card turns every ornament oval.
    """
    target_w, target_h = size
    width, height = cut.size
    scale = min(target_w / float(width), target_h / float(height))
    source_x = max(1, int(width * margins[0]))
    source_y = max(1, int(height * margins[1]))
    corner_x = min(target_w // 2, max(1, int(source_x * scale)))
    corner_y = min(target_h // 2, max(1, int(source_y * scale)))
    columns = [(0, source_x, 0, corner_x),
               (source_x, width - source_x, corner_x, target_w - corner_x),
               (width - source_x, width, target_w - corner_x, target_w)]
    rows = [(0, source_y, 0, corner_y),
            (source_y, height - source_y, corner_y, target_h - corner_y),
            (height - source_y, height, target_h - corner_y, target_h)]
    plate = Image.new("RGBA", size, (0, 0, 0, 0))
    for top, bottom, out_top, out_bottom in rows:
        for left, right, out_left, out_right in columns:
            if right <= left or out_right <= out_left or bottom <= top or out_bottom <= out_top:
                continue
            tile = cut.crop((left, top, right, bottom)).resize(
                (out_right - out_left, out_bottom - out_top), Image.LANCZOS)
            plate.paste(tile, (out_left, out_top))
    return plate


def build_card(source_name: str, size: tuple) -> Image.Image:
    cut = _field_keyed(_load(source_name))
    plate = _nine_slice(cut, size, CARD_MARGINS[source_name])
    # The painted card is parchment, and parchment is brown: the palette replaced brown with warm
    # ivory everywhere else, so the texture is kept and the colour is graded into the same ivory the
    # rest of the plates use. The alpha is left alone — the keyed field must stay keyed.
    pixels = np.asarray(plate).astype(np.float32)
    rgb = pixels[..., :3]
    luminance = rgb.mean(axis=2, keepdims=True) / 255.0
    ivory = np.array(IVORY, dtype=np.float32)[None, None, :] / 255.0
    graded_rgb = np.clip(ivory * (0.70 + 0.38 * luminance) * 255.0, 0, 255)
    # The frame is turquoise and the field is parchment, and only the field may be graded: a pixel with
    # more blue than red is part of the frame and keeps its colour.
    frame = (rgb[..., 2] > rgb[..., 0] + 12)[..., None]
    pixels[..., :3] = np.where(frame, rgb, rgb * 0.30 + graded_rgb * 0.70)
    plate = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGBA")
    card = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGBA")
    card = card.filter(ImageFilter.UnsharpMask(radius=1.4, percent=45, threshold=2))
    graded = np.asarray(card).astype(np.float32)
    graded[..., :3] = np.asarray(_grain(card.convert("RGB"), 2.0, 37)).astype(np.float32)
    return Image.fromarray(np.clip(graded, 0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    plates = [("ui_board_tray.png", build_tray()),
              ("ui_booster_disc.png", build_booster_disc()),
              ("ui_header_tab.png", build_header_tab()),
              ("ui_piece_shadow.png", build_piece_shadow()),
              ("ui_rail.png", build_rail()),
              ("ui_orb.png", build_round_plate("orb", ORB_SIZE)),
              ("ui_tile_frame.png", build_round_plate("tile", TILE_SIZE))]
    for name, (source_name, size) in CARDS.items():
        plates.append((name, build_card(source_name, size)))
    for name, picture in plates:
        path = os.path.join(OUT, name)
        picture.save(path, optimize=True)
        print("%-22s %dx%d  %6.1f kB" % (name, picture.width, picture.height,
                                         os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
