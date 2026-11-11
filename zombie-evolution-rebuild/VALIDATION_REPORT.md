# Validation report — reproducible CI preparation

## 1. Source integrity — PARTIAL, historical identity unverified

- Command: `git branch --show-current; git rev-parse HEAD; git remote -v; git status --short` — branch `arena/70907c19-ideal`, HEAD `e2f4de4ee3bdbadb07ed424218cb82445242ac52`. The rebuild files are untracked; the reported historical commit `5fcbed0` is not present. See `SOURCE_RECOVERY_REPORT.md`.
- Command: `sha256sum -c zombie-evolution-rebuild/SOURCE_MANIFEST.sha256` — exit 0, 21/21 files match the preserved manifest. Manifest SHA-256: `91eb09119c7c8b26b5387d9dacf2720aa481de028ef263be4eff2e97db971280`. This is a local baseline, not proof of origin or identity with the missing commit. The new CI scripts and reports are outside its scope.

## 2. Static validation — PASS for checks listed, not engine validation

- `python3 zombie-evolution-rebuild/tests/export_config_test.py` — Python 3.11.2, exit 0. Verifies preset intent only.
- `bash -n zombie-evolution-rebuild/ci/install_godot.sh zombie-evolution-rebuild/ci/run_headless.sh` — exit 0.
- `/tmp/zombie-tools/bin/gdparse zombie-evolution-rebuild/ci/capture_gameplay.gd` — gdtoolkit 4.5.0, exit 0; syntax only.
- PyYAML parsed `.github/workflows/zombie-evolution-validation.yml` and verified the three jobs and runner labels. Workflow execution and GitHub Actions semantics have not been validated.
- The headless harness was tested for explicit missing-tool failure and synthetic logged-error detection using a fake executable; this was not a gameplay or Godot test. Exact details are in `TESTING.md`.

## 3. Fresh headless gameplay tests — NOT TESTED

`godot --version` returned exit 127, command not found. The new workflow is configured to import assets, launch the launcher and level, and run all five existing Godot tests with per-check logs, error detection, timeouts, warning counts and summary. It has not run here or on GitHub. Previously reported tests in `TESTING.md` are historical and are not counted as fresh results.

## 4. Rendered desktop execution — NOT TESTED

`xvfb-run -a glxinfo -B` returned exit 127: `xvfb-run` not found; Godot and a display are also absent. No real or mock screenshots exist from this run. The unexecuted rendered CI job attempts software OpenGL via Xvfb and saves real frames from unmodified gameplay in artifact `godot-rendered-evidence`. It fails if any of the seven requested natural states, especially defeat, cannot be reached; it does not stage states or claim visual approval. Persian shaping, alignment, clipping, camera and touch-target appearance still require human inspection.

## 5. Android APK export — NOT TESTED

`sdkmanager --version` returned exit 127; JDK, Android SDK, Godot and matching templates are absent. No APK, effective min/target SDK, actual manifest, ABI, permissions, package verification, size or SHA-256 exists. Static preset inspection indicates portrait in project settings, ARM64-only intent, package `org.example.zombieevolution` (development placeholder), `all_resources`, signing enabled and internet permission disabled in the preset. This is not proof of generated manifest contents. The unexecuted `android` job attempts official 4.4.1 templates, debug signing and export, then checks and uploads APK only after verification. See `TESTING.md` for dependency versions and preset limitations.

## 6. Physical device / emulator — NOT TESTED

No device or Android emulator was available. Synthetic input in existing test scripts is not device touch validation. No compatibility, FPS or memory result is claimed.

## CI artifacts and limitations

The unexecuted workflow is `.github/workflows/zombie-evolution-validation.yml`; artifact names are `godot-headless-logs`, `godot-rendered-evidence`, `godot-android-logs`, and, only after successful checks, `zombie-evolution-arm64-debug`. Godot and templates are pinned to the official 4.4.1 release and checked against that release's SHA-512 sums; Ubuntu is `ubuntu-24.04`. Workflow dependencies and rendering/export behavior are unverified until a real Actions run. The current project and workflow are untracked in this checkout; they must be committed and pushed before a clean runner can access them. No gameplay or portrait setting was changed in this phase.

---

# GitHub Actions execution — Phase 3

## Source and commits

The current branch was initially at `e2f4de4ee3bdbadb07ed424218cb82445242ac52`. With the user's approval, the 21 existing files in the preserved manifest were committed unchanged as baseline `79f5fe8c90f5b0ebf89581c81fc06ebed07b58de`. CI and reports were committed as `9792387c5113c635237f00e1aede914fd9bcd1c7`. The unrelated root README, earlier prototype directories and other untracked work were not staged. No missing historical commit was reconstructed. Manifest verification passed 21/21 before committing; the portrait setting remained `window/handheld/orientation=1`.

The validation workflow ran on `4920f7713f70fcf206b4491054b338c702171e4c` at <https://github.com/kamandbeauty/Ideal/actions/runs/43094813265>. It **failed overall**. This run is separate from historical local tests and provides fresh GitHub Actions evidence. Subsequent diagnostic/audio configuration commit `53017dc5c1d0a1200738514c7a7fbabed2993843` started <https://github.com/kamandbeauty/Ideal/actions/runs/43095080416>; that run's result is not assumed here.

## Fresh headless — PASS on 4920f77

The `headless` job completed successfully. GitHub check annotations reported official `4.4.1.stable.official.49a5bc7b6`; `Checks passed=11 failed=0 warnings=0`. This includes asset import, launcher/level loading, existing focused tests, and unmodified no-input autoplay. Autoplay reported 3,761 frames, victory, 13 kills and a maximum of 3 soldiers. Focused integration tests used scripted setup/positions, as described in the historical test documentation; synthetic touch is not an Android device test. The Actions service separately warned that Node.js 20 actions were being forced to Node.js 24.

## Rendered desktop — PARTIAL / job FAIL on 4920f77

The runner launched the real game under Xvfb with software OpenGL: llvmpipe, OpenGL 4.5 Mesa 25.2.8. GitHub check annotations from `ci/capture_gameplay.gd` reported six actual 360×640 captures: launcher, initial bridge, zombie encounter, selected gate, recruited soldiers, and victory. The capture step exited 1 because neither natural run produced a defeat (`FAIL: natural gameplay did not produce 07-defeat`; `Captured 6/7; missing=1`). It also logged `ERROR: Condition "status < 0" is true. Returning: ERR_CANT_OPEN` at `init_output_device (drivers/alsa/audio_driver_alsa.cpp:90)`, so the job cannot be marked clean. The later workflow selects the dummy audio driver, but its outcome must be checked independently.

Artifact `godot-rendered-evidence` was uploaded for this run (artifact ID `13891030377`); GitHub download: <https://github.com/kamandbeauty/Ideal/actions/runs/43094813265/artifacts/13891030377>. The capture script operates on the real level and only injects a normal input action; it does not stage positions or health. However, `gh run download` in this workspace failed with EOF connecting to GitHub's `productionresultssa*.blob.core.windows.net` artifact host, which is outside the allowed outbound hosts. The image files have **not been inspected locally**; portrait dimensions are reported by the script, and Persian shaping, composition and clipping remain unverified. No defeat screenshot or visual approval is claimed.

## Android export — FAIL / no APK on 4920f77

The `Set up Android command-line tools`, `Install Android SDK components`, and `Install official Godot and matching export templates` steps succeeded. `Configure temporary debug signing and export` failed with exit 1 before APK inspection; the job never reached `Inspect debug APK` or `Upload verified APK`. The precise command and error within that multi-command step could not be recovered: the check annotation was truncated, and artifact/log download failed at the blocked GitHub result-storage host. `godot-android-logs` artifact ID `13891040449` is available at <https://github.com/kamandbeauty/Ideal/actions/runs/43094813265/artifacts/13891040449>. Do not assume an APK was created: there is no verified APK artifact, size, SHA-256, manifest, ABI or min SDK result. No emulator or device test occurred.

The earlier run on `9792387c5113c635237f00e1aede914fd9bcd1c7` (<https://github.com/kamandbeauty/Ideal/actions/runs/43094136161>) also failed overall: headless succeeded, rendered capture failed, and `android-actions/setup-android@v3` failed before SDK installation. Its detailed action log was unavailable for the same outbound-host reason. CI diagnostics and the Android setup path were subsequently adjusted without changing gameplay.

## Follow-up run status

At the time of writing, the follow-up run on `53017dc5c1d0a1200738514c7a7fbabed2993843` was still reported `in_progress` by the GitHub run API. The jobs endpoint returned HTTP 502 during attempted monitoring; `gh run watch` exited without establishing a final result. No result, screenshot approval, or APK is claimed for that run. The completed run and its failures above remain the available verified evidence.
