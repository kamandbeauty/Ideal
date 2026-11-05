class_name EnemyTarget
extends CharacterBody3D
## Offline patrol / alert behavior and staged visual damage.
signal destroyed(target: EnemyTarget)
signal health_changed(target: EnemyTarget, ratio: float)
var data: EnemyData
var target_id: String = ""
var health := HealthComponent.new()
var route: PackedVector3Array = PackedVector3Array()
var route_index: int = 0
var alert: bool = false
var current_speed: float = 0.0
var move_velocity: Vector3 = Vector3.ZERO
var model: Node3D
var turret: Node3D
var wreck_smoke: GPUParticles3D
var damage_stage: int = 0
var required: bool = false
var clock: float = 0.0

func configure(resource: EnemyData, id: String, patrol: PackedVector3Array, is_required: bool) -> void:
	data = resource
	target_id = id
	route = patrol
	required = is_required
	collision_layer = 2
	collision_mask = 0
	health.maximum = data.health

func _ready() -> void:
	add_child(health)
	health.changed.connect(_on_health_changed)
	health.destroyed.connect(_on_destroyed)
	add_to_group("damageable")
	add_to_group("enemy")
	if ResourceLoader.exists(data.model_path):
		model = load(data.model_path).instantiate()
		add_child(model)
		turret = model.find_child("Turret", true, false) as Node3D
	else:
		model = Node3D.new()
		add_child(model)
		MeshFactory.box(model, "TargetHull", Vector3(0, data.collision_size.y * 0.5, 0), data.collision_size, Color(0.24, 0.28, 0.18))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = data.collision_size
	collision.shape = shape
	collision.position.y = data.collision_size.y * 0.5
	add_child(collision)
	_build_wreck_smoke()
	Events.shot_fired.connect(_on_battlefield_shot)
	if data.speed > 0.0 and route.size() > 1:
		var direction: Vector3 = route[1] - global_position
		rotation.y = atan2(-direction.x, -direction.z)

func _build_wreck_smoke() -> void:
	wreck_smoke = GPUParticles3D.new()
	wreck_smoke.amount = 10
	wreck_smoke.lifetime = 4.0
	wreck_smoke.local_coords = false
	wreck_smoke.position.y = data.collision_size.y * 0.7
	wreck_smoke.emitting = false
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 22.0
	process.initial_velocity_min = 1.5
	process.initial_velocity_max = 3.0
	process.gravity = Vector3(0, 1.0, 0)
	process.scale_min = 1.5
	process.scale_max = 3.5
	if ExplosionEffect.smoke_ramp:
		process.color_ramp = ExplosionEffect.smoke_ramp
	wreck_smoke.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	wreck_smoke.draw_pass_1 = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = ExplosionEffect.puff_texture
	wreck_smoke.material_override = material
	add_child(wreck_smoke)
	add_to_group("quality_listener")

func apply_quality(_tier: String, settings: Dictionary) -> void:
	wreck_smoke.amount = maxi(3, int(10 * float(settings.particles)))

func _on_battlefield_shot(origin: Vector3, _direction: Vector3) -> void:
	if not health.is_destroyed and origin.distance_to(global_position) < 750.0:
		alert = true

func _physics_process(delta: float) -> void:
	clock += delta
	if health.is_destroyed:
		move_velocity = Vector3.ZERO
		return
	if data.speed <= 0.0:
		if turret and alert:
			turret.rotation.y = sin(clock * 0.35) * 0.5
		return
	if route.size() < 2:
		return
	var destination: Vector3 = route[route_index]
	var offset: Vector3 = destination - global_position
	offset.y = 0.0
	if offset.length() < 2.0:
		route_index = (route_index + 1) % route.size()
		destination = route[route_index]
		offset = destination - global_position
		offset.y = 0.0
	current_speed = data.speed * (1.2 if alert else 1.0)
	move_velocity = offset.normalized() * current_speed
	var collision: KinematicCollision3D = move_and_collide(move_velocity * delta)
	if collision:
		route_index = (route_index + 1) % route.size()
		move_velocity = Vector3.ZERO
	var desired_yaw: float = atan2(-move_velocity.x, -move_velocity.z)
	if move_velocity.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, desired_yaw, minf(1.0, delta * 2.0))
	global_position.y = TerrainSampler.height_at(global_position.x, global_position.z) + 0.08

func predict_position(seconds: float) -> Vector3:
	# Fire-control lead follows the same patrol waypoints, including corners.
	# Every shot alerts nearby enemies, so use the alerted speed prospectively.
	if data.speed <= 0.0 or route.size() < 2:
		return damage_point()
	var position: Vector3 = global_position
	var index: int = route_index
	var remaining: float = maxf(0.0, seconds) * data.speed * 1.2
	for iteration in range(16):
		var offset: Vector3 = route[index] - position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= remaining:
			position = route[index]
			remaining -= distance
			index = (index + 1) % route.size()
		else:
			position += offset.normalized() * remaining
			break
	position.y = TerrainSampler.height_at(position.x, position.z) + data.collision_size.y * 0.45
	return position

func patrol_velocity() -> Vector3:
	return move_velocity

func damage_point() -> Vector3:
	return global_position + Vector3.UP * data.collision_size.y * 0.45

func armor_value() -> float:
	return data.armor

func receive_damage(amount: float, _point: Vector3, _direct: bool) -> float:
	return health.apply_damage(amount)

func _on_health_changed(current: float, maximum: float) -> void:
	var ratio: float = current / maximum
	health_changed.emit(self, ratio)
	if ratio < 0.55 and damage_stage == 0:
		damage_stage = 1
		if turret:
			turret.rotation.z = 0.08
		MeshFactory.box(self, "ScorchPlate", Vector3(0, data.collision_size.y * 0.7, -data.collision_size.z * 0.35), Vector3(1.6, 0.12, 1.8), Color(0.075, 0.065, 0.05))

func _on_destroyed() -> void:
	damage_stage = 2
	move_velocity = Vector3.ZERO
	collision_layer = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	if model:
		var tween: Tween = create_tween()
		tween.tween_property(model, "rotation:z", 0.10 if data.kind == "tank" else -0.07, 0.45)
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var instance: MeshInstance3D = child as MeshInstance3D
			var wreck_material := StandardMaterial3D.new()
			wreck_material.albedo_color = Color(0.095, 0.10, 0.083)
			wreck_material.roughness = 0.96
			wreck_material.metallic = 0.15
			instance.material_override = wreck_material
	wreck_smoke.restart()
	wreck_smoke.emitting = true
	destroyed.emit(self)
	Events.target_destroyed.emit(target_id, data.kind, global_position)
