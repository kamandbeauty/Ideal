class_name Loc
extends RefCounted
## Persian-first UI strings. Every player-facing caption lives here so the menu
## layer never hard-codes copy and a test can assert nothing ships untranslated.
##
## Persian is RTL: widgets set Control.LAYOUT_DIRECTION_RTL and labels use
## TextServer.DIRECTION_AUTO so mixed Latin/numeric runs still shape correctly.

const FA_DIGITS: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

const STRINGS: Dictionary = {
	# ---- shared -------------------------------------------------------
	"back": "بازگشت",
	"confirm": "تأیید",
	"cancel": "انصراف",
	"locked": "قفل‌شده",
	"enabled": "روشن",
	"disabled": "خاموش",
	"credits": "اعتبار",
	"stars": "ستاره",
	"points": "امتیاز ارتقا",
	"offline": "آفلاین",
	"ready": "آماده",
	"empty": "خالی",
	"reloading": "در حال پرکردن",
	"loading": "در حال بارگذاری",
	# ---- splash / home ------------------------------------------------
	"game_title": "توپخانهٔ خط مقدم",
	"home_title": "توپخانهٔ\nخط مقدم",
	"game_subtitle": "فرماندهی دفاع ساحلی",
	"splash_boot": "راه‌اندازی سامانهٔ کنترل آتش",
	"splash_offline": "عملیات آفلاین",
	"brand": "ستاد فرماندهی خط مقدم",
	"home_kicker": "عملیات موج‌شکن · دفاع از ساحل",
	"home_tagline": "ساحل را نگه دار. سلاح‌های سنگین در برابر موج‌های پیاده‌شدهٔ دشمن.",
	"home_note": "سه‌بعدی · تک‌نفره · بدون اینترنت",
	"home_directory": "فهرست فرماندهی",
	"home_deploy": "اعزام به دفاع ساحلی",
	"home_deploy_hint": "مأموریت اصلی · موج‌شکن",
	"home_campaign": "کارزار توپخانه",
	"home_campaign_hint": "گذرگاه ریج · پنج عملیات",
	"home_map": "نقشهٔ کارزار",
	"home_map_hint": "وضعیت بخش‌ها و ستاره‌ها",
	"home_arsenal": "جنگ‌افزار و ارتقا",
	"home_arsenal_hint": "توپخانه، مهمات و بهبودها",
	"home_settings": "تنظیمات",
	"home_settings_hint": "گرافیک، صدا و کنترل",
	"home_footer": "نسخهٔ ۰.۱.۰   ·   بدون تبلیغات   ·   بدون خرید درون‌برنامه‌ای   ·   بدون نیاز به شبکه",
	# ---- campaign -----------------------------------------------------
	"campaign_title": "کارزار / گذرگاه ریج",
	"campaign_intel": "اطلاعات منطقه",
	"campaign_body": "یک پادگان دورافتاده در دل کویر، گذرگاه کوهستانی را در اختیار دارد. پنج عملیات پیاپی مسیر رسیدن به خط‌الرأس را می‌گشاید.",
	"campaign_stars_note": "در هر عملیات تا سه ستاره بگیر. نخستین پیروزی امتیاز ارتقا می‌دهد؛ تکرار مرحله رکوردت را بهتر می‌کند.",
	"campaign_progress": "%s از %s عملیات\n%s از %s ستاره\n%s امتیاز ارتقا",
	"campaign_sector": "گذرگاه ریج / بخش تاکتیکی ۰۷",
	"north": "شمال",
	"sector": "بخش",
	"campaign_coords": "۳۴° ۱۸′ شمالی   ۴۱° ۰۷′ شرقی     •     کارزار آفلاین",
	"campaign_locked": "%s  قفل‌شده",
	"campaign_star_count": "%s از ۳ ستاره",
	# ---- briefing -----------------------------------------------------
	"briefing_title": "شرح مأموریت",
	"briefing_objectives": "اهداف اصلی",
	"briefing_neutralize": "انهدام %s",
	"briefing_optional": "اختیاری  /  انهدام %s برای دریافت نشان",
	"briefing_supply": "منفجرشونده %s   /   ضدزره %s      زمان %s      پاداش پایه %s اعتبار",
	"briefing_deploy": "اعزام توپخانه",
	"briefing_arsenal": "بازبینی جنگ‌افزار",
	# ---- arsenal ------------------------------------------------------
	"arsenal_title": "جنگ‌افزار / انتخاب توپخانه",
	"arsenal_kicker": "توپخانهٔ صحرایی / ۰۱",
	"arsenal_name": "کسترل\nام-۴۲",
	"arsenal_body": "هویتزر کششی ۱۵۵ میلی‌متری. کالسکهٔ دوشاخه، چرخش و ارتفاع‌گیری مستقل، عقب‌نشینی هیدروپنوماتیک و پرکردن کمکی.",
	"arsenal_equip": "تجهیز کسترل ام-۴۲",
	"arsenal_equipped": "کسترل ام-۴۲ تجهیز شد",
	"arsenal_performance": "کارایی سلاح",
	"arsenal_ammo": "ام۷۲ منفجرشونده · شعاع انفجار ۱۷ متر\nام۹۱ ضدزره · نفوذگر پرسرعت\nهر دو نوع مهمات در این نسخه در دسترس است.",
	"arsenal_mods": "بهبودهای میدانی",
	"arsenal_stats": "قدرت تخریب    %s٪\nسرعت دهانه  %s م/ث\nزمان پرکردن   %s ثانیه\nپراکندگی        %s درجه\nخشاب صحرایی   +%s گلوله",
	# ---- upgrades -----------------------------------------------------
	"upgrades_title": "بهبودهای میدانی",
	"upgrades_body": "ارتقاهای دائمی و آفلاین. هر سطح مقداری اعتبار و یک امتیاز ارتقا مصرف می‌کند که از نخستین پیروزی‌ها به دست می‌آید.",
	"upgrades_level": "سطح %s از %s",
	"upgrades_maxed": "بیشینه",
	"upgrades_install": "نصب  /  %s اعتبار + %s امتیاز",
	# ---- settings -----------------------------------------------------
	"settings_title": "پیکربندی سامانه",
	"settings_quality": "پروفایل گرافیک",
	"settings_quality_note": "حالت خودکار از نرخ فریم محافظت می‌کند؛ حالت سینمایی عمق میدان را اضافه می‌کند",
	"settings_fps": "نرخ فریم هدف",
	"settings_fps_note": "شبیه‌سازی بازی روی ۶۰ هرتز ثابت می‌ماند",
	"settings_sensitivity": "حساسیت نشانه‌گیری",
	"settings_sensitivity_note": "ضریب کشیدن با لمس و ماوس",
	"settings_master": "بلندی صدای اصلی",
	"settings_master_note": "تمام صداهای بازی",
	"settings_sfx": "بلندی صدای جلوه‌ها",
	"settings_sfx_note": "سلاح، پرکردن و برخورد",
	"settings_ambient": "بلندی صدای محیط",
	"settings_ambient_note": "منظرهٔ صوتی باد کویر",
	"settings_shake": "لرزش دوربین",
	"settings_shake_note": "بازخورد کنترل‌شدهٔ عقب‌نشینی و برخورد",
	"settings_autoreload": "پرکردن خودکار",
	"settings_autoreload_note": "پس از شلیک گلولهٔ بعدی را می‌گذارد؛ پرکردن دستی هم در دسترس است",
	"settings_drag": "مقاومت پیشرفتهٔ هوا",
	"settings_drag_note": "پسای خطی اختیاری، مشترک میان پیش‌بینی و گلولهٔ واقعی",
	"settings_perf": "نمایش کارایی",
	"settings_perf_note": "نرخ فریم، تعداد فراخوانی رسم، وضوح و سطح کیفیت",
	"settings_footer": "موبایل: رندر ولکان · بستهٔ سازگاری اوپن‌جی‌ال هم موجود است. تنظیمات به‌صورت محلی ذخیره می‌شود.",
	"quality_auto": "خودکار / تطبیقی",
	"quality_low": "کم / کارایی",
	"quality_medium": "متوسط / متعادل",
	"quality_high": "بالا / کیفیت",
	"quality_ultra": "فوق / سینمایی",
	"fps_60": "۶۰ فریم / روان",
	"fps_30": "۳۰ فریم / کم‌مصرف",
	# ---- pause / results ----------------------------------------------
	"pause_title": "عملیات متوقف شد",
	"pause_body": "شبیه‌سازی و ساعت مأموریت معلق است.",
	"pause_resume": "ادامهٔ عملیات",
	"pause_restart": "شروع دوبارهٔ مأموریت",
	"pause_abort": "بازگشت به ستاد",
	"results_success": "بخش پاک‌سازی شد",
	"results_failure": "عملیات ناموفق",
	"results_stats": "دقت اصابت    %s٪\nگلولهٔ شلیک‌شده             %s\nاهداف اصلی  %s از %s\nزمان مأموریت              %s\nنشان اختیاری  %s",
	"results_earned": "دریافت شد",
	"results_not_earned": "دریافت نشد",
	"results_rewards": "+ %s اعتبار    /    + %s امتیاز ارتقا",
	"results_next": "عملیات بعدی",
	"results_replay": "تکرار",
	"results_command": "ستاد",
	# ---- gameplay HUD -------------------------------------------------
	"hud_primary": "اهداف اصلی  %s از %s",
	"hud_bearing": "سمت مغناطیسی",
	"hud_elevation": "زاویهٔ ارتفاع",
	"hud_breech": "وضعیت گلنگدن",
	"hud_observer": "دیده‌بان / کشف هدف",
	"hud_next_target": "هدف بعدی",
	"hud_fire_control": "کنترل آتش",
	"hud_pause": "توقف",
	"hud_predicted": "پیش‌بینی  %s متر  /  %s ثانیه",
	"hud_gun": "کسترل ام-۴۲  /  ۱۵۵ میلی‌متر",
	"hud_drag_hint": "برای نشانه‌گیری بکش  ·  ۱ / ۲ انتخاب گلوله",
	"hud_fire": "شلیک",
	"hud_reload": "پرکردن",
	"hud_reload_time": "پرکردن  %s ثانیه",
	"hud_camera": "دوربین / %s",
	"hud_zoom": "بزرگ‌نمایی",
	"hud_local_save": "آفلاین / ذخیرهٔ محلی",
	"hud_impact": "برخورد",
	"hud_perf": "%s فریم  /  %s\n%s رسم  /  %s٪ وضوح  /  %s گره",
	"hud_shell_he": "منفجر",
	"hud_shell_ap": "ضدزره",
	"camera_gun": "توپ",
	"camera_optic": "دوربین نشانه‌روی",
	"camera_shell": "گلوله",
	"camera_observer": "دیده‌بان",
	"camera_overhead": "بالاسر",
	# ---- coastal HUD --------------------------------------------------
	"coastal_autofire": "شلیک خودکار",
	"coastal_headshot": "سر!",
	"coastal_boss": "تانک بوس",
	"coastal_threat_ahead": "تهدید روبه‌رو",
	"coastal_threat_left": "تهدید از چپ <<",
	"coastal_threat_right": ">> تهدید از راست",
	"coastal_threat_distance": "تهدید روبه‌رو  %s متر",
	"coastal_next_wave": "موج بعدی تا %s ثانیه",
	"coastal_title": "موج‌شکن / %s",
	"coastal_default_label": "دفاع ساحلی",
	"coastal_enemies": "دشمن  %s",
	"coastal_round": "موج %s از %s",
	"coastal_health": "سنگر %s از %s",
	"coastal_ammo": "%s از %s",
	"coastal_reserve": "ذخیره %s",
	"coastal_reload": "پرکردن",
	"coastal_rocket": "راکت",
	"coastal_zoom": "بزرگ‌نمایی",
	"coastal_fire": "شلیک",
	"coastal_weapon": "سلاح",
	"coastal_pause_title": "توقف / تنظیمات",
	"coastal_resume": "ادامه",
	"coastal_restart": "شروع دوباره",
	"coastal_exit": "بازگشت به ستاد",
	"coastal_held": "ساحل حفظ شد",
	"coastal_lost": "سنگر سقوط کرد",
	"coastal_result_body": "موج‌های دفع‌شده: %s\nدشمن از پا درآمده: %s\nزمان: %s ثانیه",
	"coastal_replay": "تکرار مرحله",
	"coastal_support_repair": "تعمیر",
	"coastal_support_airstrike": "حملهٔ هوایی",
	"coastal_support_crate": "مهمات",
	"coastal_support_helicopter": "بالگرد",
	"coastal_support_jet": "جت",
	"coastal_support_barrage": "آتشبار",
	"coastal_seconds": "%s ثانیه",
	# ---- toasts -------------------------------------------------------
	"toast_locked": "برای باز شدن، عملیات پیشین را کامل کن",
	"toast_storage": "حافظه در دسترس نیست — پیشرفت ذخیره نشد",
	"save_recovered": "نسخهٔ پشتیبان بازیابی شد. آخرین پیشرفت سالم شما محفوظ است.",
	"upgrade_installed": "بهبود نصب شد",
	"upgrade_insufficient": "اعتبار یا امتیاز ارتقا کافی نیست",
	# ---- battle notices / result reasons ------------------------------
	"notice_intro": "برای نشانه‌گیری بکش  •  کنترل آتش یک حل محاسبه‌شده می‌دهد",
	"notice_acquired": "هدف کشف شد  /  %s",
	"notice_limits": "هدف بیرون از محدودیت توپ است — چرخش را تنظیم کن",
	"notice_solution": "کنترل آتش تنظیم شد  /  ارتفاع %s درجه  /  پرواز %s ثانیه",
	"notice_incompatible": "مهمات با این سلاح سازگار نیست",
	"notice_fire_limit": "سقف شلیک هم‌زمان — منتظر برخورد بمان",
	"notice_breech": "گلنگدن آماده نیست",
	"notice_select_ammo": "نوع مهماتی را انتخاب کن که گلولهٔ باقی‌مانده دارد",
	"notice_no_rounds": "از این نوع گلوله‌ای باقی نمانده",
	"notice_direct": "اصابت مستقیم  /  %s آسیب",
	"notice_neutralized": "هدف منهدم شد  /  %s",
	"notice_optional": "هدف اختیاری کامل شد  /  انبار تدارکات منهدم شد",
	"reason_success": "همهٔ اهداف اصلی منهدم شدند",
	"reason_time": "زمان مأموریت پایان یافت",
	"reason_ammo": "مهمات تمام شد و اهداف کامل نشدند",
	"reason_abandoned": "مأموریت رها شد",
	"reason_battery": "آتشبار منهدم شد؛ مأموریت شکست خورد",
	"notice_battery_hit": "آتشبار آسیب دید؛ %s٪ جان باقی مانده",
	"notice_battery_lost": "آتشبار منهدم شد",
	"no_target": "هدفی انتخاب نشده",
}

## Weapon and target identifiers stay ASCII in data; only display is localised.
const KINDS: Dictionary = {
	"watchtower": "برج دیده‌بانی",
	"bunker": "سنگر",
	"radar": "رادار",
	"fuel": "مخزن سوخت",
	"ammo": "انبار مهمات",
	"crate": "جعبهٔ تدارکات",
	"command": "پست فرماندهی",
	"gun": "توپ",
	"artillery": "توپخانه",
	"truck": "کامیون",
	"tank": "تانک",
	"apc": "نفربر",
	"boat": "قایق",
	"craft": "ناوچه",
	"helicopter": "بالگرد",
	"jet": "جت",
	"soldier": "سرباز",
	"infantry": "پیاده‌نظام",
	"depot": "انبار",
	"post": "پست",
	"battery": "آتشبار",
	"relay": "رله",
	"bridge": "پل",
	"convoy": "کاروان",
}


const TARGETS: Dictionary = {
	"t01": "برج دیده‌بانی جنوبی",
	"t02": "تانک واردن",
	"t03": "نفربر نومد",
	"t04": "تانک اسکورت",
	"t05": "سنگر شرقی",
	"t06": "کامیون تدارکات",
	"crate01": "انبار تدارکات",
	"crate02": "انبار تدارکات",
	"crate03": "انبار تدارکات",
	"crate04": "انبار تدارکات",
	"crate05": "مخزن سوخت",
}

const WAVES: Dictionary = {
	"FIRST LANDING": "نخستین پیاده‌سازی",
	"ARMORED PUSH": "پیشروی زرهی",
	"FINAL ASSAULT": "یورش نهایی",
	"COASTAL DEFENSE": "دفاع ساحلی",
}


const STATES: Dictionary = {"READY": "ready", "RELOADING": "reloading", "EMPTY": "empty"}
const CAMERAS: Dictionary = {"GUN": "camera_gun", "OPTIC": "camera_optic", "SHELL": "camera_shell", "IMPACT": "hud_impact"}
const SUPPORTS: Dictionary = {"repair": "coastal_support_repair", "airstrike": "coastal_support_airstrike", "helicopter": "coastal_support_helicopter", "airdrop": "coastal_support_crate"}


static func sector(code: String) -> String:
	if code.length() > 1:
		return t("sector") + " " + number(int(code.substr(1)))
	return code


static func state(id: String) -> String:
	return t(String(STATES.get(id, "ready")))


static func camera(id: String) -> String:
	return t(String(CAMERAS.get(id, "camera_gun")))


static func support(id: String) -> String:
	return t(String(SUPPORTS.get(id, "coastal_support_barrage")))


static func target_name(id: String) -> String:
	return String(TARGETS.get(id, kind(id)))


static func wave(label: String) -> String:
	return String(WAVES.get(label, label))


static func t(key: String) -> String:
	## Missing keys return the key itself so an untranslated string is visible
	## in review rather than silently rendering blank.
	return String(STRINGS.get(key, key))


static func digits(value: String) -> String:
	## Persian numerals for player-facing counts. Latin stays in technical IDs.
	var out: String = value
	for index in range(10):
		out = out.replace(str(index), FA_DIGITS[index])
	return out


static func number(value: int) -> String:
	return digits(str(value))


static func decimal(value: float, places: int = 1) -> String:
	return digits(("%." + str(places) + "f") % value)


static func clock(seconds: float) -> String:
	var total: int = int(seconds)
	return digits("%02d:%02d" % [int(total / 60.0), total % 60])


static func kind(id: String) -> String:
	## Fall back to a spaced, capitalised identifier for unmapped target kinds.
	var lower: String = id.to_lower()
	if KINDS.has(lower):
		return String(KINDS[lower])
	for key in KINDS:
		if key in lower:
			return String(KINDS[key])
	return id.replace("_", " ")


static func is_persian(text: String) -> bool:
	for index in text.length():
		var code: int = text.unicode_at(index)
		# Arabic block + Arabic Presentation Forms cover written Persian.
		if (code >= 0x0600 and code <= 0x06FF) or (code >= 0xFB50 and code <= 0xFDFF) or (code >= 0xFE70 and code <= 0xFEFF):
			return true
	return false
