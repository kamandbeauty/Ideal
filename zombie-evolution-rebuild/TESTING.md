# Phase 2 report — current workspace

## Environment and blockers

- The user confirmed that the project should remain **portrait**, despite the landscape wording in the phase request. `project.godot` remains portrait.
- This workspace has no Godot executable, Android SDK, JDK, Gradle, `adb`, Android emulator, Xvfb, display, graphics development headers or `/dev/dri`. The `/tmp/godot-source` build described in the historical report below is no longer present. No renderer or Godot version could be run in this workspace.
- `curl -IL --max-time 10 https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip` returned HTTP 302, then failed connecting to `objects.githubusercontent.com:443`. This network environment does not permit that release-asset host. No official binary was obtained.
- Git inspection: `git cat-file -t 5fcbed0` returned `fatal: Not a valid object name 5fcbed0`; the current checkout history only contains the initial base commit, although the project files and previous test report are present in the workspace. The named commit cannot be verified from this checkout.

## Checks run in this phase

- `python3 zombie-evolution-rebuild/tests/export_config_test.py` — PASS: static preset checks for portrait, ARM64-only, disabled requested internet permission, signing enabled and no embedded keystore values. It does not validate a real APK or manifest.
- `for f in zombie-evolution-rebuild/scripts/*.gd zombie-evolution-rebuild/scripts/level/*.gd zombie-evolution-rebuild/tests/*.gd; do /tmp/zombie-tools/bin/gdparse "$f" >/dev/null || exit 1; done` — PASS: grammar parsing only.
- A Python `res://` existence scan over scripts, scenes and `project.godot` found no missing references. FontTools found all 39 Persian code points used in scripts and an Arabic GSUB table in the bundled font. These do not prove rendered text shaping or RTL layout.
- Static input review: `InputEventScreenDrag` moves the hero; camera tracking, aiming, firing, gate choice and recruitment are automatic. No manual camera or aiming controls exist. No real touch-device behavior or screen-space hit areas were checked.
- Static performance review: the environment creates individual bridge pieces and 58 cloud mesh instances; character parts have individual meshes/materials and each shot allocates a tracer mesh and material. No FPS, memory use, draw-call count or Android performance measurement was possible. No unmeasured gameplay/rendering optimizations were applied.

## Status by validation category

A. **Headless:** Previously passed results are preserved below. They were not rerun in this workspace; the engine executable was lost with the temporary environment.

B. **Rendered desktop gameplay:** NOT RUN. No real or staged screenshots were produced. Bridge, clouds, animations, camera, UI, Persian joining and alignment remain visually unverified.

C. **Android APK:** NOT BUILT. A preliminary ARM64 debug export preset was added, but Godot export templates, SDK, JDK and debug signing configuration are missing. APK size and SHA-256 are unavailable; manifest, actual permissions, assets and launch could not be inspected. The `org.example.zombieevolution` package ID is a development placeholder, not a production identity.

D. **Android device:** NOT RUN. No device or emulator was available.

## Next steps when tools are available

Install the official Godot 4.4.1 editor with a renderer and matching Android export templates, Android SDK/build tools and JDK; configure a local debug keystore in Godot's editor settings, not in this repository. From `zombie-evolution-rebuild/`, run `godot --headless --editor --path . --quit`, then `mkdir -p exports && godot --headless --path . --export-debug "Android ARM64" exports/zombie-evolution-debug.apk`. Check Godot's actual export diagnostics; inspect the resulting manifest, ABI and permissions with Android build tools and calculate `sha256sum exports/zombie-evolution-debug.apk`. Run on a portrait Android device and capture real gameplay screenshots with documented input. The preset and instructions have not been validated by an export.

---

# Testing report

## Environment and engine

The previously started Godot 4.4.1 source build completed successfully (SCons exit 0). It is an editor build with X11, Wayland, Vulkan and OpenGL disabled. Its executable is `/tmp/godot-source/bin/godot.linuxbsd.editor.x86_64` in this workspace; it is not included in the repository or a release artifact. Every engine invocation prints `ERROR: No renderers available. at: setup (main/main.cpp:2319)` because the build has no renderer. Headless scene, physics and script processing nevertheless ran as described below. This build cannot validate visual rendering or capture screenshots.

All commands below were run from the repository root. `G` was set to `/tmp/godot-source/bin/godot.linuxbsd.editor.x86_64`.

## Tests actually executed

1. `"$G" --headless --editor --path zombie-evolution-rebuild --quit` — exit 0; project scanned and font imported. Renderer error above printed.
2. `"$G" --headless --path zombie-evolution-rebuild --quit-after 5` — exit 0; actual configured launcher scene ran headlessly. Renderer error above printed.
3. `"$G" --headless --path zombie-evolution-rebuild res://scenes/level/sky_bridge.tscn --quit-after 240 --fixed-fps 60` — exit 0; actual level scene ran for 240 fixed frames. Renderer error above printed.
4. `"$G" --headless --path zombie-evolution-rebuild --script res://tests/launcher_and_controls_test.gd` — exit 0; launcher start button changed to level, forward movement, synthetic touch drag and boundary clamp worked, and lethal damage showed defeat. Renderer error above printed. This does not test real Android touch input.
5. `"$G" --headless --path zombie-evolution-rebuild --script res://tests/level_test.gd` — exit 0; 13 enemies spawned; physics ray dealt zombie damage; kill counters, shooting/right-gate selection and lock, +3 recruitment, soldier health/removal, soldier firing, zombie melee, ×2 calculation and 10-soldier cap, and victory screen state passed. These are targeted tests with scripted position changes and direct setup. Renderer error above printed.
6. `"$G" --headless --path zombie-evolution-rebuild --fixed-fps 60 --script res://tests/autoplay_test.gd` — exit 0; launcher-to-victory no-input autoplay at normal damage and health completed after 3,761 physics frames, with 13 kills, a maximum of 3 soldiers and no enemies remaining. It chose the right gate automatically; it is one deterministic path, not a manual or graphical playthrough. Renderer error above printed. An earlier run exposed a type-inference error in the test itself; the test was corrected before this passing run.
7. `XDG_DATA_HOME=/tmp/zombie-godot-testdata "$G" --headless --path zombie-evolution-rebuild --script res://tests/preferences_test.gd` — exit 0; settings save/load round-trip passed in an isolated directory. Renderer error above printed.
8. `"$G" --headless --path zombie-evolution-rebuild --script res://tests/persian_ui_test.gd` — exit 0; launcher RTL property, HUD RTL direction, Persian HUD digits, and sample font glyph availability passed. This is not a visual shaping/alignment test. Renderer error above printed.
9. `/tmp/gdvenv/bin/gdparse` for each GDScript — passed grammar parsing; a Python scan of `res://` references in scripts, scenes and `project.godot` found no missing paths. FontTools inspection found all 39 Persian code points used in scripts in the bundled font and an Arabic GSUB shaping table. These static checks do not prove correct rendering.

## Known limitations and untested items

- No actual or staged screenshots were generated: this Godot build has no renderer and the environment has no graphical display. Actual rendered gameplay, camera composition, connected Persian letters, mixed-direction labels, and UI layout remain unverified.
- The game chooses a gate by auto-firing toward the player's lane; it does not support independent manual aiming. Shooting locks the gate choice; the gate is removed when crossed, not destroyed by shooting. The gate test exercises selection and crossing, not destruction.
- Touch was simulated by injecting a `InputEventScreenDrag`; no physical Android touch test was possible. The no-input autoplay validates one route but not all choices or balance.
- There is no Android SDK/JDK, Godot Android export template or device/emulator in this environment. No ARM64 APK was built or tested. The project has no Android export preset yet.
- Temporary character meshes and running motion, absent audio and visual polish, missing complete Level 1 and boss phases, missing saved progression and no device performance profiling remain. Do not treat this as a release build.

---

# Source and build environment audit — current run

## Git and source

- Branch `arena/70907c19-ideal`, HEAD `e2f4de4ee3bdbadb07ed424218cb82445242ac52`; shallow checkout. `5fcbed0` and `30c9e9b20afbc8eb80a68e102962a62c440b50e1` are not available as local commit objects and the GitHub commits API returned HTTP 422 for each. `git fsck --full --no-reflogs` exited 0 with 45 dangling blobs and no reported dangling commit or tree. Current rebuild files are untracked and cannot be compared to the missing commit. See `SOURCE_RECOVERY_REPORT.md` for evidence, limitations and current-file hashes.
- `sha256sum -c zombie-evolution-rebuild/SOURCE_MANIFEST.sha256` — PASS for 21 files. This newly generated manifest records current bytes; it is not an independent original or evidence of recovered identity.

## Environment and versions

- Debian 12 x86_64; Python 3.11.2; `gdparse` from gdtoolkit 4.5.0. No `godot`/`godot4` binary found on PATH, and the previously reported `/tmp/godot-source/bin/godot.linuxbsd.editor.x86_64` is absent. The prior build and tests below are historical, not results from this run.
- `java`, `javac`, `adb`, `sdkmanager`, `gradle`, `aapt`, `apkanalyzer`, `Xvfb`, `vulkaninfo`, `glxinfo`, and `pkg-config` are absent on PATH. No Android SDK at the checked standard paths, JDK at `/usr/lib/jvm`, Godot export templates at `~/.local/share/godot/export_templates`, `/dev/dri`, or X11/EGL/Vulkan development headers were found. No DISPLAY or WAYLAND_DISPLAY was set. This does not exhaustively prove no alternate installation exists; no usable installation was identified.
- For the previously used Godot 4.4.1 target, use the official Godot 4.4.1 editor and matching Android export templates, OpenJDK 17, Android SDK platform 34, build-tools 34.0.0, platform-tools 34.0.0 or later and command-line tools. The Godot 4.4 docs also list CMake 3.10.2.4988404 and NDK 23.2.8568313; the Godot 4.4.1 source Gradle wrapper specifies Gradle 8.2 when Gradle builds are used. Install/configure a debug keystore locally. These versions are taken from the official Godot 4.4 docs and 4.4.1 source, not from an installed toolchain.

## Tests executed in this run

- `git fsck --full --no-reflogs` — exit 0, 45 dangling blobs and no other messages.
- `git ls-remote --heads origin` — exit 0; remote main matches the current base; current session branch is not a remote head. GitHub commits API checks for the two reported commits returned HTTP 422, not found.
- `python3 zombie-evolution-rebuild/tests/export_config_test.py` — PASS, static config assertions only.
- `for f in zombie-evolution-rebuild/scripts/*.gd zombie-evolution-rebuild/scripts/level/*.gd zombie-evolution-rebuild/tests/*.gd; do /tmp/zombie-tools/bin/gdparse "$f" >/dev/null || exit 1; done` — PASS, grammar only, not engine API/type validation.
- Python `res://` reference scan over scripts, scenes and `project.godot` — 22 paths checked, none missing. `sha256sum -c zombie-evolution-rebuild/SOURCE_MANIFEST.sha256` — 21 files OK.

## Not executed in this run

No Godot GDScript engine validation, headless tests, main-scene loading, gameplay integration or autoplay, rendered desktop run, screenshot, Android export, APK/manifest inspection or emulator/device test was possible. The results reported in earlier sections were not rerun or independently verified in this audit. No new gameplay features or changes to movement, camera, orientation or mechanics were made.

## Android preset audit and blockers

- `project.godot` sets `window/handheld/orientation=1` (portrait) and `gl_compatibility`; the portrait decision remains unchanged.
- `export_presets.cfg` requests Android ARM64 only, `all_resources`, signed output, package `org.example.zombieevolution`, and `permissions/internet=false`. The application ID is a development placeholder. No APK or manifest exists to verify actual ABI, package, permissions, exported files or orientation; debug tooling can add permissions. Signing depends on local configuration.
- No minimum SDK is explicitly set in the preset and `gradle_build/use_gradle_build=false`. Godot 4.4.1 source `platform/android/java/app/config.gradle` declares min SDK 21 and target SDK 34, while the Gradle export code uses a 24 default in its Gradle path. Without the actual matching export template and APK manifest the effective minimum for this preset remains **unverified**; do not assume a value or change it without a successful export and inspection.
- The required official Godot binary and matching templates, renderer/display, Android tools, debug signing setup and device are unavailable. The earlier report documents a blocked release-asset download; no repeated attempt was made in this run. No APK size or SHA-256 is available.

---

# Reproducible CI preparation — current run

- **Source:** branch `arena/70907c19-ideal`; HEAD `e2f4de4ee3bdbadb07ed424218cb82445242ac52`. `sha256sum -c zombie-evolution-rebuild/SOURCE_MANIFEST.sha256` — 21/21 OK. The preserved manifest's SHA-256 is `91eb09119c7c8b26b5387d9dacf2720aa481de028ef263be4eff2e97db971280`. This checks a local baseline, not the missing commit. New CI files and this report are not in the original manifest.
- **Static:** `python3 zombie-evolution-rebuild/tests/export_config_test.py` — PASS, static preset only. `bash -n zombie-evolution-rebuild/ci/install_godot.sh zombie-evolution-rebuild/ci/run_headless.sh` — PASS. `/tmp/zombie-tools/bin/gdparse zombie-evolution-rebuild/ci/capture_gameplay.gd` — grammar PASS with gdtoolkit 4.5.0. PyYAML parsing and basic job structure check passed for `.github/workflows/zombie-evolution-validation.yml`; neither YAML parsing nor gdparse validates execution or Godot APIs.
- **Harness behavior:** `LOG_DIR=/tmp/zombie-ci-dependency-test GODOT=/nonexistent/godot bash zombie-evolution-rebuild/ci/run_headless.sh` exited 1 and recorded `FAIL dependency`. A separate fake executable emitted a synthetic `SCRIPT ERROR` with exit 0; the harness reported `Checks passed=10 failed=1 warnings=0` and exited 1. Those 10 apparent passes used a test fixture, not Godot, and are **not gameplay test results**.
- **New headless or rendered game tests:** NOT RUN. `godot --version` exited 127 (`command not found`). `xvfb-run -a glxinfo -B` exited 127 (`xvfb-run: command not found`). No actual or staged screenshots were created; there is no visual inspection of Persian shaping or layout.
- **Android:** NOT RUN; `sdkmanager --version` exited 127, and JDK, Godot, matching templates, SDK, build-tools and device/emulator were not found. No APK, manifest, size, checksum or device launch exists. Portrait is unchanged. Effective minimum/target SDK and permissions remain unverified without an exported manifest.
- **Workflow:** `.github/workflows/zombie-evolution-validation.yml` and `ci/` scripts were authored but have not run on GitHub Actions. The three jobs attempt official Godot 4.4.1 with official SHA-512 checksums, headless checks, actual rendered autoplay via Xvfb/Mesa, and ARM64 export/inspection. Logs are configured as artifacts. The screenshot driver uses actual gameplay only and fails if any requested state, including a natural defeat, does not occur. Captures, if produced, still require human visual review. A source commit/push is required before a clean GitHub Actions checkout can run it.
