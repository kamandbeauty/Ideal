class_name TownData
extends RefCounted
## The five towns of the roadmap. The vertical slice plays the first one; the
## others already carry their economy so the world map can be built on top.

const ORDER: Array[String] = ["desert", "forest", "mountain", "coast", "highway"]

const TOWNS := {
	"desert": {
		"traffic": 1.0,
		"income": 1.0,
		"cost": 1.0,
		"reputation_required": 0.0,
		"ground": Color(0.74, 0.6, 0.4),
		"sky_top": Color(0.29, 0.51, 0.83),
		"businesses": [
			"gas_station", "restaurant", "store", "workshop", "motel", "car_wash"
		],
	},
	"forest": {
		"traffic": 0.85,
		"income": 1.2,
		"cost": 1.1,
		"reputation_required": 600.0,
		"ground": Color(0.3, 0.55, 0.3),
		"sky_top": Color(0.3, 0.5, 0.7),
		"businesses": ["restaurant", "store", "motel", "workshop", "car_wash"],
	},
	"mountain": {
		"traffic": 0.9,
		"income": 1.3,
		"cost": 1.25,
		"reputation_required": 1400.0,
		"ground": Color(0.55, 0.56, 0.6),
		"sky_top": Color(0.28, 0.42, 0.62),
		"businesses": ["gas_station", "restaurant", "motel", "workshop", "car_wash"],
	},
	"coast": {
		"traffic": 1.15,
		"income": 1.25,
		"cost": 1.2,
		"reputation_required": 2600.0,
		"ground": Color(0.9, 0.82, 0.6),
		"sky_top": Color(0.3, 0.6, 0.9),
		"businesses": ["restaurant", "store", "motel", "car_wash"],
	},
	"highway": {
		"traffic": 1.4,
		"income": 1.4,
		"cost": 1.4,
		"reputation_required": 4200.0,
		"ground": Color(0.72, 0.68, 0.6),
		"sky_top": Color(0.3, 0.45, 0.6),
		"businesses": [
			"gas_station", "restaurant", "store", "workshop", "motel", "car_wash"
		],
	},
}


static func has_town(id: String) -> bool:
	return TOWNS.has(id)


static func data(id: String) -> Dictionary:
	if not has_town(id):
		return {}
	return TOWNS[id]


static func traffic(id: String) -> float:
	return float(data(id).get("traffic", 1.0))


static func income_multiplier(id: String) -> float:
	return float(data(id).get("income", 1.0))


static func cost_multiplier(id: String) -> float:
	return float(data(id).get("cost", 1.0))


static func reputation_required(id: String) -> float:
	return float(data(id).get("reputation_required", 0.0))


static func businesses(id: String) -> Array:
	var list: Array = data(id).get("businesses", [])
	return list.duplicate()


static func ground_color(id: String) -> Color:
	return data(id).get("ground", Color(0.8, 0.7, 0.5))


static func sky_color(id: String) -> Color:
	return data(id).get("sky_top", Color(0.3, 0.5, 0.8))


static func unlocked_towns(reputation: float) -> Array[String]:
	var result: Array[String] = []
	for id in ORDER:
		if reputation >= reputation_required(id):
			result.append(id)
	return result
