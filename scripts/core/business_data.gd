class_name BusinessData
extends RefCounted
## Catalogue of the 8 Roadside Empire facilities, their plot positions on the
## desert forecourt, renovation milestones (Lv 1..100) and equipment upgrades.

const MAX_LEVEL := 100
const MAX_BRANCH_LEVEL := 5
const MAX_MANAGER := 10
const MILESTONES: Array[int] = [10, 25, 50, 75, 100]
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

## Highway runs along z = -6.8 (upper diagonal in 38-deg isometric view).
## Canyon cliffs rise at z < -10.5; forecourt spans x in [-8.4..7.8], z in [-4.4..11.6].
const BUSINESSES := {
	"gas_station": {
		"model": "building-garage",
		"icon": "⛽",
		"sign": "GAS",
		"accent": Color(0.95, 0.42, 0.16),
		"roof": Color(0.24, 0.28, 0.56),
		"plot": Vector2(3.4, -1.2),
		"bay_offset": Vector2(-1.6, 2.7),
		"star_req": 1,
		"max_bays": 4,
		"unlock_cost": 0.0,
		"base_price": 24.0,
		"service_seconds": 3.0,
		"base_capacity": 4.0,
		"base_demand": 14.0,
		"base_upkeep": 0.0,
		"upgrade_cost": 35.0,
		"branch_cost": 180.0,
		"manager_cost": 250.0,
		"manager_id": "buck_novak",
	},
	"car_wash": {
		"model": "building-garage",
		"icon": "💧",
		"sign": "WASH",
		"accent": Color(0.14, 0.74, 0.86),
		"roof": Color(0.09, 0.48, 0.64),
		"plot": Vector2(-2.6, -1.8),
		"bay_offset": Vector2(0.0, 2.3),
		"star_req": 1,
		"max_bays": 3,
		"unlock_cost": 300.0,
		"base_price": 56.0,
		"service_seconds": 3.5,
		"base_capacity": 3.0,
		"base_demand": 11.0,
		"base_upkeep": 0.0,
		"upgrade_cost": 95.0,
		"branch_cost": 340.0,
		"manager_cost": 450.0,
		"manager_id": "rico_suds",
	},
	"auto_service": {
		"model": "building-small-c",
		"icon": "⚙️",
		"sign": "AUTO",
		"accent": Color(0.94, 0.68, 0.18),
		"roof": Color(0.26, 0.32, 0.42),
		"plot": Vector2(-6.0, 2.6),
		"bay_offset": Vector2(2.2, 0.0),
		"star_req": 2,
		"max_bays": 3,
		"unlock_cost": 1200.0,
		"base_price": 125.0,
		"service_seconds": 4.0,
		"base_capacity": 3.0,
		"base_demand": 9.0,
		"base_upkeep": 0.0,
		"upgrade_cost": 260.0,
		"branch_cost": 780.0,
		"manager_cost": 900.0,
		"manager_id": "daisy_torque",
	},
	"toilets": {
		"model": "building-small-b",
		"icon": "🚽",
		"sign": "WC",
		"accent": Color(0.28, 0.80, 0.44),
		"roof": Color(0.56, 0.34, 0.24),
		"plot": Vector2(-6.4, -2.0),
		"bay_offset": Vector2(1.9, 1.4),
		"star_req": 2,
		"max_bays": 4,
		"unlock_cost": 2800.0,
		"base_price": 210.0,
		"service_seconds": 2.6,
		"base_capacity": 4.0,
		"base_demand": 12.0,
		"base_upkeep": 0.0,
		"upgrade_cost": 560.0,
		"branch_cost": 1500.0,
		"manager_cost": 1600.0,
		"manager_id": "sunny_clean",
	},
	"diner": {
		"model": "building-small-a",
		"icon": "🍔",
		"sign": "BBQ",
		"accent": Color(0.90, 0.25, 0.26),
		"roof": Color(0.95, 0.72, 0.24),
		"plot": Vector2(5.4, 4.2),
		"bay_offset": Vector2(-2.1, 0.0),
		"star_req": 3,
		"max_bays": 4,
		"unlock_cost": 6800.0,
		"base_price": 440.0,
		"service_seconds": 3.8,
		"base_capacity": 4.0,
		"base_demand": 10.0,
		"base_upkeep": 0.0,
		"upgrade_cost": 1250.0,
		"branch_cost": 3200.0,
		"manager_cost": 3400.0,
		"manager_id": "big_tex",
	},
	"electric_charger": {
		"model": "building-garage",
		"icon": "🔋",
		"sign": "EV",
		"accent": Color(0.20, 0.88, 0.54),
		"roof": Color(0.14, 0.24, 0.30),
		"plot": Vector2(-1.2, 6.2),
		"bay_offset": Vector2(0.0, -2.1),
		"star_req": 4,
		"max_bays": 3,
		"unlock_cost": 16500.0,
		"base_price": 920.0,
		"service_seconds": 3.4,
		"base_capacity": 3.0,
		"base_demand": 9.0,
		"base_upkeep": 0.0,
		"upgrade_cost": 2900.0,
		"branch_cost": 7200.0,
		"manager_cost": 7600.0,
		"manager_id": "volt_vera",
	},
	"motel": {
		"model": "building-small-d",
		"icon": "🏨",
		"sign": "HOTEL",
		"accent": Color(0.58, 0.36, 0.94),
		"roof": Color(0.76, 0.22, 0.34),
		"plot": Vector2(-5.6, 7.8),
		"bay_offset": Vector2(2.2, -0.5),
		"star_req": 5,
		"max_bays": 4,
		"unlock_cost": 42000.0,
		"base_price": 2100.0,
		"service_seconds": 4.8,
		"base_capacity": 4.0,
		"base_demand": 8.0,
		"base_upkeep": 0.0,
		"upgrade_cost": 6800.0,
		"branch_cost": 16000.0,
		"manager_cost": 18000.0,
		"manager_id": "velvet_monroe",
	},
	"drive_in": {
		"model": "building-small-a",
		"icon": "🎬",
		"sign": "CINEMA",
		"accent": Color(0.95, 0.34, 0.64),
		"roof": Color(0.22, 0.16, 0.38),
		"plot": Vector2(4.2, 8.6),
		"bay_offset": Vector2(-2.0, -1.2),
		"star_req": 6,
		"max_bays": 4,
		"unlock_cost": 98000.0,
		"base_price": 4800.0,
		"service_seconds": 5.2,
		"base_capacity": 4.0,
		"base_demand": 8.0,
		"base_upkeep": 0.0,
		"upgrade_cost": 15500.0,
		"branch_cost": 36000.0,
		"manager_cost": 40000.0,
		"manager_id": "shregg_boudreaux",
	},
}

const ORDER: Array[String] = [
	"gas_station",
	"car_wash",
	"auto_service",
	"toilets",
	"diner",
	"electric_charger",
	"motel",
	"drive_in",
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


static func bay_offset(id: String) -> Vector2:
	return data(id).get("bay_offset", Vector2(-2.0, 0.0))


static func accent(id: String) -> Color:
	return data(id).get("accent", Color.WHITE)


static func icon(id: String) -> String:
	return str(data(id).get("icon", "🏢"))


static func sign_text(id: String) -> String:
	return str(data(id).get("sign", "SHOP"))


static func unlock_cost(id: String) -> float:
	return float(data(id).get("unlock_cost", 0.0))


static func star_required(id: String) -> int:
	return int(data(id).get("star_req", 1))


static func max_bays(id: String) -> int:
	return int(data(id).get("max_bays", 3))


static func manager_id(id: String) -> String:
	return str(data(id).get("manager_id", "buck_novak"))


static func branch_label_key(branch: String) -> String:
	return "branch.%s" % branch


## Number of milestones reached at `level` (0..5).
static func milestones_reached(level: int) -> int:
	var count := 0
	for m in MILESTONES:
		if level >= m:
			count += 1
	return count


## Visual stage 1..5 used by 3D props and renovation badges.
static func renovation_stage(level: int) -> int:
	return clampi(1 + milestones_reached(level), 1, 5)


## Next milestone target (e.g. 10, 25, 50, 75, 100).
static func next_milestone(level: int) -> int:
	for m in MILESTONES:
		if level < m:
			return m
	return MAX_LEVEL


static func previous_milestone(level: int) -> int:
	var prev := 1
	for m in MILESTONES:
		if level >= m:
			prev = m
	return prev


## Manager level needed to keep a facility automated after renovations!
static func automation_manager_level(level: int) -> int:
	if level >= 100:
		return 5
	if level >= 75:
		return 4
	if level >= 50:
		return 3
	if level >= 25:
		return 2
	return 1
