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
| Deterministic RNG | Initial port | xorshift64* represented as two 32-bit words; reference vector added |
| Level definition | Initial port | Structural validation and level metadata |
| Board factory | Initial port | Opening board avoids matches; deterministic reshuffle |
| Goal tracker | Initial port | Piece and obstacle-layer progress |
| Power-up system | Initial port | Blast shapes, color clear, all-piece clear and combo rules |
| Move resolver | Initial port | Swap/booster flow, cascades, chained triggers, clears, obstacle damage, gravity, refill and settle |
| Core tests | Written, not executed | Includes RNG reference vector, board factory and a match-swap case |
| Godot CI workflow | Added, awaiting run | Imports project and executes headless tests with Godot 4.4.1 |
| Unity/Godot full parity | Not verified | Shared deterministic test corpus and event-by-event comparison still needed |
| UI, animation, audio, VFX | Not started | Rebuild natively in Godot |
| Android export | Not started | Renderer/API/device targets still require validation |

## Files added in this phase

- `godot-port/scripts/core/deterministic_random.gd`
- `godot-port/scripts/core/level_definition.gd`
- `godot-port/scripts/core/goal_tracker.gd`
- `godot-port/scripts/core/power_ups.gd`
- `godot-port/scripts/core/board_factory.gd`
- `godot-port/scripts/core/move_resolver.gd`
- `godot-port/tests/test_core.gd` (expanded)
- `.github/workflows/godot-port.yml`

## Parity and correctness cautions

- Unity uses a fixed xorshift64* algorithm. GDScript represents the 64-bit state as two 32-bit words to avoid depending on unsigned integer support. A known seed-1 reference vector is included, but it is not verified until Godot CI executes.
- The port currently records move events as dictionaries rather than Unity event classes. Event names, positions, ordering, goal progress, counters and RNG state must be compared against the C# implementation.
- Board refill and reshuffle order are deterministic contracts. Do not alter loop order or random call order casually.
- The current move resolver is a first translation of the inspected C# logic, not a certified behavior-equivalent implementation.
- No Godot runtime, Android build, or parity test has been executed yet. Source commits are not equivalent to a verified playable build.

## Next milestone

1. Get the Godot headless workflow green; fix every parser/runtime/test issue it reports.
2. Generate deterministic test fixtures from the C# implementation for swaps, all power-up types and pair combinations, obstacles, gravity, cascades and reshuffles.
3. Compare final board ASCII, event sequence, counters, goal progress and RNG state between C# and GDScript.
4. Only after core parity is established, build the interactive board UI and native Godot presentation.
