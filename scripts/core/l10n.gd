class_name L10n
extends RefCounted
## Every player-facing string, in Persian and English.
##
## The table is static so tests can check it without starting the game or the
## `App` autoload. `App.t()` is the runtime entry point.

const FALLBACK := "en"
const LANGUAGES: Array[String] = ["fa", "en"]

const STRINGS := {
	# --- Brand ---------------------------------------------------------------
	"app.title": {"fa": "آیدیل", "en": "Ideal"},
	"app.subtitle": {"fa": "دیده‌بان جزیره", "en": "Island Watch"},

	# --- Main menu -----------------------------------------------------------
	"menu.play": {"fa": "شروع بازی", "en": "Play"},
	"menu.best": {"fa": "بهترین موج: {0}", "en": "Best wave: {0}"},
	"menu.quit": {"fa": "خروج", "en": "Quit"},
	"menu.hint": {
		"fa": "برج بساز، راه را ببند، هسته را نگه دار.",
		"en": "Build towers, hold the path, keep the core alive.",
	},
	"menu.controls": {
		"fa": "کشیدن: چرخش دوربین • دو انگشت: بزرگ‌نمایی • لمس: انتخاب",
		"en": "Drag: orbit • Pinch: zoom • Tap: select",
	},
	"menu.language_target": {"fa": "English", "en": "فارسی"},

	# --- HUD -----------------------------------------------------------------
	"hud.gold": {"fa": "طلا", "en": "Gold"},
	"hud.core": {"fa": "هسته", "en": "Core"},
	"hud.wave": {"fa": "موج {0}/{1}", "en": "Wave {0}/{1}"},
	"hud.speed": {"fa": "سرعت ×{0}", "en": "Speed ×{0}"},
	"hud.pause": {"fa": "توقف", "en": "Pause"},
	"hud.paused": {"fa": "بازی متوقف است", "en": "Game paused"},
	"hud.resume": {"fa": "ادامه", "en": "Resume"},
	"hud.quit": {"fa": "بازگشت به منو", "en": "Quit to menu"},
	"hud.start_wave": {"fa": "شروع موج", "en": "Start wave"},
	"hud.next_wave_in": {"fa": "موج بعدی: {0} ثانیه", "en": "Next wave in {0}s"},
	"hud.wave_running": {"fa": "موج {0} در جریان است", "en": "Wave {0} incoming"},
	"hud.victory": {"fa": "پیروزی", "en": "Victory"},
	"hud.defeat": {"fa": "هسته سقوط کرد", "en": "The core has fallen"},
	"hud.result_waves": {
		"fa": "موج‌های پشت سر گذاشته: {0} از {1}",
		"en": "Waves survived: {0} of {1}",
	},
	"hud.retry": {"fa": "تلاش دوباره", "en": "Try again"},
	"hud.menu": {"fa": "منو", "en": "Menu"},
	"hud.close": {"fa": "بستن", "en": "Close"},

	# --- Building ------------------------------------------------------------
	"build.title": {"fa": "ساخت برج", "en": "Build a tower"},
	"build.choose": {"fa": "نوع برج را انتخاب کن", "en": "Choose a tower type"},
	"build.upgrade": {"fa": "ارتقا ({0})", "en": "Upgrade ({0})"},
	"build.max_level": {"fa": "بالاترین سطح", "en": "Max level"},
	"build.sell": {"fa": "فروش (+{0})", "en": "Sell (+{0})"},
	"build.level": {"fa": "سطح {0}", "en": "Level {0}"},
	"build.damage": {"fa": "آسیب {0}", "en": "Damage {0}"},
	"build.range": {"fa": "برد {0}", "en": "Range {0}"},
	"build.rate": {"fa": "{0} شلیک در ثانیه", "en": "{0} shots/s"},
	"build.no_gold": {"fa": "طلا کافی نیست", "en": "Not enough gold"},
	"build.built": {"fa": "{0} ساخته شد", "en": "{0} built"},
	"build.upgraded": {"fa": "{0} به سطح {1} رسید", "en": "{0} reached level {1}"},
	"build.sold": {"fa": "برج فروخته شد (+{0} طلا)", "en": "Tower sold (+{0} gold)"},
	"build.tap_pad": {
		"fa": "برای ساخت، یک پایه را لمس کن",
		"en": "Tap a build pad to raise a tower",
	},

	# --- Towers --------------------------------------------------------------
	"tower.sentry.name": {"fa": "نگهبان", "en": "Sentry"},
	"tower.sentry.desc": {
		"fa": "تیرانداز سریع و ارزان برای هدف‌های تک",
		"en": "Fast, cheap single-target fire",
	},
	"tower.cannon.name": {"fa": "توپخانه", "en": "Cannon"},
	"tower.cannon.desc": {
		"fa": "گلولهٔ انفجاری برای جمع‌های فشرده",
		"en": "Explosive shells for tight groups",
	},
	"tower.frost.name": {"fa": "سرمازا", "en": "Frost"},
	"tower.frost.desc": {
		"fa": "دشمنان را در محدوده کند می‌کند",
		"en": "Chills nearby enemies to slow them",
	},

	# --- Waves and messages --------------------------------------------------
	"wave.started": {"fa": "موج {0} شروع شد", "en": "Wave {0} started"},
	"wave.cleared": {"fa": "موج {0} پاک شد؛ +{1} طلا", "en": "Wave {0} cleared; +{1} gold"},
	"wave.bonus": {"fa": "شروع زودهنگام: +{0} طلا", "en": "Early start: +{0} gold"},
	"info.leak": {"fa": "دشمن از خط گذشت؛ -{0} به هسته", "en": "An enemy got through; -{0} to the core"},
}


static func translate(language: String, key: String, args: Array = []) -> String:
	var entry: Variant = STRINGS.get(key)
	if entry == null:
		push_warning("L10n: missing key '%s'" % key)
		return key
	var text := str(entry.get(language, entry.get(FALLBACK, key)))
	for i in args.size():
		text = text.replace("{%d}" % i, str(args[i]))
	return text


static func keys() -> Array:
	return STRINGS.keys()


static func has_language(language: String) -> bool:
	return LANGUAGES.has(language)


static func is_complete() -> bool:
	for key in STRINGS:
		var entry: Dictionary = STRINGS[key]
		for language in LANGUAGES:
			if not entry.has(language) or str(entry[language]).strip_edges().is_empty():
				return false
	return true
