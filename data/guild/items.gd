class_name GuildItems
extends RefCounted
## The goods the guild trades. `buy` is what the guild pays an adventurer for a
## unit of loot, `sell` is what a customer pays for it: the difference is the
## guild's whole income, and the only reason to carry anything.

const ITEMS := {
	"slime_gel": {
		"name_key": "item.slime_gel",
		"category_key": "category.alchemy",
		"buy": 10.0,
		"sell": 18.0,
		"color": Color(0.58, 0.36, 0.72),
		"weight": 1,
	},
	"iron_ore": {
		"name_key": "item.iron_ore",
		"category_key": "category.ore",
		"buy": 4.0,
		"sell": 9.0,
		"color": Color(0.48, 0.5, 0.6),
		"weight": 1,
	},
	"healing_herb": {
		"name_key": "item.healing_herb",
		"category_key": "category.herb",
		"buy": 6.0,
		"sell": 14.0,
		"color": Color(0.36, 0.62, 0.42),
		"weight": 1,
	},
	"moon_shard": {
		"name_key": "item.moon_shard",
		"category_key": "category.relic",
		"buy": 40.0,
		"sell": 95.0,
		"color": Color(0.62, 0.82, 0.95),
		"weight": 1,
	},
	"ancient_coin": {
		"name_key": "item.ancient_coin",
		"category_key": "category.relic",
		"buy": 120.0,
		"sell": 240.0,
		"color": Color(0.93, 0.78, 0.4),
		"weight": 1,
	},
}

## The loot table adventurers will roll on in Phase 4, kept here so the prices and
## the drops can never drift apart.
const LOOT_TABLE := {
	"slime_gel": 32,
	"iron_ore": 26,
	"healing_herb": 22,
	"moon_shard": 14,
	"ancient_coin": 6,
}

## Cheapest first, so a low roll drops cheap loot and only a high roll finds a
## relic. The order is explicit because dictionary order is not a promise.
const LOOT_ORDER: Array[String] = ["slime_gel", "iron_ore", "healing_herb", "moon_shard", "ancient_coin"]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for id in ITEMS:
		result.append(str(id))
	result.sort()
	return result


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func exists(id: String) -> bool:
	return ITEMS.has(id)


static func name_key(id: String) -> String:
	return str(item(id).get("name_key", id))


static func buy_price(id: String) -> float:
	return float(item(id).get("buy", 0.0))


static func sell_price(id: String) -> float:
	return float(item(id).get("sell", 0.0))


static func color(id: String) -> Color:
	return item(id).get("color", Color(0.6, 0.5, 0.7)) as Color


static func margin(id: String) -> float:
	return sell_price(id) - buy_price(id)


## Every item has to be more valuable sold than bought, or the guild's loop is a
## lie. The suite asserts this for the whole table.
static func has_positive_margin(id: String) -> bool:
	return exists(id) and margin(id) > 0.0


## Weighted loot roll. `roll` is 0..1 so the caller decides the randomness and the
## test can pin it.
static func roll_loot(roll: float) -> String:
	var total := 0
	for id in LOOT_ORDER:
		total += int(LOOT_TABLE[id])
	var target := clampi(int(roll * total), 0, maxi(total - 1, 0))
	var walked := 0
	for id in LOOT_ORDER:
		walked += int(LOOT_TABLE[id])
		if target < walked:
			return id
	return LOOT_ORDER[0]
