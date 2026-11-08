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

### 0.4.1 — cancel is a first-class action
The cancel control only appeared while transcribing, so a stalled model download
on a bad network had no way out, and cancelling it surfaced the downloader's own
abort message in red. The action now covers both operations, and a
user-initiated cancel clears the state instead of reporting a failure.
Published as `subflow-0.4.1-release.apk` (tag `subflow-v0.4.1`, CI
`42208045373` on the branch, `42209456435` on the tag).

## ۷. سرویس آنلاین Whisper (۰٫۶٫۰)

**چرا:** کاربر گفت مدل دانلود می‌شود ولی تشخیص کار نمی‌کند. علاوه بر عیب‌یابی
(`asr.selfTest`)، حالا می‌شود کیفیت را از یک مدل بزرگ‌تر گرفت بدون اینکه به موتور
روی گوشی وابسته باشیم.

**چه چیزی اضافه شد**

- `CloudAsr.kt`: صدا با همان `WhisperAudio.decode` استخراج می‌شود (۱۶ کیلوهرتز،
  مونو)، در یک WAV موقت در `cacheDir` نوشته می‌شود و با `multipart/form-data` به
  `<baseUrl>/audio/transcriptions` می‌رود (`response_format=verbose_json`،
  `timestamp_granularities[]=segment`). پاسخ به همان شکل JSON موتور بومی
  نرمال می‌شود، پس `AsrResult` تفاوتی نمی‌بیند.
- پیش‌فرض‌ها: Groq (`whisper-large-v3`)، OpenAI (`whisper-1`)، و «دلخواه» برای هر
  سرویس سازگار با OpenAI. `asr.cloudCheck` با `GET /models` کلید را قبل از
  آپلود طولانی بررسی می‌کند و می‌گوید نام مدل در فهرست هست یا نه.
- سقف ۱۹ دقیقه در هر درخواست (۳۲ کیلوبایت بر ثانیه × ۱۹ دقیقه < سقف ۲۵ مگابایت
  سرویس‌ها)؛ بلندتر از آن پیام صریح می‌دهد، نه برش بی‌صدا.
- خطاها ترجمهٔ کد وضعیت هستند (۴۰۱ کلید، ۴۰۴ آدرس/مدل، ۴۱۳ حجم، ۴۲۹ سهمیه) و
  متن خود سرویس هم در پیام می‌آید.
- کلید و تنظیمات در همان جدول `app_settings` ذخیره می‌شوند (بدون وابستگی تازه)،
  در فهرست به‌صورت ماسک‌شده نشان داده می‌شوند و فقط با دکمهٔ ذخیره نوشته می‌شوند.
- مجوز `INTERNET` حالا دو کاربرد مستند دارد (دانلود مدل + سرویس آنلاین) و
  `check-project.py` هر دو عبارت را در مانیفست اجباری می‌کند.

**چه چیزی تأیید شده و چه چیزی نه**

- تأییدشده در CI: کامپایل Kotlin/C++، `flutter analyze` بدون خطا، تست‌های Dart
  (شامل `test/asr_provider_test.dart` برای آماده‌بودن تنظیمات، ماسک کلید و
  ذخیره/بازخوانی)، بیلد APK.
- تأییدشده روی دستگاه: هیچ‌کدام از مسیر آنلاین. آپلود، پارس پاسخ و پیام‌های
  خطای سرویس فقط با بازبینی کد و کامپایل تأیید شده‌اند، نه با یک اجرای واقعی.

## ۸. آنلاین به‌عنوان مسیر پیش‌فرض (۰٫۷٫۰)

**درخواست:** «برنامه برای تشخیص صدا از مدل Whisper به‌صورت آنلاین و بدون دانلود
استفاده کند.»

**تغییر:** حالت پیش‌فرض یک نصب تازه حالا `cloud` است. یعنی کاربر برای گرفتن زیرنویس
هیچ فایل مدلی دانلود نمی‌کند؛ فقط یک‌بار یک کلید API می‌دهد (Groq کلید رایگان
می‌دهد و از قبل انتخاب شده است) و دکمهٔ شروع را می‌زند. حالت «روی گوشی» با همان
دانلود یک‌بارهٔ مدل کاملاً سر جایش است و با یک ضربه انتخاب می‌شود؛ دیگر چیزی به
کاربر تحمیل نمی‌شود.

**راه‌اندازی در همان صفحه، نه در تنظیمات:** اگر کلید تنطیم نشده باشد، بالای صفحهٔ
«تشخیص گفتار» کارت «تشخیص گفتار آنلاین، بدون دانلود مدل» می‌آید: انتخاب سرویس
(Groq / OpenAI / دلخواه)، فیلد کلید، و دکمهٔ «ذخیره و تست اتصال» که همان لحظه
کلید و وجود نام مدل را بررسی می‌کند. آدرس و نام مدل از پیش پر شده‌اند تا تنها
چیزی که کاربر باید وارد کند کلید باشد.

**صادقانه:** هیچ سرویس Whisper بدون کلید و تضمین‌شده‌ای وجود ندارد؛ اگر بود،
آن را پیشفرض می‌گذاشتیم. بنابراین «بدون دانلود» درست است، «بدون حساب» نه. برای
شبکه‌هایی که Groq/OpenAI را باز نمی‌کنند، گزینهٔ «دلخواه» آدرس پروکسی
سازگار با OpenAI را می‌پذیرد و همان کار را می‌کند.

**وضعیت تأیید:** کامپایل و تست‌های Dart در CI سبز؛ مسیر آپلود روی دستگاه آزمایش
نشده است.

## ۹. خود مدل Whisper داخل APK (۰٫۸٫۰)

**درخواست:** «پس کل ویسپر را بگذار روی اپ.»

**راه‌حل:** مدل `ggml-base-q5_1` (حدود ۵۷ مگابایت) حالا داخل خود APK است. اول
اجرا، `WhisperEngine.ensureBuiltIn()` آن را از `assets/models/` با `openFd` (فایل
فشرده‌نشده) به `filesDir/models/whisper/` کپی می‌کند، امضای `ggml` را بررسی
می‌کند و اسم فایل `.part` را فقط بعد از موفقیت تغییر می‌دهد؛ یعنی نیمه‌کاره‌شدن
کپی هرگز به مدل خراب تبدیل نمی‌شود. تا وقتی مدل کپی نشده، `listModels()` آن را
«مدل همراه برنامه» با نشان سبز برمی‌گرداند و دکمهٔ حذف هم برایش نیست.

**چرا در گیت نیست:** ۵۷ مگابایت وزن مدل با قواعد مخزن (و سقف ۱۰۰ مگابایتی
GitHub برای هر فایل) جور نیست. `tools/fetch-bundled-model.sh` آن را در زمان
بیلد از Hugging Face (و در صورت بسته بودن، `hf-mirror.com`) می‌گیرد و
`.gitignore` جلوی کامیت شدنش را می‌گیرد. سه چیز در `check-project.py` اجباری
شده‌اند تا این ساختار بی‌صدا نشکند: وجود اسکریپت و دو آدرسش، `noCompress += "bin"`
در Gradle (بدون آن `openFd` کار نمی‌کند) و مسیر `assets/models/*.bin` در
`.gitignore`.

**پیامدها:** حجم APK حدود ۵۷ مگابایت بیشتر می‌شود (نصب تازه چیزی دانلود
نمی‌کند، چون مدل داخل همان فایل است). حالت پیش‌فرض دوباره «روی گوشی» است: نه
دانلود، نه حساب، نه اینترنت. حالت آنلاین به‌عنوان گزینه می‌ماند.

**وضعیت تأیید:** بیلد CI با مدل داخل APK و حجم فایل، و کامپایل Kotlin، در CI
بررسی می‌شود. کپی‌شدن asset و اجرای واقعی تشخیص روی دستگاه هنوز آزمایش نشده
است.
