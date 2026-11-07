# godot-port — کاخِ شازده on Godot 4

The independent Godot build of the Unity game in `client/`. No Unity runtime, no WebView, no wrapper:
this is a new project with its own scene, its own input, its own renderer, and the game's data and art
copied across as plain files.

Godot 4.4.1 · GDScript · `gl_compatibility` renderer · Android (portrait) and desktop.

## What is where

| Path | What it is |
|---|---|
| `project.godot` | Design space 415 × 738 dp (the same numbers as `UiKit.cs`), portrait, `canvas_items` stretch, GLES3-class renderer so low-end Android devices are in scope. |
| `scenes/main.tscn` | One node, `AppRoot`. Everything else is built by code, so there is no prefab tree to break and CI can boot the game headlessly. |
| `scripts/app_root.gd` | Loads the save, builds the five screens and the top bar, owns navigation. |
| `scripts/session.gd` | `GameSession` port: save, wallet, lives, progression, boosters, districts; the rules that span more than one of them. |
| `scripts/core/` | The engine-free core: board, match finding, cascades, power-ups, goals, level run, stars, progression, save codec/store, content loaders, determinism. 27 files. |
| `scripts/ui/` | `UiTokens` (tokens from `Tokens.gen.cs`), `PersianText`, `UiKit`, `UiScreen`, `TopBar`, `BoardView`. |
| `scripts/screens/` | Home, board, districts, shop, settings. |
| `assets/art`, `assets/fonts` | The 85 PNGs and both Vazir weights, copied from the Unity project. |
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

Not done yet, and deliberately not claimed:
- No parity fixture suite over long move sequences (event order, counters and hashes compared
  move-for-move against C#). `migration/01-audit.md` §10 R1 explains why this needs a Unity run.
- No sound: the Unity project has no audio assets either, so nothing was dropped.
- **No APK yet.** Godot 4.4.1's CLI refuses the Android export with an empty list of configuration
  errors even though the templates, SDK, JDK, keystore and icons are all in place and a Linux export on
  the same runner succeeds. This is documented as known problem **K1** in `ANDROID_EXPORT.md`, and the
  `android-debug` CI job fails on purpose rather than uploading nothing and calling it a build.

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
passed, and the game booted to the title screen" — not merely "the YAML was valid". The `android-debug`
job is separate and is currently red for the reason in `ANDROID_EXPORT.md` (K1); an `export-diagnostic`
job exists to keep explaining it.
