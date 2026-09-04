#!/usr/bin/env python3
"""
Generate translation files for the T-Shirt Designer plugin.

- Extracts all __()/_e()/esc_html__()/... calls with the 'tshirt-designer'
  text domain from the plugin's PHP files.
- Writes languages/tshirt-designer.pot (template).
- Writes languages/tshirt-designer-fa_IR.po and compiles the binary
  languages/tshirt-designer-fa_IR.mo from the FA_TRANSLATIONS table below.

Usage: python3 tools/make_translations.py
"""

import re
import struct
import time
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent.parent / "tshirt-designer"
LANG_DIR = PLUGIN / "languages"

# ----------------------------------------------------------------------------
# Persian translations (source English -> Persian). Placeholders must match.
# ----------------------------------------------------------------------------

FA = {
    "3D model (GLB / GLTF)": "مدل سه‌بعدی (GLB / GLTF)",
    "A design item references an unavailable artwork.": "یکی از آیتم‌های طرح به گرافیکی ناموجود ارجاع می‌دهد.",
    "A design item references an unavailable upload.": "یکی از آیتم‌های طرح به فایل بارگذاری‌شده‌ای ناموجود ارجاع می‌دهد.",
    "A print area can hold at most %d items.": "هر ناحیه چاپ حداکثر %d آیتم را پشتیبانی می‌کند.",
    "Actions": "عملیات",
    "Active": "فعال",
    "Add asset": "افزودن گرافیک",
    "Add color": "افزودن رنگ",
    "Add model": "افزودن مدل",
    "Add pricing rule": "افزودن قانون قیمت‌گذاری",
    "Add print area": "افزودن ناحیه چاپ",
    "Add rule": "افزودن قانون",
    "Add size": "افزودن سایز",
    "Additional item charge": "هزینه آیتم اضافی",
    "Additional items in the same print area": "آیتم‌های اضافی در همان ناحیه چاپ",
    "After the amount (350,000 Toman)": "بعد از مبلغ (۳۵۰,۰۰۰ تومان)",
    "All": "همه",
    "Allow guests to save designs": "مهمان‌ها بتوانند طرح ذخیره کنند",
    "Allow guests to upload images": "مهمان‌ها بتوانند تصویر بارگذاری کنند",
    "Allowed formats: JPG, JPEG, PNG, WEBP. PNG/WEBP transparency is preserved. SVG is not allowed.": "فرمت‌های مجاز: JPG، JPEG، PNG و WEBP. شفافیت PNG/WEBP حفظ می‌شود. SVG مجاز نیست.",
    "An item (%1$s × %2$s cm) is larger than the print area.": "یک آیتم (%1$s × %2$s سانتی‌متر) از ناحیه چاپ بزرگ‌تر است.",
    "An item is placed outside the print area.": "یک آیتم خارج از ناحیه چاپ قرار گرفته است.",
    "Animal": "حیوانات",
    "Applied to the 3D model instantly, without reloading the page.": "بلافاصله روی مدل سه‌بعدی اعمال می‌شود؛ بدون بارگذاری مجدد صفحه.",
    "Area rules override the global rules for this print area only. The global rules are also listed for reference.": "قوانین ناحیه فقط برای همین ناحیه چاپ جایگزین قوانین سراسری می‌شوند. قوانین سراسری هم برای اطلاع فهرست شده‌اند.",
    "Artwork": "گرافیک",
    "Artwork library": "کتابخانه گرافیک",
    "Asset added.": "گرافیک افزوده شد.",
    "Asset deleted.": "گرافیک حذف شد.",
    "Asset status changed.": "وضعیت گرافیک تغییر کرد.",
    "Asset updated.": "گرافیک به‌روزرسانی شد.",
    "Back": "پشت",
    "Back to designs": "بازگشت به طرح‌ها",
    "Base price": "قیمت پایه",
    "Base product": "محصول پایه",
    "Before the amount (Toman 350,000)": "قبل از مبلغ (تومان ۳۵۰,۰۰۰)",
    "Black": "مشکی",
    "Bring forward": "یک لایه بالا",
    "Calculating…": "در حال محاسبه…",
    "Cancel": "انصراف",
    "Category": "دسته",
    "Choose a 3D model (GLB/GLTF)": "انتخاب مدل سه‌بعدی (GLB/GLTF)",
    "Choose a model": "انتخاب مدل",
    "Choose an image": "انتخاب تصویر",
    "Choose from media library": "انتخاب از کتابخانه رسانه",
    "Classic T-Shirt": "تی‌شرت کلاسیک",
    "Color": "رنگ",
    "Color added.": "رنگ افزوده شد.",
    "Color deleted.": "رنگ حذف شد.",
    "Color updated.": "رنگ به‌روزرسانی شد.",
    "Colors": "رنگ‌ها",
    "Colors of “%s”": "رنگ‌های «%s»",
    "Could not load the 3D model.": "مدل سه‌بعدی بارگذاری نشد.",
    "Could not save the design.": "ذخیره طرح ممکن نشد.",
    "Create a model first.": "ابتدا یک مدل بسازید.",
    "Create area": "ساخت ناحیه",
    "Create model": "ساخت مدل",
    "Crew-neck short-sleeve t-shirt. Bundled 3D model with front, back and sleeve print areas.": "تی‌شرت آستین‌کوتاه یقه‌گرد. مدل سه‌بعدی همراه با ناحیه‌های چاپ جلو، پشت و آستین.",
    "Currency": "واحد پول",
    "Currency symbol / label": "نماد / برچسب واحد پول",
    "Custom texture": "بافت سفارشی",
    "Data": "داده‌ها",
    "Date": "تاریخ",
    "Decimal separator": "جداکننده اعشار",
    "Decimals": "ارقام اعشار",
    "Default model": "مدل پیش‌فرض",
    "Delete": "حذف",
    "Delete all plugin data (tables, settings) when the plugin is uninstalled": "حذف کامل داده‌های افزونه (جدول‌ها و تنظیمات) هنگام حذف افزونه",
    "Delete this model with its colors, sizes and print areas?": "این مدل به همراه رنگ‌ها، سایزها و ناحیه‌های چاپش حذف شود؟",
    "Description": "توضیحات",
    "Design": "طرح",
    "Design #%d": "طرح شمارهٔ %d",
    "Design Assets": "گرافیک‌های طراحی",
    "Design data (JSON)": "داده‌های طرح (JSON)",
    "Design deleted.": "طرح حذف شد.",
    "Design items must be at least %d cm wide and tall.": "ابعاد آیتم‌های طرح باید دست‌کم %d سانتی‌متر باشد.",
    "Design not found.": "طرح یافت نشد.",
    "Design saved!": "طرح ذخیره شد!",
    "Design tools": "ابزارهای طراحی",
    "Designs": "طرح‌ها",
    "Duplicate": "تکثیر",
    "Each print area maps a rectangular UV region of the 3D model. Artwork is painted into that region and follows the fabric when the model rotates.": "هر ناحیه چاپ به یک ناحیهٔ مستطیلی UV از مدل سه‌بعدی نگاشت می‌شود. گرافیک در همان ناحیه ترسیم می‌شود و با چرخش مدل روی پارچه می‌ماند.",
    "Edit": "ویرایش",
    "Edit asset": "ویرایش گرافیک",
    "Edit color": "ویرایش رنگ",
    "Edit model": "ویرایش مدل",
    "Edit print area": "ویرایش ناحیه چاپ",
    "Edit size": "ویرایش سایز",
    "Extra charge": "هزینه اضافی",
    "Extra charge added to the Nth item (N ≥ 2). If there is no rule for N, the highest defined rule applies.": "هزینه‌ای که به آیتم N-ام اضافه می‌شود (N ≥ 2). اگر برای N قانونی تعریف نشده باشد، بالاترین قانون تعریف‌شده اعمال می‌شود.",
    "Fabric texture": "بافت پارچه",
    "Fabric texture (optional)": "بافت پارچه (اختیاری)",
    "Fantasy": "فانتزی",
    "Final price = base product price + size modifier + print prices. Each printed item is priced by its size tier; the 2nd, 3rd, … item in the same area adds the configured extra charge. Prices are always recalculated on the server — values shown in the designer are for guidance only.": "قیمت نهایی = قیمت محصول پایه + تعدیل سایز + قیمت چاپ. هر آیتم چاپی بر اساس طبقهٔ اندازه‌اش قیمت می‌خورد؛ آیتم دوم، سوم و بعدی در یک ناحیه، هزینهٔ اضافهٔ تعریف‌شده را اضافه می‌کنند. قیمت‌ها همیشه روی سرور بازمحاسبه می‌شوند — مبالغ نمایش‌داده‌شده در طراحی فقط جنبهٔ راهنما دارند.",
    "Forbidden.": "دسترسی مجاز نیست.",
    'Format: {"uv_rect":[u0,v0,u1,v1], "camera":{"azimuth":0,"polar":78,"distance":1.55}} — uv_rect is the atlas region for this area (0-1 range), camera is the preset used when the area is selected.': 'قالب: {"uv_rect":[u0,v0,u1,v1], "camera":{"azimuth":0,"polar":78,"distance":1.55}} — مقدار uv_rect ناحیهٔ اطلس برای این ناحیه است (بازهٔ ۰ تا ۱) و camera پیش‌تنظیم دوربین هنگام انتخاب ناحیه است.',
    "From (cm)": "از (سانتی‌متر)",
    "Front": "جلو",
    "General settings": "تنظیمات عمومی",
    "Global": "سراسری",
    "Global (all areas)": "سراسری (همهٔ ناحیه‌ها)",
    "Green": "سبز",
    "Guest": "مهمان",
    "HEX": "HEX",
    "HEX color": "رنگ HEX",
    "How pricing works": "قیمت‌گذاری چگونه کار می‌کند",
    "Image added to the artwork.": "تصویر به گرافیک‌ها اضافه شد.",
    "Image file (PNG recommended)": "فایل تصویر (PNG پیشنهاد می‌شود)",
    "Inactive": "غیرفعال",
    "Initial model": "مدل اولیه",
    "Interactive 3D T-Shirt designer for your customers.": "طراح سه‌بعدی و تعاملی تی‌شرت برای مشتریان شما.",
    "Invalid design item type.": "نوع آیتم طرح نامعتبر است.",
    "Invalid nonce.": "مقدار امنیتی (nonce) نامعتبر است.",
    "Invalid print area contents.": "محتوای ناحیه چاپ نامعتبر است.",
    "Invalid upload payload.": "دادهٔ بارگذاری نامعتبر است.",
    "Invalid upload source.": "منبع بارگذاری نامعتبر است.",
    "Item #%d": "آیتم %d",
    "Item number": "شمارهٔ آیتم",
    "Item number (Nth item ≥ 2)": "شمارهٔ آیتم (آیتم N-ام ≥ ۲)",
    "JPG, PNG or WEBP — up to": "JPG، PNG یا WEBP — حداکثر",
    "Kids": "کودکانه",
    "Layers": "لایه‌ها",
    "Left": "چپ",
    "Left sleeve": "آستین چپ",
    "Linked WooCommerce product (optional)": "محصول ووکامرس متصل (اختیاری)",
    "Loading 3D model…": "در حال بارگذاری مدل سه‌بعدی…",
    "Logo": "لوگو",
    "Mapped": "نگاشت‌شده",
    "Max size": "حداکثر اندازه",
    "Maximum height (cm)": "حداکثر ارتفاع (سانتی‌متر)",
    "Maximum upload size (MB)": "حداکثر حجم بارگذاری (مگابایت)",
    "Maximum width (cm)": "حداکثر عرض (سانتی‌متر)",
    "Model": "مدل",
    "Model created.": "مدل ساخته شد.",
    "Model deleted.": "مدل حذف شد.",
    "Model not found.": "مدل یافت نشد.",
    "Model status changed.": "وضعیت مدل تغییر کرد.",
    "Model updated.": "مدل به‌روزرسانی شد.",
    "Model:": "مدل:",
    "Models": "مدل‌ها",
    "Name": "نام",
    "Name (e.g. S, M, L, XL)": "نام (مثلاً S، M، L و XL)",
    "Nature": "طبیعت",
    "Navy": "سرمه‌ای",
    "No assets in this category.": "در این دسته گرافیکی وجود ندارد.",
    "No colors yet.": "هنوز رنگی ثبت نشده است.",
    "No file was uploaded.": "فایلی بارگذاری نشد.",
    "No item rules yet.": "هنوز قانون آیتمی تعریف نشده است.",
    "No items on this area yet. Pick artwork or upload an image.": "هنوز آیتمی روی این ناحیه نیست. یک گرافیک انتخاب کنید یا تصویر بارگذاری کنید.",
    "No models yet — create your first one.": "هنوز مدلی وجود ندارد — اولین مدل را بسازید.",
    "No preview image was saved with this design.": "برای این طرح تصویر پیش‌نمایشی ذخیره نشده است.",
    "No pricing tier matches %d cm.": "هیچ طبقهٔ قیمتی با %d سانتی‌متر مطابقت ندارد.",
    "No print areas yet.": "هنوز ناحیه چاپی ثبت نشده است.",
    "No size tiers yet.": "هنوز طبقهٔ اندازه‌ای تعریف نشده است.",
    "No sizes yet.": "هنوز سایزی ثبت نشده است.",
    "None": "هیچ‌کدام",
    "Off": "خاموش",
    "On": "روشن",
    "Only JPG, JPEG, PNG and WEBP images are allowed.": "فقط تصاویر JPG، JPEG، PNG و WEBP مجاز هستند.",
    "Only JPG, PNG and WEBP images are allowed.": "فقط تصاویر JPG، PNG و WEBP مجاز هستند.",
    "Optional attributes: model=\"classic-tshirt\" or model=\"3\" preselects a model. A “T-Shirt Designer” block is also available in the block editor.": "اتریبیوت اختیاری: model=\"classic-tshirt\" یا model=\"3\" مدل را از پیش انتخاب می‌کند. بلوک «طراح تی‌شرت» هم در ویرایشگر بلوک در دسترس است.",
    "Other": "سایر",
    "Owner": "مالک",
    "Place the shortcode below on any page:": "شورت‌کد زیر را در هر صفحه‌ای قرار دهید:",
    "Please choose a valid color.": "لطفاً یک رنگ معتبر انتخاب کنید.",
    "Please choose a valid size.": "لطفاً یک سایز معتبر انتخاب کنید.",
    "Please enter a model name.": "لطفاً نام مدل را وارد کنید.",
    "Please log in to save designs.": "برای ذخیره طرح‌ها وارد حساب خود شوید.",
    "Please log in to upload images.": "برای بارگذاری تصویر وارد حساب خود شوید.",
    "Please provide a color name and a valid model.": "لطفاً نام رنگ و یک مدل معتبر وارد کنید.",
    "Please provide a name.": "لطفاً یک نام وارد کنید.",
    "Please provide a size name and a valid model.": "لطفاً نام سایز و یک مدل معتبر وارد کنید.",
    "Please provide an area name and a valid model.": "لطفاً نام ناحیه و یک مدل معتبر وارد کنید.",
    "Position / UV mapping (JSON)": "موقعیت / نگاشت UV (JSON)",
    "Preview": "پیش‌نمایش",
    "Preview image": "تصویر پیش‌نمایش",
    "Price": "قیمت",
    "Price breakdown": "تفکیک قیمت",
    "Price modifier": "تعدیل قیمت",
    "Pricing": "قیمت‌گذاری",
    "Pricing rule deleted.": "قانون قیمت‌گذاری حذف شد.",
    "Pricing rule saved.": "قانون قیمت‌گذاری ذخیره شد.",
    "Print Areas": "ناحیه‌های چاپ",
    "Print area": "ناحیه چاپ",
    "Print area created.": "ناحیه چاپ ساخته شد.",
    "Print area deleted.": "ناحیه چاپ حذف شد.",
    "Print area updated.": "ناحیه چاپ به‌روزرسانی شد.",
    "Print areas": "ناحیه‌های چاپ",
    "Print areas of “%s”": "ناحیه‌های چاپ «%s»",
    "Printed items": "آیتم‌های چاپی",
    "Prints": "چاپ‌ها",
    "Prints — %s": "چاپ — %s",
    "Red": "قرمز",
    "Remove": "حذف",
    "Remove item": "حذف آیتم",
    "Reset view": "بازنشانی نما",
    "Right": "راست",
    "Right sleeve": "آستین راست",
    "Rule type": "نوع قانون",
    "Save changes": "ذخیره تغییرات",
    "Save design": "ذخیره طرح",
    "Save settings": "ذخیره تنظیمات",
    "Saving…": "در حال ذخیره…",
    "Scope": "دامنه",
    "Scope:": "دامنه:",
    "Send backward": "یک لایه پایین",
    "Settings": "تنظیمات",
    "Settings saved.": "تنظیمات ذخیره شد.",
    "Size": "سایز",
    "Size added.": "سایز افزوده شد.",
    "Size affects order details and adds its price modifier to the base price.": "سایز در جزئیات سفارش اثر دارد و تعدیل قیمتش به قیمت پایه اضافه می‌شود.",
    "Size deleted.": "سایز حذف شد.",
    "Size surcharge": "هزینه اضافی سایز",
    "Size tier": "طبقه اندازه",
    "Size updated.": "سایز به‌روزرسانی شد.",
    "Size-based print pricing": "قیمت‌گذاری چاپ بر اساس اندازه",
    "Sizes": "سایزها",
    "Sizes of “%s”": "سایزهای «%s»",
    "Sort order": "ترتیب نمایش",
    "Sport": "ورزشی",
    "Status": "وضعیت",
    "Summary": "خلاصه",
    "Symbol position": "جایگاه نماد",
    "T-Shirt Designer": "طراح تی‌شرت",
    "T-Shirt Designer: WooCommerce is not active. The 3D designer works standalone; linking models to products and selling require WooCommerce.": "طراح تی‌شرت: ووکامرس فعال نیست. طراحی سه‌بعدی مستقل کار می‌کند؛ اتصال مدل‌ها به محصولات و فروش نیازمند ووکامرس است.",
    "T-shirt models": "مدل‌های تی‌شرت",
    "Text": "متن",
    "The bundled Classic T-Shirt model works out of the box. Custom models should use a \"TD_Fabric\" material and the atlas UV layout described in the plugin docs.": "مدل تی‌شرت کلاسیک همراه افزونه بدون هیچ تنظیمی کار می‌کند. مدل‌های سفارشی باید از متریال «TD_Fabric» و چیدمان اطلس UV مستندشده استفاده کنند.",
    "The file contents do not match its extension.": "محتوای فایل با پسوندش هم‌خوانی ندارد.",
    "The file could not be stored.": "ذخیره فایل ممکن نشد.",
    "The file is not a valid image.": "فایل یک تصویر معتبر نیست.",
    "The file is larger than the allowed size.": "حجم فایل بیشتر از حد مجاز است.",
    "The file is too large. Maximum allowed size is %s MB.": "حجم فایل زیاد است. حداکثر حجم مجاز %s مگابایت است.",
    "The interactive 3D designer runs on the live page. Preview it by viewing the published post.": "طراح سه‌بعدی تعاملی در صفحهٔ اصلی سایت اجرا می‌شود. برای پیش‌نمایش، نوشتهٔ منتشرشده را ببینید.",
    "The selected model is not available.": "مدل انتخاب‌شده در دسترس نیست.",
    "The tier is matched by the longest side of the artwork in centimeters. The first matching rule wins; area rules beat global rules.": "طبقه بر اساس بلندترین ضلع گرافیک بر حسب سانتی‌متر تعیین می‌شود. اولین قانون منطبق اعمال می‌شود؛ قوانین ناحیه بر قوانین سراسری اولویت دارند.",
    "The uploaded file is empty.": "فایل بارگذاری‌شده خالی است.",
    "This area": "این ناحیه",
    "This model has no 3D file yet.": "این مدل هنوز فایل سه‌بعدی ندارد.",
    "Thousands separator": "جداکننده هزارگان",
    "To (cm)": "تا (سانتی‌متر)",
    "Too many uploads. Please try again later.": "تعداد بارگذاری‌ها زیاد است. کمی بعد دوباره تلاش کنید.",
    "Total": "جمع کل",
    "Total price": "قیمت کل",
    "Type": "نوع",
    "UV mapping": "نگاشت UV",
    "Unknown page.": "صفحهٔ ناشناخته.",
    "Unknown print area in design.": "ناحیه چاپ ناشناخته در طرح.",
    "Upload image": "بارگذاری تصویر",
    "Uploading…": "در حال بارگذاری…",
    "Uploads": "بارگذاری‌ها",
    "Uploads per hour (per user/IP)": "بارگذاری در ساعت (به ازای هر کاربر/IP)",
    "Usage": "نحوه استفاده",
    "Use this file": "استفاده از این فایل",
    "View": "مشاهده",
    "When set, the product price is used as the base price.": "در صورت تنظیم، قیمت محصول به عنوان قیمت پایه استفاده می‌شود.",
    "White": "سفید",
    "Yellow": "زرد",
    "You are not allowed to do that.": "اجازه انجام این کار را ندارید.",
    "Your browser does not support WebGL, which is required for the 3D preview.": "مرورگر شما از WebGL پشتیبانی نمی‌کند؛ این قابلیت برای پیش‌نمایش سه‌بعدی لازم است.",
    "cm": "سانتی‌متر",
    "—": "—",
    "Draft": "پیش‌نویس",
    "Saved": "ذخیره‌شده",
    "Ordered": "سفارش‌داده‌شده",
    "Paid": "پرداخت‌شده",
    "In production": "در حال تولید",
    "No design selected.": "هیچ طرحی انتخاب نشده است.",
    "This design belongs to an order and cannot be deleted.": "این طرح به یک سفارش تعلق دارد و قابل حذف نیست.",
    "Custom Product Design": "طراحی محصول سفارشی",
    "This order could not be loaded.": "این سفارش بارگذاری نشد.",
    "This order does not contain any custom designs.": "این سفارش هیچ طرح سفارشی ندارد.",
    "Order not found.": "سفارش یافت نشد.",
    "Production status updated.": "وضعیت تولید به‌روزرسانی شد.",
    "Unknown action.": "عملیات نامعتبر است.",
    "Production file not found.": "فایل تولید یافت نشد.",
    "The production folder is not writable.": "پوشه تولید قابل نوشتن نیست.",
    "Production file is missing on disk.": "فایل تولید روی دیسک موجود نیست.",
    "There are no production files to download yet.": "هنوز فایل تولیدی برای دانلود وجود ندارد.",
    "Some production files could not be regenerated. Check the plugin log for details.": "برخی فایل‌های تولید بازسازی نشدند. برای جزئیات گزارش افزونه را ببینید.",
    "Print resolution saved.": "وضوح چاپ ذخیره شد.",
    "Custom Product Designer": "طراح محصول سفارشی",
    "Product Designer": "طراح محصول",
    "Product Types": "انواع محصول",
    "Design code": "کد طرح",
    "Version": "نسخه",
    "Product type": "نوع محصول",
    "Version history": "تاریخچه نسخه‌ها",
    "(current)": "(فعلی)",
    "Each version keeps its own immutable price snapshot. An order is always bound to the exact version that was purchased.": "هر نسخه تصویر قیمت تغییرناپذیر خود را نگه می‌دارد. هر سفارش همیشه به همان نسخه‌ای که خریداری شده متصل است.",
    "Search designs": "جست‌وجوی طرح‌ها",
    "Design code or ID…": "کد طرح یا شناسه…",
    "Search": "جست‌وجو",
    "User ID": "شناسه کاربر",
    "Order ID": "شناسه سفارش",
    "From": "از",
    "To": "تا",
    "Filter": "فیلتر",
    "Reset": "بازنشانی",
    "No designs match these filters.": "هیچ طرحی با این فیلترها مطابقت ندارد.",
    "#%1$d · version %2$d": "#%1$d · نسخه %2$d",
    "This design belongs to an order.": "این طرح به یک سفارش تعلق دارد.",
    "Locked": "قفل‌شده",
    "Delete this design permanently?": "این طرح برای همیشه حذف شود؟",
    "Production status": "وضعیت تولید",
    "Update": "به‌روزرسانی",
    "Download all print files (ZIP)": "دانلود همه فایل‌های چاپ (ZIP)",
    "Regenerate all production files from the order snapshot?": "همه فایل‌های تولید از روی تصویر سفارش بازسازی شوند؟",
    "Regenerate from snapshot": "بازسازی از تصویر سفارش",
    "Design preview": "پیش‌نمایش طرح",
    "No preview saved": "پیش‌نمایشی ذخیره نشده است",
    "version %d": "نسخه %d",
    "Print resolution": "وضوح چاپ",
    "Area": "ناحیه",
    "Print size": "اندازه چاپ",
    "Items": "آیتم‌ها",
    "Production file": "فایل تولید",
    "Download": "دانلود",
    "Not generated yet": "هنوز تولید نشده است",
    "Download %s": "دانلود %s",
    "Price breakdown (as charged)": "ریز قیمت (مطابق مبلغ دریافت‌شده)",
    "%s printing": "چاپ %s",
    "Unit total": "جمع واحد",
    "Download this item (ZIP)": "دانلود این آیتم (ZIP)",
    "Each product type owns its own models, colors, sizes, print areas, pricing rules and production settings. New printable products are registered in code through the \"cpd_product_types\" filter, so adding one never requires changing the designer core.": "هر نوع محصول مدل‌ها، رنگ‌ها، سایزها، نواحی چاپ، قوانین قیمت‌گذاری و تنظیمات تولید مخصوص خود را دارد. محصولات چاپی جدید از طریق فیلتر \"cpd_product_types\" در کد ثبت می‌شوند، بنابراین افزودن یک محصول هرگز نیازمند تغییر هسته طراح نیست.",
    "Print areas supported": "نواحی چاپ پشتیبانی‌شده",
    "Has sizes": "دارای سایز",
    "Print DPI": "DPI چاپ",
    "Yes": "بله",
    "No": "خیر",
    "Production files are rendered at physical print size × DPI. Leave a product type empty to use the global default.": "فایل‌های تولید بر اساس اندازه فیزیکی چاپ × DPI رندر می‌شوند. برای استفاده از مقدار پیش‌فرض سراسری، نوع محصول را خالی بگذارید.",
    "Default DPI": "DPI پیش‌فرض",
    "300 DPI is the usual choice for garment printing.": "معمولاً برای چاپ روی پوشاک از ۳۰۰ DPI استفاده می‌شود.",
    "%s DPI": "%s DPI",
    "A %1$s × %2$s cm print becomes %3$d × %4$d px at this resolution.": "یک چاپ %1$s × %2$s سانتی‌متری در این وضوح به %3$d × %4$d پیکسل تبدیل می‌شود.",
    "Add to cart": "افزودن به سبد خرید",
    "Adding to cart…": "در حال افزودن به سبد خرید…",
    "Added to your cart.": "به سبد خرید شما افزوده شد.",
    "Could not add the design to the cart.": "افزودن طرح به سبد خرید ممکن نشد.",
    "Add some artwork or text before continuing.": "پیش از ادامه، گرافیک یا متنی اضافه کنید.",
    "Add text": "افزودن متن",
    "Type some text first.": "ابتدا متنی بنویسید.",
    "Text is limited to 200 characters.": "متن حداکثر ۲۰۰ کاراکتر می‌تواند باشد.",
    "Text added to the print area.": "متن به ناحیه چاپ افزوده شد.",
    "Text updated.": "متن به‌روزرسانی شد.",
    "Update text": "به‌روزرسانی متن",
    "Pick a print area first.": "ابتدا یک ناحیه چاپ انتخاب کنید.",
    "WooCommerce is not available.": "ووکامرس در دسترس نیست.",
    "This design has no saved version yet.": "این طرح هنوز نسخه ذخیره‌شده‌ای ندارد.",
    "This model is not linked to a WooCommerce product yet.": "این مدل هنوز به هیچ محصول ووکامرس متصل نشده است.",
    "The linked product cannot be purchased right now.": "محصول متصل در حال حاضر قابل خرید نیست.",
    "Could not prepare the design for checkout.": "آماده‌سازی طرح برای تسویه‌حساب ممکن نشد.",
    "Could not add the product to your cart.": "افزودن محصول به سبد خرید ممکن نشد.",
    "%1$s (v%2$d)": "%1$s (نسخه %2$d)",
    "Classic Tote Bag": "کیف پارچه‌ای کلاسیک",
    "Canvas shopping tote with independent front and back print areas.": "کیف خرید کتان با نواحی چاپ مستقل جلو و پشت.",
    "Natural": "طبیعی",
    "Olive": "زیتونی",
    "One size": "تک‌سایز",
    "Text items need some text.": "آیتم متنی باید متن داشته باشد.",
    "You are not allowed to edit this design.": "شما اجازه ویرایش این طرح را ندارید.",
    "Designs attached to an order cannot be deleted.": "طرح‌های متصل به سفارش قابل حذف نیستند.",
    "The file could not be uploaded. Please try again.": "فایل بارگذاری نشد. لطفاً دوباره تلاش کنید.",
    "My Designs": "طرح‌های من",
    "This link has expired. Please try again.": "این پیوند منقضی شده است. لطفاً دوباره تلاش کنید.",
    "New": "جدید",
    "Ready for production": "آماده تولید",
    "Printed": "چاپ‌شده",
    "Quality check": "کنترل کیفیت",
    "Shipped": "ارسال‌شده",
    "Completed": "تکمیل‌شده",
    "Cancelled": "لغوشده",
    "You are not allowed to reorder this item.": "شما اجازه سفارش مجدد این آیتم را ندارید.",
    "Order item not found.": "آیتم سفارش یافت نشد.",
    "This item has no stored design.": "این آیتم هیچ طرح ذخیره‌شده‌ای ندارد.",
    "The product of this design is no longer available.": "محصول این طرح دیگر در دسترس نیست.",
    "The uploads directory is not writable.": "پوشه بارگذاری‌ها قابل نوشتن نیست.",
    "The GD image library is required to generate production files.": "برای تولید فایل‌های چاپ، کتابخانه تصویری GD لازم است.",
    "Could not allocate the print canvas.": "تخصیص بوم چاپ ممکن نشد.",
    "Could not write the production file.": "نوشتن فایل تولید ممکن نشد.",
    "Vazirmatn (Persian)": "وزیرمتن (فارسی)",
    "Sans (Latin)": "سنس (لاتین)",
    "Serif": "سریف",
    "Display": "نمایشی",
    "Your text": "متن شما",
    "Type something…": "چیزی بنویسید…",
    "Font": "قلم",
    "Style": "سبک",
    "Alignment": "تراز",
    "Center": "وسط",
    "Direction": "جهت",
    "Auto": "خودکار",
    "The design was duplicated.": "از طرح یک نسخه کپی ساخته شد.",
    "The design was deleted.": "طرح حذف شد.",
    "Ordering is unavailable right now.": "ثبت سفارش در حال حاضر در دسترس نیست.",
    "That action could not be completed.": "این عملیات انجام نشد.",
    "You have not saved any designs yet.": "هنوز هیچ طرحی ذخیره نکرده‌اید.",
    "Start designing": "شروع طراحی",
    "Product": "محصول",
    "Updated": "به‌روزرسانی",
    "Version %d": "نسخه %d",
    "Unavailable": "در دسترس نیست",
    "Order again": "سفارش مجدد",
    "Delete this design?": "این طرح حذف شود؟",

    # --- Phase 3: production workflow ---
    "You are not allowed to manage production.": "شما اجازه مدیریت تولید را ندارید.",
    "Production": "تولید",
    "That production job does not exist.": "این کار تولید وجود ندارد.",
    "Production job #%d": "کار تولید #%d",
    "Status updated.": "وضعیت به‌روزرسانی شد.",
    "Quality check recorded.": "کنترل کیفیت ثبت شد.",
    "Note added.": "یادداشت افزوده شد.",
    "The note could not be added.": "یادداشت افزوده نشد.",
    "Priority updated.": "اولویت به‌روزرسانی شد.",
    "That priority is not valid.": "این اولویت معتبر نیست.",
    "Manual regeneration from the dashboard.": "بازتولید دستی از داشبورد.",
    "Production files regenerated from the purchased snapshot.": "فایل‌های تولید از روی اسنپ‌شات خریداری‌شده بازتولید شدند.",
    "Production retried successfully.": "تلاش مجدد تولید با موفقیت انجام شد.",
    "Select at least one job and an action.": "حداقل یک کار و یک عملیات انتخاب کنید.",
    "Bulk action.": "عملیات گروهی.",
    "You are not allowed to download production files.": "شما اجازه دانلود فایل‌های تولید را ندارید.",
    "There are no production files to export for this job yet.": "هنوز فایل تولیدی برای خروجی گرفتن از این کار وجود ندارد.",
    "View production": "مشاهده تولید",
    "Back to production": "بازگشت به تولید",
    "Production failed:": "تولید ناموفق بود:",
    "Order": "سفارش",
    "(order not found)": "(سفارش یافت نشد)",
    "Customer": "مشتری",
    "Payment": "پرداخت",
    "Product &amp; design": "محصول و طرح",
    "(version %d)": "(نسخه %d)",
    "Note (required if the check fails)": "یادداشت (در صورت رد شدن الزامی است)",
    "Pass": "تأیید",
    "Fail — back to production": "رد — بازگشت به تولید",
    "Move to": "انتقال به",
    "Note (optional)": "یادداشت (اختیاری)",
    "Update status": "به‌روزرسانی وضعیت",
    "This job has reached a final state and can no longer change.": "این کار به وضعیت نهایی رسیده و دیگر قابل تغییر نیست.",
    "Priority": "اولویت",
    "Set": "ثبت",
    "Print areas &amp; production files": "نواحی چاپ و فایل‌های تولید",
    "Download all (ZIP)": "دانلود همه (ZIP)",
    "Reason (optional)": "دلیل (اختیاری)",
    "Retry production": "تلاش مجدد تولید",
    "Dimensions": "ابعاد",
    "Pixels": "پیکسل",
    "DPI": "DPI",
    "File": "فایل",
    "This job has no stored design areas.": "برای این کار هیچ ناحیه طرحی ذخیره نشده است.",
    "Not designed": "طراحی نشده",
    "Not generated": "تولید نشده",
    "Missing on disk": "روی دیسک موجود نیست",
    "Ready": "آماده",
    "PNG": "PNG",
    "Notes": "یادداشت‌ها",
    "Note": "یادداشت",
    "e.g. Needs a colour check before printing": "مثلاً: پیش از چاپ نیاز به بررسی رنگ دارد",
    "Add note": "افزودن یادداشت",
    "Activity log": "گزارش فعالیت",
    "%1$s → %2$s": "%1$s ← %2$s",
    "Search production": "جست‌وجوی تولید",
    "Order, customer, email, design or job ID": "سفارش، مشتری، ایمیل، طرح یا شناسه کار",
    "All product types": "همه انواع محصول",
    "All models": "همه مدل‌ها",
    "Any priority": "هر اولویتی",
    "Newest first": "جدیدترین اول",
    "Oldest first": "قدیمی‌ترین اول",
    "Bulk action": "عملیات گروهی",
    "Bulk actions": "عملیات گروهی",
    "Mark as %s": "علامت‌گذاری به‌عنوان %s",
    "Apply": "اعمال",
    "Job": "کار",
    "No production jobs match these filters.": "هیچ کار تولیدی با این فیلترها مطابقت ندارد.",
    "&laquo;": "&laquo;",
    "&raquo;": "&raquo;",
    "Production job not found.": "کار تولید یافت نشد.",
    "A note is required when a quality check fails.": "در صورت رد شدن کنترل کیفیت، ثبت یادداشت الزامی است.",
    "Someone else changed this job first — it is now %s. Reload and try again.": "شخص دیگری زودتر این کار را تغییر داده است — اکنون %s است. صفحه را بارگذاری کنید و دوباره تلاش کنید.",
    "This job is not awaiting a quality check.": "این کار در انتظار کنترل کیفیت نیست.",
    "Quality check passed.": "کنترل کیفیت تأیید شد.",
    "Quality check failed.": "کنترل کیفیت رد شد.",
    "Priority set to %s.": "اولویت روی %s تنظیم شد.",
    "This job has no stored design snapshot, so no print files can be produced.": "این کار اسنپ‌شات طرح ذخیره‌شده ندارد، بنابراین فایل چاپی تولید نمی‌شود.",
    "Manual regeneration.": "بازتولید دستی.",
    "Retry after failure.": "تلاش مجدد پس از خطا.",
    "Recovered by retry.": "با تلاش مجدد بازیابی شد.",
    "That production file does not exist.": "این فایل تولید وجود ندارد.",
    "That file does not belong to this production job.": "این فایل متعلق به این کار تولید نیست.",
    "The production directory is unavailable.": "پوشه تولید در دسترس نیست.",
    "The production file is missing. Regenerate it and try again.": "فایل تولید موجود نیست. آن را بازتولید کنید و دوباره تلاش کنید.",
    "That file is outside the production directory.": "این فایل خارج از پوشه تولید است.",
    "Packed": "بسته‌بندی‌شده",
    "Production error": "خطای تولید",
    "Normal": "عادی",
    "High": "بالا",
    "Urgent": "فوری",
    "That production status does not exist.": "این وضعیت تولید وجود ندارد.",
    "This job has an unrecognised status.": "وضعیت این کار ناشناخته است.",
    "The job already has that status.": "این کار هم‌اکنون در همین وضعیت است.",
    "This job is %s and can no longer change.": "این کار %s است و دیگر قابل تغییر نیست.",
    "A job cannot go from %1$s to %2$s.": "یک کار نمی‌تواند از %1$s به %2$s منتقل شود.",
    "The note cannot be empty.": "یادداشت نمی‌تواند خالی باشد.",
}

# ----------------------------------------------------------------------------
# Extraction
# ----------------------------------------------------------------------------

CALL_RE = re.compile(
    r"""(?P<func>__|_e|esc_html__|esc_attr__|esc_html_e|esc_attr_e)\(\s*'(?P<msg>(?:[^'\\]|\\.)*)'\s*,\s*'tshirt-designer'""",
)
COMMENT_RE = re.compile(r"/\*\*\s*translators:\s*(?P<text>.*?)\s*\*/", re.S)


def php_unescape(s: str) -> str:
    return s.replace("\\'", "'").replace('\\\\', '\\').replace('\\"', '"')


def po_escape(s: str) -> str:
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\t', '\\t')


def extract():
    """Return {msg: {'refs': [..], 'comments': [..]}} in file order."""
    catalog = {}

    for path in sorted(PLUGIN.rglob("*.php")):
        rel = path.relative_to(PLUGIN)
        if "vendor" in rel.parts:
            continue
        text = path.read_text(encoding="utf-8")

        for m in CALL_RE.finditer(text):
            msg = php_unescape(m.group("msg"))
            entry = catalog.setdefault(msg, {"refs": [], "comments": []})
            line = text.count("\n", 0, m.start()) + 1
            entry["refs"].append(f"{rel}:{line}")

            # Look behind for a translators comment.
            before = text[: m.start()]
            cm = None
            for cm in COMMENT_RE.finditer(before):
                pass
            if cm:
                entry["comments"].append(" ".join(cm.group("text").split()))

    return catalog


# ----------------------------------------------------------------------------
# PO / POT / MO writers
# ----------------------------------------------------------------------------


def po_header(language: str = "") -> str:
    now = time.strftime("%Y-%m-%d %H:%M+0000", time.gmtime())
    lang_line = f'"Language: {language}\\n"\n' if language else ""
    return (
        f'# Translation template for the T-Shirt Designer plugin.\n'
        f'msgid ""\n'
        f'msgstr ""\n'
        f'"Project-Id-Version: T-Shirt Designer 1.0.0\\n"\n'
        f'"Report-Msgid-Bugs-To: https://github.com/kamandbeauty/Ideal/issues\\n"\n'
        f'"POT-Creation-Date: {now}\\n"\n'
        f'"PO-Revision-Date: {now}\\n"\n'
        f'{lang_line}'
        f'"MIME-Version: 1.0\\n"\n'
        f'"Content-Type: text/plain; charset=UTF-8\\n"\n'
        f'"Content-Transfer-Encoding: 8bit\\n"\n'
        f'"Plural-Forms: nplurals=2; plural=(n > 1);\\n"\n'
    )


def write_po(path: Path, catalog: dict, translations: dict | None, language: str = "") -> None:
    out = [po_header(language)]
    for msg, entry in catalog.items():
        out.append("\n")
        for ref in entry["refs"]:
            out.append(f"#: {ref}\n")
        for comment in dict.fromkeys(entry["comments"]):
            out.append(f"#. {comment}\n")
        out.append(f'msgid "{po_escape(msg)}"\n')
        if translations is None:
            out.append('msgstr ""\n')
        else:
            out.append(f'msgstr "{po_escape(translations.get(msg, ""))}"\n')
    path.write_text("".join(out), encoding="utf-8")


def mo_metadata(language: str = "fa_IR") -> str:
    """Metadata block for the .mo entry with an empty msgid.

    This is the plain 'Key: value\n' form gettext expects - not the quoted
    PO syntax that po_header() produces.
    """
    now = time.strftime("%Y-%m-%d %H:%M+0000", time.gmtime())
    return (
        "Project-Id-Version: T-Shirt Designer 1.0.0\n"
        f"POT-Creation-Date: {now}\n"
        f"PO-Revision-Date: {now}\n"
        f"Language: {language}\n"
        "MIME-Version: 1.0\n"
        "Content-Type: text/plain; charset=UTF-8\n"
        "Content-Transfer-Encoding: 8bit\n"
        "Plural-Forms: nplurals=2; plural=(n > 1);\n"
    )


def write_mo(path: Path, catalog: dict, translations: dict) -> None:
    """Minimal GNU .mo writer (hash table omitted)."""
    # The entry with an empty msgid carries the catalog metadata. Without it
    # gettext readers cannot determine the charset, and WordPress rejects the
    # whole file, so every translation silently falls back to English.
    pairs = [(b"", mo_metadata().encode("utf-8"))]

    for msg in catalog:
        translated = translations.get(msg, "")
        if not translated:
            continue        # an empty translation just means "use the original"
        pairs.append((msg.encode("utf-8"), translated.encode("utf-8")))

    pairs.sort(key=lambda p: p[0])

    n = len(pairs)
    header_size = 7 * 4
    ktable_at = header_size          # original string table
    vtable_at = header_size + 8 * n  # translation string table
    keystart = header_size + 16 * n  # ids blob
    valuestart = keystart + sum(len(src) + 1 for src, _ in pairs)

    ids = b"".join(src + b"\x00" for src, _ in pairs)
    strs = b"".join(dst + b"\x00" for _, dst in pairs)

    koffsets = []
    voffsets = []
    ipos = keystart
    vpos = valuestart
    for src, dst in pairs:
        # A .mo string descriptor is (length, offset) - in that order. Writing
        # them the other way round produces a file every gettext reader
        # rejects, which is why the Persian catalog never loaded.
        koffsets += [len(src), ipos]
        voffsets += [len(dst), vpos]
        ipos += len(src) + 1
        vpos += len(dst) + 1

    output = struct.pack(
        "Iiiiiii",
        0x950412DE,  # magic
        0,           # revision
        n,           # count
        ktable_at,   # original table offset
        vtable_at,   # translation table offset
        0,           # hash size (no hash table)
        # Even with an empty hash table the offset must point just past the
        # two index tables: readers derive the translation table's size from
        # hash_addr - translations_addr, so leaving it at 0 makes that length
        # negative and the file is rejected.
        keystart,    # hash offset
    )
    output += struct.pack(f"{2 * n}i", *koffsets)
    output += struct.pack(f"{2 * n}i", *voffsets)
    output += ids + strs

    path.write_bytes(output)


def main() -> None:
    LANG_DIR.mkdir(parents=True, exist_ok=True)
    catalog = extract()
    print(f"extracted {len(catalog)} strings")

    write_po(LANG_DIR / "tshirt-designer.pot", catalog, None)
    print(f"wrote {LANG_DIR / 'tshirt-designer.pot'}")

    missing = [m for m in catalog if m not in FA]
    unused = [m for m in FA if m not in catalog]

    write_po(
        LANG_DIR / "tshirt-designer-fa_IR.po",
        catalog,
        FA,
        language="fa_IR",
    )
    write_mo(LANG_DIR / "tshirt-designer-fa_IR.mo", catalog, FA)
    print(f"wrote {LANG_DIR / 'tshirt-designer-fa_IR.po'} + .mo")

    if missing:
        print(f"\nMISSING fa translations ({len(missing)}):")
        for m in missing:
            print(f"  - {m[:80]}")
    if unused:
        print(f"\nunused fa entries ({len(unused)}):")
        for m in unused:
            print(f"  - {m[:80]}")
    if not missing and not unused:
        print("fa_IR coverage: 100%")


if __name__ == "__main__":
    main()
