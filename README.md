# MotionShot

**MotionShot** is a fully offline Android application (Flutter UI + native Kotlin OpenGL ES / MediaCodec / MediaMuxer video renderer) that transforms still photos into smooth cinematic videos with real camera motion, manual keyframe authoring, transitions, and music.

- **100% Offline by Design** — `AndroidManifest.xml` declares **no `INTERNET` permission** and **no storage read/write permissions** (uses Android Photo Picker + `MediaStore`).
- **No FFmpeg / No GPL Bloat** — Rendering uses hardware-accelerated **OpenGL ES 3.0** (with automatic **ES 2.0** fallback), zero-copy `Surface` input into **MediaCodec** (H.264 High@4.1 & HEVC Main), and **MediaMuxer** MP4 output.
- **Preview == Export by Construction** — Both the Flutter interactive preview and the Kotlin renderer implement [`docs/MOTION_SPEC.md`](docs/MOTION_SPEC.md) and are verified against shared golden test vectors.
- **Bilingual & RTL-First** — Full Persian (`fa`, RTL default) and English (`en`, LTR) localization (303 keys each) bundled with offline **Vazirmatn** fonts.

---

## Features

- **Photo Management**: Multi-photo import via Android Photo Picker, EXIF orientation handling, non-destructive high-res retention, background thumbnail cache, drag-to-reorder, replace, per-photo 90° rotation, and duration control.
- **15 Deterministic Camera Motions**: `zoomIn`, `zoomOut`, `panLeft`, `panRight`, `panUp`, `panDown`, `diagonalLeft`, `diagonalRight`, `slowPush`, `pullBack`, `zoomPan`, `subtleRotation`, `drift`, `centerToCorner`, `combined` — seeded per project & photo so **Auto Motion** never repeats adjacent motion types and **Regenerate All** preserves locked shots.
- **Manual Keyframe Editor**: Up to 20 keyframes per photo, pinch-to-zoom & drag-to-pan canvas, safe-area cover clamping (mathematically prevents black borders at any zoom/rotation), 6 built-in easings + custom CSS `cubic-bezier` editor, copy/paste motion across photos, and 50-step undo/redo.
- **Curved Motion Paths** (spec §12): ten path presets (circles, ellipses, spirals, arcs, figure-eights, S-curves, béziers) plus freehand drawing, arc-length-uniform speed, C1-continuous centripetal Catmull-Rom smoothing, and deterministic auto-path generation — evaluated by the same code in preview and export.
- **9 Transitions**: `crossDissolve`, `fade`, `fadeToBlack`, `slideLeft`, `slideRight`, `zoomTransition`, `blurTransition` (2-pass separable Gaussian blur FBO with cross-dissolve fallback), `smoothZoom`, and `none` (hard cut).
- **Audio Engine**: System document picker for MP3/AAC/WAV/OGG/FLAC, trim start/end, volume, linear fade-in/out, equal-power crossfaded looping (20 ms seam), and hardware AAC-LC encoding muxed to exact video duration.
- **Capability-Aware Export**: 720p / 1080p / 1440p / 4K (2160p), 24 / 30 / 60 fps, `9:16` / `16:9` / `1:1` / `4:5` / original aspect, H.264 & HEVC, quality presets + custom bitrate, disk-space & hardware-encoder preflight, Android `mediaProcessing` foreground service with notification cancel action, post-render `MediaProbe` verification, `MediaStore` gallery publishing, and `FileProvider` sharing.

---

## Repository Layout

```text
docs/
  MOTION_SPEC.md          # Canonical math, timeline, rendering & encoding spec
  RELEASE.md              # Build, signing, test & on-device smoke checklist
  phases/                 # Phase reports + latest portcheck & audit outputs
lib/
  app/                    # Theme, Vazirmatn RTL/LTR setup, 303-key fa/en l10n, router, providers
  core/                   # Immutable models, SQLite project repository, media & thumbnail services
  features/               # Home, Gallery, Editor, Motion + Path Editor, Preview, Audio, Export, Settings
test/                     # Dart golden-vector, keyframe-ops, motion-path & editor-controller tests
android/app/src/
  main/kotlin/.../        # NativeBridge, MainActivity, AudioPicker + 23-file motion/GL/MediaCodec engine
  test/kotlin/.../        # MotionConformanceTest + MotionPathConformanceTest (JUnit golden-vector replay)
tools/validate/motionshot/# Executable Python reference model, MP4 verifier, portcheck & feature audit
```

---

## Verification & Build Commands

### 1. Run Reference & Static Parity Suites (Python 3.11+)

```bash
cd tools/validate
python3 -m motionshot.verify     # 3651/3651 math, timeline, path-engine, audio & bitrate checks
python3 -m motionshot.portcheck  # 32/32 Kotlin/Dart parity, channel/JSON protocol & symbol checks
python3 -m motionshot.audit      # 95/95 product feature traceability checks
```

### 2. Run Flutter & Android Unit Tests (Requires Flutter >= 3.27.0, JDK 17, Android SDK 35)

```bash
flutter pub get
flutter analyze
flutter test
cd android && ./gradlew testDebugUnitTest
```

### 3. Build Release APK

```bash
flutter build apk --release
```

See [`docs/RELEASE.md`](docs/RELEASE.md) for signing (`key.properties`) and on-device smoke-test steps, and [`docs/phases/`](docs/phases/) for detailed phase verification reports.
