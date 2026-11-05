# سند تحویل — MotionShot v1.0

این پروژه یک اپلیکیشن **کاملاً آفلاین** برای تبدیل عکس‌ها به ویدیوهای سینمایی با حرکت دوربین،
ویرایش دستی کاف‌فریم، مسیرهای منحنی، ترنزیشن و موزیک است. رابط کاربری با Flutter و
رندرر و رمبر بومی با Kotlin (OpenGL ES + MediaCodec + MediaMuxer) نوشته شده است.

## ۱. کد کجا است؟

- **رپازیتوری**: `github.com/kamandbeauty/Ideal`
- **بوش**: `arena/01e7698d-ideal`
- **کمیّت**: `baec434`

برداشتن کد روی دستگاه خودتان:

```bash
git clone https://github.com/kamandbeauty/Ideal.git
cd Ideal
git checkout arena/01e7698d-ideal
```

## ۲. ساخت APK (بر دستگاه واقعی)

پیش‌نیازها: **Flutter ≥ 3.27**، **JDK 17**، **Android SDK 35** (با `flutter doctor -v` بررسی کنید).

```bash
flutter pub get
flutter build apk --release      # خروجی: build/app/outputs/flutter-apk/app-release.apk
```

> اگر کلید امضای شخصی تنظیم نشده باشد، خروجی با کلید `debug` امضا می‌شود و روی دستگاه نصب می‌شود.
> برای انتشار در گوگل‌پلی، مراحل امضای کامل در [`RELEASE.md`](RELEASE.md) است
> (`key.properties` را بسازید؛ این فایل git-ignore شده است).

## ۳. تأیید صحت پیش از/پس از build

سه سوتِ اعتبارسنجی با **Python 3.11+** (بدون نیاز به Flutter/JDK):

```bash
cd tools/validate
pip install numpy pillow imageio-ffmpeg
python3 -m motionshot.verify     # انتظار: 3651/3651
python3 -m motionshot.portcheck  # انتظار: 32/32
python3 -m motionshot.audit      # انتظار: 95/95
```

تست‌های واحد (نیاز به Flutter و JDK دارد):

```bash
flutter test                                # شامل test/motion_path_test.dart
cd android && ./gradlew testDebugUnitTest   # شامل MotionPathConformanceTest.kt
```

اگر هر دستور خطا داد، خروجی کامل را گزارش کنید تا رفع شود.

## ۴. ساختار رپازیتوری (نمای کلی)

| مسیر | محتوا |
|---|---|
| `docs/MOTION_SPEC.md` | **منبع اصلی ریاضی** اپ (۱۲ بخش: مختصات، easing، کاف‌فریم، مسیر منحنی و…) |
| `lib/` | کل اپ Flutter (مدل‌ها، صفحات، موتور حرکت، ویرایشگرها) |
| `lib/features/motion_path/` | موتور مسیر منحنی (Dart) — لوت طول قوس، کاتل-روم، هموارسازی |
| `android/app/src/main/kotlin/` | رندرر بومی ۲۳‌فایل‌ه (OpenGL، MediaCodec، سرویس خروجی، موتور مسیر) |
| `android/app/src/test/` | تست‌های conformance بومی + بردارهای طلایی |
| `tools/validate/motionshot/` | مرجع اجرایی Python + بردارهای طلایی + سه سوتِ بالا |
| `test/golden/` | همان بردارهای طلایی برای تست‌های Dart |

## ۵. وضعیت تحویل — چه چیزی تأیید شده و چه چیزی مانده است

**تأییدشده (در محیط توسعه):**
- تمام ریاضی حرکت با 3651 چکِ مرجع Python و تطابق بیت‌به‌بیت با پورت‌های Dart/Kotlin
- پروتکل JSON بین Dart و Kotlin، نام کانال‌ها و کدهای خطا (portcheck)
- ردیابی ۹۵ نیازمندی محصول به کد واقعی (audit)
- بردارهای طلایی مسیر منحنی (۱۶ هندسه + bake + seams + uniformity + C1 + freehand + ۴۰抽取 از تولید تصادفی) که هر سه ران‌تایم باید یک‌جورشان بازتولید کنند

**کار‌ن‌شده در محیط توسعه (نیاز به دستگاه/SDK شما):**
- compile نهایی Kotlin و Dart (در محیط توسعه JDK/SDK وجود نداشت؛ کد با بررسی
  خط‌به‌خط و چک استاتیک پوشش داده شده)
- اجرای `flutter test` / `gradlew test` و build نهایی APK
- تست smoke روی دستگاه واقعی (لیست کامل در [`RELEASE.md`](RELEASE.md))

## ۶. نکات مهم طراحی (برای نگهداری)

1. **تغییر ریاضی = تغییر در سه زبان**: هر فرمولی که در `MOTION_SPEC.md` تغییر کند باید
   همزمان در `tools/validate/motionshot/*.py` (مرجع)، `lib/...` (Dart) و
   `android/.../motion/*.kt` (Kotlin) اعمال و `verify` دوباره اجرا شود تا گلدن‌ها تازه شوند.
2. **گلدن‌ها سه‌تایی دستی sync می‌شوند**:
   `tools/validate/motionshot/golden/*.json` ← `test/golden/` و `android/app/src/test/resources/`
   (portcheck خودکار این sync را چک می‌کند).
3. **ترتیب فراخوانی‌های PRNG قرارداد است**: در `generatePathProfile` / `generate_profile`
   ترتیب فراخوانی‌های `rng` را تغییر ندهید؛ کل خروجی deterministic است.
4. **آفلاین بودن خط قرمز است**: هیچ permission اینترنت/ذخیره‌ساز جدید اضافه نکنید
   (audit این مورد را چک می‌کند).
