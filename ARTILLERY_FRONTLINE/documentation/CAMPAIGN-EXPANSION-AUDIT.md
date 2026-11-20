# Campaign expansion: pre-change audit

Baseline reviewed: branch `arena/1f525ed9-ideal`, commit `3f834f242cf8694a246b836d166c3d5ce970b164`. This checkout was fast-forwarded from its stale base to the actual remote branch before inspecting the current game. The existing untracked `designs/` directory is left alone. The session branch is fixed by the environment; a separate branch cannot be created.

## Runtime and reusable systems

- Godot 4.7.2; project version 0.6.1, Mobile/Vulkan renderer on Android with an OpenGL compatibility export. Landscape viewport, stretch/expand and touch input are already configured.
- `scenes/main.tscn`, `scripts/core/game.gd` own the state machine and loading; `scenes/player/defender.tscn` and `scripts/player/` provide the stationary gunner, camera, aim and weapons. `scripts/weapons/` contains weapon and pooled projectile systems.
- `CityLevel`, `Defense`, `LevelLayout`, `Horde`, `AttackLines`, `Zombie` and `WaveDirector` wire defense, route following, attacks, pooling, targeting and waves. `city_wall.tres` sets wall 1000 / gate 700. Gate and wall breach behavior already exists.
- `Profile`, `SaveManager`, `Menus`, `Hud` and `Loc` handle save data, settings, upgrades, selection, HUD, Persian and English. Existing career progress is stored, but `Campaign.open_stages` currently grants access to every stage; selection is not progression-locked. Existing menu tests explicitly expect this behavior.
- Graphics tiers, dynamic resolution, enemy/corpse limits and pooled effects already exist. Current visuals use shared meshes, atlas textures, MultiMeshes and non-shadowed distant geometry.

## Actual content vs requested expansion

- All 30 wave-set resources exist and are selectable. Stages 7–30 each currently contain **three waves**, not eight. Their 72 waves have no boss spawn. Only the city boss in stage 3 exists; there are no eight location-specific bosses, Climber or Exploder. Existing zombie silhouettes share one human model in normal play.
- Metro has a separate scene, underground geometry and layout, but uses existing route conventions and lacks many requested environmental events and the Tunnel Brute. Hospital also has a dedicated scene.
- Factories through fortress use `city_siege.tscn`, shared city routes and defensive layout with district-specific procedural skyline landmarks and atmosphere. These are not seven fully distinct playable environments.
- Boss phases, special attacks, environmental hazards, per-location destruction, finale, difficulty unlock, and full staged progression are not present. None should be represented as complete merely because a stage resource or skyline exists.
- Existing saves only track a contiguous `stages_cleared` count, not per-stage completion. Earlier builds exposed every stage; any lock/migration policy must account for existing saves and be covered by tests before changing access.

## Baseline test evidence and limits

- Last recorded CI run `44738711760` (source `b3963c34afdfc26a989eec09868c7323afe55625`, same game source as this baseline) passed 4,795 headless checks, 218 software-rendered smoke checks, asset audit and ARM64 export. Existing evidence is in `documentation/qa/`. The APK was not run on a physical Android device.
- Fresh local Godot execution could not be started: no Godot editor binary is installed, and the official GitHub release redirects to a host unreachable from this sandbox. A workflow dispatch attempt returned HTTP 403 for this integration. Automatic CI on a later source push remains available.
- The local static audit was run before importing assets. It reported 40 missing `.import` sidecars; a fresh checkout needs the Godot editor import step first. The last recorded CI imported assets and its audit passed. Do not interpret this local result as a missing-source-asset diagnosis.
- Baseline smoke's Compatibility software-renderer measurement: 368 draw calls, 275,438 primitives, 6.4 FPS at its recorded scene/tier; this is **not** a POCO X5 Pro benchmark. No device profiling, battery/thermal test, or target-frame-rate guarantee has been performed.

## Delivery discipline

Keep defense, camera, controls, current saves and weapon behavior intact. Integrate changes incrementally with engine tests and screenshots; profile on target hardware before claiming the mobile performance target. An individual region is complete only after its own eight-wave gameplay, navigation, boss mechanics, environmental systems, localization and performance have been verified. This audit is not a claim that stages 7–30 meet that standard.
