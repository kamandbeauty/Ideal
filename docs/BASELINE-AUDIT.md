# Baseline Audit — Phase 1 (T-Shirt Designer → Custom Product Designer Engine)

سند مرجع: «Custom Product Designer — Execution Contract & Product Roadmap»، بند ۵.
تاریخ: 2026-09-04 — شاخه: `arena/01a06d64-ideal` — کامیت پایه: `fdf828e`

هدف این سند: ثبت وضعیت واقعی کد موجود (Baseline) پیش از هرگونه توسعهٔ Phase 2،
طبق اصل «Extend, Don't Rewrite».

---

## 1. Existing Architecture

پلاگین WordPress مستقل از قالب، با Namespace `TShirtDesigner`، Autoloader اختصاصی
(`includes/class-autoloader.php`) و یک Composition Root به نام `Plugin` (Singleton).

```
tshirt-designer.php            bootstrap + ثابت‌ها (TD_VERSION, TD_DB_VERSION=1.0.0, TD_PLUGIN_FILE)
includes/                      لایهٔ Core + Infrastructure (۱۷ کلاس)
admin/                         لایهٔ Presentation-Admin (۹ کلاس + ۱۰ view)
templates/designer.php         لایهٔ Presentation-Frontend (markup)
assets/js/designer/*.js        اپلیکیشن ۳بعدی (۸ ماژول ES)
assets/js/blocks/              بلاک گوتنبرگ
assets/js/vendor/three/        Three.js r170 (subset، bundled)
languages/                     pot + fa_IR (po/mo، ۲۶۵ رشته، ۱۰۰٪)
tests/unit-bounds-pricing.php  تست واحد (۳۵ assertion)
uninstall.php                  حذف کامل داده (اختیاری)
```

`Plugin::instance()` این سرویس‌ها را می‌سازد و به هم تزریق می‌کند:
`Database`, `Settings`, `Model_Manager`, `Color_Manager`, `Size_Manager`,
`Print_Area_Manager`, `Asset_Manager`, `Media_Manager`, `Pricing_Engine`,
`Design_Manager`.

نگاشت به لایه‌بندی خواسته‌شده در سند (بند ۴):

| لایهٔ سند | وضعیت فعلی | فاصله |
|---|---|---|
| Core (Product/Model/Design/Asset/PrintArea/Pricing/Validation) | موجود ولی به‌صورت Manager های DB-aware | لایهٔ Product Type وجود ندارد؛ Core و Infrastructure در یک کلاس ادغام‌اند |
| Core/Production | وجود ندارد | Phase 3 |
| Infrastructure (Database/FileStorage/WordPress) | `Database`, `Media_Manager` | OK |
| Infrastructure/WooCommerce | فقط `class-woocommerce.php` (اعلام سازگاری HPOS + نوتیس) | Phase 2 |
| Application services | وجود ندارد؛ `Design_Manager` نقش DesignService+PricingService را دارد | نیاز به سرویس‌های Cart/Order/Production در Phase 2/3 |
| Presentation (Frontend/Admin/REST) | کامل | OK |

نکتهٔ مثبت: `Pricing_Engine::compute()` تابع خالص است (بدون DB و بدون فراخوانی
بدون‌گارد WP) — این دقیقاً همان جهت وابستگی مطلوب سند است.

نکتهٔ منفی: Managerها مستقیماً `global $wpdb` می‌زنند، پس Core به Infrastructure
وابسته است (برخلاف نمودار بند ۴). این بدهی فنی است ولی Blocking نیست.

---

## 2. Existing Modules

| فایل | مسئولیت | ارزیابی |
|---|---|---|
| `class-plugin.php` | Composition root، activate/upgrade، ثبت بلاک | فاقد لایهٔ ProductType |
| `class-autoloader.php` | نگاشت class → file | OK |
| `class-database.php` | تعریف ۸ جدول + `install()` (dbDelta) + `drop()` | **Migration واقعی ندارد** |
| `class-settings.php` | آپشن `td_settings` + sanitize | OK |
| `class-model-manager.php` | CRUD مدل + مسیر GLB/preview | مدل، Product Type ندارد |
| `class-color-manager.php` | CRUD رنگ per-model | OK |
| `class-size-manager.php` | CRUD سایز + price_modifier | OK |
| `class-print-area-manager.php` | CRUD ناحیهٔ چاپ، `AREA_TYPES = front/back/left_sleeve/right_sleeve/other` | **لیست ثابت، برای Tote Bag و محصولات بعدی باید قابل توسعه شود** |
| `class-print-area-bounds.php` | AABB ناحیهٔ چرخیده، clamp، رد کردن Overflow | تست‌شده، قابل استفادهٔ مجدد |
| `class-asset-manager.php` | کتابخانهٔ آثار سایت + دسته‌بندی | OK |
| `class-media-manager.php` | اعتبارسنجی و ذخیرهٔ آپلود کاربر | امنیت خوب (۳ لایه) |
| `class-design-manager.php` | validate/quote/save/list/get طرح + Ownership | **بدون Versioning، بدون UUID** |
| `class-pricing-engine.php` | تابع خالص محاسبه + CRUD قاعده | مطابق سند |
| `class-content-seeder.php` | دادهٔ اولیه (مدل تی‌شرت، رنگ، سایز، ۴ ناحیه، ۱۷ اثر) | دادهٔ واقعی است نه Mock |
| `class-rest-api.php` | ۷ route با namespace `tshirt-designer/v1` | نیاز به namespace نسخهٔ جدید برای Engine |
| `class-shortcode.php` | `[tshirt_designer]`، کوکی مهمان، `?td_design=` | OK |
| `class-assets.php` | enqueue + boot data + i18n | OK |
| `class-woocommerce.php` | فقط اعلام سازگاری HPOS و نوتیس | Phase 2 |

---

## 3. Existing Database

پیشوند جداول: `{$wpdb->prefix}td_`، نسخه در آپشن `td_db_version` (فعلاً `1.0.0`).

| جدول | ستون‌های کلیدی |
|---|---|
| `td_models` | id, name, slug, description, model_file_id/path, preview_image_id/path, **wc_product_id**, base_price, is_active, sort_order, created_at, updated_at |
| `td_model_colors` | id, model_id, name, hex, texture_image_id, thumbnail_id, is_active, sort_order |
| `td_model_sizes` | id, model_id, name, price_modifier, is_active, sort_order |
| `td_print_areas` | id, model_id, name, area_type, max_width_cm, max_height_cm, position (longtext: uv_rect + camera), is_active, sort_order |
| `td_design_assets` | id, name, category, file_id, file_path, is_active, sort_order |
| `td_pricing_rules` | id, rule_type(size_tier/item_extra), scope(global/area), print_area_id, size_from_cm, size_to_cm, item_count, price, is_active, sort_order |
| `td_designs` | id, user_id, guest_token, model_id, color_id, size_id, design_data(longtext JSON), preview_image_id, price_total, price_breakdown(longtext JSON), status, created_at, updated_at |
| `td_uploads` | id, user_id, guest_token, attachment_id, original_name, mime, width, height |

کمبودهای نسبت به سند:
- ستون `uuid`, `version`, `product_type` در `td_designs` نیست (بندهای ۹ و ۱۰).
- جدول نسخه‌های طرح (`design_versions`) نیست.
- جدول `product_types` و `templates` نیست (بندهای ۳ و ۱۴).
- جدول Production/Order snapshot نیست (بندهای ۱۶–۲۱).
- مکانیزم Migration نسخه‌به‌نسخه نیست؛ فقط `dbDelta` روی آخرین Schema اجرا می‌شود.

---

## 4. Existing APIs

Namespace: `tshirt-designer/v1`

| Route | Method | Permission | خروجی |
|---|---|---|---|
| `/models` | GET | public | فهرست عمومی مدل‌ها |
| `/models/(?P<id>\d+)` | GET | public | مدل + colors + sizes + print_areas + base_price + currency |
| `/assets` | GET | public | کتابخانهٔ آثار (فیلتر category) |
| `/uploads` | POST | `can_upload()` | `{ok, upload:{id,url,width,height,mime}}` |
| `/price` | POST | `can_post()` | `{ok, breakdown}` — قیمت همیشه سمت سرور |
| `/designs` | POST | `can_post()` | `{ok, id, breakdown}` |
| `/designs` | GET | `can_post()` | طرح‌های همان کاربر/مهمان |
| `/designs/(?P<id>\d+)` | GET | `can_post()` | با بررسی Ownership |

سیاست دسترسی: کاربر لاگین → بررسی nonce `wp_rest` از هدر `X-WP-Nonce`؛
مهمان → بررسی same-origin + تنظیمات `allow_guest_uploads` / `allow_guest_designs`.
توکن مهمان در کوکی HttpOnly `td_guest` (۳۰ روز).

طبق بند ۳۱ سند، این ۸ endpoint باید **حفظ** شوند و API نسل بعد زیر
`custom-product-designer/v1` اضافه شود.

---

## 5. Existing Frontend

- Three.js r170 (bundle محلی، بدون CDN)، `GLTFLoader`, `OrbitControls`, `RoomEnvironment` (PMREM).
- مدل `assets/models/classic-tshirt.glb` (۱۲۷۳۰ مثلث) با متریال `TD_Fabric`.
- Compositor: بوم ۲۰۴۸×۲۰۴۸، هر ناحیه یک مستطیل UV؛ رنگ پایه + بافت اختیاری،
  آیتم‌ها با چرخش رسم می‌شوند، `CanvasTexture` با `flipY=false` و `SRGBColorSpace`
  → طرح روی سطح واقعی مدل می‌نشیند (نه Overlay — مطابق بند ۸).
- Editor2D: درگ، ۴ دستگیرهٔ Resize نسبت‌ثابت، دستگیرهٔ چرخش، جابه‌جایی با کلید جهت
  (۰٫۵cm / ۲cm با Shift)، حذف با Delete.
- انتخاب ناحیه با Raycast روی UV مدل.
- State store با subscribe/emit؛ فراخوانی قیمت debounce ۵۰۰ms.
- Responsive: گرید ۳ ستونه → موبایل با کشوی ابزار (`.td-tools-toggle`).
- مدیریت خطای WebGL با Overlay جایگزین. Loading state دارد.

کمبود نسبت به سند: Text Engine (بند ۱۳) و Template (بند ۱۴) در UI نیست؛
ساختار `design item` فعلاً فقط `asset|upload` را می‌پذیرد.

---

## 6. Existing Admin

منوی `tshirt-designer` با زیرمنوهای: Models, Colors, Sizes, Print Areas,
Design Assets, Pricing, Designs, Settings. Capability: `manage_options`.
همهٔ فرم‌ها به `admin-post.php?action=td_action` با `wp_nonce_field('td_admin_<page>')`
POST می‌کنند و روتر مرکزی nonce + capability را بررسی می‌کند.
انتخاب فایل با `wp.media` (تشخیص GLB). استایل RTL-friendly با logical properties.

کمبود نسبت به بند ۲۳: Templates, Orders, Production, Logs وجود ندارد (Phase 2/3).

---

## 7. Existing Tests

- `tests/unit-bounds-pricing.php` — **۳۵ تست، ۰ خطا** (اجرا شد و پاس شد).
  پوشش: AABB و clamp نواحی چاپ، رد کردن طرح بزرگ‌تر از ناحیه، آیتم چرخیده،
  Tier قیمت بر اساس بزرگ‌ترین ضلع، مرزهای بازه، اولویت area بر global،
  قیمت آیتم چندم، fallback، هشدارها.
- Lint: هر ۴۱ فایل PHP با php-wasm 8.3 پارس می‌شوند؛ همهٔ فایل‌های JS با
  `node --check` پاس می‌شوند.
- ابزار اجرا: `/home/user/scratch/php.mjs` (php-wasm 8.3 + دسترسی به فایل‌سیستم میزبان).
- **تست یکپارچه با WordPress واقعی وجود ندارد** — بدهی اصلی تست.

---

## 8. Potential Conflicts (ریسک‌های توسعهٔ Phase 2)

1. **نبود Product Type**: مدل مستقیماً به تی‌شرت گره خورده. افزودن Tote Bag
   بدون لایهٔ `product_type` باعث if-گذاری در Core می‌شود → نقض بند ۶ و ۷.
2. **`Print_Area_Manager::AREA_TYPES` ثابت**: Tote Bag فقط front/back می‌خواهد؛
   کلاه/ماگ انواع دیگر. باید به تعریف در سطح Product Type منتقل شود
   (با حفظ سازگاری عقب‌رو برای مقادیر فعلی).
3. **نبود Versioning طرح**: بند ۱۰ و ۱۹ (Immutability سفارش) بدون نسخه‌بندی
   قابل تحقق نیست. سفارش باید به یک نسخهٔ ثابت وصل شود.
4. **`design_data` تک‌فیلد JSON**: خوب برای Snapshot، ضعیف برای کوئری و
   Production per-area. برای Phase 3 احتمالاً جدول کمکی لازم است.
5. **نبود Migration**: `dbDelta` ستون حذف نمی‌کند و تغییر نوع را همیشه درست
   انجام نمی‌دهد. بدون Runner نسخه‌ای، بند ۱۴ و ۳۰ نقض می‌شود.
6. **`user_owns_design()` به ادمین دسترسی کامل می‌دهد** — برای پنل ادمین درست
   است، ولی هنگام افزودن API «دانلود فایل تولید» باید Capability مجزا داشته باشد.
7. **نام‌گذاری فعلی (`td_`, `TShirtDesigner`, `tshirt-designer/v1`)**: تغییر نام
   کامل = Breaking Change و نقض بند ۱ و ۱۵. پیشنهاد: نگه‌داشتن پیشوندها و
   افزودن namespace جدید API در کنار آن، نه به‌جای آن.
8. **پرداخت/سبد خرید**: هیچ کدی وجود ندارد؛ کل بندهای ۱۷–۲۲ کار جدید است
   (بدون تعارض با کد موجود).

---

## 9. Required Extensions (نقشهٔ کم‌ریسک)

به ترتیب اولویت و همگی به‌صورت «افزودن» نه «بازنویسی»:

**E1 — Migration Runner (پیش‌نیاز همه چیز)**
`includes/class-migrations.php`: آرایهٔ نسخه‌ها → callable، اجرا از `td_db_version`
تا `TD_DB_VERSION`، idempotent، بدون دست‌زدن به دادهٔ سفارش‌های قبلی.
`Database::install()` حفظ می‌شود و به‌عنوان migration پایه (1.0.0) ثبت می‌گردد.

**E2 — Product Type Registry**
`includes/class-product-type-registry.php` با فیلتر `td_product_types`:
هر Product Type شامل `slug`, `label`, `area_types[]`, `default_areas[]`,
`production_rules`. دو نوع ثبت‌شدهٔ پیش‌فرض: `tshirt`, `totebag`.
ستون `product_type` به `td_models` (پیش‌فرض `tshirt` برای رکوردهای موجود →
سازگاری کامل عقب‌رو). `Print_Area_Manager::AREA_TYPES` به‌عنوان fallback باقی
می‌ماند ولی اعتبارسنجی از Registry می‌آید.

**E3 — Design UUID + Versioning**
ستون‌های `uuid`, `version`, `product_type` روی `td_designs` + جدول
`td_design_versions` (snapshot کامل `design_data` + `price_breakdown`).
API موجود بدون تغییر شکل خروجی می‌ماند؛ فیلدهای جدید فقط اضافه می‌شوند.

**E4 — Design Item Type polymorphism**
افزودن `text` و `template` به انواع مجاز آیتم به همراه اعتبارسنجی اختصاصی و
`layer`, `opacity`, `metadata`. رندر متن در Compositor. (بند ۱۳ — Phase 4 در
سند، ولی ساختار داده باید در Phase 2 آماده شود.)

**E5 — Tote Bag**
مدل GLB مستقل + Seed جداگانه، بدون یک خط کد اختصاصی در Core.

**E6 — Commerce (Phase 2)**
`CartService`/`OrderService` روی هوک‌های WooCommerce + Price Snapshot تغییرناپذیر
روی order item meta.

**E7 — Integration Test Harness**
اجرای WordPress واقعی روی php-wasm + SQLite drop-in و تست کامل REST
(مالکیت، دستکاری قیمت، آپلود، مجوزها).

---

## 10. حکم Baseline

Phase 1 (Core + Admin + 3D Designer + Pricing Engine) از نظر پیاده‌سازی،
امنیت و تست واحد **پایدار و قابل اتکا** است و به‌عنوان قرارداد پایه پذیرفته می‌شود.

سه شکاف معماری که پیش از افزودن Tote Bag باید بسته شود:
**Migration Runner (E1)** → **Product Type Registry (E2)** → **Design Versioning (E3)**.

هیچ‌کدام نیازمند بازنویسی Core نیستند؛ همگی افزایشی و سازگار عقب‌رو هستند.
