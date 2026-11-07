# Phase 1 — Technical audit of the Unity project

Status: **complete, awaiting review.** No migration work has started; nothing under `client/` was
touched. Every number here is produced by `migration/tools/audit.py` (173 files scanned, output in
[`02-inventory.csv`](02-inventory.csv)) — re-run it and the numbers must agree, `--check` fails the
build if they drift.

Scope audited: the whole of `client/` (the Unity project), plus the parts of the repo a port depends on
(`art/manifest.json`, `client/Assets/Content/Resources/**`, `docs/`, `tools/`, `.github/workflows/`).

Headline: **there is almost nothing Unity-shaped to migrate.** The project contains no scene files, no
prefabs, no materials, no shaders, no animation, no audio, no 3D and no `.meta` files. Everything —
scenes included — is built by C# at runtime. The migration is therefore a **re-implementation of ~9,060
lines of C# in GDScript**, plus an asset import, and *not* an asset-conversion problem. The 152 written
tests are the only executable description of the game's behaviour, which makes them the migration's
spec and its safety net.

---

## 1. Scenes

| what | count | note |
| --- | --- | --- |
| `.unity` scene files in the repository | **0** | they do not exist in git |
| scenes created by the editor menu | 3 | `کاخ شازده → Create scenes` writes them |
| objects in the playable scene | 1 | a single `GameObject` carrying `AppRoot` |
| objects in the two dev scenes | 1 each | `DesignSystemView`, `PersianCheckView` |

`client/Assets/Editor/ShazdehMenu.cs` creates `Assets/Scenes/App.unity`, `_DesignSystem.unity` and
`_PersianCheck.unity` from code and registers only `App` in the build settings. The rest of the scene
graph (canvas, camera, every widget) is constructed in `AppRoot.Awake` and each screen's `Build()`.

Consequence for the port: there is **no scene graph to convert**, and equally **no scene file to diff
against**. The Godot side must author real `.tscn` scenes (that is the requirement: native Godot scene
architecture), so the hierarchy that currently exists only as call order has to be designed once, on
purpose. See [`04-dependency-graph.md`](04-dependency-graph.md).

## 2. Scripts

| assembly (`*.asmdef`) | files | non-blank lines | engine reference |
| --- | --- | --- | --- |
| `Shazdeh.Core` | 21 | 2,607 | **none** (`"noEngineReferences": true`) |
| `Shazdeh.Content` | 6 | 669 | none, except `Newtonsoft.Json` in `SaveCodec` |
| `Shazdeh.Game` | 20 | 3,570 | uGUI, TextMeshPro, Input System |
| `Shazdeh.Editor` | 5 | 387 | UnityEditor (not needed at runtime) |
| `Shazdeh.Core.Tests` | 14 | 2,220 | NUnit, editor-only |
| **total** | **66** | **9,453** | |

Of those, **3 files / 393 lines are generated** and must be *regenerated*, never translated:
`Core/Text/PersianForms.gen.cs`, `Game/ArtCatalog.gen.cs`, `Game/Generated/Tokens.gen.cs`
(the test-side `Core.Tests/Generated/PersianGoldenVectors.gen.cs` is generated too and comes along with
the tests). Handwritten C# to port: **9,060 non-blank lines**.

Tests: **152 `[Test]` methods** in 14 files, 0 `[TestCase]`, 0 `[UnityTest]`. They are engine-free apart
from the three files that touch `ArtLibrary`/`SpriteRenderer`. They have **never been executed** — see
§10, risk R1.

Largest and riskiest files: `BoardScreen.cs` 1,142 · `SaveTests.cs` 358 · `MoveResolver.cs` 345 ·
`EconomyTests.cs` 308 · `PersianText.cs` 306 · `DistrictScreen.cs` 242 · `UiKit.cs` 227.

## 3. Asset inventory

| asset class | count | size | shipped to the player | port treatment |
| --- | --- | --- | --- | --- |
| sprites (PNG, 128–1024 px, RGBA) | 85 | 1,841 KiB | yes | import as-is, re-import settings |
| fonts (TTF, Vazir Medium + Bold, OFL) | 2 | 198 KiB | yes | import as `FontFile` |
| content JSON (10 levels + 1 district meta) | 11 | 10 KiB | yes | copy, same schema |
| level/content contract (`art/manifest.json`) | 1 | — | no | stays a repo artifact; drives a registry |
| design tokens (`replica/design/tokens.json`) | 1 | — | no | generator input for the GDScript token file |
| SQL schema (`replica/schema.sql`, `smoke.sql`) | 2 | — | no (server) | out of scope for the client port |
| review sheets (`art/preview/*.png/html`) | 3 + 2 | — | no | stays a repo artifact |
| concept references (`replica/design/concepts/*.jpg`) | 2 | — | **never** | reference only (clean-room rule) |
| audio | **0** | — | — | nothing to migrate; there is no mixer to port |
| 3D models / textures / skyboxes | **0** | — | — | not a 3D game |
| animations / animator controllers | **0** | — | — | motion is code (`BoardScreen` tweens) |
| materials / shaders / ShaderGraph | **0** | — | — | no shader to translate |

**Git LFS:** not configured, and `git lfs` is not installed in this environment; `git ls-files` shows no
LFS pointers. Total binary payload is **~2.0 MiB**, so the port does not need LFS at all. If the sprite
set later grows past a few hundred MB, the decision point is recorded in
[`03-compatibility.md`](03-compatibility.md) §5; today the answer is "copy the files".

## 4. Gameplay systems

Every system the game has, where it lives, and what the port owes it. This table is the seed of the
migration checklist (`05-checklist.csv` is generated from it in Phase 2).

| # | system | source | lines | behaviour that must survive |
| --- | --- | --- | --- | --- |
| 1 | board model + gravity + reshape | `Core/Board.cs`, `BoardFactory.cs` | 225 | 9×9 grid, blocked cells, gravity directions, deterministic fill from a seed |
| 2 | match finding | `Core/MatchFinder.cs` | 213 | horizontal/vertical runs, 3+, L/T detection, power-up spawn rules |
| 3 | move resolution | `Core/MoveResolver.cs` | 345 | swap legality, cascade loop, gravity, refill, obstacle damage, power-up activation, event list |
| 4 | power-ups | `Core/PowerUps.cs` | 177 | electro ball, dynamite, rocket row/column, spinner; super variants |
| 5 | obstacles | `Core/Goals.cs`, `LevelModel.cs` | 157 | 8 obstacle kinds with their own counter rules |
| 6 | goals + level result | `Core/LevelRun.cs`, `StarRating.cs` (+ `Goals`) | 272 | per-goal progress, moves, stages, win/lose, 1–3 stars from moves left |
| 7 | boosters | `Core/Boosters.cs` | 122 | five kinds, prices, owned cap 9, use/refund, all-or-nothing purchase |
| 8 | economy | `Core/Wallet.cs` | 47 | coins + potions, spend/grant, overflow guard |
| 9 | lives | `Core/Lives.cs` | 91 | 5 max, 1,800 s refill, timestamp-based, offline-safe |
| 10 | progression | `Core/Progression.cs` | 130 | level unlock, task completion, chest claims |
| 11 | save / load | `Content/SaveCodec.cs`, `Core/SaveData.cs`, `Game/SaveStore.cs` | 303 | JSON v2, temp+backup write, corrupt-file recovery, migrations |
| 12 | content parsing + validation | `Content/LevelParser`, `LevelValidator`, `DistrictParser` | 357 | JSON → models, schema + design-rule validation with Persian messages |
| 13 | determinism | `Core/DeterministicRandom.cs`, `StateHash.cs` | 146 | seeded RNG and a stable state hash used by replays/tests |
| 14 | Persian text | `Core/Text/PersianText.cs` + generated forms | 306 + 173 | Arabic joining, RTL reordering, Persian digits, ZWNJ, time/clock formatting |
| 15 | UI construction (no board) | `Game/Ui/UiKit.cs` + 8 screens | 1,262 | 415×738 dp design space, RTL placement, nine-slice art, buttons, switches |
| 16 | board rendering + input | `Game/Ui/BoardScreen.cs` | 1,142 | swipe/tap, camera framing, tweens, sparks, booster aiming, result overlay |
| 17 | art registry | `Game/ArtLibrary.cs` (+ generated catalog, 134) | 124 | id → sprite with a guaranteed placeholder, nine-slice borders at runtime |
| 18 | session/navigation | `Game/AppRoot.cs`, `GameSession.cs` | 425 | screen graph, one-way navigation, save-on-change, 1 Hz HUD tick |
| 19 | settings + shop screens | `Ui/SettingsScreen.cs`, `Ui/ShopScreen.cs` | 294 | four save flags; five priced boosters with caps |
| 20 | dev scenes | `DesignSystemView`, `PersianCheckView` | 256 | token specimen page; Persian shaping specimen |

Explicitly **absent** (so the port must not invent them): audio, haptics, notifications, tutorial,
world map, pre-level booster placement, IAP/store, accounts, server calls, analytics, ads, cloud save,
localisation beyond Persian, tablet layout.

## 5. Third-party dependencies

`client/Packages/manifest.json` pins 14 packages. Only **five** are actually referenced by code:

| package | version | used by | Godot position |
| --- | --- | --- | --- |
| `com.unity.ugui` | 2.0.0 | all UI | built into Godot (`Control`, `Button`, `TextureRect`) |
| `com.unity.nuget.newtonsoft-json` | 3.2.1 | `SaveCodec`, level/district parsers | built-in `JSON` class; no port needed |
| `com.unity.inputsystem` | 1.11.2 | `InputCompat` | built-in `InputEvent*` |
| `com.unity.test-framework` | 1.4.5 | 152 tests | GDScript test addon (Phase 2 decision: GUT vs gdUnit4) |
| TextMeshPro | (ships in ugui 2.0) | every label | built-in `Label` + `TextServer` |

Declared but **never used** (dead weight in the Unity project, and a hint about scope):
`com.unity.modules.animation`, `.audio`, `.particlesystem`, `.physics2d`, `.uielements`, `.imgui`,
`.imageconversion`, `.jsonserialize`, `.unitywebrequest`. Nine modules, zero references — the port does
not have to replace them.

No NuGet DLLs, no native plugins, no `.unitypackage` imports, no paid assets, no asset-store packages.
Repo-side tooling is Python + stdlib (`tools/`), not a runtime dependency.

## 6. Unity-specific features, and what each one costs

| Unity feature | where | hits | Godot 4 replacement | cost |
| --- | --- | --- | --- | --- |
| uGUI `Canvas` + `CanvasScaler` (415×738, match 0.5) | `UiKit.CreateCanvas` | 1 | `Control` root + project stretch `canvas_items` / `expand` | medium — not an exact match, documented |
| `EventSystem` + input module (resolved by reflection) | `UiKit.EnsureEventSystem` | 1 | built in | none |
| TextMeshPro labels, bold weight as a second asset | every screen (43 labels) | 43 | `Label` + `FontFile` (variation/weight) | medium (shaping, §7) |
| `SpriteRenderer` + orthographic `Camera` for the board | `BoardScreen` | 16 | `Node2D` + `Camera2D`, or a `SubViewport` | high (re-layout) |
| `Sprite.Create` at runtime for nine-slice borders | `ArtLibrary.GetSliced` | 4 ids | `NinePatchRect` / `StyleBoxTexture` with explicit margins | low |
| SDF-generated rounded-rect sprites | `UiKit.Rounded` | 1 | `StyleBoxFlat.corner_radius` | low |
| `Resources.Load<Sprite>` by id | `ArtLibrary.Get` | 8 | `load()` + a generated registry, or `Resource` preloads | low |
| `Application.persistentDataPath` + `File` IO | `SaveStore` | 3 | `user://` + `FileAccess` | none |
| Newtonsoft `JsonConvert` | `SaveCodec`, parsers (3 files) | 4 | `JSON.parse_string` / `JSON.stringify` | low, but float/int care needed |
| Editor menu + `EditorBuildSettings` | `ShazdehMenu` | 1 | `@tool` script or `addons/` plugin, or a shell script | low (dropped from runtime) |
| Assembly definitions (5) | `*.asmdef` | 5 | no equivalent; GDScript `class_name` + folders | none (dropped) |
| IL2CPP / `.aab` / keystore via CI | `Editor/CiBuild.cs` | 1 | `export_presets.cfg` + `--export-release "Android"` | medium |
| Input System package with legacy `#if` fallback | `InputCompat` | 1 | one input path, no reflection | none (simplification) |
| `Time.unscaledDeltaTime` / manual tweens | `BoardScreen`, `AppRoot` | 17 | `_process(delta)` or `Tween` | low |
| `[MenuItem]` Persian menu labels | `ShazdehMenu` | 6 | editor plugin or `--headless -s` script | low |

## 7. Godot compatibility issues

1. **Persian text shaping is the one genuinely non-mechanical problem.** The Unity build does its own
   shaping (`PersianText`, 306 lines + 196 generated lines of joining tables) *because* TMP cannot do
   Arabic. Godot 4 ships `TextServerAdvanced`, which shapes Arabic/Persian natively and does bidi. The
   port therefore has two paths, and the audit does not pick one on faith:
   - **(a)** rely on `TextServer` and keep a thin GDScript layer only for Persian digits, ZWNJ and the
     numeric/time formatters;
   - **(b)** port `PersianText` + `PersianForms` to GDScript and keep full control.
   The decisive evidence exists in the repo: `Core.Tests/Generated/PersianGoldenVectors.gen.cs` +
   `tools/text/check_font.py` + `arabic-reshaper` cross-checks. Phase 2 starts with a **spike** that runs
   the same golden vectors through `TextServer` and reports the diff. Whichever path wins, the vectors
   ship as tests. Estimated 2–3 days, and it is the highest-risk item in the whole migration.
2. **Unsigned 64-bit arithmetic.** `DeterministicRandom` and `StateHash` are built on `ulong` with
   specific overflow behaviour; GDScript's `int` is signed 64-bit with wrapping add/sub but no unsigned
   type. The port must mask every operation with `0xFFFF_FFFF_FFFF_FFFF` and be validated against the
   C# golden values already committed in `DeterministicRandomTests` (`6255019084209693600`,
   `"c0d2f1a263e84ebf"`). If these drift, save files and replay hashes diverge silently.
3. **No `.meta` files means no import settings to transfer.** Godot's `.import` files are generated with
   defaults; sprite import (`filter`, `mipmaps`, compression) and font rendering flags must be set
   deliberately, or the flat-vector art will render with texture filtering artefacts at 48 px.
4. **`CanvasScaler` match 0.5 has no exact Godot equivalent.** Godot's `stretch/mode=canvas_items` +
   `aspect=expand` behaves closest; the deviation must be written down and checked on three aspect
   ratios, because every layout constant in the project is in the 415×738 space.
5. **Generated code must be regenerated, not translated.** `Tokens.gen.cs`, `ArtCatalog.gen.cs` and
   `PersianForms.gen.cs` come from `replica/design/tokens.json`, `art/manifest.json` and the Unicode
   tables. The Godot side needs equivalent generators (`*.gd` output) so art and tokens keep one source
   of truth — otherwise the port forks the design system.
6. **Save-file compatibility is achievable but must be proven.** The schema is plain JSON v2 with stable
   keys; a player's Unity save should open in the Godot build. A test with three fixtures (fresh, mid,
   corrupt+backup) is required, not assumed.
7. **No Unity runtime to compare against.** See R1 in §10.
8. Everything else (2D sprites, tweens, JSON, file IO, touch, portrait) is a straight mapping with no
   fidelity question.

## 8. Migration complexity

| area | lines to port | type of work | estimate |
| --- | --- | --- | --- |
| `Core` logic (16 systems, engine-free) | 2,607 | mechanical translation, tests guide every step | **4–6 days** |
| `Content` (parsers, validator, save codec) | 669 | translation + JSON edge cases | **1–2 days** |
| `Game` runtime glue (session, save store, level source, art registry) | 1,166 | translation, some re-architecture (autoloads) | **2–3 days** |
| `Game/Ui` minus the board (9 screens + kit) | 1,262 | reconstruction in `Control` nodes | **4–6 days** |
| `BoardScreen` | 1,142 | reconstruction (rendering, input, tweens, overlays) | **4–6 days** |
| tests | 2,220 | port 152 tests to GDScript | **3–4 days** |
| Persian text spike + decision | 306 | spike then port or adapt | **2–3 days** |
| Android export + CI + perf pass | — | new pipeline, not a port | **2–3 days** |
| **total** | **9,060** | | **22–33 engineering days** |

Complexity verdict: **moderate, and unusually low-fidelity-risk for a port** — no serialized data, no
shaders, no physics, no animation, no audio. The two real hazards are Persian shaping and determinism,
both of which are *testable in the repo today*.

## 9. Recommended migration order

Ordered by "dependency first, and by what can be verified headlessly without a device":

1. **Headless core** — `Primitives → DeterministicRandom → StateHash → Board → MatchFinder →
   MoveResolver → PowerUps → Goals → LevelModel → LevelRun → Boosters → Wallet → Lives → Progression →
   SaveData/StarRating`, with its tests ported alongside. Success = the 152 tests' logic runs green in
   `godot --headless`.
2. **Content + save** — parsers, validator, codec, fixtures, save round-trip and corrupt-save recovery.
3. **Persian text spike** (blocks every label in the game) — golden vectors, then decide path (a)/(b).
4. **Regenerators** — tokens, art catalog, (forms if path (b)).
5. **Runtime glue** — `GameSession`, `SaveStore`, `LevelSource`, `ArtRegistry` as autoloads/resources.
6. **UI kit + the four simple screens** — TopBar, Home, Settings, Shop, Districts.
7. **Board screen** — last, because it consumes everything above.
8. **Android** — export preset, compatibility renderer, texture compression, CI build with verification.
9. **Dev scenes + docs** — design-system page and Persian specimen page, as in the Unity project.

This is exactly phases 2–8 of the migration plan, so no work is done twice.

## 10. Estimated technical risks

| id | risk | L | I | mitigation |
| --- | --- | --- | --- | --- |
| **R1** | **There is no working Unity build to compare against.** The Unity project has never compiled or run in this environment (no licence secret), so "parity" cannot mean "matches the running original". | high | high | Define parity as **the 152 tests + the design docs + the golden vectors**. Port the tests first, keep them as the spec, and treat the first Godot run as the project's first real run — documented as such, not hidden. If a Unity licence ever arrives, capture a reference build and add screenshot comparisons. |
| R2 | Persian shaping differs from the hand-written shaper | medium | high | Vectors-first spike (Phase 2 gate); keep `PersianText` as the fallback; test ZWNJ, joining forms, Persian digits, `۱٫۵` decimals and the lives timer string. |
| R3 | Determinism drift (RNG/hash) | medium | high | Port with explicit 64-bit masking; assert the two committed golden values; extend the fixtures with a per-turn hash chain. |
| R4 | Layout drift without a visual reference | high | medium | Port the 415×738 numbers verbatim (they are literals in the C#), keep a Godot dev scene equivalent to `_DesignSystem`, review on three aspect ratios, then on a device. |
| R5 | Save incompatibility | low | high | Keep JSON v2 keys exactly; fixtures: fresh, mid-game, corrupt+backup; a GDScript test decodes a save produced by the C# codec (fixture committed now). |
| R6 | Art fidelity (filtering, nine-slice, rounded corners) | medium | medium | Compare a Godot-rendered board mock against the Python `art/preview/board-mock.png` that already exists — the same composition, two renderers. |
| R7 | Android export unknowns (SDK, templates, keystore) | medium | medium | CI job that exports a debug APK with export templates; keystore from secrets; never mark green without a produced artifact. |
| R8 | Scope creep while porting (adding audio, tutorial, map) | high | medium | The port is **behaviour-for-behaviour**; new features go on a separate list and are out of scope for this migration. `05-checklist.csv` carries a `port | new` column so a feature cannot quietly appear. |
| R9 | Divergence of the design system (two token sources) | low | medium | Generators only; a CI check that the GDScript tokens match `tokens.json`, mirroring today's `design` job. |

## 11. Decisions this audit asks the reviewer to confirm

1. **Branch:** a new `feature/godot-migration` branch cannot be created from this session (the working
   branch is fixed to `arena/d42cf39b-ideal`). The port is therefore isolated **by directory**
   (`godot-port/`, `migration/`) on the current branch, `client/` stays untouched, and a PR to `main` is
   opened at the Phase 2 milestone. Nothing is pushed to `main` directly.
2. **Test framework:** GUT (lightweight, `-s` script runner) vs gdUnit4 (richer, heavier). Recommendation:
   **GUT**, because the suite is 152 plain assertions and CI needs the simplest possible headless runner.
3. **Renderer:** **Compatibility (OpenGL ES 3.0)** as the default Android renderer. Rationale: pure 2D,
   flat vector art, low draw calls, and the widest device reach; `Mobile` (Vulkan) stays a one-line switch
   if profiling on a real device says otherwise.
4. **Persian path:** decide by measurement in Phase 2 (a/b above), not by preference.
