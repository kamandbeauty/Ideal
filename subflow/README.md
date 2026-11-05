# SubFlow

**Professional Offline AI Subtitle & Video Editor** — اندروید ۸+ (API 26)، ARM64-first،
بدون WebView، بدون ارسال هیچ فایل به سرور.

نسخه فعلی: **۰.۱.۰ — فاز ۱ (پایه فنی)**

---

## در یک نگاه

| بخش | وضعیت |
| --- | --- |
| ورود ویدئو (Photo Picker) + خواندن دقیق مشخصات | ✅ پیاده‌سازی‌شده |
| مدیریت پروژه (ساخت/کپی/تغییر نام/حذف نرم/بازیابی) | ✅ پیاده‌سازی‌شده |
| دیتابیس SQLite با ۱۵ جدول + مهاجرت نسخه‌دار | ✅ پیاده‌سازی‌شده و تست‌شده |
| پخش ویدئو با Media3 ExoPlayer (فایل اصلی) | ✅ پیاده‌سازی‌شده |
| موتور کیفیت خروجی + پلن رندر (C++) | ✅ پیاده‌سازی‌شده و تست‌شده |
| رمزگذار SRT/ASS + پارسر SRT (C++) | ✅ پیاده‌سازی‌شده و تست‌شده |
| VAD (تشخیص سکوت) + برش تایم‌لاین (C++) | ✅ پیاده‌سازی‌شده و تست‌شده |
| تشخیص گفتار Whisper | ⏳ فاز ۲ |
| ویرایشگر زیرنویس / استایل / افکت | ⏳ فاز ۳ و ۴ |
| واترمارک / رندر خروجی | ⏳ فاز ۵ و ۶ |
| ترجمه آفلاین | ⏳ فاز ۷ (با ارزیابی کیفیت و مجوز) |

جزئیات کامل: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · تصمیم‌ها:
[`docs/DECISIONS.md`](docs/DECISIONS.md) · گزارش فاز ۱:
[`docs/PHASE-1-REPORT.md`](docs/PHASE-1-REPORT.md)

---

## اجرای پروژه

```bash
# 1) پیش‌نیاز: Flutter 3.22+، JDK 17، Android SDK 34 + NDK 26.1
cd subflow
bash tools/bootstrap-android.sh   # gradle wrapper + local.properties + آیکون‌ها
flutter pub get
flutter run --release             # روی دستگاه/شبیه‌ساز
flutter build apk --release       # arm64-v8a + x86_64
```

> بدون `bootstrap-android.sh` هیچ فایل Kotlin/C++ بازنویسی نمی‌شود؛ اسکریپت فقط
> چیزهایی را می‌سازد که باید تولید شوند (wrapper.jar، آیکون، `local.properties`).

## بررسی‌هایی که بدون دستگاه اجرا می‌شوند

```bash
bash subflow/tools/verify-all.sh
```

خروجی انتظاری:

```
native core unit tests ........ 124 checks, 0 failure(s)     (+ ASan/UBSan)
SQLite schema ................. 43 assertions, 0 failure(s)
source tree consistency ....... 349 assertions, 0 failure(s)
ALL CHECKS PASSED
```

## تست‌های Dart

```bash
cd subflow && flutter test
```
(نیازمند Flutter SDK؛ در محیط ساخت این پروژه در دسترس نبود — در گزارش فاز ۱
صادقانه به‌عنوان «اجرا نشده» علامت خورده است.)

---

## ساختار کوتاه

```
lib/        Flutter: Riverpod + GoRouter + sqflite، ۷ صفحه فاز ۱
android/    Kotlin (bridge, probe, picker, Media3 player) + C++ core + CMake
assets/     SQL مهاجرت‌ها، فونت Vazirmatn (OFL)، قالب‌ها
tools/      verify-all.sh, check-project.py, check_schema.py, native-core/, bootstrap
docs/       معماری، تصمیم‌ها، گزارش فازها
```

## قاعده‌های غیرقابل مذاکره (چک‌شده به‌صورت خودکار)

- WebView ممنوع → `check-project.py` هر استفاده از API وب‌ویو را رد می‌کند.
- بدون مجوز INTERNET → manifest توسط checker بررسی می‌شود.
- کیوی با `end_us <= start_us` ممنوع → constraint در SQLite.
- هیچ درصد پیشرفت ساختگی: همه پیشرفت‌ها از بایت/فریم واقعی می‌آیند.
