# client — کاخ شازده (Unity 6)

The game. Native Android + iOS, no web build.

```
Assets/
  Core/          Shazdeh.Core     the engine: board, matches, power-ups, goals, level run.
                                  No UnityEngine anywhere — pure C#, unit tested, replayable.
  Content/       Shazdeh.Content  level JSON → LevelDefinition, the validator, the level files.
  Game/          Shazdeh.Game     grey-box view, HUD, tokens (generated), level source.
  Editor/        Shazdeh.Editor   menu, scene creation, headless CI build.
  Core.Tests/    EditMode tests   engine + content tests (NUnit).
Packages/manifest.json
```

## First run

1. Install **Unity 6 LTS** (6.0 LTS) via Unity Hub and add the Android module (iOS needs a Mac).
2. Open `client/` as the project (Hub → Add → this folder).
3. Unity resolves `Packages/manifest.json`. If a package version is unknown to your editor, let the
   Package Manager upgrade it and commit the new `manifest.json` + `packages-lock.json`.
4. Menu **کاخ شازده → Create M0 scenes**. This writes `Assets/Scenes/M0_Greybox.unity` and
   `Assets/Scenes/_DesignSystem.unity` **from code** and puts them in Build Settings. Nothing in this
   repo hand-edits a `.unity` file.
5. Open `Assets/Scenes/M0_Greybox.unity`, press Play.

The first time Unity opens the project it generates `ProjectSettings/` — commit that. It is also the
file the Unity CI workflow waits for (`ProjectSettings/ProjectVersion.txt`): until it exists, the
build jobs intentionally skip.

## What M0 does

- Loads `levels/ch01/level-001.json` … `level-010.json` through `Shazdeh.Content`.
- Builds the board from the level + a seed and plays the **real** engine: swaps, cascades, power-ups,
  obstacles, goals, moves, win/lose, dead-board reshuffle.
- Draws the board as coloured squares (tokens, no art) with an IMGUI HUD.
- Tap two adjacent tiles to swap. Select a tile and press **1–5** for Mallet / Ram / Auger /
  Whirlwind / Falcon. **R** restarts, **N** goes to the next level.

It is meant to feel bad to look at and right to play. Screens, real art, animation and the Persian UI
come in M1/M2 (`replica/design/components.md` is the spec).

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
moves ⇒ identical state hash), every shipped level's JSON, and the validator's ability to reject bad
content.

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
- No screen reads or writes currency; the wallet is the server's (M1). The client animates numbers it
  was given.
- No hard-coded colour, font size or duration: everything comes from `Tokens.gen.cs`, generated from
  `replica/design/tokens.json` by `replica/design/gen_tokens.py`. CI fails if the two drift.
- Art is ours: Persian-royal direction, no traced or recoloured assets from the original.
