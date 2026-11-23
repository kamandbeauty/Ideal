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

## First implementation increment (not campaign completion)

- Commits: `d554fab` (baseline audit), `5f875ed` (metro detail batches and tests), `94211a8` (softened wet-floor patches). All are on `arena/1f525ed9-ideal`.
- Modified scene script: `scripts/environment/metro_geometry.gd`. The existing scene is reused; no new scene, script, external texture or model was introduced. Added non-colliding, batched escalator treads/rails, control-booth details, ceiling utilities, wet-floor patches, and inexpensive flickering emissive indicators. The sampled gameplay view is [`qa/47-metro-attack.png`](qa/47-metro-attack.png). Not all details are prominent from the gunner's view; further art and readability work is required.
- Added batch-presence and collision checks for the three metro stages to `tests/integration/test_campaign.gd` and a smoke assertion to `tools/game_smoke.gd`. This does not validate all requested new mechanics.
- CI `44815632732`, source `94211a8037c937646b530aae0ca4d98ef237852a`: asset import/audit passed, 4,825 headless checks passed, 219 software-rendered smoke checks passed, Android ARM64 export and signature/manifest checks passed. The Android build is signed with an ephemeral development key, not tested on a device.
- Its software Compatibility renderer reported 377 draw calls, 273,166 primitives, 6.1 FPS in the recorded test scene. This desktop software-renderer measurement cannot establish mobile performance; target POCO X5 Pro remains untested.
- Remaining: **all 24 requested stages remain incomplete**. No stage was changed to eight waves; none of the eight new bosses, the two new enemies, district-specific playable layouts after metro, hazards, story ending, higher-difficulty unlock or new save migration/unlock behavior has been implemented. Metro itself lacks several requested assets and events. These require further design, implementation, balancing and end-to-end/device validation; they are not represented by substitute bosses or placeholder mechanics.

## Metro wave increment

Stages 7–9 now have eight shorter, director-driven waves apiece, with pooled existing walkers, runners and brutes and two pairs of existing metro routes. The per-stage crowd is distributed across the waves rather than multiplying the original army eightfold. Intermissions and capped resupply give the player breathing room. The opening six stages and their requested gun-hit counts are unchanged. Enemy speed retains the old district difficulty baseline and is interpolated across the longer metro stages; adding wave numbers does not accelerate later districts. Legacy profile wave records are migrated to schema 2 by stage and approximate within-metro progress, preserving currency, upgrades, settings and stage completion. No stage-lock policy was changed.

**Still incomplete:** the metro Tunnel Brute boss, boss-specific mechanics and environmental events are not implemented. In particular stage 9 wave 8 is an ordinary wave, not a substitute boss. Stages 10–30 remain three-wave shared-layout content without their requested bosses and specials. The metro increment is not an assertion that the region or campaign is complete. Validation reports in `documentation/qa/` and the build status describe the latest CI run; Android playability, fun and performance require real-device playtesting.

## Metro boss increment

Stage 9 wave 8 now schedules the Tunnel Brute, a distinct data/behavior variant of the pooled boss using the existing shared rigs, with a non-colliding chest plate. It warns before a short route-following rush with an orange ring and localized HUD text; blasts interrupt the rush. The existing boss HUD, hit volumes, gate/slot rules and pooling remain in use. Its final-wave escorts were reduced to keep the encounter manageable. It is not a new custom sculpt or fully animated bespoke boss: appearance readability and tuning still need real player/device testing. Stages 7 and 8 have no boss.

Metro still lacks some requested environmental events and art; stages 10–30 remain incomplete, including their seven unique bosses, Climber, Exploder, eight-wave design and dedicated environments. Existing open-stage/save policy remains unchanged.
