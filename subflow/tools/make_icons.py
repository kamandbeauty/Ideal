#!/usr/bin/env python3
"""Generate every launcher/adaptive/splash bitmap SubFlow ships.

Input:  assets/branding/app_icon_master.png  (1024x1024, AI-authored brand mark)
Output: android/app/src/main/res/mipmap-*/ic_launcher*.png
        android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
        android/app/src/main/res/mipmap-*/ic_launcher_background.png
        assets/branding/app_icon_512.png (store listing)
        assets/branding/app_icon_1024.png (master, normalised)

The adaptive foreground is derived by keying the flat navy backdrop out of the
master instead of shipping a second, subtly different artwork: one source of
truth for the brand mark. Requires Pillow (`pip install pillow`).
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "assets" / "branding"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

LEgacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

# Colour the mark sits on in the master artwork; also the adaptive background.
BACKDROP = (7, 10, 18)


def load_master() -> Image.Image:
    src = BRANDING / "app_icon_master.png"
    if not src.exists():
        sys.exit(f"missing {src}")
    image = Image.open(src).convert("RGB")
    side = min(image.size)
    left = (image.width - side) // 2
    top = (image.height - side) // 2
    return image.crop((left, top, left + side, top + side)).resize((1024, 1024), Image.LANCZOS)


def key_mark(image: Image.Image) -> Image.Image:
    """Return the brand mark on a transparent canvas.

    Region growing from the border is used instead of a global colour key: the
    artwork has a soft glow that a fixed threshold either keeps (halo) or eats
    (mark edges). Growing across smooth background gradients stops dead at the
    mark's hard edge, so the silhouette is exact.
    """
    width, height = image.size
    px = image.load()
    inside = bytearray(width * height)  # 1 = background
    stack: list[tuple[int, int]] = []
    for x in range(width):
        stack.append((x, 0))
        stack.append((x, height - 1))
    for y in range(height):
        stack.append((0, y))
        stack.append((width - 1, y))
    tolerance = 16
    for x, y in stack:
        inside[y * width + x] = 1
    while stack:
        x, y = stack.pop()
        r, g, b = px[x, y]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            index = ny * width + nx
            if inside[index]:
                continue
            nr, ng, nb = px[nx, ny]
            if max(abs(nr - r), abs(ng - g), abs(nb - b)) > tolerance:
                continue
            inside[index] = 1
            stack.append((nx, ny))

    alpha = Image.new("L", (width, height), 0)
    apx = alpha.load()
    for y in range(height):
        row = y * width
        for x in range(width):
            if not inside[row + x]:
                apx[x, y] = 255
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.7))
    mark = image.convert("RGBA")
    mark.putalpha(alpha)
    bbox = alpha.getbbox()
    if bbox is None:
        sys.exit("keying produced an empty mark")
    mark = mark.crop(bbox)
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    scale = int(1024 * 0.86)
    mark.thumbnail((scale, scale), Image.LANCZOS)
    canvas.paste(mark, ((1024 - mark.width) // 2, (1024 - mark.height) // 2), mark)
    return canvas


def backdrop_layer(size: int) -> Image.Image:
    """Subtle radial glow, same hue family as the mark."""
    layer = Image.new("RGB", (size, size), BACKDROP)
    glow = Image.new("RGB", (size, size), (16, 26, 52))
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse(
        (int(size * 0.16), int(size * 0.10), int(size * 0.92), int(size * 0.86)),
        fill=200,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(size / 5.5))
    layer = Image.composite(glow, layer, mask)
    return layer


def rounded_mask(size: int, radius_ratio: float = 0.22) -> Image.Image:
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * 4 - 1, size * 4 - 1),
        radius=int(size * 4 * radius_ratio),
        fill=255,
    )
    return mask.resize((size, size), Image.LANCZOS)


def circle_mask(size: int) -> Image.Image:
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def main() -> None:
    master = load_master()
    BRANDING.mkdir(parents=True, exist_ok=True)
    master.save(BRANDING / "app_icon_1024.png", optimize=True)
    master.resize((512, 512), Image.LANCZOS).save(BRANDING / "app_icon_512.png", optimize=True)

    # Legacy icon: tighten the frame a little so the mark reads at 48 px.
    crop = int(1024 * 0.94)
    inset = (1024 - crop) // 2
    legacy_src = master.crop((inset, inset, inset + crop, inset + crop))
    mark = key_mark(master)

    for density, size in LEgacy.items():
        folder = RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        square = legacy_src.resize((size, size), Image.LANCZOS).convert("RGBA")
        square.save(folder / "ic_launcher.png", optimize=True)
        rounded = square.copy()
        rounded.putalpha(rounded_mask(size))
        rounded.save(folder / "ic_launcher_round.png", optimize=True)

    for density, size in ADAPTIVE.items():
        folder = RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        backdrop_layer(size).save(folder / "ic_launcher_background.png", optimize=True)
        # Safe zone: keep the mark inside the central 66/108 of the canvas.
        inner = int(size * 0.62)
        fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        scaled = mark.resize((inner, inner), Image.LANCZOS)
        fg.paste(scaled, ((size - inner) // 2, (size - inner) // 2), scaled)
        fg.save(folder / "ic_launcher_foreground.png", optimize=True)

    # Preview sheet for review (not shipped).
    sheet = Image.new("RGB", (1024, 512), (12, 16, 28))
    sheet.paste(master.resize((256, 256), Image.LANCZOS), (32, 96))
    legacy = legacy_src.resize((128, 128), Image.LANCZOS).convert("RGBA")
    legacy_round = legacy.copy()
    legacy_round.putalpha(circle_mask(128))
    sheet.paste(legacy, (336, 160), legacy)
    sheet.paste(legacy_round, (496, 160), legacy_round)
    adapt_fg = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    inner = int(256 * 0.62)
    scaled = mark.resize((inner, inner), Image.LANCZOS)
    adapt_fg.paste(scaled, ((256 - inner) // 2, (256 - inner) // 2), scaled)
    adapted = backdrop_layer(256).convert("RGBA")
    adapted.alpha_composite(adapt_fg)
    adapted.putalpha(circle_mask(256))
    sheet.paste(adapted, (680, 128), adapted)
    sheet.save(BRANDING / "icon-preview.png", optimize=True)
    print("icons written")


if __name__ == "__main__":
    main()
