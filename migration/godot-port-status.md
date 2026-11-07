# Godot port status

Updated: 2026-11-07
Branch: `feature/godot-migration`
Unity source baseline: `arena/d42cf39b-ideal`

## Implemented source

| Area | Status | Notes |
|---|---|---|
| Godot project scaffold | Created | `project.godot`, main scene, minimal app shell |
| Shared game enums | Initial port | Numeric values align with Unity `Primitives.cs` |
| Board model | Initial port | Cells, obstacles, pieces, power-ups, clone/copy, ASCII fixtures |
| Match detection | Initial port | Horizontal/vertical runs, 2×2 squares, clusters and spawn selection |
| Deterministic RNG | Initial port; reference-tested | xorshift64* represented as two 32-bit words; C# seed-1 vector and sequence pass |
| Level definition | Initial port; tested | Structural validation and level metadata |
| Board factory | Initial port; tested | Opening board avoids matches and reproduces from the same seed |
| Goal tracker | Initial port; tested | Piece and obstacle-layer progress |
| Power-up system | Initial port; partially tested | Blast geometry, electro-ball targeting, super clear and rocket pair combo |
| Move resolver | Initial port; partially tested | Swap validation, accepted/rejected swaps, match clears, goal events, obstacle damage, four-match rocket creation, mallet-triggered rocket, gravity/refill/settle path |
| GDScript loading | Passed | 11 script files load under Godot 4.4.1 |
| Core headless tests | Passed | 34 checks, 0 failures |
| Unity/Godot full parity | Not verified | Shared deterministic test corpus and event-by-event comparison still needed |
| Remaining power-up combinations | Not fully tested | All pairings and long trigger chains need reference fixtures |
| UI, animation, audio, VFX | Not started | Rebuild natively in Godot |
| Assets and fonts | Not imported | Need source manifest reconciliation and import validation |
| Save/progression/economy/backend | Not started | Must preserve save compatibility and server-authoritative contracts |
| Android export | Not started | Renderer/API/device targets still require validation |

## Current test evidence

GitHub Actions run: [Godot 4 headless import and core tests](https://github.com/kamandbeauty/Ideal/actions/runs/42404951036)

Verified checks include:
- Horizontal run detection, diagonal non-match, 2×2 square detection and board clone independence.
- xorshift64* reference output, internal state and subsequent sequence values.
- Dynamite area, rocket row/column, electro-ball most-common-color selection, super-electro-ball full clear and rocket pair cross.
- Valid level structure, no automatic opening match, reproducible board generation and at least one legal move.
- Goal progress, invalid swap rejection, no-match rejection and board restoration.
- Accepted match swap, piece clearing, obstacle destruction and both goal progress types.
- Four-piece rocket creation and mallet-triggered rocket column clear.

## Parity and correctness cautions

- The current move resolver is a first translation of the inspected C# logic, not a certified behavior-equivalent implementation.
- The port currently records move events as dictionaries rather than Unity event classes. Event names, positions, ordering, goal progress, counters and RNG state must be compared against the C# implementation.
- Board refill and reshuffle order are deterministic contracts. Do not alter loop order or random call order casually.
- The current CI validates scripts and selected deterministic cases; it does not compare the full C# and GDScript outputs.
- No Android build, device test, or complete playable build has been produced.

## Next milestone

1. Add shared C# → GDScript deterministic fixtures for all power-up types/pairs, obstacle layers, gravity directions, cascades, boosters and reshuffles.
2. Port and test booster catalog/bag, wallet/economy, level-run state, progression, save data and server contract boundaries.
3. Reconcile and import the project's original art, fonts and UI assets.
4. Build the interactive native Godot board and Persian RTL screens.
5. Add Android export templates, export presets, APK build and device-performance validation.
