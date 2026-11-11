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
