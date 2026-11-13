# گزارش فاز ۷٫۱ — بازیابی CI و اعتبارسنجی اندروید

> **English at a glance.** Phase 7.1 repairs the CI break from `e6ae907`
> without new gameplay. `zombie.gd` no longer names the Graphics autoload
> (the headless `--script` runner compiles it before autoloads exist). The
> package id is `com.studiojavid.zombiesiege` in presets, tests and
> validators. The test runner writes JSON after every suite. **Physical
> Android validation is pending.** This report does not claim CI green
> until a run of this commit has passed.

تعمیر شکست CI فاز ۷. مرحلهٔ ۲ و سلاح تازه در کار نیست.

## ۱. کامیت و CI

| | |
| --- | --- |
| پایه | `e6ae907` Phase 7: bind governor scale to the 3D buffer |
| CI قبلی | [43332282959](https://github.com/kamandbeauty/Ideal/actions/runs/43332282959) — JSON خالی |
| Autoload | [43357325714](https://github.com/kamandbeauty/Ideal/actions/runs/43357325714) — سوئیت‌ها دویدند؛ `show_loading` نبود |
| علت ۱ | `zombie.gd` `Graphics.profile()` زیر `--script` |
| علت ۲ | فاز ۷ `menus.show_loading()` را صدا زد بدون پیاده‌سازی؛ `start_match` شکست؛ back روی عنوان `quit()` کرد |

URL اجرای این کامیت بعد از پوش در Actions همان workflow `LAST WALL` است.
تا آن اجرا سبز نشود، سوئیت‌ها **پاس‌شده اعلام نمی‌شوند**.

## ۲. Autoload گرافیک

`tests/run_tests.gd` با `--script` قبل از Autoload کامپایل می‌شود. نام
`Zombie.mix_extras` اسکریپت `zombie.gd` را وابسته می‌کرد؛ آن فایل
`Graphics.profile()` داشت → `Identifier not found: Graphics` →
`class_name Zombie` ثبت نمی‌شد → `Horde._create` نمی‌توانست `Zombie`
بسازد.

**اصلاح**

- `zombie.gd`: کیفیت از `/root/Graphics` در زمان اجرا خوانده می‌شود
  (`call("profile")`)، نه شناسهٔ Autoload.
- `run_tests.gd`: `load("res://scripts/zombies/zombie.gd")` بعد از وجود
  Autoload؛ دیگر `Zombie.mix_extras` در زمان parse نیست.
- گزارش JSON بعد از **هر** سوئیت نوشته می‌شود تا کرش بعدی فایل خالی نگذارد.
- `test_project` قفل می‌کند که `zombie.gd` حاوی `Graphics.` نباشد.
- `test_horde`: اسپاون باید `is_instance_of(..., Zombie)` باشد.

رفتار زمان اجرا همان است: شکل اضافه فقط وقتی کیفیت `detail` دارد و حدود
یک‌چهارم جمعیت.

اجرای `05adb5b` سوئیت‌ها را راه انداخت (`test_governor` ۲۲، `test_combat`
۳۷، `test_project` ۲۹، JSON غیرخالی). بعد `start_match` به
`menus.show_loading()` خورد که فاز ۷ صدا زد و ننوشت. مسابقه شروع نشد؛
`NOTIFICATION_WM_GO_BACK_REQUEST` روی عنوان `get_tree().quit()` کرد و
رانر مرد. `show_loading` الان صفحهٔ GET READY است؛ `start_match` دو فریم
منتظر رنگ‌شدن است؛ تست‌های شروع مسابقه `frames(4)` می‌مانند.

## ۳. شناسهٔ بسته

Canonical: **`com.studiojavid.zombiesiege`**
(سازگاری: `com.studiojavid.zombiesiege.compatibility`)

| فایل | وضعیت |
| --- | --- |
| `export_presets.cfg` | از قبل درست بود |
| `tools/verify_packages.py` | از قبل درست بود |
| `tests/unit/test_project.gd` | انتظار قدیمی `com.frontline.lastwall` → شناسهٔ جدید |
| `tests/unit/test_release.gd` | هر دو preset با شناسهٔ صریح |

ذکر `com.frontline.lastwall` در `PHASE_1`…`PHASE_5` آرشیو همان فازهاست،
نه پیکربندی فعلی.

## ۴. گاورنر

`test_governor.gd` حالا:

- low / medium / high می‌نویسد روی `viewport.scaling_3d_scale`
- یک گام پایین و **بازگشت به بالا** هر دو بافر واقعی را عوض می‌کنند
- MSAA بعد از اولین bind ثابت می‌ماند

محدودیت مستند: MSAA یک‌بار بسته می‌شود؛ عوض کردنش روی رندر موبایل بافر را
پاره می‌کند.

## ۵. اندروید

- **اعتبارسنجی روی دستگاه واقعی: در انتظار.** هیچ گوشی یا شبیه‌سازی در
  این فاز اجرا نشده.
- چک‌لیست: `documentation/ANDROID_DEVICE_TEST.md` (FPS، لمس، تعویض سلاح،
  مقیاس رزولوشن، حرارت، حافظه، صدا).
- امضا: کلید و رمز در Git نیست. Secretهای
  `ARTILLERY_KEYSTORE_BASE64` / `PASSWORD` / `KEY_ALIAS` همان هویت انتشار
  می‌مانند. بدون آن‌ها CI کلید موقت می‌سازد — هویت فروشگاه عوض نمی‌شود.

## ۶. سوئیت‌هایی که باید در گزارش JSON باشند

`check_report.py` اگر هر کدام صفر بررسی داشته باشد شکست می‌خورد:

`test_governor`, `test_polish`, `test_combat`, `test_playthrough`,
`test_campaign`, `test_edge_cases`, `test_explosives`, `test_project`

حداقل ۲۲۵۰ بررسی؛ فایل خالی رد است.

**شمارش پاس/رد این کامیت: هنوز نیست.** تا اجرای CI این SHA، هیچ سوئیتی
پاس‌شده نیست.

## ۷. APK

ساخت APK این تعمیر فقط بعد از سبز شدن validate در workflow.
APK قبلی سالم (قبل از فاز ۷): `31d3b66`، حدود ۴۴٫۴ مگ.

## ۸. مسدودکننده‌های باقی

1. اجرای CI این کامیت هنوز باید سبز شود (smoke + export).
2. **گوشی واقعی: pending.**
3. امضای فروشگاه فقط با secretهای موجود؛ کلید موقت هویت انتشار نیست.
4. MSAA بعد از bind اول عوض نمی‌شود.

مرحلهٔ ۲ شروع نشده است.
