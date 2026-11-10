# گزارش بررسی — نسخهٔ فارسی/گرافیکی ARTILLERY FRONTLINE

شاخه: `arena/40ad7d87-ideal`
منبع ساخت بسته‌ها: `c19c81ebc48cf5aa27af5f58a1ec55b3c0c31856`
کامیت انتشار بسته‌ها توسط CI: `5988df5103fe12d3db2ee5687d85d95bd0084c2a`
اجرای موفق CI: [42774113640](https://github.com/kamandbeauty/Ideal/actions/runs/42774113640)
موتور: Godot **4.7.2 stable**

## خلاصهٔ نتیجه

- آزمون‌های headless: **۸۶۲ بررسی، ۰ شکست** در `artillery-test-results.json`.
- smoke بازی با رندر نرم‌افزاری: **۳۴ بررسی، ۰ شکست** در `documentation/qa/smoke-report.json`.
- smoke دفاع ساحلی با رندر نرم‌افزاری: **۴۳ بررسی، ۰ شکست** در `documentation/qa/coastal-smoke-report.json`.
- APK اصلی ARM64، AAB ARM64 و APK سازگاری در CI خروجی گرفته و راستی‌آزمایی شدند.
- امضای APK v2/v3 و امضای JAR فایل AAB تأیید شد؛ ARM64، CRC، افقی بودن و نبود مجوز INTERNET بررسی شد.
- تصویرهای منوی خانه، کارزار، شرح مأموریت، جنگ‌افزار، ارتقا، تنظیمات، توقف، نتایج و کارت‌های ساحلی بازبینی شدند.
- **هیچ دستگاه یا شبیه‌ساز اندروید اجرا نشده است.** این گزارش گواهی انتشار فروشگاهی یا ادعای کارایی موبایل نیست.

## بررسی‌های اجراشده

| بررسی | محل اجرا | نتیجه |
|---|---|---|
| نصب Godot با SHA-256 پین‌شده | CI | موفق |
| import پروژه و کامپایل منابع | CI headless | موفق |
| آزمون‌های واحد/یکپارچه | CI headless | **۸۳۹ / ۰** |
| smoke gameplay | CI، Xvfb/llvmpipe، Compatibility | **۳۴ / ۰** |
| smoke ساحلی | CI، Xvfb/llvmpipe، Compatibility | **۴۲ / ۰** |
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

اصلاحات این گذر:

- منو/HUD تمام‌صفحه با پس‌زمینهٔ مات؛ پنهان‌شدن جهان سه‌بعدی پشت منو و پوشش کامل کارت‌های توقف/نتیجهٔ ساحلی بیرون از safe area بررسی شد.
- سمت راست فیزیکی بودن دکمهٔ شلیک در هر دو HUD، هم در آزمون یکپارچه و هم در smoke تصویری تأیید شد. علت آینه‌شدن، اعمال RTL روی مستطیل نهایی Control بود؛ خوشه‌های مکان‌یابی‌شده جهت چیدمان فیزیکی LTR می‌گیرند، ولی ریشهٔ HUD و متن فارسی RTL می‌مانند.
- سرباز با یک اصابت بدنی از پا درمی‌آید؛ تانک با دو اصابت توپ، نفربر با یک اصابت توپ؛ نیروها داخل شناور می‌مانند تا فرود و از رمپ پیاده شوند؛ انفجار زمینی روی سطح می‌نشیند؛ جان ۶۰۰۰ کاربر، ضریب آسیب ۰٫۵۵ و تعمیر/بستهٔ هوایی با آزمون پوشش داده شدند.
- تصویرهای `menu-home.png`، `battlefield.png`، `coastal-beach.png` و `coastal-pause.png` پس از ساخت دوباره بازبینی شدند.

## بسته‌های اندروید

| فایل | بایت | SHA-256 |
|---|---:|---|
| `delivery/Artillery-Frontline-arm64.apk` | 58,327,578 | `f48452315fb7a65cbc7617a8c2085bbf2024c0125fbaa799a3bf949013710fb5` |
| `delivery/Artillery-Frontline-arm64.aab` | 57,726,613 | `b240052b21a975e29d71483d1740ee16c3bc67a72b7edd962508195a217082a4` |
| `Artillery-Frontline-compatibility.apk`، فقط artifact CI | 58,327,578 | `b85052cc96a0525f63a24eae5bbcf88b38ed65d728f0dc87e6650de79eadea1f` |

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
- اعداد کارایی CI مربوط به رستر نرم‌افزاری دسکتاپ است، نه GPU موبایل. در این اجرا gameplay حدود **18.6 FPS** و coastal حدود **13.9 FPS** روی llvmpipe گزارش شد؛ ادعای 30/60 FPS پایدار موبایل وجود ندارد.
- لاگ‌های CI هشدارهای غیرکشندهٔ teardown/صدا دارند: نبود درایور صوتی در runner و fallback به dummy، و leak بافت/منبع در خروج llvmpipe. این‌ها شکست آزمون‌ها نبودند، اما باید در QA دستگاه واقعی دوباره بررسی شوند.
