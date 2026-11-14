# Ideal — Island City Builder · آیدیل — شهرساز جزیره

بازی شهرسازی سه‌بعدی برای اندروید، ساخته‌شده با **Godot 4.7**.
یک جزیرهٔ خالی را آباد می‌کنی: جاده می‌کشی، خانه و کارگاه می‌سازی، پارک و
فواره می‌گذاری و با طلا و رضایت مردم، شهر را بزرگ می‌کنی. رابط بازی فارسی
(راست‌به‌چپ) و انگلیسی است و در همان‌جا عوض می‌شود.

A 3D city builder for Android, built with **Godot 4.7**. Start with an empty
island: lay roads, raise homes and workshops, plant parks and fountains, and
grow a town with gold, people and happiness. The interface ships in Persian
(right-to-left) and English and can be switched at any time.

## در این نسخه / What is in the build

| | |
| --- | --- |
| نقشه | جزیرهٔ ۲۴×۲۴ خانه‌ای با شهرداری در مرکز |
| جاده | یک ابزار جاده که خودکار به جادهٔ راست، گوشه، سه‌راه و چهارراه تبدیل می‌شود |
| ساختمان‌ها | سه خانه (۴، ۷ و ۱۵ نفر) و کارگاه درآمدزا |
| طبیعت و خدمات | چمن، درخت، درخت بلند، پیاده‌رو و فواره برای رضایت مردم |
| اقتصاد | طلا، درآمد در ثانیه، رشد جمعیت تا ظرفیت، جریمهٔ ساختمان‌های بی‌جاده |
| هدف‌ها | ۲۰، ۵۰، ۱۰۰ و ۲۰۰ نفر؛ هر هدف پاداش طلا می‌دهد |
| ذخیره | ذخیرهٔ خودکار هر ۲۰ ثانیه و دکمهٔ ذخیره؛ ادامهٔ شهر از منو |
| زبان | فارسی (RTL) و انگلیسی، ذخیره‌شده در `user://settings.cfg` |
| صدا | موسیقی محیط و صدای ساخت، تخریب و چرخش از کیت Kenney |

## اجرا / Running

```bash
# Godot 4.7.x
godot --path .                 # بازی
godot --path . --editor        # ویرایشگر
godot --headless --path . --editor --import   # ایمپورت بدون پنجره
```

## کنترل‌ها / Controls

- **لمس/کلیک** روی زمین: ساختن ساختار انتخاب‌شده
- **کشیدن**: جابه‌جایی دوربین • **دو انگشت / چرخ ماوس**: بزرگ‌نمایی
- دکمه‌های پایین صفحه: دسته‌ها، چرخش ساختمان، تخریب، واگرد
- دکمه‌های بالا: ذخیره و بازگشت به منو

## تست / Tests

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

پوشش: جدول ساختمان‌ها و قیمت‌ها، قاعدهٔ خودچینش جاده، اقتصاد و رشد جمعیت،
اتصال جاده و شهرداری، هدف‌ها، ذخیره/بارگذاری و کامل‌بودن جدول ترجمه.
گزارش در `documentation/qa/test-results.json` نوشته می‌شود.

CI روی هر push موتور Godot را نصب می‌کند، پروژه را ایمپورت می‌کند، تست‌ها را
اجرا می‌کند و بعد **یک بازی اسکریپت‌شده زیر Xvfb** انجام می‌دهد و از منو و
شهر اسکرین‌شات می‌گیرد (`tools/smoke.tscn`)؛ خروجی به‌صورت artifact
ذخیره می‌شود. قدم بعدی، ساخت APK اندروید در همان ورک‌فلو است.

## ساختار / Layout

```
project.godot            تنظیمات پروژه، اتولودهای App و Sound
scenes/                  صحنهٔ اصلی، منو، HUD، شهر
scripts/core/            زبان (L10n)، تنظیمات (App)، صدا (Sound)
scripts/city/            دادهٔ ساختمان‌ها، وضعیت شهر، نمای شهر، دوربین، صحنه
scripts/ui/              تم، منو، HUD
assets/models/           مدل‌های GLB کیت Kenney (CC0) + بافت
assets/audio/            صداهای OGG کیت Kenney (CC0)
assets/fonts/            وزیرمتن (Vazirmatn) با مجوز OFL
tests/                   مجموعه‌تست‌های headless
tools/smoke.tscn         بازی اسکریپت‌شده و اسکرین‌شات برای CI
documentation/           طراحی و خروجی کنترل کیفیت
```

## دارایی‌ها / Assets

مدل‌ها، بافت‌ها و صداها از **Starter Kit City Builder** (Kenney) گرفته شده‌اند:
کد کیت با مجوز MIT و دارایی‌ها با CC0. متن مجوز در
[`assets/kenney/LICENSE.md`](assets/kenney/LICENSE.md) و فهرست کامل در
[`ATTRIBUTION.md`](ATTRIBUTION.md) است. فونت رابط، Vazirmatn، با مجوز SIL OFL
است (`assets/fonts/OFL.txt`).

## وضعیت / Status

نسخهٔ ۰٫۲٫۰: حلقهٔ کامل شهرسازی (ساخت، اتصال جاده، اقتصاد، رشد، هدف،
ذخیره) و تست و اسکرین‌شات در CI. جزئیات عددها و قدم‌های بعدی در
[`documentation/DESIGN.md`](documentation/DESIGN.md).
