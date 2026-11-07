# Godot port status

Updated: 2026-11-07
Branch: `feature/godot-migration`
Unity source baseline: `arena/d42cf39b-ideal`

## Implemented source

| Area | Status | Notes |
|---|---|---|
| Godot project scaffold | Created | Main scene points to native gameplay screen |
| Original art and fonts | Imported | 85 PNGs and both Vazir TTF files reused from original Git blobs |
| Chapter-one content | Imported and validated | Ten level JSON files, three districts and twelve tasks |
| Content and asset loaders | Tested | JSON name mapping, metadata and texture resolution |
| Level/catalog validator | Ported and tested | Bounds, goals, obstacle layers, duplicates, rewards and catalog continuity |
| Board model and match finder | Initial port; tested | Runs, squares, clusters and spawn selection |
| Deterministic RNG | Exact reference-tested | C# seed-1 and seed-42 golden vectors and state match |
| State hash | Exact reference-tested | C# fixed-board and seed-42 LevelRun FNV hashes match |
| Board factory | Tested | 20-seed opening-board corpus: full, no automatic matches, legal move |
| Goal tracker and move resolver | Partially tested | Accepted/rejected swaps, move accounting, clears, obstacle damage, rocket creation and mallet trigger |
| Power-up system | Partially tested | Target geometry, electro-ball, super clear and rocket pair combo |
| Wallet and booster inventory | Tested | Spend, grant, caps, buy, consume and refund/history rollback |
| Lives and clock | Tested | Spending and timed refill |
| Level run, stars and progression | Tested | First-clear reward, unlock, task payment and chest claim |
| Save codec and store | Tested | JSON round-trip, v1 migration, corruption fallback and backup recovery |
| Persian gameplay UI | Headless smoke-tested | Gameplay scene instantiates and creates all 81 board cells |
| GDScript load validation | Passed | All listed scripts load under Godot 4.4.1 |
| Headless test suite | Passed | 179 checks, 0 failures |
| Full Unity/Godot parity | Not verified | Full event-order and state-hash fixture comparison remains |
| UI animation/audio/VFX | Not complete | Visual polish and feedback remain |
| Android export | Not started | Export templates, signing, API level and device tests remain |

## Current test evidence

GitHub Actions: [Godot 4.4.1 headless import and core tests](https://github.com/kamandbeauty/Ideal/actions/runs/42406840610)

The 179 passing checks cover:
- Board/match detection, cloning, deterministic RNG golden vectors and 20 opening seeds.
- C# FNV board and LevelRun hash reference vectors.
- Power-up geometry, electro-ball target selection, super clear and rocket pair combo.
- Goal progress, accepted/rejected swaps, LevelRun move accounting, obstacle damage, rocket creation and booster trigger/refund history.
- Wallet, booster inventory, lives and refill timing.
- Level progression, first-clear rewards, unlocks, task payments and chest claims.
- Save JSON round-trip, v1 migration, corrupt-save fallback and backup restoration.
- Full validation/loading of all ten chapter-one levels, three districts, twelve build tasks and original texture lookup.
- Runtime instantiation of the gameplay scene with a populated 9×9 board.

## Parity and correctness cautions

- The current move resolver is a first translation of the inspected C# logic, not a certified behavior-equivalent implementation.
- The port currently records move events as dictionaries rather than Unity event classes. Event names, positions, ordering, goal progress, counters and RNG state must be compared against the C# implementation.
- Golden vectors now cover RNG and selected FNV states; they do not cover every board, power-up pairing or long move sequence.
- All power-up pairings, obstacle layer edge cases, gravity-up cases, long cascades, reshuffle exhaustion and booster inventory edge cases still need shared fixtures.
- The gameplay screen has passed a headless smoke test, but has not yet been run on an Android device.
- No Android APK/AAB or performance result exists yet.

## Next milestone

1. Export deterministic C# fixtures for all power-up/booster combinations, obstacle layers, gravity directions, cascades, reshuffles and full replay sequences.
2. Compare exact board state, event order, counters, goals and RNG/hash outputs.
3. Polish animations, selection feedback, win/lose panels and Persian RTL layout.
4. Port district/home/shop/settings screens and wire persistence/progression/lives across all screens.
5. Add Android export presets, build an APK, and test on representative Android devices.
