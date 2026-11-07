# Godot port status

Updated: 2026-11-07
Branch: `feature/godot-migration`
Unity source baseline: `arena/d42cf39b-ideal`

## Implemented source

| Area | Status | Notes |
|---|---|---|
| Godot project scaffold | Created | Main scene points to native gameplay screen |
| Original art and fonts | Imported | 85 PNGs and both Vazir TTF files reused from original Git blobs |
| Chapter-one content | Imported | Ten level JSON files and district metadata |
| Content and asset loaders | Tested | JSON name mapping and texture resolution |
| Board model and match finder | Initial port; tested | Runs, squares, clusters and spawn selection |
| Deterministic RNG | Reference-tested | xorshift64* state and sequence match C# seed-1 vector |
| Board factory | Tested | Reproducible opening board without automatic matches |
| Goal tracker and move resolver | Partially tested | Accepted/rejected swaps, clears, obstacle damage, rocket creation and mallet trigger |
| Power-up system | Partially tested | Target geometry, electro-ball, super clear and rocket pair combo |
| Wallet and booster inventory | Tested | Spend, grant, caps, buy and consume |
| Lives and clock | Tested | Spending and timed refill |
| Level run, state hash, stars | Initial port; tested | Same-seed replay hash and star thresholds |
| Progression | Tested | First-clear reward, unlock, task payment and chest claim |
| Save codec and store | Tested | JSON round-trip, v1 migration, corruption fallback and backup recovery |
| Persian gameplay UI | Headless smoke-tested | Gameplay scene instantiates and creates all 81 board cells |
| GDScript load validation | Passed | All listed scripts load under Godot 4.4.1 |
| Headless test suite | Passed | 77 checks, 0 failures |
| Full Unity/Godot parity | Not verified | Full event-order and state-hash fixture comparison remains |
| UI animation/audio/VFX | Not complete | Visual polish and feedback remain |
| Android export | Not started | Export templates, signing, API level and device tests remain |

## Current test evidence

GitHub Actions: [Godot 4.4.1 headless import and core tests](https://github.com/kamandbeauty/Ideal/actions/runs/42406286650)

The 77 passing checks cover:
- Board and match detection, cloning, deterministic RNG sequence and board generation.
- Power-up geometry, electro-ball target selection, super clear and rocket pair combo.
- Goal progress, accepted/rejected swaps, obstacle damage, four-match rocket creation and mallet-triggered rocket.
- Wallet, booster inventory, lives and refill timing.
- Level run replay hash, stars, first-clear rewards, unlocks, task payments and chest claims.
- Save JSON round-trip, v1 migration, corrupt-save fallback and backup restoration.
- Loading all ten chapter-one levels, original texture lookup, and runtime instantiation of the gameplay scene with a populated 9×9 board.

## Parity and correctness cautions

- The current move resolver is a first translation of the inspected C# logic, not a certified behavior-equivalent implementation.
- The port currently records move events as dictionaries rather than Unity event classes. Event names, positions, ordering, goal progress, counters and RNG state must be compared against C#.
- Same-seed replay hash tests do not replace C# reference hashes for a corpus of known boards and runs.
- All power-up pairings, obstacle layer edge cases, gravity-up cases, long cascades, reshuffle exhaustion and booster inventory edge cases still need shared fixtures.
- The gameplay screen has passed a headless smoke test, but has not yet been run on an Android device.
- No Android APK/AAB or performance result exists yet.

## Next milestone

1. Add a deterministic C# fixture export and compare exact board state, event order, counters, goals and RNG/hash outputs.
2. Complete remaining power-up/booster, obstacle, gravity and cascade parity tests.
3. Polish animations, selection feedback, win/lose panels and Persian RTL layout.
4. Port district/home/shop/settings UI and wire SaveStore/Progression/Lives to all screens.
5. Add Android export presets, build an APK, and test on representative Android devices.
