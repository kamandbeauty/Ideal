# ARTILLERY FRONTLINE

Original, offline, landscape 3D artillery combat for Android, built with Godot 4.7.2 and typed GDScript.

## Playable vertical slice

- One authored desert battlefield: **Sable Ridge**.
- Original Blender-authored **Kestrel M-42** 155 mm howitzer with independent traverse/elevation, recoil, breech animation and reload.
- **M72 HE** and **M91 AP** ammunition; swept ballistic collision and matching trajectory prediction.
- Stationary emplacements, patrolling Warden tanks and Nomad transports.
- Five sequential missions, optional objectives, performance rewards, stars, credits and permanent upgrades.
- Layered pooled explosions, smoke, dust, debris, shockwaves, impact light, craters and staged destruction.
- Touch-first HUD, optical zoom, shell-tracking camera, pause, briefing, campaign, arsenal, results and settings.
- Versioned local saves with atomic replacement and backup recovery.
- Low/medium/high/auto graphics, sustained frame-time adaptation, 30/60 FPS targets.

## Open and run

1. Install Godot **4.7.2 stable** (standard, non-Mono).
2. Import `project.godot`.
3. Press F6 on `scenes/core/main.tscn`, or F5.

Desktop controls: drag left mouse to aim; **W/S** elevation, **A/D** traverse; **Space** fire; **R** reload; **F** fire-control solution; **Tab** next target; **1/2** ammunition; **Z** zoom; **C** camera; **Esc** pause. Android uses the on-screen controls and one-finger aiming surface.

## Validate

```sh
godot --headless --path ARTILLERY_FRONTLINE --editor --import
godot --headless --path ARTILLERY_FRONTLINE --script res://tests/run_tests.gd
```

The dependency-free runner writes `artillery-test-results.json` at the repository root and exits nonzero on failure. It includes real scene/physics integration for all five missions, not only arithmetic tests.

## Android deliverables

Verified CI test packages are retained in [`../delivery/`](../delivery/): primary ARM64 APK, ARM64 AAB and an OpenGL Compatibility APK. They are development-signed unless repository release secrets are configured. Package hashes and inspection reports are beside the binaries.

See `documentation/BUILD_ANDROID.md`. The repository workflow validates the project before exporting ARM64 APK/AAB and an explicit OpenGL Compatibility APK. Without repository signing secrets, packages use an **ephemeral development key** and are not store-release artifacts. No credentials are stored in the project.

## Scope and honesty

This is a production-oriented vertical slice, not a claim of completed commercial release certification. Smoke visuals and frame time from a software-rendered CI desktop are not Android device performance. See `documentation/QA_REPORT.md` and the milestone report for executed checks and remaining limitations.

Original asset provenance: `ASSET_LICENSES.md`. Architecture: `documentation/TECHNICAL.md`.
