class_name Quality
extends RefCounted
## The three graphics presets and what each one is allowed to spend.
##
## Everything the presets touch is a budget, never a rule: the simulation is
## identical on a flagship and on a five-year-old phone, only the dressing
## changes. That keeps the economy honest while making the game playable on the
## hardware this genre actually runs on.

const LEVELS: Array[String] = ["low", "medium", "high"]
const DEFAULT := "high"
const LABELS := {
	"low": "settings.quality.low",
	"medium": "settings.quality.medium",
	"high": "settings.quality.high",
}


static func normalise(value: String) -> String:
	return value if LEVELS.has(value) else DEFAULT


## How many customer vehicles may be in the world at once.
static func agent_cap(level: String) -> int:
	match normalise(level):
		"low":
			return 3
		"medium":
			return 5
	return 7


static func pedestrian_count(level: String) -> int:
	match normalise(level):
		"low":
			return 4
		"medium":
			return 7
	return 10


## How many plots get a real light; the rest rely on emissive windows and halos.
static func light_budget(level: String) -> int:
	match normalise(level):
		"low":
			return 0
		"medium":
			return 3
	return 6


## 30 fps is a deliberate battery choice on the low preset.
static func max_fps(level: String) -> int:
	match normalise(level):
		"low":
			return 30
		"medium":
			return 60
	return 0


## Push the preset into the engine where it belongs.
static func apply(level: String) -> void:
	Engine.max_fps = max_fps(level)


static func label_key(level: String) -> String:
	return str(LABELS.get(normalise(level), LABELS[DEFAULT]))
