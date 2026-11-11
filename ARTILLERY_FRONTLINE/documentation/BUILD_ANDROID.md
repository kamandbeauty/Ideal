# Building the Android APK

The APK is built by GitHub Actions, not on a developer machine.
Workflow: `.github/workflows/last-wall.yml`, triggered by every push to the
session branch that touches the project.

## What the workflow does

1. **validate**
   - downloads Godot 4.7.2 (checksum verified) and imports the project;
     any script or shader error fails the job;
   - runs the headless suites (`tests/run_tests.gd`) and requires the report
     to pass with at least 700 checks;
   - plays the real game under a software renderer (`-- --smoke`): menus,
     every weapon, the gate falling and the defeat screen, with a screenshot
     of each step and a report;
   - commits the evidence to `documentation/qa/`.
2. **android** (only if validate passed)
   - installs Java 17, Android SDK 36 and the Godot export templates;
   - exports `LastWall-arm64.apk` (Vulkan mobile renderer) and
     `LastWall-compatibility.apk` (OpenGL ES fallback);
   - verifies the signature with `apksigner`, then inspects the packages
     (`tools/verify_packages.py`): ARM64 engine library present, no other
     architecture, project data present, ZIP integrity, package id,
     API 24 minimum / API 36 target, landscape activity, no network
     permission, no tests or tools exported;
   - commits `delivery/LastWall-arm64.apk` with its checksum and metadata.
     The compatibility APK is kept as a workflow artifact only.

## Signing

Without repository secrets the workflow creates a throw-away development
key for each run. That APK installs and runs for testing, but every build has
a different signature, so a newer build cannot update an older one in place
(uninstall first), and it is not a store release.

For a stable signature add these repository secrets (the names are kept
from the earlier project so existing secrets continue to work):

| Secret | Content |
| --- | --- |
| `ARTILLERY_KEYSTORE_BASE64` | the release keystore, base64 encoded |
| `ARTILLERY_KEYSTORE_PASSWORD` | its password |
| `ARTILLERY_KEY_ALIAS` | the key alias |

With them present the workflow exports in release mode with that key.

## What CI does not prove

The packages are built, signed and inspected, and the game is played under
a desktop software renderer. Nothing in CI runs the APK on an Android
device or emulator. Frame rate, touch feel and device-specific rendering
have to be checked on a phone.

## Installing

Copy `delivery/LastWall-arm64.apk` to an ARM64 Android phone (Android 7.0
or newer), allow installation from that source, and open it. If the game
shows rendering problems on an older GPU, use `LastWall-compatibility.apk`
from the workflow artifacts instead.
