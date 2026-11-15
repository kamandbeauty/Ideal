class_name Pedestrians
extends Node3D
## A handful of low-poly travellers walking the sidewalks. They are decorative,
## but they are what makes the stop feel occupied between cars.

const COUNT := 10
const SIDEWALK_X: Array[float] = [-1.5, 1.5]
const LIMIT := 17.0
const WALK_SPEED_MIN := 0.5
const WALK_SPEED_MAX := 1.05

var agents: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _phase := 0.0


func _ready() -> void:
	_rng.seed = 901
	for i in COUNT:
		_spawn(i)


func _spawn(index: int) -> void:
	var lane := index % SIDEWALK_X.size()
	var direction := 1.0 if lane == 0 else -1.0
	var agent := PersonMesh.build(index)
	agent.name = "Walker%d" % index
	agent.position = Vector3(
		SIDEWALK_X[lane] + _rng.randf_range(-0.2, 0.2),
		0.0,
		_rng.randf_range(-LIMIT, LIMIT)
	)
	agent.rotation_degrees.y = 0.0 if direction > 0.0 else 180.0
	add_child(agent)
	agents.append({
		"node": agent,
		"direction": direction,
		"speed": _rng.randf_range(WALK_SPEED_MIN, WALK_SPEED_MAX),
		"phase": _rng.randf_range(0.0, TAU),
	})


func _process(delta: float) -> void:
	_phase += delta * 7.0
	for entry in agents:
		var agent: Node3D = entry["node"]
		var direction := float(entry["direction"])
		var speed := float(entry["speed"])
		agent.position.z += direction * speed * delta
		if agent.position.z > LIMIT:
			agent.position.z = -LIMIT
		elif agent.position.z < -LIMIT:
			agent.position.z = LIMIT
		agent.position.y = absf(sin(_phase + float(entry["phase"]))) * 0.02
		PersonMesh.animate(agent, _phase + float(entry["phase"]), 1.0)
