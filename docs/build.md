# Build and test

Two ways to run the game, and what each one proves.

## 1. On your machine (fastest loop)

```bash
# open the project
# Unity Hub → Add → client/   (Unity 6 LTS, Android module)

# menu: کاخ شازده → Create scenes
# then: put a Persian TTF in Assets/Fonts/ and run کاخ شازده → Build UI font (docs/ui.md)
# open Assets/Scenes/App.unity, press Play
```

EditMode tests: Test Runner window, or

```bash
Unity -batchmode -projectPath client -runTests -testPlatform EditMode -testResults results.xml -logFile -
```

Local build: menu **کاخ شازده → Build → Android (AAB)**. Output: `build/Android/Shazdeh.aab`.

## 2. In GitHub Actions (nothing to install)

`.github/workflows/unity.yml`:

| job | runs when | what |
| --- | --- | --- |
| `detect` | always | skips everything with a notice until `client/ProjectSettings/ProjectVersion.txt` exists, and fails if its Unity version differs from `env.UNITY_VERSION` |
| `test` | project exists | EditMode + PlayMode via `game-ci/unity-test-runner`, artifacts kept 14 days |
| `build-android` | project exists | `game-ci/unity-builder` → `Shazdeh.EditorTools.CiBuild.BuildAndroid` → `.aab` |
| `build-ios` | project exists **and** manual dispatch | `CiBuild.BuildIos` on `macos-14` → Xcode project (unsigned) |

Why a custom `buildMethod`: GameCI's default builder needs at least one scene in Build Settings, and
no `.unity` file is committed until the project is opened once. `CiBuild` calls
`ShazdehMenu.EnsureGreyBoxScene()`, which creates the boot scene from code, then builds. That makes a
fresh clone buildable with no editor session.

Manually:

```bash
gh workflow run unity.yml -f target=android
gh workflow run unity.yml -f target=both
```

Secrets and licence activation: `docs/ci.md`. Nothing in this repo contains a key, a keystore or a
licence.

## 3. What can be verified without Unity at all

```bash
# SQL: schema + the 8 wallet constraints
psql -v ON_ERROR_STOP=1 -f replica/schema.sql
psql -v ON_ERROR_STOP=1 -f replica/db/smoke.sql

# levels: regenerate + validate against the same rules the C# validator enforces
python3 tools/levels/gen_levels.py --check

# chapter meta: districts, tasks, chests (mirrors DistrictParser.Validate)
python3 tools/content/check_meta.py

# C#: parse every file, check static member access, and check that every Unity type is in scope
# (needs tree-sitter, see requirements.txt)
pip install -r tools/csharp/requirements.txt
python3 tools/csharp/lint.py

# Persian: letter tables vs the Unicode database, our shaping vs arabic-reshaper, golden vectors,
# and whether the shipped font can draw what the shaper emits
pip install -r tools/text/requirements.txt
python3 tools/text/gen_persian_table.py --check
python3 tools/text/persian_ref.py --check
python3 tools/text/check_font.py
python3 tools/text/persian_ref.py --emit && git diff --exit-code -- client/Assets/Core.Tests/Generated

# art: the contract, its generated catalog, and every committed sprite
python3 tools/art/art.py --check

# design tokens: WCAG + generated C# in sync
python3 .claude/skills/replica-design/contrast.py replica/design/tokens.json
python3 replica/design/gen_tokens.py && git diff --exit-code -- client/Assets/Game/Generated/Tokens.gen.cs
```

Compiling and running the C# needs Unity or the .NET SDK, and this sandbox has neither. So the
engine tests are written and reviewed here, syntax-checked by `tools/csharp/lint.py`, and executed by
CI (or by your editor) — that is the honest status, not a claim that they passed. The lint is a
grammar check, a shallow static-member check, and a namespace check (a type named without its
`using` is `CS0246`, which reads like valid code to a human). It is not a type checker.

## 4. Gates before a build is called good (M0 exit — engine)

- EditMode tests green, including the 40-seed × 60-move invariant run.
- Every level loads, validates, and has a legal opening move on 5 seeds.
- Same seed + same moves ⇒ same state hash (determinism is the anti-cheat foundation).
- 60 fps with a 9×9 board in the editor, and no per-frame allocations from the board loop
  (Profiler → GC Alloc: 0 B in `RefreshTiles`/engine calls; the grey box allocates on purpose, the
  real view will not).
- People who play match-3 say the swap feels right. That gate is not automated and never will be.

## 5. Gates before a build is called good (M1 exit: offline economy)

- A fresh install starts at level 1 with 5 lives, 0 coins, 0 potions, and no network.
- Losing an attempt costs exactly one life; killing the app mid-refill and reopening it restores
  lives from `livesUpdatedAtUnix` (no timers, no background job).
- The first clear of a level pays its `RewardCoins`/`RewardPotions` once, unlocks `number + 1`, and a
  replay pays nothing.
- A district task is charged once, "Do it" is all-or-nothing, and its chest opens only after every
  task is built.
- Deleting `shazdeh-save.json` starts a new save; corrupting it recovers `.bak`; corrupting both
  starts a new save with both failures logged. The game never crashes on a save.
- `docs/decisions/0001-offline-first.md` still holds: nothing above needs a server.

## 6. Gates before a build is called good (M2 exit: screens + Persian)

- Every string a player reads is Persian, right to left, shaped — and the shaping is byte-identical to
  `arabic-reshaper` on all 33 shipped strings (`tools/text/persian_ref.py --check`).
- Numbers are Persian numerals with Persian separators (`۱٬۲۳۴`), counts read `۳ از ۵`, and a countdown
  reads `۲۹:۵۹` — never ASCII digits in the UI.
- The home → play → result → home loop works with the network off, and a loss costs exactly one life.
- A district can be built from potions earned on the board, and its chest opens once.
- No screen contains a hex colour, a raw font size or a duration: they come from `Tokens.gen.cs`.
- `_PersianCheck.unity` reads correctly with the real UI font on a real device, at both 16:9 and 19.5:9.
- The board still runs at 60 fps with the canvas on top (Profiler: no per-frame allocations from the
  HUD; `Refresh` runs on change, not per frame).

## 7. Gates before a build is called good (M3 exit: art pipeline)

- The manifest is valid, `ArtCatalog.gen.cs` is current, and every committed PNG has the size, alpha
  channel and weight budget the contract asks for (`art.py --check`).
- `art.py --check --strict` passes: every required sprite exists. It is green: 84 assets in the contract,
  all 84 on disk, 10 of them required.
- Every screen still runs with zero art files present (the placeholder path is the default path).
- The board is readable at 48 px with real art: five stones distinguishable in greyscale by silhouette.
- One light, one camera across the three district plates; no baked text, no baked glow.
- 60 fps with the art in place: the pieces batch into one atlas per group, ≤ 150 draw calls.

## 8. Gates before a build is called good (M4 exit: the turn)

- A swipe of at least 0.45 of a cell plays the move; a shorter drag is a tap; a rejected move springs
  back and costs nothing.
- The view never edits the board: it plays the event list the model returns, and `Update` early-returns
  while a tween is running, so two moves cannot overlap.
- Stars come from `bestMovesLeft`, so a replay that does worse never loses a star already earned.
- **A booster costs a booster only when the board accepts the target** — an armed chip fired at an empty
  cell leaves the count untouched (`GameSession.TryUseBooster` refunds).
- A booster costs no move: `MovesLeft` and `MovesUsed` are unchanged by `LevelRun.UseBooster`.
- Counts stay in `[0, 9]`, a purchase charges only for what fits under the cap, and a save written by
  v1 is migrated to v2 with the starter set instead of five zeros.
- Every screen still runs with the booster bar present but no booster art: the chip stays a chip.
