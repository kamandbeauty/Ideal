# پروژهٔ بعدی 👈 ویس رو اینجا بذار

این پوشه **آمادهٔ دریافت ویس** پروژهٔ جدیده، با همون سبک «رقص استراسبورگ ۱۵۱۸».

## ۱. فقط یه کار بکن

```
projects/next/vo/     👈 فایل ویس رو اینجا بذار
```

- نام پیشنهادی: `fa.wav` (یا `en.wav` اگه انگلیسیه).
- فرمتها: `wav / mp3 / m4a / aac / ogg / flac / opus / webm` — فرقی نمیکنه، خودمون دیکود میکنیم.
- متن نریشن رو هم تو `vo/script.txt` بنویس: **هر خط = یک صحنه**. اگه متن نداری، نگران نباش: قدم بعدی بهاندازهٔ جملههای صدا اسکلت میسازه.
- برای دو زبانه: `vo/fa.wav` + `vo/en.wav` و `vo/script.en.txt`، بعد اجرا با `--lang en`.

> اگه اسم پروژه مشخص شد، یه پوشهٔ دیگه بساز: `npm run story:new -- my-story`
> و ویس رو ببر تو `projects/my-story/vo/`.

## ۲. بعدش بگو / یا خودت اجرا کن

```bash
npm install                              # فقط بار اول (ffmpeg + chromium باندلشده)
npm run story:build -- next              # تایم لاین + زیرنویس + میکس صدا
npm run story:stills -- next             # ۸ فریم مرور
npm run story:render -- next --fast      # MP4 نهایی 1080×1920
```

خروجیها:

| چی | کجا |
| --- | --- |
| تایم لاین صحنهها | `content/timeline.js` |
| زیرنویس | `subtitles/fa.srt` + `exports/next-fa.srt` |
| میکس نریشن + درون/ضربان قلب | `audio/mix.fa.wav` |
| تصویرهای نقاشیشده | `assets/plates/hd/p01.jpg`, `p02.jpg`, … |
| فیلم | `exports/next-fa-1080x1920.mp4` |

تا وقتی پلیتها رو نذاری، رندر با گرادیان جایگزین کار میکنه (فقط برای مرور،
خروجی نهایی نیست). پلان دوربین تو `content/scenes.js` قابل ویرایشه.

قوانین سبک: [`../../style/STYLE.md`](../../style/STYLE.md) · موتور: [`../../engine/README.md`](../../engine/README.md)
