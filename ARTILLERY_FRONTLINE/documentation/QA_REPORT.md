# گزارش بررسی — نسخهٔ فارسی/گرافیکی ARTILLERY FRONTLINE

شاخه: `arena/40ad7d87-ideal`
منبع ساخت بسته‌ها: `b1e69384aeafc26bf381f3922d1813bbe87dad57`
کامیت انتشار بسته‌ها توسط CI: `da4f3c7a73c144b8a0bece39f6f125933c0ec6a8`
اجرای موفق CI: [42576649775](https://github.com/kamandbeauty/Ideal/actions/runs/42576649775)
موتور: Godot **4.7.2 stable**

## خلاصهٔ نتیجه

- آزمون‌های headless: **۷۶۷ بررسی، ۰ شکست** در `artillery-test-results.json`.
- smoke بازی با رندر نرم‌افزاری: **۲۹ بررسی، ۰ شکست** در `documentation/qa/smoke-report.json`.
- smoke دفاع ساحلی با رندر نرم‌افزاری: **۳۵ بررسی، ۰ شکست** در `documentation/qa/coastal-smoke-report.json`.
- APK اصلی ARM64، AAB ARM64 و APK سازگاری در CI خروجی گرفته و راستی‌آزمایی شدند.
- امضای APK v2/v3 و امضای JAR فایل AAB تأیید شد؛ ARM64، CRC، افقی بودن و نبود مجوز INTERNET بررسی شد.
- تصویرهای منوی خانه، کارزار، شرح مأموریت، جنگ‌افزار، ارتقا، تنظیمات، توقف، نتایج و کارت‌های ساحلی بازبینی شدند.
- **هیچ دستگاه یا شبیه‌ساز اندروید اجرا نشده است.** این گزارش گواهی انتشار فروشگاهی یا ادعای کارایی موبایل نیست.

## بررسی‌های اجراشده

| بررسی | محل اجرا | نتیجه |
|---|---|---|
| نصب Godot با SHA-256 پین‌شده | CI | موفق |
| import پروژه و کامپایل منابع | CI headless | موفق |
| آزمون‌های واحد/یکپارچه | CI headless | **۷۶۷ / ۰** |
| smoke gameplay | CI، Xvfb/llvmpipe، Compatibility | **۲۹ / ۰** |
| smoke ساحلی | CI، Xvfb/llvmpipe، Compatibility | **۳۵ / ۰** |
| خروجی APK/AAB/Compatibility | CI | موفق |
| Prefetch و بررسی SHA-256 Gradle 8.11.1 | CI | موفق |
| امضای APK با `apksigner` | CI | v2/v3 تأیید شد |
| امضای AAB با `jarsigner` | CI | `jar verified` |
| معماری، CRC، دادهٔ پروژه، SDK، landscape، آفلاین | CI + بازرسی محلی بسته‌های ردیابی‌شده | موفق |
| SHA-256 بسته‌های ردیابی‌شده | محلی پس از انتشار | `delivery/SHA256SUMS.txt: OK` |

بستهٔ سازگاری به‌دلیل بودجهٔ snapshot در Git ردیابی نمی‌شود و فقط artifact CI است؛ راستی‌آزمایی کامل آن در CI انجام شد. برای بررسی محلیِ همهٔ بسته‌ها، ابتدا artifactهای همان اجرا را دانلود کنید و سپس `python3 ARTILLERY_FRONTLINE/tools/verify_packages.py delivery` را روی پوشه‌ای که هر سه بسته را دارد اجرا کنید.

## شواهد بصری

تصویرهای بازبینی‌شده در `documentation/qa/`:

- `menu-home.png` — خانهٔ تصویری با کلیدآرت ساحل و کارت‌های فرماندهی
- `menu-campaign.png` — نقشهٔ کارزار و پیشرفت فارسی
- `menu-briefing.png` — شرح مأموریت با پنل تمام‌عرض
- `menu-arsenal.png` — جنگ‌افزار با پنل هویتِ گسترده
- `menu-upgrades.png` — بهبودهای میدانی
- `menu-settings.png` — تنظیمات فارسی/راست‌به‌چپ
- `menu-pause.png` و `mission-results.png` — توقف/نتایج توپخانه
- `coastal-pause.png` و `coastal-results.png` — کارت‌های وسط‌چین ساحلی
- `coastal-beach.png`، `coastal-infantry.png`، `coastal-fire.png`، `coastal-explosion.png`، `coastal-weapon-reload.png`
- `battlefield.png`، `battlefield-ultra.png`، `impact_t01.png`، `impact_t03.png`

اصلاحات بصری/چیدمانی این گذر:

- پنل شرح مأموریت دیگر باریک/چپ‌چین نمی‌ماند؛ `SIZE_EXPAND_FILL` روی `PanelContainer` اعمال شد.
- کارت‌های توقف/نتیجهٔ ساحلی به‌جای گیرکردن در گوشهٔ RTL، با `CenterContainer` تمام‌صفحه وسط‌چین شدند.
- نسبت‌های نمایشی با «از» نوشته می‌شوند تا ترتیب اعداد در RTL مبهم نشود.
- آزمون یکپارچه، عرض شرح مأموریت و مرکزچین بودن/بریده‌نشدن کارت‌های ساحلی را بررسی می‌کند.

## بسته‌های اندروید

| فایل | بایت | SHA-256 |
|---|---:|---|
| `delivery/Artillery-Frontline-arm64.apk` | 55,379,236 | `ab76047438fd6421de92e0bd995cd85a4a7dd62ca25bff1400d81101bf6e99c1` |
| `delivery/Artillery-Frontline-arm64.aab` | 54,776,657 | `e05c7d1f49e7a1ee5e9ac1c62d6d147087f2001d3ec5e9be1a93df6d7e6e2a28` |
| `Artillery-Frontline-compatibility.apk`، فقط artifact CI | 55,379,236 | `c93cd6117ba6ded1c58bdbd92d69023f43df14df78eed4453cc5d4974fa93b52` |

واقعیت‌های بسته:

- APK اصلی: `com.frontline.artillery`، ARM64، min SDK 24، target SDK 36، landscape، بدون INTERNET.
- APK سازگاری: `com.frontline.artillery.compatibility`، ARM64، fallback OpenGL، همان واقعیت‌های SDK/landscape/آفلاین.
- AAB: باندل Gradle با override حداقل SDK 26؛ امضای JAR به‌صورت صریح اعمال/تأیید شد.
- نام نمایشی برنامه در manifest فارسی است: `توپخانهٔ خط مقدم`.

امضا در این اجرا: **کلید موقت توسعه**، `CN=Artillery Frontline Development, O=Frontline, C=DE`. این هویت انتشار Play نیست. گواهی self-signed و کوتاه‌مدت است؛ هشدارهای مربوطه در `jarsigner` انتظار می‌رود. نصب به‌روزرسانی‌شده از کلید موقت دیگر ممکن است شکست بخورد و حذف نصب قبلی لازم شود.

## اصلاحات مسیر ساخت/آزمون

- دانلود زندهٔ Gradle داخل export باعث شکست AAB شده بود؛ اکنون توزیع `gradle-8.11.1-bin.zip` کش/پیش‌دانلود می‌شود، SHA-256 آن با `f397b287023acdba1e9f6fc5ea72d22dd63669d59ed4a289a29b1a76eee151c6` بررسی می‌شود و `distributionUrl=file://` به wrapper داده می‌شود.
- smoke بازی برای کندی llvmpipe در حل کنترل آتش، انتظار طولانی‌تر و یک درخواست حل مجدد دارد؛ لاگ smoke نیز حفظ می‌شود.
- کارت‌های ساحلی و پنل شرح مأموریت اصلاح و با تصویر/آزمون پوشش داده شدند.

## محدودیت‌ها و اجراهای انجام‌نشده

- بدون `adb install`، تست لمس دستگاه واقعی، شبیه‌ساز، پروفایل GPU اندروید، تست حرارتی، suspend/resume، audio-focus یا force-stop save.
- بدون امضای انتشار فروشگاهی، مگر اینکه Secretهای مخزن تنظیم و CI دوباره اجرا شود.
- مدل پیاده‌نظام ارسالی طبق اجازهٔ اعلام‌شدهٔ مالک نگه داشته شده؛ این حسابرسی مستقل مجوز نیست. انگشت‌ها استخوان ندارند و دور قبضه مشت نمی‌شوند.
- اعداد کارایی CI مربوط به رستر نرم‌افزاری دسکتاپ است، نه GPU موبایل. در این اجرا gameplay حدود **10.5 FPS** و coastal حدود **10.9 FPS** روی llvmpipe گزارش شد؛ ادعای 30/60 FPS پایدار موبایل وجود ندارد.
- لاگ‌های CI هشدارهای غیرکشندهٔ teardown/صدا دارند: نبود درایور صوتی در runner و fallback به dummy، و leak بافت/منبع در خروج llvmpipe. این‌ها شکست آزمون‌ها نبودند، اما باید در QA دستگاه واقعی دوباره بررسی شوند.
