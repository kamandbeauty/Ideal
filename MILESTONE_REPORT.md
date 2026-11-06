# ARTILLERY FRONTLINE — milestone report

Date: 2026-11-06  
Branch: `arena/40ad7d87-ideal`  
Repository: `kamandbeauty/Ideal`  
Verified build source commit: **`e4407def4dda0dbfa802f97ba22976557b71f982`**  
Final CI run: **42204972594** — validate and Android jobs successful  
Package publication commit: **`f6f3568`**  
Engine: Godot **4.7.2 stable**, standard GDScript build  
Original model authoring: Blender **5.0.1** via free GitHub Actions toolchain

## Outcome

A playable, original, offline single-player 3D Android artillery vertical slice / MVP candidate is implemented and exported. The repository contains source, original assets, data resources, tests, documentation, licenses, CI workflows and verified development-signed Android packages.

This milestone is **not** a commercial release certification. No Android device/emulator was available; all gameplay validation is desktop/headless/CI, and all performance numbers are software-rendered CI observations.

## Implemented features

| Area | Implemented behavior | Principal files |
|---|---|---|
| Application flow | Splash, main menu, campaign map, briefing, HUD, pause, results, arsenal/gun selection, upgrades, settings | `scripts/core/game.gd`, `scripts/ui/menu_screens.gd`, `scripts/ui/hud.gd`, `scenes/core/main.tscn` |
| Artillery | Kestrel M-42 155 mm howitzer; independent yaw/elevation; recoil spring; breech/reload timing; muzzle flash; fire signals | `scripts/artillery/artillery_controller.gd`, `resources/weapons/kestrel.tres`, `assets/models/kestrel.glb` |
| Ammunition | M72 HE blast/falloff and M91 AP armor penetration; supply counts; compatible selection | `resources/ammunition/he.tres`, `ap.tres`, `scripts/artillery/weapon_loadout.gd` |
| Ballistics | Shared analytic vacuum + exact linear-drag model; live swept collision; collision-aware trajectory preview; optional advanced drag | `scripts/ballistics/ballistics.gd`, `scripts/projectiles/`, `scripts/targeting/targeting_system.gd` |
| Fire control | Nominal gun solution plus waypoint-aware moving-target lead and iterative flight-time solve; manual aiming remains available | `scripts/core/battle_controller.gd`, `scripts/enemy_ai/enemy_target.gd` |
| Combat/destruction | One direct/radial damage pass; armor; health stages; pooled layered explosions, smoke, dust, debris, shockwave, light and craters | `scripts/combat/`, `scripts/destruction/`, `scripts/effects/` |
| Enemy AI | Stationary emplacements, patrolling Warden tanks and Nomad transports; alert response; wreck smoke/staged visuals | `scripts/enemy_ai/enemy_target.gd`, `resources/enemies/` |
| Missions | Five sequential operations, primary/optional objectives, time/ammo failure, accuracy/par-time scoring | `scripts/missions/mission_manager.gd`, `resources/missions/sr01–sr05.tres` |
| Progression/economy | Credits, best-star records, first-clear upgrade points, replay-safe rewards, five permanent upgrade tracks | `scripts/progression/`, `scripts/economy/`, `resources/upgrades/` |
| Save | Versioned JSON schema validation, atomic temp/rename write, backup recovery, clamped settings | `scripts/save/save_manager.gd`, `scripts/progression/profile.gd` |
| Graphics/performance | LOW/MEDIUM/HIGH/AUTO, sustained frame-time hysteresis, 30/60 targets, Mobile renderer + explicit Compatibility APK | `scripts/graphics/graphics_manager.gd`, `scripts/performance/frame_monitor.gd`, `export_presets.cfg` |
| Input/cameras | Landscape touch aiming surface isolated from buttons; keyboard/mouse desktop controls; gun/optic/shell/impact cameras, zoom and shake | `scripts/ui/aim_input.gd`, `scripts/artillery/camera_rig.gd` |
| Audio | Original synthesized PCM; fixed spatial/UI pools; volume buses; shutdown cleanup | `scripts/audio/audio_manager.gd`, `assets/audio/`, `tools/create_audio.py` |
| Battlefield | Sable Ridge: chunked LOD terrain, trimesh collision, conforming roads, base kit, hangars, towers, fence, radar, helipad, scatter, sandbags | `scripts/environments/desert_battlefield.gd`, `scripts/environments/terrain_sampler.gd`, `scenes/battlefield/` |
| Assets/licenses | Five original Blender-authored GLB/BLEND model sets, procedural geometry/shaders/icon/audio, Rajdhani OFL font, Godot MIT notice | `tools/create_models.py`, `assets/`, `ASSET_LICENSES.md`, `documentation/licenses/` |

Inventory at milestone: 39 gameplay GDScript files, 16 custom `.tres` data resources, 10 executable test suites plus shared test context, 5 original GLB models, 6 original WAV clips.

## Executed tests and results

Authoritative machine reports:

- `artillery-test-results.json`: **197 checks, 0 failures**.
- `ARTILLERY_FRONTLINE/documentation/qa/smoke-report.json`: **17 checks, 0 failures**.
- `delivery/package-validation.json`: package inspection pass.
- `delivery/SHA256SUMS.txt`: locally rechecked, all OK.

Coverage includes ballistics, swept collision, damage/armor, reload timing, mission completion/failure, save/load/recovery, progression/replay safety, graphics selection/hysteresis, resource integrity, combat integration, real first-mission scene completion, and real scene completion of missions `sr02`–`sr05`.

The CI smoke path exercised touch drag, UI fire button, fire-control solution, projectile flight, target destruction, results, and persistent upgrade purchase. Mission `sr01` finished with 2 shots / 2 hits / 100% accuracy / 3 stars / 535 credits / 2 points.

Visual evidence is retained in `ARTILLERY_FRONTLINE/documentation/qa/`: battlefield, two impact captures, mission results and upgrades.

## Android build status

Final CI run **42204972594** succeeded through import, tests, Xvfb smoke, APK/AAB export, explicit AAB signing, signature verification and package inspection.

| Deliverable | Bytes | SHA-256 | Status |
|---|---:|---|---|
| `delivery/Artillery-Frontline-arm64.apk` | 32135359 | `a3a104f4e79d8f34ba7c1c0e57a24f2190e82b252d606929012e359928c27cf5` | ARM64, v2/v3 signature verified, landscape, no INTERNET |
| `delivery/Artillery-Frontline-compatibility.apk` | 32135359 | `baa4545f7b7b6bcf8d797af33805338c0d9e314599a98f63144646c6c4cc4d3d` | ARM64 OpenGL fallback, v2/v3 signature verified, separate package ID |
| `delivery/Artillery-Frontline-arm64.aab` | 31974632 | `a69dcb485da104cb3cbd0dc90fd44693c865cc1a8ad5329a5183b9aa1f7cd36e` | Gradle ARM64 bundle, explicit JAR signature verified, META-INF signature block present |

APK inspection: min SDK 24, target SDK 36, landscape activity orientation, package IDs `com.frontline.artillery` and `com.frontline.artillery.compatibility`, no INTERNET permission. AAB preset uses minimum SDK override 26.

Signing: **ephemeral development key**, not a store release. The workflow supports persistent release signing through GitHub Secrets `ARTILLERY_KEYSTORE_BASE64`, `ARTILLERY_KEYSTORE_PASSWORD`, `ARTILLERY_KEY_ALIAS`; no keystore or password is committed. The development certificate is self-signed and short-lived, which produces expected jarsigner warnings but a verified signature.

## Performance observation

Final CI snapshot: Compatibility renderer under Xvfb/llvmpipe, manual medium tier, 0.82 3D scale, **12.6 FPS**, **79.48 ms** smoothed frame interval, **372 draw calls**, **1189 objects**, **126158 primitives**. Earlier software-rendered runs varied roughly 12–20 FPS.

These are CPU-rasterized desktop CI measurements. They do not establish Android GPU performance, thermal behavior, or sustained 30/60 FPS. The game includes quality tiers and sustained adaptation, but device profiling remains required.

## Issues and limitations

Resolved during the milestone: Godot 4.7 API mismatches; moving-target lead; terrain/road facing and collision; road z-fighting; HUD layout; Android ETC2/ASTC configuration; Gradle template version metadata; release-signing env typo; unsigned Gradle AAB; brittle orientation parsing; headless dummy-audio playback cleanup.

Remaining:

1. No physical Android/emulator installation, touch comfort, safe-area, suspend/resume, audio-focus, force-stop save, Vulkan/OpenGL startup or thermal validation.
2. Development signing only until release Secrets are configured and CI is rerun.
3. One battlefield and one weapon; gun selection UI is present but the slice ships one configurable gun.
4. Enemy AI is patrol/alert/destruction, not full return-fire combined-arms combat.
5. Realistic visual ambition is bounded by original low/poly procedural assets, realtime sun/fog, billboard particles and no baked GI.
6. Earlier CI emitted non-fatal themed-icon `aapt2` warnings; Android launcher appearance remains untested.
7. Software CI frame rate is below mobile targets and must not be interpreted as device performance.

## Key commit chain

- `b46c5bf` / `fafe14f` / `6913113`: free toolchain bootstrap and verified Godot transport.
- `7721a77`: foundation systems, data resources and early tests.
- `fd80df1`: full validation/Android workflows and tooling.
- `0ee86cd`: original Blender models fetched from successful asset CI.
- `c40ad09`: complete playable game source, UI, missions, docs and licenses.
- `6d467ae` / `c43fea6`: terrain/prediction/model-orientation corrections.
- `8dffd09`: Android ETC2/ASTC and signing-env fixes.
- `bbf486b` / `9dd4942`: Gradle template identifier and broader CI triggers.
- `aeef77b`: full-campaign integration, road conformance, audio cleanup.
- `e4407de`: final signed-package verification source.
- `f6f3568`: final verified Android package publication.

## Next tasks

1. Run a device QA matrix on at least one Mali and one Adreno ARM64 phone/tablet: install both APK variants, test touch/safe areas, suspend/resume, audio focus, force-stop saves, permissions and launcher icons.
2. Profile sustained frame time and thermals on real hardware; tune draw calls, scatter density, shadow distance and particle budgets from measured GPU/CPU bottlenecks.
3. Configure a persistent release/upload keystore in GitHub Secrets, rerun CI, and validate store-release signing and Play upload requirements.
4. Add baked lighting/detail textures and higher-fidelity material work where device budgets allow.
5. Expand content only after device stability: additional weapons/battlefields, enemy return fire, richer destruction and accessibility/localization options.
