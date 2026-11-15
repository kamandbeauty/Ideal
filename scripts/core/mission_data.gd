class_name MissionData
extends RefCounted
## The guided chain that takes a new player from one pump to a finished stop.
## Each mission is a goal the state can measure, plus a cash/gem reward.

## The order follows the prices, not the fiction: the store (1,100) is always
## the first thing a player can afford after the starting 1,500, so asking for the
## restaurant first left new players stuck between the goal and the till.
const MISSIONS: Array[Dictionary] = [
	{"id": "first_upgrade", "reward": 250.0, "gems": 0},
	{"id": "open_store", "reward": 450.0, "gems": 0},
	{"id": "reach_level_three", "reward": 600.0, "gems": 0},
	{"id": "hire_manager", "reward": 800.0, "gems": 0},
	{"id": "open_restaurant", "reward": 900.0, "gems": 0},
	{"id": "buy_branch", "reward": 700.0, "gems": 0},
	{"id": "serve_customers", "reward": 1000.0, "gems": 0},
	{"id": "open_all", "reward": 2000.0, "gems": 0},
	{"id": "complete_town", "reward": 0.0, "gems": 25},
]


static func count() -> int:
	return MISSIONS.size()


static func at(index: int) -> Dictionary:
	if index < 0 or index >= MISSIONS.size():
		return {}
	return MISSIONS[index]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for mission in MISSIONS:
		result.append(str(mission["id"]))
	return result


static func title_key(id: String) -> String:
	return "mission.%s.title" % id


static func description_key(id: String) -> String:
	return "mission.%s.desc" % id
