class_name TowerData
extends RefCounted
## Tower catalogue: build costs, upgrade costs and per-level combat stats.
##
## Level 1 is what you get when you build; levels 2 and 3 are upgrades. `cost`
## inside a level entry is the price of reaching that level.

const TYPES: Array[String] = ["sentry", "cannon", "frost"]
const MAX_LEVEL := 3

const TOWERS := {
	"sentry": {
		"color": Color(0.35, 0.78, 1.0),
		"levels": [
			{"cost": 60, "damage": 10.0, "range": 7.0, "cooldown": 0.7, "splash": 0.0, "slow": 0.0, "slow_time": 0.0},
			{"cost": 80, "damage": 17.0, "range": 8.0, "cooldown": 0.62, "splash": 0.0, "slow": 0.0, "slow_time": 0.0},
			{"cost": 130, "damage": 27.0, "range": 9.0, "cooldown": 0.55, "splash": 0.0, "slow": 0.0, "slow_time": 0.0},
		],
	},
	"cannon": {
		"color": Color(1.0, 0.62, 0.28),
		"levels": [
			{"cost": 110, "damage": 34.0, "range": 6.5, "cooldown": 1.7, "splash": 2.6, "slow": 0.0, "slow_time": 0.0},
			{"cost": 130, "damage": 52.0, "range": 7.0, "cooldown": 1.6, "splash": 3.0, "slow": 0.0, "slow_time": 0.0},
			{"cost": 190, "damage": 82.0, "range": 7.5, "cooldown": 1.5, "splash": 3.4, "slow": 0.0, "slow_time": 0.0},
		],
	},
	"frost": {
		"color": Color(0.45, 0.9, 0.95),
		"levels": [
			{"cost": 90, "damage": 5.0, "range": 6.0, "cooldown": 1.5, "splash": 3.2, "slow": 0.4, "slow_time": 1.6},
			{"cost": 100, "damage": 8.0, "range": 6.6, "cooldown": 1.4, "splash": 3.6, "slow": 0.5, "slow_time": 1.9},
			{"cost": 150, "damage": 12.0, "range": 7.2, "cooldown": 1.3, "splash": 4.0, "slow": 0.6, "slow_time": 2.2},
		],
	},
}


static func has_type(kind: String) -> bool:
	return TOWERS.has(kind)


static func levels(kind: String) -> Array:
	if not has_type(kind):
		return []
	return TOWERS[kind]["levels"]


static func max_level(kind: String) -> int:
	return levels(kind).size()


static func stats(kind: String, level: int) -> Dictionary:
	var table := levels(kind)
	if table.is_empty():
		return {}
	return table[clampi(level, 1, table.size()) - 1]


static func build_cost(kind: String) -> int:
	return int(stats(kind, 1).get("cost", 0))


## Cost of going from `level` to `level + 1`; 0 when already at the top.
static func upgrade_cost(kind: String, level: int) -> int:
	if level >= max_level(kind):
		return 0
	return int(stats(kind, level + 1).get("cost", 0))


## Total gold put into a tower that is now at `level`.
static func invested(kind: String, level: int) -> int:
	var total := 0
	var table := levels(kind)
	for i in mini(level, table.size()):
		total += int(table[i].get("cost", 0))
	return total


static func sell_value(kind: String, level: int) -> int:
	return int(floor(invested(kind, level) * 0.6))


static func color(kind: String) -> Color:
	if not has_type(kind):
		return Color.WHITE
	return TOWERS[kind]["color"]



static func range_for(kind: String, level: int) -> float:
	return float(stats(kind, level).get("range", 6.0))


static func cooldown_for(kind: String, level: int) -> float:
	return maxf(0.1, float(stats(kind, level).get("cooldown", 1.0)))


static func damage_for(kind: String, level: int) -> float:
	return float(stats(kind, level).get("damage", 0.0))


static func splash_for(kind: String, level: int) -> float:
	return float(stats(kind, level).get("splash", 0.0))


static func slow_for(kind: String, level: int) -> float:
	return float(stats(kind, level).get("slow", 0.0))


static func slow_time_for(kind: String, level: int) -> float:
	return float(stats(kind, level).get("slow_time", 0.0))
