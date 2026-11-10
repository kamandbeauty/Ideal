# دروازهٔ smoke پیش از تحویل — ARTILLERY FRONTLINE

الگوی این سند از ایدهٔ `smoke-check` در [Claude-Code-Game-Studios](https://github.com/donchitos/claude-code-game-studios) (MIT) گرفته شده و با دستورهای واقعی CI این پروژه تطبیق یافته است. هیچ hook یا مجوز bash اضافه نشده است.

## قاعده

**بیلدی که هر یک از مراحل زیر را رد کند، به تحویل QA یا بسته‌بندی APK/AAB نمی‌رود.** اگر یک بررسی اجرا نشده باشد، وضعیتش `NOT ASSESSED` است، نه `PASS`.

## ۱. مراحل و دستورها

| مرحله | دستور (از ریشهٔ ریپو) | شرط قبولی | مدرک |
|---|---|---|---|
| import و کامپایل منابع | `godot --headless --path ARTILLERY_FRONTLINE --editor --import` | بدون خطای اسکریپت یا import | `documentation/qa/import.log` |
| آزمون headless | `godot --headless --path ARTILLERY_FRONTLINE --script res://tests/run_tests.gd` | بدون شکست | `documentation/qa/tests.log`، `artillery-test-results.json` |
| گزارش آزمون | `python3 ARTILLERY_FRONTLINE/tools/check_report.py artillery-test-results.json` | `passed: true` و `failures: 0` | خروجی همین دستور |
| smoke بازی (رندر نرم‌افزاری) | `xvfb-run -a -s '-screen 0 1440x810x24' godot --path ARTILLERY_FRONTLINE --rendering-method gl_compatibility --resolution 1440x810 -- --smoke-test` | بدون شکست و تصویرهای `battlefield.png`، `menu-home.png` ساخته شوند | `documentation/qa/smoke-report.json`، `smoke.log` |
| smoke دفاع ساحلی | همان پارامترها با `-- --coastal-smoke` | `passed: true` و `failures` خالی | `documentation/qa/coastal-smoke-report.json` |

اجرای CI تنها محلی است که Godot در آن نصب و تأیید شده است. اجرای محلی بدون Godot پین‌شده، نتیجهٔ معتبر نیست.

## ۲. وضعیت‌ها

- **PASS**: دستور اجرا شد، شرط قبولی برقرار بود و مدرک ذخیره شد.
- **FAIL**: دستور اجرا شد و شرط برقرار نبود. بیلد برای QA آماده نیست.
- **NOT ASSESSED**: دستور اجرا نشد یا مدرک موجود نیست. این وضعیت موفقیت نیست و نباید به‌عنوان PASS گزارش شود.

## ۳. موارد مرزی این پروژه

- **`teardown` با llvmpipe:** در smoke ساحلی خروج Godot ممکن است کد غیر صفر بدهد و CI این را تحمل می‌کند، به شرطی که گزارش JSON قبول باشد. این اجازه، شکست گزارش را پنهان نمی‌کند.
- **smoke بازی:** شمارش بررسی‌ها ممکن است تغییر کند، چون یک شلیک دوم فقط وقتی اجرا می‌شود که شلیک اول هدف را نزند. تفاوت شمارش به‌تنهایی شکست نیست؛ `failures` باید صفر باشد.
- **دستگاه واقعی:** smoke هیچ‌وقت جای تست روی گوشی را نمی‌گیرد. تست گوشی در `DEVICE_QA.md` ثبت می‌شود و تا آن زمان در گزارش‌ها به‌عنوان `NOT ASSESSED — نیاز به دستگاه` علامت می‌خورد.

## ۴. قالب گزارش

```
تاریخ:
Commit منبع:
Commit بسته:

| مرحله | وضعیت | مدرک |
|---|---|---|
| import | | |
| headless | | |
| check_report | | |
| smoke بازی | | |
| smoke ساحلی | | |
| تست دستگاه (DEVICE_QA) | NOT ASSESSED یا PASS/FAIL | |

نتیجهٔ کلی: PASS / FAIL / NOT ASSESSED
```
