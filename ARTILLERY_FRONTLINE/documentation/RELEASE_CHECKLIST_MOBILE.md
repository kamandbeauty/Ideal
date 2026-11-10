# فهرست انتشار موبایل — ARTILLERY FRONTLINE

الگوی این سند از ایدهٔ `release-checklist` در [Claude-Code-Game-Studios](https://github.com/donchitos/claude-code-game-studios) (MIT) گرفته شده. فقط سکوی هدف این پروژه، یعنی **Android ARM64**، در آن آمده است. گواهی‌های کنسول و PC در این پروژه کاربرد ندارند و عمداً حذف شده‌اند. هیچ hook یا مجوز bash هم اضافه نشده است.

قاعده: هر مورد یا `PASS` است، یا `FAIL`، یا `NOT ASSESSED` با دلیل. مورد بدون مدرک PASS نیست.

## ۱. ساخت و بسته

| مورد | بررسی | وضعیت | مدرک |
|---|---|---|---|
| commit منبع مشخص است | `git rev-parse HEAD` و مقایسه با `delivery/BUILD-STATUS.txt` | | |
| CI سبز روی همان commit منبع | `gh run list --branch arena/40ad7d87-ideal` | | شمارهٔ اجرا |
| APK ARM64 ساخته شد | `delivery/Artillery-Frontline-arm64.apk` | | |
| AAB ARM64 ساخته شد | `delivery/Artillery-Frontline-arm64.aab` | | |
| checksum تطابق دارد | از ریشهٔ ریپو: `sha256sum -c delivery/SHA256SUMS.txt` | | |
| امضای APK (v2/v3) | `delivery/apk-signature.txt` | | |
| امضای JAR برای AAB | `delivery/aab-signature.txt` | | |
| ZIP CRC سالم است | بررسی CI در `delivery/package-validation.json` | | |
| فقط `arm64-v8a` | بررسی CI | | |
| مجوز INTERNET وجود ندارد | `delivery/package-metadata.txt` و `package-validation.json` | | |
| landscape | `package-validation.json` | | |
| min/target SDK | `minSdk 24`، `targetSdk 36`؛ AAB با override حداقل SDK 26 | | |
| بستهٔ سازگاری (فقط artifact CI) | `verify_packages.py` نیاز به فایل `Artillery-Frontline-compatibility.apk` دارد | | |

## ۲. کیفیت

| مورد | وضعیت | مدرک |
|---|---|---|
| دروازهٔ smoke پاس شده (`GATE_SMOKE.md`) | | |
| headless: `failures: 0` | | `artillery-test-results.json` |
| تصویرهای منو و HUD بازبینی شده‌اند | | `documentation/qa/*.png` |
| تست روی دستگاه ARM64 واقعی (`DEVICE_QA.md`) | `NOT ASSESSED` تا اجرا شود | |
| ذخیرهٔ پیشرفت پس از force-stop | `NOT ASSESSED` تا تست دستگاه | |
| کارایی روی دستگاه (`PERF_PROFILE.md`) | `NOT ASSESSED` تا اندازه‌گیری | |

## ۳. امضا و توزیع

| مورد | وضعیت |
|---|---|
| کلید انتشار فروشگاه | **NOT ASSESSED**؛ فعلاً کلید موقت توسعه است |
| Secrets انتشار در GitHub | تنظیم نشده یا نامشخص |
| بسته‌ها برای فروشگاه آماده‌اند | **خیر**، تا زمان امضای انتشار و تست دستگاه |

## ۴. متن فروشگاه و محتوا

| مورد | وضعیت |
|---|---|
| نام نمایشی فارسی در manifest (`توپخانهٔ خط مقدم`) | PASS |
| توضیح فروشگاه، اسکرین‌شات و آیکون بزرگ | NOT ASSESSED |
| سیاست حریم خصوصی | NOT ASSESSED؛ بازی اینترنت ندارد، اما متن رسمی ننوشته شده |
| مجوز و منبع دارایی‌ها | `ASSET_LICENSES.md` و `documentation/uploaded-infantry-provenance.md` بررسی شوند |

## ۵. نتیجهٔ نهایی

```
نتیجه: آماده برای نصب آزمایشی (APK) / آماده برای فروشگاه / نیاز به کار بیشتر
موارد NOT ASSESSED:
موارد FAIL:
```

**یادآوری:** این فهرست تأیید انتشار فروشگاهی نیست. تا زمانی که تست دستگاه و امضای انتشار کامل نشوند، گزارش‌ها نباید «آماده برای فروشگاه» بنویسند.
