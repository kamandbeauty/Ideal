# پروژهٔ Ideal — نسخهٔ فارسی

ترجمه و انتشارِ **نسخهٔ فارسی** از PDFهای نخستِ کانال
[t.me/tkppktkppk](https://t.me/tkppktkppk) با تایپوگرافی حرفه‌ای و فونتِ
**وزیرمتن** (Vazirmatn — [OFL](fonts/vazirmatn/OFL.txt)).

> ⚠️ کپی‌رایت: محتوای آن کانال حاوی آثاری است که تحت کپی‌رایت هستند.
> انتشار/توزیعِ نسخهٔ فارسی باید با اجازهٔ صاحب اثر باشد؛ طبق گفتهٔ مالک این
> ریپو، مجوز لازم برای ترجمه و انتشار وجود دارد. این ریپو برای همان استفادهٔ
> مجاز تنظیم شده است.

## وضعیت فعلی

- ریپو (که قبلاً میزبان بازیِ `LAST WALL: Zombie Siege` بود) طبق درخواست
  خالی شد؛ محتوای قبلی در تاریخچهٔ git (شاخهٔ `main`) محفوظ است.
- خطِ لولهٔ ساخت PDF آماده و آزموده شده: راست‌به‌چپِ کامل، شکل‌دهی HarfBuzz،
  تراز کامل (Justify)، فهرست مطالب خودکار با شمارهٔ صفحهٔ درست، جلد حرفه‌ای،
  سرصفحه/پاورقی با ارقام فارسی.
- نمونهٔ قالب ساخته شده: [`output/sample-template-fa.pdf`](output/sample-template-fa.pdf)

**⏳ گام باقیمانده برای دو PDF نهایی:** فایل‌های PDF اصلیِ کانال در این
محیط قابل دانلود نیستند (تلگرام از اینجا در دسترس نیست و پیش‌نمایش وب فقط
صفحهٔ کانال را نشان می‌دهد). لطفاً فایل‌های اصلی را در پوشهٔ
`source-pdfs/` قرار بده (یا در چت پیوست کن) تا متن فارسی
نوشته و دو PDF نهایی ساخته شود.

## ساخت PDF نمونه

```bash
python3 pipeline/bootstrap.py                                   # یک‌بار: ساخت venv و نصب وابستگی‌ها
.venv/bin/python pipeline/build.py examples/sample.md output/sample-template-fa.pdf --toc
```

## ساخت PDF برای یک کتاب

۱. فایل ترجمه‌شده را مانند `examples/sample.md` بنویس (با `@title:` و بقیهٔ
سربرگ‌ها؛ مارک‌داون ساده: `#` عنوان، `**ضخیم**`، `-` فهرست، `>` نقل‌قول،
جدول با `|`، بلوک کد با ` ``` `، `[TOC]` برای فهرست، `---` برای وداع صفحهٔ جدید).

۲. بساز:

```bash
.venv/bin/python pipeline/build.py books/<نام>/fa.md output/<نام>-fa.pdf --toc
```

## ساختار

| مسیر | کارکرد |
| --- | --- |
| `pipeline/fa_pdf.py` | موتور تایپ‌سازی (HarfBuzz، چیدمان RTL دستی، جلد، فهرست خودکار) |
| `pipeline/build.py` | رابط خط فرمان؛ ساخت دو‌مرحله‌ایِ فهرست (نقطه‌ی ثابتِ شماره‌صفحه) |
| `pipeline/vendor/rlbidi.py` | شیم محلیِ `rlbidi` برای ReportLab (روی PyPI نیست) |
| `pipeline/bootstrap.py` | ساخت محیط و نصب وابستگی‌ها |
| `fonts/vazirmatn/` | فونت وزیرمتن (۹ وزن) + مجوز OFL |
| `examples/sample.md` | نمونهٔ ورودی |
| `output/` | PDFهای ساخته‌شده |
| `source-pdfs/` | PDFهای اصلی (در گیت نگه‌داری نمی‌شوند) |

## محدودیت‌های شناخته‌شده

- کپی/جستجو در PDF ساخته‌شده به خوبی متن منطقی کار نمی‌کند (استخراج به
  حروف شکل‌داده‌شدهٔ یونیکد برمی‌گردد، نه حروف پایه)؛ کیفیت بصری کامل است.
- در بلوک کد، متن لاتین و فارسی چسبیـده به هم (بدون فاصله) به‌صورت runهای
  جدا رسم می‌شود؛ بهتر است کُد رالاتین بنویسی.
- پیچیدهٔ‌های فارسیِ خیلی بلند بدون فاصله، شکست نمی‌خورند (سطر ممکن است
  سرریز شود).

## English (short)

This repo hosts the **Persian (Farsi) editions** of the first two PDFs from
the Telegram channel `t.me/tkppktkppk`, typeset with the open-source
**Vazirmatn** font (SIL OFL). The previous game project was emptied on
request; its content remains in git history (`main`). The typesetting engine
(`pipeline/`) does full RTL layout with HarfBuzz shaping, justified text,
auto table of contents with correct page numbers, and a professionally
designed violet/gold cover. The English source PDFs cannot be fetched from
this environment — drop them into `source-pdfs/` and the two final Persian
PDFs will be built into `output/`.

Copyright notice: the channel's content is copyrighted material; redistribution
requires the rights holder's permission (the repo owner states it is granted
for this use).
