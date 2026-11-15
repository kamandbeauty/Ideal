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
	"app.title": {"fa": "رودستاپ تایکون", "en": "Roadstop Tycoon"},
	"app.subtitle": {"fa": "امپراتوری شهرک‌های بین‌راهی", "en": "Roadside Empire"},

	# --- Main menu -----------------------------------------------------------
	"menu.new_game": {"fa": "شهرک جدید", "en": "New town"},
	"menu.continue": {"fa": "ادامهٔ بازی", "en": "Continue"},
	"menu.language_target": {"fa": "English", "en": "فارسی"},
	"menu.quit": {"fa": "خروج", "en": "Quit"},
	"menu.record": {"fa": "بهترین اعتبار: {0}", "en": "Best reputation: {0}"},
	"menu.hint": {
		"fa": "از یک پمپ‌بنزین شروع کن و شهرک را به امپراتوری برسان.",
		"en": "Start with one gas station and grow a roadside empire.",
	},
	"menu.controls": {
		"fa": "کشیدن: جابه‌جایی • دو انگشت: بزرگ‌نمایی • لمس ساختمان: مدیریت",
		"en": "Drag: pan • Pinch: zoom • Tap a building: manage",
	},

	# --- Towns ---------------------------------------------------------------
	"town.desert": {"fa": "شهرک کویر", "en": "Desert stop"},
	"town.forest": {"fa": "شهرک جنگل", "en": "Forest stop"},
	"town.mountain": {"fa": "شهرک کوهستان", "en": "Mountain stop"},
	"town.coast": {"fa": "شهرک ساحل", "en": "Coast stop"},
	"town.highway": {"fa": "بزرگراه مرکزی", "en": "Central highway"},

	# --- Businesses ----------------------------------------------------------
	"business.gas_station.name": {"fa": "پمپ‌بنزین", "en": "Gas station"},
	"business.gas_station.desc": {
		"fa": "سوخت، خوراکی و اولین درآمد شهرک",
		"en": "Fuel, snacks and the first income",
	},
	"business.restaurant.name": {"fa": "رستوران بین‌راهی", "en": "Roadside restaurant"},
	"business.restaurant.desc": {
		"fa": "غذا و استراحت برای مسافران گرسنه",
		"en": "Food and a rest for hungry travellers",
	},
	"business.store.name": {"fa": "فروشگاه", "en": "Store"},
	"business.store.desc": {
		"fa": "کالاهای سفر و خرید سریع",
		"en": "Travel supplies and quick shopping",
	},
	"business.workshop.name": {"fa": "تعمیرگاه", "en": "Workshop"},
	"business.workshop.desc": {
		"fa": "تعمیر خودروهای سنگین با درآمد بالا",
		"en": "Heavy repairs, high value per customer",
	},
	"business.motel.name": {"fa": "مسافرخانه", "en": "Motel"},
	"business.motel.desc": {
		"fa": "اقامت شبانه برای مسافران خسته",
		"en": "A bed for the night",
	},
	"business.car_wash.name": {"fa": "کارواش", "en": "Car wash"},
	"business.car_wash.desc": {
		"fa": "شست‌وشوی سریع، مشتری زیاد",
		"en": "Quick washes, plenty of cars",
	},

	# --- Branches and managers ----------------------------------------------
	"branch.capacity": {"fa": "ظرفیت", "en": "Capacity"},
	"branch.speed": {"fa": "سرعت", "en": "Speed"},
	"branch.quality": {"fa": "کیفیت", "en": "Quality"},
	"manager.rank.0": {"fa": "بدون مدیر", "en": "No manager"},
	"manager.rank.1": {"fa": "مدیر مبتدی", "en": "Junior manager"},
	"manager.rank.2": {"fa": "مدیر حرفه‌ای", "en": "Professional manager"},
	"manager.rank.3": {"fa": "مدیر متخصص", "en": "Specialist manager"},
	"manager.rank.4": {"fa": "مدیر ارشد", "en": "Senior manager"},

	# --- HUD -----------------------------------------------------------------
	"hud.cash": {"fa": "پول", "en": "Cash"},
	"hud.gems": {"fa": "الماس", "en": "Gems"},
	"hud.reputation": {"fa": "اعتبار", "en": "Reputation"},
	"hud.level": {"fa": "سطح {0}", "en": "Level {0}"},
	"hud.town_level": {"fa": "سطح شهرک {0}", "en": "Town level {0}"},
	"hud.income": {"fa": "سود در دقیقه", "en": "Profit per minute"},
	"hud.income_value": {"fa": "{0} سکه در دقیقه", "en": "{0}/min"},
	"hud.customers": {"fa": "مشتری در دقیقه", "en": "Customers per minute"},
	"hud.capacity": {"fa": "ظرفیت", "en": "Capacity"},
	"hud.capacity_value": {"fa": "{0} مشتری", "en": "{0} customers"},
	"hud.upkeep": {"fa": "هزینه نگهداری", "en": "Upkeep"},
	"hud.upkeep_value": {"fa": "{0} در دقیقه", "en": "{0}/min"},
	"hud.efficiency": {"fa": "بازدهی {0}٪", "en": "Efficiency {0}%"},
	"hud.menu": {"fa": "منو", "en": "Menu"},
	"hud.save": {"fa": "ذخیره", "en": "Save"},
	"hud.saved": {"fa": "شهرک ذخیره شد", "en": "Town saved"},
	"hud.close": {"fa": "بستن", "en": "Close"},
	"hud.upgrade": {"fa": "ارتقا ({0})", "en": "Upgrade ({0})"},
	"hud.max_level": {"fa": "بالاترین سطح", "en": "Max level"},
	"hud.branch": {"fa": "{0} · سطح {1}", "en": "{0} · Lv {1}"},
	"hud.branch_state": {"fa": "سطح {0} · {1}", "en": "Lv {0} · {1}"},
	"hud.hire_manager": {"fa": "استخدام ({0})", "en": "Hire ({0})"},
	"hud.promote_manager": {"fa": "ارتقای مدیر ({0})", "en": "Promote ({0})"},
	"hud.manager_max": {"fa": "مدیر ارشد", "en": "Senior manager"},
	"hud.unlock": {"fa": "باز کردن ({0})", "en": "Unlock ({0})"},
	"hud.locked": {"fa": "بسته", "en": "Locked"},
	"hud.offline_title": {"fa": "در حالی که نبودی", "en": "While you were away"},
	"hud.offline_body": {
		"fa": "{0} ساعت و {1} دقیقه گذشت و {2} سکه به دست آمد.",
		"en": "{0}h {1}m passed and {2} coins were earned.",
	},
	"hud.offline_claim": {"fa": "دریافت", "en": "Collect"},
	"hud.manager_none": {"fa": "بدون مدیر", "en": "No manager"},
	"hud.completion": {"fa": "تکمیل شهرک {0}٪", "en": "Town completion {0}%"},
	"hud.completion_done": {"fa": "تکمیل شهرک {0}٪ · کامل", "en": "Town {0}% · complete"},
	"hud.town_complete": {
		"fa": "شهرک کامل شد؛ آمادهٔ شهر بعدی!",
		"en": "Town complete — ready for the next stop!",
	},
	# --- Missions -----------------------------------------------------------
	"mission.title": {"fa": "مأموریت", "en": "Mission"},
	"mission.claim": {"fa": "دریافت", "en": "Claim"},
	"mission.progress": {"fa": "{0} از {1}", "en": "{0} of {1}"},
	"mission.reward_coins": {"fa": "{0} سکه", "en": "{0} coins"},
	"mission.reward_gems": {"fa": "{0} الماس", "en": "{0} gems"},
	"mission.reward": {"fa": "جایزه: {0}", "en": "Reward: {0}"},
	"msg.mission_claimed": {"fa": "جایزهٔ مأموریت: {0}", "en": "Mission reward: {0}"},
	"mission.first_upgrade.title": {"fa": "اولین ارتقا", "en": "First upgrade"},
	"mission.first_upgrade.desc": {
		"fa": "یک کسب‌وکار را یک سطح ارتقا بده.",
		"en": "Put one level into any business.",
	},
	"mission.open_restaurant.title": {"fa": "آشپزخانهٔ بین‌راهی", "en": "The roadside kitchen"},
	"mission.open_restaurant.desc": {
		"fa": "رستوران را باز کن تا مسافران غذا بخورند.",
		"en": "Open the restaurant so travellers can eat.",
	},
	"mission.reach_level_three.title": {"fa": "سطح سه", "en": "Level three"},
	"mission.reach_level_three.desc": {
		"fa": "یک کسب‌وکار را به سطح ۳ برسان.",
		"en": "Get any business to level 3.",
	},
	"mission.hire_manager.title": {"fa": "اولین مدیر", "en": "First manager"},
	"mission.hire_manager.desc": {
		"fa": "برای یک کسب‌وکار مدیر استخدام کن تا آفلاین هم درآمد بدهد.",
		"en": "Hire a manager so a business earns while you are away.",
	},
	"mission.buy_branch.title": {"fa": "تخصص", "en": "Specialise"},
	"mission.buy_branch.desc": {
		"fa": "یکی از شاخه‌های ظرفیت، سرعت یا کیفیت را ارتقا بده.",
		"en": "Buy a capacity, speed or quality branch.",
	},
	"mission.serve_customers.title": {"fa": "مشتریان ثابت", "en": "Regulars"},
	"mission.serve_customers.desc": {
		"fa": "۵۰۰ مشتری را سرویس بده.",
		"en": "Serve 500 customers.",
	},
	"mission.open_all.title": {"fa": "ششگانه", "en": "Full house"},
	"mission.open_all.desc": {
		"fa": "هر شش کسب‌وکار شهرک را باز کن.",
		"en": "Open all six businesses.",
	},
	"mission.complete_town.title": {"fa": "شهرک کامل", "en": "Complete stop"},
	"mission.complete_town.desc": {
		"fa": "شهرک را ۱۰۰٪ کامل کن.",
		"en": "Finish the town.",
	},

	# --- Events -------------------------------------------------------------
	"event.title": {"fa": "رویداد", "en": "Event"},
	"event.started": {"fa": "رویداد: {0}", "en": "Event: {0}"},
	"event.ended": {"fa": "{0} تمام شد", "en": "{0} ended"},
	"event.remaining": {"fa": "{0} ثانیه", "en": "{0}s"},
	"event.rush.name": {"fa": "هجوم مسافران", "en": "Rush hour"},
	"event.rush.desc": {"fa": "ترافیک ۸۰٪ بیشتر", "en": "Traffic up 80%"},
	"event.holiday.name": {"fa": "تعطیلات", "en": "Holiday"},
	"event.holiday.desc": {
		"fa": "گردشگر بیشتر، درآمد ۲۰٪ بالاتر",
		"en": "More tourists, income up 20%",
	},
	"event.rain.name": {"fa": "بارندگی", "en": "Rain"},
	"event.rain.desc": {"fa": "تردد ۴۰٪ کمتر", "en": "Traffic down 40%"},
	"event.breakdown.name": {"fa": "خرابی دستگاه", "en": "Breakdown"},
	"event.breakdown.desc": {"fa": "درآمد ۲۵٪ کمتر", "en": "Income down 25%"},
	"event.festival.name": {"fa": "جشنوارهٔ محلی", "en": "Local festival"},
	"event.festival.desc": {"fa": "درآمد ۳۰٪ بیشتر", "en": "Income up 30%"},
	"event.power_cut.name": {"fa": "قطع برق", "en": "Power cut"},
	"event.power_cut.desc": {
		"fa": "خدمات کندتر، درآمد ۲۰٪ کمتر",
		"en": "Services slower, income down 20%",
	},

	"hud.complete_title": {"fa": "شهرک تکمیل شد!", "en": "Town complete!"},
	"hud.complete_body": {
		"fa": "هر شش کسب‌وکار ساخته شد و به بالاترین سطح رسید. ۲۵ الماس گرفتی و شهرک آمادهٔ مقصد بعدی است.",
		"en": "All six businesses are built and maxed out. You earned 25 gems and the stop is ready for the next one.",
	},
	"hud.complete_continue": {"fa": "ادامه", "en": "Continue"},
	"hud.hint": {
		"fa": "یک کسب‌وکار را لمس کن تا ارتقا و مدیرش را ببینی.",
		"en": "Tap a business to see upgrades and its manager.",
	},

	# --- Messages ------------------------------------------------------------
	"msg.no_cash": {"fa": "پول کافی نیست", "en": "Not enough cash"},
	"msg.upgraded": {"fa": "{0} به سطح {1} رسید", "en": "{0} reached level {1}"},
	"msg.unlocked": {"fa": "{0} باز شد", "en": "{0} unlocked"},
	"msg.manager_hired": {"fa": "{0}: {1}", "en": "{0}: {1}"},
	"msg.branch_upgraded": {"fa": "{0}: {1} سطح {2}", "en": "{0}: {1} level {2}"},
	"msg.save_ok": {"fa": "شهرک ذخیره شد", "en": "Town saved"},
	"msg.auto_level": {
		"fa": "مدیر: {0} · سطح {1}",
		"en": "Manager: {0} · level {1}",
	},
	"msg.auto_branch": {
		"fa": "مدیر: {0} · {1} {2}",
		"en": "Manager: {0} · {1} {2}",
	},
	"msg.auto_rank": {
		"fa": "مدیر: {0} · {1}",
		"en": "Manager: {0} · {1}",
	},
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
