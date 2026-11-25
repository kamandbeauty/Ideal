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

Keep defense, camera, controls, current saves and weapon behavior intact. Integrate changes incrementally with engine tests and screenshots; profile on target hardware before claiming the mobile performance target. An individual region is complete only after its three-wave gameplay, navigation, boss mechanics, environmental systems, localization and performance have been verified. This audit is not a claim that stages 7–30 meet that standard.

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

## Correction: every stage has three waves

The earlier eight-wave requirement and the "Metro wave increment" above are superseded by the user's correction: **all 30 stages use three waves**. Stage 3 previously had only two; its first wave was split into two with the same enemy totals, leaving the original city boss in its third wave. Stages 7–9 are back to three waves; the Tunnel Brute appears only in stage 9 wave 3, with fewer escorts in that final wave. Health and weapon-hit balance are unchanged. Wave numbering is now 1–90, while enemy speed retains the existing progression rather than jumping because of the numbering change.

Profile schema 3 migrates both older schemas: v1's city/metro records and v2's temporary eight-wave metro records are mapped to the same stage and approximate position in three-wave structure; currency, upgrades, settings and stage completion remain unchanged. Seven other regional bosses, events, district-specific levels and other campaign requirements remain incomplete. This is not a claim of device-tested balance or campaign completion.

## Hospital boss increment

The Quarantine Brute now appears only in stage 6 wave 3. It follows the existing pool and defense-slot rules, and telegraphs every third strike before doing limited extra gate/wall damage; a blast interrupts the bonus. Localized HUD, a red warning ring and a simple non-colliding medical plate use the existing boss rig. It is not a bespoke character model, and visual readability and enjoyment require real-device/player testing. The wave's escorts were reduced; its 1,900 health preserves exactly 50 direct base twin-gun body hits in the hospital. Stages remain three waves and neither saves nor weapon upgrades were changed. Metro still needs environmental work; stages 10–30 still need their dedicated settings and seven bosses, plus the requested special enemies and progression features.

## Metro scenery and harmless events increment

Metro now includes batched damaged ventilation and electrical cabinets, plus occasional vent smoke and circuit sparks while a match is active. They use existing pooled effects, are skipped on low detail, have no collision or damage, and do not change enemy routes, walls, weapons, waves or the player's station. Their timing and lifecycle are tested separately from combat; a staged software-rendered screenshot documents the vent. These are ambient visual events, not interactive environmental hazards, a finished soundscape, or a fully detailed station. Metro still needs further art and device/player validation; the other seven districts and requested enemies/progression remain incomplete.

## Industrial yard increment

Stages 10–12 now load a factory yard scene rather than the city mesh: a concrete gun platform and industrial gate, distant factory skyline, warehouses, overhead gantry and grouped yard fittings. Most new architecture uses three non-colliding MultiMeshes; permanent floor, platform and defense arms use existing collision conventions. The yard has its own fire/smoke placement but deliberately retains the city mount, attack paths, defense slots, breach paths, wave sets, enemy stats, saves and weapons. It is an initial environment increment, not a full industrial district: its stage-12 regional boss, special events, additional art and design/play/device validation remain outstanding. The later six districts still use the shared city scene. Software-render screenshots and automated logic tests are not phone performance or player-experience validation.


## Industrial boss increment

The Foundry Brute is scheduled only in stage 12 wave 3, with fewer escorts to make room for it. It uses the existing boss body/rig and a non-colliding industrial chest plate, not a new sculpt. While advancing, an amber warning precedes four seconds of blue-indicated brace: body shots do 75% damage, while headshots and blasts retain their normal damage; a blast interrupts it. This is not invulnerability and it stops at the wall or on breach. It shares existing path, slot, health scaling (industrial 1.06), pool, HUD and weapon systems. Tests cover wave placement, actual director progression, body/head/blast damage, warning, timeout, interruption and reuse; a staged image documents appearance. Further visual clarity, combat balance, device performance and real-player testing remain necessary, along with industrial art and events and the six remaining regional bosses and districts.


## Industrial vehicle and art pass

Stages 10–12 now feature a modular forklift and a scorched flatbed truck, with wheels, cabs, lift rails, forks and safety-colored fittings. The existing pair of quality-limited flame/smoke systems is repositioned onto the vehicles, so no additional emitters are introduced. Their first placements were hidden by the defense walls in the software render; they were moved inward while preserving route clearance, and line-of-sight checks were added. The fire particles also proved too faint at that distance, so two small animated, unlit flame accents were attached to the existing capped fire roots; these are stylized meshes rather than realistic simulation. Factory roof trusses, pipes, a distant loading hall, pavement wear and drains add depth without new blocking collision. The vehicles are original, procedural low-poly assemblies built from shared materials and fixed MultiMeshes, not high-detail licensed vehicle models; the effect is visual only. Existing routes, player position, waves, defenses, saving and combat remain unchanged. Rendered desktop screenshots document actual gunner views, but readability, visual quality and performance still require Android and player testing.


## Industrial yard visual polish

Stages 10–12 use two district-only 512 × 512 AI-generated, edge-blended JPEG surfaces for worn pavement and corrugated metal; mipmapped textures replace flat/shared surfaces. The overhead gantry has a batched truss, loading hall has framing and a caution band, and the forklift lift and burnt truck cab have extra batched detail. The existing truck flame was brought toward the front of the cab, still within the original two-fire quality budget. No routes, combat or collision were added or changed; the new architecture is visual-only. This remains a procedural low-poly environment rather than bespoke vehicle models. Software-rendered screenshots and automated tests are evidence of the build, not validation on a physical phone.


## Bazaar district, stages 13–15

These stages now load a dedicated procedural market scene rather than the shared city mesh. Its rear arcaded facade, side colonnades, domed skyline, colored tile bands and fabric stalls are decorative and batched; the 512px masonry surface is AI-generated and edge-blended. The scene reuses the exact city routes, wall, gate, attack lines, zombie roster, three existing wave sets and health scaling. At that initial scene increment there was no boss, special encounter, hazard or bespoke character model; the boss was added in the following increment. Ground and defenses are collidable; market details are not. Automated tests cover route rays and complete director-driven waves; software screenshots are not a substitute for playtesting or device performance measurements.


## Bazaar boss increment

Stage 15 wave 3 now spawns one Bazaar Brute and has fewer escorts than before. It uses the existing boss rig and hitboxes, with a teal-and-red decorative sash, not a bespoke character model. On reaching a defense it has a 3-second delay, then an orange 1.8-second warning and 4 seconds of 1.5× attack speed; each strike has ordinary damage. A blast cancels the warning or frenzy, then a 12-second recovery follows. It has 1900 base health with the district's 1.09 scaling. No new route, hazard or attack is added to other stages. Headless/director tests and staged screenshots do not substitute for human balance or Android performance testing.


## Bazaar visual detail pass

The market now uses district-only AI-generated 512px paving, mosaic and woven rug textures, with edge blending on tiled surfaces and mipmapping. Decorative teal domes with finials, colored tile friezes, rear arch recesses, shutters, high bunting, striped stall valances, rugs, pottery, produce and emissive lantern meshes enrich the view. Wares and repeated details use MultiMesh batches and no physics; lanterns do not add dynamic lights. Stall bounds are tested against the established route envelopes, and route collision rays, director tests and gunner-view screenshots remain in CI. These are lightweight procedural props, not bespoke scanned assets; mobile performance and human readability still need device testing.


## Terminal district, stages 16–18

These stages now select a dedicated procedural bus-terminal scene, with a glazed arrival hall and signage, side platform canopies, departure boards, faded lane paint and two abandoned buses. AI-generated 512px edge-blended asphalt and metal cladding are mipmapped and local to the district. Repeated architecture and each six-batch bus are visual-only; lantern meshes do not add dynamic lights. The city routes, defense positions, zombie roster, health scaling, three existing waves per stage and all combat rules are unchanged. No terminal boss, special event, vehicle physics or new hazard was added in this increment. CI exercises all three real directors, route clearance, conservative bus separation and a gate breach; software renders and automated simulations are not a substitute for human or physical Android testing.


## Terminal visual detail pass

District-only AI-generated weathered glass, paint and retro destination-poster textures (512px and mipmapped) add visual variation to the hall and vehicles; the tiled surfaces are edge-blended. The terminal now has bilingual signage, enlarged poster billboards, waiting shelters, seats and facade framing. Bus wipers, trim, handles and small luggage use the same six material batches per bus; flat surface wear adds no obstacle and no dynamic lights were added. All new architectural details are visual-only. CI checks shelter and bus clearance, route rays and the three actual wave directors; ordinary gunner-view and staged sight-zoom screenshots are captured. This remains procedural low-poly scenery, and the build has not been profiled or playtested on a physical phone.


## Terminal signaler boss

Stage 18 wave 3 now schedules one Terminal Signaler alongside reduced escorts on the existing avenue route. It reuses the existing boss rig and hitboxes with a decorative transit vest and high-visibility patches; it is not a bespoke sculpt. While advancing, it starts with an eight-second delay, gives a 1.8-second orange overhead warning and HUD announcement, then shows a 12-meter blue ground ring for five seconds. Walkers and runners advancing within the ring move at 1.3× speed; their base speed and attack damage are unchanged. A blast interrupts either the warning or the signal, followed by a 16-second recovery; the signal also stops when the boss stops advancing or dies. It has 1,900 base health with terminal district scaling (1.12). No other campaign wave gains this boss, and no routes or collision were changed. Tests exercise movement, range and type restrictions, interruption, death, pool reuse, localized HUD and the actual stage-18 director; staged software-rendered images illustrate the warning and ring. Balance and readability need human playtesting, and Android runtime and performance have not been tested on a device.


## Residential district, stages 19–21

These stages now use a separate procedural residential scene with rear apartment blocks, side facades, rows of windows and balconies, two stylized trees and parked cars. Repeated elements use non-colliding MultiMeshes; the scene reuses the existing asphalt and facade textures. The city layout, defender, wall and gate positions, original three wave sets, enemy roster and combat systems remain unchanged. Tests cover navigation rays, conservative clearance around the trees and cars, intact defenses, gate breach and all three real directors; software-rendered gunner views capture the scene and attackers. This is an initial low-poly environment pass, not a bespoke detailed neighborhood. No residential boss, special event or hazard has been added yet; balance, visibility and performance still need human playtesting and physical Android device validation.
