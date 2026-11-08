# Release & Build Guide

MotionShot is a pure Flutter + Kotlin Android application (`minSdk = 24`,
`targetSdk = 35`, Java/Kotlin 17, Flutter `>= 3.27.0` / Dart `>= 3.6.0`, no NDK,
no FFmpeg, no network permissions).

## 1. Offline / CI Verification Suites

Run all three deterministic verification and static-audit suites first:

```bash
cd tools/validate
python3 -m motionshot.verify     # 1850 invariant checks + golden vector generation
python3 -m motionshot.portcheck  # 24 cross-runtime parity, bridge, symbol & Dart/Kotlin checks
python3 -m motionshot.audit      # 76 product requirement traceability checks
```

## 2. Dart & JVM Conformance Tests

On a workstation or CI runner with Flutter `>= 3.27.0` and JDK 17:

```bash
flutter pub get
flutter analyze
flutter test
cd android && ./gradlew testDebugUnitTest
```

`MotionConformanceTest` replays the exact golden vectors under
`android/app/src/test/resources/*.json` against the Kotlin motion, camera,
timeline, transition, PRNG, bitrate, and `ExportRequest` implementations.

## 3. Signing Configuration

`android/key.properties` + `android/app/keystore/motionshot-release.p12` are
**committed** (an intentional exception in `.gitignore`) because the CI
pipeline has no secrets access. The APKs are installed directly on phones
outside the Play Store, so Play-Store-grade key secrecy does not apply; the
cost of a leaked key is limited to someone pushing a fake "update" through
this repository, which is already under the owner's control.

```properties
storePassword=<keystore-password>
keyPassword=<key-password>
keyAlias=motionshot
storeFile=keystore/motionshot-release.p12
```

**Rotating the key**: regenerate the `.p12` (any keytool/cryptography
PKCS12 with alias `motionshot`), replace the file + both passwords in
`key.properties`, commit. Devices must reinstall once after a rotation.

When `key.properties` is absent, `release` falls back to the local debug key so
local profiling builds (`flutter build apk --release`) work out of the box.

## 4. Building Release Artifacts

```bash
flutter build apk --release
flutter build appbundle --release
```

Output paths:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

## 5. On-Device Smoke Checklist

1. Import 5–20 mixed-aspect photos (portrait 3:4, landscape 4:3, ultra-wide, rotated EXIF) via the Android Photo Picker — verify zero storage permission prompts.
2. Run **Auto Motion**, lock one photo, run **Regenerate All** — verify locked photo keyframes remain unchanged and no two adjacent unlocked photos share a motion type.
3. Scrub and play **Preview** across all 9 transition types (`crossDissolve`, `fade`, `fadeToBlack`, `slideLeft`, `slideRight`, `zoomTransition`, `blurTransition`, `smoothZoom`, `none`).
4. Attach an MP3/AAC/WAV track via **Audio**, configure trim, fade-in/out, and loop, then export 1080p@30fps H.264 and HEVC.
5. Background the app mid-export — verify foreground notification progress updates and **Cancel** cleanly stops rendering and deletes any partial MP4.
6. Verify the finished video appears in `Movies/MotionShot` via `MediaStore`, plays with synchronized audio, and has zero black borders outside `fadeToBlack`.
