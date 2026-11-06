# SubFlow — Phase 3: looks, layout and the Whisper engine

Version: `0.3.0+5` · APK: `subflow-0.3.0-release.apk` (tag `subflow-v0.3.0`)

Three things were asked for after the 0.2.2 install worked on the reporting
device: make the look and layout professional like CapCut, add the Whisper
engine, and fix the caption samples that did not work and were a mess.

---

## 1. The caption samples were broken — two real bugs, both fixed

**Bug A: a grid of empty boxes.** Every tile in the gallery ran its own looping
`AnimatedCaptionPreview`, all created at the same moment with the same 2.6 s
cycle. They therefore shared one phase: a screenshot taken during the entrance
or exit stretch showed *every* card blank, and a fade-in preset spent most of the
cycle at low opacity. The card that was scrolled into view later had a different
phase, which is why exactly one tile showed something.

Fixed by separating audition from selection: tiles now paint the *held* state
(`enter = 1`), so a look is always legible while browsing, and only the sheet
animates — one looping preview instead of ten phase-locked ones.

**Bug B: decorations in the wrong coordinate space.** Word backdrops
(`activeBackground`, `activeUnderline`) are measured with
`TextPainter.getBoxesForSelection`, which reports rectangles in the text's own
layout space. The painter drew them after translating the canvas to the caption's
*centre*, so the highlight landed somewhere else on the frame — the green block
floating in the corner of the screenshot. The painter now translates to the text
origin before drawing those rectangles, and restores afterwards.

`test/` gained coverage for the renderer's contract that can be checked without a
device, and the layout bugs are gone from the redesign described next.

## 2. Look and layout

- **Gallery (`/captions`)**: categories as one clean scrolling row (no more
  clipped chips), a two-column grid of compact tiles with a real caption painted
  over a bundled cinematic still (`assets/images/caption_frame.jpg`) instead of a
  flat card, selected tile outlined with a check badge, and a detail sheet with a
  large animated audition, metadata chips and one primary action.
- **Editor (`/project/:id`)**: the auto-transcription card is now the headline
  action, styled with the brand gradient; the studio card stays below it for
  projects that already have text.
- **Studio empty state**: offers "تشخیص خودکار گفتار" as the primary action and
  keeps manual entry as a secondary link.
- Shared pieces (`SfScaffold`, `SfCard`, `SfPrimaryButton`, palette) were left as
  the single source of truth so screens keep one rhythm.

## 3. Whisper engine (offline, on-device)

**Engine.** `third_party/whisper.cpp` (v1.7.6, MIT) is vendored with `ggml`, built
as a static library into `libsubflow_core.so` (`SF_ENABLE_WHISPER=ON`). Hardware
backends are off, OpenMP is off (the NDK ships no libgomp), `GGML_NATIVE` is off
for cross-compilation, and warnings are per-target so the vendored code does not
inherit ours.

**Native wrapper** (`android/app/src/main/cpp/core/sf_asr.{h,cpp}`): load/unload a
ggml model, transcribe mono 16 kHz float PCM, cancel mid-run, report 0-100
progress, and split over-long captions on word boundaries. The whole file is
compiled *without* whisper too, where every entry point refuses with
`this build has no whisper engine` — the host test suite verifies that guard
(139 checks, up from 124).

**JNI** (`sf_jni.cpp`): `nativeAsrAvailable`, `nativeAsrLoadModel`,
`nativeAsrReady`, `nativeAsrUnload`, `nativeAsrCancel`, `nativeAsrProgress`,
`nativeAsrTranscribe` (returns `{"ok":true,"segments":[[startUs,endUs,"text"]…]}`).
Array-in/JSON-out keeps the boundary allocation-cheap; Kotlin declares every one
of them, and `tools/check-project.py` fails if the two sides drift.

**Audio** (`asr/WhisperAudio.kt`): MediaExtractor + MediaCodec decode, 16-bit or
float PCM, mid-stream format changes, downmix to mono and linear resample to
16 kHz. No ffmpeg. Progress 0-30 % while decoding, 30-100 % while whisper runs.

**Models** (`asr/WhisperEngine.kt`): the app never downloads or bundles a model.
The user picks a ggml `.bin` through the system document picker; it is copied into
app-private storage, the `ggml` magic is verified (a wrong file is refused, not
fed to the engine), and size + sha256 are reported. Deleting a model is confined
to the model directory on a canonical path check.

**Dart** (`lib/services/asr_service.dart`, `lib/features/asr/asr_screen.dart`):
capabilities first (a build without the engine says so instead of failing
halfway), model list with import/delete, language (auto/fa/en), start with a real
progress bar and cancel, and on success the transcript is written into the
project's original track through `SubtitleDocument.withText`, so word timings are
spread by the same code the studio uses and the editor reloads it immediately.

**Not claimed**: this workspace has no Android device. The Kotlin, JNI and
whisper.cpp integration is compiled and unit-tested where possible (host C++
tests, `flutter test`, `flutter analyze`, the Kotlin + NDK build in GitHub Actions CI),
and the APK builds for arm64-v8a and x86_64 — but "transcribed a real video on a
real phone" is the user's check, not ours. Model quality and duration figures in
the UI are guidance, not measurements.

## 4. Verification

| Check | Result |
| --- | --- |
| `tools/native-core` host tests | 139 checks, 0 failures |
| ASan + UBSan | clean |
| `check-jni` (syntax only, stub jni.h) | OK |
| `check_schema.py` | 43 assertions |
| `check-project.py` | 862 assertions |
| `flutter analyze` | 0 errors (CI run `42130184708`) |
| `flutter test` | 91 cases / 8 files, all green in CI |
| APK | arm64-v8a + x86_64, 46,959,547 B, `libsubflow_core.so` includes whisper |

The whisper build itself was also validated outside Android while writing this:
the vendored tree configures and builds on the host (cmake 4.4, g++ 12) and
`sf_asr.cpp` compiles and links against it with `SF_HAVE_WHISPER=1`; a smoke
program confirmed `AsrAvailable() == true`, a missing model refused with a
message, and `Transcribe` refused cleanly with `no model is loaded`. Two build
regressions found that way (a lost field declaration, `-ffast-math` leaking into
ggml, a Double/Float mix in the resampler) were fixed before the tag.

Tag `subflow-v0.3.0` → CI run `42131874848` ✅ published
`subflow-0.3.0-release.apk` (+ `.sha256`) on the `subflow-apk-latest` release;
the 0.2.2 assets were removed.

## 5. Known limits

- Whisper is CPU-only and runs on one thread pool; a 10-minute clip on a mid-range
  phone is minutes, not seconds.
- 32-bit ARM is still excluded (a 300 MB model on a 2-3 GB device is not a
  supported configuration).
- Detection of the spoken language ("auto") is whisper's own; the UI also lets the
  user pin fa/en.
- Word-level timings come from the document's spreader, not from whisper's token
  timestamps, so they are as good as the caption split — the same rule the manual
  editor follows.

---

## 6. 0.4.0 — model in one tap, CapCut-style frame, no welcome screen

**"The Whisper model isn't in the app."** Correct, and it cannot be shipped as a
file: the smallest usable model is ~32 MB and the useful Persian one is ~57 MB, and
the weights are not in this repository (and never may be - they are not ours to
vendor). What was missing was a way to get one *from inside the app*. Added:

- `asr.catalog` + `asr.downloadModel`: three quantised models (tiny 32 MB, base
  57 MB - the recommendation for Persian, small 190 MB), downloaded over HTTPS
  from Hugging Face with `hf-mirror.com` as a fallback because one of the two is
  routinely unreachable on some networks.
- Every download is verified twice before it is kept: ggml magic number, then a
  real `whisper_init_from_file_with_params` load through the native engine. A bad
  file is deleted and reported, never silently used.
- The ASR screen now lists the catalogue with sizes and per-model progress, and a
  completed download is selected automatically. Manual `.bin` import still works
  for anyone who already has a model.
- `INTERNET` permission added to the manifest, documented next to the paragraph
  that says media never leaves the device. `tools/check-project.py` now enforces
  that exception instead of a blanket ban: no `ACCESS_NETWORK_STATE`, no other
  network permission, and the manifest must keep explaining itself.

**"Layout like CapCut."** The app now has the frame short-form editors use:

- persistent bottom bar with three destinations: پروژه‌ها / استایل‌ها / تنظیمات
  (`StatefulShellRoute.indexedStack`, so tab state survives a push);
- home = identity row, a large gradient "پروژهٔ تازه" action, two quick tools
  (تشخیص گفتار, استایل زیرنویس) and a two-column grid of project tiles with a
  status badge and last-used time;
- every deeper screen (import, editor, ASR, studio, picker gallery) is pushed on
  top of the bar, so "back" always returns to the list you left.

**"No welcome screen."** Onboarding is gone: file, route, provider and its setting
key. Splash waits for the database only, then goes straight to `/home`. A
first-run carousel in front of a three-tap workflow was pure friction.

**Verification for this pass**: no compiler here, so the loop was CI. Three real
defects were found and fixed before the tag - the analyzer's missing
`CaptionPainter.minFontSize` field, `-ffast-math` leaking from gradle into ggml
(a hard `#error` in Android builds), and a Double/Float mix in the resampler.
Locally: host core 139 checks, ASan/UBSan clean, JNI syntax, schema 43, project
checker (now quote-aware when stripping comments, because a URL literal was being
mistaken for a comment), and the Dart suite.
