class_name Pedestrians
extends Node3D
## A handful of low-poly travellers walking the sidewalks. They are decorative,
## but they are what makes the stop feel occupied between cars.

const COUNT := 10
const SIDEWALK_X: Array[float] = [-1.5, 1.5]
const LIMIT := 17.0
const WALK_SPEED_MIN := 0.5
const WALK_SPEED_MAX := 1.05

const SHIRTS: Array[Color] = [
	Color(0.85, 0.32, 0.28), Color(0.25, 0.45, 0.8), Color(0.95, 0.78, 0.3),
	Color(0.4, 0.7, 0.5), Color(0.75, 0.5, 0.8), Color(0.9, 0.9, 0.9),
]
const SKIN: Array[Color] = [
	Color(0.96, 0.8, 0.66), Color(0.84, 0.65, 0.5), Color(0.62, 0.45, 0.32),
]

var agents: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 901
	for i in COUNT:
		_spawn(i)


func _spawn(index: int) -> void:
	var agent := Node3D.new()
	agent.name = "Walker%d" % index
	var lane := index % SIDEWALK_X.size()
	var direction := 1.0 if lane == 0 else -1.0
	agent.position = Vector3(
		SIDEWALK_X[lane] + _rng.randf_range(-0.2, 0.2),
		0.0,
		_rng.randf_range(-LIMIT, LIMIT)
	)
	if direction < 0.0:
		agent.rotation_degrees.y = 180.0

	var shirt: Color = SHIRTS[index % SHIRTS.size()]
	var skin: Color = SKIN[index % SKIN.size()]

	var legs := Node3D.new()
	legs.position.y = 0.32
	agent.add_child(legs)
	var leg_pivots: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position.x = 0.07 * side
		legs.add_child(pivot)
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.1, 0.3, 0.12)
		leg.mesh = leg_mesh
		leg.material_override = _flat(Color(0.24, 0.26, 0.32))
		leg.position.y = -0.15
		pivot.add_child(leg)
		leg_pivots.append(pivot)

	var body := MeshInstance3D.new()
	var torso := CapsuleMesh.new()
	torso.radius = 0.15
	torso.height = 0.5
	body.mesh = torso
	body.material_override = _flat(shirt)
	body.position.y = 0.62
	agent.add_child(body)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.24
	head.mesh = sphere
	head.material_override = _flat(skin)
	head.position.y = 0.98
	agent.add_child(head)

	add_child(agent)
	agents.append({
		"node": agent,
		"legs": leg_pivots,
		"direction": direction,
		"speed": _rng.randf_range(WALK_SPEED_MIN, WALK_SPEED_MAX),
		"phase": _rng.randf_range(0.0, TAU),
	})


func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _process(delta: float) -> void:
	for entry in agents:
		var agent: Node3D = entry["node"]
		var direction := float(entry["direction"])
		var speed := float(entry["speed"])
		var phase := float(entry["phase"]) + Time.get_ticks_msec() * 0.006
		agent.position.z += direction * speed * delta
		if agent.position.z > LIMIT:
			agent.position.z = -LIMIT
		elif agent.position.z < -LIMIT:
			agent.position.z = LIMIT
		agent.position.y = absf(sin(phase)) * 0.03
		for i in entry["legs"].size():
			var pivot: Node3D = entry["legs"][i]
			pivot.rotation.x = sin(phase + PI * float(i)) * 0.5
