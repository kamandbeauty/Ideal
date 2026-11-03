# engine/ — موتور مشترک «کتاب مصور متحرک»

از روی `motion/dance-1518/` استخراج شده، ولی هیچ وابستگی به اون فیلم خاص
نداره. فیلم = داده تو `projects/<slug>/`؛ موتور = این پوشه.

| فایل | کار |
| --- | --- |
| `stage.html` | صحنهٔ ۱۰۸۰×۱۹۲۰: پلیت + دوربین آرام + نور/مِه/دانه + زیرنویس کینتیک کلمهبهکلمه. فونتها تو `fonts/`، بافت تو `assets/grain.png` |
| `lib.mjs` | پیدا کردن پروژه، زبان، فایل ویس، متن، ffmpeg |
| `timeline.mjs` | `silencedetect` → صحنهها + کیوهای زیرنویس + SRT + پلان دوربین پیشفرض |
| `words.mjs` | دیکود صدا → پاکت انرژی ۱۰ms → تایمکد هر کلمه روی نزدیکترین درهٔ انرژی |
| `audio.mjs` | نریشن + درون ۵۵Hz + ضربان قلب ۱٫۴۲s + رومتون، ducking و loudnorm −14 LUFS |
| `render.mjs` | `seek(frame)` فریمبهفریم با Chromium/Playwright → H.264 + AAC |
| `build.mjs` | timeline → words → audio، پشتسرهم |
| `new-project.mjs` | اسکلت `projects/<slug>/` |

## اصولی که نباید شکسته بشن

1. **هیچ زمانبندی دستی نیست.** همهچیز از صدای واقعی گوینده استخراج میشه؛
   ضبط عوض بشه، کل فیلم دوباره کات میخوره.
2. **هر فریم مستقل و قطعیه.** انیمیشن CSS، `Math.random`، فونت شبکهای و
   فیلترهای متحرک ممنوع؛ فقط `transform`/`opacity` و `window.__MOTION__.seek(frame)`.
3. **یه تصویر برای هر جمله.** کات سخت، ۱٫۵–۳ ثانیه، بدون ترنزیشن نرم و
   بدون تیتر/HUD روی تصویر (جز استامپ تاریخ افتتاحیه).
4. **زیرنویس = تایپوگرافی اصلی.** سفید بولد، دورخط تیره، پایین کادر،
   حداکثر دو خط، کلمهٔ در حال گفتن کهربایی + خط کاراوکه.
5. **صدا: سکوت موضوعه.** بستر فقط درون و ضربان قلب؛ موسیقی ملودیک نمیاد
   زیر صدا رقابت کنه. جزئیات پالت و گرامر پلان: `style/STYLE.md`.

## دستورات

```bash
npm run story:new     -- <slug> [--title "..."] [--lang fa|en]
npm run story:build   -- <slug> [--lang ...]     # timeline + words + audio
npm run story:timeline -- <slug> [--vo ...] [--script ...]
npm run story:words   -- <slug>
npm run story:audio   -- <slug>
npm run story:stills  -- <slug> [--lang ...]
npm run story:render  -- <slug> [--fast] [--no-audio] [--from 0 --to 30]   # ثانیه
```

همهچیز به `node_modules/@ffmpeg-installer/linux-x64/ffmpeg` و
`@sparticuz/chromium` + `playwright-core` نیاز داره → `npm install`.
رندر کامل یه فیلم ۳ دقیقهای هزاران فریمه (`--fast` دانه رو وقت انکود اضافه
میکنه و سریعتره).

## توسعهٔ موتور

اگه changeای تو `stage.html` دادی، همون تغییر رو تو
`motion/dance-1518/index.html` هم در نظر بگیر (اون نسخهٔ تحویلشدهٔ ۱۵۱۸
مستقل و دستنخورده میمونه تا آرشیو قابل replay باشه).
