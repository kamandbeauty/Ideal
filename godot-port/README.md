# Godot port — Prince's Palace

Independent Godot 4.x + GDScript client. The Unity project remains in `client/` and is not modified by this port.

## Implemented

- Godot project configuration and native match-3 gameplay scene as the app entry point.
- Imported all 85 original PNG art assets, both original Vazir fonts, ten chapter-one level JSON files and district metadata.
- Level and district content loaders, full level/catalog validation, Persian metadata mapping and asset catalog.
- Board/cell model, match detection, 2×2 squares, clusters and power-up spawn selection.
- Deterministic xorshift64* RNG represented as two 32-bit words; exact C# seed-1 and seed-42 golden vectors pass.
- FNV state hashing ported with C# golden vectors for a fixed board and a seed-42 LevelRun.
- Level definition, board generation, goal tracking and power-up target/combo logic.
- Move resolver for swaps, boosters, cascades, chained triggers, clears, obstacle damage, gravity, refill and settle.
- Wallet, booster inventory, lives/refill clock, star rating, level run, replay hash and progression.
- Versioned JSON save codec and local file store with temporary writes and backup recovery.
- Native 9×9 board UI with original background, piece, power-up and obstacle art; Persian goals/move labels and booster selection.

## Verification

<badge color="success">Godot 4.4.1 headless CI passed</badge>

Latest workflow: [Godot headless import and core tests](https://github.com/kamandbeauty/Ideal/actions/runs/42406840610)

- All listed GDScript files loaded successfully.
- Core suite: 179 checks, 0 failures.
- C# RNG golden draws and state for seeds 1 and 42 match exactly.
- C# FNV board-hash and seed-42 LevelRun hash reference vectors match.
- Twenty opening-board seeds produce full boards without automatic matches and with legal moves.
- All ten chapter-one levels pass full content/catalog validation; all three districts and twelve tasks load.
- Save, progression, economy, lives, booster, power-up and obstacle cases pass.
- Gameplay scene was instantiated in headless mode; it created an 81-cell board and entered level-one playing state.

This verifies the selected headless cases only. Exhaustive Unity/Godot event-by-event parity, every power-up pairing, complete visual polish, Android export, device performance, audio/animation/VFX and release readiness remain outstanding.

Run tests locally from the repository root:

```sh
godot --headless --editor --path godot-port --quit
godot --headless --path godot-port --script res://tests/validate_scripts.gd
godot --headless --path godot-port --script res://tests/test_core.gd
```

See [the migration audit](../migration/initial-audit.md) and [current port status](../migration/godot-port-status.md).
