# Development and milestone notes

## Scope

This repository starts with an original, single-battlefield vertical slice. Operation Dustline has one gun, HE and AP ammunition, three target types (radar, patrolling tank, patrolling transport), one objective, reload/zoom/shell camera, effects, results, and local preferences/records. It is **not** the requested five-mission MVP or final release. No claims of photorealism, final balance, or production/device readiness are made.

## Architecture

- `core/game.gd` composes systems and routes signals, input, results and save requests.
- `artillery/weapon_config.gd` and `ammo_config.gd` define editable `Resource` types; `.tres` files contain the actual values. `weapon_state.gd` owns compatible ammunition and reload rules independently of the model. Weapon damage, effective range and accuracy are configurable. Dispersion is sampled when a round is chambered, so the displayed prediction is also the shot actually fired.
- `ballistics/ballistics.gd` provides the same 60 Hz integrator for live shells and preview. The prediction performs a raycast every four integration steps; the maximum gravity-only chord error is under a centimetre. Each live shell sweeps its entire movement segment, preventing tunneling through thin collision bodies.
- `projectiles/projectile_pool.gd` caps simultaneously active shells at six; `effects/effect_pool.gd` reuses five explosion effects and twelve scorch marks. Particle layers are one-shot GPU emitters, not unbounded rigid bodies.
- `enemies/target.gd` uses lightweight scripted patrols, health, and staged damage/destruction. Terrain and static set dressing are not deformable; craters are pooled flat scorch meshes. Buildings are decorative and do not block shells. There is no enemy return fire in this slice.
- `missions/mission_state.gd` tracks unique target deaths, hits, time and a three-star rating. `save_system/save_store.gd` uses a versioned JSON file, a temporary write, and a last-good backup. Preferences and a Dustline best record are saved in `user://`; they are not cloud synchronized.
- `graphics/quality_policy.gd` applies LOW/MEDIUM/HIGH settings for resolution scale, shadows, particle allocation, decorative detail and LOD bias. AUTO uses multi-second frame-time windows and hysteresis, not single-frame spikes; target 30 or 60 FPS. There are no texture-quality levels because the slice uses procedural materials and no terrain textures. Profile behavior and real performance still require physical-device measurement.
- `ui/` builds a landscape, anchored tactical HUD and modal screens. Controls consume their own pointer input; an aim drag is started only by an unhandled touch/mouse event.

## Requirements

- Godot **4.7.2 stable**, its matching export templates, and a graphics driver supporting the Mobile renderer or its OpenGL Compatibility fallback.
- For Android: JDK 17, Godot's Android export templates, Android SDK platform 36, build-tools 36.1.0, platform-tools, and (for the Gradle AAB export) Android NDK 29.0.14206865. Configure the SDK and JDK paths in Godot Editor Settings or provide `ANDROID_HOME` and `JAVA_HOME` before the first editor run.
- No asset store, paid service, internet permission, account, ads, or in-app purchases are needed by the installed game.

### Run tests

```sh
# Replace `godot` with your Godot 4.7.2 executable.
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/run_tests.gd
# Optional static checks:
python -m pip install gdtoolkit==4.5.0
gdformat --check scripts tests
gdlint scripts tests
```

Tests include analytic ballistics, drag, blast falloff, reload and ammo rules, range falloff, unique objective completion, backup recovery, quality hysteresis, swept collision, predicted vs. actual impact, and a scene-level mission flow. The visual smoke test also exercises touch input and captures rendered screenshots under Xvfb. Headless validation exercises the simulation and scene initialization but does not validate GPU rendering, sound output, touch hardware, or actual Android performance.

### Android debug exports

Install matching 4.7.2 export templates and Android SDK/JDK first. A debug keystore must be available to Godot (the editor can generate one) or supplied with the `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`, `GODOT_ANDROID_KEYSTORE_DEBUG_USER`, and `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD` environment variables. Then:

```sh
mkdir -p build
godot --headless --editor --path . --import --quit
# Both presets use Godot's Gradle build template and a working Gradle/SDK installation:
godot --headless --path . --install-android-build-template --export-debug "Android" build/ARTILLERY_FRONTLINE-debug.apk
godot --headless --path . --export-debug "Android AAB" build/ARTILLERY_FRONTLINE-debug.aab
```

Both Android deliverables use the Gradle template rather than direct APK patching; the latter produced duplicate provider authorities with the 4.7.2 template in this environment. The debug APK is for testing, not a store release. The GitHub Actions workflow generates a disposable debug keystore and uploads debug artifacts; its hosted build may need network access for tool installation. To create a release, configure a private release keystore and the `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` environment variables from GitHub Secrets or a secure local environment. Never commit the keystore or credentials. Independently verify the signed artifacts and test installation on representative devices.

## Known limitations / next work

1. Physical Android installation, touch, sound, visual quality, thermal and FPS testing are required; no emulator/device is assumed available.
2. A single training operation is implemented; campaign map, four more missions, unlocks, currency and weapon upgrades are not yet implemented.
3. Art is original, low-poly procedural geometry rather than Blender-authored high-detail assets. Damage states are staged; no full building fracture, physics debris simulation or persistent terrain deformation.
4. There are no baked-lighting assets, occlusion data, texture quality variants, localization, accessibility settings, or release signing pipeline in this milestone.
5. Tune trajectories, difficulty, controls, memory, material sharing and mobile GPU effects based on real-device profiling before shipping.
