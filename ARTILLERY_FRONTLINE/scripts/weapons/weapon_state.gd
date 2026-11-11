class_name WeaponState
extends RefCounted
## Fire cadence, ammunition and reload as plain logic. The scene node asks
## `try_fire` in a loop each tick, so the rate of fire is exact at any frame rate.

signal fired(shot_number: int)
signal reload_started(duration: float)
signal reload_finished

var data: WeaponData
var ammo: int = 0
var cooldown: float = 0.0
var reloading: bool = false
var reload_left: float = 0.0
var shots: int = 0


func _init(weapon_data: WeaponData) -> void:
	data = weapon_data
	ammo = data.magazine_size


func step(delta: float) -> void:
	# Keep at most one tick of credit: a long pause must not release a burst.
	cooldown = maxf(cooldown - delta, -delta)
	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			reloading = false
			reload_left = 0.0
			ammo = data.magazine_size
			reload_finished.emit()


func can_fire() -> bool:
	return not reloading and ammo > 0 and cooldown <= 0.0


func try_fire() -> bool:
	if not can_fire():
		return false
	ammo -= 1
	shots += 1
	cooldown += data.fire_interval
	fired.emit(shots)
	if ammo == 0 and data.auto_reload:
		start_reload()
	return true


func start_reload() -> bool:
	if reloading or ammo >= data.magazine_size:
		return false
	reloading = true
	reload_left = data.reload_time
	reload_started.emit(data.reload_time)
	return true


## 0 at the start of a reload, 1 when it completes (and whenever idle).
func reload_progress() -> float:
	if not reloading:
		return 1.0
	return clampf(1.0 - reload_left / data.reload_time, 0.0, 1.0)
