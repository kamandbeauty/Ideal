# Godot port — phase-by-phase report

Every claim on this page has a commit, a CI run or a command behind it. Where a claim cannot be
backed by one of those three, it is written down as pending instead of as done — the same rule the
audit used.

## Where the work lives

| | |
| --- | --- |
| branch | `arena/d42cf39b-ideal` |
| Godot project | `godot-port/` (never touches `client/`) |
| Unity source | `client/` — asserted unchanged by the `unity project pin` job and by `migration/tools/check_audit.py` |
| CI | `.github/workflows/godot-port.yml` (`godot-port` workflow: `headless`, `android-debug`) |
| audit + decisions | [`01-audit.md`](01-audit.md), [`03-compatibility.md`](03-compatibility.md), [`README.md`](README.md) |

Sizes at the time of writing: **42 GDScript files, 5,081 lines** — 26 core files (2,213 lines),
6 kit files (874), 5 screens (869), 3 test files (702). Design space 415 × 738 dp, the same numbers as
`client/Assets/Game/Ui/UiKit.cs`.

---

## Phase 1 — audit · complete

Deliverables: `01-audit.md` (§1–§11), `02-inventory.csv` (173 rows), `03-compatibility.md`,
`04-dependency-graph.md`, `tools/audit.py`, `tools/check_audit.py`, and a `migration audit` CI job that
fails if the numbers drift.

Commits: `83a8fca`, `8aefe03`.

Headline: nothing serialised to convert — zero `.unity`, `.prefab`, `.mat`, `.shader`, `.anim`,
`.controller`, no audio, no 3D. 66 C# files, 9,453 non-blank lines, 9,060 handwritten, 152 `[Test]`.

## Phase 2 — project init + headless CI · complete

- `godot-port/project.godot`: 415 × 738 viewport, `canvas_items` stretch, portrait, **GL Compatibility**
  renderer (audit decision D2), `input_devices/pointing/emulate_touch_from_mouse` so the same code path
  is testable on a desktop.
- `scenes/main.tscn` holds one `Control` with `AppRoot`. Nothing else is authored: every widget is built
  from tokens at runtime, so there is no scene tree to break and CI can boot the game.
- CI job `headless`: import (`--editor --quit`), `validate_scripts.gd` (every `.gd` must compile),
  `test_core.gd`, `test_ui.gd`, then a real boot with `--quit-after` and a grep for the boot line.

Evidence: run `42411833253` — job *Godot 4 headless import, script validation and tests*: **success**
(all five steps green, including the boot check).

Known problems found and fixed on the way, kept here because they are the sort of thing that silently
rots a port: a heredoc inside a `run: |` block never terminates (moved logic into
`godot-port/tools/write_editor_settings.py`), `android-actions/setup-android@v3` fails on the current
runner image (SDK installed from Google's command-line tools instead), and Godot's `--export-debug`
does not create the output directory (the step now makes it first).

## Phase 3 — assets · complete

85 PNGs, both Vazir weights (SIL OFL) and 11 JSON files copied from the Unity project as plain files;
no `.meta`, no GUIDs, no re-import step. `AssetCatalog` resolves art ids to `res://` paths and returns
`null` for a missing id instead of throwing, and `test_ui.gd` asserts both behaviours.

## Phase 4 — core gameplay · complete

`godot-port/scripts/core/` is a behaviour port of `client/Assets/Core/` (2,607 lines of C# → 2,213
lines of GDScript), engine-free: `BoardModel`, `MatchFinder`, `MoveResolver`, `PowerUps`,
`BoardFactory`, `GoalTracker`, `LevelRun`, `StarRating`, `Wallet`, `Lives`, `Progression`,
`BoosterBag`, `SaveCodec`/`SaveStore`, the content loaders and validator, and `DeterministicRandom` +
`StateHash`.

Determinism is not "looks random": `test_core.gd` reproduces the C# golden vectors — xorshift64* state
`c0d2f1a263e84ebf` after six draws from seed 42, the seed-1 draw sequence, and the C# FNV board and
`LevelRun` hashes. Save compatibility keeps `shazdeh-save.json` with `.bak`/`.tmp`, v1 migration,
corrupt-file recovery and backup restore.

## Phase 5 — UI, motion, audio, visual · playable, not finished

Ported from `Game/Ui`: the token file (`UiTokens` ← `Tokens.gen.cs`), `UiKit` (panels, nine-slice art,
labels, buttons, icons, placement by top-left dp), `UiScreen`, `TopBar`, `BoardView`, and the five
screens — home, board, districts, shop, settings. Motion: swap 0.14 s, clear 0.14 s, fall 0.22 s,
reject shake 0.16 s, with the settle pass derived from the event list the resolver returns.
Interface: swipe and tap-tap, booster targeting, goal chips, result card with stars and rewards.

Pending, explicitly:
- **No audio.** The Unity project has no audio assets, so nothing was dropped, but a shipping game needs
  music and match/clear/reward sounds. Not written yet.
- **No spark/VFX layer.** `fx_spark`, `fx_ring`, `fx_coins` are imported and unused.
- **No screen transition animation** (decision: polish after a device run).
- Layout has been reasoned from `BoardScreen.cs`'s constants and the design tokens, but not compared
  pixel-for-pixel on a device.

## Phase 6 — levels and progression · complete for chapter one

Ten levels in `content/levels/ch01`, three districts and twelve build tasks in
`content/meta/ch01-districts.json`, both unchanged from the Unity project and validated by
`LevelValidator`/`DistrictContentLoader`. `test_ui.gd` boots **all ten levels through `BoardScreen`**
and checks each draws its own board size; `test_core.gd` plays 500 legal moves across them.
Session rules ported with their tests: first-clear reward, unlock, star rating, task payment, chest
claim, lives spend on loss and timed refill.

## Phase 7 — testing and Android · APK builds, device work pending

`android-debug` job: OpenJDK 17, Android command-line tools, `platform-tools`/`build-tools;34.0.0`/
`platforms;android-34`, Godot with export templates, a debug keystore, editor settings written from a
script, then `--export-debug "Android"` into `godot-port/build/`, then a **verification step** that the
file is non-empty, is a zip, and contains `AndroidManifest.xml` and `classes.dex` before uploading it.

Package id `com.shazdeh.palace`, version 1.0.0, min SDK 23, target SDK 34, portrait, `armeabi-v7a` +
`arm64-v8a`.

Pending: a real device/emulator run, frame-time and memory profiling, draw-call and texture-memory
budget from the audit's §3, release signing, an AAB, and the store listing.

## Phase 8 — release validation · not started

Needs Phase 7's device results plus the parity fixtures from the audit's risk R1 (no working Unity build
exists to compare against, so parity has to be defined as the 152 C# tests, the design documents and
the golden vectors — all of which the port currently reproduces).

---

## How to verify any of this yourself

```bash
git checkout arena/d42cf39b-ideal
python3 migration/tools/audit.py --check          # the inventory is still exactly 173 files
python3 migration/tools/check_audit.py            # Unity untouched, no C# in godot-port
godot --headless --editor --path godot-port --quit
godot --headless --path godot-port --script res://tests/validate_scripts.gd
godot --headless --path godot-port --script res://tests/test_core.gd
godot --headless --path godot-port --script res://tests/test_ui.gd
godot --headless --path godot-port --quit-after 120      # boots to the title screen
godot --path godot-port                                   # plays it
```
