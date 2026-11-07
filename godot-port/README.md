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
- Headless test script with a reference RNG vector and basic gameplay cases.
- GitHub Actions workflow for Godot headless import and core tests.

## Verification status

All items above are source additions only. **The Godot workflow has not yet reported a run**, so GDScript parsing, tests, import, Android export and gameplay parity remain unverified. This is not yet a playable or feature-complete game.

Run tests locally from the repository root:

```sh
godot --headless --editor --path godot-port --quit
godot --headless --path godot-port --script res://tests/test_core.gd
```

See [the migration audit](../migration/initial-audit.md) and [current port status](../migration/godot-port-status.md).
