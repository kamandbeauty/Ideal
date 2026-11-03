# projects/ — فیلمهای جدید (سبک رقص استراسبورگ)

هر پروژه یه پوشهٔ مستقله؛ موتور و استایل مشترکن (`engine/` + `style/`).
هیچ فایلی از پروژهٔ دیگه کپی نمیشه جز دادهها.

```
projects/<slug>/
├── config.json          نام، زبان، fps، طول نگه داشتن فریم آخر، ضربان قلب
├── vo/                  👈 نریشن خام + متن  (محل گذاشتن ویس)
│   ├── fa.wav
│   ├── en.wav           اختیاری — نسخهٔ دوم زبان
│   ├── script.txt       هر خط = یک صحنه
│   └── script.en.txt
├── content/
│   ├── timeline.js      ساختهشده از سکوتهای ویس (صحنهها)
│   ├── words.js         تایمکد کلمهبهکلمه روی انرژی صدا
│   ├── scenes.js        پلان دوربین + نام پلیت هر صحنه (قابل ویرایش)
│   └── scenes.auto.js   پلان پیشفرض تولیدشده
├── assets/plates/hd/    تصویرهای نقاشیشده: p01.jpg, p02.jpg, …
├── subtitles/fa.srt
├── audio/mix.fa.wav     نریشن + درون + ضربان قلب، −14 LUFS
├── exports/             MP4 + SRT تحویلی
└── stills/              فریمهای مرور
```

## شروع یه پروژهٔ تازه

```bash
npm run story:new -- my-story
# ویس رو بذار تو projects/my-story/vo/
npm run story:build -- my-story
```

پروژهٔ `next/` از قبل ساخته شده و **آمادهٔ دریافت ویس** هست — اگه اسم
پروژه هنوز معلوم نیست، مستقیم بریز تو `projects/next/vo/`.

## دو زبانه (FA + EN)

یک تصویر، دو تایم لاین جدا (تصمیم ثبتشده تو `style/DECISIONS.md`):

```bash
npm run story:build  -- my-story --lang fa
npm run story:build  -- my-story --lang en
npm run story:render -- my-story --lang fa --fast
npm run story:render -- my-story --lang en --fast
```

هر زبان `timeline.<lang>.js`، `words.<lang>.js`، `<lang>.srt`،
`mix.<lang>.wav` و `<slug>-<lang>-1080x1920.mp4` خودش رو میسازه؛ هیچ
زبانی فشرده یا کشیده نمیشه.
