class_name Pedestrians
extends Node3D
## Visitors strolling along the station forecourt walkways between facilities.

const COUNT := 8
const LANES_Z: Array[float] = [-3.6, 3.6]
const LIMIT_X := 7.2
const WALK_SPEED_MIN := 0.55
const WALK_SPEED_MAX := 1.05

var agents: Array[Dictionary] = []
var count := COUNT
var _rng := RandomNumberGenerator.new()
var _phase := 0.0


func _ready() -> void:
	_rng.seed = 901
	for i in count:
		_spawn(i)


func set_count(value: int) -> void:
	count = clampi(value, 0, COUNT + 6)
	for i in agents.size():
		(agents[i]["node"] as Node3D).visible = i < count


func _spawn(index: int) -> void:
	var lane := index % LANES_Z.size()
	var direction := 1.0 if index % 2 == 0 else -1.0
	var agent := PersonMesh.build(index)
	agent.name = "Visitor%d" % index
	agent.position = Vector3(
		_rng.randf_range(-LIMIT_X, LIMIT_X),
		0.03,
		LANES_Z[lane] + _rng.randf_range(-0.35, 0.35)
	)
	agent.rotation_degrees.y = 90.0 if direction > 0.0 else -90.0
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
		if not agent.visible:
			continue
		var direction := float(entry["direction"])
		var speed := float(entry["speed"])
		agent.position.x += direction * speed * delta
		if agent.position.x > LIMIT_X:
			agent.position.x = -LIMIT_X
		elif agent.position.x < -LIMIT_X:
			agent.position.x = LIMIT_X
		agent.position.y = 0.03 + absf(sin(_phase + float(entry["phase"]))) * 0.02
		PersonMesh.animate(agent, _phase + float(entry["phase"]), 1.0)
