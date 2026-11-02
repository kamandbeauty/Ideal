#!/usr/bin/env python3
"""A second implementation of Shazdeh.Core.Text.PersianText, in Python.

Why a twin? Because the C# cannot run in this sandbox, and "the Persian looks right" is not something
a reviewer can check by reading code. This script implements the same two steps with the same tables,
so that:

  * the golden strings in client/Assets/Core.Tests/PersianTextTests.cs are generated, not typed by
    hand — if the C# disagrees with them CI says so;
  * the shaping can be compared against `arabic-reshaper` (a well-tested implementation of the same
    Unicode rules) on every string the game ships. If they disagree, ours is wrong.

Usage:
    python3 tools/text/persian_ref.py --vectors      # C# arrays for the test file
    python3 tools/text/persian_ref.py --check        # shaped output vs arabic-reshaper, + table check
    python3 tools/text/persian_ref.py "متن"          # show the three steps for one string
"""
from __future__ import annotations

import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FORM_RANGES = [(0xFE70, 0xFEFC), (0xFB50, 0xFDFF)]
FORMS = ("isolated", "final", "initial", "medial")

ZWNJ = "\u200c"
TATWEEL = "\u0640"
LAM = "\u0644"
ALEF = "\u0627"
LAM_ALEF_ISOLATED = "\ufefb"
LAM_ALEF_FINAL = "\ufefc"
PERSIAN_ZERO, PERSIAN_NINE = "\u06f0", "\u06f9"
THOUSANDS = "\u066c"
DECIMAL = "\u066b"
MIRROR = {"(": ")", ")": "(", "[": "]", "]": "[", "{": "}", "}": "{",
          "<": ">", ">": "<", "\u00ab": "\u00bb", "\u00bb": "\u00ab"}


def build_forms():
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
            table.setdefault(base, {})[tag] = ch
    return table


FORMS_TABLE = build_forms()


def join_type(ch: str) -> str:
    forms = FORMS_TABLE.get(ch)
    if not forms:
        return "None"
    if "medial" in forms and "initial" in forms:
        return "Dual"
    if "final" in forms:
        return "Right"
    return "None"


def is_transparent(ch: str) -> bool:
    if ch == TATWEEL or ch == ZWNJ:
        return False
    if unicodedata.category(ch) in ("Mn", "Me"):
        return True
    cp = ord(ch)
    return 0x06D6 <= cp <= 0x06ED or cp in (0x0653, 0x0654, 0x0655, 0x0670)


def is_letter(ch: str) -> bool:
    return ch in FORMS_TABLE


def form_of(ch: str, joins_previous: bool, joins_next: bool) -> str:
    forms = FORMS_TABLE.get(ch)
    if not forms:
        return ch
    if joins_previous and joins_next:
        candidate = forms.get("medial")
    elif joins_previous:
        candidate = forms.get("final")
    elif joins_next:
        candidate = forms.get("initial")
    else:
        candidate = forms.get("isolated")
    if candidate:
        return candidate
    if joins_previous and forms.get("final"):
        return forms["final"]
    return forms.get("isolated", ch)


def skip_transparent(text: str, index: int) -> int:
    while index < len(text) and is_transparent(text[index]):
        index += 1
    return index


def next_letter(text: str, index: int) -> str:
    i = skip_transparent(text, index + 1)
    while i < len(text):
        ch = text[i]
        if ch == ZWNJ:
            return ""
        if is_transparent(ch):
            i += 1
            continue
        if is_letter(ch) or ch == TATWEEL:
            return ch
        return ""
    return ""


def joins_previous(text: str, index: int) -> bool:
    i = index - 1
    while i >= 0:
        ch = text[i]
        if is_transparent(ch):
            i -= 1
            continue
        if ch == ZWNJ:
            return False
        if ch == TATWEEL:
            return True
        if not is_letter(ch):
            return False
        return join_type(ch) == "Dual" and join_type(text[index]) != "None"
    return False


def joins_next(text: str, index: int) -> bool:
    if join_type(text[index]) != "Dual":
        return False
    nxt = next_letter(text, index)
    if nxt == "":
        return False
    if nxt == TATWEEL:
        return True
    return join_type(nxt) != "None"


def shape(text: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == ZWNJ:
            i += 1
            continue
        if not is_letter(ch) and ch != TATWEEL:
            out.append(ch)
            i += 1
            continue
        if ch == TATWEEL:
            out.append(ch)
            i += 1
            continue

        previous = joins_previous(text, i)
        following = joins_next(text, i)

        if ch == LAM and following and next_letter(text, i) == ALEF:
            out.append(LAM_ALEF_FINAL if previous else LAM_ALEF_ISOLATED)
            i = skip_transparent(text, i + 2)  # skip the alef it absorbed
            continue

        out.append(form_of(ch, previous, following))
        i += 1
    return "".join(out)


def is_rtl(ch: str) -> bool:
    cp = ord(ch)
    return (0x0590 <= cp <= 0x05FF or 0x0600 <= cp <= 0x06FF or 0x0750 <= cp <= 0x077F
            or 0xFB50 <= cp <= 0xFDFF or 0xFE70 <= cp <= 0xFEFF or cp == 0x200F)


def is_ltr(ch: str) -> bool:
    return ("A" <= ch <= "Z") or ("a" <= ch <= "z") or ("0" <= ch <= "9") \
        or PERSIAN_ZERO <= ch <= PERSIAN_NINE or ch in (THOUSANDS, DECIMAL)


def classify(ch: str) -> str:
    if is_rtl(ch):
        return "Rtl"
    if is_ltr(ch):
        return "Ltr"
    return "Neutral"


def clusters(shaped: str) -> list[str]:
    out, i = [], 0
    while i < len(shaped):
        start = i
        while i + 1 < len(shaped) and is_transparent(shaped[i + 1]):
            i += 1
        out.append(shaped[start:i + 1])
        i += 1
    return out


def to_visual_order(shaped: str) -> str:
    runs: list[tuple[str, list[str]]] = []
    pending: list[str] = []
    for cluster in clusters(shaped):
        direction = classify(cluster[0])
        if direction == "Neutral":
            pending.append(cluster)
            continue
        if not runs or runs[-1][0] != direction:
            runs.append((direction, []))
        runs[-1][1].extend(pending)
        pending.clear()
        runs[-1][1].append(cluster)

    if pending:
        if not runs:
            runs.append(("Neutral", []))
        runs[-1][1].extend(pending)

    out: list[str] = []
    for direction, items in reversed(runs):
        if direction == "Rtl":
            for item in reversed(items):
                out.extend(MIRROR.get(ch, ch) for ch in item)
        else:
            out.extend(items)
    return "".join(out)


def for_display(logical: str) -> str:
    return to_visual_order(shape(logical))


def to_persian_digits(text: str) -> str:
    return "".join(chr(ord(PERSIAN_ZERO) + ord(c) - ord("0")) if "0" <= c <= "9" else c for c in text)


def number(value: int) -> str:
    text = to_persian_digits(format(abs(value), ",d").replace(",", THOUSANDS))
    return ("\u2212" + text) if value < 0 else text  # U+2212 minus, not a hyphen


def time_text(seconds: int) -> str:
    seconds = max(0, seconds)
    hours, rest = divmod(seconds, 3600)
    minutes, secs = divmod(rest, 60)
    text = f"{hours:02d}:{minutes:02d}:{secs:02d}" if hours else f"{minutes:02d}:{secs:02d}"
    return to_persian_digits(text)


# The strings the game actually shows. Golden vectors are generated from these so the test file and
# the UI cannot drift apart.
VECTORS = [
    "کاخ شازده",
    "شروع",
    "ادامه",
    "مرحله ۳",
    "میدانِ فیروزه",
    "۲۵ معجون",
    "جان",
    "سکه",
    "پاداش",
    "تنظیمات",
    "بازگشت",
    "ساخت",
    "همه را بساز",
    "صندوق ناحیه",
    "شازده (کاخ)",
    "متن انگلیسی Royal Match در جمله",
    "۱٬۲۳۴ سکه و ۵۶ معجون",
    "کاخِ شازده",  # with kasra
    "می‌روم",      # ZWNJ
    "سلام",        # lam-alef at the end
    "بالا",
    "برای شروع، روی دکمه بزن",
    "۳ از ۵ جان",
    "معجون کافی نیست",
    "کاخِ شازده — فصل یک",
    "«ساخت»",
    "۲۹:۵۹",
    "سطح ۱ از ۱۰",
    "ناحیه کامل شد! صندوق را باز کن",
    "یک خانه را انتخاب کن",     # the booster prompt: hamza-less, all simple letters
    "خانهٔ دیگری را بزن",        # with hamza above (U+0654): the one combining mark the UI prints
    "گردباد",
    "بوستر تمام شده",
]


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 0

    if argv[0] == "--check":
        import subprocess

        table = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "text" / "gen_persian_table.py"), "--check"],
            capture_output=True, text=True)
        if table.returncode != 0:
            print(table.stderr.strip(), file=sys.stderr)
            return 1

        try:
            import arabic_reshaper
        except ImportError:
            print("persian_ref: arabic-reshaper not installed; shaped output is not cross-checked.\n"
                  "             pip install arabic-reshaper", file=sys.stderr)
        else:
            reshaper = arabic_reshaper.ArabicReshaper(configuration={
                "delete_harakat": False,
                "support_ligatures": True,
                "use_unshaped_instead_of_isolated": False,
            })
            disagreements = 0
            for text in VECTORS:
                theirs = reshaper.reshape(text)
                ours = shape(text)
                # arabic-reshaper keeps ZWNJ; we drop it after it breaks the join.
                theirs = theirs.replace(ZWNJ, "")
                if theirs != ours:
                    disagreements += 1
                    print(f"  differs: {text!r}\n    ours  : {ours}\n    theirs: {theirs}")
            if disagreements:
                print(f"persian_ref: {disagreements} shaping disagreement(s)", file=sys.stderr)
                return 1
            print(f"persian_ref: {len(VECTORS)} strings shaped identically to arabic-reshaper")

        print(f"persian_ref: {len(FORMS_TABLE)} letters, {len(VECTORS)} vectors")
        return 0

    if argv[0] == "--emit":
        target = Path(argv[1]) if len(argv) > 1 else ROOT / "client" / "Assets" / "Core.Tests" / "Generated" / "PersianGoldenVectors.gen.cs"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(emit_csharp(), encoding="utf-8")
        print(f"wrote {target.relative_to(ROOT)}: {len(VECTORS)} strings, "
              f"{len(NUMBERS)} numbers, {len(TIMES)} times")
        return 0

    if argv[0] == "--vectors":
        print("        // generated by tools/text/persian_ref.py --vectors")
        print("        // logical (as written) | shaped forms | visual order handed to TMP")
        for text in VECTORS:
            shaped = shape(text)
            visual = to_visual_order(shaped)
            print(f'        {{ "{escape(text)}", "{escape(shaped)}", "{escape(visual)}" }},')
        return 0

    for text in argv:
        print(f"logical : {text}")
        print(f"shaped  : {shape(text)}")
        print(f"visual  : {to_visual_order(shape(text))}")
    return 0


NUMBERS = [0, 7, 25, 999, 1000, 1234, 45678, 999999999, -5]
TIMES = [0, 59, 60, 1799, 1800, 3599, 3600, 3661]


def emit_csharp() -> str:
    lines = [
        "// <auto-generated>",
        "//   Generated by tools/text/persian_ref.py --emit",
        "//   Do not edit by hand. CI fails if this file drifts.",
        "//",
        "//   Each row is: what an author writes, what shaping turns its letters into, and the order a",
        "//   left-to-right renderer must draw. PersianTextTests asserts the C# produces exactly this.",
        "// </auto-generated>",
        "namespace Shazdeh.Core.Tests",
        "{",
        "    internal static class PersianGoldenVectors",
        "    {",
        "        internal struct Vector",
        "        {",
        "            public string Logical;",
        "            public string Shaped;",
        "            public string Visual;",
        "",
        "            public Vector(string logical, string shaped, string visual)",
        "            {",
        "                Logical = logical;",
        "                Shaped = shaped;",
        "                Visual = visual;",
        "            }",
        "        }",
        "",
        "        internal static readonly Vector[] Strings = new Vector[]",
        "        {",
    ]
    for text in VECTORS:
        lines.append(f'            new Vector("{escape(text)}", "{escape(shape(text))}", '
                     f'"{escape(to_visual_order(shape(text)))}"),')
    lines += [
        "        };",
        "",
        "        /// <summary>value, expected Number(value)</summary>",
        "        internal static readonly long[] NumberValues = new long[]",
        "        {",
        "            " + ", ".join(str(n) for n in NUMBERS),
        "        };",
        "",
        '        internal static readonly string[] NumberText = new string[]',
        "        {",
        "            " + ", ".join(f'"{escape(number(n))}"' for n in NUMBERS),
        "        };",
        "",
        "        internal static readonly int[] TimeValues = new int[]",
        "        {",
        "            " + ", ".join(str(t) for t in TIMES),
        "        };",
        "",
        "        internal static readonly string[] TimeText = new string[]",
        "        {",
        "            " + ", ".join(f'"{escape(time_text(t))}"' for t in TIMES),
        "        };",
        "    }",
        "}",
        "",
    ]
    return "\n".join(lines)


def escape(text: str) -> str:
    out = []
    for ch in text:
        cp = ord(ch)
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif 0x20 <= cp < 0x7F:
            out.append(ch)
        else:
            out.append(f"\\u{cp:04X}")
    return "".join(out)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
