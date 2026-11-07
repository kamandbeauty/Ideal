# Godot port status

Updated: 2026-11-07
Branch: `feature/godot-migration`
Unity source baseline: `arena/d42cf39b-ideal`

## Implemented in this phase

| Area | Status | Notes |
|---|---|---|
| Godot project scaffold | Created | `project.godot`, main scene, minimal app shell |
| Shared game enums | Ported | Numeric values align with `Primitives.cs` |
| Board model | Initial port | Cells, obstacles, pieces, power-ups, clone/copy, ASCII fixtures |
| Match detection | Initial port | Horizontal/vertical runs, square detection, run clusters |
| Legal move scan | Initial port | Swap simulation and restoration |
| Automated test script | Added, not executed | Requires Godot 4 headless runtime |
| Move resolution/cascades | Not started | Next core gameplay milestone |
| RNG and board generation | Not started | Must preserve exact xorshift64* sequence and call order |
| Goals/obstacle damage | Not started | Must match event and progress semantics |
| Power-up target/combination rules | Not started | Must be ported with deterministic fixtures |
| UI, animation, audio, VFX | Not started | Rebuild natively in Godot |
| Android export | Not started | Renderer/API/device targets still require validation |

## Files created

- `godot-port/project.godot`
- `godot-port/scenes/main.tscn`
- `godot-port/scripts/main.gd`
- `godot-port/scripts/core/game_types.gd`
- `godot-port/scripts/core/board_model.gd`
- `godot-port/scripts/core/match_finder.gd`
- `godot-port/tests/test_core.gd`

## Important parity notes

- Unity uses row-major storage and scans match runs bottom-up, then left-to-right. The initial GDScript implementation follows that order.
- Piece and power-up enum numeric values are part of the deterministic contract and must not be reordered.
- The first pass is not yet a complete gameplay port. In particular, the move resolver, RNG, cascades, power-up chain expansion, obstacle damage, refill, reshuffle, save data, and server contracts remain outstanding.
- No Godot runtime, Android build, or parity test has been executed yet. The current commits are source additions only, not a verified playable build.

## Next milestone

Port the deterministic RNG and board factory, then port the full `MoveResolver` event flow and power-up target rules. Add shared test vectors from the C# core and compare board state, event order, counters, and RNG state. Only after these tests pass should the board UI be implemented.
