# Agent instructions — Ideal workspace

## سبک خانه (قانون اول)

**همهٔ ویدیوهای جدید با سبک «رقص استراسبورگ ۱۵۱۸ / کتاب مصور متحرک» ساخته
میشن.** قبل از هر کار تصویری [`style/STYLE.md`](style/STYLE.md) رو کامل بخون،
و [`engine/README.md`](engine/README.md) رو برای معماری موتور.

- پروژههای جدید **فقط** تو `projects/<slug>/` ساخته میشن و از `engine/`
  استفاده میکنن. `motion/dance-1518/` آرشیو تحویلشدهست — دستش نزن (موتور
  خودشو داره که باید قابل replay بمونه).
- `motion/odd-file/` برند جداگانهٔ انگلیسی و بایگانیه؛ جزو کارهای جدید نیست،
  ولی حذف/تغییر هم نشه مگر اینکه کاربر صریحاً بگه.
- کمپینهای کمند حذف شدن؛ اسامیشون (`kamand-*`, `assets/kamand`, TTS فارسی)
  نباید دوباره وارد ریپو بشن.

## ورودی پروژهٔ جدید

```
projects/<slug>/vo/     ← ویس ضبطشده کاربر (fa.wav / en.wav / mp3 / …)
projects/<slug>/vo/script.txt     ← متن، هر خط = یک صحنه
projects/<slug>/assets/plates/hd/ ← پلیتهای نقاشیشدة p01.jpg, p02.jpg …
```

`projects/next/` از قبل آمادست؛ اگه کاربر گفت «ویس رو گذاشتم»، اول اونجا رو
چک کن. **از TTS استفاده نکن** — ویس حتماً ضبط واقعی کاربره.

```bash
npm install                          # ffmpeg + chromium باندلشده
npm run story:new -- <slug>           # پروژهٔ تازه
npm run story:build -- <slug>         # timeline → words → audio
npm run story:stills -- <slug>        # فریمهای مرور
npm run story:render -- <slug> --fast # MP4 نهایی
npm run story:build -- <slug> --lang en   # نسخهٔ دوم زبان
```

ترتیب واجب: `timeline` قبل `words`، `words` قبل `audio`، `audio` قبل `render`.
اگه ویس عوض شد، کل زنجیره رو دوباره اجرا کن — هیچ زمانبندی دستی وجود نداره.

## قوانین موتور (نشکن)

1. هر فریم `window.__MOTION__.seek(frame)`؛ انیمیشن CSS، `Math.random`،
   فونت/CDN شبکهای و فیلترهای متحرک ممنوع. فقط `transform`/`opacity`.
2. یک تصویر نقاشیشده برای هر جمله، کات سخت ۱٫۵–۳ ثانیه؛ بدون ترنزیشن نرم،
   بدون تیتر/لوگو/HUD (جز استامپ تاریخ افتتاحیه).
3. تایپوگرافی = فقط زیرنویس؛ فارسی RTL با وزیرمتن، انگلیسی LTR. کلمهٔ
   درحالگفتن کهربایی + خط کاراوکه.
4. صدا: درون + ضربان قلب ۱٫۴۲s + رومتون، ducking زیر ویس، −14 LUFS.
   موسیقی ملودیک نیار.
5. پالت گرم/خاکی، بافت کاغذ، نور شمع، وینیت. رنگ نئونی ممنوع.
6. خروجیها (SRT، `mix.<lang>.wav`، MP4، ویس، پلیتها) تو گیت بمونن؛ فقط
   فریمهای میانی `/tmp` و `frames/` نگهداری نشن.

## Installed skills

Skills تو `.agents/skills/` (استاندارد Agent Skills)؛ لینک
`.claude/skills/motion-graphics` همون اسکیل رو برای کلاینتهای دیگه قابل
کشف میکنه.

| Skill | کی فعال بشه |
| --- | --- |
| `motion-graphics` | درخواست موشن گرافی/انیمیشن/تیتر متحرک — ولی برای فیلمهای داستانی این ریپو، مسیر `engine/` اولویت داره |
| `ip-character-builder` | ساخت پک شخصیت ثابت برای پلیتهای نقاشیشده |
| `spine-animation` | فقط اگه کاربر صریحاً ریگ Spine خواست |

پیشنمایش زنده: `npm run motion:preview` (پورت ۸۰۸۰، bind روی 0.0.0.0).
اعتبارسنجی اسکیلها: `npm run skills:validate`.
