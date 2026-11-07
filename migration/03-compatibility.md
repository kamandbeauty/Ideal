# Unity → Godot 4 mapping, and the register of unsupported components

Companion to [`01-audit.md`](01-audit.md) §6–§7. This is the table a phase claims against: if a Unity
feature appears in the code and it is not in this register, the phase is not finished.

Target: **Godot 4.x, GDScript, Android, Compatibility renderer** (no Unity runtime, no WebView, no
wrapper). GDScript only — no C#, no GDExtension — so the shipped game has no .NET dependency.

## 1. Engine-level mapping

| Unity | Godot 4 | notes |
| --- | --- | --- |
| `.unity` scene (generated today) | `.tscn` | authored by hand/script, one per screen + one `Main.tscn` |
| `GameObject` + `AddComponent` at runtime | `Node` subclasses, `PackedScene.instantiate()` | the port builds nodes from scenes, not from code, where the node is structural |
| uGUI `Canvas` (ScreenSpaceOverlay) | `CanvasLayer` + `Control` | one `CanvasLayer` per screen layer (game, HUD, modal) |
| `CanvasScaler` 415×738, match 0.5 | `display/window/stretch/mode=canvas_items`, `aspect=expand`, base viewport 415×738 | **not an exact match** — the deviation is documented and reviewed on 3 aspects |
| `RectTransform` + `UiKit.Place(x,y,w,h)` | `Control` with anchors + `position`/`size` | keep the same design-space numbers: they are literals in the C# |
| `Image` (+ `Image.Type.Sliced`) | `TextureRect` / `NinePatchRect` / `StyleBoxTexture` | patch margins are explicit in Godot (Unity needed runtime `Sprite.Create`) |
| `UiKit.Rounded(radius)` (SDF texture) | `StyleBoxFlat` with `corner_radius_*` | removes a whole generated-texture subsystem |
| `Button` + `onClick` | `Button` + `pressed` signal | |
| `TextMeshProUGUI` | `Label` / `RichTextLabel` | shaping via `TextServerAdvanced` (see §3) |
| `TMP_FontAsset` (medium/bold baked separately) | `FontFile` + `FontVariation` (`variation_opentype` / weight) | one TTF per weight is simplest: Vazir Medium + Vazir Bold are both shipped |
| `SpriteRenderer` + orthographic `Camera` | `Node2D` inside a `SubViewport`, or plain `Node2D` with a `Camera2D` | the board is drawn by camera in Unity; in Godot a `Control`-free `Node2D` layer under the HUD is enough |
| `SpriteRenderer.sortingOrder` | `z_index` / tree order | the port must define an explicit layer table (board backdrop −8 … sparks +2) |
| `Resources.Load<Sprite>("art/<id>")` | `load("res://assets/art/<id>.png")` via a generated registry | registry is generated from `art/manifest.json`, as `ArtCatalog.gen.cs` is today |
| `Application.persistentDataPath` | `user://` | same file name and schema |
| `File.ReadAllText` / `WriteAllText` | `FileAccess.open` | keep temp + `.bak` + atomic replace behaviour |
| Newtonsoft `JsonConvert` | `JSON.stringify` / `JSON.parse_string` | numbers come back as floats — the codec must coerce to int explicitly |
| Input System / legacy `Input` behind `#if` | `InputEventScreenTouch`, `InputEventScreenDrag`, `_unhandled_input` | one path; the reflection fallback disappears |
| `[MenuItem]` editor menu | `@tool` script, `EditorPlugin`, or `godot --headless -s` | build/validation scripts become CLI entry points, which is better for CI |
| `*.asmdef` (5) | — | dropped; GDScript uses `class_name` + folders |
| IL2CPP, `.aab`, keystore via `Editor/CiBuild.cs` | `export_presets.cfg`, `--export-release "Android"`, keystore from env | see §4 |
| `Time.unscaledDeltaTime`, manual tween structs | `_process(delta)`, `Tween` | the port may keep the manual tweens: they are deterministic and already tested |

## 2. Register of Unity components with **no** direct equivalent

Each one is either replaced by a different mechanism (and the replacement is named) or dropped on
purpose. Nothing here is "assumed to work".

| # | component | why it cannot be copied | decision |
| --- | --- | --- | --- |
| 1 | `CanvasScaler.MatchWidthOrHeight = 0.5` | Godot has no geometric-mean scaling | replaced by `canvas_items`/`expand`, deviation documented, verified on 20:9, 16:9, 4:3 |
| 2 | TMP font asset baked by `TmpFontSetup.cs` | Unity-only binary asset | dropped; the TTF ships and Godot builds its own font at import |
| 3 | `Sprite.Create` nine-slice border at runtime | no runtime sprite mutation needed | replaced by `NinePatchRect` patch margins, hard-coded per id in the registry |
| 4 | `SpriteRenderer` sorting + camera framing maths (`FrameCamera`) | different renderer | reconstructed: node z-index table + explicit "fit the grid, leave the booster bar" rule |
| 5 | `EventSystem` / input module resolved by reflection | not needed | dropped |
| 6 | `EditorBuildSettings.scenes` | editor-only | replaced by `run/main_scene` in `project.godot` |
| 7 | Assembly definitions | no equivalent concept | dropped; folder layout + `class_name` |
| 8 | IL2CPP player settings (`ProjectSettings.asset`) | serialized Unity settings | replaced by `project.godot` + `export_presets.cfg` (portrait, package id, min SDK, ARM64) |
| 9 | `Resources/` folder semantics | Godot imports everything in the project | replaced by explicit `res://assets/...` paths and a generated registry |
| 10 | `.meta` import settings | not in the repo at all | Godot `.import` files are generated; the needed flags (no mipmaps, filter off for the 48 px glyphs, ETC2 on Android) are set deliberately |

Nothing in the audit produced an unsupported component that blocks the port. The two items that need
*design*, not translation, are the board's rendering layer (4) and text shaping (§3).

## 3. Persian text: the one system with two honest options

The Unity build shapes Persian itself: `Core/Text/PersianText.cs` (306 lines) over generated joining
tables (`PersianForms.gen.cs`, 196 lines), because TextMeshPro cannot join Arabic script. It also maps
digits to `۰–۹` and formats decimals with `٫` and time as `۱۲:۳۴`.

Godot 4's `TextServerAdvanced` implements Arabic shaping and bidi. So the port has two paths:

- **(a) Trust `TextServer`** and keep a thin GDScript helper for digits, ZWNJ, decimals and time. Less
  code, native rendering, automatic future-proofing.
- **(b) Port `PersianText`** and keep full control, exactly as the Unity build did.

The choice is made by a **Phase 2 spike**, not by opinion: the committed golden vectors
(`Core.Tests/Generated/PersianGoldenVectors.gen.cs`, 84 lines, plus `tools/text/check_font.py` and the
`arabic-reshaper` cross-check) are run through Godot's `TextServer` in headless mode, and the diff is
recorded. Whatever the outcome, the vectors become GDScript tests, so a regression is caught either way.

Known traps for both paths: ZWNJ (`U+200C`) between joined forms, the Persian decimal separator `٫`,
Persian digits in an RTL run of Latin digits, truncation of long labels in `Label` (`text_overrun_behavior`),
and the bold weight (Vazir Bold is a separate file; a synthetic bold would break the type scale).

## 4. Android: renderer, textures, export

- **Renderer: Compatibility (OpenGL ES 3.0).** The game is 2D, flat-vector, ~30–60 draw calls, no shaders,
  no particles; Compatibility has the widest device reach, the smallest binary and the fastest cold start.
  `Mobile` (Vulkan) is a one-line switch if a device profile ever needs it.
- **Textures:** ETC2/ASTC on Android, no mipmaps for UI art, mipmaps off for 48 px glyphs, `filter` nearest
  only where the art is pixel-crisp (it is not — flat vector art wants linear), `detect_3d` off.
- **Resolution:** base 415×738, `canvas_items` stretch, `expand` aspect; portrait locked; safe areas read
  from `DisplayServer.get_display_safe_area()`.
- **Export:** `export_presets.cfg` committed; Gradle build; `arm64-v8a` + `armeabi-v7a`; min SDK 24;
  target SDK current; keystore from repository secrets, never committed. A debug APK must be produced in
  CI before any phase is called done.
- **Battery/loading:** no `_process` work beyond the board's tween list and a 1 Hz HUD tick (same as
  `AppRoot.Update`); scenes loaded on demand, art loaded through one registry.

## 5. Git LFS

- Checked: no `.gitattributes`, no LFS pointers, `git lfs` not installed in the environment.
- Payload: 85 sprites (1.84 MiB) + 2 fonts (198 KiB) + 11 JSON (10 KiB) ≈ **2.0 MiB**. LFS is neither
  needed nor configured.
- Decision point, recorded now so it is not re-litigated: if `godot-port/assets/` grows past ~200 MiB
  (extra chapters' art, audio), move binaries to LFS in a dedicated commit before adding them, and update
  the CI checkout (`lfs: true`).

## 6. What "ported" means (the verification bar)

A file is never "ported" because it compiles. Each phase must show, in `migration/README.md`:

1. `godot --headless --check-only --script <file>` (or `--import`) parses every script.
2. The GDScript test runner passes, with a **count** of tests, not a checkmark.
3. The scene relevant to the phase boots headless (`godot --headless --quit` after loading `Main.tscn`)
   and prints the `[boot]` line the Unity build prints today.
4. On Android: an APK artifact exists in the run, and its size is reported.
5. A commit hash per task group, and the pending list is not hidden.
