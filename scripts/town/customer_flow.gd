class_name CustomerFlow
extends Node3D
## The living part of the stop: vehicles drive in, park beside their business,
## a traveller gets out, waits in line, is served, pays and drives off again.
##
## The economy stays statistical - the coins here are the visible face of the
## income the business already books - so the flow can never change the balance
## of the game, it only shows it.

const MAX_AGENTS := 7
const DRIVE_SPEED := 3.4
const WALK_SPEED := 1.2
const SPAWN_MIN := 1.6
const SPAWN_MAX := 4.2
const QUEUE_EXTRA := 1
const ROAD_REACH := 17.0

var agents: Array[Dictionary] = []
var state
var _queues: Dictionary = {}
var _timers: Dictionary = {}
var _spots: Dictionary = {}
var _bays: Dictionary = {}
var _bay_roots: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _swing := 0.0


func setup(town_state) -> void:
	state = town_state
	_rng.seed = 77123
	if state == null:
		return
	for id in state.business_ids():
		_spots[id] = _plot_spot(id)
		_queues[id] = ServiceQueue.new()
		_timers[id] = _rng.randf_range(0.4, 2.5)


func _plot_spot(id: String) -> Dictionary:
	var plot := BusinessData.plot(id)
	var to_road := -signf(plot.x)
	if to_road == 0.0:
		to_road = -1.0
	return {
		"center_z": plot.y,
		"to_road": to_road,
		"car_x": plot.x + to_road * 2.7,
		"person_x": plot.x + to_road * 1.95,
		"door": Vector3(plot.x + to_road * 1.15, 0, plot.y + 0.45),
	}


## How many people can be served at once: it grows with the business level and
## is capped so a level 5 shop still reads as a queue you can follow with the
## eye instead of a crowd.
func slots_for(id: String) -> int:
	var business = state.business(id) if state != null else null
	if business == null or not business.unlocked:
		return 0
	return clampi(1 + int((business.level - 1) * 0.75), 1, 4)


func _process(delta: float) -> void:
	if state == null:
		return
	_swing += delta * 7.5
	for id in _spots.keys():
		_tick_business(id, delta)
	_tick_agents(delta)


func _tick_business(id: String, delta: float) -> void:
	var slots := slots_for(id)
	var queue: ServiceQueue = _queues[id]
	if slots <= 0:
		queue.clear()
		return
	queue.configure(slots, slots + QUEUE_EXTRA)
	if int(_bays.get(id, -1)) != slots:
		_draw_bays(id, slots)

	# Anyone who finished their service pays here.
	for finished in queue.tick(delta):
		_paid(id, int(finished))

	if agents.size() >= MAX_AGENTS:
		return
	_timers[id] = float(_timers[id]) - delta
	if float(_timers[id]) > 0.0:
		return
	var business = state.business(id)
	var per_minute := maxf(1.0, business.served_per_minute(state.traffic()))
	_timers[id] = clampf(60.0 / per_minute * 6.0, SPAWN_MIN, SPAWN_MAX) * _rng.randf_range(
		0.8, 1.25
	)
	_spawn(id)


## Painted service bays on the apron: capacity is something you can see grow.
func _draw_bays(id: String, slots: int) -> void:
	_bays[id] = slots
	var old: Node3D = _bay_roots.get(id)
	if old != null:
		old.queue_free()
	var root := Node3D.new()
	root.name = "Bays_" + id
	add_child(root)
	_bay_roots[id] = root

	var spot: Dictionary = _spots[id]
	var x := float(spot["car_x"])
	var first := _car_slot_z(id, 0)
	var last := _car_slot_z(id, slots - 1)

	# The paved forecourt between the road and the plot, so parked cars sit on
	# tarmac with painted bays instead of floating on the walkway.
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(1.4, 0.03, absf(first - last) + 1.5)
	slab.mesh = slab_mesh
	slab.material_override = VehicleMesh.paint(Color(0.33, 0.34, 0.37), 0.95)
	slab.position = Vector3(x, 0.045, (first + last) * 0.5)
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(slab)

	var paint := VehicleMesh.paint(Color(0.93, 0.93, 0.89), 0.8)
	for i in slots:
		var z := _car_slot_z(id, i)
		for side in [-1.0, 1.0]:
			_bay_mark(root, paint, Vector3(x, 0.075, z + 0.62 * side), Vector3(2.0, 0.02, 0.055))
			_bay_mark(root, paint, Vector3(x + 1.0 * side, 0.075, z), Vector3(0.055, 0.02, 1.2))


func _bay_mark(root: Node3D, paint: StandardMaterial3D, at: Vector3, size: Vector3) -> void:
	var mark := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mark.mesh = mesh
	mark.material_override = paint
	mark.position = at
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mark)


func _spawn(id: String) -> void:
	var spot: Dictionary = _spots[id]
	var customer_id := _next_id
	_next_id += 1

	var kind: String = VehicleMesh.KINDS[_rng.randi_range(0, VehicleMesh.KINDS.size() - 1)]
	var paint: Color = VehicleMesh.PAINTS[_rng.randi_range(0, VehicleMesh.PAINTS.size() - 1)]
	var car := VehicleMesh.build(kind, paint)
	var slot_z := _car_slot_z(id, 0)
	car.position = Vector3(float(spot["car_x"]), 0.0, slot_z + ROAD_REACH)
	car.rotation_degrees.y = 180.0
	add_child(car)

	var entry := {
		"id": customer_id,
		"business": id,
		"car": car,
		"person": null,
		"phase": "drive",
		"timer": 0.0,
		"crew": _rng.randi_range(0, PersonMesh.SHIRTS.size() - 1),
		"amount": _ticket(id),
	}
	var verdict := (_queues[id] as ServiceQueue).request(customer_id, _service_time(id))
	if verdict == "rejected":
		# The line is full: this one drives straight past without stopping.
		entry["phase"] = "pass"
	agents.append(entry)


func _ticket(id: String) -> float:
	var business = state.business(id)
	var served := maxf(1.0, business.served_per_minute(state.traffic()))
	return maxf(1.0, round(business.net_per_minute(state.traffic()) / served))


func _service_time(id: String) -> float:
	var slots := maxf(1.0, float(slots_for(id)))
	var business = state.business(id)
	var served := maxf(1.0, business.served_per_minute(state.traffic()))
	return clampf(60.0 / served * slots * 2.0, 2.5, 9.0)


func _car_slot_z(id: String, index: int) -> float:
	var spot: Dictionary = _spots[id]
	return float(spot["center_z"]) + 1.5 - 1.45 * float(index)


func _person_slot(id: String, index: int) -> Vector3:
	var spot: Dictionary = _spots[id]
	return Vector3(
		float(spot["person_x"]),
		0.0,
		float(spot["center_z"]) + 1.0 - 0.55 * float(index)
	)


func _tick_agents(delta: float) -> void:
	var finished: Array[int] = []
	for i in agents.size():
		var agent: Dictionary = agents[i]
		match String(agent["phase"]):
			"drive":
				if _drive(agent, delta):
					_exit_car(agent)
			"pass":
				if _pass(agent, delta):
					finished.append(i)
			"board":
				if _walk(agent, delta, _person_slot_of(agent)):
					agent["phase"] = "wait"
			"wait":
				_wait(agent)
			"to_door":
				if _walk(agent, delta, _door_of(agent)):
					_enter(agent)
			"inside":
				pass
			"leaving":
				if _walk(agent, delta, (agent["car"] as Node3D).position):
					_free_person(agent)
					agent["phase"] = "depart"
			"depart":
				if _drive_out(agent, delta):
					finished.append(i)
	for index in range(finished.size() - 1, -1, -1):
		_remove(finished[index])


func _person_slot_of(agent: Dictionary) -> Vector3:
	var id := String(agent["business"])
	var index := maxi(0, (_queues[id] as ServiceQueue).index_of(int(agent["id"])))
	return _person_slot(id, index)


func _door_of(agent: Dictionary) -> Vector3:
	var spot: Dictionary = _spots[String(agent["business"])]
	var door: Vector3 = spot["door"]
	return door


func _drive(agent: Dictionary, delta: float) -> bool:
	var id := String(agent["business"])
	var queue: ServiceQueue = _queues[id]
	var index := queue.index_of(int(agent["id"]))
	var target := _car_slot_z(id, maxi(0, index))
	var car: Node3D = agent["car"]
	var distance := target - car.position.z
	var step := DRIVE_SPEED * delta
	if absf(distance) <= step:
		car.position.z = target
		return true
	car.position.z += signf(distance) * step
	VehicleMesh.roll(car, step)
	return false


func _pass(agent: Dictionary, delta: float) -> bool:
	var car: Node3D = agent["car"]
	var step := DRIVE_SPEED * delta
	car.position.z -= step
	VehicleMesh.roll(car, step)
	return car.position.z < -ROAD_REACH


func _drive_out(agent: Dictionary, delta: float) -> bool:
	var car: Node3D = agent["car"]
	var step := DRIVE_SPEED * 1.25 * delta
	car.position.z -= step
	VehicleMesh.roll(car, step)
	return car.position.z < -ROAD_REACH


func _exit_car(agent: Dictionary) -> void:
	var car: Node3D = agent["car"]
	var spot: Dictionary = _spots[String(agent["business"])]
	var person := PersonMesh.build(int(agent["crew"]))
	var door := Vector3(float(spot["to_road"]) * 0.55, 0.0, 0.25)
	person.position = car.position + door
	person.rotation_degrees.y = 90.0 * float(spot["to_road"])
	add_child(person)
	agent["person"] = person
	agent["phase"] = "board"

	# Nose the car in towards the shop so the parked row reads as a forecourt
	# and never as a traffic jam.
	var to_road := float(spot["to_road"])
	var facing := 90.0 * to_road
	if facing < 0.0:
		facing += 360.0
	var tween := create_tween()
	tween.tween_property(car, "rotation_degrees:y", facing, 0.5).set_trans(
		Tween.TRANS_SINE
	)


func _walk(agent: Dictionary, delta: float, target: Vector3) -> bool:
	var person: Node3D = agent["person"]
	if person == null:
		return true
	var flat_target := Vector3(target.x, 0.0, target.z)
	var to_target := flat_target - person.position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance < 0.06:
		PersonMesh.animate(person, _swing, 0.0)
		return true
	var direction := to_target / distance
	person.position += direction * minf(distance, WALK_SPEED * delta)
	person.position.y = 0.0
	if absf(direction.x) > 0.05:
		person.rotation_degrees.y = 90.0 if direction.x > 0.0 else -90.0
	elif absf(direction.z) > 0.05:
		person.rotation_degrees.y = 0.0 if direction.z > 0.0 else 180.0
	PersonMesh.animate(person, _swing, 1.0)
	return false


func _wait(agent: Dictionary) -> void:
	var id := String(agent["business"])
	var queue: ServiceQueue = _queues[id]
	var person: Node3D = agent["person"]
	if person == null:
		return
	var index := queue.index_of(int(agent["id"]))
	if index < 0:
		# Already served: head inside.
		agent["phase"] = "to_door"
		return
	# Shuffle forward as the line advances, then wait with a small idle sway.
	var target := _person_slot(id, index)
	if person.position.distance_to(Vector3(target.x, 0.0, target.z)) > 0.08:
		person.position = person.position.lerp(
			Vector3(target.x, 0.0, target.z), 0.12
		)
	PersonMesh.animate(person, _swing, 0.0)
	person.position.y = absf(sin(_swing * 0.6 + float(agent["id"]))) * 0.012
	if queue.is_serving(int(agent["id"])):
		agent["phase"] = "to_door"


func _enter(agent: Dictionary) -> void:
	var person: Node3D = agent["person"]
	if person != null:
		person.visible = false
	agent["phase"] = "inside"


## Called by ServiceQueue.tick, in the middle of the queue step, so the payment
## pop-up lands exactly when the traveller walks back out with their parcel.
func _paid(_id: String, customer_id: int) -> void:
	for i in agents.size():
		var agent: Dictionary = agents[i]
		if int(agent["id"]) != customer_id:
			continue
		var person: Node3D = agent["person"]
		if person != null:
			person.position = _door_of(agent)
			person.visible = true
			PersonMesh.animate(person, _swing, 0.0, true)
		agent["phase"] = "leaving"
		_coin_burst(_door_of(agent), float(agent["amount"]))
		return


func _free_person(agent: Dictionary) -> void:
	var person: Node3D = agent["person"]
	if person != null:
		person.queue_free()
	agent["person"] = null


func _remove(index: int) -> void:
	var agent: Dictionary = agents[index]
	_free_person(agent)
	var car: Node3D = agent["car"]
	if car != null:
		car.queue_free()
	agents.remove_at(index)


func _coin_burst(at: Vector3, amount: float) -> void:
	var label := Label3D.new()
	label.text = "+%s" % App.format_number(amount)
	label.font_size = 72
	label.pixel_size = 0.0032
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 14
	label.modulate = Color(1.0, 0.87, 0.42)
	label.outline_modulate = Color(0.12, 0.08, 0.02, 0.9)
	var font := load("res://assets/fonts/Vazirmatn-Bold.ttf")
	if font != null:
		label.font = font
	label.position = at + Vector3(0, 1.9, 0)
	add_child(label)
	var coins: Array[Node3D] = []
	for i in 3:
		var coin := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.07
		mesh.bottom_radius = 0.07
		mesh.height = 0.03
		mesh.radial_segments = 8
		coin.mesh = mesh
		coin.rotation_degrees.x = 90.0
		coin.material_override = PersonMesh.flat(Color(1.0, 0.8, 0.28))
		coin.position = at + Vector3(0, 1.4, 0)
		add_child(coin)
		coins.append(coin)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", 2.9, 1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_delay(0.35)
	for i in coins.size():
		var coin: Node3D = coins[i]
		var side := -1.0 if i % 2 == 0 else 1.0
		tween.tween_property(
			coin, "position", at + Vector3(0.35 * side, 0.5, 0.2 * float(i) - 0.2), 0.9
		).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(func() -> void:
		label.queue_free()
		for coin in coins:
			coin.queue_free()
	)
