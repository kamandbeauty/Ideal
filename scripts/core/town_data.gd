class_name TownData
extends RefCounted
## The 6 Story Mode territories of Roadside Empire across America.

const ORDER: Array[String] = [
	"desert",
	"mojave",
	"forest",
	"swamp",
	"star_city",
	"vegas",
]

const TOWNS := {
	"desert":
	{
		"chapter": 1,
		"traffic": 1.0,
		"income": 1.0,
		"cost": 1.0,
		"star_required": 1,
		"reputation_required": 0.0,
		"ground": Color("#cce34f"),
		"cliff": Color("#b3cd5a"),
		"verge": Color("#d2e753"),
		"sky_top": Color("#86caf3"),
		"businesses": BusinessData.ORDER,
	},
	"mojave":
	{
		"chapter": 2,
		"traffic": 1.12,
		"income": 1.6,
		"cost": 1.25,
		"star_required": 2,
		"reputation_required": 350.0,
		"ground": Color("#cedf60"),
		"cliff": Color("#b5ce61"),
		"verge": Color("#d9e96d"),
		"sky_top": Color("#92cbef"),
		"businesses": BusinessData.ORDER,
	},
	"forest":
	{
		"chapter": 3,
		"traffic": 1.18,
		"income": 2.4,
		"cost": 1.55,
		"star_required": 3,
		"reputation_required": 900.0,
		"ground": Color("#b7d45c"),
		"cliff": Color("#85ac55"),
		"verge": Color("#c4df61"),
		"sky_top": Color("#91cbe8"),
		"businesses": BusinessData.ORDER,
	},
	"swamp":
	{
		"chapter": 4,
		"traffic": 1.25,
		"income": 3.6,
		"cost": 1.95,
		"star_required": 4,
		"reputation_required": 1800.0,
		"ground": Color("#b0d778"),
		"cliff": Color("#85b878"),
		"verge": Color("#bce37b"),
		"sky_top": Color("#9cd4d9"),
		"businesses": BusinessData.ORDER,
	},
	"star_city":
	{
		"chapter": 5,
		"traffic": 1.35,
		"income": 5.2,
		"cost": 2.5,
		"star_required": 5,
		"reputation_required": 3000.0,
		"ground": Color("#b9d991"),
		"cliff": Color("#99bc90"),
		"verge": Color("#c5e59c"),
		"sky_top": Color("#9fc6ed"),
		"businesses": BusinessData.ORDER,
	},
	"vegas":
	{
		"chapter": 6,
		"traffic": 1.55,
		"income": 8.0,
		"cost": 3.2,
		"star_required": 6,
		"reputation_required": 4600.0,
		"ground": Color("#cfe16a"),
		"cliff": Color("#b5c46a"),
		"verge": Color("#dceb7d"),
		"sky_top": Color("#9bc7ef"),
		"businesses": BusinessData.ORDER,
	},
}


static func has_town(id: String) -> bool:
	return TOWNS.has(id)


static func data(id: String) -> Dictionary:
	if not has_town(id):
		return {}
	return TOWNS[id]


static func chapter(id: String) -> int:
	return int(data(id).get("chapter", 1))


static func traffic(id: String) -> float:
	return float(data(id).get("traffic", 1.0))


static func income_multiplier(id: String) -> float:
	return float(data(id).get("income", 1.0))


static func cost_multiplier(id: String) -> float:
	return float(data(id).get("cost", 1.0))


static func star_required(id: String) -> int:
	return int(data(id).get("star_required", 1))


static func reputation_required(id: String) -> float:
	return float(data(id).get("reputation_required", 0.0))


static func businesses(id: String) -> Array:
	var list: Array = data(id).get("businesses", BusinessData.ORDER)
	return list.duplicate()


static func ground_color(id: String) -> Color:
	return data(id).get("ground", CartoonPalette.GRASS)


static func cliff_color(id: String) -> Color:
	return data(id).get("cliff", Color(0.86, 0.60, 0.34))


static func verge_color(id: String) -> Color:
	return data(id).get("verge", CartoonPalette.GRASS_LIGHT)


static func sky_color(id: String) -> Color:
	return data(id).get("sky_top", Color(0.34, 0.64, 0.94))


static func unlocked_towns(reputation: float, star_level: int = 1) -> Array[String]:
	var result: Array[String] = []
	for id in ORDER:
		if star_level >= star_required(id) or reputation >= reputation_required(id):
			result.append(id)
	return result
