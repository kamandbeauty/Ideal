# Phase 3 — Native Android Renderer

Status: **PASS for source completeness, math parity, and protocol audit; BLOCKED for Gradle compilation & device execution** (no JDK, Android SDK, Gradle distribution, Maven mirror, or `adb` in this sandbox).

## Scope Delivered

| Area | Files | State |
| --- | --- | --- |
| Build & Gradle | `settings.gradle.kts`, `build.gradle.kts`, `gradle.properties`, `gradle-wrapper.properties`, `app/build.gradle.kts`, `app/proguard-rules.pro` | Written (`../../build` output dir wired for Flutter, `org.json:json` wired for host JVM tests) |
| Math & Timeline Core | `CameraMath.kt`, `KeyframeEngine.kt`, `MotionTypes.kt`, `MotionInterpolator.kt`, `TimelineEngine.kt` | Written & numerically verified against all 8 golden fixtures |
| OpenGL ES Renderer | `EGLCore.kt`, `OpenGLRenderer.kt`, `TextureManager.kt`, `RenderEngine.kt` | Written (ES 3.0 primary + ES 2.0 fallback, LRU 4-texture cache, 2-pass separable 9-tap Gaussian blur FBO with cross-dissolve fallback) |
| Media & Muxing | `PhotoDecoder.kt`, `VideoEncoder.kt`, `AudioProcessor.kt`, `MediaMuxerManager.kt`, `MediaProbe.kt` | Written (zero-copy `Surface` encode via `eglPresentationTimeANDROID`, CSD-bearing `INFO_OUTPUT_FORMAT_CHANGED` track registration, AAC-LC audio loop/trim/fade) |
| Service & Bridge | `ExportWorker.kt`, `ExportRequest.kt`, `DeviceCapabilities.kt`, `StorageManager.kt`, `ExportService.kt`, `NativeBridge.kt`, `AudioPicker.kt`, `MainActivity.kt` | Written (`mediaProcessing` foreground service, `@UiThread` event sink dispatch, `MediaStore` gallery publish, `FileProvider` sharing) |
| Resources | `AndroidManifest.xml`, `res/xml/file_paths.xml`, `res/values/{colors,styles}.xml`, adaptive icon + `mipmap-m..xxxhdpi` PNG fallbacks | Written (zero `INTERNET` or storage permissions) |
| JVM Conformance Tests | `MotionConformanceTest.kt` + 8 golden JSON fixtures in `src/test/resources/` | Written & audited against actual golden schemas (unexecuted — no JDK) |

## Critical Defects Found & Fixed During Audit

1. **MP4 `MediaMuxer` Codec-Specific-Data (`csd-0`/`csd-1`) registration (`VideoEncoder.kt`, `AudioProcessor.kt`, `ExportWorker.kt`)** — Originally, synthetic `MediaFormat`s without `csd-0`/`csd-1` were passed to `MediaMuxer.addTrack` prior to encoding, which causes Android's `MPEG4Writer` to fail (`Missing codec specific data`). Fixed by pre-encoding AAC (`encodeAacTrack` capturing the encoder's real `INFO_OUTPUT_FORMAT_CHANGED` format) and registering video (track 0) + audio (track 1) + `mux.startIfReady()` inside `VideoEncoder.onOutputFormat` before the first encoded sample.
2. **Trailing video frames dropped at EOS (`ExportWorker.kt`)** — `enc.finish { sample -> drainQuietly(enc, mux) }` discarded every buffered sample dequeued during EOS drain. Fixed to write every non-config sample directly via `mux.writeVideo(...)`.
3. **Cooperative per-frame cancellation (`ExportWorker.kt`)** — `ExportWorker.cancel()` previously set `cancelled` without signalling `RenderEngine.requestCancel()`, delaying cancellation until all frames finished rendering. Fixed via `@Volatile activeEngine?.requestCancel()`.
4. **Aborted muxer cleanup (`MediaMuxerManager.kt`)** — Removed `muxer?.stop()` inside `abort()` so cancelled/failed exports release the muxer cleanly and delete partial files without flushing corrupt `moov` atoms.
5. **Separable Gaussian blur transition (`OpenGLRenderer.kt`, `RenderEngine.kt`)** — Wired ping-pong FBO creation and the 2-pass 9-tap separable Gaussian blur shader for `blurTransition` (`layer.blurRadius > 0.05`), automatically falling back to standard cross-dissolve if FBOs are unsupported.
6. **Audio picker cancellation & error propagation (`AudioPicker.kt`, `NativeBridge.kt`, `MainActivity.kt`)** — Cancelling the system document picker previously returned `false` from `onActivityResult`, leaving the Dart `pickAudio` `Future` pending forever. Replaced with a typed `AudioPicker.Outcome` (`Picked`, `Cancelled`, `Failed`) and `@UiThread` dispatch on `EventChannel.EventSink`.
7. **PRNG state update order (`MotionTypes.kt`)** — Aligned `Xorshift128Plus.nextU64` state swap order with `MOTION_SPEC.md` §10.
8. **`MotionConformanceTest.kt` schema & boundary alignment** — Extracted top-level `transitionDrawLayers(...)` in `TimelineEngine.kt` so boundary steps `p = 0.0`, `p = 1.0`, and `TransitionType.NONE` match `transitions.json` (`9 × 21` rows), added `custom_ez`, `encoding.json` (`108` bitrates + `roundEven`), and `ExportRequest.fromJson` contract tests, and added `testImplementation("org.json:json:20240303")`.
9. **Flutter Gradle APK output directory & API 24 launcher icons** — Configured `../../build` directory mapping in `android/build.gradle.kts` (required by `flutter build apk`) and generated `mipmap-mdpi..xxxhdpi/ic_launcher.png` fallbacks for API 24–25 (`minSdk = 24`).

## Blocked in This Environment

| Item | Reason |
| --- | --- |
| `./gradlew testDebugUnitTest` | No JDK or Gradle distribution installed; `services.gradle.org` and `dl.google.com` unreachable |
| `flutter build apk` | No Flutter/Android SDK installed |
| Real hardware MediaCodec / OpenGL ES / MediaMuxer device run | No Android emulator, `adb`, or physical device |
