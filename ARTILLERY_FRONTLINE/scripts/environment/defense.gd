class_name Defense
extends Node
## Health of the wall and the gate. Zombies at the gate wear the gate down;
## once it falls, each one that runs through tears at the wall itself, as do
## those clawing at the wall directly. The wall reaching zero ends the match.

## A blow landed: lets the level shake the gate and raise dust.
signal struck(target: String, position: Vector3, amount: float)

@export var data: DefenseData

var wall_health: float = 0.0
var gate_health: float = 0.0
var gate_destroyed: bool = false
var breached: bool = false
var clock: float = 0.0
var warned: Dictionary = {}
var last_attack_warning: Dictionary = {}


func _ready() -> void:
	if data == null:
		data = DefenseData.new()
	reset()


func reset() -> void:
	wall_health = data.wall_max_health
	gate_health = data.gate_max_health
	gate_destroyed = false
	breached = false
	clock = 0.0
	warned.clear()
	last_attack_warning.clear()


func _physics_process(delta: float) -> void:
	clock += delta


func wall_fraction() -> float:
	return wall_health / data.wall_max_health


func gate_fraction() -> float:
	return gate_health / data.gate_max_health


## `target` is "gate" or "wall". Blows on a fallen gate pass through to the wall.
func apply_damage(target: String, amount: float, position: Vector3 = Vector3.ZERO) -> void:
	if breached or amount <= 0.0:
		return
	var actual: String = target if (target == "gate" and not gate_destroyed) else "wall"
	_announce_attack(actual)
	if actual == "gate":
		gate_health = maxf(0.0, gate_health - amount)
		Events.gate_damaged.emit(amount, gate_health, data.gate_max_health)
		_thresholds("gate", gate_fraction())
		struck.emit("gate", position, amount)
		if gate_health <= 0.0:
			gate_destroyed = true
			Events.gate_destroyed.emit()
	else:
		struck.emit("wall", position, amount)
		_damage_wall(amount)


## A zombie made it through the fallen gate into the city.
func apply_breach(amount: float) -> void:
	if breached or amount <= 0.0:
		return
	_damage_wall(amount)


func _damage_wall(amount: float) -> void:
	wall_health = maxf(0.0, wall_health - amount)
	Events.wall_damaged.emit(amount, wall_health, data.wall_max_health)
	_thresholds("wall", wall_fraction())
	if wall_health <= 0.0:
		breached = true
		Events.wall_breached.emit()


func _thresholds(target: String, fraction: float) -> void:
	if fraction <= data.critical_threshold and not warned.has(target + "_critical"):
		warned[target + "_critical"] = true
		warned[target + "_half"] = true
		Events.defense_warning.emit(target + "_critical")
	elif fraction <= data.half_threshold and not warned.has(target + "_half"):
		warned[target + "_half"] = true
		Events.defense_warning.emit(target + "_half")


func _announce_attack(target: String) -> void:
	# Announce the start of an assault, not every blow of it.
	var last: float = last_attack_warning.get(target, -1000.0)
	last_attack_warning[target] = clock
	if clock - last >= data.attack_warning_cooldown:
		Events.defense_warning.emit(target + "_attack")
