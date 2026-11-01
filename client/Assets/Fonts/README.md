# Fonts

The game has one typeface: **Vazir** by Saber Rastikerdar, under the SIL Open Font License 1.1.
It ships with the repository, so a fresh clone renders Persian with no setup.

| file | what it is |
| --- | --- |
| `../Game/Resources/fonts/Vazir-Medium.ttf` | body, buttons, numbers — weight 500 |
| `../Game/Resources/fonts/Vazir-Bold.ttf` | titles and the big counters — weight 700 |
| `OFL.txt` | the licence, verbatim |
| `AUTHORS.txt` | the font's copyright holders, verbatim |

Provenance: the `vazir-font` package, version **30.1.0**, published by the typeface's author
(https://github.com/rastikerdar/vazir-font). The TTFs are unmodified; only the OFL and AUTHORS files
travel with them.

## Why this font, and not just "a Persian font"

Most modern Arabic-script fonts do **not** contain the Unicode presentation forms (U+FB50–U+FEFF);
they expect the text engine to do contextual shaping through OpenType features. TextMeshPro does no
shaping, so this game shapes Persian itself and then hands the renderer presentation-form code points
(`docs/ui.md` §1). A font without those glyphs would show a wall of boxes.

Vazir has them. That is not a guess: `tools/text/check_font.py` reads the font's character map and
fails CI if any form the shaper can emit, any Persian digit, or any punctuation a screen prints is
missing. It is also how we learned Vazir has no check mark (U+2713) — the task list says «ساخته شد»
instead.

```bash
python3 tools/text/check_font.py
```

## Licence obligations if you ship this

- Keep `OFL.txt` and `AUTHORS.txt` in the build's notices (`docs/launch.md` will list them).
- Do not sell the font by itself; do not use the names "Vazir" or "Vazirmatn" for a modified version.
  If you replace the TTFs with a modified cut, rename it (e.g. "Shazdeh Vazir").
- Dynamic use inside the game is fine, including the runtime SDF atlas the game builds at boot.

## Replacing the typeface

1. Put the new `Regular`/`Medium` and `Bold` TTFs in `../Game/Resources/fonts/`.
2. Update the two paths in `Assets/Game/Ui/ShazdehFonts.cs`.
3. Run `python3 tools/text/check_font.py` — if it fails, the font cannot render this game's text.
4. Update this file and `OFL.txt` if the licence changed.
