# Ideal — استودیوی «کتاب مصور متحرک»

> **سبک خانه از این به بعد: رقص استراسبورگ ۱۵۱۸.** کمپینهای قدیمی کمند
> پاکسازی شدن؛ فیلم ۱۵۱۸ نگه داشته شده، و موتورش به یه زیرساخت قابل
> استفادهٔ مجدد تبدیل شده تا پروژهٔ بعدی فقط با گذاشتن یه فایل ویس شروع بشه.
>
> 👉 **ویس پروژهٔ جدید رو بذار تو [`projects/next/vo/`](projects/next/vo/)**
> و بعد `npm run story:build -- next` رو اجرا کن.
>
> 🎬 **پروژهٔ فعال الان:** [`projects/austin-appelbee/`](projects/austin-appelbee/) —
> داستان واقعی پسر ۱۳ سالهای که ۴ کیلومتر تو دریای طوفانی شنا کرد. سبک ۱۵۱۸،
> دوربین نرم، زیرنویس تو محدودهٔ امن ریلز، هماهنگی کلمهبهکلمه با ویس و
> عکس واقعی شخص آخر کلیپ. نمونه:
> [`plates-contact-sheet.jpg`](projects/austin-appelbee/exports/plates-contact-sheet.jpg).

---

## شروع سریع

```bash
npm install                         # فقط بار اول: ffmpeg + chromium باندلشده

# ۱. ویس رو بذار
#    projects/next/vo/fa.wav    (+ متنش: vo/script.txt — هر خط = یک صحنه)
# ۲. بساز
npm run story:build  -- next       # تایم لاین + زیرنویس کلمهبهکلمه + میکس صدا
npm run story:stills -- next       # ۸ فریم مرور
npm run story:render -- next --fast # MP4 نهایی ۱۰۸۰×۱۹۲۰
```

متن نریشن نداری؟ `story:build` به تعداد جملههای ویس برات اسکلت
`vo/script.txt` میسازه؛ فقط پرش کن و دوباره اجرا کن.

اسم پروژه مشخصه؟ `npm run story:new -- my-story` یه پوشهٔ تازه با `vo/`
مخصوص خودش میسازه.

| دستور | کار |
| --- | --- |
| `story:new -- <slug>` | اسکلت پروژهٔ تازه |
| `story:build -- <slug>` | align (ASR) یا timeline → words → audio، پشتسرهم |
| `story:align -- <slug>` | صحنهها + SRT + تایمکد کلمهها دقیقاً از `transcript.json` |
| `story:photo-card -- <slug>` | کارت «عکس واقعی (…)» برای پایان کلیپ |
| `story:timeline -- <slug>` | صحنهها + SRT + پلان دوربین از روی سکوتهای ویس |
| `story:words -- <slug>` | تایمکد تک تک کلمهها روی انرژی صدا |
| `story:audio -- <slug>` | نریشن + درون + ضربان قلب، −14 LUFS |
| `story:stills -- <slug>` | ۸ فریم مرور |
| `story:render -- <slug> --fast` | MP4 نهایی (H.264 + AAC) |
| `--lang en` | نسخهٔ انگلیسی همان تصویر، تایم لاین/زیرنویس/صدا/MP4 جدا |

جزئیات: [`projects/README.md`](projects/README.md) ·
[`engine/README.md`](engine/README.md) · قوانین سبک: [`style/STYLE.md`](style/STYLE.md)

---

## ساختار ریپو

```
style/                 سبک خانه + نمونهٔ مرجع + تصمیمها
  STYLE.md             قوانین قطعی (پالت، گرامر پلان، تایپوگرافی، صدا)
  DECISIONS.md         دو زبان، ویس توسط کاربر، …
  reference/           ویدئو و اسکرینشاتهای نمونه
engine/                موتور مشترک، config-driven (از ۱۵۱۸ استخراج شده)
  stage.html           صحنهٔ ۹:۱۶ + دوربین نرم + زیرنویس کینتیک (محدودهٔ امن ریلز)
  timeline / words / audio / render / build / new-project .mjs
  align.py / transcribe.py / photo-card.mjs   مسیر ASR دقیق + کارت عکس واقعی
projects/              فیلمهای جدید
  austin-appelbee/     🎬 پروژهٔ فعال (ویس جدید، ۸۷ ثانیه، فارسی)
  next/                👈 آمادهٔ دریافت ویس (config + vo/ + خروجیها)
motion/
  dance-1518/          پروژهٔ مرجع تحویلشده (MP4 + SRT + ویس فا/ان)
  odd-file/            برند جداگانهٔ انگلیسی THE ODD FILE — بایگانی
  style-v3-poc/        PoC ریگ کاتاوت دوبعدی (مرجع معماری)
.agents/skills/        Agent Skills استاندارد (motion-graphics و …)
```

---

## پروژهٔ مرجع: ۱۵۱۸ — رقص استراسبورگ

| مورد | مقدار |
| --- | --- |
| خروجی | `motion/dance-1518/exports/dance-1518-1080x1920.mp4` |
| مشخصات | ۱۰۸۰×۱۹۲۰ · ۳۰fps · ۱۵۳٫۱s · ۲۰ صحنه · ۵۲ کیوی زیرنویس |
| صدا | نریشن فارسی + درون + ضربان قلب ۱٫۴۲s، −۱۳٫۵ LUFS |
| ویسها | `vo/fa.wav` (ضبطشده) · `vo/en.wav` (انگلیسی، آماده) |
| متنها | `vo/fa.txt` · `vo/en.txt` |

```bash
npm run dance:timeline
npm run dance:words
npm run dance:audio
npm run dance:render
```

**باقیمانده:** نسخهٔ انگلیسی همان تصویر (ویس و متنش آمادهست، رندر نشده).
پروژههای جدید این حالت رو بهصورت پیشفرض با `--lang en` پشتیبانی میکنن.

---

## پاکسازی انجامشده

حذف شدن (همه توی تاریخچهٔ گیت قابل برگشتن):
`motion/kamand-eye`، `motion/kamand-eyebrow-gel`، `motion/kamand-paper`،
`motion/kamand-vox`، `motion/brand-intro`، `assets/kamand/`،
`reference/reel-DfNkAVNNVBu.md`، `third_party/persian_tts/` و اسکریپتهای TTS
کمند.

نگه داشته شدن: `motion/dance-1518` (سبک خانه)، `motion/odd-file` (برند
جداگانهٔ انگلیسی، بایگانی — جزو کمپینهای کمند نبود)،
`motion/style-v3-poc` (مرجع ریگ)، و زیرساخت Agent Skills.

ویسها و متنهای پراکندهٔ ریشه جمعآوری شدن: ویس فارسی/انگلیسی و متنها الان
تو `motion/dance-1518/vo/`؛ نمونهٔ سبک و تحلیلش تو `style/`.

> نکته: `motion/dance-1518/` عمداً موتور خودش رو نگه داشت تا آرشیو قابل
> replay باشه. پروژههای **جدید** فقط از `engine/` استفاده میکنن.
