class_name EnemyData
extends RefCounted
## Enemy catalogue.

const TYPES := {
	"grunt": {
		"health": 46.0,
		"speed": 2.1,
		"gold": 7,
		"core_damage": 1,
		"scale": 1.0,
		"color": Color(0.62, 0.78, 0.42),
	},
	"runner": {
		"health": 28.0,
		"speed": 4.3,
		"gold": 6,
		"core_damage": 1,
		"scale": 0.85,
		"color": Color(0.95, 0.78, 0.35),
	},
	"tank": {
		"health": 190.0,
		"speed": 1.35,
		"gold": 22,
		"core_damage": 3,
		"scale": 1.35,
		"color": Color(0.78, 0.45, 0.42),
	},
	"boss": {
		"health": 950.0,
		"speed": 1.1,
		"gold": 120,
		"core_damage": 8,
		"scale": 1.9,
		"color": Color(0.62, 0.4, 0.9),
	},
}


static func has_type(kind: String) -> bool:
	return TYPES.has(kind)


static func get_type(kind: String) -> Dictionary:
	if not has_type(kind):
		push_warning("EnemyData: unknown type '%s'" % kind)
		return TYPES["grunt"]
	return TYPES[kind]


static func health_of(kind: String) -> float:
	return float(get_type(kind)["health"])


static func speed_of(kind: String) -> float:
	return float(get_type(kind)["speed"])


static func gold_of(kind: String) -> int:
	return int(get_type(kind)["gold"])


static func core_damage_of(kind: String) -> int:
	return int(get_type(kind)["core_damage"])


static func scale_of(kind: String) -> float:
	return float(get_type(kind)["scale"])


static func color_of(kind: String) -> Color:
	return get_type(kind)["color"]
