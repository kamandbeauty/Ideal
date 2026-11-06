# Technical architecture

Engine: Godot 4.7.2 stable, standard GDScript build. Mobile/Vulkan is the primary Android renderer; a separate Compatibility/OpenGL preset forces `--rendering-method gl_compatibility`. The project also uses OpenGL for the web renderer configuration and software-rendered CI smoke tests.

## Composition and boundaries

- `scripts/core/game.gd`: application screen flow, pause and battle lifetime.
- `BattleController`: composition root for one mission; connects independent systems.
- `EventBus` autoload: cross-system signals, never UI references.
- `WeaponData`, `AmmunitionData`, `EnemyData`, `MissionData`, `UpgradeData`: exported custom Resources; `.tres` instances are the game data.
- `WeaponLoadout`: supply, compatible ammunition and upgrade modifiers.
- `ArtilleryController`: mechanical traverse/elevation, recoil spring, breech/reload timing and firing signals.
- `Ballistics`: exact constant-gravity integration with optional analytic linear drag. Both prediction and live shells call the same function.
- `ArtilleryProjectile`: fixed physics-step swept rays, lifetime and trail; no RigidBody allocation per shot.
- `ProjectilePool`: 12 preallocated shells; fire is refused when all are live.
- `TargetingSystem`: collision-aware nominal arc and impact marker. Fire control iterates the enemy patrol predictor for moving-target lead; actual shots still include weapon dispersion.
- `CombatCoordinator` / `DamageSystem`: one direct/radial damage pass per impact; armor and distance falloff.
- `HealthComponent`: bounded health and one-shot destruction signal.
- `EnemyTarget`: waypoint patrol, alert detection, health stages and wreck smoke.
- `MissionManager`: objectives, unique accurate-shell accounting, time/ammo failure and performance scoring; no UI or file access.
- `Progression`, `Economy`, `Profile`: first-clear points, best-star records, replay-safe star totals and upgrade purchases.
- `SaveManager`: versioned JSON schema validation, temporary-file write, backup copy and rename replacement; corrupt primary falls back to last good backup.
- `Graphics` / `SustainedFrameMonitor`: quality tiers and four-second frame-time windows with downgrade/upgrade hysteresis.
- `Sound`: fixed spatial/UI player pools and original PCM assets. Headless logic tests skip dummy-driver playback; shutdown stops and releases pooled streams.

## Ballistic model

Vacuum: `p(t)=p0+v0*t+0.5*g*t²`, `v(t)=v0+g*t`.
Optional linear drag uses the exact exponential solution, avoiding frame-rate-dependent Euler error. Live shells sweep each fixed-step displacement against physics layers 1–3. Prediction samples the same model and sweeps the same world. Collision time is quantized by the preview interval, so the marker is a close aiming aid rather than a guarantee against dispersion or a target changing course.

The fire-control computer is an intentional accessibility feature. It solves nominal elevation/traverse and predicts patrol waypoints; manual drag remains fully functional. Advanced drag is a settings toggle and is applied to both preview and fired shells.

## World and rendering

Sable Ridge is deterministic original geometry: 64 terrain chunks with generated mesh LOD and static trimesh collision, procedural multi-resolution ground noise, height-conforming road grids, hangars, barracks, towers, fencing, utility lines, radar, helipad, rocks, acacia-style vegetation and sandbags. Repeated props use MultiMesh. Materials/primitive meshes are shared. Blender-authored GLBs use a documented runtime +Y-to--Z import correction while preserving named turret/barrel/recoil/muzzle pivots. Frustum culling and visibility ranges limit work; no unsupported occlusion feature is claimed.

Lighting uses a realtime directional sun, procedural sky ambient/reflection and distance fog. This milestone does not contain baked LightmapGI data. Smoke is layered billboard GPU particles (volumetric-style), not raymarched volumetrics. Destruction uses authored intermediate/wreck states and bounded manual debris rather than unlimited rigid-body fracture.

## Bounds

- 12 projectile slots.
- 10 preallocated explosion effects; active cap 4/7/10 by tier.
- 24 reusable crater decals.
- 8 manual debris pieces per effect; no physics debris bodies.
- 12 spatial audio players and four UI players.
- Six enemy instances and a fixed set of destructibles in the single battlefield.

## Adaptive quality

LOW: 62% 3D scale, no shadows, 40% particles, four effect slots, 35% scatter, 128px procedural ground noise.
MEDIUM: 82%, 90 m shadows, 70% particles, seven effects, 65% scatter, 256px noise.
HIGH: 100%, 180 m shadows, full particles, ten effects, full scatter, 512px noise.

AUTO starts at medium on Android, high on desktop. It ignores isolated stalls, requires sustained overload before reducing quality, and requires sustained headroom plus cooldown before restoring it. Manual profiles are never overridden. Texture quality here means procedural texture resolution and mip bias; imported model textures are not dynamically streamed.

## Save format

`user://frontline_v1.json`, schema version 1. No Resource deserialization from player data. Settings and records are type checked/clamped. On Android the application uses its private app storage; no network permission is requested. Uninstalling generally removes local progress; cloud save is intentionally absent.
