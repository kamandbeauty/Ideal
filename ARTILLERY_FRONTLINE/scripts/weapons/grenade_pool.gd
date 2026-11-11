class_name GrenadePool
extends Node3D
## Thrown grenades: a ballistic flight swept with one ray per tick, a bounce
## off whatever they meet, and a fuze that starts burning on the first
## touch-down. A few pooled bodies; nothing is created by a throw.

const CAPACITY: int = 4
const MODEL_PATH: String = "res://assets/models/weapons/frag_grenade.glb"
## Drawn larger than life so the arc can be followed from the wall.
const MODEL_SCALE: float = 2.2
const REST_SPEED: float = 0.7
## A grenade touches nothing for this long after it leaves the hand, so the
## parapet in front of the gunner can never catch it.
const ARM_TIME: float = 0.15

var explosions: Explosions
var nodes: Array[Node3D] = []
var trails: Array[CPUParticles3D] = []
var alive := PackedByteArray()
var landed := PackedByteArray()
var resting := PackedByteArray()
var positions := PackedVector3Array()
var velocities := PackedVector3Array()
var fuses := PackedFloat32Array()
var lives := PackedFloat32Array()
var spins := PackedVector3Array()
var payloads: Array[GrenadeData] = []
var active_count: int = 0
var thrown: int = 0
var detonated: int = 0
var bounces: int = 0
var cursor: int = 0
## Where the last grenade went off; tests read it instead of watching.
var last_burst := Vector3.ZERO
var query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	alive.resize(CAPACITY)
	landed.resize(CAPACITY)
	resting.resize(CAPACITY)
	positions.resize(CAPACITY)
	velocities.resize(CAPACITY)
	fuses.resize(CAPACITY)
	lives.resize(CAPACITY)
	spins.resize(CAPACITY)
	payloads.resize(CAPACITY)
	query.collision_mask = Layers.GRENADE_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var model: PackedScene = load(MODEL_PATH)
	var smoke := StandardMaterial3D.new()
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke.billboard_keep_scale = true
	smoke.vertex_color_use_as_albedo = true
	smoke.albedo_texture = EffectPool.soft_dot()
	smoke.disable_receive_shadows = true
	for index: int in CAPACITY:
		var body: Node3D = model.instantiate()
		body.name = "Grenade%d" % index
		body.scale = Vector3.ONE * MODEL_SCALE
		body.visible = false
		add_child(body)
		nodes.append(body)
		var trail: CPUParticles3D = _trail(smoke)
		trail.name = "Trail%d" % index
		add_child(trail)
		trails.append(trail)


func _trail(material: StandardMaterial3D) -> CPUParticles3D:
	var mesh := QuadMesh.new()
	mesh.material = material
	var fade := Gradient.new()
	fade.set_color(0, Color(0.92, 0.9, 0.86, 0.5))
	fade.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
	var trail := CPUParticles3D.new()
	trail.mesh = mesh
	trail.emitting = false
	trail.amount = 18
	trail.lifetime = 0.55
	trail.local_coords = false
	trail.spread = 180.0
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.2
	trail.scale_amount_min = 0.1
	trail.scale_amount_max = 0.18
	trail.color_ramp = fade
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return trail


## Throws one grenade. Returns the slot used, or -1 when every body is in the air.
func throw_from(origin: Vector3, velocity: Vector3, data: GrenadeData) -> int:
	if active_count >= CAPACITY:
		return -1
	var slot: int = cursor
	while alive[slot] != 0:
		slot = (slot + 1) % CAPACITY
	cursor = (slot + 1) % CAPACITY
	alive[slot] = 1
	landed[slot] = 0
	resting[slot] = 0
	positions[slot] = origin
	velocities[slot] = velocity
	fuses[slot] = data.fuse_after_landing
	lives[slot] = 0.0
	spins[slot] = Vector3(randf_range(6.0, 11.0), randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
	payloads[slot] = data
	active_count += 1
	thrown += 1
	nodes[slot].position = origin
	nodes[slot].visible = true
	trails[slot].global_position = origin
	trails[slot].restart()
	trails[slot].emitting = true
	return slot


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
		var data: GrenadeData = payloads[slot]
		lives[slot] += delta
		if landed[slot] != 0:
			fuses[slot] -= delta
		if (landed[slot] != 0 and fuses[slot] <= 0.0) or lives[slot] >= data.max_life:
			_detonate(slot)
			continue
		if resting[slot] != 0:
			continue
		var velocity: Vector3 = velocities[slot] + Vector3(0.0, -data.gravity * delta, 0.0)
		var from: Vector3 = positions[slot]
		var to: Vector3 = from + velocity * delta
		query.from = from
		query.to = to
		var hit: Dictionary = space.intersect_ray(query) if lives[slot] >= ARM_TIME else {}
		if hit.is_empty():
			positions[slot] = to
		else:
			var normal: Vector3 = hit.normal
			positions[slot] = (hit.position as Vector3) + normal * 0.06
			velocity = Ballistics.rebound(velocity, normal, data.bounce, data.roll)
			bounces += 1
			if landed[slot] == 0:
				landed[slot] = 1
			Sound.play_at("grenade_bounce", positions[slot], -6.0, randf_range(0.9, 1.15))
			if velocity.length() < REST_SPEED and normal.y > 0.6:
				velocity = Vector3.ZERO
				resting[slot] = 1
		velocities[slot] = velocity
		var node: Node3D = nodes[slot]
		node.position = positions[slot]
		if resting[slot] == 0:
			node.rotation += spins[slot] * delta
		trails[slot].global_position = positions[slot]


func _detonate(slot: int) -> void:
	var data: GrenadeData = payloads[slot]
	var at: Vector3 = positions[slot] + Vector3(0.0, 0.1, 0.0)
	_retire(slot)
	detonated += 1
	last_burst = at
	if explosions != null and data.explosion != null:
		explosions.detonate(at, data.explosion)
