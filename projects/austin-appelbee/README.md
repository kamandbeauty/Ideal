# آستین اپلبی — شنا تا نجات خانواده

پروژهٔ بعدی با **سبک تصویرهای رقص استراسبورگ (۱۵۱۸)**، روی ویس تازهای که
روی ریشهٔ ریپو گذاشته شد (حالا `vo/fa.wav`، ۸۷٫۰۸ ثانیه، فارسی).

داستان: پسر ۱۳ سالهای در استرالیا حدود ۴ کیلومتر در دریای طوفانی شنا میکند،
دو کیلومتر دیگر میدود تا به تلفن برسد و مادر، خواهر و برادرش بعد از نزدیک
ده ساعت نجات پیدا میکنند. منبع خبر:
[AP](https://apnews.com/article/rescue-australia-swim-boy-c191a2f24e9aa594c073faa2d8c00086) ·
[CBC](https://www.cbc.ca/news/world/australia-boy-rescues-family-9.7071962) ·
[7NEWS](https://7news.com.au/news/austin-appelbee-opens-up-on-courageous-swim-to-save-mum-siblings-swept-out-to-sea-off-wa-coast-c-21516864)

## چهچیزهایی ساخته شده

| مورد | وضعیت |
| --- | --- |
| متن پاکسازیشدهٔ نریشن (۱۷ جمله = ۱۷ صحنه) | ✅ `vo/script.txt` |
| رونوشت ASR با تایمستَم کلمهبهکلمه | ✅ `content/transcript.json` |
| تایمالاین و زیرنویس **دقیقاً هماهنگ با صدا** | ✅ `npm run story:align` |
| پلیتهای نقاشیشدهٔ ۱۵۱۸ | ✅ p01–p16 کامل (لباس/چهرهٔ امروزی یکدست) + p17 کارت عکس واقعی |
| عکس واقعی شخص در پایان (لایک و فالو) | ✅ `assets/real/` + `p17.jpg` با نوشتهٔ «عکس واقعی (آستین اپلبی)» |
| زیرنویس بالاتر، محدودهٔ امن ریلز | ✅ `config.subtitle` (`bottom: 430`, `right: 150`) |
| حرکت دوربین نرم | ✅ `engine/stage.html` (smootherstep + لرزش/بلور/زوم ملایم) |
| میکس صدا | ✅ `audio/mix.fa.wav` |

## دستورها

```bash
npm run story:build -- austin-appelbee         # align + میکس صدا
npm run story:align -- austin-appelbee          # فقط تایمالاین/زیرنویس کلمهای
npm run story:photo-card -- austin-appelbee     # کارتِ عکس واقعی → p17
npm run story:stills -- austin-appelbee         # ۸ فریم نمونه
npm run story:render -- austin-appelbee --fast  # رندر نهایی
```

با `--lang en` خروجی انگلیسی جداگانه میگیرید (فعلاً ویس انگلیسی نداریم).

## چرا زیرنویس هماهنگ است؟

`content/transcript.json` خروجی Whisper با `word_timestamps` است؛
`engine/align.py` هر خط `script.txt` را به همان segment صدا نگاشت میکند و
زمان شروع/پایان **تکتمک کلمات** را مستقیم از ویس میگیرد. هیچ تایمینگ دستی،
هیچ حدسِ انرژیصوت، هیچ درصد پیشفرضی وجود ندارد. نتیجه: ۱۷ صحنه، ۳۷ کیو،
۲۲۰ کلمه، SRT در `subtitles/fa.srt`.

## عکس واقعی

منبع و اعتبار کامل: `assets/real/SOURCE.md`. عکس **بازتولید AI نشده**؛
فقط روی کارت کاغذی سبک خانه قرار گرفته و رویش نوشته شده است.
