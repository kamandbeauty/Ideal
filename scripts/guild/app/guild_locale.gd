class_name GuildLocale
extends RefCounted
## English-first localisation with text-only Persian.
##
## The rule for this game: **the UI is authored in English**, and its layout,
## reading order, alignment and direction never change. Choosing Persian replaces
## words and nothing else - no mirroring, no flipped panels, no re-flowed numbers.
## That keeps one layout to design, test and screenshot, and guarantees that a
## translation can never break the interface.
##
## `STRINGS` is the source of truth (English). `PERSIAN` holds the overrides and
## the tests require an override for every key, so Persian never silently falls
## back to English. Numbers stay in Latin digits with thousands separators in both
## languages: digit styles would change the width of every meter and counter.

const BASE_LANGUAGE := "en"
const LANGUAGES: Array[String] = ["en", "fa"]

# --- English base ----------------------------------------------------------

const STRINGS := {
	# Brand and menu
	"app.title": "Guild Tycoon",
	"app.subtitle": "Build the guild. Trade the loot. Own the frontier.",
	"menu.play": "Enter the guild",
	"menu.continue": "Continue",
	"menu.settings": "Settings",
	"menu.language": "Language",
	# HUD
	"hud.gold": "Gold",
	"hud.reputation": "Reputation",
	"hud.warehouse": "Warehouse",
	"hud.warehouse_value": "{0} / {1}",
	"hud.customers": "Customers",
	"hud.missions": "Missions",
	"hud.guild_level": "Guild level {0}",
	"hud.hero_level": "Level {0}",
	# Console verbs
	"action.pick_up": "Pick up",
	"action.put_back": "Put back",
	"action.deliver": "Deliver",
	"action.deposit": "Deposit",
	"action.deposit_all": "Deposit all",
	"action.read_board": "Read board",
	"action.open_shop": "Open shop",
	# Items
	"item.slime_gel": "Slime Gel",
	"item.iron_ore": "Iron Ore",
	"item.healing_herb": "Healing Herb",
	"item.moon_shard": "Moon Shard",
	"item.ancient_coin": "Ancient Coin",
	"category.alchemy": "Alchemy",
	"category.ore": "Ore",
	"category.herb": "Herb",
	"category.relic": "Relic",
	# Trade
	"market.buy_price": "Buy {0}",
	"market.sell_price": "Sell {0}",
	"market.margin": "Margin {0}",
	"order.new": "{0} x {1}",
	"order.waiting": "Waiting",
	"order.ready": "Ready to deliver",
	"order.paid": "Paid {0}",
	# Customers
	"customer.warrior": "Warrior",
	"customer.mage": "Mage",
	"customer.archer": "Archer",
	"customer.rogue": "Rogue",
	"customer.knight": "Knight",
	# Adventurers and missions
	"adventurer.warrior": "Warrior",
	"adventurer.mage": "Mage",
	"adventurer.archer": "Archer",
	"adventurer.rogue": "Rogue",
	"adventurer.paladin": "Paladin",
	"adventurer.idle": "Idle",
	"adventurer.dispatched": "On a mission",
	"adventurer.returning": "Returning",
	"mission.board": "Mission board",
	"mission.dispatch": "Dispatch",
	"mission.duration": "{0} min",
	"mission.success": "{0}% success",
	"mission.returns_in": "{0} left",
	"mission.loot": "Loot",
	# Treasury and upgrades
	"treasury.title": "Treasury",
	"treasury.deposit_hint": "Deposit the gold in your hands",
	"upgrade.carry": "Carry capacity",
	"upgrade.speed": "Movement speed",
	"upgrade.hands": "Money capacity",
	"upgrade.storage": "Warehouse capacity",
	# Feedback
	"msg.picked": "{0} picked up",
	"msg.delivered": "{0} delivered",
	"msg.deposited": "{0} deposited",
	"msg.hands_full": "Your hands are full",
	"msg.no_stock": "Not enough stock",
	"msg.no_order": "Nobody is waiting for that",
	"msg.order_done": "Order complete",
	"msg.mission_started": "{0} sets out",
	"msg.mission_returned": "{0} is back with loot",
	# Settings
	"settings.title": "Settings",
	"settings.music": "Music",
	"settings.effects": "Sound effects",
	"settings.haptics": "Vibration",
	"settings.quality": "Graphics",
	"settings.language": "Language",
	"quality.low": "Low",
	"quality.medium": "Medium",
	"quality.high": "High",
	"setting.on": "On",
	"setting.off": "Off",
	# Hints
	"hint.move": "Drag the left stick to walk",
	"hint.interact": "The action button talks, picks up and delivers",
	"hint.camera": "Drag the right side to turn the camera, pinch to zoom",
}

# --- Persian: text-only overrides ------------------------------------------

const PERSIAN := {
	"app.title": "گیلد تایکون",
	"app.subtitle": "گیلد را بساز، غنیمت را بفروش، مرزها را بگیر.",
	"menu.play": "ورود به گیلد",
	"menu.continue": "ادامه",
	"menu.settings": "تنظیمات",
	"menu.language": "زبان",
	"hud.gold": "طلا",
	"hud.reputation": "اعتبار",
	"hud.warehouse": "انبار",
	"hud.warehouse_value": "{0} / {1}",
	"hud.customers": "مشتری‌ها",
	"hud.missions": "مأموریت‌ها",
	"hud.guild_level": "سطح گیلد {0}",
	"hud.hero_level": "سطح {0}",
	"action.pick_up": "برداشتن",
	"action.put_back": "بازگرداندن",
	"action.deliver": "تحویل",
	"action.deposit": "واریز",
	"action.deposit_all": "واریز همه",
	"action.read_board": "تختهٔ مأموریت",
	"action.open_shop": "باز کردن فروشگاه",
	"item.slime_gel": "ژل اسلایم",
	"item.iron_ore": "سنگ آهن",
	"item.healing_herb": "گیاه شفا",
	"item.moon_shard": "خردهٔ ماه",
	"item.ancient_coin": "سکهٔ باستانی",
	"category.alchemy": "کیمیاگری",
	"category.ore": "سنگ",
	"category.herb": "گیاه",
	"category.relic": "یادگار",
	"market.buy_price": "خرید {0}",
	"market.sell_price": "فروش {0}",
	"market.margin": "سود {0}",
	"order.new": "{1} عدد {0}",
	"order.waiting": "در انتظار",
	"order.ready": "آمادهٔ تحویل",
	"order.paid": "{0} پرداخت شد",
	"customer.warrior": "جنگجو",
	"customer.mage": "جادوگر",
	"customer.archer": "کماندار",
	"customer.rogue": "دزد",
	"customer.knight": "شهسوار",
	"adventurer.warrior": "جنگجو",
	"adventurer.mage": "جادوگر",
	"adventurer.archer": "کماندار",
	"adventurer.rogue": "دزد",
	"adventurer.paladin": "پالادین",
	"adventurer.idle": "بی‌کار",
	"adventurer.dispatched": "در مأموریت",
	"adventurer.returning": "در بازگشت",
	"mission.board": "تختهٔ مأموریت",
	"mission.dispatch": "اعزام",
	"mission.duration": "{0} دقیقه",
	"mission.success": "{0}٪ موفقیت",
	"mission.returns_in": "{0} مانده",
	"mission.loot": "غنیمت",
	"treasury.title": "خزانه",
	"treasury.deposit_hint": "طلاهای دستت را واریز کن",
	"upgrade.carry": "ظرفیت حمل",
	"upgrade.speed": "سرعت حرکت",
	"upgrade.hands": "ظرفیت طلا",
	"upgrade.storage": "ظرفیت انبار",
	"msg.picked": "{0} برداشته شد",
	"msg.delivered": "{0} تحویل شد",
	"msg.deposited": "{0} واریز شد",
	"msg.hands_full": "دست‌هایت پر است",
	"msg.no_stock": "موجودی کافی نیست",
	"msg.no_order": "کسی منتظر این نیست",
	"msg.order_done": "سفارش کامل شد",
	"msg.mission_started": "{0} راه افتاد",
	"msg.mission_returned": "{0} با غنیمت برگشت",
	"settings.title": "تنظیمات",
	"settings.music": "موسیقی",
	"settings.effects": "جلوه‌های صوتی",
	"settings.haptics": "لرزش",
	"settings.quality": "گرافیک",
	"settings.language": "زبان",
	"quality.low": "کم",
	"quality.medium": "متوسط",
	"quality.high": "زیاد",
	"setting.on": "روشن",
	"setting.off": "خاموش",
	"hint.move": "اهرم چپ را بکش تا راه بروی",
	"hint.interact": "دکمهٔ کنش حرف می‌زند، برمی‌دارد و تحویل می‌دهد",
	"hint.camera": "سمت راست را بکش تا دوربین بچرخد، برای زوم دو انگشت",
}


# --- Lookup ----------------------------------------------------------------

static func keys() -> Array[String]:
	var result: Array[String] = []
	for key in STRINGS:
		result.append(str(key))
	result.sort()
	return result


static func has_key(key: String) -> bool:
	return STRINGS.has(key)


## The English string, or the Persian override when one is asked for.
static func text(key: String, language: String = BASE_LANGUAGE) -> String:
	if not STRINGS.has(key):
		return key
	if _is_persian(language) and PERSIAN.has(key):
		return str(PERSIAN[key])
	return str(STRINGS[key])


## Same as `text`, with `{0}`, `{1}` … substituted from `args`.
static func t(key: String, args: Array = [], language: String = BASE_LANGUAGE) -> String:
	var value := text(key, language)
	for index in args.size():
		value = value.replace("{%d}" % index, str(args[index]))
	return value


static func missing_overrides() -> Array[String]:
	var missing: Array[String] = []
	for key in STRINGS:
		if not PERSIAN.has(str(key)):
			missing.append(str(key))
	missing.sort()
	return missing


## Overrides that are still the English text - a translation that never happened.
static func untranslated_overrides() -> Array[String]:
	var same: Array[String] = []
	for key in PERSIAN:
		if str(STRINGS.get(key, "")) == str(PERSIAN[key]):
			same.append(str(key))
	same.sort()
	return same


static func _is_persian(language: String) -> bool:
	return language == "fa"


# --- Layout ----------------------------------------------------------------

## Always left-to-right, in both languages: Persian replaces words only.
static func layout_direction() -> int:
	return Control.LAYOUT_DIRECTION_LTR


static func is_rtl(_language: String = BASE_LANGUAGE) -> bool:
	return false


## Text alignment is fixed too; Persian glyphs shape right-to-left inside the
## same left-aligned box, so no label changes width or position.
static func alignment() -> int:
	return HORIZONTAL_ALIGNMENT_LEFT


# --- Numbers ---------------------------------------------------------------

## Latin digits and thousands separators, identical in both languages, so a
## counter never changes width when the player switches language.
static func format_number(value: float, decimals: int = 0) -> String:
	var negative := value < 0.0
	var magnitude := absf(value)
	var raw := ""
	if decimals > 0:
		raw = ("%." + str(decimals) + "f") % magnitude
	else:
		raw = str(int(round(magnitude)))
	var parts := raw.split(".")
	var out := _group_thousands(parts[0])
	if parts.size() > 1:
		out += "." + parts[1]
	return ("-" + out) if negative else out


## Abbreviated money: 12,340 → 12.3K, 4,500,000 → 4.5M, 2,100,000,000 → 2.1B.
static func format_money(value: float) -> String:
	var magnitude := absf(value)
	if magnitude >= 1.0e9:
		return format_number(value / 1.0e9, 1) + "B"
	if magnitude >= 1.0e6:
		return format_number(value / 1.0e6, 1) + "M"
	if magnitude >= 1.0e4:
		return format_number(value / 1.0e3, 1) + "K"
	return format_number(value)


static func format_duration(seconds: float) -> String:
	var total := maxi(0, int(round(seconds)))
	if total < 60:
		return "%ds" % total
	if total < 3600:
		return "%dm" % (total / 60)
	if total < 86400:
		return "%dh %dm" % [total / 3600, (total % 3600) / 60]
	return "%dd %dh" % [total / 86400, (total % 86400) / 3600]


static func _group_thousands(digits: String) -> String:
	var out := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		out = digits[index] + out
		count += 1
		if count % 3 == 0 and index > 0:
			out = "," + out
	return out
