extends CharacterBody3D
## Base enemy script covering all three Level-1 enemy types.
## Set `zombie_type` in the Inspector per-instance (or per-scene variant);
## stat defaults below match the spec, but can be overridden per scene.

signal died(zombie: Node3D)
signal damaged(current: float, max: float)

enum ZombieType { NORMAL, RUNNER, BRUTE }

@export var zombie_type: ZombieType = ZombieType.NORMAL
@export var animation_player: NodePath  # TODO: assign in editor

@export_group("Normal stats (used if type == NORMAL)")
@export var normal_health: float = 30.0
@export var normal_speed: float = 3.0
@export var normal_attack_damage: float = 8.0

@export_group("Runner stats (used if type == RUNNER)")
@export var runner_health: float = 20.0
@export var runner_speed: float = 6.5
@export var runner_attack_damage: float = 6.0

@export_group("Brute stats (used if type == BRUTE)")
@export var brute_health: float = 220.0
@export var brute_speed: float = 1.8
@export var brute_attack_damage: float = 25.0
@export var is_boss: bool = false  # true for "The Bridge Destroyer"

@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.2

var _max_health: float
var _current_health: float
var _speed: float
var _attack_damage: float
var _attack_timer: float = 0.0
var _target: Node3D = null

@onready var _anim: AnimationPlayer = get_node_or_null(animation_player)

func _ready() -> void:
	add_to_group("zombies")
	match zombie_type:
		ZombieType.NORMAL:
			_max_health = normal_health
			_speed = normal_speed
			_attack_damage = normal_attack_damage
		ZombieType.RUNNER:
			_max_health = runner_health
			_speed = runner_speed
			_attack_damage = runner_attack_damage
		ZombieType.BRUTE:
			_max_health = brute_health
			_speed = brute_speed
			_attack_damage = brute_attack_damage

	_current_health = _max_health

func _physics_process(delta: float) -> void:
	if _current_health <= 0.0:
		return

	_find_target()
	if _target == null:
		return

	var dist: float = global_position.distance_to(_target.global_position)
	if dist > attack_range:
		_chase(delta)
	else:
		_attack(delta)

func _find_target() -> void:
	# Prefer the nearest of: hero, any living soldier.
	# TODO: replace with your actual spatial/group query if you have many soldiers.
	var candidates: Array = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("squad")
	var closest: Node3D = null
	var closest_dist: float = INF
	for c in candidates:
		if not is_instance_valid(c):
			continue
		var d: float = global_position.distance_to(c.global_position)
		if d < closest_dist:
			closest = c
			closest_dist = d
	_target = closest

func _chase(delta: float) -> void:
	var dir: Vector3 = (_target.global_position - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	velocity = dir * _speed
	move_and_slide()

	if _anim and _anim.current_animation != "Running":
		_anim.play("Running")

func _attack(delta: float) -> void:
	velocity = Vector3.ZERO
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		if _anim:
			_anim.play("Attack")
		if _target and _target.has_method("take_damage"):
			_target.take_damage(_attack_damage)

func take_damage(amount: float) -> void:
	if _current_health <= 0.0:
		return

	_current_health = max(_current_health - amount, 0.0)
	damaged.emit(_current_health, _max_health)

	if _anim:
		_anim.play("HitReaction")

	if _current_health <= 0.0:
		_die()

func _die() -> void:
	if _anim:
		_anim.play("Death")
	died.emit(self)
	# TODO: spawn death effect, award coins/XP via GameManager
	# Defer removal to let the death animation play.
	await get_tree().create_timer(1.5).timeout
	queue_free()

func get_health_fraction() -> float:
	return _current_health / _max_health
