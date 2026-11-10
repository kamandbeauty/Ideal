class_name WaveManager
extends Node
## Combined-arms landing waves for the fixed coastal emplacement.
signal round_started(round_number: int, setup: Dictionary)
signal remaining_changed(remaining: int)
signal intermission_changed(seconds: float)
signal mission_finished(success: bool)

## "heavy" and "rpg" are counted inside "soldiers": they replace riflemen, so target totals are unchanged.
const ROUNDS: Array[Dictionary] = [
	{"soldiers": 8, "rpg": 1, "tanks": 1, "transports": 0, "helicopters": 1, "fighters": 0, "craft": 1, "label": "FIRST LANDING", "support": ["repair", "airstrike"]},
	{"soldiers": 12, "heavy": 2, "rpg": 2, "tanks": 1, "transports": 0, "jeeps": 1, "helicopters": 2, "fighters": 2, "craft": 2, "label": "ARMORED PUSH", "support": ["repair", "airstrike", "helicopter"]},
	{"soldiers": 20, "heavy": 4, "rpg": 3, "tanks": 1, "transports": 0, "apcs": 1, "bosses": 1, "helicopters": 2, "fighters": 2, "craft": 2, "label": "FINAL ASSAULT", "support": ["repair", "airstrike", "helicopter", "airdrop"]}
]
const INTERMISSION: float = 6.0
var round_index: int = -1
var remaining: int = 0
var active: bool = false
var intermission: float = 0.0

static func target_count(setup: Dictionary) -> int:
	return int(setup.soldiers) + int(setup.tanks) + int(setup.transports) + int(setup.get("jeeps", 0)) + int(setup.get("apcs", 0)) + int(setup.get("bosses", 0)) + int(setup.helicopters) + int(setup.fighters) + int(setup.craft)

func start() -> void:
	round_index = -1
	remaining = 0
	intermission = 0.0
	active = true
	_next_round()

func _next_round() -> void:
	round_index += 1
	intermission = 0.0
	intermission_changed.emit(0.0)
	if round_index >= ROUNDS.size():
		active = false
		mission_finished.emit(true)
		return
	var setup: Dictionary = ROUNDS[round_index]
	remaining = target_count(setup)
	remaining_changed.emit(remaining)
	round_started.emit(round_index + 1, setup)

func register_kill() -> void:
	if not active or intermission > 0.0:
		return
	remaining = maxi(0, remaining - 1)
	remaining_changed.emit(remaining)
	if remaining <= 0:
		intermission = INTERMISSION
		intermission_changed.emit(intermission)

func tick(delta: float) -> void:
	if not active:
		return
	if intermission > 0.0:
		intermission = maxf(0.0, intermission - delta)
		intermission_changed.emit(intermission)
		if intermission <= 0.0:
			_next_round()

func current_label() -> String:
	if round_index < 0 or round_index >= ROUNDS.size():
		return "COASTAL DEFENSE"
	return String(ROUNDS[round_index].label)

func supports() -> Array:
	if round_index < 0 or round_index >= ROUNDS.size():
		return ["repair", "airstrike"]
	return ROUNDS[round_index].support

func total_rounds() -> int:
	return ROUNDS.size()
