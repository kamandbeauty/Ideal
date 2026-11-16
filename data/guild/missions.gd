class_name GuildMissions
extends RefCounted
## The mission board's data: what can be sent out, for how long, for what fee, and
## what loot the table can actually return.
##
## Everything is a constant so the board, the desk, the tests and the HUD read the
## same table, and loot is rolled from a seeded generator so a captured run can be
## repeated exactly.

const RANKS: Array[String] = ["F", "E", "D", "C", "B", "A", "S"]

const TABLE := {
	"gather_herbs": {
		"name_key": "mission.gather_herbs",
		"rank": "F",
		"duration": 25.0,
		"fee": 8.0,
		"reputation": 1.0,
		"loot": [
			{"item": "healing_herb", "min": 1, "max": 3, "chance": 0.9},
			{"item": "slime_gel", "min": 1, "max": 2, "chance": 0.5},
		],
	},
	"slime_hunt": {
		"name_key": "mission.slime_hunt",
		"rank": "F",
		"duration": 30.0,
		"fee": 10.0,
		"reputation": 1.2,
		"loot": [
			{"item": "slime_gel", "min": 2, "max": 4, "chance": 0.95},
			{"item": "iron_ore", "min": 1, "max": 1, "chance": 0.3},
		],
	},
	"ore_run": {
		"name_key": "mission.ore_run",
		"rank": "E",
		"duration": 45.0,
		"fee": 18.0,
		"reputation": 1.8,
		"loot": [
			{"item": "iron_ore", "min": 1, "max": 3, "chance": 0.9},
			{"item": "moon_shard", "min": 1, "max": 1, "chance": 0.25},
		],
	},
	"relic_dig": {
		"name_key": "mission.relic_dig",
		"rank": "D",
		"duration": 70.0,
		"fee": 40.0,
		"reputation": 3.0,
		"loot": [
			{"item": "moon_shard", "min": 1, "max": 2, "chance": 0.6},
			{"item": "iron_ore", "min": 1, "max": 2, "chance": 0.4},
			{"item": "ancient_coin", "min": 1, "max": 1, "chance": 0.3},
		],
	},
}


static func ids() -> Array[String]:
	var found: Array[String] = []
	for id in TABLE:
		found.append(str(id))
	found.sort()
	return found


static func mission(id: String) -> Dictionary:
	return TABLE.get(id, {})


static func exists(id: String) -> bool:
	return TABLE.has(id)


static func name_key(id: String) -> String:
	return str(mission(id).get("name_key", "mission.none"))


static func rank_index(rank: String) -> int:
	return RANKS.find(rank)


## A mission needs someone of at least its rank: an F-rank recruit cannot be sent
## on a D-rank dig.
static func fits_rank(rank: String, mission_id: String) -> bool:
	var needed := rank_index(str(mission(mission_id).get("rank", "F")))
	return rank_index(rank) >= needed and needed >= 0


## Rolls the loot a finished mission brings back. Returns item id -> count, with
## only the items that actually dropped.
static func roll_loot(mission_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var found: Dictionary = {}
	if rng == null:
		return found
	for entry in mission(mission_id).get("loot", []):
		var row := entry as Dictionary
		if rng.randf() > float(row.get("chance", 1.0)):
			continue
		var item_id := str(row.get("item", ""))
		if not GuildItems.exists(item_id):
			continue
		var amount := rng.randi_range(int(row.get("min", 1)), int(row.get("max", 1)))
		if amount > 0:
			found[item_id] = int(found.get(item_id, 0)) + amount
	return found


## What the guild pays for a pile of loot: the buy price, per item.
static func value_of(loot: Dictionary) -> float:
	var total := 0.0
	for id in loot:
		total += float(loot[id]) * GuildItems.buy_price(str(id))
	return total


static func item_count(loot: Dictionary) -> int:
	var total := 0
	for id in loot:
		total += int(loot[id])
	return total
