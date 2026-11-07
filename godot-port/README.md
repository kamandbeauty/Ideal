# Godot port — Prince's Palace

Independent Godot 4.x + GDScript client. The Unity project remains in `client/` and is not modified by this port.

## Migration rules

- Keep Unity source, assets, and project settings in `client/` unchanged.
- Do not copy Unity-generated `Library/`, `Temp/`, `Obj/`, or build output.
- Do not add Unity as a runtime or build dependency for Godot.
- Port deterministic game rules before rebuilding presentation.
- Preserve Persian RTL, Persian numerals, product scope, and backend contracts.
- Do not claim parity until matching deterministic tests pass.

## Implemented source modules

- Godot project configuration and a minimal Persian-language app shell.
- Shared numeric game enums matching the Unity core.
- Board/cell model, cloning, ASCII fixtures and board inspection helpers.
- Match detection for horizontal/vertical runs and 2×2 squares; clusters and power-up spawn selection.
- Deterministic xorshift64* RNG represented as two 32-bit words to preserve unsigned 64-bit behavior in GDScript.
- Level definition model and structural validation.
- Goal progress tracking for piece and obstacle objectives.
- Initial board generation, no-opening-match placement and deterministic reshuffle.
- Power-up target shapes and combo targeting.
- Move resolver for swaps, boosters, cascades, chained triggers, clears, obstacle damage, gravity, refill and settle/reshuffle.
- Headless tests for match detection, RNG reference vectors, power-up targeting/combos, board generation, legal moves, goals, rejected/accepted swaps, obstacle damage, power-up creation and mallet-triggered rocket chains.
- GitHub Actions workflow for Godot headless import, script loading validation and core tests.

## Verification

<badge color="success">Godot 4.4.1 headless CI passed</badge>

- All 11 listed GDScript files loaded successfully.
- Core test suite: 34 checks, 0 failures.
- The xorshift64* sequence matches the C# reference vector for seed 1.
- Board generation is reproducible for a fixed seed and starts without automatic matches.
- A real swap creates a match, clears pieces, advances goals and damages an obstacle.
- A four-piece match creates a rocket; using a mallet on a rocket triggers its column clear.

This confirms the tested core cases only. It does **not** yet prove full Unity/Godot event-by-event parity, all power-up pairings, full feature coverage, Android export, device performance, or a complete playable game.

Run tests locally from the repository root:

```sh
godot --headless --editor --path godot-port --quit
godot --headless --path godot-port --script res://tests/validate_scripts.gd
godot --headless --path godot-port --script res://tests/test_core.gd
```

See [the migration audit](../migration/initial-audit.md) and [current port status](../migration/godot-port-status.md).
