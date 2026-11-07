# Godot port — Prince's Palace

This directory is reserved for the independent Godot 4.x + GDScript client.

## Migration rules

- The existing Unity project remains in `client/` and is not modified by the port.
- The Godot project will be created here after the initial audit is complete.
- Do not copy Unity's generated `Library/`, `Temp/`, `Obj/`, or build output.
- Do not add Unity as a runtime or build dependency for the Godot game.
- Port game rules with deterministic fixtures before rebuilding presentation.
- Preserve Persian RTL, Persian numerals, the existing product scope, and backend contracts.
- Keep migration status and verification evidence in `../migration/`.

## Current status

Audit/scaffolding only. No `project.godot`, scenes, scripts, or converted assets have been created yet. This is intentional: the full source and asset inventory must be completed before implementation begins.

See [the initial audit](../migration/initial-audit.md).
