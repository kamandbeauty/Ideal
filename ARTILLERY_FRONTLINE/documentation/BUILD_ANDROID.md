# ساخت و امضای اندروید

## زنجیرهٔ ابزار

- Godot 4.7.2 stable استاندارد و قالب‌های خروجی هم‌نسخه.
- JDK 17.
- Android SDK platform 36، build-tools 36.1.0 و platform-tools.
- قالب Gradle منبع Godot برای AAB؛ APKهای اصلی/سازگاری بدون Gradle هم خروجی می‌شوند.
- Gradle 8.11.1 برای AAB، با SHA-256 پین‌شده:
  `f397b287023acdba1e9f6fc5ea72d22dd63669d59ed4a289a29b1a76eee151c6`
- در این مایل‌استون فقط ARM64-v8a برای بسته‌های اصلی/سازگاری/AAB خروجی گرفته می‌شود. یک APK آزمایشی x86_64 نیز فقط به‌صورت artifact CI ساخته می‌شود.
- APKهای اصلی/سازگاری: min SDK 24، target SDK 36. AAB: override حداقل SDK 26، target SDK 36.
- Vulkan برای اندروید ۱۰/API 29 به بالا توصیه می‌شود؛ APK سازگاری OpenGL برای دستگاه‌های بدون شروع موفق Vulkan است.

## ساخت خودکار

گردش‌کار **ARTILLERY FRONTLINE** روی شاخهٔ نشست اجرا می‌شود:

1. import و کامپایل منابع.
2. آزمون‌های واحد/یکپارچهٔ headless.
3. smoke بازی با رندر نرم‌افزاری.
4. smoke دفاع ساحلی با رندر نرم‌افزاری.
5. خروجی APK اصلی، AAB و APK سازگاری.
6. امضا/تأیید امضا و بازرسی بسته‌ها.
7. انتشار APK/AAB در `delivery/` و آپلود artifactهای سازگاری/آزمایشی.

آخرین اجرای موفق این گذر: [42593105670](https://github.com/kamandbeauty/Ideal/actions/runs/42593105670).
منبع ساخت: `0ed3f189f16570476eae0b5e79a9504f166c3431`.
انتشار بسته‌ها: `6df94a4db9d514a96599ec9e8e0934a78f14533a`.

### اصلاح دانلود Gradle

export فایل AAB قبلاً به دانلود زندهٔ `gradle-8.11.1-bin.zip` توسط wrapper وابسته بود و در CI شکست خورد. اکنون گردش‌کار:

- توزیع را در `~/.cache/artillery-gradle` کش می‌کند.
- در صورت نبود/خرابی کش، ZIP را با retry دانلود می‌کند.
- SHA-256 را با مقدار پین‌شده بررسی می‌کند.
- فایل تأییدشده را به `gradle-wrapper.properties` قالب نصب‌شده با `distributionUrl=file://` معرفی می‌کند.

این کار دانلود داخل export را حذف می‌کند، ولی وابستگی به دانلود اولیهٔ GitHub release را با retry/cache مدیریت می‌کند.

## امضا

برای اعتبارسنجی توسعه، CI یک keystore موقت RSA در حافظهٔ موقت runner می‌سازد، APKها را debug-signed خروجی می‌گیرد و در صورت نیاز امضای JAR فایل AAB را با همان کلید اعمال/تأیید می‌کند. این‌ها بستهٔ آزمایشی قابل نصب‌اند، **نه هویت انتشار Play**.

برای هویت انتشار پایدار، GitHub Secrets را تنظیم کنید:

- `ARTILLERY_KEYSTORE_BASE64`
- `ARTILLERY_KEYSTORE_PASSWORD`
- `ARTILLERY_KEY_ALIAS`

گردش‌کار keystore را فقط در حافظهٔ موقت runner باز می‌کند و از متغیرهای محیطی مستند Godot استفاده می‌کند؛ سپس `--export-release` را اجرا می‌کند. هیچ keystore، رمز، `key.properties` یا مسیر SDK محلی نباید commit شود. کلید انتشار واقعی را بیرون از مخزن نگه دارید؛ از دست دادن آن، به‌روزرسانی با همان هویت امضا را ناممکن می‌کند.

هشدار نصب: اگر نسخهٔ آزمایشی قبلی با کلید موقت دیگری نصب شده، به‌روزرسانی مستقیم ممکن است شکست بخورد و حذف نصب قبلی لازم شود. حذف نصب می‌تواند ذخیرهٔ محلی را پاک کند.

## خروجی محلی

پس از نصب قالب‌های هم‌نسخه، تنظیم مسیر Java/Android SDK در Editor Settings، نصب قالب ساخت اندروید برای AAB و تنظیم امضا:

```sh
godot --headless --path ARTILLERY_FRONTLINE --export-release "Android APK" res://../delivery/Artillery-Frontline-arm64.apk
godot --headless --path ARTILLERY_FRONTLINE --export-release "Android AAB" res://../delivery/Artillery-Frontline-arm64.aab
```

برای دستگاه آزمایشی متصل:

```sh
adb install -r delivery/Artillery-Frontline-arm64.apk
```

اگر شروع Vulkan پشتیبانی نشد، از APK سازگاری استفاده کنید. این دستورات در sandbox اجرا نشدند.

گواهی‌های توسعه/آپلود اندروید معمولاً self-signed هستند؛ هشدار self-signed انتظار می‌رود، اما jar بدون امضا رد می‌شود. پس از خروجی محلی AAB همیشه اجرا کنید:

```sh
jarsigner -verify delivery/Artillery-Frontline-arm64.aab
```

## راستی‌آزمایی بسته

CI این موارد را بررسی می‌کند:

- امضای APK با `apksigner` و گزارش گواهی.
- امضای JAR فایل AAB با `jarsigner` و وجود بلوک امضای `META-INF`.
- کتابخانهٔ native موتور برای ARM64 و نبود معماری ناخواسته.
- وجود دادهٔ پروژه و CRC فایل ZIP.
- شناسهٔ بسته، min/target SDK، جهت landscape decoded و نبود مجوز INTERNET.

بستهٔ سازگاری به‌دلیل بودجهٔ snapshot در Git ردیابی نمی‌شود و فقط artifact CI است. برای راستی‌آزمایی محلیِ کامل، artifactهای همان اجرا را دانلود کنید و پوشه‌ای بسازید که هر سه بسته و گزارش‌های متنی را داشته باشد، سپس:

```sh
python3 ARTILLERY_FRONTLINE/tools/verify_packages.py delivery
```

موفقیت export، آزمون نصب نیست. QA دستگاه واقعی باید لمس، safe area، suspend/resume، throttling حرارتی، شروع Vulkan/OpenGL، audio focus، ذخیره پس از force-stop و کارایی پایدار را پوشش دهد.
