class_name Loc
extends RefCounted
## Two-language text table. Persian is the default; digits follow the language.

const DIGITS_FA: String = "۰۱۲۳۴۵۶۷۸۹"
const TEXT: Dictionary = {
	"en": {
		"title": "LAST WALL",
		"subtitle": "ZOMBIE SIEGE",
		"tagline": "Hold the gate. The city is behind you.",
		"play": "DEFEND THE WALL",
		"settings": "SETTINGS",
		"resume": "RESUME",
		"restart": "RESTART",
		"main_menu": "MAIN MENU",
		"paused": "PAUSED",
		"back": "BACK",
		"language": "Language",
		"language_name": "English",
		"sensitivity": "Aim sensitivity",
		"invert_y": "Invert vertical aim",
		"left_handed": "Left-handed layout",
		"master_volume": "Master volume",
		"sfx_volume": "Effects volume",
		"music_volume": "Music volume",
		"quality": "Graphics quality",
		"quality_auto": "Auto",
		"quality_low": "Low",
		"quality_medium": "Medium",
		"quality_high": "High",
		"show_fps": "Show frame rate",
		"wave": "WAVE %s / %s",
		"wave_incoming": "WAVE %s",
		"wave_cleared": "WAVE CLEARED",
		"next_wave": "Next wave in %s",
		"get_ready": "GET READY",
		"wall": "WALL",
		"gate": "GATE",
		"hostiles": "HOSTILES %s",
		"kills": "KILLS",
		"headshots": "HEADSHOTS",
		"accuracy": "ACCURACY",
		"time": "TIME",
		"waves_held": "WAVES HELD",
		"wall_left": "WALL INTEGRITY",
		"fire": "FIRE",
		"reload": "RELOAD",
		"reloading": "RELOADING",
		"weapon_twin_hmg": "TWIN HMG",
		"weapon_rpg": "RPG LAUNCHER",
		"grenade": "GRENADE",
		"out_of_rockets": "NO ROCKETS LEFT",
		"resupply_rockets": "+%s ROCKETS",
		"resupply_grenades": "+%s GRENADES",
		"hint_weapons": "Tap a weapon card to switch  ·  The grenade lands where you aim",
		"zombie_walker": "WALKER",
		"zombie_runner": "RUNNER",
		"zombie_brute": "BRUTE",
		"zombie_boss": "BEHEMOTH",
		"warn_boss": "BEHEMOTH INCOMING",
		"boss_down": "BEHEMOTH DOWN",
		"wave_hint_runners": "Runners: fast, but two rounds drop one",
		"wave_hint_brutes": "Brutes: aim for the head, or spend a rocket",
		"wave_hint_swarm": "A swarm of runners",
		"wave_hint_heavy": "A heavy push on the gate",
		"wave_hint_boss": "The Behemoth is coming for the gate",
		"warn_gate_attack": "GATE UNDER ATTACK",
		"warn_wall_attack": "WALL UNDER ATTACK",
		"warn_gate_half": "GATE AT HALF STRENGTH",
		"warn_gate_critical": "GATE CRITICAL",
		"warn_gate_destroyed": "GATE DOWN — THEY ARE INSIDE",
		"warn_wall_half": "WALL AT HALF STRENGTH",
		"warn_wall_critical": "WALL CRITICAL",
		"warn_wall_breached": "WALL BREACHED",
		"victory_title": "THE WALL HOLDS",
		"victory_text": "Every wave broken. The city sleeps tonight.",
		"defeat_title": "THE WALL HAS FALLEN",
		"defeat_text": "The horde is inside the city.",
		"hint_controls": "Drag to aim  ·  Hold FIRE to shoot",
		"best_wave": "Best run: wave %s",
		"fps": "%s FPS",
	},
	"fa": {
		"title": "آخرین دیوار",
		"subtitle": "محاصرهٔ زامبی‌ها",
		"tagline": "دروازه را نگه دار. شهر پشت سر توست.",
		"play": "دفاع از دیوار",
		"settings": "تنظیمات",
		"resume": "ادامه",
		"restart": "شروع دوباره",
		"main_menu": "منوی اصلی",
		"paused": "توقف",
		"back": "بازگشت",
		"language": "زبان",
		"language_name": "فارسی",
		"sensitivity": "حساسیت نشانه‌گیری",
		"invert_y": "معکوس‌کردن محور عمودی",
		"left_handed": "چیدمان چپ‌دست",
		"master_volume": "صدای کلی",
		"sfx_volume": "صدای افکت‌ها",
		"music_volume": "صدای موسیقی",
		"quality": "کیفیت گرافیک",
		"quality_auto": "خودکار",
		"quality_low": "کم",
		"quality_medium": "متوسط",
		"quality_high": "زیاد",
		"show_fps": "نمایش نرخ فریم",
		"wave": "موج %s از %s",
		"wave_incoming": "موج %s",
		"wave_cleared": "موج دفع شد",
		"next_wave": "موج بعدی تا %s ثانیهٔ دیگر",
		"get_ready": "آماده باش",
		"wall": "دیوار",
		"gate": "دروازه",
		"hostiles": "دشمن: %s",
		"kills": "کشته",
		"headshots": "هدشات",
		"accuracy": "دقت",
		"time": "زمان",
		"waves_held": "موج‌های دفع‌شده",
		"wall_left": "سلامت دیوار",
		"fire": "آتش",
		"reload": "خشاب",
		"reloading": "در حال خشاب‌گذاری",
		"weapon_twin_hmg": "مسلسل سنگین دولول",
		"weapon_rpg": "آرپی‌جی",
		"grenade": "نارنجک",
		"out_of_rockets": "راکت تمام شد",
		"resupply_rockets": "+%s راکت",
		"resupply_grenades": "+%s نارنجک",
		"hint_weapons": "برای تعویض، روی کارت سلاح بزن  ·  نارنجک همان‌جا که نشانه رفته‌ای می‌افتد",
		"zombie_walker": "زامبی عادی",
		"zombie_runner": "دونده",
		"zombie_brute": "سنگین‌وزن",
		"zombie_boss": "غول‌پیکر",
		"warn_boss": "غول‌پیکر در راه است",
		"boss_down": "غول‌پیکر از پا درآمد",
		"wave_hint_runners": "دونده‌ها: سریع‌اند، ولی با دو گلوله می‌افتند",
		"wave_hint_brutes": "سنگین‌وزن‌ها: سرشان را بزن یا راکت خرج کن",
		"wave_hint_swarm": "هجوم دونده‌ها",
		"wave_hint_heavy": "فشار سنگین روی دروازه",
		"wave_hint_boss": "غول‌پیکر به سراغ دروازه می‌آید",
		"warn_gate_attack": "دروازه زیر حمله است",
		"warn_wall_attack": "دیوار زیر حمله است",
		"warn_gate_half": "دروازه نیمه‌جان است",
		"warn_gate_critical": "وضعیت دروازه بحرانی است",
		"warn_gate_destroyed": "دروازه فرو ریخت — وارد شدند",
		"warn_wall_half": "دیوار نیمه‌جان است",
		"warn_wall_critical": "وضعیت دیوار بحرانی است",
		"warn_wall_breached": "دیوار شکافته شد",
		"victory_title": "دیوار ایستاد",
		"victory_text": "همهٔ موج‌ها در هم شکست. شهر امشب در امان است.",
		"defeat_title": "دیوار فرو ریخت",
		"defeat_text": "گلهٔ زامبی‌ها وارد شهر شد.",
		"hint_controls": "برای نشانه‌گیری بکش  ·  دکمهٔ آتش را نگه دار",
		"best_wave": "بهترین رکورد: موج %s",
		"fps": "%s فریم",
	},
}

static var language: String = "fa"


static func is_rtl() -> bool:
	return language == "fa"


static func has(key: String) -> bool:
	return TEXT[language].has(key)


## Translates `key`; numeric arguments are written with the language's digits.
static func t(key: String, args: Array = []) -> String:
	var table: Dictionary = TEXT.get(language, TEXT.en)
	var text: String = table.get(key, TEXT.en.get(key, key))
	if args.is_empty():
		return text
	var parts: Array = []
	for value: Variant in args:
		parts.append(number(value) if (value is int or value is float) else str(value))
	return text % parts


static func number(value: Variant) -> String:
	var text: String = str(value)
	if language != "fa":
		return text
	var out: String = ""
	for character: String in text:
		var code: int = character.unicode_at(0)
		out += DIGITS_FA[code - 48] if code >= 48 and code <= 57 else character
	return out


static func percent(fraction: float) -> String:
	var text: String = number(int(round(clampf(fraction, 0.0, 1.0) * 100.0)))
	return text + ("٪" if language == "fa" else "%")


static func clock(seconds: float) -> String:
	var total: int = int(seconds)
	return number("%d:%02d" % [total / 60, total % 60])
