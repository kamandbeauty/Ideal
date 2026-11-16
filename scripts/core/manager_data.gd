class_name ManagerData
extends RefCounted
## Catalogue of Roadside Empire Managers, Rarity Cards, Bourbon upgrade costs
## and Supply Cases.

const MAX_LEVEL := 10
const RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]

const RARITY_COLORS := {
	"common": Color(0.54, 0.63, 0.74),
	"rare": Color(0.24, 0.62, 0.98),
	"epic": Color(0.68, 0.36, 0.96),
	"legendary": Color(1.0, 0.74, 0.18),
}

const MANAGERS := {
	"buck_novak": {
		"facility": "gas_station",
		"rarity": "common",
		"avatar": "🧑‍🔧",
		"base_mult": 1.5,
		"level_mult": 0.45,
		"speed_bonus": 0.15,
		"color": Color(0.95, 0.38, 0.20),
	},
	"rico_suds": {
		"facility": "car_wash",
		"rarity": "common",
		"avatar": "🧑‍🚒",
		"base_mult": 1.6,
		"level_mult": 0.45,
		"speed_bonus": 0.18,
		"color": Color(0.16, 0.74, 0.88),
	},
	"daisy_torque": {
		"facility": "auto_service",
		"rarity": "rare",
		"avatar": "👩‍🔧",
		"base_mult": 1.85,
		"level_mult": 0.55,
		"speed_bonus": 0.20,
		"color": Color(0.95, 0.68, 0.18),
	},
	"sunny_clean": {
		"facility": "toilets",
		"rarity": "common",
		"avatar": "🧹",
		"base_mult": 1.6,
		"level_mult": 0.45,
		"speed_bonus": 0.22,
		"color": Color(0.30, 0.82, 0.46),
	},
	"big_tex": {
		"facility": "diner",
		"rarity": "rare",
		"avatar": "🤠",
		"base_mult": 2.0,
		"level_mult": 0.60,
		"speed_bonus": 0.20,
		"color": Color(0.90, 0.26, 0.28),
	},
	"volt_vera": {
		"facility": "electric_charger",
		"rarity": "epic",
		"avatar": "👩‍🔬",
		"base_mult": 2.35,
		"level_mult": 0.75,
		"speed_bonus": 0.25,
		"color": Color(0.22, 0.88, 0.56),
	},
	"velvet_monroe": {
		"facility": "motel",
		"rarity": "epic",
		"avatar": "🕶️",
		"base_mult": 2.5,
		"level_mult": 0.80,
		"speed_bonus": 0.24,
		"color": Color(0.64, 0.38, 0.96),
	},
	"shregg_boudreaux": {
		"facility": "drive_in",
		"rarity": "legendary",
		"avatar": "👑",
		"base_mult": 3.2,
		"level_mult": 1.05,
		"speed_bonus": 0.30,
		"global_bonus": 0.20,
		"color": Color(1.0, 0.76, 0.20),
	},
}

const ORDER: Array[String] = [
	"buck_novak",
	"rico_suds",
	"daisy_torque",
	"sunny_clean",
	"big_tex",
	"volt_vera",
	"velvet_monroe",
	"shregg_boudreaux",
]

const CASES := {
	"free_crate": {
		"gem_cost": 0,
		"cooldown": 180.0,
		"cards": 2,
		"bourbon_min": 14,
		"bourbon_max": 26,
		"cash_minutes": 1.2,
		"weights": {"common": 72, "rare": 24, "epic": 4, "legendary": 0},
	},
	"common_case": {
		"gem_cost": 10,
		"cooldown": 0.0,
		"cards": 3,
		"bourbon_min": 25,
		"bourbon_max": 42,
		"cash_minutes": 2.0,
		"weights": {"common": 62, "rare": 28, "epic": 9, "legendary": 1},
	},
	"rare_case": {
		"gem_cost": 25,
		"cooldown": 0.0,
		"cards": 5,
		"bourbon_min": 65,
		"bourbon_max": 95,
		"cash_minutes": 4.0,
		"weights": {"common": 30, "rare": 46, "epic": 20, "legendary": 4},
	},
	"epic_case": {
		"gem_cost": 55,
		"cooldown": 0.0,
		"cards": 8,
		"bourbon_min": 150,
		"bourbon_max": 220,
		"cash_minutes": 8.0,
		"weights": {"common": 10, "rare": 32, "epic": 42, "legendary": 16},
	},
}


static func has_manager(id: String) -> bool:
	return MANAGERS.has(id)


static func data(id: String) -> Dictionary:
	return MANAGERS.get(id, {})


static func ids() -> Array[String]:
	return ORDER.duplicate()


static func for_facility(facility_id: String) -> String:
	for id in ORDER:
		if str(MANAGERS[id].get("facility", "")) == facility_id:
			return id
	return "buck_novak"


static func rarity(id: String) -> String:
	return str(data(id).get("rarity", "common"))


static func rarity_color(id: String) -> Color:
	return RARITY_COLORS.get(rarity(id), Color.WHITE)


static func avatar(id: String) -> String:
	return str(data(id).get("avatar", "🧑‍💼"))


static func income_multiplier(id: String, level: int) -> float:
	if level <= 0 or not has_manager(id):
		return 1.0
	var entry := data(id)
	return float(entry.get("base_mult", 1.5)) + float(entry.get("level_mult", 0.4)) * float(level - 1)


static func speed_multiplier(id: String, level: int) -> float:
	if level <= 0 or not has_manager(id):
		return 1.0
	var bonus := float(data(id).get("speed_bonus", 0.15))
	return 1.0 + bonus + 0.04 * float(level - 1)


static func global_bonus(id: String, level: int) -> float:
	if level <= 0 or not has_manager(id):
		return 0.0
	var base := float(data(id).get("global_bonus", 0.0))
	if base <= 0.0:
		return 0.0
	return base + 0.05 * float(level - 1)


static func cards_needed(current_level: int) -> int:
	if current_level >= MAX_LEVEL:
		return 0
	return maxi(1, current_level + 1)


static func bourbon_needed(current_level: int) -> int:
	if current_level >= MAX_LEVEL:
		return 0
	if current_level <= 0:
		return 10
	return 15 * current_level


static func pick_manager_by_rarity(rng: RandomNumberGenerator, rarity_name: String) -> String:
	var pool: Array[String] = []
	for id in ORDER:
		if rarity(id) == rarity_name:
			pool.append(id)
	if pool.is_empty():
		return ORDER[rng.randi_range(0, ORDER.size() - 1)]
	return pool[rng.randi_range(0, pool.size() - 1)]


static func roll_case_cards(rng: RandomNumberGenerator, case_id: String) -> Dictionary:
	var spec: Dictionary = CASES.get(case_id, CASES["common_case"])
	var count := int(spec.get("cards", 3))
	var weights: Dictionary = spec.get("weights", {"common": 70, "rare": 25, "epic": 5})
	var drops: Dictionary = {}
	for _i in count:
		var total_w := 0
		for r in RARITIES:
			total_w += int(weights.get(r, 0))
		var roll := rng.randi_range(1, maxi(1, total_w))
		var chosen_rarity := "common"
		var acc := 0
		for r in RARITIES:
			acc += int(weights.get(r, 0))
			if roll <= acc:
				chosen_rarity = r
				break
		var mgr := pick_manager_by_rarity(rng, chosen_rarity)
		drops[mgr] = int(drops.get(mgr, 0)) + 1
	return drops
