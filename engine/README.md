# engine/ — موتور مشترک «کتاب مصور متحرک»

از روی `motion/dance-1518/` استخراج شده، ولی هیچ وابستگی به اون فیلم خاص
نداره. فیلم = داده تو `projects/<slug>/`؛ موتور = این پوشه.

| فایل | کار |
| --- | --- |
| `stage.html` | صحنهٔ ۱۰۸۰×۱۹۲۰: پلیت + دوربین نرم + نور/مِه/دانه + زیرنویس کینتیک کلمهبهکلمه در محدودهٔ امن ریلز. فونتها تو `fonts/`، بافت تو `assets/grain.png` |
| `lib.mjs` | پیدا کردن پروژه، زبان، فایل ویس، متن، ffmpeg |
| `timeline.mjs` | `silencedetect` → صحنهها + کیوهای زیرنویس + SRT + پلان دوربین پیشفرض (مسیر بدون ASR) |
| `words.mjs` | دیکود صدا → پاکت انرژی ۱۰ms → تایمکد هر کلمه روی نزدیکترین درهٔ انرژی (مسیر بدون ASR) |
| `transcribe.py` | اختیاری: `faster-whisper` + مدل CTranslate2 لوکال → `content/transcript.json` با تایمستَم کلمهها |
| `align.py` | **مسیر دقیق:** تایمالاین/کیوها/کلمات/SRT مستقیم از `transcript.json`؛ جایگزین timeline+words میشه |
| `photo-card.mjs` | کارتِ کاغذی «عکس واقعی (…)» برای پایان کلیپ؛ عکس واقعی دستنخورده میمونه |
| `audio.mjs` | نریشن + درون ۵۵Hz + ضربان قلب ۱٫۴۲s + رومتون، ducking و loudnorm −14 LUFS |
| `render.mjs` | `seek(frame)` فریمبهفریم با Chromium/Playwright → H.264 + AAC |
| `build.mjs` | اگر `transcript.json` باشه: align + audio؛ وگرنه timeline + words + audio |
| `new-project.mjs` | اسکلت `projects/<slug>/` |

## اصولی که نباید شکسته بشن

1. **هیچ زمانبندی دستی نیست.** همهچیز از صدای واقعی گوینده استخراج میشه؛
   ضبط عوض بشه، کل فیلم دوباره کات میخوره. با ASR، کیوها دقیقاً روی کلمات
   ضبطشده مینشینن، نه روی تخمین انرژی.
2. **هر فریم مستقل و قطعیه.** انیمیشن CSS، `Math.random`، فونت شبکهای و
   فیلترهای متحرک ممنوع؛ فقط `transform`/`opacity` و `window.__MOTION__.seek(frame)`.
3. **یه تصویر برای هر جمله.** کات سخت، بدون ترنزیشن نرم و بدون تیتر/HUD
   روی تصویر (جز استامپ افتتاحیه و کارت عکس واقعی آخر کلیپ).
4. **زیرنویس = تایپوگرافی اصلی.** سفید بولد، دورخط تیره، حداکثر دو خط،
   کلمهٔ در حال گفتن کهربایی + خط کاراوکه. **محدودهٔ امن اینستاگرام ریلز:**
   `config.subtitle = { bottom: 430, left: 80, right: 150 }` یعنی بالاتر از
   کپشن/دکمهها و کنار ریلِ سمت راست (عکس پروفایل و دکمهٔ فالو).
5. **دوربین نرم.** `easeCamera` smootherstep (سرعت و شتاب صفر در دو سر)،
   دامنهٔ زوم کوچک، لرزش دستیِ کند و کم، بلور کات ۲٫۶px و فلاش ۰٫۱۰.
6. **صدا: سکوت موضوعه.** بستر فقط درون و ضربان قلب؛ موسیقی ملودیک نمیاد
   زیر صدا رقابت کنه. جزئیات پالت و گرامر پلان: `style/STYLE.md`.

## دستورات

```bash
npm run story:new      -- <slug> [--title "..."] [--lang fa|en]
npm run story:build    -- <slug> [--lang ...]    # align (یا timeline+words) + audio
npm run story:align    -- <slug>                 # فقط تایمالاین/کلمات/SRT دقیق
npm run story:transcribe -- <slug>              # بازسازی transcript.json (نیازمند .venv)
npm run story:photo-card -- <slug>              # کارت عکس واقعی
npm run story:timeline -- <slug> [--vo ...] [--script ...]
npm run story:words    -- <slug>
npm run story:audio    -- <slug>
npm run story:stills   -- <slug> [--lang ...]
npm run story:render   -- <slug> [--fast] [--no-audio] [--from 0 --to 30]   # ثانیه
```

همهچیز به `node_modules/@ffmpeg-installer/linux-x64/ffmpeg` و
`@sparticuz/chromium` + `playwright-core` نیاز داره → `npm install`.
`transcribe.py` فقط برای ساخت `transcript.json` لازمه؛ چون اون فایل چکاین
میشه، بقیهٔ pipeline کاملاً آفلاین و بدون مدل هم تکرارپذیره.
رندر کامل یه فیلم ۳ دقیقهای هزاران فریمه (`--fast` دانه رو وقت انکود اضافه
میکنه و سریعتره).

## توسعهٔ موتور

اگه changeای تو `stage.html` دادی، همون تغییر رو تو
`motion/dance-1518/index.html` هم در نظر بگیر (اون نسخهٔ تحویلشدهٔ ۱۵۱۸
مستقل و دستنخورده میمونه تا آرشیو قابل replay باشه).
