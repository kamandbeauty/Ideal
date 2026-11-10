class_name EnemyVehicle
extends CharacterBody3D
## Destructible armored threat with rolling road wheels, tracked suspension,
## independently aiming turret, recoiling gun, muzzle flash and persistent wreck.
signal died(vehicle: EnemyVehicle)
signal damaged(vehicle: EnemyVehicle, ratio: float)
signal shoot_requested(origin: Vector3, target: Vector3, damage: float, blast: float)

var kind: String = "tank"
## Armour is light enough that two cannon hits (or two rockets) stop a tank and
## one cannon hit stops a transport.
const TANK_HEALTH: float = 260.0
const TRANSPORT_HEALTH: float = 120.0
const WADE_FLOOR: float = -0.35
var health: float = TANK_HEALTH
var max_health: float = TANK_HEALTH
var speed: float = 3.2
var objective: Vector3 = Vector3.ZERO
var model_root: Node3D
var turret: Node3D
var barrel_pivot: Node3D
var recoil_node: Node3D
var recoil_rest: Vector3 = Vector3.ZERO
var muzzle: Node3D
var wheels: Array[Node3D] = []
var collision: CollisionShape3D
var dead: bool = false
var shoot_cooldown: float = 3.0
var clock: float = 0.0
var stop_distance: float = 46.0
## Tanks close half the distance from their spawn to the emplacement, then hold
## that line and fire instead of parking at the beach or driving into the gun.
const ADVANCE_FRACTION: float = 0.5
const MIN_HOLD_DISTANCE: float = 16.0
var advance_origin: Vector3 = Vector3.ZERO
var advance_span: float = 0.0
var holding: bool = false
var recoil_offset: float = 0.0
var recoil_velocity: float = 0.0
var muzzle_flash: MeshInstance3D
var muzzle_light: OmniLight3D
var flash_timer: float = 0.0
var suspension_phase: float = 0.0
var turret_rest_y: float = 0.0

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
	var changed: bool = vehicle_kind != kind or model_root == null
	kind = vehicle_kind
	objective = target
	global_position = spawn
	if changed and is_inside_tree():
		if model_root:
			model_root.queue_free()
		model_root = null
		wheels.clear()
		turret = null
		barrel_pivot = null
		recoil_node = null
		muzzle = null
		var shape := BoxShape3D.new()
		shape.size = Vector3(3.4, 2.6, 6.2) if kind == "tank" else Vector3(3.0, 2.6, 6.8)
		collision.shape = shape
		_build_model()
	advance_origin = spawn
	var flat_spawn := Vector3(spawn.x, 0.0, spawn.z)
	var flat_target := Vector3(target.x, 0.0, target.z)
	advance_span = flat_spawn.distance_to(flat_target)
	if kind == "tank":
		health = TANK_HEALTH
		speed = 3.0
		stop_distance = maxf(MIN_HOLD_DISTANCE, advance_span * ADVANCE_FRACTION)
	else:
		health = TRANSPORT_HEALTH
		speed = 5.0
		stop_distance = 28.0
	holding = false
	max_health = health
	shoot_cooldown = randf_range(2.5, 4.5)
	suspension_phase = randf() * TAU

func _build_model() -> void:
	var path: String = "res://assets/models/warden.glb" if kind == "tank" else "res://assets/models/nomad.glb"
	if ResourceLoader.exists(path):
		model_root = load(path).instantiate()
		model_root.rotation.y = PI
		model_root.scale = Vector3.ONE * (0.72 if kind == "tank" else 0.62)
		add_child(model_root)
		MaterialLibrary.apply_to_model(model_root)
		turret = model_root.find_child("Turret", true, false) as Node3D
		if turret:
			turret_rest_y = turret.position.y
		barrel_pivot = model_root.find_child("BarrelPivot", true, false) as Node3D
		recoil_node = model_root.find_child("RecoilAssembly", true, false) as Node3D
		if recoil_node:
			recoil_rest = recoil_node.position
		muzzle = model_root.find_child("Muzzle", true, false) as Node3D
		for child in model_root.find_children("Wheel*", "Node3D", true, false):
			wheels.append(child as Node3D)
		_build_muzzle_flash()
	if model_root == null:
		model_root = Node3D.new()
		model_root.rotation.y = PI
		add_child(model_root)
		MeshFactory.box(model_root, "Hull", Vector3(0, 1.1, 0), Vector3(3.2, 1.6, 6.0), Color(0.3, 0.34, 0.24), true, "paint_olive")
		turret = Node3D.new()
		turret.name = "Turret"
		turret.position = Vector3(0, 2.2, -0.4)
		model_root.add_child(turret)
		MeshFactory.box(turret, "TurretBody", Vector3.ZERO, Vector3(2.0, 0.9, 2.4), Color(0.28, 0.32, 0.22), true, "paint_olive")
		MeshFactory.cylinder(turret, "Gun", Vector3(0, 0, -2.6), 0.12, 3.4, Color(0.2, 0.22, 0.18), 16, "steel").rotation.x = PI * 0.5
		turret_rest_y = turret.position.y

func _build_muzzle_flash() -> void:
	if muzzle == null:
		return
	muzzle_flash = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6) if kind == "tank" else Vector2(0.7, 0.7)
	muzzle_flash.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.78, 0.35, 0.95)
	var texture: Texture2D = MaterialLibrary.texture("muzzle_flash.png")
	if texture:
		material.albedo_texture = texture
	muzzle_flash.material_override = material
	muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_flash.visible = false
	muzzle.add_child(muzzle_flash)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.62, 0.25)
	muzzle_light.omni_range = 9.0
	muzzle_light.light_energy = 0.0
	muzzle.add_child(muzzle_light)

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
	if muzzle_flash:
		muzzle_flash.visible = false
	if muzzle_light:
		muzzle_light.light_energy = 0.0
	# Persistent wreck: suspension settles, turret droops; no sinking tween.
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(model_root, "rotation:z", randf_range(-0.06, 0.06), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(model_root, "position:y", -0.08, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if barrel_pivot:
		tween.tween_property(barrel_pivot, "rotation:x", 0.12, 1.2)
	if turret:
		tween.tween_property(turret, "rotation:z", randf_range(-0.05, 0.05), 1.2)
	died.emit(self)

func muzzle_position() -> Vector3:
	if muzzle:
		return muzzle.global_position
	return global_position + Vector3.UP * 2.2 - global_transform.basis.z * 3.0

func _fire() -> void:
	recoil_velocity += 7.0 if kind == "tank" else 3.5
	flash_timer = 0.07 if kind == "tank" else 0.045
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash.rotation.z = randf_range(0.0, TAU)
		muzzle_flash.scale = Vector3.ONE * randf_range(0.85, 1.25)
	if muzzle_light:
		muzzle_light.light_energy = 4.0 if kind == "tank" else 2.0
	shoot_requested.emit(muzzle_position(), objective, 150.0 if kind == "tank" else 22.0, 5.0 if kind == "tank" else 0.0)

func _physics_process(delta: float) -> void:
	if dead:
		return
	clock += delta
	shoot_cooldown -= delta
	var offset: Vector3 = objective - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	var moving: bool = distance > stop_distance
	holding = not moving
	var current_speed: float = speed if moving else 0.0
	if moving:
		var direction: Vector3 = offset.normalized()
		# Clamp the last step so even a slow physics frame cannot overshoot the
		# half-way hold line and oscillate around it.
		global_position += direction * minf(speed * delta, distance - stop_distance)
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 2.0)
	# Hulls follow the beach and wade out of the surf; they drop from a landing
	# craft's ramp rather than teleporting to the sand.
	var ground: float = maxf(CoastalTerrain.height_at(global_position.x, global_position.z), WADE_FLOOR)
	global_position.y = move_toward(global_position.y, ground, 2.2 * delta)
	_roll_wheels(delta, current_speed)
	_suspension(delta, current_speed)
	_aim_turret(delta)
	_tick_recoil(delta)
	if shoot_cooldown <= 0.0 and distance < 170.0:
		shoot_cooldown = 4.6 if kind == "tank" else 2.6
		_fire()

func _roll_wheels(delta: float, current_speed: float) -> void:
	if current_speed <= 0.0:
		return
	var radius: float = 0.55 if kind == "tank" else 0.45
	var angular: float = current_speed / radius
	for wheel in wheels:
		wheel.rotate_object_local(Vector3.RIGHT, angular * delta)

func _suspension(delta: float, current_speed: float) -> void:
	suspension_phase += delta * (2.0 + current_speed * 1.5)
	var amplitude: float = 0.015 * clampf(current_speed / maxf(speed, 0.1), 0.0, 1.0)
	if turret:
		turret.position.y = turret_rest_y + sin(suspension_phase) * amplitude
	if model_root:
		model_root.rotation.x = sin(suspension_phase * 0.7) * amplitude * 0.35

func _aim_turret(delta: float) -> void:
	if turret == null:
		return
	var local_target: Vector3 = model_root.to_local(objective + Vector3.UP * 1.2)
	var desired: float = atan2(local_target.x, local_target.z)
	turret.rotation.y = lerp_angle(turret.rotation.y, desired, delta * 1.5)
	if barrel_pivot:
		var horizontal: float = Vector2(local_target.x, local_target.z).length()
		var pitch: float = clampf(atan2(local_target.y - barrel_pivot.position.y, horizontal), -0.12, 0.22)
		barrel_pivot.rotation.x = lerpf(barrel_pivot.rotation.x, -pitch, delta * 2.0)

func _tick_recoil(delta: float) -> void:
	recoil_velocity += (-recoil_offset * 140.0 - recoil_velocity * 16.0) * delta
	recoil_offset += recoil_velocity * delta
	if recoil_node:
		recoil_node.position = recoil_rest + Vector3(0, 0, -recoil_offset * 0.10)
	flash_timer = maxf(0.0, flash_timer - delta)
	if muzzle_flash and flash_timer <= 0.0:
		muzzle_flash.visible = false
	if muzzle_light:
		muzzle_light.light_energy = maxf(0.0, muzzle_light.light_energy - delta * 40.0)
