class_name WeaponState
extends RefCounted
## Pure weapon state; presentation and input are handled elsewhere.

signal changed
signal reload_started
signal reload_finished

var config: WeaponConfig
var ammunition: Array[AmmoConfig] = []
var rounds: Dictionary = {}
var selected_index: int = 0
var chambered: bool = true
var reload_remaining: float = 0.0


func setup(weapon: WeaponConfig, ammo_types: Array[AmmoConfig]) -> void:
	config = weapon
	ammunition.clear()
	for ammo in ammo_types:
		if weapon.compatible_ammunition.has(ammo.id):
			ammunition.append(ammo)
	assert(not ammunition.is_empty(), "Weapon needs at least one compatible ammunition type")
	rounds.clear()
	for ammo in ammunition:
		rounds[ammo.id] = ammo.starting_rounds
	selected_index = 0
	chambered = true
	reload_remaining = 0.0


func current_ammo() -> AmmoConfig:
	return ammunition[selected_index]


func current_rounds() -> int:
	return int(rounds.get(current_ammo().id, 0))


func can_fire() -> bool:
	return chambered and reload_remaining <= 0.0 and current_rounds() > 0


func fire() -> bool:
	if not can_fire():
		return false
	var ammo := current_ammo()
	rounds[ammo.id] = current_rounds() - 1
	chambered = false
	changed.emit()
	return true


func request_reload() -> bool:
	if chambered or reload_remaining > 0.0 or current_rounds() <= 0:
		return false
	reload_remaining = maxf(config.reload_seconds, 0.01)
	reload_started.emit()
	changed.emit()
	return true


func advance(delta: float) -> void:
	if reload_remaining <= 0.0:
		return
	reload_remaining = maxf(0.0, reload_remaining - maxf(delta, 0.0))
	if reload_remaining <= 0.0:
		chambered = true
		reload_finished.emit()
	changed.emit()


func select_ammo(index: int) -> bool:
	if index < 0 or index >= ammunition.size() or index == selected_index:
		return false
	# Switching rounds aborts any reload; a different round must be chambered.
	selected_index = index
	reload_remaining = 0.0
	chambered = false
	changed.emit()
	return true


func has_any_rounds() -> bool:
	for ammo in ammunition:
		if int(rounds.get(ammo.id, 0)) > 0:
			return true
	return false
