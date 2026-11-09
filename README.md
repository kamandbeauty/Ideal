# Ideal — ARTILLERY FRONTLINE

نسخهٔ فارسی و گرافیکیِ برش عمودیِ آفلاینِ توپخانه/دفاع ساحلی با Godot 4.7.2.

## دانلود بستهٔ اندرویدِ تأییدشده

منبع ساخت: `b1e69384aeafc26bf381f3922d1813bbe87dad57`
انتشار بسته‌ها توسط CI: `da4f3c7a73c144b8a0bece39f6f125933c0ec6a8`
اجرای موفق CI: [42576649775](https://github.com/kamandbeauty/Ideal/actions/runs/42576649775)

| بسته | کاربرد | لینک |
|---|---|---|
| APK اصلی ARM64 | نصب آزمایشی روی گوشی/تبلت ARM64، اندروید ۷٫۰/API 24 به بالا | [دانلود APK](https://github.com/kamandbeauty/Ideal/raw/da4f3c7a73c144b8a0bece39f6f125933c0ec6a8/delivery/Artillery-Frontline-arm64.apk) |
| AAB ARM64 | خروجی Gradle برای انتشار/Bundletool؛ نصب مستقیم نیست | [دانلود AAB](https://github.com/kamandbeauty/Ideal/raw/da4f3c7a73c144b8a0bece39f6f125933c0ec6a8/delivery/Artillery-Frontline-arm64.aab) |
| APK سازگاری OpenGL | فقط به‌صورت artifact در CI، برای دستگاه‌های بدون شروع موفق Vulkan | [artifact سازگاری](https://github.com/kamandbeauty/Ideal/actions/runs/42576649775) |

هشدار امضا: بسته‌ها با کلید موقت توسعه امضا شده‌اند، نه کلید انتشار فروشگاه. اگر نسخهٔ آزمایشی قبلی با کلید موقت دیگری نصب است، به‌روزرسانی مستقیم ممکن است شکست بخورد و حذف نصب قبلی لازم شود؛ حذف نصب می‌تواند ذخیرهٔ محلی را پاک کند.

## چه چیزی تغییر کرد

- صفحهٔ خانه و منوها با تصویرهای کلیدی، نشان فرماندهی، پلاک‌های بافت‌دار و چیدمان راست‌به‌چپ بازطراحی شدند.
- متن‌های نمایشیِ منوها، HUD، کارزار، شرح مأموریت، جنگ‌افزار، ارتقا، تنظیمات، توقف و نتایج فارسی شدند؛ اعداد نمایشی فارسی و نسبت‌ها با «از» نوشته می‌شوند.
- فونت وزیرمتن با پوشش نویسه‌های فارسی اضافه شد.
- کارت‌های توقف/نتیجهٔ دفاع ساحلی وسط‌چین شدند و عرض پنل شرح مأموریت اصلاح شد.
- مدل پیاده‌نظام ارسالی حفظ شد؛ اجازهٔ استفاده طبق اعلام مالک در `ARTILLERY_FRONTLINE/documentation/uploaded-infantry-provenance.md` ثبت شده است. این ثبت، حسابرسی مستقل مجوز نیست.

## نتیجهٔ بررسی

- آزمون‌های headless: **۷۶۷ بررسی، ۰ شکست**.
- smoke gameplay نرم‌افزاری: **۲۹ بررسی، ۰ شکست**.
- smoke ساحلی نرم‌افزاری: **۳۵ بررسی، ۰ شکست**.
- بسته‌ها در CI از نظر امضا، ARM64، CRC، افقی بودن و نبود مجوز INTERNET بررسی شدند.
- **اجرای واقعی روی دستگاه/شبیه‌ساز اندروید انجام نشده است.** کارایی موبایل ادعا نمی‌شود.

جزئیات: [`ARTILLERY_FRONTLINE/documentation/QA_REPORT.md`](ARTILLERY_FRONTLINE/documentation/QA_REPORT.md) · [`MILESTONE_REPORT.md`](MILESTONE_REPORT.md) · [`راهنمای ساخت اندروید`](ARTILLERY_FRONTLINE/documentation/BUILD_ANDROID.md)

کد و دارایی‌ها: [`ARTILLERY_FRONTLINE/`](ARTILLERY_FRONTLINE/README.md)
