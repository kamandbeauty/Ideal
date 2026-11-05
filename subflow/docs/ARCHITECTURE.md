# SubFlow — معماری و برنامه اجرایی

> Professional Offline AI Subtitle & Video Editor · Android 8+ (API 26) · ARM64-first
> وضعیت سند: پلان مادر پروژه. هر فاز باید در پایان با گزارش اجرایی به این سند گره بخورد.

---

## ۰. خلاصه مدیریتی

SubFlow یک ادیتور ویدئو و زیرنویس **کاملاً آفلاین** است: تشخیص گفتار روی خود گوشی با
`whisper.cpp` انجام می‌شود، استایل و افکت‌های زیرنویس توسط یک موتور مشترک بین
«پیش‌نمایش» و «خروجی» رندر می‌شوند و رندر نهایی با `Media3 Transformer` + کدگذار
سخت‌افزاری دستگاه انجام می‌گیرد.

سه تصمیم معماری که بقیه پروژه را تعیین می‌کنند:

1. **یک مدل داده برای همه‌چیز.** استایل زیرنویس، موقعیت واترمارک، پلن خروجی و
   تایم‌لاین در SQLite ذخیره می‌شوند و همان مقادیر (نه کپی دیگری از آن‌ها) به
   رندرکننده و به پیش‌نمایش داده می‌شوند. دلیل اصلی «اختلاف Preview و Export» در
   نرم‌افزارهای مشابه، وجود دو مدل استایل موازی است.
2. **زمان = `int` میکروثانیه.** هیچ `double` ثانیه‌ای مالک یک Timestamp نیست.
   ۲۹٫۹۷ و ۲۳٫۹۷۶ fps روی یک تایم‌لاین طولانی با `double` به‌سرعت از هم می‌پاشند.
3. **هسته بومی (C++) برای منطق حساس.** رمزگذار SRT/ASS، برش تایم‌لاین پس از حذف
   سکوت، VAD و «پلن کیفیت خروجی» در C++ هستند؛ همان کد روی هاست کامپایل و تست
   می‌شود و همان کد از JNI در اپ اجرا می‌شود. بنابراین چیزی که تست شده با چیزی که
   روی گوشی اجرا می‌شود یکی است.

---

## ۱. لایه‌ها و ساختار پوشه

```
subflow/
├── lib/                          # Flutter (UI + state + مدل داده) — بدون WebView
│   ├── app/                      # app.dart, router.dart, providers.dart
│   ├── core/                     # constants, errors, time_us, ids, platform/*
│   ├── database/                 # AppDatabase + DAO ها (sqflite)
│   ├── models/                   # ۹ موجودیت + enums (منبع حقیقت Dart)
│   ├── services/                 # MediaService, ProjectRepository
│   ├── features/                 # splash, onboarding, home, projects,
│   │                             # video_import, editor, settings
│   └── shared/                   # theme, widgets
├── android/app/src/main/kotlin/app/subflow/
│   ├── MainActivity.kt           # سیم‌کشی فقط
│   ├── bridge/                   # BridgeContract (قرارداد) + SubFlowBridge
│   ├── media/                    # VideoProbe, MediaPicker, PlayerViewFactory
│   └── core/NativeCore.kt        # پل JNI
├── android/app/src/main/cpp/
│   ├── core/                     # sf_time, sf_silence, sf_timeline,
│   │                             # sf_subtitle, sf_quality
│   ├── jni/sf_jni.cpp
│   └── CMakeLists.txt            # + سوئیچ SF_ENABLE_WHISPER (فاز ۲)
├── assets/
│   ├── db/                       # 001_init.sql, 002_*.sql, manifest.json
│   ├── fonts/                    # Vazirmatn (OFL) + متن مجوز
│   └── templates/
├── test/                         # تست‌های Dart (نیازمند Flutter SDK)
├── tools/                        # verify-all.sh, check-project.py,
│                                 # check_schema.py, native-core/, bootstrap-android.sh
└── docs/                         # ARCHITECTURE, DECISIONS, PHASE-*-REPORT
```

قاعده: **UI هیچ‌وقت پردازش سنگین انجام نمی‌دهد.** هر عملیات روی فایل، کدک، AI یا
رندر از طریق `NativeBridge` به Kotlin می‌رود و Kotlin آن را روی یک
`Executor`/`Dispatchers.Default` اجرا می‌کند.

---

## ۲. جریان داده

```
Photo Picker ──► MediaPicker(Kotlin) ──► VideoProbe (MediaMetadataRetriever + MediaExtractor)
                                              │
                                              ▼
                                    VideoProbeResult (Dart DTO)
                                              │
                       ProjectRepository.createFromProbe()
                                              │
                        ┌─────────────────────┴──────────────────────┐
                        ▼                                            ▼
                 projects / video_assets                       projectsController
                        (SQLite, µs)                          (Riverpod, UI)
```

فاز ۲ به همین زنجیره اضافه می‌کند:

```
ExoPlayer/Transformer ──► PCM 16k mono ──► whisper.cpp (JNI, worker thread)
        ──► tokens + timestamps ──► segments/words در SQLite ──► Editor
```

نکته مهم: فایل ویدئو **هرگز کپی یا بازکدگذاری نمی‌شود** مگر کاربر خروجی رندرشده
بخواهد. پروژه فقط URI و مشخصات فنی را نگه می‌دارد.

---

## ۳. سیاست کیفیت خروجی (قلب محصول)

منطق در `sf_quality.cpp` است و در `tools/native-core` تست می‌شود. قواعد ثابت‌شده:

| قاعده | پیاده‌سازی |
| --- | --- |
| «کیفیت اصلی» رزولوشن/نسبت/نرخ فریم را تغییر نمی‌دهد | `preset = kOriginal` ⇒ هندسه از منبع |
| بزرگ‌نمایی بدون اجازه ممنوع | اگر هدف > منبع و `allow_upscale=false` ⇒ clamp + هشدار `UPSCALE_CLAMPED` |
| Big‌نمایی با اجازه، صادقانه برچسب می‌خورد | هشدار `UPSCALE_INTERPOLATED` |
| بدون تغییر تصویر، بازکدگذاری ممنوع | `passthrough_video = true` ⇒ stream copy |
| بیت‌ریت از «پیکسل بر ثانیه» منبع محاسبه می‌شود | `bpp × w × h × fps` و کف `source × ratio × 0.85` |
| رزولوشن‌های زوج | `MakeEven()` (جلوگیری از نوار سبز یک‌پیکسلی) |
| کدک پشتیبانی‌نشده، شکست بی‌صدا نیست | `HEVC_UNAVAILABLE_H264` |
| HDR بدون حفظ، ادعا نمی‌شود | `hdr = passthrough`؛ در غیر این صورت `HDR_NOT_PRESERVED` |
| نمایش پریست‌های ناسازگار ممنوع | فقط پریست‌های ≤ منبع + گزینه اصلی نمایش داده می‌شود (فاز ۶) |
| تخمین حجم خروجی | `(v_bitrate + a_bitrate) × duration / 8` |

**صادقانه:** وقتی زیرنویس روی تصویر می‌نشیند، Encode مجدد اجتناب‌ناپذیر است و
حفظ بیت‌به‌بیت ممکن نیست. کاری که می‌کنیم: کدگذار سخت‌افزاری، عدم Resize، حفظ
نرخ فریم، بیت‌ریت ≥ منبع و جلوگیری از تبدیل چندباره. ادعای «کیفیت ۱۰۰٪ بدون
تغییر» فقط در حالت stream copy مطرح می‌شود.

---

## ۴. یکسان‌بودن Preview و Export

سه ضامن:

1. **همان مدل:** `SubtitleStyle` (Dart) ↔ `AssStyle` (C++) با mapping عددی مستقیم.
   فونت بر حسب پیکسل اسکریپت (نسبت به ضلع کوتاه ویدئو) ذخیره می‌شود، درست مثل
   `PlayResX/PlayResY` در ASS.
2. **همان متن منطقی:** متن فارسی هرگز دستی برعکس یا Pre-shape نمی‌شود. هم
   Flutter (HarfBuzz + BiDi) و هم libass با متن UTF-8 منطقی کار می‌کنند.
   ASS هیچ تگ جهت ندارد؛ اتکا به BiDi رندرکننده رفتار درست است.
3. **همان زمان‌بندی:** همه زمان‌ها µs صحیح؛ ASS با گرد کردن به سنتی‌ثانیه و SRT با
   برش به میلی‌ثانیه نوشته می‌شود (هر دو تست‌شده).

فاز ۴ یک «snapshot مشترک» اضافه می‌کند: یک `RenderSpec` (JSON) که هم overlay
پیش‌نمایش و هم Transformer می‌خوانند؛ هیچ پارامتری از UI مستقیم به رندر نمی‌رود.

---

## ۵. مدل‌های AI و صراحت درباره محدودیت‌ها

| مورد | تصمیم | دلیل |
| --- | --- | --- |
| STT | `whisper.cpp`، مدل‌های `tiny/base/small` (+medium در دستگاه قوی) | آفلاین، رایج‌ترین runtime قابل اتکا روی ARM64 |
| دانلود مدل | جدا از APK، با checksum SHA-256 | APK سبک؛ نصب فقط با تأیید کاربر |
| فارسی در `tiny` | **توصیه نمی‌شود** | دقت فارسی/انگلیسی مخلوط در tiny افت شدید دارد؛ پیش‌فرض `base`، پیشنهاد `small` برای فارسی |
| Timestamp واژه‌ای | در فاز ۷ از token timestamps و سپس refinement با انرژی صدا | Karaoke واقعی بدون آن ممکن نیست |
| ترجمه آفلاین fa↔en | موتور «قابل توسعه» با ارزیابی قبل از عرضه؛ کاندید: OPUS-MT (CC-BY-4.0) | NLLB-200 مجوز CC-BY-**NC** دارد و برای محصول تجاری مجاز نیست |
| شبیه‌سازی ترجمه | ممنوع | اگر کیفیت کافی نبود، قابلیت با برچسب «تجربی» و بدون خروجی جعلی می‌ماند |

تا زمانی که یک مدل ترجمه با کیفیت قابل قبول و مجوز مناسب تأیید نشود، دکمه
«ترجمه» در UI غیرفعال و همراه با توضیح است — نه دکمه‌ای که چیزی شبیه ترجمه
تولید کند.

---

## ۶. دیتابیس

- ۱۵ جدول: `projects`, `video_assets`, `subtitle_tracks`, `subtitle_segments`,
  `subtitle_words`, `subtitle_styles`, `subtitle_effects`, `animation_presets`,
  `watermarks`, `templates`, `translation_tracks`, `export_jobs`, `ai_models`,
  `app_settings`, `edit_history`.
- همه زمان‌ها `INTEGER` میکروثانیه؛ همه ساعت‌های دیواری `*_ms`.
- `CHECK` برای همه enum ها و برای `end_us > start_us` (یک کیوی صفر‌مدت کل
  رندرکننده را می‌شکند).
- حذف: `ON DELETE CASCADE` فقط وقتی خود پروژه حذف شود؛ در UI همیشه soft delete
  تا تأیید کاربر.
- مهاجرت‌ها فایل‌های SQL واقعی هستند (`assets/db/`), و `tools/check_schema.py`
  همین فایل‌ها را روی SQLite اجرا می‌کند و constraint ها، cascade ها و مسیر
  ارتقای v1→v2 را با داده واقعی می‌سنجد.

---

## ۷. قرارداد Dart ↔ Kotlin ↔ C++

- یک MethodChannel ثابت: `app.subflow/native`.
- نام متدها در `lib/core/constants.dart` و
  `android/.../bridge/BridgeContract.kt` تعریف شده‌اند و
  `tools/check-project.py` **هر دو طرف را تطبیق می‌دهد** (متنی که Dart صدا می‌زند
  باید در Kotlin هندل شده باشد و برعکس).
- Pigeon فعلاً استفاده نشده: تولید کد قبل از کامپایل بودن پروژه را شکننده می‌کند و
  سطح تبادل کوچک است. مسیر ارتقا در `DECISIONS.md` آمده.
- JNI: نمادها با نام کلاس Kotlin تطبیق داده می‌شوند و checker اسم‌ها را مقایسه
  می‌کند (`Java_app_subflow_core_NativeCore_nativeX`).

---

## ۸. فارسی/انگلیسی (الزام غیرقابل مذاکره)

- کل اپ `RTL` است (Material با delegateهای بومی‌سازی فارسی) و هر Track زبان و
  جهت مستقل دارد.
- `RtlText` فقط **تصمیم‌های نمایشی** می‌گیرد (تشخیص جهت، تشخیص متن مخلوط، اعداد
  فارسی برای نمایش). هیچ‌جا متن بازآرایی نمی‌شود.
- نیم‌فاصله (U+200C) حفظ می‌شود؛ Yeh/Kaf عربی در جست‌وجو به فارسی نرمال‌سازی
  می‌شود (تست‌شده در `test/rtl_text_test.dart`).
- فونت: Vazirmatn نسخه 33.003، مجوز **OFL-1.1**، فایل مجوز در
  `assets/fonts/OFL-Vazirmatn.txt`. همان فونت در ASS و در UI استفاده می‌شود.

---

## ۹. فازها و دروازه‌های پذیرش

| فاز | محتوا | دروازه پذیرش (بدون آن «تمام‌شده» اعلام نمی‌شود) |
| --- | --- | --- |
| **۱ (انجام‌شده)** | پایه فنی: Flutter+Riverpod+GoRouter، SQLite، bridge، probe، پخش Media3، هسته C++ (SRT/ASS/VAD/timeline/quality)، تم و ۷ صفحه | تست هسته بومی + تست اسکیما + checker ساختار سبز؛ APK روی دستگاه واقعی ساخته شود |
| ۲ | whisper.cpp + دانلود مدل + استخراج صدا + STT فارسی/انگلیسی/مخلوط | WER روی ۳ کلیپ فارسی واقعی گزارش شود؛ حافظه/دما روی دستگاه ضعیف |
| ۳ | ویرایشگر: متن، زمان، کلمه، split/merge، Undo/Redo، چند Track | ویرایش ۱۰۰ زیرنویس بدون افت فریم؛ Undo واقعی |
| ۴ | موتور استایل/افکت + ۳۰ قالب + پیش‌نمایش زنده | اسکرین‌شات تطبیق Preview/Export برای هر قالب |
| ۵ | واترمارک تصویری/متنی چندگانه | Overlay در پیش‌نمایش و فایل نهایی یکسان |
| ۶ | Export: MP4/SRT/ASS، پریست‌ها، کدگذار سخت‌افزاری، پیش‌نمایش خروجی | تست کیفیت روی ۷۲۰p/۱۰۸۰p/4K و ۲۴/۳۰/۶۰fps با ffprobe |
| ۷ | ترجمه، حذف سکوت، Word timing، Karaoke | کیفیت ترجمه با نمونه انسانی؛ حذف سکوت بدون drift |
| ۸ | تست دستگاه ضعیف/متوسط/قوی، APK+AAB | چک‌لیست نهایی + امضای release |

---

## ۱۰. ریسک‌های فنی (با برنامه کاهش)

| ریسک | اثر | کاهش |
| --- | --- | --- |
| whisper روی دستگاه‌های ۲–۳GB رم | Crash / OOM | مدل `tiny`/`base`، پردازش قطعه‌ای، آزادسازی مدل، محدودیت طول |
| دقت فارسی Whisper | خروجی نادرست | `base`/`small` پیش‌فرض، ارزیابی WER، امکان ویرایش سریع |
| دسترسی پایدار به URI انتخابی Photo Picker | فایل «گم‌شده» بعد از ریستارت | تلاش برای `takePersistableUriPermission`، تشخیص فایل گم‌شده و درخواست انتخاب مجدد، مسیر SAF در فاز ۶ |
| Encoder سخت‌افزاری ناسازگار | خروجی خراب | fallback نرم‌افزاری + گزارش کدک، تست روی دستگاه‌های واقعی در فاز ۶ |
| ASS و افکت‌های اختصاصی | ناهمخوانی با ادیتورهای دیگر | ASS فقط استایل‌های پشتیبانی‌شده را می‌برد؛ افکت‌های اختصاصی فقط در خروجی رندرشده یا JSON پروژه |
| تفاوت Preview/Export | شکایت اصلی کاربران | `RenderSpec` مشترک + تست تصویری هر قالب |
| مجوز مدل ترجمه | ریسک حقوقی | فقط مدل‌های OFL/CC-BY/Apache؛ NLLB-NC کنار گذاشته شد |

---

## ۱۱. آنچه در این محیط قابل تأیید نیست

این سندباکس Flutter SDK، JDK، Android SDK و دستگاه اندروید ندارد. بنابراین:
تست‌های `flutter analyze` / `flutter test`، کامپایل Kotlin، لینک NDK، پخش واقعی
ویدئو و کیفیت خروجی **در این مرحله اجرا نشده‌اند** و به‌عنوان «تأییدشده» علامت
نخورده‌اند. جزئیات دقیق در `PHASE-1-REPORT.md` آمده است.
