# QA report — vertical slice in progress

## Executed locally

- Environment inspection: Debian 12, Python 3.11, Node 22; initially no Godot/Blender/Java/Android SDK/ADB/templates.
- Obtained Godot 4.7.2 stable editor through checksum-verified GitHub transport; `--headless --version` reports `4.7.2.stable.official.ed1daf0bf`.
- Headless project import and script compilation performed after each implementation chunk.
- Dependency-free unit and scene-integration runner executed. Latest local report: **131 assertions, 0 failures** (`artillery-test-results.json`). Includes a complete first mission using real terrain collision, projectile flight, moving AI, reload and results.
- Runtime scene startup exercised headlessly; discovered API mismatches (ImmediateMesh, MultiMesh, particle process properties) were corrected and startup rerun.

## Not yet claimed

- Android device/emulator installation, touch hardware testing and thermal/performance validation.
- Store-release signing (unless repository secrets are configured).
- Final CI APK/AAB build status is recorded in the milestone report and `delivery/BUILD-STATUS.txt` after actual export.
- Software-rendered screenshots/frame time are desktop CI observations, not mobile benchmarks.

The Blender asset workflow and Android build workflow are present. Their failures during toolchain bring-up were diagnosed and corrected; final package success is only reported after a successful run and artifact inspection.
