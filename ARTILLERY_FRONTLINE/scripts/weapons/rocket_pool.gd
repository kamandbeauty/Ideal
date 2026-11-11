class_name RocketPool
extends Node3D
## Rockets in flight: a handful of pooled rounds, each swept with one ray per
## tick. Whatever a round meets, it detonates there; one that meets nothing
## bursts at the end of its range.

const CAPACITY: int = 4
const MODEL_PATH: String = "res://assets/models/weapons/rocket.glb"
## The round is drawn larger than life so it can be followed down the street.
const MODEL_SCALE: float = 1.5

var explosions: Explosions
var nodes: Array[Node3D] = []
var trails: Array[CPUParticles3D] = []
var alive := PackedByteArray()
var positions := PackedVector3Array()
var velocities := PackedVector3Array()
var travelled := PackedFloat32Array()
var payloads: Array[WeaponData] = []
var active_count: int = 0
var launched: int = 0
var detonated: int = 0
var cursor: int = 0
var query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	alive.resize(CAPACITY)
	positions.resize(CAPACITY)
	velocities.resize(CAPACITY)
	travelled.resize(CAPACITY)
	payloads.resize(CAPACITY)
	query.collision_mask = Layers.BULLET_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var model: PackedScene = load(MODEL_PATH)
	var smoke: StandardMaterial3D = _smoke_material()
	for index: int in CAPACITY:
		var round_node := Node3D.new()
		round_node.name = "Rocket%d" % index
		var body: Node3D = model.instantiate()
		body.scale = Vector3.ONE * MODEL_SCALE
		round_node.add_child(body)
		round_node.add_child(_flame())
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.6, 0.25)
		glow.light_energy = 1.6
		glow.omni_range = 7.0
		glow.shadow_enabled = false
		glow.position = Vector3(0.0, 0.0, 0.9)
		round_node.add_child(glow)
		round_node.visible = false
		add_child(round_node)
		nodes.append(round_node)
		var trail: CPUParticles3D = _trail(smoke)
		trail.name = "Trail%d" % index
		add_child(trail)
		trails.append(trail)


func _smoke_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = EffectPool.soft_dot()
	material.disable_receive_shadows = true
	return material


func _flame() -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.albedo_texture = EffectPool.soft_dot()
	material.albedo_color = Color(1.0, 0.72, 0.34, 1.0)
	material.disable_fog = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	quad.material = material
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	flame.mesh = quad
	flame.position = Vector3(0.0, 0.0, 0.95)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return flame


func _trail(material: StandardMaterial3D) -> CPUParticles3D:
	var mesh := QuadMesh.new()
	mesh.material = material
	var fade := Gradient.new()
	fade.set_color(0, Color(0.9, 0.86, 0.8, 0.7))
	fade.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.35))
	growth.add_point(Vector2(1.0, 1.0))
	var trail := CPUParticles3D.new()
	trail.mesh = mesh
	trail.emitting = false
	trail.amount = 56
	trail.lifetime = 1.0
	trail.local_coords = false
	trail.direction = Vector3.UP
	trail.spread = 180.0
	trail.gravity = Vector3(0.0, 0.4, 0.0)
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.7
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.0
	trail.scale_amount_curve = growth
	trail.color_ramp = fade
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return trail


## Sends a round on its way. Returns the slot used, or -1 when every round is in flight.
func launch(origin: Vector3, direction: Vector3, data: WeaponData) -> int:
	if active_count >= CAPACITY:
		return -1
	var slot: int = cursor
	while alive[slot] != 0:
		slot = (slot + 1) % CAPACITY
	cursor = (slot + 1) % CAPACITY
	alive[slot] = 1
	positions[slot] = origin
	velocities[slot] = direction.normalized() * data.muzzle_velocity
	travelled[slot] = 0.0
	payloads[slot] = data
	active_count += 1
	launched += 1
	_place(slot)
	nodes[slot].visible = true
	trails[slot].global_position = origin
	trails[slot].restart()
	trails[slot].emitting = true
	return slot


func _place(slot: int) -> void:
	var node: Node3D = nodes[slot]
	var direction: Vector3 = velocities[slot].normalized()
	var up := Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT
	node.global_transform = Transform3D(Basis.looking_at(direction, up), positions[slot])
	trails[slot].global_position = positions[slot] - direction * 0.9


func _retire(slot: int) -> void:
	if alive[slot] == 0:
		return
	alive[slot] = 0
	active_count -= 1
	nodes[slot].visible = false
	trails[slot].emitting = false


func clear() -> void:
	for slot: int in CAPACITY:
		_retire(slot)


func _physics_process(delta: float) -> void:
	if active_count == 0:
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for slot: int in CAPACITY:
		if alive[slot] == 0:
			continue
		var data: WeaponData = payloads[slot]
		var from: Vector3 = positions[slot]
		var velocity: Vector3 = velocities[slot]
		var step: float = minf(velocity.length() * delta, data.max_range - travelled[slot])
		var to: Vector3 = from + velocity.normalized() * step
		query.from = from
		query.to = to
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			var struck: Zombie = null
			var collider: Object = hit.collider
			if collider != null and collider.has_meta("zombie"):
				struck = collider.get_meta("zombie")
			# Burst just clear of the surface, so the blast is not buried in the wall it struck.
			_detonate(slot, (hit.position as Vector3) + (hit.normal as Vector3) * 0.15, struck)
			continue
		positions[slot] = to
		travelled[slot] += step
		if travelled[slot] >= data.max_range - 0.001:
			_detonate(slot, to, null)
		else:
			_place(slot)


func _detonate(slot: int, at: Vector3, struck: Zombie) -> void:
	var data: WeaponData = payloads[slot]
	_retire(slot)
	detonated += 1
	if explosions != null and data.explosion != null:
		explosions.detonate(at, data.explosion, struck, data.damage)
