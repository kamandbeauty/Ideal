class_name TownEvents
extends RefCounted
## Roadside Empire events & live expeditions: Monster Hills, BBQ Fest,
## Burning Fest, Rush Hour, Holiday Convoy and Desert Sandstorm.

const EVENTS := {
	"monster_hills": {
		"duration": 90.0,
		"traffic": 1.6,
		"income": 2.5,
		"monster": true,
	},
	"holiday": {
		"duration": 120.0,
		"traffic": 1.5,
		"income": 2.0,
		"monster": false,
	},
	"rush_hour": {
		"duration": 90.0,
		"traffic": 1.85,
		"income": 1.3,
		"monster": false,
	},
	"bbq_fest": {
		"duration": 95.0,
		"traffic": 1.4,
		"income": 1.75,
		"monster": false,
	},
	"burning_fest": {
		"duration": 100.0,
		"traffic": 1.55,
		"income": 1.9,
		"monster": false,
	},
	"sandstorm": {
		"duration": 50.0,
		"traffic": 0.78,
		"income": 0.9,
		"monster": false,
	},
}

const ORDER: Array[String] = [
	"monster_hills",
	"holiday",
	"rush_hour",
	"bbq_fest",
	"burning_fest",
	"sandstorm",
]


static func has_event(id: String) -> bool:
	return EVENTS.has(id)


static func duration(id: String) -> float:
	return float(EVENTS.get(id, {}).get("duration", 0.0))


static func traffic_multiplier(id: String) -> float:
	if not has_event(id):
		return 1.0
	return float(EVENTS[id]["traffic"])


static func income_multiplier(id: String) -> float:
	if not has_event(id):
		return 1.0
	return float(EVENTS[id]["income"])


static func spawns_monsters(id: String) -> bool:
	return bool(EVENTS.get(id, {}).get("monster", false))


static func name_key(id: String) -> String:
	return "event.%s" % id


static func pick(rng: RandomNumberGenerator, exclude: String = "") -> String:
	var pool: Array[String] = []
	for id in ORDER:
		if id != exclude and id != "monster_hills":
			pool.append(id)
	if pool.is_empty():
		return ORDER[0]
	return pool[rng.randi_range(0, pool.size() - 1)]
