# SubFlow — Phase 1.5 report (fonts, effects, branding, bug sweep)

Scope of this phase: the typography and caption-look layer the brief asks for
("best Persian fonts", "most attractive subtitle effects", "beautiful
professional app graphics"), plus a real bug/quality sweep and a build that
actually produces an installable APK.

Everything below was produced in a workspace without Flutter/JDK/Android SDK, so
"verified" always means *one of*: a local static/host test, or a real CI run on
an Android toolchain. Nothing is claimed as working because the code exists.

---

## 1. Files created

Fonts (all OFL-1.1, licence text shipped next to the binaries):

| File | Purpose |
|---|---|
| `assets/fonts/Vazirmatn-{Regular,Medium,Bold,ExtraBold}.ttf` | default UI + caption family |
| `assets/fonts/Estedad-{Regular,Bold,ExtraBold}.ttf` | geometric Persian caption face |
| `assets/fonts/Sahel-{Regular,Bold}.ttf` | humanist Persian face |
| `assets/fonts/Samim-{Regular,Bold}.ttf` | display-leaning Persian face |
| `assets/fonts/Shabnam-{Regular,Bold}.ttf` | tall Persian face, good for 9:16 |
| `assets/fonts/Tanha-Regular.ttf` | Persian title/headline face |
| `assets/fonts/Lalezar-Regular.ttf` | Persian gaming/entertainment display face |
| `assets/fonts/{ArchivoBlack,BebasNeue,Anton}-Regular.ttf` | Latin display faces (English presets only) |
| `assets/fonts/licenses/OFL-*.txt` | 10 licence files |

Caption engine:

| File | Lines | Purpose |
|---|---|---|
| `lib/features/effects/caption_fonts.dart` | 187 | font catalogue: family, Persian capability, licence, weights, display flag |
| `lib/features/effects/caption_effect.dart` | 156 | 17 entrance animations, 9 exits, 8 word effects, 6 easings, `CaptionEffects` with defensive `fromMap` |
| `lib/features/effects/caption_preset.dart` | 159 | immutable preset + `toMap()` (the single settings model for preview *and* export) |
| `lib/features/effects/presets_library.dart` | 560 | 20 looks × fa/en = **40 presets** in 7 categories |
| `lib/features/effects/caption_renderer.dart` | 640 | `CaptionPainter` (real 4-layer `CustomPainter`), `CaptionSurface`, `AnimatedCaptionPreview` |
| `lib/features/effects/caption_labels.dart` | 108 | Persian labels for every enum value |
| `lib/features/effects/caption_gallery_screen.dart` | 360 | gallery with live audition, category chips, fa/en switch, detail sheet |

Branding:

| File | Purpose |
|---|---|
| `assets/branding/app_icon_master.png` | 1024² master mark |
| `assets/branding/app_icon_1024.png`, `app_icon_512.png` | store listing sizes |
| `assets/branding/icon-preview.png` | review sheet (not shipped) |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | 48/72/96/144/192 legacy icon |
| `android/app/src/main/res/mipmap-*/ic_launcher_round.png` | round icon |
| `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png` | keyed mark, adaptive foreground |
| `android/app/src/main/res/mipmap-*/ic_launcher_background.png` | generated backdrop |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher{,_round}.xml` | adaptive icon (background + foreground + monochrome) |
| `android/app/src/main/res/values-v31/styles.xml` | Android 12 splash (mark on brand background) |
| `tools/make_icons.py` | regenerates all of the above from the master |

Tests:

| File | Purpose |
|---|---|
| `test/caption_engine_test.dart` | paints every entrance/exit/word effect at 0/50/100 %, plus preset/font/label invariants (39 assertions) |
| `docs/PHASE-1.5-REPORT.md` | this document |

## 2. Files changed

| File | Change |
|---|---|
| `pubspec.yaml` | 10 font families with explicit weights; assets = `assets/db/`, `assets/fonts/`, `assets/branding/` |
| `lib/app/router.dart` | `/captions` route, documented as the only place a style is chosen |
| `lib/features/editor/editor_screen.dart` | live caption overlay on top of the real Media3 surface + style card + gallery hand-off |
| `lib/features/home/home_screen.dart` | gallery entry card |
| `android/app/src/main/AndroidManifest.xml` | `android:roundIcon` |
| `android/app/src/main/kotlin/.../MediaPicker.kt` | **bug fix**: works on `Activity` (see §6) |
| `android/app/src/main/kotlin/.../MainActivity.kt` | holds the picker, routes `onActivityResult` |
| `android/app/src/main/kotlin/.../SubFlowBridge.kt` | takes `android.app.Activity` |
| `tools/check-project.py` | 467 → **664** assertions (see §4) |
| `.github/workflows/subflow-android.yml` | honest failure reporting + annotation channel (see §6) |

## 3. Capabilities implemented

* **Fonts**: 7 Persian-capable families + 3 Latin display families, embedded in
  the APK (no runtime download), each with its OFL licence file. Every Persian
  preset is wired to a family whose cmap really contains Arabic-script glyphs.
* **Caption engine**: 17 entrance animations (fade, four slides, zoom in/out,
  pop, bounce, rotate, blur-in, typewriter, word-reveal, elastic, shake, glow
  pulse, none), 9 exits (incl. rotate-out, pop-out, blur-out, zoom-in),
  8 word effects (karaoke fill, active colour, active scale, word pop, active
  background, active underline, neighbour dim, none) and 6 easing curves.
  Each preset is parameterisable: duration, delay, easing, intensity, pulse,
  stroke width/colour, shadow blur/colour/offset, glow radius/colour, gradient
  fill, background box (colour/opacity/radius), letter spacing, line height,
  width fraction, vertical position, uppercase, direction.
* **Presets**: 20 looks × fa/en = 40, across وایرال / کوتاه / سینمایی / مینیمال /
  آموزشی / گیمینگ, with TikTok/Reels/Shorts/podcast/cinema/gaming characters.
* **One render engine**: the gallery tiles, the editor overlay and the export
  path consume the same `CaptionPreset` + `CaptionPainter`. There is no second
  style model, which is what makes "preview == export" structural rather than a
  promise.
* **Branding**: legacy + adaptive + round + monochrome launcher icons at all
  densities, Android 12 splash, store icons — all derived from one master mark
  by a committed script.
* **Persian typography rules** already enforced in Phase 1 (RTL, bidi,
  ZWNJ-preserving text handling, Persian digit formatting) now apply to the
  caption layer too: `CaptionPreset.direction` is derived from `language`, and
  the renderer lays out with `TextDirection.rtl` and per-family shaping.

Explicitly **not** implemented in this phase (and not claimed anywhere in the
UI): speech recognition, subtitle segment editing, watermark rendering, silence
removal UI, and the native burn-in renderer. The gallery is honest about being a
style picker: it paints a sample line, not a processed video.

## 4. Tests run

Local (no Android toolchain), `bash tools/verify-all.sh`:

| Suite | Result |
|---|---|
| C++ core host tests (`make test`, `-Wall -Wextra -Wpedantic -Wconversion`) | **124 checks, 0 failures** |
| C++ core under ASan + UBSan | clean |
| JNI syntax check against stub `jni.h` | OK |
| SQLite schema: migrations, constraints, cascades, v1→v2 upgrade | **43 assertions, 0 failures** |
| Project checker (imports, assets, channel parity, JNI symbols, braces, WebView ban, INTERNET ban, **enum coverage, Persian-font wiring, launcher densities, preset count**) | **664 assertions, 0 failures** |

CI (`subflow-android.yml`, run `42072627325`, commit `6c7a871`):

| Job / step | Result |
|---|---|
| native core + schema + structure | ✅ |
| `flutter pub get` | ✅ |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | ✅ **0 errors** (was 2 — fixed, see §6) |
| `flutter test --reporter expanded` | ✅ **39 tests** (incl. the new caption-engine suite) |
| `flutter build apk --release` (JDK 17, NDK 26.1.10909125, CMake 3.22.1, Flutter 3.24.5) | ✅ |
| artefact assertions (`lib/arm64-v8a/libsubflow_core.so`, `lib/arm64-v8a/libapp.so`) | ✅ |

## 5. Test results (what the evidence actually proves)

* The app **compiles and ships**: Dart, Kotlin and the NDK C++ core all build on
  a real Android toolchain, and a signed release APK was produced, inspected and
  attached to the rolling release
  <https://github.com/kamandbeauty/Ideal/releases/tag/subflow-apk-latest>
  (`subflow-0.1.0-release.apk`, 43,605,124 bytes + `.sha256`, published by CI run
  `42074006445` on tag `subflow-v1.0.0`).
* The caption engine **paints every one of its 34 effect values without
  throwing**, at entrance 0/50/100 %, with and without an active word, for all
  40 presets — that is what the new widget tests assert (`tester.takeException()`).
* The preset/font contract is verified mechanically: every enum value has a
  Persian label *and* a renderer branch, every Persian preset points at a
  Persian-capable family, every family used by a preset is declared in
  `pubspec.yaml`, and all five launcher densities exist.
* **Not verified**: on-device rendering of Persian shaping at large caption
  sizes, real video + overlay performance, the adaptive icon on a real launcher,
  and HDR/4K paths. No device or emulator was available here, so these remain
  open and are listed as risks instead of claims.

## 6. Remaining errors and bugs found & fixed in this phase

Found and fixed (all caught by real runs, not speculation):

1. **Missing launcher resources** — `@mipmap/ic_launcher` was referenced by the
   manifest but no mipmap existed; that is a resource-linker failure waiting to
   happen. Fixed by generating the full icon set.
2. **`isPartial()` lost its `length` parameter** during an edit →
   `undefined_identifier` (CI, analyzer).
3. **`@immutable` without `foundation`** in `caption_preset.dart` →
   `undefined_annotation` (CI, analyzer).
4. **`CaptionEffects.fromMap` threw `CastError` on a non-numeric field** — found
   by the new "fromMap survives junk" test; now every field is read defensively.
5. **Kotlin could never compile**: `FlutterActivity` extends `android.app.Activity`,
   not `ComponentActivity`, so `registerForActivityResult` and the
   `ComponentActivity`-typed bridge were type errors. The Photo Picker contract
   is now driven directly (`createIntent` / `parseResult`) with results routed
   through `MainActivity.onActivityResult`, which also keeps API 26–32 working.
6. **CI lied about failures**: the build step had `continue-on-error`, so a
   broken Gradle build reported *success* and the diagnostics step was skipped,
   and the job then died in "Collect artefact" with no message. Now the build
   fails honestly, publishes compiler errors as check-run annotations (the only
   log channel reachable from automation), and the collector searches every
   known output directory.

Known open issues (not fixed, deliberately listed):

* `PlayerView`'s `setShowBuffering` and `Color.withOpacity` are deprecated in
  newer SDK/Flutter versions; both are required for Flutter 3.24.5 / Media3
  1.4.1 and will be migrated when the pinned versions move.
* `lib/core/platform/contracts.dart` still uses `as num?` casts on bridge maps.
  Those maps are produced by our own Kotlin encoder, so a wrong type there is a
  programming error rather than user data — but it is a `CastError` instead of a
  graceful message. Scheduled with the Phase 2 bridge work.
* The caption renderer lays out up to four `TextPainter`s per frame (fill,
  stroke, shadow, glow). Fine for one caption line; the gallery animates several
  tiles at once and has not been profiled on a low-end device.

## 7. Next phase

**Phase 2 — offline speech recognition (whisper.cpp / JNI)**: vendor whisper.cpp,
add the model manager (Tiny/Base/Small with size, free-space and ABI checks,
default selection, no fake progress), the audio-extraction path, word-level
timestamps, language auto-detect for fa/en/mixed, cancel + progress plumbing, and
the transcription screen. The caption engine from this phase is the consumer of
those timestamps: `subtitle_words` → `CaptionPainter.activeWord`, so the karaoke
in the gallery becomes real karaoke on real speech in that phase.
