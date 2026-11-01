# Build and test — M0

Two ways to run the engine and the levels, and what each one proves.

## 1. On your machine (fastest loop)

```bash
# open the project
# Unity Hub → Add → client/   (Unity 6 LTS, Android module)

# menu: کاخ شازده → Create M0 scenes
# open Assets/Scenes/M0_Greybox.unity, press Play
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

# C#: parse every file and check static member access (needs tree-sitter, see requirements.txt)
pip install -r tools/csharp/requirements.txt
python3 tools/csharp/lint.py

# design tokens: WCAG + generated C# in sync
python3 .claude/skills/replica-design/contrast.py replica/design/tokens.json
python3 replica/design/gen_tokens.py && git diff --exit-code -- client/Assets/Game/Generated/Tokens.gen.cs
```

Compiling and running the C# needs Unity or the .NET SDK, and this sandbox has neither. So the
engine tests are written and reviewed here, syntax-checked by `tools/csharp/lint.py`, and executed by
CI (or by your editor) — that is the honest status, not a claim that they passed. The lint is a
grammar check plus a shallow static-member check; it is not a type checker.

## 4. Gates before a build is called good (M0 exit)

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
