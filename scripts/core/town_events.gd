class_name TownEvents
extends RefCounted
## Short roadside events. They are simple multipliers, so the economy stays
## deterministic and testable and nothing depends on the frame rate.

const TYPES := {
	"rush": {"duration": 90.0, "traffic": 1.8, "income": 1.0},
	"holiday": {"duration": 120.0, "traffic": 1.5, "income": 1.2},
	"rain": {"duration": 90.0, "traffic": 0.6, "income": 0.9},
	"breakdown": {"duration": 60.0, "traffic": 1.0, "income": 0.75},
	"festival": {"duration": 90.0, "traffic": 1.2, "income": 1.3},
	"power_cut": {"duration": 45.0, "traffic": 0.8, "income": 0.8},
}


static func has(id: String) -> bool:
	return TYPES.has(id)


static func ids() -> Array[String]:
	var result: Array[String] = []
	for id in TYPES:
		result.append(str(id))
	result.sort()
	return result


static func duration(id: String) -> float:
	return float(TYPES.get(id, {}).get("duration", 0.0))


static func traffic(id: String) -> float:
	if id.is_empty():
		return 1.0
	return float(TYPES.get(id, {}).get("traffic", 1.0))


static func income(id: String) -> float:
	if id.is_empty():
		return 1.0
	return float(TYPES.get(id, {}).get("income", 1.0))


static func name_key(id: String) -> String:
	return "event.%s.name" % id


static func description_key(id: String) -> String:
	return "event.%s.desc" % id


## Picks an event, avoiding the one that just ended.
static func pick(rng: RandomNumberGenerator, avoid: String = "") -> String:
	var options := ids()
	if options.is_empty():
		return ""
	if options.size() > 1 and not avoid.is_empty():
		options.erase(avoid)
	return options[rng.randi_range(0, options.size() - 1)]
