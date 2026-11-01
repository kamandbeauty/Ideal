# UI — screens, RTL and the Persian text pipeline

M2 replaces the M0 grey box with the three screens the loop actually needs, and with Persian text that
is shaped rather than hoped for.

```
ثبت نشده ──▶ Home ──▶ Board ──(win)──▶ reward ──▶ Home / next level
               │                     (loss) ──▶ retry (costs one life)
               └──▶ Districts ──▶ build tasks ──▶ chest ──▶ Home
```

## 1. Why Persian is shaped in C#

TextMeshPro draws the code points it is given. Persian is a joining script: a letter's shape depends on
its neighbours (`ب` is four different glyphs), and the line runs right to left. TMP does neither.

`TMP_Text.isRightToLeftText` reverses characters. Reversing is not shaping — the letters stay isolated
and some of them still point the wrong way — so the game does not use it. Instead, before a string
reaches a label, `Shazdeh.Core.Text.PersianText` does two things:

| step | method | what it does |
| --- | --- | --- |
| shape | `PersianText.Shape` | replaces each letter with the Unicode presentation form its neighbours imply (isolated / final / initial / medial), handles LAM+ALEF as one glyph, and drops ZWNJ after it has done its job of breaking a join |
| reorder | `PersianText.ToVisualOrder` | lays the line out for a left-to-right renderer: RTL runs are reversed, Latin words and numbers keep their own order, brackets are mirrored, and a letter keeps its harakat |

`PersianText.ForDisplay(text)` is both, and it is what `RtlText.Set(label, text)` calls. No screen
assigns `TMP_Text.text` directly, which is the only rule the UI layer has to keep.

Numbers are part of the same promise: `PersianText.Number(1234)` → `۱٬۲۳۴`, `PersianText.Time(1799)` →
`۲۹:۵۹`, and `RtlText.SetNumber` / `RtlText.SetTime` / `RtlText.SetFraction` are the three ways a screen
puts a number on the glass.

### The tables are generated, not typed

`PersianForms.gen.cs` (76 letters, with their four forms and their joining type) is generated from the
Unicode database by `tools/text/gen_persian_table.py`. A hand-typed table is how shapers rot: one wrong
code point and a word silently renders with the wrong letter.

```bash
python3 tools/text/gen_persian_table.py           # regenerate
python3 tools/text/gen_persian_table.py --check   # CI: fail if it drifted
```

### It is tested against a second implementation

`tools/text/persian_ref.py` implements the same two steps in Python and compares its output with
`arabic-reshaper` (a widely used shaper) on the 29 strings the game ships. It then writes
`client/Assets/Core.Tests/Generated/PersianGoldenVectors.gen.cs`, and `PersianTextTests` asserts the C#
produces exactly those strings. So "does the Persian look right" is a byte comparison, not an opinion.

```bash
pip install -r tools/text/requirements.txt
python3 tools/text/persian_ref.py --check    # shaping vs arabic-reshaper
python3 tools/text/persian_ref.py --emit     # regenerate the golden vectors
python3 tools/text/persian_ref.py "کاخ شازده" # shaped + drawn, for one string
```

What is *not* covered, stated plainly: Hebrew, Arabic-Indic digits in the middle of Latin words,
bidi bracket pairs nested inside numbers, and Arabic justification (`kashida`). The game does not show
those, and a test that pretends otherwise would be a lie.

## 2. The font: Vazir, shipped

The typeface is **Vazir** (SIL OFL 1.1, v30.1.0) and it ships with the game:

```
Assets/Game/Resources/fonts/Vazir-Medium.ttf   body, buttons, numbers (500)
Assets/Game/Resources/fonts/Vazir-Bold.ttf     titles, big counters (700)
Assets/Fonts/OFL.txt, AUTHORS.txt              the licence, verbatim
```

Vazir is not an arbitrary choice: it contains the Arabic Presentation Forms (U+FB50–U+FEFF) that the
shaper emits. Most Arabic-script fonts do not, and would show boxes. That claim is checked, not assumed
— `tools/text/check_font.py` reads the font's character map and CI fails if a single form, digit or
punctuation mark the UI can print is absent. (It is also how we found that Vazir has no check mark, so
the finished-task label says «ساخته شد».)

At runtime `ShazdehFonts` does one of two things:

1. if `Resources/fonts/shazdeh-ui(.asset)` exists — built by the optional menu item
   **کاخ شازده → Build UI font assets** — it loads that, with the atlas baked at build time;
2. otherwise it builds a dynamic SDF asset from the TTF on first use. That is the default path, which is
   why a fresh clone shows correct Persian with no setup step and why CI never needs a font asset in
   git (it is a binary only Unity can produce).

If neither exists — someone deleted the TTFs — labels fall back to the TMP default, one warning is
logged, and `Assets/Scenes/_PersianCheck.unity` shows exactly which layer is broken.

```bash
python3 tools/text/check_font.py       # glyph coverage, no Unity needed
```

## 3. Layout

- **Design space**: 415 × 738 units, 1 unit = 1 dp. `replica/design/components.md` writes sizes in dp
  (touch target 48, safe top 44, type 12–34), so a number in the spec and a number in a screen are the
  same number. The 1080 × 1920 art reference is that space at ~2.6×.
- **Anchoring**: everything is placed from the top-left with `UiKit.Place(x, y, w, h)`, y growing
  downwards, like a design tool.
- **RTL placement**: the reading eye starts on the right, so lives (the resource you spend by playing)
  sit top-right, dashes and captions are right-aligned, and the level progress bar fills from the right.
- **Tokens only**: colours, type sizes, spacing and radius come from `Tokens.gen.cs`. No hex in a
  screen file — `DesignSystemView` and the `design` CI job both enforce that.
- **Rounded corners without art**: `UiKit.Rounded(radius)` generates a 9-sliced sprite once per radius.

## 4. Files

| file | what it is |
| --- | --- |
| `Assets/Game/AppRoot.cs` | the only component a scene needs: loads the save, builds the canvas, owns navigation |
| `Assets/Game/GameSession.cs` | save + economy + content for one player; screens call it, it calls `Shazdeh.Core` |
| `Assets/Game/Ui/UiKit.cs` | canvas, panel, label, button, placement, rounded sprites |
| `Assets/Game/Ui/UiScreen.cs` | a screen: build once, refresh on change |
| `Assets/Game/Ui/TopBar.cs` | coins, potions, lives — on every screen |
| `Assets/Game/Ui/HomeScreen.cs` | palace header, level card, play, districts |
| `Assets/Game/Ui/BoardScreen.cs` | the board (real engine), swipe + tap input, animated turns, per-goal chips, result card with stars — see `docs/gameplay.md` |
| `Assets/Game/Ui/DistrictScreen.cs` | districts, task prices, "build all", chest |
| `Assets/Game/Ui/PersianCheckView.cs` | the specimen scene that isolates font / shaper / layout problems |
| `Assets/Game/Ui/RtlText.cs` | the only door text goes through |
| `Assets/Core/Text/PersianText.cs` | shaping + reordering + digits (no UnityEngine) |
| `Assets/Core/Text/PersianForms.gen.cs` | generated letter tables |
| `Assets/Game/Ui/ShazdehFonts.cs` | Vazir: prebuilt asset, else a dynamic asset from the TTF |
| `tools/text/check_font.py` | does the shipped font contain what the shaper emits |

## 5. What M2 does not have yet

- **Animation beyond the turn.** The swap, the clear and the settle are animated from the engine's
  event list (`docs/gameplay.md` §1), but there is no build animation, no chest reveal and no
  particles. `replica/design/art-direction.md` is the spec; shipping graphics at the level
  of the original is the acceptance criterion, and none of it exists yet. The pipeline that will
  consume it is `docs/art.md`.
- **A world map.** Districts are a list, not a map.
- **Settings, shop, tutorial, audio.** All later milestones.
- **A tablet/landscape layout.** The canvas scales but the layout is portrait-first.
- **Real device testing.** Nothing here has run on a phone yet: this sandbox has no Unity. First run on
  a device should be: check Persian on `_PersianCheck`, then play level 1 to the result overlay and
  back, then build a task with potions earned from that level.
