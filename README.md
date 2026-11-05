# Ideal — استودیوی موشن گرافی کمند

> **SubFlow** — اپلیکیشن اندروید «زیرنویس و ویرایش ویدئو با هوش مصنوعی آفلاین» در
> `subflow/`. فاز ۱ (پایه فنی)، فاز ۱٫۵ (تایپوگرافی و استایل زیرنویس) و فاز ۲
> (استودیوی زیرنویس) کامل است: ویرایش/برش/ادغام/جابه‌جایی زمان، واگرد و ازنو،
> کاراوکه کلمه‌به‌کلمه روی پخش واقعی، ذخیرهٔ اتمیک در SQLite و خروجی SRT/ASS/TXT
> بدون دست‌زدن به فایل ویدئو. نسخهٔ **۰٫۲٫۱** (hotfix): باز شدن دیتابیس روی دستگاه
> واقعی درست شد و همین مسیر حالا با SQLite واقعی در CI تست می‌شود؛
> ورود ویدئو با Photo Picker، خواندن دقیق مشخصات فایل، پخش Media3، دیتابیس SQLite
> با ۱۵ جدول، هسته C++ (SRT/ASS، VAD، برش تایم‌لاین، پلن کیفیت خروجی)، ۱۰ خانواده
> فونت OFL (۷ فارسی)، موتور افکت زیرنویس (۱۷ ورود / ۹ خروج / ۸ افکت کلمه) با ۴۰
> استایل فارسی و انگلیسی، آیکون adaptive، و گالری استایل با پیش‌نمایش زنده.
> دانلود APK: https://github.com/kamandbeauty/Ideal/releases/tag/subflow-apk-latest
> بررسی: `npm run subflow:verify` · معماری: `subflow/docs/ARCHITECTURE.md` ·
> گزارش فازها: `subflow/docs/PHASE-1-REPORT.md`، `PHASE-1.5-REPORT.md` و
> `subflow/docs/PHASE-2-REPORT.md`.
> وضعیت تأییدشده/تأییدنشده به‌تفصیل در همان گزارش‌ها آمده است — چیزی بیش از آن ادعا نمی‌شود.

> **THE ODD FILE** — سیستم تولید مستقل و انگلیسیزبانِ کانال شورتس در
> `motion/odd-file/`. قاب عمودی ۹:۱۶، تایپوگرافی ادیتوریال، بنفش الکتریک،
> ۲۵–۳۵ ثانیه. تایملاین از روی ویساور ساخته میشود (هر بیت = یک کلیپ narration)
> و رندر واقعی MP4 میدهد:
> `npm run odd-file:audio` → `npm run odd-file:sample` → `npm run odd-file:render`.
> بریف کامل: `motion/odd-file/brief.md` · نسخه فعلی:
> `motion/odd-file/exports/odd-file-1080p.mp4`.


این ریپو شامل **چهار کمپین موشن گرافی** و **زیرساخت استاندارد Agent Skills**
است. همه ویدیوها واقعاً رندر و همراه صدا تحویل شدهاند، نه استوریبرد.

---

## ۰. تازهترین: `kamand vox` — کلاژ کاغذی Vox با اسکرول پیوسته (۳۷ ثانیه)

چهارمین ویدئو **از صفر ساخته شد**: تنها دارایی تکراری، `assets/product-open.png`
(عکس رسمی ژل لیفت ابرو، بستهبندی و لوگو دستنخورده) است. باقی بصریها —
کاغذ پاره، پولاروید، نوار چسب، ماژیک قرمز، هافتون، بارکد، استامپ، گیره کاغذ،
شمارههای ادیتوریال — همگی تازه با CSS/SVG ساخته شدند؛ ویساور و بستر صوتی هم
اختصاصی همین فیلماند.

- **دوربین پیوسته:** یک سند کاغذی ۷۲۰۰px که دوربین طی ۸۸۸ فریم بدون هیچ کات
  از بالا به پایین اسکرول میکند (پارالاکس ۴ لایه + sway و زوم تدریجی).
- **همزمانی کلمهبهکلمه:** ۶۰ تکه کاغذ جداگانه، هر کدام دقیقاً در `start`
  همان کلمه از `audio/words.json` میچسبد؛ ماژیک قرمز زیرش کشیده میشود.
  زمانبندی توسط کد `nimaone/persian_tts` (`split_phrases`, `_letter_words`,
  وقفهها) + `silencedetect` روی کلیپ گوینده استخراج شده است.
- مسیر اصلی TTS همانطور که خواسته شد `generate-vo-persian-tts.py` ← `OnnxTts`
  است؛ چون وزنهای ONNX در این سندباکس در دسترس نیست، صدای تحویلی ۱۰ کلیپ
  جایگزین `voice-00` است (`audio/tts-attempt.log`). با دانلود وزنها و اجرای
  سه اسکریپت صدا، صدای اصلی بدون تغییر چیدمان جایگزین میشود.

| خروجی | توضیح |
| --- | --- |
| `motion/kamand-vox/exports/kamand-vox-4k.mp4` | 2160×3840 · 24fps · H.264 + AAC |
| `motion/kamand-vox/exports/kamand-vox-1080p.mp4` | 1080×1920، همان صدا |
| `motion/kamand-vox/stills/contact-sheet.jpg` | کانتکتشیت ۱۰ فریم |
| `motion/kamand-vox/audio/words.json` | ۶۰ تایمکد کلمه |
| `motion/kamand-vox/brief.md` | بریف کامل فارسی |

```bash
npm run kamand-vox:audio      # mix.wav + words.json
npm run kamand-vox:timeline   # timeline.js
npm run kamand-vox:sample     # ۱۰ استیل مرور
npm run kamand-vox:render     # 1080p + 4K همراه صدا
```

---

## ۱. `kamand paper` — ریل کاغذی ۳۰ ثانیهای

سومین موشن گرافی، دقیقاً با **همان استایل اسکرینشاتهای ریل مرجع**: بکگراند
کرم کاغذی، آرک خاکستری، گرید محو، بارکد، واترماک `KAMAND · MOTION 03`،
نوار پیشرفت نارنجی، **تایپوگرافی فارسی خیلی درشت مشکی + یک کلمه نارنجی
درخشان**، کارت سفید گرد، جعبه هدیه کرافت سهبعدی با روبان نارنجی و دکمه CTA
نارنجی. کاتهای سریع، پاپ الاستیک، ماسک ریویل و ریتم 120BPM.

| خروجی | توضیح |
| --- | --- |
| `motion/kamand-paper/exports/kamand-paper-4k.mp4` | 2160×3840 · 24fps · H.264 + AAC |
| `motion/kamand-paper/exports/kamand-paper-1080p.mp4` | 1080×1920، همان صدا |
| `motion/kamand-paper/stills/contact-sheet.jpg` | کانتکتشیت ۸ فریم |
| `motion/kamand-paper/index.html` | صحنه قطعی `seek(frame)` |
| `motion/kamand-paper/brief.md` | استوریبرد، پالت، صدا، مشخصات |
| `reference/reel-DfNkAVNNVBu.md` | مطالعه ریل مرجع |

ویساور ۵ خط فارسی + بستر الکترونیک 120BPM، بدون انسان/چهره/دست، بستهبندی
اصلی کمند دستنخورده. شش بیت ۵ ثانیهای: هوک ← کارت نام ← جعبه هدیه ← بدون
سفیدک ← ۳ قدم ← تیتر نهایی و CTA.

```bash
npm run kamand-paper:audio
npm run kamand-paper:sample
npm run kamand-paper:render
```

---

## ۲. کمپین دوم: `kamand eye` — تیزر ۴۵ ثانیهای

تیزر عمودی ۹:۱۶ تماماً انیمیشن، فارسی، با **محوریت تایپوگرافی جنبشی**،
صداگذاری کامل فارسی (گوینده زن ایرانی) و بستر موسیقی الکترونیک.

| خروجی | توضیح |
| --- | --- |
| `motion/kamand-eye/exports/kamand-eye-4k.mp4` | 2160×3840 · 24fps · H.264 + AAC · **با ویساور و موزیک** |
| `motion/kamand-eye/exports/kamand-eye-1080p.mp4` | نسخه سبک 1080×1920، همان صدا |
| `motion/kamand-eye/stills/contact-sheet.jpg` | کانتکتشیت ۱۰ فریم |
| `motion/kamand-eye/index.html` | صحنه قابل ویرایش، تایمline قطعی `seek(frame)` |
| `motion/kamand-eye/audio/mix.wav` | میکس نهایی ۴۵٫۵ ثانیه |
| `motion/kamand-eye/audio/vo-script.md` | اسکریپت ویساور با اعراب کامل + تایمکدها |
| `motion/kamand-eye/brief.md` | استوریبرد، مشخصات فنی و محدودیتها |

### استوریبرد (۱۰۸۰ فریم)

| صحنه | زمان | اتفاق |
| --- | --- | --- |
| 1 — Hook | 0–5s | «ابروهات؟!» میکوبد داخل کادر، کش میآید، میلرزد، به دو نیمه split میشود؛ «نامرتب؟» «بدحالت؟» «سرکش؟!» از جهتهای مختلف میآیند |
| 2 — Solution | 5–12s | موج مایع زمردی، «وقت یه تغییر قشنگه!» با ماسک ریویل، محصول با چرخش سهبعدی وارد میشود |
| 3 — Benefits | 12–25s | «کاملاً گیاهی» (برگها رشد میکنند) · «بدون سفیدک» (پودر سفید در مایع شفاف حل میشود) · «بدون ریزش» (تایپ پایدار + امواج سبز) |
| 4 — How to use | 25–37s | ۷۴ تار موی SVG کمکم مرتب میشوند، برس اسپولی از میانشان عبور میکند، ۴ کارت شمارهدار |
| 5 — Final | 37–45s | کلمات به مرکز همگرا میشوند، محصول روی پایه سنگی، متنها، لوگوریویل تمیز با حلقه طلایی |

- **فونت نمایشی:** Estedad 900/800 (مدرن فارسی، همرده Peyda ExtraBold / Morabba) + وزیرمتن برای متنهای فرعی؛ همه لوکال، بدون CDN.
- **بدون** انسان، چهره، دست، فیلم لایواکشن یا کاراکتر کارتونی.
- **بستهبندی و لوگوی اصلی کمند دستنخورده** (عکس رسمی سایت، فقط بکگراند سفید حذف شد).
- ویساور ۱۰ کلیپ با اعراب کامل برای تلفظ صحیح؛ متن روی صفحه بدون اعراب اضافی.
- **بکاند گفتار فارسی:** ریپوی [`nimaone/persian_tts`](https://github.com/nimaone/persian_tts)
  در `third_party/persian_tts/` وندور و به پایپلاین وصل شده (صدای مرجع زن
  `female_narration.wav`). وزنهای ONNX مدل (~469MB) روی HuggingFaceاند و این
  سندباکس به `huggingface.co` دسترسی ندارد، بنابراین MP4های تحویلی فعلاً با
  صدای جایگزین `voice-00` ساخته شدند؛ `third_party/persian_tts/model/README.md`
  دستور یکباره دانلود و `npm run kamand-eye:vo:persian-tts` مسیر تعویض صدا را
  دارد. نکته لایسنس: مدل پایه CC-BY-NC-4.0 است، پیش از انتشار تجاری بررسی شود.
- موزیک 120 BPM الکترونیک + افکتهای impact/riser + امضای پایانی، با ducking زیر صدا.

```bash
npm run kamand-eye:audio        # ساخت mix.wav
npm run kamand-eye:sample       # ۱۰ استیل مرور
npm run kamand-eye:render       # خروجی 1080p + 4K همراه صدا
npm run motion:preview          # پیشنمایش زنده پورت 8080
```

> **شفافسازی:** فیلم تماماً انیمیشن 2D/2.5D است (تایپوگرافی، SVG، چرخش CSS 3D،
> پلیتهای CGI و کاتاوت واقعی محصول)، نه شبیهسازی بلادرنگ سیال/مو. موزیک بهصورت
> برنامهنویسیشده سنتز شده (تراک لایسنسشده نیست) و ویساور TTS است؛ هر دو در پست
> قابل تعویضاند بدون تغییر تایمline. خروجی 4K از مستر 1080×1920 با lanczos
> آپاسکیل شده (پلیتهای منبع 768×1376اند).

---

## ۳. کمپین اول: ژل لیفت ابرو کمند (۶ صحنه، ۲۷٫۶ ثانیه)

تیزر عمودی ۹:۱۶ شش صحنهای با پلیتهای CGI فوقواقعی و عکس واقعی محصول.
مستر 4K + 1080p + دو نسخه «بدون متن» برای پستپروداکشن:

`motion/kamand-eyebrow-gel/exports/` · کانتکتشیت:
`motion/kamand-eyebrow-gel/stills/contact-sheet.jpg` · بریف:
`motion/kamand-eyebrow-gel/brief.md`.

```bash
npm run kamand:render
npm run kamand:render:no-text
```

---

## ۴. زیرساخت Agent Skills

لینک `agentskills/agentskills` **خود استاندارد** است، نه یک اسکیل قابل نصب
(`npx skills add agentskills/agentskills --list` → «No skills found»). به همین
دلیل پشتیبانی استاندارد نصب شد و اسکیل `motion-graphics` مطابق همان مشخصات
ساخته شد:

| بخش | مسیر |
| --- | --- |
| اسکیل | `.agents/skills/motion-graphics/` (+ لینک `.claude/skills/`) |
| مدیریت / اعتبارسنجی | `skills` CLI، `skills-ref` (`npm run skills:validate` → `Valid skill`) |
| راهنمای ایجنت | `AGENTS.md` |
| پیشنمایش | `scripts/preview.mjs` → پورت 8080 |

نصب اسکیل دیگر:

```bash
npx skills add <owner>/<repo> --skill <name> -a '*' -y
```

وابستگیها (`node_modules/`، `venv/`) و فریمهای میانی (`/tmp`) داخل گیت
نمیآیند؛ فقط منابع قابل ویرایش، استیلها و خروجی MP4 نگهداری میشوند.
