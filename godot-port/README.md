# Godot port — Prince's Palace

Independent Godot 4.x + GDScript client. The Unity project remains in `client/` and is not modified by this port.

## Migration rules

- Keep Unity source, assets, and project settings in `client/` unchanged.
- Do not copy Unity-generated `Library/`, `Temp/`, `Obj/`, or build output.
- Do not add Unity as a runtime or build dependency for Godot.
- Port deterministic game rules before rebuilding presentation.
- Preserve Persian RTL, Persian numerals, product scope, and backend contracts.
- Do not claim parity until matching deterministic tests pass.

## Current implementation

- Godot project configuration and a minimal Persian RTL-capable app shell.
- Shared numeric game enums matching the Unity core.
- Board model: cells, pieces, power-ups, obstacles, bounds, clone/copy, ASCII fixtures.
- Match finder: horizontal/vertical runs, 2×2 squares, run clusters, power-up selection, legal-move detection.
- Initial headless test script for board cloning and match detection.

## Verification status

The files have been committed, but **Godot has not yet been run in this environment**. Script parsing, test execution, asset import, and Android export remain unverified. Do not treat the test script as passing until a Godot 4 executable runs it successfully.

Run tests from this directory with:

```sh
godot --headless --path . --script res://tests/test_core.gd
```

See [the migration audit](../migration/initial-audit.md) and [current port status](../migration/godot-port-status.md).
