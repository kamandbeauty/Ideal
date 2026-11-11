class_name BulletPool
extends Node3D
## Machine-gun rounds as flat arrays, swept with one ray per tick each. No
## nodes are created while firing and a single MultiMesh draws every tracer.

const CAPACITY: int = 96
const TRACER_LENGTH: float = 6.5
const TRACER_WIDTH: float = 0.05

var alive := PackedByteArray()
var positions := PackedVector3Array()
var velocities := PackedVector3Array()
var damages := PackedFloat32Array()
var headshot_scales := PackedFloat32Array()
var travelled := PackedFloat32Array()
var ranges := PackedFloat32Array()
var pierce := PackedInt32Array()
var pierce_scales := PackedFloat32Array()
var tracers := PackedByteArray()
var excludes: Array = []
var active_count: int = 0
var cursor: int = 0
var launched: int = 0
var hits: int = 0
var effects: EffectPool
var multimesh: MultiMesh
var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -1000.0, 0.0))
var query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	alive.resize(CAPACITY)
	positions.resize(CAPACITY)
	velocities.resize(CAPACITY)
	damages.resize(CAPACITY)
	headshot_scales.resize(CAPACITY)
	travelled.resize(CAPACITY)
	ranges.resize(CAPACITY)
	pierce.resize(CAPACITY)
	pierce_scales.resize(CAPACITY)
	tracers.resize(CAPACITY)
	excludes.resize(CAPACITY)
	for index: int in CAPACITY:
		excludes[index] = []
	query.collision_mask = Layers.BULLET_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = false
	_build_tracers()


func _build_tracers() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TRACER_WIDTH, TRACER_WIDTH, 1.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.78, 0.36)
	material.disable_receive_shadows = true
	material.disable_fog = true
	mesh.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = CAPACITY
	for index: int in CAPACITY:
		multimesh.set_instance_transform(index, hidden)
	var instance := MultiMeshInstance3D.new()
	instance.name = "Tracers"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Rounds cross the whole street within a few frames; never cull the batch.
	instance.custom_aabb = AABB(Vector3(-400, -20, -400), Vector3(800, 200, 800))
	add_child(instance)


## Returns the slot used, or -1 when every round is still in flight.
func fire(origin: Vector3, velocity: Vector3, damage: float, max_range: float, tracer: bool = true, penetration: int = 0,
		penetration_scale: float = 0.5, headshot_scale: float = 2.0) -> int:
	if active_count >= CAPACITY:
		return -1
	var slot: int = cursor
	while alive[slot] != 0:
		slot = (slot + 1) % CAPACITY
	cursor = (slot + 1) % CAPACITY
	alive[slot] = 1
	positions[slot] = origin
	velocities[slot] = velocity
	damages[slot] = damage
	headshot_scales[slot] = headshot_scale
	travelled[slot] = 0.0
	ranges[slot] = max_range
	pierce[slot] = penetration
	pierce_scales[slot] = penetration_scale
	tracers[slot] = 1 if tracer else 0
	excludes[slot].clear()
	active_count += 1
	launched += 1
	return slot


func _retire(slot: int) -> void:
	if alive[slot] == 0:
		return
	alive[slot] = 0
	active_count -= 1
	multimesh.set_instance_transform(slot, hidden)


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
		var from: Vector3 = positions[slot]
		var velocity: Vector3 = velocities[slot]
		var to: Vector3 = from + velocity * delta
		var guard: int = 4
		while guard > 0:
			guard -= 1
			query.from = from
			query.to = to
			query.exclude = excludes[slot]
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty():
				break
			if _resolve(slot, hit, velocity):
				_retire(slot)
				break
			from = hit.position
		if alive[slot] == 0:
			continue
		positions[slot] = to
		travelled[slot] += velocity.length() * delta
		if travelled[slot] >= ranges[slot]:
			_retire(slot)
		elif tracers[slot] != 0:
			_place_tracer(slot, to, velocity)


## True when the round stops here.
func _resolve(slot: int, hit: Dictionary, velocity: Vector3) -> bool:
	var collider: Object = hit.collider
	var at: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	if collider != null and collider.has_meta("zombie"):
		var zombie: Zombie = collider.get_meta("zombie")
		var head: bool = collider.get_meta("head", false)
		if zombie == null or not zombie.alive:
			excludes[slot].append(hit.rid)
			return false
		hits += 1
		var amount: float = damages[slot] * (headshot_scales[slot] if head else 1.0)
		var lethal: bool = zombie.take_hit(amount, head, at, velocity.normalized())
		if effects:
			effects.burst("gore" if (head or lethal) else "blood", at, -velocity.normalized())
		Sound.play_at("headshot" if head else "impact_flesh", at, -6.0, randf_range(0.9, 1.12))
		Events.zombie_hit.emit(at, head, lethal)
		if pierce[slot] <= 0:
			return true
		pierce[slot] -= 1
		damages[slot] *= pierce_scales[slot]
		for rid: RID in zombie.hit_rids():
			excludes[slot].append(rid)
		return false
	var metal: bool = collider != null and collider.has_meta("metal")
	if effects:
		effects.burst("spark" if metal else "dust", at + normal * 0.03, normal)
	Sound.play_at("impact_metal" if metal else "impact", at, -10.0, randf_range(0.9, 1.15))
	return true


func _place_tracer(slot: int, head: Vector3, velocity: Vector3) -> void:
	var direction: Vector3 = velocity.normalized()
	var length: float = minf(TRACER_LENGTH, travelled[slot])
	if length < 0.3:
		multimesh.set_instance_transform(slot, hidden)
		return
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up: Vector3 = side.cross(direction)
	multimesh.set_instance_transform(slot, Transform3D(Basis(side, up, direction * length), head - direction * length * 0.5))
