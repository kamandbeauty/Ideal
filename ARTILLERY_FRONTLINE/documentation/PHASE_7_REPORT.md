# گزارش فاز ۷ — پایداری و آمادگی انتشار

> **English at a glance.** Phase 7 is technical stabilisation of LAST WALL
> 0.6.1, not a new level. The graphics governor now writes
> `viewport.scaling_3d_scale` whenever `render_scale` moves (bilinear only;
> MSAA is bound once so the mobile renderer does not tear). New tests
> (`test_governor.gd`, `test_playthrough.gd`) assert the real buffer and a
> title-to-victory play of stage 1. Combat one-shots are silenced on the
> way back to the menu. **Godot was not run in this workspace. No Android
> device was used.** CI must still import, test, smoke, and export.
> Store release is blocked until a phone run and a production keystore.

فاز ۷ پایدارسازی است، نه مرحلهٔ تازه. طراحی اول‌شخص، شهر، اسلحه، زامبی،
کارزار و UI همان است.

## ۱. خلاصه

| خواسته | وضعیت | شواهد |
| --- | --- | --- |
| گاورنر واقعاً رزولوشن سه‌بعدی را عوض کند | کد نوشته شد؛ تست آماده است | `graphics_manager.gd`, `test_governor.gd` |
| بازی واقعی از عنوان تا پیروزی | تست یکپارچه از `main.tscn` | `test_playthrough.gd` |
| روی گوشی | ✘ انجام نشده | `ANDROID_DEVICE_TEST.md` |
| صدا و توازن | پاکسازی one-shot؛ آسیب عوض نشده | بخش ۴ |
| بستهٔ اندروید | شناسه، آیکون، نسخه ۰٫۶٫۱ / کد ۷ | `export_presets.cfg` |
| اجرای Godot / CI در این محیط | ✘ موتور اینجا نیست | بخش ۶ |

**آمادگی انتشار فروشگاهی: خیر.** امضا در CI بدون secret موقتی است؛ هیچ
اندازه‌گیری‌ای روی سخت‌افزار واقعی نیست.

## ۲. فاز ۱ — گاورنر گرافیک

### مسئله

`Graphics.render_scale` عوض می‌شد ولی `_set_scale` دیگر
`viewport.scaling_3d_scale` را نمی‌نوشت (`viewport_committed`). روی گوشی
بافر ۳بعدی همان اندازهٔ اول می‌ماند. علت قفل قبلی این بود که عوض کردن
MSAA و scale با هم روی رندر موبایل تصویر را پاره یا سیاه می‌کرد.

### ریشه

یک پرچم برای «بافر یک‌بار بسته شد» هم scale و هم MSAA را قفل می‌کرد.
Scale دوطرفه (bilinear) همان API رزولوشن پویای Godot 4 است؛ MSAA بافر را
از نو می‌سازد.

### اصلاح

فایل: `scripts/graphics/graphics_manager.gd`

- Scale هر بار که گاورنر یا کیفیت دستی عوض شود روی ویوپورت نوشته می‌شود
  (`_write_scale` / `_sync_viewport`).
- حالت همیشه `SCALING_3D_MODE_BILINEAR` است (نه FSR).
- MSAA فقط بار اول بسته می‌شود (`msaa_committed`).
- `buffer_scale()` خودِ ویوپورت را می‌خواند، نه متغیر.

کیفیت دستی low / medium / high همان scale پروفایل را اعمال می‌کند.
`auto` همچنان گاورنر است.

### تست

- `tests/unit/test_governor.gd` — هر تیِر بافر واقعی را به 0.7 / 0.85 / 1.0
  می‌برد؛ یک گام گاورنر `viewport.scaling_3d_scale == render_scale` است؛
  MSAA بعد از commit عوض نمی‌شود.
- `tests/unit/test_polish.gd` — ادعای قبلی «کیفیت بافر را عوض نکند»
  برداشته شد؛ حالا باید عوض شود.

**روی گوشی ثابت نشده** که نوشتن bilinear scale پاره نمی‌کند. اگر پاره
کرد، همان فرم دستگاه را پر کنید.

## ۳. فاز ۲ — اعتبارسنجی گیم‌پلی

`tests/integration/test_playthrough.gd` از صحنهٔ واقعی `main.tscn` شروع
می‌کند، نه از سطح چیده‌شده:

1. صفحهٔ عنوان → زرادخانه → شروع
2. مکث و ادامه
3. رگبار مسلسل دولول از ماشهٔ خودِ سلاح
4. خشاب‌گذاری واقعی
5. آرپی‌جی و نارنجک از دستِ توپچی
6. مرحلهٔ ۱ تا پیروزی با سیستم‌های زنده (دشمن، موج، دیوار)؛ نتیجه از
   `match_finished` است نه پرچمِ تست
7. ذخیره: `stages_cleared == 1`
8. AGAIN
9. مسلسل شش‌لول انتخاب و شلیک
10. ۹۰ ثانیه بدون شلیک: دروازه آسیب می‌بیند

شکستِ کامل دیوار همچنان در `test_siege` (دیوار بی‌دفاع) است.
`game_smoke.gd` هنوز چند تصویر پیش‌نمایش دارد؛ آن‌ها را جعلِ پیروزی حساب
نکردیم.

**این تست در این محیط اجرا نشده.**

## ۴. فاز ۳ — اندروید روی دستگاه

سخت‌افزار در دسترس نبود.

رویه‌ٔ تکرارپذیر: `documentation/ANDROID_DEVICE_TEST.md`.

هیچ عدد FPS / RAM / حرارت دستگاهی وجود ندارد. ادعا نمی‌شود کارایی موبایل
تأیید شده.

## ۵. فاز ۴ — صدا و توازن

### صدا

هر ۴۶ نام `Sound.CLIPS` فایل `assets/audio/*.wav` دارد. حلقه‌ها (باد و
تم) با `stop_loop` قطع می‌شوند؛ محدودکننده روی Master هست؛ حجم صفر باس را
mute می‌کند.

**ایراد:** برگشت به منو one-shot جنگی را روی Autoload باقی می‌گذاشت.

**اصلاح:** `Sound.silence_combat()` حلقه‌ها را نگه می‌دارد و صداهای جنگی
را قطع می‌کند. صدا زده می‌شود از `Game.to_menu` و قبل از صفحهٔ نتیجه.
تست در `test_polish.gd`.

`rotary_spin` one-shot است نه حلقهٔ گیر کرده.

### توازن

آسیب، جان، نرخ شلیک و شعاع انفجار **عوض نشده** (قفل `test_release`).

تغییر مرتبط با پایداری، نه سختیِ عمدی:

| | قبل (درخت کثیف) | حالا |
| --- | --- | --- |
| مقیاس واکر | ۱٫۳۸–۱٫۵۲ | ۱٫۱۰–۱٫۲۲ |
| شکل اضافه | روی همهٔ استخر از ابتدا | فقط وقتی پوشیده شود؛ حداکثر حدود ۱/۴ جمعیت |

مدل `zombie_bloat` دیگر ۲۶+۱۲+۴ اسکلت اضافه از فریم اول نمی‌سازد. شکل
اضافه هنوز در بازی هست.

## ۶. فاز ۵ — آمادگی بسته

| مورد | مقدار | یادداشت |
| --- | --- | --- |
| Package | `com.studiojavid.zombiesiege` | سازگاری جدا: `.compatibility` |
| نسخه | ۰٫۶٫۱ | `project.godot` |
| versionCode | ۷ | هر دو preset |
| آیکون | `assets/textures/icon.png` | ۱۹۲ و adaptive |
| معماری | فقط arm64-v8a | |
| مجوز | هیچ | |
| Gradle | خاموش؛ قالب آماده | API 24–36 |
| امضا | secret یا کلید موقت CI | کلید در ریپو نیست |
| خروجی | `delivery/LastWall-arm64.apk` | CI می‌سازد |

کلید و رمز commit نشده. بدون `ARTILLERY_KEYSTORE_*` هر ساخت امضای تازه
دارد: **قبل از نصب، نسخهٔ قبلی را حذف کنید.**

APK در این محیط export نشده.

## ۷. فاز ۶ — پذیرش نهایی

| اجرا | اینجا | انتظار از CI |
| --- | --- | --- |
| بازرسی ایستا `audit_project.py` | اجرا نشد (بعد از پوش) | باید سبز شود |
| تست‌های قبلی + `test_governor` + `test_playthrough` | اجرا نشد | Godot 4.7.2 headless |
| smoke رندر نرم‌افزاری | اجرا نشد | xvfb، ≥۳۷ تصویر |
| export اندروید | اجرا نشد | بعد از validate |
| گوشی واقعی | انجام نشد | دستی، طبق فرم |

### فایل‌های این فاز

- `scripts/graphics/graphics_manager.gd`
- `tests/unit/test_governor.gd` (تازه)
- `tests/unit/test_polish.gd`
- `tests/integration/test_playthrough.gd` (تازه)
- `scripts/audio/audio_manager.gd`
- `scripts/core/game.gd`
- `scripts/zombies/zombie.gd` (بار تنبل شکل اضافه)
- `scripts/environment/city_level.gd` (`fog_sun_scatter = 0`؛ بدون پالس نور آتش)
- `resources/zombies/{walker,runner,brute,boss}.tres` (مقیاس)
- `project.godot`, `export_presets.cfg`
- `documentation/ANDROID_DEVICE_TEST.md`
- `documentation/PHASE_7_REPORT.md`

### باقی‌مانده (مسدودکنندهٔ فروشگاه)

1. **هیچ اجرای Godot / CI در این workspace ثبت نشده** — تست‌ها نوشته شده‌اند، نه پاس‌شده.
2. **هیچ گوشی‌ای بازی را ندیده** — گاورنر، لمس، حرارت، حافظه.
3. **امضای انتشار پایدار نیست** مگر secretهای keystore ست شوند.
4. MSAA بعد از اولین bind عوض نمی‌شود؛ اگر بازی با auto (medium، MSAA خاموش)
   شروع شود، انتخاب high آنتی‌الیاس نمی‌آورد.
5. اعداد گاورنر هنوز روی گوشی تنظیم نشده‌اند.
6. چند تصویر smoke هنوز پیش‌نمایش‌اند (پیروزی ساخته‌شده).
7. Glow زمان اجرا همچنان خاموش است (رندر موبایل).

### غیرمسدودکننده

- مرحلهٔ ۲ ساخته نشده (طبق دستور).
- صداها مصنوعی‌اند؛ کسی در این فاز نشنیده.
- لنگیدن در حرکت روی دستگاه دیده نشده.

---

**وضعیت نهایی:** پایدارسازی کد انجام شده؛ **آمادهٔ انتشار فروشگاهی نیست.**
بعد از سبز شدن CI و یک دور فرم `ANDROID_DEVICE_TEST.md` روی گوشی واقعی
می‌توان دربارهٔ 0.6.1 حرف زد.
