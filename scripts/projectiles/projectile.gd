class_name ShellProjectile
extends Node3D

signal impacted(projectile: ShellProjectile, point: Vector3, collider: Object, ammo: AmmoConfig)
signal expired(projectile: ShellProjectile)

const MAX_LIFETIME: float = 9.0

var active: bool = false
var velocity: Vector3 = Vector3.ZERO
var gravity: float = 9.81
var drag: float = 0.0
var age: float = 0.0
var ammo: AmmoConfig


func _ready() -> void:
	var shell_mat := ShapeFactory.material(Color("d6b46a"), 0.65, 0.35)
	var shell := ShapeFactory.sphere(self, Vector3(0.45, 0.45, 0.9), Vector3.ZERO, shell_mat, 10)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	set_physics_process(false)


func launch(
	origin: Vector3,
	initial_velocity: Vector3,
	ammo_data: AmmoConfig,
	gravity_value: float,
	drag_value: float
) -> void:
	global_position = origin
	velocity = initial_velocity
	ammo = ammo_data
	gravity = gravity_value
	drag = drag_value
	age = 0.0
	active = true
	visible = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not active:
		return
	var previous := global_position
	var step := Ballistics.advance(previous, velocity, delta, gravity, drag)
	var next: Vector3 = step.position
	velocity = step.velocity
	var query := PhysicsRayQueryParameters3D.create(previous, next, Ballistics.WORLD_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		var point: Vector3 = hit.position
		var collider: Object = hit.collider
		var impact_ammo := ammo
		_deactivate()
		impacted.emit(self, point, collider, impact_ammo)
		return
	global_position = next
	if velocity.length_squared() > 0.1:
		look_at(global_position + velocity.normalized(), Vector3.UP)
	age += delta
	if age >= MAX_LIFETIME or global_position.y < -10.0:
		_deactivate()
		expired.emit(self)


func _deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)
