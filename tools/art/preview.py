#!/usr/bin/env python3
"""Build the art review sheet, and check the one rule pixels can prove.

Two things live here:

  * a contact sheet and a self-contained HTML page (images inlined as base64, because the review
    sandbox cannot fetch files) so the set can be looked at as a whole instead of file by file;
  * `--check`, a silhouette test: the pieces must stay distinguishable at 48 px, in greyscale, with
    no colour at all. That is the rule `art/manifest.json` states for piece_firouzeh ("the silhouette
    must stay readable at 48 px") and repeats for the other four. If two stones overlap more than
    the threshold, this fails — which is the failure a human eye tends to miss in greyscale.

Usage:
    python3 tools/art/preview.py            # write art/preview/contact-sheet.png, silhouettes.png,
                                            # index.html and the 48 px test row
    python3 tools/art/preview.py --check    # silhouette gate, exit 1 on failure
"""
from __future__ import annotations

import argparse
import base64
import json
import random
import sys
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "art" / "manifest.json"
ART = ROOT / "client" / "Assets" / "Game" / "Resources" / "art"
OUT = ROOT / "art" / "preview"

PIECES = ["piece_firouzeh", "piece_lajvard", "piece_aqiq", "piece_zomorrod", "piece_morvarid"]

# 48 px is the smallest a piece is ever drawn: seven columns on a phone-width board.
SMALL = 48
# The board, composed the way BoardScreen composes it — offline, so a human can judge the floor
# under the pieces without an 8 GB editor install. Every number here mirrors the C#: the frame is
# nine-sliced at 28 px, the frame is 0.34 of a cell wider than the grid, pieces sit at 94 % of a cell.
MOCK_SIZE = (480, 768)
MOCK_CELL = 40
MOCK_COLS = 9
FRAME_BORDER = 28
PIECE_SCALE = 0.94
OBSTACLE_SCALE = 0.90
POWERUP_SCALE = 0.80

# Two outlines must differ by at least this much (as a fraction of the radius) at some angle.
# Area overlap is the wrong test — two filled blobs always overlap — so the gate compares the
# *outline*: the distance from the centre to the edge, sampled all the way round.
MIN_SHAPE_DIFF = 0.05
ANGLES = 90


def load(asset_id: str) -> Image.Image:
    path = ART / f"{asset_id}.png"
    if not path.exists():
        raise SystemExit(f"preview: {path.relative_to(ROOT)} is missing — run tools/art/gen_art.py")
    return Image.open(path).convert("RGBA")


def silhouette(image: Image.Image, size: int = SMALL) -> Image.Image:
    """Alpha-only, greyscale, on a black ground: exactly what 'reads in greyscale' means."""
    small = image.resize((size, size), Image.LANCZOS)
    mask = small.split()[3].point(lambda v: 255 if v > 96 else 0)
    out = Image.new("L", (size, size), 0)
    out.paste(mask)
    return out


def signature(shape: Image.Image) -> list[float]:
    """Distance from the centre to the edge, sampled at ANGLES around the silhouette."""
    import math

    pixels = shape.load()
    size = shape.size[0]
    centre = size / 2
    out = []
    for i in range(ANGLES):
        angle = 2 * math.pi * i / ANGLES
        radius = 0.0
        step = 0.25
        distance = 0.0
        while distance < centre:
            x = int(centre + distance * math.cos(angle))
            y = int(centre + distance * math.sin(angle))
            if 0 <= x < size and 0 <= y < size and pixels[x, y] > 127:
                radius = distance
            distance += step
        out.append(radius / centre)
    return out


def shape_difference(a: list[float], b: list[float]) -> float:
    """The largest relative difference between two outlines. 0 = identical shape."""
    return max(abs(ra - rb) / max(ra, rb, 1e-6) for ra, rb in zip(a, b))


def check_silhouettes() -> int:
    failures = 0
    shapes = {asset_id: signature(silhouette(load(asset_id))) for asset_id in PIECES}
    for i, first in enumerate(PIECES):
        for second in PIECES[i + 1:]:
            difference = shape_difference(shapes[first], shapes[second])
            if difference < MIN_SHAPE_DIFF:
                print(f"  x {first} and {second} differ by only {difference:.1%} of the radius at "
                      f"{SMALL} px (need {MIN_SHAPE_DIFF:.0%})", file=sys.stderr)
                failures += 1
            else:
                print(f"  . {first} / {second}: {difference:.0%}")
    return failures


def sheet(assets: list[dict], cell: int = 200, cols: int = 6) -> Image.Image:
    rows = (len(assets) + cols - 1) // cols
    pad = 14
    canvas = Image.new("RGBA", (cols * (cell + pad) + pad, rows * (cell + pad) + pad), (11, 26, 47, 255))
    for i, asset in enumerate(assets):
        preview = load(asset["id"])
        preview.thumbnail((cell, cell), Image.LANCZOS)
        x = pad + (i % cols) * (cell + pad) + (cell - preview.width) // 2
        y = pad + (i // cols) * (cell + pad) + (cell - preview.height) // 2
        canvas.alpha_composite(preview, (x, y))
    return canvas


def silhouette_row(assets: list[dict], height: int = 96) -> Image.Image:
    """Every asset as a 48 px black silhouette, on white: the harshest possible read of a shape."""
    pad = 8
    cells = []
    for asset in assets:
        size = min(height, max(48, asset["size"][0]))
        cells.append(silhouette(load(asset["id"]), size))
    width = sum(c.size[0] for c in cells) + pad * (len(cells) + 1)
    canvas = Image.new("L", (width, height + pad * 2), 255)
    x = pad
    for cell_image in cells:
        canvas.paste(cell_image.point(lambda v: 0 if v > 127 else 255),
                     (x, pad + (height - cell_image.height) // 2))
        x += cell_image.size[0] + pad
    return canvas


def fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Cover: scale by the larger ratio, then centre-crop. What the camera does to the floor."""
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))),
                           Image.LANCZOS)
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def nine_slice(sprite: Image.Image, size: tuple[int, int], border: int) -> Image.Image:
    """`SpriteDrawMode.Sliced`, by hand: corners 1:1, edges stretched on one axis, centre on both."""
    width, height = size
    b = min(border, sprite.width // 2, sprite.height // 2)
    sw, sh = sprite.size
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    for sx, sy, dx, dy in ((0, 0, 0, 0), (1, 0, width - b, 0), (0, 1, 0, height - b), (1, 1, width - b, height - b)):
        corner = sprite.crop((sx * (sw - b), sy * (sh - b), sx * (sw - b) + b, sy * (sh - b) + b))
        out.alpha_composite(corner, (dx, dy))

    out.alpha_composite(sprite.crop((b, 0, sw - b, b)).resize((width - 2 * b, b), Image.LANCZOS), (b, 0))
    out.alpha_composite(sprite.crop((b, sh - b, sw - b, sh)).resize((width - 2 * b, b), Image.LANCZOS), (b, height - b))
    out.alpha_composite(sprite.crop((0, b, b, sh - b)).resize((b, height - 2 * b), Image.LANCZOS), (0, b))
    out.alpha_composite(sprite.crop((sw - b, b, sw, sh - b)).resize((b, height - 2 * b), Image.LANCZOS), (width - b, b))
    out.alpha_composite(sprite.crop((b, b, sw - b, sh - b)).resize((width - 2 * b, height - 2 * b), Image.LANCZOS),
                        (b, b))
    return out


def place(canvas: Image.Image, art: Image.Image, centre: tuple[int, int], side: float) -> None:
    size = max(2, round(side))
    scaled = art.resize((size, size), Image.LANCZOS)
    canvas.alpha_composite(scaled, (centre[0] - size // 2, centre[1] - size // 2))


def board_layout() -> list[list[int]]:
    """A plausible board: no three of a stone in a row, so it reads as a real level and not a pattern."""
    rng = random.Random(20261103)
    stones = len(PIECES)
    layout = [[-1] * MOCK_COLS for _ in range(MOCK_COLS)]
    for row in range(MOCK_COLS):
        for col in range(MOCK_COLS):
            choices = list(range(stones))
            rng.shuffle(choices)
            for choice in choices:
                if col >= 2 and layout[row][col - 1] == choice and layout[row][col - 2] == choice:
                    continue
                if row >= 2 and layout[row - 1][col] == choice and layout[row - 2][col] == choice:
                    continue
                layout[row][col] = choice
                break
            if layout[row][col] < 0:
                layout[row][col] = 0
    return layout


def board_mock() -> Image.Image:
    """One frame of the board screen, assembled from the same PNGs the game loads.

    This is the review that a contact sheet cannot give: the floor under the pieces, the frame's
    nine-slice at a real stretch, and every stone at the size it is actually played at.
    """
    width, height = MOCK_SIZE
    canvas = Image.new("RGBA", MOCK_SIZE, (11, 26, 47, 255))
    canvas.alpha_composite(fit(load("board_backdrop_ch01"), MOCK_SIZE))

    grid = MOCK_COLS * MOCK_CELL
    x0 = (width - grid) // 2
    y0 = 120
    margin = round(MOCK_CELL * 0.34)
    canvas.alpha_composite(nine_slice(load("board_frame"), (grid + margin * 2, grid + margin * 2), FRAME_BORDER),
                           (x0 - margin, y0 - margin))

    tile = load("board_tile")
    layout = board_layout()
    obstacles = {(1, 1): "obstacle_frost", (7, 2): "obstacle_crate", (5, 6): "obstacle_ivy"}
    powerups = {(4, 4): "powerup_electro", (2, 7): "powerup_rocket_row"}

    for row in range(MOCK_COLS):
        for col in range(MOCK_COLS):
            cx = x0 + col * MOCK_CELL + MOCK_CELL // 2
            cy = y0 + row * MOCK_CELL + MOCK_CELL // 2
            place(canvas, tile, (cx, cy), MOCK_CELL * 0.98)

            if (col, row) in obstacles:
                place(canvas, load(obstacles[(col, row)]), (cx, cy), MOCK_CELL * OBSTACLE_SCALE)
            elif (col, row) in powerups:
                place(canvas, load(powerups[(col, row)]), (cx, cy), MOCK_CELL * POWERUP_SCALE)
            else:
                place(canvas, load(PIECES[layout[row][col]]), (cx, cy), MOCK_CELL * PIECE_SCALE)

    # the booster bar: five chips, the same 48 dp the game reserves at the bottom of the canvas
    chip, gap = 56, 10
    total = chip * 5 + gap * 4
    left = (width - total) // 2
    bar = Image.new("RGBA", MOCK_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(bar)
    for i, booster in enumerate(["booster_mallet", "booster_ram", "booster_auger", "booster_whirlwind", "booster_falcon"]):
        x = left + i * (chip + gap)
        y = height - 84
        draw.rounded_rectangle((x, y, x + chip, y + chip), radius=14, fill=(20, 41, 74, 255),
                               outline=(196, 154, 62, 255), width=2)
        place(bar, load(booster), (x + chip // 2, y + chip // 2), 40)
    canvas.alpha_composite(bar)

    return canvas


def data_uri(image: Image.Image) -> str:
    buffer = BytesIO()
    image.convert("RGB").save(buffer, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def write_html(assets: list[dict], small_row: Image.Image, mock: Image.Image, path: Path) -> None:
    cards = []
    for asset in assets:
        image = load(asset["id"])
        tag = " · required" if asset.get("required") else ""
        cards.append(
            '<figure class="card">'
            f'<div class="thumb" style="background-image:url({data_uri(image)})"></div>'
            f'<figcaption><b>{asset["id"]}</b><span>{asset["size"][0]}×{asset["size"][1]}{tag}</span>'
            f'<em>{asset.get("description", "")}</em></figcaption>'
            "</figure>")
    html = f"""<!doctype html>
<html lang="fa" dir="rtl"><head><meta charset="utf-8">
<title>کاخ شازده — برگه بازبینی هنری</title>
<style>
 body {{ margin:0; background:#0B1A2F; color:#F7F2E6; font:15px/1.6 system-ui, "Segoe UI", sans-serif; }}
 header {{ padding:28px 32px 8px; }}
 h1 {{ margin:0 0 6px; font-size:22px; font-weight:600; }}
 p {{ margin:0; color:#BFCBDB; max-width:70ch; }}
 .row {{ display:flex; gap:12px; padding:18px 32px; flex-wrap:wrap; }}
 .row img {{ border-radius:10px; background:#fff; }}
 .grid {{ display:grid; grid-template-columns:repeat(auto-fill, minmax(190px, 1fr)); gap:14px; padding:8px 32px 40px; }}
 .card {{ margin:0; background:#14294A; border:1px solid #2C4E78; border-radius:14px; overflow:hidden; }}
 .thumb {{ height:150px; background-color:#0F2138; background-repeat:no-repeat;
           background-position:center; background-size:contain; image-rendering:auto; }}
 figcaption {{ display:flex; flex-direction:column; gap:2px; padding:10px 12px 14px; }}
 figcaption b {{ font-size:13px; letter-spacing:.02em; direction:ltr; text-align:right; }}
 figcaption span {{ font-size:12px; color:#9FB2C9; }}
 figcaption em {{ font-size:12px; color:#BFCBDB; font-style:normal; }}
</style></head><body>
<header>
 <h1>برگه بازبینی هنری — {len(assets)} دارایی</h1>
 <p>هر تصویر با کد ساخته شده است (tools/art/gen_art.py) و با اندازهٔ قرارداد در
    art/manifest.json مطابقت دارد. ردیف زیر همان چیزی است که بازی در بدترین حالت می‌بیند:
    سیلوئت ۴۸ پیکسلی، سیاه روی سفید.</p>
</header>
<div class="row"><img alt="48 px silhouettes" src="{data_uri(small_row)}"></div>
<header>
 <h1>تخته، همان‌طور که بازی می‌سازدش</h1>
 <p>زمینِ فصل، قابِ نُه‌تکه با کششِ واقعی، مهره‌ها در ۹۴٪ خانه و نوار بوسترها — همه از همان
    فایل‌هایی که بازی لود می‌کند، بدون یونیتی. اگر این تصویر شلوغ یا کم‌کنتراست به نظر برسد،
    روی دستگاه هم همین‌طور خواهد بود.</p>
</header>
<div class="row"><img alt="board mock" src="{data_uri(mock)}"></div>
<div class="grid">
{''.join(cards)}
</div>
</body></html>
"""
    path.write_text(html, encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="run the 48 px silhouette gate only")
    args = parser.parse_args(argv)

    assets = json.loads(MANIFEST.read_text(encoding="utf-8"))["assets"]

    if args.check:
        failures = check_silhouettes()
        if failures:
            print(f"preview: {failures} silhouette collision(s) — the stones are too alike", file=sys.stderr)
            return 1
        print(f"preview: the five stones stay distinct at {SMALL} px in greyscale")
        return 0

    OUT.mkdir(parents=True, exist_ok=True)
    sheet(assets).convert("RGB").save(OUT / "contact-sheet.png", "PNG", optimize=True)
    row = silhouette_row(assets)
    row.save(OUT / "silhouettes.png", "PNG", optimize=True)
    mock = board_mock()
    mock.convert("RGB").save(OUT / "board-mock.png", "PNG", optimize=True)
    write_html(assets, row, mock, OUT / "index.html")
    print(f"preview: wrote {OUT.relative_to(ROOT)}/contact-sheet.png, silhouettes.png, board-mock.png, index.html")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
