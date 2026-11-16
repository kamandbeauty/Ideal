class_name Pedestrians
extends Node3D
## Visitors stay on the frontage pavement, behind the vehicle stopping line.
## No random straight-line walking through a shop or across a live drive lane.

const COUNT := 8
var state: TownState
var count := COUNT
var agents: Array[Dictionary] = []
var _signature := ""
var _phase := 0.0


func _ready() -> void:
	_rebuild()


func set_count(value: int) -> void:
	count = clampi(value, 0, COUNT + 6)
	_signature = ""


func _rebuild() -> void:
	for entry in agents:
		(entry["node"] as Node3D).queue_free()
	agents.clear()
	if state == null:
		return
	var ids := state.unlocked_ids()
	_signature = str(ids) + str(count)
	for i in mini(count, ids.size() * 2):
		var id: String = ids[i % ids.size()]
		var plot := BusinessData.plot(id)
		var visitor := PersonMesh.build(i)
		var direction := 1.0 if i % 2 == 0 else -1.0
		visitor.position = Vector3(plot.x - direction * 0.9, 0.08, plot.y + 1.42)
		visitor.rotation.y = direction * PI * 0.5
		add_child(visitor)
		agents.append({"node": visitor, "origin": plot.x, "direction": direction, "speed": 0.42 + float(i % 3) * 0.09})


func _process(delta: float) -> void:
	if state == null:
		return
	if _signature != str(state.unlocked_ids()) + str(count):
		_rebuild()
	_phase += delta * 6.0
	for entry in agents:
		var visitor: Node3D = entry["node"]
		var direction := float(entry["direction"])
		var origin := float(entry["origin"])
		visitor.position.x = clampf(
			visitor.position.x + direction * float(entry["speed"]) * delta, origin - 1.22, origin + 1.22
		)
		if absf(visitor.position.x - origin) >= 1.21:
			entry["direction"] = -direction
			visitor.rotation.y = -direction * PI * 0.5
		PersonMesh.animate(visitor, _phase + origin, 0.7)
