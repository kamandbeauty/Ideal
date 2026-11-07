# Godot port — Prince's Palace

Independent Godot 4.x + GDScript client. The Unity project remains in `client/` and is not modified by this port.

## Implemented

- Godot project configuration and native match-3 gameplay scene as the app entry point.
- Imported all 85 original PNG art assets, both original Vazir fonts, ten chapter-one level JSON files and district metadata.
- Content loader maps JSON piece, goal, obstacle and gravity names to the Godot game model.
- Asset catalog maps piece, power-up and obstacle enums to original textures.
- Board/cell model, match detection, 2×2 squares, clusters and power-up spawn selection.
- Deterministic xorshift64* RNG represented as two 32-bit words; C# reference sequence tests pass.
- Level definition, board generation, goal tracking and power-up target/combo logic.
- Move resolver for swaps, boosters, cascades, chained triggers, clears, obstacle damage, gravity, refill and settle.
- Wallet, booster inventory, lives/refill clock, star rating, level run, replay hash and progression.
- Versioned JSON save codec and local file store with temporary writes and backup recovery.
- Native 9×9 board UI with original background, piece, power-up and obstacle art; Persian goals/move labels and booster selection.

## Verification

<badge color="success">Godot 4.4.1 headless CI passed</badge>

Latest workflow: [Godot headless import and core tests](https://github.com/kamandbeauty/Ideal/actions/runs/42406286650)

- All listed GDScript files loaded successfully.
- Core suite: 77 checks, 0 failures.
- Original chapter-one levels load and map correctly.
- Original piece, power-up and obstacle textures resolve.
- Save round-trip, v1 migration and backup recovery pass.
- Wallet, booster bag, lives, level progression, task completion and chest claims pass.
- The gameplay scene was instantiated in headless mode; it created an 81-cell board and entered level-one playing state.

This verifies the selected headless cases only. Full Unity/Godot event-by-event parity, every power-up pairing, complete visual polish, Android export, device performance, audio/animation/VFX and release readiness remain outstanding.

Run tests locally from the repository root:

```sh
godot --headless --editor --path godot-port --quit
godot --headless --path godot-port --script res://tests/validate_scripts.gd
godot --headless --path godot-port --script res://tests/test_core.gd
```

See [the migration audit](../migration/initial-audit.md) and [current port status](../migration/godot-port-status.md).
