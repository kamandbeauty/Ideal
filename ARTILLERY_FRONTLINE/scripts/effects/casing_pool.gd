class_name CasingPool
extends MultiMeshInstance3D
## Spent brass from the machine gun: thrown clear of the gun, tumbling, and
## gone once it has dropped out of sight. The casings are one MultiMesh moved
## from flat arrays; firing creates no nodes and the pool sleeps when nothing
## is in the air.

const COUNT: int = 20
const LIFE: float = 0.6
const GRAVITY: float = 9.8
const LENGTH: float = 0.05
const RADIUS: float = 0.0075

var alive := PackedByteArray()
var positions := PackedVector3Array()
var velocities := PackedVector3Array()
var axes := PackedVector3Array()
var spins := PackedFloat32Array()
var angles := PackedFloat32Array()
var ages := PackedFloat32Array()
var cursor: int = 0
var flying: int = 0
var ejected: int = 0
var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -1000.0, 0.0))
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	# Casings live in the world, not on the gun that threw them.
	top_level = true
	transform = Transform3D.IDENTITY
	alive.resize(COUNT)
	positions.resize(COUNT)
	velocities.resize(COUNT)
	axes.resize(COUNT)
	spins.resize(COUNT)
	angles.resize(COUNT)
	ages.resize(COUNT)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.82, 0.63, 0.27)
	brass.metallic = 0.55
	brass.roughness = 0.32
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS * 0.8
	mesh.bottom_radius = RADIUS
	mesh.height = LENGTH
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.material = brass
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = COUNT
	for index: int in COUNT:
		multimesh.set_instance_transform(index, hidden)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-400, -20, -400), Vector3(800, 200, 800))
	set_process(false)


## Throws one casing from `at` with `velocity` (world space). The oldest one in the air gives up its place.
func eject(at: Vector3, velocity: Vector3) -> void:
	var slot: int = cursor
	cursor = (cursor + 1) % COUNT
	if alive[slot] == 0:
		flying += 1
	alive[slot] = 1
	positions[slot] = at
	velocities[slot] = velocity
	axes[slot] = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0)).normalized()
	spins[slot] = rng.randf_range(14.0, 34.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	angles[slot] = rng.randf() * TAU
	ages[slot] = 0.0
	ejected += 1
	set_process(true)


func _process(delta: float) -> void:
	for slot: int in COUNT:
		if alive[slot] == 0:
			continue
		ages[slot] += delta
		if ages[slot] >= LIFE:
			alive[slot] = 0
			flying -= 1
			multimesh.set_instance_transform(slot, hidden)
			continue
		var velocity: Vector3 = velocities[slot]
		velocity.y -= GRAVITY * delta
		velocities[slot] = velocity
		positions[slot] += velocity * delta
		angles[slot] += spins[slot] * delta
		multimesh.set_instance_transform(slot, Transform3D(Basis(axes[slot], angles[slot]), positions[slot]))
	if flying <= 0:
		set_process(false)


func clear() -> void:
	for slot: int in COUNT:
		alive[slot] = 0
		multimesh.set_instance_transform(slot, hidden)
	flying = 0
	set_process(false)
