class_name TownStaff
extends Node3D
## The people who work here: one staff member per opened business, standing at
## its door and working, plus a manager in a hi-vis vest patrolling the plot
## once one has been hired.
##
## Hiring a manager is therefore something you can see, not just a number in the
## detail panel - the same person is the one who spends the takings for you.

const WORK_SPOT := Vector3(1.2, 0.0, 1.65)
const MANAGER_SPOT := Vector3(1.95, 0.0, 1.9)
const PATROL := 0.75
const MANAGER_SPEED := 0.42

var state
var _crew: Dictionary = {}
var _phase := 0.0


func setup(town_state) -> void:
	state = town_state
	refresh()


func refresh() -> void:
	if state == null:
		return
	for id in _crew.keys():
		(_crew[id]["root"] as Node3D).queue_free()
	_crew.clear()
	for id in state.business_ids():
		var business = state.business(id)
		if business == null or not business.unlocked:
			continue
		_build(id, business)


func refresh_business(id: String) -> void:
	if state == null:
		return
	if _crew.has(id):
		(_crew[id]["root"] as Node3D).queue_free()
		_crew.erase(id)
	var business = state.business(id)
	if business == null or not business.unlocked:
		return
	_build(id, business)


func _build(id: String, business) -> void:
	var plot := BusinessData.plot(id)
	var to_road := -signf(plot.x)
	if to_road == 0.0:
		to_road = -1.0
	var root := Node3D.new()
	root.name = "Crew_" + id
	add_child(root)

	var staff := PersonMesh.build(int(absf(float(hash(id))) % 5.0))
	staff.position = Vector3(
		plot.x + to_road * WORK_SPOT.x, 0.0, plot.y + WORK_SPOT.z
	)
	staff.rotation_degrees.y = 90.0 * to_road
	root.add_child(staff)

	var manager: Node3D = null
	if business.manager_rank > 0:
		manager = _build_manager(int(absf(float(hash(id + "m"))) % 5.0))
		manager.position = Vector3(
			plot.x + to_road * MANAGER_SPOT.x, 0.0, plot.y + MANAGER_SPOT.z
		)
		root.add_child(manager)

	_crew[id] = {
		"root": root,
		"staff": staff,
		"manager": manager,
		"to_road": to_road,
		"patrol_origin": plot.y + MANAGER_SPOT.z,
		"direction": 1.0,
	}


## Managers wear a hi-vis vest and a cap so they read as staff at a glance.
func _build_manager(crew: int) -> Node3D:
	var manager := PersonMesh.build(crew)
	var vest := MeshInstance3D.new()
	var vest_mesh := BoxMesh.new()
	vest_mesh.size = Vector3(0.3, 0.34, 0.24)
	vest.mesh = vest_mesh
	vest.position = Vector3(0, 0.72, 0)
	vest.material_override = PersonMesh.flat(Color(0.98, 0.78, 0.18))
	manager.add_child(vest)

	var cap := MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(0.24, 0.09, 0.26)
	cap.mesh = cap_mesh
	cap.position = Vector3(0, 1.14, 0.02)
	cap.material_override = PersonMesh.flat(Color(0.16, 0.2, 0.28))
	manager.add_child(cap)

	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.2, 0.26, 0.03)
	board.mesh = board_mesh
	board.position = Vector3(0.24, 0.62, 0.16)
	board.material_override = PersonMesh.flat(Color(0.86, 0.84, 0.78))
	manager.add_child(board)
	return manager


func _process(delta: float) -> void:
	if _crew.is_empty():
		return
	_phase += delta * 6.0
	for id in _crew.keys():
		var entry: Dictionary = _crew[id]
		_work(entry["staff"] as Node3D)
		var manager: Node3D = entry["manager"]
		if manager != null:
			_patrol(entry, manager, delta)


## A two-handed workshop beat: the arms lift and fall, the body leans in.
func _work(person: Node3D) -> void:
	if person == null:
		return
	PersonMesh.animate(person, _phase, 0.0)
	var arms: Array = person.get_meta("arms", [])
	for i in arms.size():
		var pivot: Node3D = arms[i]
		pivot.rotation.x = -1.05 + sin(_phase * 1.6 + PI * float(i)) * 0.55
	person.position.y = absf(sin(_phase * 0.9)) * 0.015


func _patrol(entry: Dictionary, manager: Node3D, delta: float) -> void:
	var origin := float(entry["patrol_origin"])
	var direction := float(entry["direction"])
	manager.position.z += direction * MANAGER_SPEED * delta
	if manager.position.z > origin + PATROL:
		manager.position.z = origin + PATROL
		entry["direction"] = -1.0
	elif manager.position.z < origin - PATROL:
		manager.position.z = origin - PATROL
		entry["direction"] = 1.0
	manager.rotation_degrees.y = 0.0 if float(entry["direction"]) > 0.0 else 180.0
	PersonMesh.animate(manager, _phase, 1.0)
