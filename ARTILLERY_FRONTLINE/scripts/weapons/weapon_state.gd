class_name WeaponState
extends RefCounted
## Fire cadence, ammunition and reload as plain logic. The scene node asks
## `try_fire` in a loop each tick, so the rate of fire is exact at any frame rate.

signal fired(shot_number: int)
signal reload_started(duration: float)
signal reload_finished

var data: WeaponData
var ammo: int = 0
## Spare rounds; negative means the supply never runs out.
var reserve: int = -1
var cooldown: float = 0.0
var reloading: bool = false
var reload_left: float = 0.0
var shots: int = 0


func _init(weapon_data: WeaponData) -> void:
	data = weapon_data
	ammo = data.magazine_size
	reserve = data.reserve


func step(delta: float) -> void:
	# Keep at most one tick of credit: a long pause must not release a burst.
	cooldown = maxf(cooldown - delta, -delta)
	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			reloading = false
			reload_left = 0.0
			var wanted: int = data.magazine_size - ammo
			if reserve >= 0:
				wanted = mini(wanted, reserve)
				reserve -= wanted
			ammo += wanted
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
	if reloading or ammo >= data.magazine_size or reserve == 0:
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


## Nothing loaded and nothing left to load.
func is_spent() -> bool:
	return ammo <= 0 and reserve == 0


## Loaded and spare rounds together; -1 when the supply is unlimited.
func rounds_left() -> int:
	return -1 if reserve < 0 else ammo + reserve


## Adds spare rounds up to the weapon's limit and returns how many fitted.
func add_reserve(amount: int) -> int:
	if reserve < 0 or amount <= 0:
		return 0
	var room: int = amount if data.reserve_max < 0 else maxi(0, data.reserve_max - reserve)
	var taken: int = mini(amount, room)
	reserve += taken
	if taken > 0 and ammo == 0 and data.auto_reload:
		start_reload()
	return taken
