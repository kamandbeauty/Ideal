class_name GameState
extends RefCounted
## The numbers of a run: gold, core integrity, wave counter and phase.
##
## Pure logic with signals, so the tests can drive a whole run without a
## window, a renderer or any scene.

signal gold_changed(gold: int)
signal core_changed(core: int, core_max: int)
signal wave_changed(wave: int, total: int)
signal phase_changed(phase: int)
signal finished(victory: bool)

enum Phase { PREPARE, WAVE, FINISHED }

const STARTING_GOLD := 220
const CORE_MAX := 20
const TOTAL_WAVES := WaveData.TOTAL

var gold: int = STARTING_GOLD
var core: int = CORE_MAX
var wave: int = 0
var completed_waves: int = 0
var phase: int = Phase.PREPARE


func is_finished() -> bool:
	return phase == Phase.FINISHED


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend(cost: int) -> bool:
	if cost < 0 or gold < cost:
		return false
	gold -= cost
	gold_changed.emit(gold)
	return true


func earn(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


func damage_core(amount: int) -> void:
	if is_finished() or amount <= 0:
		return
	core = maxi(0, core - amount)
	core_changed.emit(core, CORE_MAX)
	if core == 0:
		_finish(false)


## Starts the next wave and returns its 1-based index.
func begin_wave() -> int:
	if is_finished() or phase == Phase.WAVE:
		return wave
	wave += 1
	phase = Phase.WAVE
	wave_changed.emit(wave, TOTAL_WAVES)
	phase_changed.emit(phase)
	return wave


## Called when the last enemy of a wave is gone.
func complete_wave() -> void:
	if phase != Phase.WAVE:
		return
	completed_waves = wave
	if wave >= TOTAL_WAVES:
		_finish(true)
	else:
		phase = Phase.PREPARE
		phase_changed.emit(phase)


func finish(victory: bool) -> void:
	if is_finished():
		return
	_finish(victory)


func _finish(victory: bool) -> void:
	phase = Phase.FINISHED
	phase_changed.emit(phase)
	finished.emit(victory)


func snapshot() -> Dictionary:
	return {
		"gold": gold,
		"core": core,
		"core_max": CORE_MAX,
		"wave": wave,
		"completed_waves": completed_waves,
		"phase": phase,
		"total_waves": TOTAL_WAVES,
	}
