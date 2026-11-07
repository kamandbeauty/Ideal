# Godot port status

Updated: 2026-11-07
Branch: `feature/godot-migration`
Unity source baseline: `arena/d42cf39b-ideal`

## Implemented source

| Area | Status | Notes |
|---|---|---|
| Godot project scaffold | Created | Home screen is the main scene |
| Native UI screens | Headless smoke-tested | Home, gameplay, district construction, booster shop and settings |
| Original art and fonts | Imported | 85 PNGs and both Vazir TTF files reused from original Git blobs |
| Chapter-one content | Imported and validated | Ten level JSON files, three districts and twelve tasks |
| Content and asset loaders | Tested | JSON name mapping, metadata and texture resolution |
| Level/catalog validator | Ported and tested | Bounds, goals, obstacle layers, duplicates, rewards and catalog continuity |
| Board model and match finder | Initial port; tested | Runs, squares, clusters and spawn selection |
| Deterministic RNG | Exact reference-tested | C# seed-1 and seed-42 golden vectors and state match |
| State hash | Exact reference-tested | C# fixed-board and seed-42 LevelRun FNV hashes match |
| Board factory | Tested | 20-seed opening-board corpus: full, no automatic matches, legal move |
| Real level move sequences | Tested | 500 legal-move attempts across all ten chapter-one levels |
| Goal tracker and move resolver | Partially tested | Accepted/rejected swaps, move accounting, clears, obstacle damage, rocket creation and mallet trigger |
| Power-up system | Partially tested | Target geometry, electro-ball, super clear, rocket pair combo and edge clipping |
| Wallet and booster inventory | Tested | Spend, grant, caps, buy, consume and refund/history rollback |
| Lives and clock | Tested | Spending and timed refill |
| Level run, stars and progression | Tested | First-clear reward, unlock, task payment and chest claim |
| Save codec and store | Tested | JSON round-trip, v1 migration, corruption fallback and backup recovery |
| GDScript load validation | Passed | 33 scripts load under Godot 4.4.1 |
| Headless test suite | Passed | 1,722 checks, 0 failures |
| Full Unity/Godot parity | Not verified | Full event-order and state-hash fixture comparison remains |
| UI animation/audio/VFX | Not complete | Visual polish and feedback remain |
| Android export | Not started | Export templates, signing, API level and device tests remain |

## Current test evidence

GitHub Actions: [Godot 4.4.1 headless import and core tests](https://github.com/kamandbeauty/Ideal/actions/runs/42407372225)

The 1,722 passing checks cover:
- Board/match detection, cloning, deterministic RNG golden vectors and 20 opening seeds.
- C# FNV board and LevelRun hash reference vectors.
- Power-up geometry, electro-ball target selection, super clear, rocket pair combo and edge clipping.
- Goal progress, accepted/rejected swaps, LevelRun move accounting, obstacle damage, rocket creation and booster trigger/refund history.
- Wallet, booster inventory, lives and refill timing.
- Level progression, first-clear rewards, unlocks, task payments and chest claims.
- Save JSON round-trip, v1 migration, corrupt-save fallback and backup restoration.
- Full validation/loading of all ten chapter-one levels, three districts, twelve build tasks and original texture lookup.
- 500 move attempts across the actual chapter levels.
- Runtime instantiation of home, gameplay, district, shop and settings screens.

## Parity and correctness cautions

- The current move resolver is a first translation of the inspected C# logic, not a certified behavior-equivalent implementation.
- The port currently records move events as dictionaries rather than Unity event classes. Event names, positions, ordering, goal progress, counters and RNG state must be compared against the C# implementation.
- Golden vectors cover RNG and selected FNV states; they do not cover every board, power-up pairing or long move sequence.
- All power-up pairings, obstacle layer edge cases, gravity-up cases, long cascades, reshuffle exhaustion and booster inventory edge cases still need shared fixtures.
- UI screens have passed headless smoke tests, but have not yet been run on Android devices.
- No Android APK/AAB or performance result exists yet.

## Next milestone

1. Export deterministic C# fixtures for all power-up/booster combinations, obstacle layers, gravity directions, cascades, reshuffles and full replay sequences.
2. Compare exact board state, event order, counters, goals and RNG/hash outputs.
3. Polish animations, selection feedback, win/lose panels and Persian RTL layout.
4. Add home/district/shop/settings UX polish and full persistence wiring.
5. Add Android export presets, build an APK, and test on representative Android devices.
