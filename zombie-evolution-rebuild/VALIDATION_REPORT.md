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

---

# Phase 4 — run monitoring (2026-11-11 20:52 UTC)

No gameplay, rendering or CI fixes were made and no additional commit was created while runs remained active. The three requested runs were queried with `gh api repos/kamandbeauty/Ideal/actions/runs/<run_id>` and their job/check-run APIs. Statuses at the time of this entry:

| Run | Tested commit | Overall | Headless | Rendered | Android |
| --- | --- | --- | --- | --- | --- |
| [43094813265](https://github.com/kamandbeauty/Ideal/actions/runs/43094813265) | `4920f7713f70fcf206b4491054b338c702171e4c` | completed, failure | success: 11 checks, 0 failures, 0 warnings | failure: `Capture actual automated gameplay`, exit 1 | failure: `Configure temporary debug signing and export`, exit 1 |
| [43095080416](https://github.com/kamandbeauty/Ideal/actions/runs/43095080416) | `53017dc5c1d0a1200738514c7a7fbabed2993843` | in progress; conclusion unavailable | check-run still in progress; no result | check-run still in progress; no result | check-run still in progress; no result |
| [43095434424](https://github.com/kamandbeauty/Ideal/actions/runs/43095434424) | `8d1b49491a27f9e7f5537ff351a401a77ddd085b` | queued; conclusion unavailable | not started | not started | not started |

`gh run watch` was used to wait for the queued run; it remained queued for more than 30 minutes. Run 43095080416 remained `in_progress` for more than 35 minutes, with its `updated_at` unchanged since 20:17:30 UTC, and its jobs endpoint repeatedly returned HTTP 502. These are observed GitHub responses, not a diagnosis of the service failure. Neither run was cancelled or marked as passed. Monitoring ended without a final outcome, so no new commit was made; this report update is uncommitted.

## Latest completed run: details and limitations

- Headless: Godot `4.4.1.stable.official.49a5bc7b6`, 11/11 checks; autoplay completed with 13 kills. The two later runs have no completed headless result yet.
- Rendered: software OpenGL llvmpipe, Mesa 25.2.8, 360×640 captured dimensions. The log reports six gameplay captures and two runs ended; it explicitly reports `FAIL: natural gameplay did not produce 07-defeat`, `Captured 6/7; missing=1`. This indicates the automated attempts did not reach a natural defeat; it is not evidence that the capture script quit early. A real ALSA initialization error (`ERR_CANT_OPEN`) also occurred. The dummy-audio follow-up remains unverified. No deterministic test-only defeat scenario has been implemented while active runs remain unfinished.
- The [rendered artifact](https://github.com/kamandbeauty/Ideal/actions/runs/43094813265/artifacts/13891030377) exists, but prior `gh run download` and `gh run view --log-failed` attempts failed with EOF on GitHub result-storage hosts unavailable from this environment. Its images were not retrieved or visually inspected. Persian shaping, HUD layout, scene composition and image authenticity cannot be independently approved from annotations alone.
- Android: `setup-java`, Android command-line tools, SDK components, and Godot plus matching templates were marked successful. The combined `Configure temporary debug signing and export` step failed with exit 1; APK inspection and upload were skipped. The annotation is truncated and the full log artifact cannot be downloaded here, so the particular failing command and error (debug signing, import or export) are **unknown**. The [Android log artifact](https://github.com/kamandbeauty/Ideal/actions/runs/43094813265/artifacts/13891040449) is available in GitHub for inspection by someone with access to the storage host. No verified APK, manifest, minimum API, hash or device test exists.

---

# Phase 5 — evidence collection and export diagnostics

## Observed completed run

[Run 43095080416](https://github.com/kamandbeauty/Ideal/actions/runs/43095080416), commit `53017dc5c1d0a1200738514c7a7fbabed2993843`, completed with overall failure. The `Run all headless checks` step succeeded: Godot `4.4.1.stable.official.49a5bc7b6`, `Checks passed=11 failed=0 warnings=0`; the headless job failed later during artifact upload. The rendered job captured six 360×640 frames under llvmpipe and failed because the two normal attempts did not produce natural defeat. With the dummy audio driver selected in this run, the earlier ALSA initialization error was absent from the published renderer diagnostics.

All three log/artifact uploads in this run failed. GitHub check-run annotations report `Failed to CreateArtifact: Failed to make request after 5 attempts: Unexpected token '<', "<!DOCTYPE "... is not valid JSON` for headless and rendered, and `Failed to CreateArtifact: Received non-retryable error: Failed request: (404) Not Found: workflow run not found` for Android. GitHub reports zero artifacts for this run. The prior run successfully uploaded artifacts under the same job paths/names; this failure is at the artifact service request, not evidence of missing files, name conflict, or insufficient permissions. The exact underlying server-side cause is unknown.

Android's SDK and matching Godot templates steps succeeded, the temporary debug keystore was generated, and the import step ran. The export command reported `ERROR: Cannot export project with preset "Android ARM64" due to configuration errors:` followed by `ERROR: Project export for preset "Android ARM64" failed.` The published annotation omitted the underlying configuration detail; APK inspection and upload were skipped. The exact configuration error and effective Android manifest remain unknown.

[Run 43095434424](https://github.com/kamandbeauty/Ideal/actions/runs/43095434424), commit `8d1b49491a27f9e7f5537ff351a401a77ddd085b`, was still queued at the time of this report; it was not cancelled and no result is claimed.

## Diagnostic changes prepared in Phase 5

- Separate rendered logs from optional screenshot uploads, upload logs after failure, require nonempty log files, and retain failure/diagnostic annotations. The artifact service itself can still fail, so successful uploading is not assumed. Missing optional screenshots cannot suppress the captured gameplay log.
- Keep the 11 headless checks and unchanged gameplay; add a clearly labeled test-only capture that applies lethal damage via the real hero's `apply_damage` and checks the actual defeat transition only when both natural runs fail to reach defeat. Normal gameplay balance is unchanged, and the resulting `07-defeat-test-only.png` must not be described as a natural defeat.
- Print export preset, exact command, destination, keystore existence/alias and exit code; preserve complete output with `tee` and reprint it on failure. The temporary debug password is generated and masked on the CI runner; the script does not print it. Expanded CI annotations include the export log to aid diagnosis if artifact storage is unavailable. These diagnostics do not themselves correct the unknown Godot export configuration error.

## Current-run checks and limits

`sha256sum -c zombie-evolution-rebuild/SOURCE_MANIFEST.sha256` passed all 21 recorded baseline files. `python3 zombie-evolution-rebuild/tests/export_config_test.py`, `bash -n zombie-evolution-rebuild/ci/*.sh`, GDScript grammar parsing with gdtoolkit, and a PyYAML workflow structure check passed. Portrait remains unchanged. No local Godot runtime, rendered capture, Android SDK export or device testing was available. The diagnostic changes have not yet been validated on a runner, and artifact service recovery is not guaranteed.

---

# Phase 6 — Android export investigation

Run [43130009205](https://github.com/kamandbeauty/Ideal/actions/runs/43130009205) invoked `Godot_v4.4.1-stable_linux.x86_64 --headless --path zombie-evolution-rebuild --export-debug 'Android ARM64' exports/zombie-debug.apk`, using a temporary generated debug key and Godot editor settings for the JDK, Android SDK and keystore. The exported output in the published annotation showed `Cannot export project with preset "Android ARM64" due to configuration errors:` with no diagnostic following the colon, then project export failed. The full log artifact was uploaded, but its redirected storage host cannot be reached from this sandbox. No password was published.

Godot 4.4.1's Android `has_valid_project_configuration` sets `valid = false` without adding an error message when `ResourceImporterTextureSettings::should_import_etc2_astc()` is false. That function uses the `rendering/textures/vram_compression/import_etc2_astc` project setting or the host's preferred texture format; the default setting is false, and x86 hosts prefer S3TC/BPTC. The project had no ETC2/ASTC setting, and the experiment recorded an x86_64 runner. The repository contains no source image textures or `.import` sidecars; visual geometry is generated by the project. The preset uses a prebuilt template, ARM64 only, and signing. Relevant upstream source: [Android exporter](https://github.com/godotengine/godot/blob/4.4.1-stable/platform/android/export/export_plugin.cpp), [texture settings](https://github.com/godotengine/godot/blob/4.4.1-stable/editor/import/resource_importer_texture_settings.cpp), [host defaults](https://github.com/godotengine/godot/blob/4.4.1-stable/core/os/os.cpp).

Controlled experiment [43130482742](https://github.com/kamandbeauty/Ideal/actions/runs/43130482742) copied the project and changed only the ETC2/ASTC setting before import and export. It passed the previously failing configuration check and proceeded to create the APK. Subsequent experiment [43130650176](https://github.com/kamandbeauty/Ideal/actions/runs/43130650176) confirmed export exit code 0, passed APK inspection and uploaded the APK, while headless and rendered jobs also passed. Together with the source, this confirms the missing mobile texture import setting as the cause of the original configuration rejection.

The minimal project fix enables `textures/vram_compression/import_etc2_astc=true` in the existing `[rendering]` section before import. This preserves existing assets, portrait, the ARM64 preset and visual design; the original `SOURCE_MANIFEST.sha256` is retained unchanged as historical baseline evidence, so its `project.godot` entry describes the pre-fix file rather than the current one.

Godot separately emits `ERROR: No project icon specified...` while returning export code 0 and retaining the default template icon. The workflow explicitly tolerates only that exact known message, fails on other Godot errors or a nonzero exit, and still requires ZIP integrity, package, manifest, ABI, signature and SHA checks before upload. This is a missing custom icon diagnostic, not an indication of a failed export. Physical-device and emulator testing: **NOT TESTED**. Visual screenshot and Persian shaping inspection also remain outstanding.

The first run of the committed project fix, [43130856804](https://github.com/kamandbeauty/Ideal/actions/runs/43130856804) at `7117c00f0181b0c0cf6e2d91e7ac23e6de08b544`, passed rendered capture and Android export, inspection and upload, but failed the headless suite's historical manifest check (10/11 checks) because the intentional project setting changed the baseline hash. Its verified debug APK is [artifact 13905251656](https://github.com/kamandbeauty/Ideal/actions/runs/43130856804/artifacts/13905251656), size 27,433,314 bytes, SHA-256 `556b6be240019a48f65fbb54c3c1e25d64e000f90906a9911ac8f96a74f55459`. `aapt` reported `org.example.zombieevolution`, min API 21, target API 34, and only `arm64-v8a`; its manifest reports portrait (`screenOrientation=1`). ZIP integrity and signature verification passed; the package permission dump listed no requested permissions. No device was used.

To retain all 11 checks without falsifying the historical baseline, `SOURCE_MANIFEST.sha256` remains byte-for-byte unchanged and its own historical SHA-256 is checked; the same 21 current project files are checked against `CURRENT_MANIFEST.sha256`, which differs only in the intentionally updated project configuration hash. The earlier baseline check failure is not represented as a pass. A fresh workflow run must establish regression status for this change.
