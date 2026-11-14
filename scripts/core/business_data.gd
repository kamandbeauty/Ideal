class_name BusinessData
extends RefCounted
## Catalogue of the roadside businesses: where they stand, what they earn and
## what an upgrade costs. Pure static data, read by the state and by tests.

const MAX_LEVEL := 5
const MAX_BRANCH_LEVEL := 5
const MAX_MANAGER := 4
const BRANCHES: Array[String] = ["capacity", "speed", "quality"]

const MODELS := {
	"building-garage": "res://assets/models/building-garage.glb",
	"building-small-a": "res://assets/models/building-small-a.glb",
	"building-small-b": "res://assets/models/building-small-b.glb",
	"building-small-c": "res://assets/models/building-small-c.glb",
	"building-small-d": "res://assets/models/building-small-d.glb",
	"grass": "res://assets/models/grass.glb",
	"grass-trees": "res://assets/models/grass-trees.glb",
	"grass-trees-tall": "res://assets/models/grass-trees-tall.glb",
	"pavement": "res://assets/models/pavement.glb",
	"pavement-fountain": "res://assets/models/pavement-fountain.glb",
	"road-straight": "res://assets/models/road-straight.glb",
	"road-straight-lightposts": "res://assets/models/road-straight-lightposts.glb",
}

const BUSINESSES := {
	"gas_station": {
		"model": "building-garage",
		"accent": Color(0.98, 0.62, 0.24),
		"plot": Vector2(-5.0, 6.0),
		"unlock_cost": 0.0,
		"base_price": 2.6,
		"base_capacity": 6.0,
		"base_demand": 10.0,
		"base_upkeep": 28.0,
		"upgrade_cost": 850.0,
		"branch_cost": 480.0,
		"manager_cost": 900.0,
	},
	"restaurant": {
		"model": "building-small-a",
		"accent": Color(0.95, 0.45, 0.4),
		"plot": Vector2(5.0, 6.0),
		"unlock_cost": 1400.0,
		"base_price": 3.4,
		"base_capacity": 5.0,
		"base_demand": 9.0,
		"base_upkeep": 34.0,
		"upgrade_cost": 980.0,
		"branch_cost": 520.0,
		"manager_cost": 1000.0,
	},
	"store": {
		"model": "building-small-b",
		"accent": Color(0.45, 0.72, 0.96),
		"plot": Vector2(5.0, 0.0),
		"unlock_cost": 1100.0,
		"base_price": 2.0,
		"base_capacity": 8.0,
		"base_demand": 8.0,
		"base_upkeep": 22.0,
		"upgrade_cost": 760.0,
		"branch_cost": 420.0,
		"manager_cost": 800.0,
	},
	"workshop": {
		"model": "building-small-c",
		"accent": Color(0.7, 0.75, 0.8),
		"plot": Vector2(-5.0, 0.0),
		"unlock_cost": 2000.0,
		"base_price": 4.2,
		"base_capacity": 3.0,
		"base_demand": 5.0,
		"base_upkeep": 40.0,
		"upgrade_cost": 1250.0,
		"branch_cost": 620.0,
		"manager_cost": 1200.0,
	},
	"motel": {
		"model": "building-small-d",
		"accent": Color(0.85, 0.55, 0.9),
		"plot": Vector2(-5.0, -6.0),
		"unlock_cost": 3500.0,
		"base_price": 6.0,
		"base_capacity": 4.0,
		"base_demand": 4.0,
		"base_upkeep": 55.0,
		"upgrade_cost": 1800.0,
		"branch_cost": 900.0,
		"manager_cost": 1600.0,
	},
	"car_wash": {
		"model": "building-garage",
		"accent": Color(0.35, 0.85, 0.8),
		"plot": Vector2(5.0, -6.0),
		"unlock_cost": 2600.0,
		"base_price": 1.8,
		"base_capacity": 7.0,
		"base_demand": 7.0,
		"base_upkeep": 26.0,
		"upgrade_cost": 1400.0,
		"branch_cost": 700.0,
		"manager_cost": 1300.0,
	},
}

const ORDER: Array[String] = [
	"gas_station", "restaurant", "store", "workshop", "motel", "car_wash"
]


static func has_business(id: String) -> bool:
	return BUSINESSES.has(id)


static func data(id: String) -> Dictionary:
	if not has_business(id):
		return {}
	return BUSINESSES[id]


static func ids() -> Array[String]:
	return ORDER.duplicate()


static func model_path(id: String) -> String:
	return str(MODELS.get(str(data(id).get("model", "")), ""))


static func plot(id: String) -> Vector2:
	return data(id).get("plot", Vector2.ZERO)


static func accent(id: String) -> Color:
	return data(id).get("accent", Color.WHITE)


static func unlock_cost(id: String) -> float:
	return float(data(id).get("unlock_cost", 0.0))


static func branch_label_key(branch: String) -> String:
	return "branch.%s" % branch
