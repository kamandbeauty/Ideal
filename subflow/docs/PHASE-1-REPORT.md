# گزارش فاز ۱ — Technical Foundation

تاریخ: ۲۰۲۶-۱۱-۰۵ · وضعیت: **تکمیل‌شده در محدوده‌ای که در این محیط قابل تأیید بود**
(مرز دقیق «تأییدشده / تأییدنشده» در بخش ۵ آمده است)

---

## ۱. فایل‌های ساخته‌شده

هیچ فایل موجودی در ورک‌اسپیس تغییر داده نشده است؛ SubFlow در پوشه‌ی مستقل
`subflow/` ساخته شد تا کمپین‌های موشن‌گرافیک موجود دست‌نخورده بمانند.

| گروه | فایل‌ها | حجم |
| --- | --- | --- |
| Flutter app | ۴۸ فایل `.dart` (lib + test) | ۴٬۸۵۲ خط |
| Kotlin | ۷ فایل (bridge/media/core/MainActivity) | ۸۴۸ خط |
| C++ core | ۱۲ فایل `.h/.cpp` (۵ ماژول + JNI) | ۱٬۴۷۰ خط |
| SQL | ۲ مهاجرت + manifest | ۲۷۶ خط |
| ابزارها | verify-all, check-project, check_schema, native-core harness, bootstrap | ۱٬۱۰۸ خط |
| منابع | ۴ وزن Vazirmatn + متن مجوز OFL | ۴۹۲ KB |
| مستندات | ARCHITECTURE, DECISIONS, README, این گزارش | — |

**لیست کامل کلیدی:**

```
lib/main.dart, app/{app,router,providers}.dart
lib/core/{constants,errors,ids,logger,time_us}.dart
lib/core/platform/{contracts,native_bridge}.dart
lib/core/util/rtl_text.dart
lib/database/app_database.dart + dao/{project,media,settings,model,export}_dao.dart
lib/models/{enums,project,video_asset,subtitle,subtitle_style,watermark,export_job,ai_model}.dart
lib/services/{media_service,project_repository}.dart
lib/features/{splash,onboarding,home,projects,video_import,editor,settings}/*
lib/shared/{theme,widgets}/*
android/app/src/main/kotlin/app/subflow/{MainActivity,bridge/*,media/*,core/NativeCore}
android/app/src/main/cpp/{core/sf_time,core/sf_silence,core/sf_timeline,
                           core/sf_subtitle,core/sf_quality,jni/sf_jni,CMakeLists}
android/{settings,build,gradle.properties}.kts + app/build.gradle.kts + Manifest
assets/db/{001_init.sql,002_translation_review.sql,manifest.json}
test/{time_us,rtl_text,models,database_migrations}_test.dart
tools/{verify-all.sh,check-project.py,check_schema.py,bootstrap-android.sh,
       native-core/{Makefile,sf_test.h,test_main.cpp,stub/jni.h}}
```

## ۲. قابلیت‌های پیاده‌سازی‌شده

1. **پایه Flutter:** Material 3 دارک اختصاصی (سرمه‌ای/بنفش/آبی الکتریکی)، Riverpod،
   GoRouter، RTL کامل با بومی‌سازی فارسی، فونت Vazirmatn همراه اپ.
2. **هفت صفحه:** Splash (باز کردن DB + مسیردهی)، Onboarding (۳ اسلاید + ذخیره فلگ)،
   Home، Projects، Video Import، Editor (پیش‌نمایش)، Settings.
3. **دیتابیس:** ۱۵ جدول، مهاجرت نسخه‌دار از فایل SQL واقعی، soft delete،
   `PRAGMA foreign_keys` و WAL، DAO های تایپ‌شده.
4. **ورود ویدئو:** Photo Picker → probe واقعی (MediaMetadataRetriever +
   MediaExtractor): رزولوشن با چرخش اعمال‌شده، fps میلی‌دقت، بیت‌ریت، کدک،
   HDR از `KEY_COLOR_TRANSFER`، مشخصات صدا، حجم و نام فایل.
5. **پخش ویدئو:** Media3 ExoPlayer داخل platform view با کانال اختصاصی هر
   instance (play/pause/seek/speed/dispose + رویداد وضعیت).
6. **مدیریت پروژه:** ساخت از probe، کپی عمیق (asset, styles, tracks, segments,
   words, watermarks, effects با نگاشت شناسه‌ها)، تغییر نام، حذف نرم + بازگردانی،
   حذف دائمی با تأیید.
7. **موتور بومی:** SRT writer/parser، ASS writer با `PlayResX/Y` و mapping رنگ،
   VAD انرژی‌محور با hysteresis، `TimeMap` برای برش تایم‌لاین همه اشیای زمان‌دار،
   `PlanExport` برای سیاست کیفیت.
8. **قرارداد بومی:** MethodChannel تایپ‌شده + JNI + bridge روی Executor
   (بدون کار سنگین روی main thread) + fallback امن وقتی `.so` بارگذاری نشود.
9. **پلن خروجی در UI:** کارت «پلن خروجی کیفیت اصلی» اعداد واقعی
   `PlanExport` را نشان می‌دهد (رزولوشن، بیت‌ریت، کدک، stream-copy یا رندر، هشدارها).

## ۳. تست‌های اجراشده و نتیجه

دستور واحد: `bash subflow/tools/verify-all.sh`

| مجموعه | تعداد | نتیجه |
| --- | --- | --- |
| هسته بومی (`g++ -std=c++17 -O2 -Wall -Wextra -Wpedantic -Wshadow -Wconversion`) | ۱۲۴ assertion | ✅ 0 failure |
| همان مجموعه با **ASan + UBSan** | ۱۲۴ assertion | ✅ 0 failure (بدون memory/UB error) |
| بررسی نحوی JNI در برابر `jni.h` ساختگی | — | ✅ `jni syntax OK` |
| اسکیمای SQLite (مهاجرت، constraint، cascade، ارتقای v1→v2 با داده واقعی) | ۴۳ assertion | ✅ 0 failure |
| سازگاری ساختار پروژه (import، asset، تطبیق نام کانال Dart↔Kotlin، نمادهای JNI، CMake، ممنوعیت WebView/INTERNET، import بلااستفاده) | ۴۶۸ assertion | ✅ 0 failure |

پوشش واقعی تست هسته بومی:

- **زمان:** فرمت SRT/ASS، رفتار سانتی‌ثانیه (۱٫۹۹۵s → `0:00:02.00`)،
  drift در ۲۹٫۹۷fps برای ۳۰۰ فریم.
- **VAD:** سیگنال مصنوعی سه‌گانه (سکوت/تُن/سکوت) با تلورانس ۴۰ms، تُن خالص بدون
  سکوت، سکوت دیجیتال تکی، ورودی `null`/صفر بدون crash.
- **TimeMap:** نگاشت زمان، collapse داخل برش، حذف کامل، شکستن یک زیرنویس به دو
  تکه، حذف کلمه‌ای که داخل سکوت افتاده و clamp کلمه‌ی نیمه‌بریده.
- **SRT:** round-trip با متن فارسی و چندخطی، BOM، ورودی شلخته (LF، `.` به‌جای `,`،
  بدون ایندکس)، ورودی خراب → هشدار بدون کیوی جعلی.
- **ASS:** هدر `v4.00+`، `PlayResX/Y`، رنگ `&H0000CCFF` برای `#FFCC00`، `\N`،
  استایل هر کیو، تبدیل آکولادها، و حضور بایت‌های UTF-8 فارسی بدون تغییر.
- **پلنر کیفیت:** ۱۱ سناریو شامل 1080p، 480p (نسبت تصویر و ابعاد زوج)، 4K از
  منبع 1080p (clamp + هشدار)، پرتره 1080×1920، HEVC پشتیبانی‌نشده، تغییر fps،
  HDR، منبع نامعتبر، و 4K60.

## ۴. خطاهای رفع‌شده در همین مرحله (نمونه واقعی)

- `NormalizeRanges` با طول نامعلوم، همه برش‌ها را حذف می‌کرد → limit نامحدود.
- `ParseSrtTime` در نسخه اول با `.` و فرمت بدون میلی‌ثانیه اشتباه پارس می‌کرد →
  بازنویسی کامل و افزودن ورودی «شلخته» به تست.
- `apply_migrations` در checker، مهاجرت‌های قدیمی‌تر را دوباره اجرا می‌کرد →
  تطبیق با `PRAGMA user_version` (همان قاعده‌ای که Dart اجرا می‌کند).
- `ProjectRepository` پیش‌فرضِ throwing برای بررسی وجود فایل داشت → تزریق وابستگی.
- `num.clamp()` در Dart مقدار `num` برمی‌گرداند → `.toDouble()`.
- `CardTheme` در Flutter 3.27 به `CardThemeData` تغییر کرده → استفاده نکردیم.

## ۵. آنچه تأیید **نشده** است (و به‌عنوان تأییدشده علامت نمی‌خوریم)

این محیط Flutter SDK، Dart SDK، JDK، Android SDK/NDK و دستگاه اندروید ندارد
(دسترسی شبکه هم به `pub.dev` و `storage.googleapis.com` بسته است). بنابراین:

| مورد | وضعیت |
| --- | --- |
| `flutter analyze` / `flutter test` | ⛔ اجرا نشده — چهار فایل تست Dart نوشته شده و آماده اجراست |
| کامپایل Kotlin (Gradle/AGP) | ⛔ اجرا نشده — فقط بازبینی دستی + checker ساختاری |
| لینک NDK و ساخت `libsubflow_core.so` | ⛔ اجرا نشده — ولی همان منابع روی هاست با g++ کامپایل و تست شدند |
| ساخت APK/AAB | ⛔ اجرا نشده — `tools/bootstrap-android.sh` مسیر را آماده می‌کند |
| پخش واقعی ویدئو با Media3 | ⛔ اجرا نشده (نیازمند دستگاه) |
| دقت Whisper فارسی | ⛔ فاز ۲ است و هنوز کد اجرایی ندارد |
| کیفیت خروجی تصویر (Sharpness/Color/Audio sync) | ⛔ فاز ۶ — ادعایی مطرح نشده |
| تست 4K/HDR | ⛔ ادعایی مطرح نشده |

نتیجه: فاز ۱ از نظر **منطق قابل تست** تأیید شده و از نظر **زنجیره ساخت و اجرا روی
دستگاه** تأیید نشده است. برای اعلام نهایی باید این چهار دستور روی ماشین با
Flutter SDK اجرا شود:

```bash
cd subflow && flutter pub get && flutter analyze && flutter test
bash tools/bootstrap-android.sh && flutter build apk --release
```

## ۶. ریسک‌های باقی‌مانده

1. **سازگاری API های Media3/کتابخانه‌ها با نسخه‌های جدید** — پین شده روی
   media3 1.4.1 و AGP 8.3.2؛ ارتقا نیاز به اجرای تست دستگاه دارد.
2. **تطبیق بدون کامپایلر** — checker ساختاری جای `dart analyze` را نمی‌گیرد؛
   اولین اجرای `flutter analyze` ممکن است چند خطای تایپ کوچک نشان دهد (قابل رفع سریع).
3. **دسترسی Photo Picker** — تا فاز ۶ (مسیر SAF) احتمال «فایل گم‌شده» وجود دارد؛
   رفتار UI برای آن پیاده شده است.
4. **مدل ترجمه** — هنوز انتخاب نشده؛ کاندید OPUS-MT (CC-BY-4.0)، رد شده:
   NLLB-200 (NC).
5. **حجم مدل و رم روی دستگاه‌های ضعیف** — برنامه: `base` پیش‌فرض، `small` پیشنهادی
   برای فارسی، پردازش قطعه‌ای در فاز ۲.

## ۷. مرحله بعد (فاز ۲ — AI Engine)

1. وندور کردن `whisper.cpp` با اسکریپت `tools/fetch-whisper.sh` و فعال کردن
   `-DSF_ENABLE_WHISPER=ON` (سوئیچ CMake از قبل وجود دارد).
2. `AudioExtractor` در Kotlin: PCM 16kHz mono از Media3، به‌صورت stream (بدون
   بارگذاری کل فایل در رم).
3. `WhisperEngine` در C++ با worker thread + progress واقعی (بر اساس تعداد نمونه
   پردازش‌شده) + لغو واقعی.
4. `ModelManager`: دانلود با checksum، نصب/حذف، بررسی فضای دیسک، انتخاب پیش‌فرض
   (در همین فاز مجوز INTERNET با یک DownloadService صریح اضافه می‌شود).
5. تولید `subtitle_segments` + `subtitle_words` و نمایش در Editor با RTL درست.
6. تست روی سه کلیپ واقعی فارسی/انگلیسی/مخلوط و گزارش WER + زمان پردازش + پیک رم.
