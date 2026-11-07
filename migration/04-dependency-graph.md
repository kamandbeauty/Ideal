# Dependency graph of the Unity project, and the Godot shape it implies

Derived from the `namespace`, `types` and `engine_deps` columns of
[`02-inventory.csv`](02-inventory.csv) and from the five `*.asmdef` files (which are the project's own
declaration of who may reference whom).

## 1. Assemblies (as the project declares them)

```mermaid
graph TD
    Editor["Shazdeh.Editor<br/>5 files · 387 lines<br/>UnityEditor only"]
    Tests["Shazdeh.Core.Tests<br/>14 files · 2,220 lines<br/>NUnit, editor-only"]
    Game["Shazdeh.Game<br/>20 files · 3,570 lines<br/>uGUI · TMP · InputSystem"]
    Content["Shazdeh.Content<br/>6 files · 669 lines<br/>Newtonsoft only"]
    Core["Shazdeh.Core<br/>21 files · 2,607 lines<br/>noEngineReferences: true"]

    Editor --> Game
    Editor --> Content
    Editor --> Core
    Tests --> Game
    Tests --> Content
    Tests --> Core
    Game --> Content
    Game --> Core
    Content --> Core
```

`Core` has no engine reference at all — that is the single most useful fact in this audit. 2,607 lines
of the game (the rules, the economy, the save model, the text shaper) can be tested and ported without a
renderer, a window or a device.

## 2. Runtime graph, system level

```mermaid
graph TD
    subgraph Core
        P[Primitives<br/>types, enums]
        RNG[DeterministicRandom]
        HASH[StateHash]
        BOARD[Board / BoardFactory]
        MATCH[MatchFinder]
        MOVE[MoveResolver]
        POWER[PowerUps]
        GOALS[Goals]
        LM[LevelModel]
        RUN[LevelRun]
        STAR[StarRating]
        BOOST[Boosters + BoosterCatalog]
        WALLET[Wallet]
        LIVES[Lives]
        PROG[Progression]
        SAVE[SaveData]
        TEXT[PersianText + PersianForms.gen]
        CLOCK[Clock]
    end

    subgraph Content
        LVJSON[LevelJson]
        LVPARSE[LevelParser + LevelValidator]
        DIST[DistrictModel / DistrictParser]
        CODEC[SaveCodec<br/>Newtonsoft]
    end

    subgraph Game
        APP[AppRoot<br/>navigation]
        SESS[GameSession<br/>session facade]
        STORE[SaveStore<br/>user:// file]
        SRC[LevelSource<br/>Resources JSON]
        ART[ArtLibrary + ArtCatalog.gen]
        INP[InputCompat]
        UI[UiKit · TopBar · Home · Board · District · Settings · Shop · RtlText · Fonts]
    end

    BOARD --> P
    BOARD --> RNG
    MATCH --> BOARD
    MOVE --> BOARD
    MOVE --> MATCH
    MOVE --> POWER
    MOVE --> HASH
    RUN --> BOARD
    RUN --> MOVE
    RUN --> GOALS
    RUN --> LM
    RUN --> HASH
    STAR --> RUN
    BOOST --> WALLET
    WALLET --> SAVE
    LIVES --> CLOCK
    PROG --> SAVE
    LVJSON --> P
    LVPARSE --> LVJSON
    LVPARSE --> LM
    DIST --> P
    CODEC --> SAVE
    CODEC --> CLOCK

    APP --> SESS
    APP --> UI
    SESS --> RUN
    SESS --> BOOST
    SESS --> LIVES
    SESS --> PROG
    SESS --> STAR
    SESS --> SRC
    SESS --> STORE
    SESS --> DIST
    STORE --> CODEC
    SRC --> LVPARSE
    UI --> ART
    UI --> TEXT
    UI --> SESS
    UI --> INP
```

Notes that matter for the port:

- **`GameSession` is the only façade the screens know.** Screens call `Session.*` and nothing else; the
  arrow never points from `Core` upwards. In Godot this is an autoload (`Game` singleton) or a
  `Resource`-held object passed down — the audit recommends an **autoload**, because every screen and the
  HUD need it and there is exactly one.
- **`AppRoot` is the whole navigation graph** (six transitions: home ↔ districts, home ↔ settings,
  home ↔ shop, home → board, board → home). In Godot this becomes a `Main.tscn` with a screen stack and
  `change_scene_to_packed` or a `Control` switcher; the one-way rule (a screen never knows another
  screen) should survive the port.
- **`LevelSource` reads JSON from `Resources/`** with no async; Godot equivalent: `FileAccess` +
  `JSON`, or `Resource` files loaded synchronously. Keep it synchronous — 10 levels, 10 KiB.
- **`ArtLibrary` is a registry with a guaranteed placeholder** (missing art → token-coloured shape). That
  property is what let the art arrive gradually and it is worth keeping in the port: it makes the Godot
  build runnable before any sprite is imported.

## 3. Editor-side graph (dropped or relocated)

```mermaid
graph LR
    MENU[ShazdehMenu<br/>Create scenes · Validate levels] --> APP[AppRoot]
    MENU --> DS[DesignSystemView]
    MENU --> PC[PersianCheckView]
    MENU --> VAL[LevelValidator]
    ARTTOOLS[ArtTools<br/>report missing art] --> CAT[ArtCatalog.gen]
    IMPORT[ArtImportSettings<br/>sprite import rules] --> CAT
    TMPFONT[TmpFontSetup<br/>bake font asset] --> FONT[Vazir TTF]
    BUILD[CiBuild<br/>APK · AAB · iOS] --> PRESET[export presets]
```

These five files do not exist at runtime in Unity either — they are menu items. In Godot they become:

| Unity editor script | Godot destination | why |
| --- | --- | --- |
| `ShazdehMenu` (scenes) | the `.tscn` files themselves + `Main.tscn` | scenes are authored files now, not generated |
| `ShazdehMenu` (validate levels) | `godot-port/tools/validate_levels.gd` run with `--headless -s` | a CI step that can fail a build |
| `ArtTools` | `godot-port/tools/art_report.gd` | same |
| `ArtImportSettings` | `.import` settings + a documented import table | Godot has no per-folder import rules; document and enforce with a check script |
| `TmpFontSetup` | nothing | Godot imports the TTF directly |
| `CiBuild` | `export_presets.cfg` + a `--export-release` CI job | see `03-compatibility.md` §4 |

## 4. What this implies for the Godot project shape

```
godot-port/
  project.godot                 415×738 base, canvas_items/expand, portrait, compatibility renderer
  export_presets.cfg            Android (arm64 + armv7), debug + release
  scenes/
    Main.tscn                   the screen host (was AppRoot)
    ui/{TopBar,Home,Board,Districts,Settings,Shop}.tscn
    dev/{DesignSystem,PersianCheck}.tscn
    board/{BoardView,Cell,Piece}.tscn
  scripts/
    core/**                     one .gd per Core file, class_name, no Node dependency
    content/**                  parsers + validator + save codec
    game/**                     autoloads: Game, Saves, Art, Content
    ui/**                       screen scripts
  assets/
    art/**.png                  copied from client/Assets/Game/Resources/art (85)
    fonts/Vazir-{Medium,Bold}.ttf
    content/levels/**           copied JSON (10 + districts meta)
  test/                         GUT suite, ported 1:1 from the 152 C# tests
  tools/                        validate_levels.gd, art_report.gd, regenerate_tokens.gd, regenerate_catalog.gd
```

The `core/**` folder must not `preload`, `load` or reference `Node`, `SceneTree` or `Input` — the same
rule Unity expressed as `"noEngineReferences": true`, and the same rule that keeps 2,607 lines testable
in headless CI.
