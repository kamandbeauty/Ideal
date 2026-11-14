# گزارش فاز ۷٫۱ — بازیابی CI و اعتبارسنجی اندروید

> **English at a glance.** Phase 7.1 repairs the CI break from `e6ae907`
> without new gameplay. Headless suites, smoke play-through and Android
> export are green on
> [43357757470](https://github.com/kamandbeauty/Ideal/actions/runs/43357757470).
> **Physical Android validation is pending.** CI software-renderer play is
> not a phone run.

تعمیر شکست CI فاز ۷. مرحلهٔ ۲ و سلاح تازه در کار نیست.

## ۱. کامیت و CI

| | |
| --- | --- |
| پایه | `e6ae907` Phase 7: bind governor scale to the 3D buffer |
| تعمیر کد | `7f67dc7` (روی `05adb5b`) |
| شواهد تست | `d16e759` |
| APK | `1777019` |
| CI سبز | [43357757470](https://github.com/kamandbeauty/Ideal/actions/runs/43357757470) — validate 3m28s، android 1m13s |
| CI قبلی | [43332282959](https://github.com/kamandbeauty/Ideal/actions/runs/43332282959) JSON خالی؛ [43357325714](https://github.com/kamandbeauty/Ideal/actions/runs/43357325714) `show_loading` نبود |

## ۲. Autoload گرافیک

`tests/run_tests.gd` با `--script` قبل از Autoload کامپایل می‌شود. نام
`Zombie.mix_extras` اسکریپت `zombie.gd` را وابسته می‌کرد؛ آن فایل
`Graphics.profile()` داشت → `Identifier not found: Graphics` →
`class_name Zombie` ثبت نمی‌شد → `Horde._create` `Node3D` می‌گرفت.

**اصلاح**

- `zombie.gd`: کیفیت از `/root/Graphics` در زمان اجرا (`call("profile")`).
- `run_tests.gd`: `load(...)` بعد از وجود Autoload.
- JSON بعد از هر سوئیت نوشته می‌شود.
- `test_horde`: اسپاون باید `is_instance_of(..., Zombie)` باشد.

فاز ۷ `menus.show_loading()` را صدا زد بدون متد. `start_match` شکست؛
back روی عنوان `quit()` کرد. الان overlay با `GET READY` است؛ دو فریم
منتظر رنگ‌شدن؛ تست‌های شروع مسابقه `frames(4)`.

## ۳. شناسهٔ بسته

Canonical: **`com.studiojavid.zombiesiege`**
(سازگاری: `com.studiojavid.zombiesiege.compatibility`)

Presets، `test_project`، `test_release` و APK ساخته‌شده همین شناسه را دارند.
ذکر `com.frontline.lastwall` در PHASE_1…5 آرشیو است.

## ۴. گاورنر

`test_governor` ۲۲ بررسی: low/medium/high روی `viewport.scaling_3d_scale`؛
یک گام پایین و بازگشت به بالا هر دو بافر واقعی را عوض می‌کنند؛ MSAA بعد از
اولین bind ثابت می‌ماند.

محدودیت: MSAA یک‌بار بسته می‌شود. روی گوشی اثبات نشده.

## ۵. سوئیت‌ها — اجرا شده، نه skip

منبع: `documentation/qa/test-results.json` از `d16e759`.
موتور 4.7.2-stable. **۲۳۹۹ بررسی، ۲۹ سوئیت، ۰ شکست، ۰ skip.**

| سوئیت | بررسی |
| --- | ---: |
| test_aim | 46 |
| test_attack_lines | 75 |
| test_ballistics | 21 |
| test_defense | 30 |
| test_explosion | 48 |
| test_governor | 22 |
| test_layout | 68 |
| test_loc | 37 |
| test_polish | 160 |
| test_project | 29 |
| test_release | 79 |
| test_save | 47 |
| test_waves | 115 |
| test_weapon_state | 48 |
| test_zombie_types | 118 |
| test_arsenal | 102 |
| test_campaign | 78 |
| test_combat | 37 |
| test_edge_cases | 86 |
| test_explosives | 204 |
| test_feedback | 81 |
| test_horde | 63 |
| test_hud | 57 |
| test_playthrough | 38 |
| test_scenes | 69 |
| test_screens | 398 |
| test_siege | 70 |
| test_sight | 51 |
| test_specials | 122 |

الزامی‌ها همه >۰: governor، polish، combat، playthrough، campaign،
edge_cases، explosives، project.

محدودهٔ گزارش: منطق هدلس روی دسکتاپ؛ **اجرای دستگاه اندروید نیست.**

Smoke نرم‌افزاری هم در همان workflow سبز شد (اسکرین‌شات‌ها در
`documentation/qa/`). آن هم گوشی نیست.

## ۶. APK — بازرسی بسته، نه گوشی

منبع: `delivery/package-validation.json` از `1777019`.
امضا: کلید موقت CI (`BUILD-STATUS.txt`). هویت فروشگاه عوض نشده.

| | LastWall-arm64.apk | LastWall-compatibility.apk |
| --- | --- | --- |
| بسته | `com.studiojavid.zombiesiege` | `com.studiojavid.zombiesiege.compatibility` |
| حجم | ۴۴٬۴۳۵٬۳۳۰ بایت (~۴۲٫۴ مگ) | همان |
| SHA-256 | `31b770060ca3cb590e7ac964c41fcec1510ffad2790016cf301181b801d134ab` | `414f91528fe7eff14f3fd878efac6896b5d7ef32436b5dfc0acfff727a71579e` |
| min/target SDK | ۲۴ / ۳۶ | ۲۴ / ۳۶ |
| ABI | فقط arm64-v8a | فقط arm64-v8a |
| نسخه | 0.6.1 / versionCode 7 | همان |
| اینترنت | هیچ permission | هیچ |
| افقی، بازی، غیر debug | بله | بله |

نصب: اول uninstall. هر ساخت CI کلید موقت جدا دارد.

## ۷. اندروید روی دستگاه

- **اعتبارسنجی فیزیکی: PENDING.** هیچ گوشی یا شبیه‌ساز این ساخت را اجرا نکرده.
- چک‌لیست: `documentation/ANDROID_DEVICE_TEST.md`
- Secretهای `ARTILLERY_KEYSTORE_*` اگر باشند هویت انتشار می‌مانند؛ این اجرا
  کلید موقت داشت.

## ۸. مسدودکننده‌های باقی

1. **گوشی واقعی: pending.** CI سبز ≠ بازی روی تلفن.
2. امضای این APK موقت است؛ برای فروشگاه کلید انتشار لازم است (خارج از Git).
3. MSAA بعد از bind اول عوض نمی‌شود؛ bilinear scale ممکن است حرکت کند.
4. مرحلهٔ ۲ شروع نشده.

فاز ۷٫۱ از نظر CI (سوئیت + smoke + export + بازرسی APK) تمام است.
اعتبارسنجی تلفن تمام نیست.
