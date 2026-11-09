# godot-port — کاخِ شازده on Godot 4

The independent Godot build of the Unity game in `client/`. No Unity runtime, no WebView, no wrapper:
this is a new project with its own scene, its own input, its own renderer, and the game's data and art
copied across as plain files.

Godot 4.7.2 · GDScript · `gl_compatibility` renderer · **landscape** (738 × 415 dp) on Android and desktop.

**Every pixel on screen is a picture.** The game art is the 85 plates from the Unity project, byte for
byte (`assets/art/`); the panels, buttons, pills, chips, switch tracks, knobs, washes and hairlines are
PNGs in `assets/ui/`, baked by `tools/make_ui_art.py` and nine-sliced by `UiKit`. `StyleBoxFlat` and
`ColorRect` survive only as fallbacks for a missing texture — a screen that draws a rectangle the engine
rounded at runtime is a bug now, not a style.

The five stones are the one place where a second, better picture exists: `assets/gems/` holds the gems
re-cut by `tools/make_gem_art.py` — bezel, crown facets, table, specular, sparkle — and the board draws
those, because the Unity sprites are flat polygons that read as "no graphics at all" at 36 dp. The
Unity originals still ship, untouched, and `AssetCatalog` falls back to them if the folder is missing.

## What is where

| Path | What it is |
|---|---|
| `project.godot` | Design space 738 × 415 dp, **landscape**, `canvas_items` stretch, GLES3-class renderer so low-end Android devices are in scope. |
| `scenes/main.tscn` | One node, `AppRoot`. Everything else is built by code, so there is no prefab tree to break and CI can boot the game headlessly. |
| `scripts/app_root.gd` | Loads the save, builds the five screens and the top bar, owns navigation. |
| `scripts/session.gd` | `GameSession` port: save, wallet, lives, progression, boosters, districts; the rules that span more than one of them. |
| `scripts/core/` | The engine-free core: board, match finding, cascades, power-ups, goals, level run, stars, progression, save codec/store, content loaders, determinism. 27 files. |
| `scripts/ui/` | `UiTokens` (tokens from `Tokens.gen.cs`), `PersianText`, `UiKit`, `UiScreen`, `TopBar`, `BoardView`. |
| `scripts/screens/` | Home, board, districts, shop, settings. |
| `assets/art`, `assets/fonts` | The 85 PNGs and both Vazir weights, copied from the Unity project. |
| `assets/ui`, `assets/gems` | The picture chrome and the re-cut stones, both generated — `tools/make_ui_art.py` and `tools/make_gem_art.py`. |
| `content/` | The ten chapter-one levels and the chapter metadata, unchanged JSON. |
| `tests/` | Headless suites: `test_core.gd` (rules, determinism, save, content), `test_ui.gd` (Persian numerals, kit, session, board, every level), `validate_scripts.gd` (every `.gd` compiles). |

## What is ported and what a reviewer can check

Ported, with tests: deterministic RNG and FNV state hashes against the C# golden vectors, board
generation, match finding, cascades, power-ups and their pairings, obstacles, goals, move accounting,
stars, first-clear rewards, unlocks, lives and refill, wallet, booster bag and shop, save codec with
v1 migration and corrupt-save recovery, all ten levels and the three districts, and the screens that
drive them.

Ported and drawn from the Unity art: the board, HUD, booster bar, result card, shop, districts and
settings, with swipe/tap input, swap, clear, fall and reject animation.

**Score and combo.** A move's event list is priced at the core (`LevelRun._award_score`): 50 a cleared
piece, 100 an obstacle hit, 180 a triggered power-up, 250 a cascade, 300 a created power-up; a move's
cascades plus its triggered power-ups form a combo, and every link past the first is worth a flat 150
(`bonus = (combo − 1) × 150`). The number is presentation only — nothing on the board, in the goals or
in progression reads it back — but it is deterministic, tested arithmetic (a three-chain is exactly
980 in `tests/test_core.gd`), it is shown live under the goals, the result card prints it, and each
level's best is persisted per level as `bestScore` in the save JSON. The board also gained the four
cues that go with it: `clear`, `obstacle`, `combo` and `powerup_create`, each pitched by how much of
the event it is reporting.

Not done yet, and deliberately not claimed:
- No parity fixture suite over long move sequences (event order, counters and hashes compared
  move-for-move against C#). `migration/01-audit.md` §10 R1 explains why this needs a Unity run.
- **Sound: ported, not migrated.** The Unity project ships no audio at all, so there was nothing to
  copy — the fourteen cues and the 27 s palace loop are synthesised by `godot-port/tools/make_audio.py`
  and committed as build output, so a reviewer can regenerate them byte for byte (`md5sum` matches).
- **First device run happened, and it found bugs the tests could not.** The APK from the artifact
  installed and ran, and the screenshots showed the layout piled into one screen with the HUD numbers
  floating outside their pills. Three real defects were behind it — a Godot 3 API call (`raise()`) that
  aborted startup, `UiKit.place()` forcing a minimum size on every control so labels refused to shrink,
  and `set_anchors_preset()` leaving every screen 0x0 — plus the full-bleed art being the only widget
  sized by anchors, which is why the palace, the board backdrop and the map never drew. All fixed, and
  the suite now has assertions for each: one view visible at a time, every screen filling the design
  space, no label escaping its panel.
- **Download the APK without logging in:**
  https://github.com/kamandbeauty/Ideal/releases/download/android-latest/princes-palace-debug.apk
  — every green `android-debug` run refreshes that asset, so the link is stable.
- **The screenshots are in the repository.** A `visual` CI job renders the real game under Xvfb on both
  a 415x738 window and a 1080x2400 phone shape and commits the PNGs to `godot-port/.shots/`, with
  `00-contact-sheet.png` (all five screens in one image) and `layout.txt` next to them containing every
  visible control's rect, the switch states, and a list of
  any control that escapes its parent. It reported 0 escapes for all five screens on the last run.
- **Still no measured performance.** Frame time, memory and touch latency on hardware are unmeasured.

## Persian

Unity had to shape Arabic script by hand (`Shazdeh.Core.Text.PersianText`) because TMP cannot. Godot's
`TextServer` runs HarfBuzz and ICU, so the port does **not** reorder anything — it hands the logical
string to the engine and sets `layout_direction = RTL`. What is still ported is the other half of the
contract: Persian numerals, thousands grouping (`۱۲٬۳۴۵`), `م:ث` clocks and `۳ از ۵` fractions, all
covered by `tests/test_ui.gd`. `SettingsScreen` renders a live sample line so a human can confirm the
font and the shaping on the device.

## Running it

```bash
godot --headless --editor --path godot-port --quit          # import + build the class cache
godot --headless --path godot-port --script res://tests/validate_scripts.gd
godot --headless --path godot-port --script res://tests/test_core.gd
godot --headless --path godot-port --script res://tests/test_ui.gd
godot --path godot-port                                       # play it
```

CI (`.github/workflows/godot-port.yml`) runs exactly those first four steps on every push. The
`headless` job is the gate: a green run means "the project imported, every script compiled, both suites
passed, and the game booted to the title screen" — not merely "the YAML was valid". `android-debug`
builds and verifies the APK in the same run, and `export-diagnostic` is a probe kept around for the day
an export is refused again.
