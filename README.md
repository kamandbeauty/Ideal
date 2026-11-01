# Ideal — استودیوی موشن گرافی کمند

این ریپو دو بخش دارد: **کمپین فعلی ژل لیفت ابرو کمند** و **زیرساخت Agent Skills**
که مرحله قبل نصب شد.

---

## ۱. کمپین فعلی: KAMAND Eyebrow Lift Gel

تیزر عمودی ۹:۱۶، شش صحنه، با خروجی **4K (2160×3840)** ساخته شده است
(مستر 1080×1920 با آپاسکیل lanczos؛ پلیتهای منبع 768×1376 هستند).
هیچ انسان، چهره، پوست، دست یا بخشی از بدن در هیچ فریمی وجود ندارد؛ همهچیز
از بستهبندی واقعی محصول، پلیتهای CGI گیاهی/شیشهای/طلایی و انیمیشن فریمبهفریم
ساخته شده است.

### خروجیها

| فایل | توضیح |
| --- | --- |
| `motion/kamand-eyebrow-gel/exports/kamand-eyebrow-gel-4k.mp4` | مستر 2160×3840، 24fps، H.264 |
| `motion/kamand-eyebrow-gel/exports/kamand-eyebrow-gel-1080p.mp4` | نسخه سبک 1080×1920 |
| `motion/kamand-eyebrow-gel/exports/kamand-eyebrow-gel-4k-no-text.mp4` | مستر تمیز بدون هیچ متن/کارت شمارهدار |
| `motion/kamand-eyebrow-gel/exports/kamand-eyebrow-gel-1080p-no-text.mp4` | نسخه سبک مستر تمیز |
| `motion/kamand-eyebrow-gel/stills/contact-sheet.jpg` | کانتکتشیت شش صحنه |
| `motion/kamand-eyebrow-gel/stills/s1.jpg … s6.jpg` | استیل هر صحنه |
| `motion/kamand-eyebrow-gel/index.html` | صحنه قابل ویرایش، تایمline قطعی `seek(frame)` |
| `motion/kamand-eyebrow-gel/brief.md` | بریف، بیتشیت و متنهای فارسی |

### نقشه صحنهها (جمعاً ۶۶۲ فریم ≈ ۲۷٫۶ ثانیه)

| # | صحنه | فریمها | متن فارسی |
| --- | --- | --- | --- |
| 1 | Product Reveal — استیج بژ/زمردی، محصول شناور، برگها و قطرات | 0–108 | ژل لیفت ابرو کمند · کاملاً گیاهی |
| 2 | Botanical Formula — عصارهها، قطرات، ذرات درخشان | 94–202 | کاملاً گیاهی · بدون ریزش |
| 3 | No White Residue — ژل شفاف روی شیشه، محو شدن ذرات سفید | 188–296 | بدون سفیدک |
| 4 | Natural Styling — مجسمه تاربهتار ابرو + برس اسپولی | 282–402 | حالتدهی طبیعی و زیبا |
| 5 | How to Use — ۵ مرحله شمارهدار سهبعدی | 388–544 | استفاده آسان، نتیجه جذاب |
| 6 | Final Hero — پایه سنگی، برگها، ذرات طلایی، اوربیت آرام | 530–662 | «کمند؛ زیبایی طبیعی ابروها» |

بین صحنهها ۱۴ فریم کراسفید + یک sweep نوری وجود دارد.

### متن فارسی (لایه جدا برای پستپروداکشن)

تمام متنهای درخواستی در ویدیو هستند، ولی در لایه `.copy` جدا نگه داشته شدهاند:
`ژل لیفت ابرو کمند` · `کاملاً گیاهی` · `بدون سفیدک` · `بدون ریزش` ·
`حالتدهی طبیعی و زیبا` · `استفاده آسان، نتیجه جذاب` ·
`«کمند؛ زیبایی طبیعی ابروها»`.

برای تحویل **مستر تمیز بدون هیچ اورلی** (متنها و کارتهای شمارهدار در
پستپروداکشن اضافه شوند):

```bash
npm run kamand:render:no-text      # → exports/*-no-text.mp4
# یا در مرورگر: index.html?frame=120&noText=1
```

### بستهبندی و لوگوی اصلی — بدون تغییر

عکسهای محصول مستقیماً از سایت رسمی
[kamandbeauty.com](https://kamandbeauty.com/shop/cosmetic/eyebrow-cosmetics/eyebrow-lift-gel/kamand-eyebrow-lift-gel/)
گرفته شدهاند (ظرف گرد سفید، درپوش با لوگوی `K Kamand`، ژل شفاف و برس قرمز).
هیچ بستهبندی، لوگو یا تایپوگرافی جدیدی طراحی نشده است؛ فقط بکگراند سفید با
`scripts/make-cutout.py` حذف و همان پیکسلها روی پلیتها کامپوزیت شدهاند.
فایلها در `assets/kamand/` (اصلی) و
`motion/kamand-eyebrow-gel/assets/` (کپی self-contained صحنه) هستند.

### مشخصات فنی

- طراحی و کپچر روی `1080×1920`، آپاسکیل `lanczos + unsharp` → **2160×3840 (4K)**
  (پلیتهای CGI منبع 768×1376 هستند، بنابراین جزئیات نیتیو 4K وجود ندارد)
- `24 fps`، ۶۶۲ فریم، `H.264 / yuv420p / CRF 20 / +faststart`، بدون صدا
- فونت فارسی **وزیرمتن** (Vazirmatn) بهصورت لوکال، بدون وابستگی شبکه
- انیمیشن کاملاً قطعی: هر فریم فقط از شماره فریم محاسبه میشود
  (`window.__MOTION__.seek(frame)`)؛ هیچ `setTimeout`، `rAF`، `Math.random()`
  زنده یا CDN در رندر وجود ندارد
- رندر بدون نیاز به نصب سیستمی: Chromium همراه `@sparticuz/chromium`،
  ffmpeg همراه `@ffmpeg-installer/linux-x64`

### دستورات

```bash
npm install
python3 -m pip install -r requirements-dev.txt   # skills-ref + Pillow

npm run kamand:sample          # ۶ استیل مرور سریع (۱۰۸۰×۱۹۲۰)
npm run kamand:render          # مستر 4K + نسخه 1080p
npm run kamand:render:no-text  # مستر بدون لایه متن
npm run motion:preview         # پیشنمایش زنده روی پورت 8080
python3 scripts/make-contact-sheet.py
```

> **شفافسازی:** این یک موشن گرافیک **۲٫۵بعدی سینمایی** است: پلیتهای CGI
> فوقواقعی (تولیدشده با هوش مصنوعی) + کامپوزیت عکس واقعی محصول + انیمیشن
> فریمبهفریم دوربین، پارالاکس، ذرات و نور. مواردی که بهصورت «پلیت + افکت»
> شبیهسازی شدند (نه شبیهسازی بلادرنگ): سیال ژل، پخش شدن ژل روی شیشه،
> حرکت فیزیکی برس لابهلای تارها، لیفت شدن تکتک موها و اوربیت واقعی
> دوربین سهبعدی. برای آن سطح، مرحله بعد انتقال صحنهها به
> Blender / Remotion + Three.js است؛ ساختار `seek(frame)` و بریف اینجا
> همان نقشه راه را نگه میدارد.

---

## ۲. زیرساخت Agent Skills (مرحله قبل)

لینک `agentskills/agentskills` **خود استاندارد** است، نه یک اسکیل قابل نصب
(`npx skills add agentskills/agentskills --list` → «No skills found»). برای
همین پشتیبانی استاندارد نصب شد و یک اسکیل `motion-graphics` مطابق همان
مشخصات ساخته شد:

| بخش | مسیر |
| --- | --- |
| اسکیل | `.agents/skills/motion-graphics/` (+ لینک `.claude/skills/`) |
| مدیریت و اعتبارسنجی | `package.json` → `skills` CLI، `requirements-dev.txt` → `skills-ref` |
| اعتبارسنجی | `npm run skills:validate` → `Valid skill` |
| راهنمای ایجنت | `AGENTS.md` |
| پیشنمایش | `scripts/preview.mjs` → پورت 8080 |

اسکیل شامل `SKILL.md`، منابع `motion-design / stacks / rendering`، قالب
`starter.html` و اسکریپتهای `new-motion` و `render` است. مستندات کاملتر
در `AGENTS.md` و `.agents/skills/motion-graphics/SKILL.md`.

نصب اسکیل دیگر:

```bash
npx skills add <owner>/<repo> --skill <name> -a '*' -y
```

فایلهای حجیم (`node_modules/`، فریمهای میانی در `/tmp`، `out/`) داخل گیت
نمیآیند؛ فقط منابع قابل ویرایش، استیلها و خروجی MP4 نگهداری میشوند.
