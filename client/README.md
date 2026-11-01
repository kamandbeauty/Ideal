# client — کاخ شازده (Unity 6)

The game. Native Android + iOS, no web build.

```
Assets/
  Core/          Shazdeh.Core     the engine: board, matches, power-ups, goals, level run.
                                  No UnityEngine anywhere — pure C#, unit tested, replayable.
  Content/       Shazdeh.Content  level JSON → LevelDefinition, the validator, the level files;
                                  chapter meta (districts/tasks/chests) and the save codec.
  Game/          Shazdeh.Game     AppRoot, GameSession, screens (Ui/), tokens (generated), save file.
  Editor/        Shazdeh.Editor   menu, scene creation, font build, headless CI build.
  Core.Tests/    EditMode tests   engine + content + Persian text tests (NUnit).
  Fonts/         (empty in git)   drop a Persian TTF here, then build the font asset — see docs/ui.md
Packages/manifest.json
```

## First run

1. Install **Unity 6 LTS** (6.0 LTS) via Unity Hub and add the Android module (iOS needs a Mac).
2. Open `client/` as the project (Hub → Add → this folder).
3. Unity resolves `Packages/manifest.json`. If a package version is unknown to your editor, let the
   Package Manager upgrade it and commit the new `manifest.json` + `packages-lock.json`.
4. Menu **کاخ شازده → Create scenes**. This writes `Assets/Scenes/App.unity` (the game),
   `Assets/Scenes/_DesignSystem.unity` (tokens) and `Assets/Scenes/_PersianCheck.unity` (the Persian
   specimen) **from code** and puts the app scene in Build Settings. Nothing in this repo hand-edits a
   `.unity` file.
5. Persian text needs a font: put a Persian TTF in `Assets/Fonts/` and run **کاخ شازده → Build UI
   font** (`docs/ui.md` §2). Without it every label falls back to the TMP default and warns once.
6. Open `Assets/Scenes/App.unity`, press Play. You land on the home screen.

The first time Unity opens the project it generates `ProjectSettings/` — commit that. It is also the
file the Unity CI workflow waits for (`ProjectSettings/ProjectVersion.txt`): until it exists, the
build jobs intentionally skip.

## What it does

- Loads `levels/ch01/level-001.json` … `level-010.json` through `Shazdeh.Content`.
- Builds the board from the level + a seed and plays the **real** engine: swaps, cascades, power-ups,
  obstacles, goals, moves, win/lose, dead-board reshuffle.
- Draws the board as coloured squares (tokens, no art). Tap two adjacent tiles to swap.
- Home → level card → play → result (reward or lost life) → home, all in Persian, right to left.

It is meant to feel bad to look at and right to play: art, animation and audio are the next milestone
(`replica/design/art-direction.md` is the spec).

## What M1 adds (offline economy)

The game is playable with the network off, and its save is the source of truth
(`docs/decisions/0001-offline-first.md`).

- **Save** — `Game/SaveStore.cs` writes `shazdeh-save.json` next to the app (temp file + `.bak`, one
  kept generation). `Content/SaveCodec.cs` migrates older versions, clamps impossible numbers, and
  turns a corrupt file into a fresh save instead of a crash.
- **Wallet** — coins and potions, never negative, all-or-nothing spends.
- **Lives** — 5, one back every 30 minutes, computed from `livesUpdatedAtUnix` (no timers, so closing
  the app for two days is handled by arithmetic). A loss spends one; a win does not.
- **Progression** — first clear pays the level's potions/coins and unlocks the next level; replays pay
  nothing but are recorded (`plays`, `bestMovesLeft`, replay hash).
- **Districts** — `Assets/Content/Resources/meta/ch01-districts.json`: 3 districts, 12 tasks, 685
  potions to build everything, one chest each. The districts screen buys tasks one at a time or all at
  once ("همه را بساز"), then opens the chest when the district is built.
- **Autosave** — every state change writes immediately; the save is small enough that debouncing
  would add risk for no gain.

```bash
python3 tools/content/check_meta.py     # districts/tasks/chests, no Unity needed
```

## What M2 adds (screens, RTL, Persian numerals)

- **Three screens** built in code from the tokens: home, board, districts (`Assets/Game/Ui/`). One
  component in the scene (`AppRoot`), no prefabs, no hand-edited `.unity`.
- **Persian, actually shaped.** TMP does not shape Arabic script, so `Shazdeh.Core.Text.PersianText`
  replaces letters with their contextual forms and reorders the line for a left-to-right renderer, then
  `RtlText` puts it on the label. Numbers go through `PersianText.Number` → `۱٬۲۳۴`.
- **A specimen scene** (`_PersianCheck.unity`) that separates a font problem from a shaper problem from
  a layout problem.
- Details, the algorithm and what is deliberately not covered: `docs/ui.md`.

## Tests

```
Window → General → Test Runner → EditMode → Run All
```

or headless:

```bash
Unity -batchmode -projectPath client -runTests -testPlatform EditMode \
      -testResults results.xml -logFile -
```

`Shazdeh.Core.Tests` covers the RNG golden vectors, match finding, the power-up rules, board
construction, the resolver invariants (40 seeds × 60 moves), level-run determinism (same seed + same
moves ⇒ identical state hash), every shipped level's JSON, the validator's ability to reject bad
content, the economy (wallet, lives, progression, save codec, file store, district content) and the
Persian shaper against generated golden vectors (see `docs/ui.md` §1).

## Levels

`Assets/Content/Resources/levels/ch01/*.json` — authored by `tools/levels/gen_levels.py`, validated by
`LevelValidator` (mirrored in that script), and re-validated in tests. To change one by hand, edit the
JSON and run **کاخ شازده → Validate levels**. A level is its parameters, its obstacle layout and its
goals; the board itself is generated from a seed, which is what makes replays verifiable.

## Builds

- Locally: **کاخ شازده → Build → Android (AAB)** / **iOS (Xcode project)**.
- In CI: `.github/workflows/unity.yml` calls `Shazdeh.EditorTools.CiBuild.BuildAndroid` and
  `BuildIos` on a fresh clone, creating the boot scene itself. Secrets: `docs/ci.md`.

## Rules this project holds itself to

- `Shazdeh.Core` has `noEngineReferences: true`. If you need UnityEngine in the engine, the engine is
  wrong.
- Currency changes go through `Shazdeh.Core.Wallet` only. When purchases arrive the server mirrors
  those rules (`replica/architecture.md`); it does not replace them.
- No hard-coded colour, font size or duration: everything comes from `Tokens.gen.cs`, generated from
  `replica/design/tokens.json` by `replica/design/gen_tokens.py`. CI fails if the two drift.
- Art is ours: Persian-royal direction, no traced or recoloured assets from the original.
