extends CharacterBody3D
## Hero controller for "The Sky Bridge" level.
## Handles swipe-based lateral movement, constant forward movement,
## automatic targeting/shooting, reload, health, and death.

signal health_changed(current: float, max: float)
signal died

@export var forward_speed: float = 6.0
@export var lateral_speed: float = 10.0
@export var lane_half_width: float = 4.0  # bridge playable half-width
@export var max_health: float = 100.0
@export var fire_rate: float = 6.0        # shots per second
@export var magazine_size: int = 30
@export var reload_time: float = 1.5
@export var attack_range: float = 18.0

@export var muzzle_point: NodePath        # TODO: assign in editor (Marker3D at gun barrel)
@export var animation_player: NodePath    # TODO: assign in editor

var _current_health: float
var _ammo: int
var _is_reloading: bool = false
var _fire_cooldown: float = 0.0
var _current_target: Node3D = null
var _swipe_start_x: float = 0.0
var _touch_active: bool = false
var _lane_offset: float = 0.0  # -lane_half_width .. +lane_half_width

@onready var _anim: AnimationPlayer = get_node_or_null(animation_player)
@onready var _muzzle: Node3D = get_node_or_null(muzzle_point)

func _ready() -> void:
	_current_health = max_health
	_ammo = magazine_size
	health_changed.emit(_current_health, max_health)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_active = true
			_swipe_start_x = event.position.x
		else:
			_touch_active = false
	elif event is InputEventScreenDrag and _touch_active:
		var delta_x: float = event.position.x - _swipe_start_x
		_swipe_start_x = event.position.x
		# Convert screen-space drag to world lateral movement.
		_lane_offset = clamp(_lane_offset + delta_x * 0.01 * lateral_speed, -lane_half_width, lane_half_width)

func _physics_process(delta: float) -> void:
	if _current_health <= 0.0:
		return

	_move(delta)
	_update_target()
	_handle_firing(delta)

func _move(delta: float) -> void:
	var target_x: float = _lane_offset
	var current_x: float = position.x
	var new_x: float = move_toward(current_x, target_x, lateral_speed * delta)

	velocity.x = (new_x - current_x) / max(delta, 0.0001)
	velocity.z = -forward_speed  # bridge runs along -Z; adjust to your scene orientation
	move_and_slide()

	if _anim and _anim.current_animation != "Running":
		_anim.play("Running")

func _update_target() -> void:
	# Simple nearest-enemy-in-range targeting.
	# TODO: replace with your actual enemy group / spatial query.
	var enemies := get_tree().get_nodes_in_group("zombies")
	var closest: Node3D = null
	var closest_dist: float = attack_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest = enemy
			closest_dist = dist

	_current_target = closest

func _handle_firing(delta: float) -> void:
	if _is_reloading:
		return

	if _current_target == null:
		return

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_fire_cooldown = 1.0 / fire_rate
		_fire_shot()

func _fire_shot() -> void:
	if _ammo <= 0:
		_start_reload()
		return

	_ammo -= 1

	if _anim:
		_anim.play("Shooting")

	# TODO: instance muzzle flash + bullet trail effect at _muzzle.global_transform
	# TODO: play shooting SFX

	if _current_target and is_instance_valid(_current_target) and _current_target.has_method("take_damage"):
		_current_target.take_damage(10.0)  # placeholder damage value

func _start_reload() -> void:
	_is_reloading = true
	if _anim:
		_anim.play("Reloading")
	await get_tree().create_timer(reload_time).timeout
	_ammo = magazine_size
	_is_reloading = false

func take_damage(amount: float) -> void:
	if _current_health <= 0.0:
		return

	_current_health = max(_current_health - amount, 0.0)
	health_changed.emit(_current_health, max_health)

	if _anim:
		_anim.play("HitReaction")

	if _current_health <= 0.0:
		_die()

func _die() -> void:
	if _anim:
		_anim.play("Death")
	died.emit()
	# GameManager should listen to `died` and trigger the defeat screen
	# ("شکست خوردید!") per the spec.

func play_victory() -> void:
	if _anim:
		_anim.play("Victory")

func get_ammo_fraction() -> float:
	return float(_ammo) / float(magazine_size)
