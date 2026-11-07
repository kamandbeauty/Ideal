class_name EnemyVehicle
extends CharacterBody3D
## Destructible armored threat that advances on the fixed emplacement and returns fire.
signal died(vehicle: EnemyVehicle)
signal damaged(vehicle: EnemyVehicle, ratio: float)
signal shoot_requested(origin: Vector3, target: Vector3, damage: float, blast: float)

var kind: String = "tank"
var health: float = 650.0
var max_health: float = 650.0
var speed: float = 3.2
var objective: Vector3 = Vector3.ZERO
var model_root: Node3D
var turret: Node3D
var collision: CollisionShape3D
var dead: bool = false
var shoot_cooldown: float = 3.0
var clock: float = 0.0
var stop_distance: float = 46.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("damageable")
	collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.4, 2.6, 6.2) if kind == "tank" else Vector3(3.0, 2.6, 6.8)
	collision.shape = shape
	collision.position.y = 1.3
	add_child(collision)
	_build_model()

func configure(spawn: Vector3, target: Vector3, vehicle_kind: String = "tank") -> void:
	kind = vehicle_kind
	objective = target
	global_position = spawn
	if kind == "tank":
		health = 650.0
		speed = 3.0
		stop_distance = 46.0
	else:
		health = 380.0
		speed = 5.0
		stop_distance = 28.0
	max_health = health
	shoot_cooldown = randf_range(2.5, 4.5)

func _build_model() -> void:
	var path: String = "res://assets/models/warden.glb" if kind == "tank" else "res://assets/models/nomad.glb"
	if ResourceLoader.exists(path):
		model_root = load(path).instantiate()
		model_root.rotation.y = PI
		model_root.scale = Vector3.ONE * (0.72 if kind == "tank" else 0.62)
		add_child(model_root)
		MaterialLibrary.apply_to_model(model_root)
		turret = model_root.find_child("Turret", true, false) as Node3D
	if model_root == null:
		model_root = Node3D.new()
		add_child(model_root)
		MeshFactory.box(model_root, "Hull", Vector3(0, 1.1, 0), Vector3(3.2, 1.6, 6.0), Color(0.3, 0.34, 0.24), true, "paint_olive")
		MeshFactory.box(model_root, "Turret", Vector3(0, 2.2, -0.4), Vector3(2.0, 0.9, 2.4), Color(0.28, 0.32, 0.22), true, "paint_olive")
		MeshFactory.cylinder(model_root, "Gun", Vector3(0, 2.2, -2.6), 0.12, 3.4, Color(0.2, 0.22, 0.18), 16, "steel").rotation.x = PI * 0.5

func is_dead() -> bool:
	return dead

func receive_damage(amount: float) -> void:
	if dead:
		return
	var armor: float = 0.22 if amount <= 25.0 else (0.65 if amount < 100.0 else 0.9)
	health = maxf(0.0, health - amount * armor)
	damaged.emit(self, health / max_health)
	if health <= 0.0:
		_die()

func react_to_explosion(point: Vector3, radius: float) -> void:
	if dead:
		return
	var distance: float = global_position.distance_to(point)
	if distance < radius * 1.7:
		receive_damage(190.0 * (1.0 - distance / (radius * 1.7)))

func _die() -> void:
	dead = true
	collision_layer = 0
	collision.set_deferred("disabled", true)
	set_physics_process(false)
	var tween: Tween = create_tween()
	tween.tween_property(model_root, "rotation:z", randf_range(-0.18, 0.18), 0.8)
	tween.parallel().tween_property(model_root, "position:y", -0.25, 0.8)
	died.emit(self)

func _physics_process(delta: float) -> void:
	if dead:
		return
	clock += delta
	shoot_cooldown -= delta
	var offset: Vector3 = objective - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance > stop_distance:
		var direction: Vector3 = offset.normalized()
		global_position += direction * speed * delta
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 2.0)
	global_position.y = CoastalTerrain.height_at(global_position.x, global_position.z)
	if turret:
		var local_target: Vector3 = to_local(objective + Vector3.UP * 1.2)
		turret.rotation.y = lerp_angle(turret.rotation.y, atan2(local_target.x, local_target.z), delta * 1.5)
	if shoot_cooldown <= 0.0 and distance < 170.0:
		shoot_cooldown = 4.6 if kind == "tank" else 2.6
		var origin: Vector3 = global_position + Vector3.UP * 2.2 - global_transform.basis.z * 3.0
		shoot_requested.emit(origin, objective, 150.0 if kind == "tank" else 22.0, 5.0 if kind == "tank" else 0.0)
