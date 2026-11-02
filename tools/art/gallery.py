#!/usr/bin/env python3
"""Build the browsable art gallery: every asset, grouped, on one page.

The review sandbox renders HTML with no network at all, so every PNG goes in as a base64 data
URI. That is why this file exists instead of a page that points at `../../client/.../*.png`: a
relative `src` would load for a developer and show eighty broken boxes for everyone else.

Usage:
    python3 tools/art/gallery.py            # write art/preview/gallery.html
    python3 tools/art/gallery.py --check    # fail if the page is older than the manifest
"""
from __future__ import annotations

import argparse
import base64
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "art" / "manifest.json"
ART = ROOT / "client" / "Assets" / "Game" / "Resources" / "art"
OUT = ROOT / "art" / "preview" / "gallery.html"

# Group order and the Persian name each group is shown under. The ids stay English: they are what
# the code and the manifest call the asset, and a developer reading this page needs to match them.
GROUPS = [
    ("piece", "مهره‌ها"),
    ("ui", "اجزای رابط"),
    ("hud", "نوار بالا و آیکون‌ها"),
    ("powerup", "قدرت‌ها"),
    ("booster", "بوسترها"),
    ("obstacle", "موانع"),
    ("map", "نقشهٔ جهان"),
    ("district", "ناحیه‌ها"),
    ("scene", "صحنه‌ها"),
    ("brand", "برند و فروشگاه"),
    ("prop", "اشیای صحنه"),
]

NOTES = {
    "piece": "هفت مهره، هرکدام یک شکل و یک رنگ؛ تفاوت شکل‌ها باید در ۴۸ پیکسل هم دیده شود.",
    "ui": "قاب‌ها و دکمه‌ها به‌صورت نُه‌تکه برش می‌خورند، پس لبه‌هایشان کشیده نمی‌شود.",
    "hud": "آیکون‌ها تک‌رنگ‌اند تا در هر زمینه‌ای خوانده شوند.",
    "powerup": "پنج قدرت پایه و نسخهٔ پرشدهٔ الکترو.",
    "booster": "نشان‌های بوستر: بدون قاب، چون روی دکمه می‌نشینند.",
    "obstacle": "موانع روی تخته؛ هرکدام یک لایهٔ برداشتن دارند.",
    "map": "نقشهٔ جهان و گره‌هایش: قفل، باز، ستاره‌دار، در حال ساخت.",
    "district": "هر ناحیه دو حال دارد: ساخته‌نشده و ساخته‌شده.",
    "scene": "پس‌زمینه‌های تمام‌صفحه، با جای خالی برای کارت‌ها.",
    "brand": "آیکون برنامه و گرافیک فروشگاه.",
    "prop": "اشیای کوچک صحنه.",
}


def data_uri(path: Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def build() -> str:
    assets = json.loads(MANIFEST.read_text(encoding="utf-8"))["assets"]
    required = sum(1 for a in assets if a.get("required"))

    sections = []
    for group, title in GROUPS:
        members = [a for a in assets if a["group"] == group]
        if not members:
            continue
        cards = []
        for a in members:
            w, h = a["size"]
            aria = "required" if a.get("required") else "optional"
            cards.append(f"""
      <figure class="card">
        <div class="stage" style="--ar:{w}/{h}">
          <img src="{data_uri(ART / (a['id'] + '.png'))}" alt="{a['id']}" loading="lazy">
        </div>
        <figcaption>
          <code>{a['id']}</code>
          <span class="meta">{w}×{h} · {aria}</span>
          <span class="desc">{a.get('description', '')}</span>
        </figcaption>
      </figure>""")
        sections.append(f"""
  <section id="{group}">
    <h2>{title}<span class="count">{len(members)}</span></h2>
    <p class="note">{NOTES.get(group, '')}</p>
    <div class="grid">{''.join(cards)}
    </div>
  </section>""")

    nav = "".join(
        f'<a href="#{g}">{title}</a>'
        for g, title in GROUPS
        if any(a["group"] == g for a in assets))

    return f"""<!doctype html>
<html lang="fa" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>کاخِ شازده — گالری هنری</title>
<style>
  :root {{
    --bg: #0b1622; --panel: #122132; --line: #23405c; --ink: #e8eef6; --soft: #93a9c0;
    --gold: #d7ac5f;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; background: var(--bg); color: var(--ink);
    font: 15px/1.7 "Vazirmatn", "Segoe UI", Tahoma, system-ui, sans-serif;
  }}
  header {{ padding: 28px 24px 10px; border-bottom: 1px solid var(--line); }}
  h1 {{ margin: 0 0 6px; font-size: 24px; letter-spacing: .2px; }}
  h1 small {{ color: var(--gold); font-size: 15px; font-weight: 400; margin-inline-start: 8px; }}
  .lede {{ margin: 0; color: var(--soft); max-width: 70ch; }}
  nav {{ display: flex; flex-wrap: wrap; gap: 8px; padding: 14px 24px; position: sticky; top: 0;
        background: rgba(11,22,34,.94); backdrop-filter: blur(6px); border-bottom: 1px solid var(--line);
        z-index: 2; }}
  nav a {{ color: var(--ink); text-decoration: none; font-size: 13px; padding: 4px 10px;
          border: 1px solid var(--line); border-radius: 999px; }}
  nav a:hover {{ border-color: var(--gold); color: var(--gold); }}
  section {{ padding: 22px 24px 8px; }}
  h2 {{ margin: 0 0 2px; font-size: 18px; display: flex; align-items: center; gap: 10px; }}
  .count {{ font-size: 12px; color: var(--bg); background: var(--gold); border-radius: 999px;
           padding: 1px 8px; font-weight: 600; }}
  .note {{ margin: 0 0 16px; color: var(--soft); font-size: 13px; }}
  .grid {{ display: grid; gap: 14px; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); }}
  .card {{ margin: 0; background: var(--panel); border: 1px solid var(--line); border-radius: 12px;
          overflow: hidden; display: flex; flex-direction: column; }}
  .stage {{ display: grid; place-items: center; padding: 10px; min-height: 132px;
           background:
             repeating-conic-gradient(#0e1c2b 0% 25%, #101f30 0% 50%) 50% / 16px 16px; }}
  .stage img {{ max-width: 100%; max-height: 190px; aspect-ratio: var(--ar);
               image-rendering: auto; }}
  figcaption {{ padding: 8px 10px 10px; display: flex; flex-direction: column; gap: 2px;
               border-top: 1px solid var(--line); }}
  code {{ font: 12px/1.4 ui-monospace, "SF Mono", Menlo, monospace; color: var(--gold);
         direction: ltr; text-align: start; }}
  .meta {{ font-size: 11px; color: var(--soft); direction: ltr; text-align: start; }}
  .desc {{ font-size: 12px; color: var(--soft); }}
  footer {{ padding: 24px; color: var(--soft); font-size: 12px; border-top: 1px solid var(--line); }}
</style>
</head>
<body>
<header>
  <h1>کاخِ شازده <small>گالری هنری</small></h1>
  <p class="lede">{len(assets)} دارایی، {required} تای آن‌ها برای انتشار لازم است. همهٔ تصویرها از
    <code>tools/art/gen_art.py</code> بیرون می‌آیند، پس هر تغییر در کد با یک بازسازی قابل بازبینی است.
    این مجموعه یک ست وکتور تخت و قوی است، نه کار سفارشی یک تصویرگر.</p>
</header>
<nav>{nav}</nav>
{sections}
<footer>ساختهٔ <code>python3 tools/art/gallery.py</code> — تصویرها به‌صورت base64 درون همین فایل‌اند،
  چون صفحهٔ بازبینی به شبکه دسترسی ندارد.</footer>
</body>
</html>
"""


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if the page is stale")
    args = parser.parse_args(argv)

    if args.check:
        if not OUT.exists():
            print("gallery: art/preview/gallery.html is missing", file=sys.stderr)
            return 1
        if OUT.stat().st_mtime < MANIFEST.stat().st_mtime:
            print("gallery: the page is older than art/manifest.json", file=sys.stderr)
            return 1
        print("gallery: art/preview/gallery.html is current")
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(build(), encoding="utf-8")
    print(f"gallery: wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KiB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
