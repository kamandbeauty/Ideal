class_name EnemyAircraft
extends CharacterBody3D
## Attack helicopter / fighter pass: a moving, shootable aerial threat.
signal died(aircraft: EnemyAircraft)
signal damaged(aircraft: EnemyAircraft, ratio: float)
signal shoot_requested(origin: Vector3, target: Vector3, damage: float, blast: float)

var kind: String = "helicopter"
var health: float = 320.0
var max_health: float = 320.0
var objective: Vector3 = Vector3.ZERO
var model_root: Node3D
var rotor: Node3D
var collision: CollisionShape3D
var dead: bool = false
var clock: float = 0.0
var orbit_radius: float = 105.0
var altitude: float = 30.0
var angular_speed: float = 0.16
var phase: float = 0.0
var shoot_cooldown: float = 3.0
var crash_velocity: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("damageable")
	collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 3.4 if kind == "helicopter" else 4.2
	collision.shape = shape
	add_child(collision)
	_build_model()

func configure(target: Vector3, aircraft_kind: String = "helicopter", start_phase: float = 0.0) -> void:
	kind = aircraft_kind
	objective = target
	phase = start_phase
	if kind == "fighter":
		health = 240.0
		orbit_radius = 150.0
		altitude = 58.0
		angular_speed = 0.28
	else:
		health = 320.0
		orbit_radius = 95.0
		altitude = 30.0
		angular_speed = 0.14
	max_health = health
	shoot_cooldown = randf_range(2.0, 4.0)
	_update_position(0.0)

func _build_model() -> void:
	var path: String = "res://assets/models/helicopter.glb" if kind == "helicopter" else "res://assets/models/fighter.glb"
	if ResourceLoader.exists(path):
		model_root = load(path).instantiate()
		add_child(model_root)
		MaterialLibrary.apply_to_model(model_root)
		rotor = model_root.find_child("Rotor", true, false) as Node3D
	if model_root == null:
		model_root = Node3D.new()
		add_child(model_root)
		if kind == "helicopter":
			MeshFactory.sphere(model_root, "Fuselage", Vector3.ZERO, Vector3(1.3, 1.1, 3.0), Color(0.28, 0.32, 0.26), "paint_olive")
			MeshFactory.box(model_root, "Tail", Vector3(0, 0.3, 4.0), Vector3(0.3, 0.3, 4.5), Color(0.28, 0.32, 0.26), true, "paint_olive")
			rotor = Node3D.new()
			rotor.position.y = 1.2
			model_root.add_child(rotor)
			MeshFactory.box(rotor, "BladeA", Vector3.ZERO, Vector3(8.5, 0.05, 0.25), Color(0.1, 0.11, 0.1), false, "steel")
			MeshFactory.box(rotor, "BladeB", Vector3.ZERO, Vector3(0.25, 0.05, 8.5), Color(0.1, 0.11, 0.1), false, "steel")
		else:
			MeshFactory.sphere(model_root, "Fuselage", Vector3.ZERO, Vector3(0.9, 0.8, 4.5), Color(0.4, 0.43, 0.4), "paint_sand")
			MeshFactory.box(model_root, "Wing", Vector3(0, 0, 0.4), Vector3(9.0, 0.12, 1.8), Color(0.4, 0.43, 0.4), true, "paint_sand")
			MeshFactory.box(model_root, "Tail", Vector3(0, 0.8, 4.0), Vector3(0.12, 1.6, 1.2), Color(0.4, 0.43, 0.4), true, "paint_sand")

func is_dead() -> bool:
	return dead

func receive_damage(amount: float) -> void:
	if dead:
		return
	health = maxf(0.0, health - amount)
	damaged.emit(self, health / max_health)
	if health <= 0.0:
		_die()

func react_to_explosion(point: Vector3, radius: float) -> void:
	if dead:
		return
	var distance: float = global_position.distance_to(point)
	if distance < radius * 1.5:
		receive_damage(140.0 * (1.0 - distance / (radius * 1.5)))

func _die() -> void:
	dead = true
	collision_layer = 0
	collision.set_deferred("disabled", true)
	crash_velocity = -6.0
	died.emit(self)

func _update_position(delta: float) -> void:
	clock += delta
	var angle: float = phase + clock * angular_speed
	var point := Vector3(objective.x + cos(angle) * orbit_radius, altitude + sin(clock * 0.7) * 2.0, objective.z + sin(angle) * orbit_radius * 0.7 - 20.0)
	var forward: Vector3 = point - global_position
	global_position = point
	if forward.length_squared() > 0.001:
		rotation.y = atan2(forward.x, forward.z)
		rotation.z = sin(angle) * 0.18

func _physics_process(delta: float) -> void:
	if dead:
		crash_velocity -= 18.0 * delta
		global_position.y += crash_velocity * delta
		rotation.x += delta * 1.4
		if global_position.y < CoastalTerrain.height_at(global_position.x, global_position.z) + 0.5:
			queue_free()
		return
	_update_position(delta)
	if rotor:
		rotor.rotation.y += delta * 24.0
	shoot_cooldown -= delta
	if shoot_cooldown <= 0.0:
		shoot_cooldown = 3.2 if kind == "helicopter" else 5.0
		shoot_requested.emit(global_position, objective, 55.0 if kind == "helicopter" else 90.0, 3.0 if kind == "helicopter" else 4.0)
