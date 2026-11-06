class_name WaveManager
extends Node
## Round-based landing waves for the coastal milestone.
signal round_started(round_number: int, setup: Dictionary)
signal remaining_changed(remaining: int)
signal mission_finished(success: bool)

const ROUNDS: Array[Dictionary] = [
	{"soldiers": 8, "craft": 1, "label": "FIRST LANDING", "support": ["repair"]},
	{"soldiers": 12, "craft": 1, "label": "ARMORED PUSH", "support": ["repair", "airstrike"]},
	{"soldiers": 16, "craft": 2, "label": "FINAL ASSAULT", "support": ["repair", "airstrike", "helicopter", "airdrop"]}
]
var round_index: int = -1
var remaining: int = 0
var active: bool = false
var intermission: float = 0.0

func start() -> void:
	round_index = -1
	active = true
	_next_round()

func _next_round() -> void:
	round_index += 1
	if round_index >= ROUNDS.size():
		active = false
		mission_finished.emit(true)
		return
	var setup: Dictionary = ROUNDS[round_index]
	remaining = int(setup.soldiers)
	remaining_changed.emit(remaining)
	round_started.emit(round_index + 1, setup)

func register_kill() -> void:
	if not active:
		return
	remaining = maxi(0, remaining - 1)
	remaining_changed.emit(remaining)
	if remaining <= 0:
		intermission = 3.0

func tick(delta: float) -> void:
	if not active:
		return
	if intermission > 0.0:
		intermission -= delta
		if intermission <= 0.0:
			_next_round()

func current_label() -> String:
	if round_index < 0 or round_index >= ROUNDS.size():
		return "COASTAL DEFENSE"
	return String(ROUNDS[round_index].label)

func supports() -> Array:
	if round_index < 0 or round_index >= ROUNDS.size():
		return ["repair"]
	return ROUNDS[round_index].support

func total_rounds() -> int:
	return ROUNDS.size()
