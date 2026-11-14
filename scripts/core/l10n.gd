class_name L10n
extends RefCounted
## Every player-facing string, in Persian and English.
##
## Static so tests can check the table without starting the game or the `App`
## autoload. `App.t()` is the runtime entry point.

const FALLBACK := "en"
const LANGUAGES: Array[String] = ["fa", "en"]

const STRINGS := {
	# --- Brand ---------------------------------------------------------------
	"app.title": {"fa": "آیدیل", "en": "Ideal"},
	"app.subtitle": {"fa": "شهرساز جزیره", "en": "Island City Builder"},

	# --- Main menu -----------------------------------------------------------
	"menu.play": {"fa": "شهر جدید", "en": "New city"},
	"menu.continue": {"fa": "ادامهٔ شهر", "en": "Continue"},
	"menu.best": {"fa": "بهترین جمعیت: {0}", "en": "Best population: {0}"},
	"menu.quit": {"fa": "خروج", "en": "Quit"},
	"menu.hint": {
		"fa": "جاده بکش، خانه بساز، شهر را آباد کن.",
		"en": "Lay roads, build homes, grow the town.",
	},
	"menu.controls": {
		"fa": "کشیدن: جابه‌جایی دوربین • دو انگشت: بزرگ‌نمایی • لمس: ساختن",
		"en": "Drag: pan • Pinch: zoom • Tap: build",
	},
	"menu.language_target": {"fa": "English", "en": "فارسی"},

	# --- Categories ----------------------------------------------------------
	"category.road": {"fa": "جاده", "en": "Roads"},
	"category.residential": {"fa": "مسکونی", "en": "Homes"},
	"category.commercial": {"fa": "تجاری", "en": "Business"},
	"category.nature": {"fa": "طبیعت", "en": "Nature"},
	"category.civic": {"fa": "خدمات", "en": "Civic"},

	# --- Structures ----------------------------------------------------------
	"structure.road.name": {"fa": "جاده", "en": "Road"},
	"structure.road.desc": {
		"fa": "شبکهٔ شهر را به هم وصل می‌کند؛ هر ساختمان باید به جادهٔ متصل به شهرداری برسد.",
		"en": "Connects the city; every building needs a road linked to the town hall.",
	},
	"structure.house_a.name": {"fa": "خانهٔ کوچک", "en": "Small house"},
	"structure.house_a.desc": {"fa": "جا برای ۴ نفر", "en": "Room for 4 people"},
	"structure.house_b.name": {"fa": "خانهٔ دوطبقه", "en": "Town house"},
	"structure.house_b.desc": {"fa": "جا برای ۷ نفر", "en": "Room for 7 people"},
	"structure.house_d.name": {"fa": "آپارتمان", "en": "Apartment"},
	"structure.house_d.desc": {"fa": "جا برای ۱۵ نفر", "en": "Room for 15 people"},
	"structure.shop.name": {"fa": "کارگاه", "en": "Workshop"},
	"structure.shop.desc": {
		"fa": "درآمد ثابت می‌دهد، کمی هم آلودگی دارد",
		"en": "Steady income, a little pollution",
	},
	"structure.grass.name": {"fa": "چمن", "en": "Lawn"},
	"structure.grass.desc": {"fa": "کمی رضایت", "en": "A little happiness"},
	"structure.trees.name": {"fa": "درخت", "en": "Trees"},
	"structure.trees.desc": {"fa": "رضایت بیشتر برای محله", "en": "More happiness nearby"},
	"structure.tall_trees.name": {"fa": "درختان بلند", "en": "Tall trees"},
	"structure.tall_trees.desc": {"fa": "بیشترین رضایت میان سبزه‌ها", "en": "The greenest choice"},
	"structure.pavement.name": {"fa": "پیاده‌رو", "en": "Pavement"},
	"structure.pavement.desc": {"fa": "کف‌سازی مرتب و کمی رضایت", "en": "Tidy ground, a little happiness"},
	"structure.fountain.name": {"fa": "فواره", "en": "Fountain"},
	"structure.fountain.desc": {"fa": "مرکز تفریح شهر", "en": "The heart of the park"},
	"structure.town_hall.name": {"fa": "شهرداری", "en": "Town hall"},
	"structure.town_hall.desc": {
		"fa": "قلب شهر؛ جاده‌ها از اینجا باید شروع شوند.",
		"en": "The heart of the town; roads must lead here.",
	},

	# --- HUD -----------------------------------------------------------------
	"hud.cash": {"fa": "طلا", "en": "Gold"},
	"hud.population": {"fa": "جمعیت", "en": "People"},
	"hud.income": {"fa": "درآمد", "en": "Income"},
	"hud.happiness": {"fa": "رضایت", "en": "Happiness"},
	"hud.next_goal": {"fa": "هدف بعدی: {0} نفر", "en": "Next goal: {0} people"},
	"hud.all_goals": {"fa": "همهٔ هدف‌ها انجام شد", "en": "Every goal reached"},
	"hud.milestone": {"fa": "{0} نفر شد! +{1} طلا", "en": "{0} people! +{1} gold"},
	"hud.rotate": {"fa": "چرخش", "en": "Rotate"},
	"hud.undo": {"fa": "واگرد", "en": "Undo"},
	"hud.menu": {"fa": "منو", "en": "Menu"},
	"hud.demolish": {"fa": "تخریب", "en": "Demolish"},
	"hud.build": {"fa": "ساختن", "en": "Build"},
	"hud.save": {"fa": "ذخیره", "en": "Save"},
	"hud.saved": {"fa": "شهر ذخیره شد", "en": "City saved"},
	"hud.hint": {
		"fa": "یک ساختار را انتخاب کن، بعد روی زمین لمس کن.",
		"en": "Pick a structure, then tap the ground.",
	},
	"hud.income_value": {"fa": "+{0} در ثانیه", "en": "+{0}/s"},
	"hud.population_value": {"fa": "{0} / {1}", "en": "{0} / {1}"},
	"hud.happiness_value": {"fa": "{0}٪", "en": "{0}%"},
	"hud.road_needed": {
		"fa": "این ساختمان به جادهٔ متصل به شهرداری نیاز دارد",
		"en": "This building needs a road connected to the town hall",
	},

	# --- Messages ------------------------------------------------------------
	"msg.occupied": {"fa": "این زمین پر است", "en": "That ground is taken"},
	"msg.no_cash": {"fa": "طلا کافی نیست", "en": "Not enough gold"},
	"msg.built": {"fa": "{0} ساخته شد", "en": "{0} built"},
	"msg.removed": {"fa": "{0} برداشته شد (+{1} طلا)", "en": "{0} removed (+{1} gold)"},
	"msg.cannot_remove": {"fa": "شهرداری را نمی‌توان برداشت", "en": "The town hall stays"},
	"msg.undo_empty": {"fa": "چیزی برای واگرد نیست", "en": "Nothing to undo"},
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
