#!/usr/bin/env python3
"""Does the shipped font actually contain every glyph the shaper emits?

This is the seam where the two halves of the Persian work meet: `PersianText` replaces letters with
presentation forms, and the font has to have those exact code points or the player sees boxes. Most
modern Arabic fonts do *not* ship the presentation forms (they rely on GSUB shaping), so this check
is not paranoia — it is the reason Vazir was chosen.

Checks, in order of how badly they break the game:

  1. every presentation form the shaper can emit exists in the font;
  2. every base letter exists (the fallback path emits base letters);
  3. the digits the UI prints exist: Persian ۰-۹, the two Persian separators, ASCII digits and
     Latin letters (a mixed sentence keeps its Latin run);
  4. the punctuation the screens use exists — brackets, guillemets, !, ?, the Persian comma and
     semicolon, the em dash and the minus sign. (No check-mark: Vazir has no U+2713, so the task list
     says «ساخته شد» in words instead. That is exactly the kind of thing this script is for.)

Usage:
    python3 tools/text/check_font.py                     # every TTF under client/Assets/Game/Resources/fonts
    python3 tools/text/check_font.py path/to/font.ttf
"""
from __future__ import annotations

import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FONT_DIR = ROOT / "client" / "Assets" / "Game" / "Resources" / "fonts"

FORM_RANGES = [(0xFE70, 0xFEFC), (0xFB50, 0xFDFF)]
FORMS = ("isolated", "final", "initial", "medial")

# The letters a Persian UI needs. If a font lacks one of these it cannot be the UI font at all.
REQUIRED_LETTERS = "ءاآأإبپتثجچحخدذرزژسشصضطظعغفقکگلمنوهیيةؤئ"

# Punctuation and symbols the screens actually print (see client/Assets/Game/Ui/*.cs).
REQUIRED_PUNCTUATION = "()[]{}«»!?،؛:.,-_—−·٬٫"

# Latin letters and ASCII digits: a mixed sentence keeps its Latin run.
REQUIRED_ASCII = [chr(c) for c in range(ord("0"), ord("9") + 1)] + [chr(c) for c in range(ord("A"), ord("Z") + 1)] + [chr(c) for c in range(ord("a"), ord("z") + 1)]


def build_form_table() -> dict[str, dict[str, str]]:
    table: dict[str, dict[str, str]] = {}
    for lo, hi in FORM_RANGES:
        for cp in range(lo, hi + 1):
            ch = chr(cp)
            decomposition = unicodedata.decomposition(ch)
            if not decomposition.startswith("<"):
                continue
            tag, _, rest = decomposition.partition(">")
            tag = tag.lstrip("<").strip()
            if tag not in FORMS:
                continue
            parts = rest.split()
            if len(parts) != 1:
                continue
            base = chr(int(parts[0], 16))
            if base == ch:
                continue
            table.setdefault(base, {})[tag] = ch
    return table


def check(path: Path) -> list[str]:
    from fontTools.ttLib import TTFont

    errors: list[str] = []
    font = TTFont(str(path), fontNumber=0, lazy=True)
    cmap = font.getBestCmap()

    def missing(chars) -> list[str]:
        return [c for c in chars if ord(c) not in cmap]

    letters = missing(REQUIRED_LETTERS)
    if letters:
        errors.append(f"missing base letters: {names(letters)}")

    table = build_form_table()
    form_misses: list[str] = []
    for base in REQUIRED_LETTERS:
        forms = table.get(base)
        if not forms:
            continue
        for tag, form in forms.items():
            if ord(form) not in cmap:
                form_misses.append(f"{base} {tag} U+{ord(form):04X}")
    if form_misses:
        errors.append(
            f"{len(form_misses)} presentation form(s) missing — the shaper emits them, so they would "
            f"render as boxes: {', '.join(form_misses[:8])}"
        )

    digits = missing([chr(c) for c in range(0x06F0, 0x06FA)])
    if digits:
        errors.append(f"missing Persian digits: {names(digits)}")

    punctuation = missing(REQUIRED_PUNCTUATION)
    if punctuation:
        errors.append(f"missing punctuation: {names(punctuation)}")

    ascii_missing = missing(REQUIRED_ASCII)
    if ascii_missing:
        errors.append(f"missing Latin letters/digits: {names(ascii_missing)}")

    return errors


def names(chars: list[str]) -> str:
    return ", ".join(f"U+{ord(c):04X}" for c in chars)


def main(argv: list[str]) -> int:
    paths = [Path(a) for a in argv] or sorted(FONT_DIR.glob("*.ttf"))
    if not paths:
        print(f"check_font: no .ttf under {FONT_DIR}", file=sys.stderr)
        return 1

    try:
        import fontTools  # noqa: F401
    except ImportError:
        print("check_font: fonttools is missing. pip install -r tools/text/requirements.txt", file=sys.stderr)
        return 2

    failures = 0
    for path in paths:
        if not path.is_file():
            print(f"check_font: {path} does not exist", file=sys.stderr)
            failures += 1
            continue

        errors = check(path)
        label = path.name
        if errors:
            failures += 1
            print(f"FAIL {label}", file=sys.stderr)
            for error in errors:
                print("  - " + error, file=sys.stderr)
        else:
            print(f"  {label}: letters, presentation forms, digits and punctuation all present")

    if failures:
        print(f"\ncheck_font: {failures} font(s) cannot render the UI", file=sys.stderr)
        return 1

    print(f"\ncheck_font: {len(paths)} font(s) can render everything the shaper emits")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
