class_name CustomerFlow
extends Node3D
## Vehicles pull off the desert highway through the entry crosswalk, park inside
## painted white service bays, show a live green service progress bar, pop
## floating green cash, and exit back onto the highway!

const MAX_AGENTS := 9
const DRIVE_SPEED := 4.4
const SPAWN_MIN := 1.1
const SPAWN_MAX := 3.2
const ENTRY_POS := Vector3(-1.2, 0.03, -6.4)
const EXIT_POS := Vector3(4.8, 0.03, -6.4)

var agents: Array[Dictionary] = []
var max_agents := MAX_AGENTS
var state: TownState
var _queues: Dictionary = {}
var _timers: Dictionary = {}
var _bays: Dictionary = {}
var _bay_roots: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _next_id := 1


func setup(town_state: TownState) -> void:
	state = town_state
	_rng.seed = 77123
	if state == null:
		return
	for id in state.business_ids():
		_queues[id] = ServiceQueue.new()
		_timers[id] = _rng.randf_range(0.3, 1.8)


func slots_for(id: String) -> int:
	var b = state.business(id) if state != null else null
	if b == null or not b.unlocked:
		return 0
	return b.active_bays()


func _bay_world_pos(id: String, slot_index: int, total_slots: int) -> Vector3:
	var plot := BusinessData.plot(id)
	var bay_off := BusinessData.bay_offset(id)
	var ox := bay_off.x + (float(slot_index) - float(maxi(1, total_slots) - 1) * 0.5) * 1.65
	return Vector3(plot.x + ox, 0.03, plot.y + bay_off.y)


func _process(delta: float) -> void:
	if state == null:
		return
	for id in _queues.keys():
		_tick_business(id, delta)
	_tick_agents(delta)


func _tick_business(id: String, delta: float) -> void:
	var slots := slots_for(id)
	var queue: ServiceQueue = _queues[id]
	if slots <= 0:
		queue.clear()
		if _bay_roots.has(id):
			(_bay_roots[id] as Node3D).queue_free()
			_bay_roots.erase(id)
			_bays.erase(id)
		return
	queue.configure(slots, slots + 1)
	if int(_bays.get(id, -1)) != slots:
		_draw_bays(id, slots)

	for finished in queue.tick(delta):
		_paid(id, int(finished))

	if agents.size() >= max_agents:
		return
	_timers[id] = float(_timers[id]) - delta
	if float(_timers[id]) > 0.0:
		return
	var b = state.business(id)
	var per_min := maxf(2.0, b.served_per_minute(state.traffic()))
	_timers[id] = clampf(60.0 / per_min * 3.5, SPAWN_MIN, SPAWN_MAX) * _rng.randf_range(0.8, 1.2)
	_spawn(id, slots)


func _draw_bays(id: String, slots: int) -> void:
	_bays[id] = slots
	if _bay_roots.has(id):
		(_bay_roots[id] as Node3D).queue_free()
	var root := Node3D.new()
	root.name = "Bays_" + id
	add_child(root)
	_bay_roots[id] = root

	var paint := VehicleMesh.paint(Color(0.95, 0.95, 0.92), 0.78, 0.0)
	var pad := VehicleMesh.paint(Color(0.32, 0.32, 0.36), 0.95, 0.02)
	for i in slots:
		var pos := _bay_world_pos(id, i, slots)
		_mark(root, pad, pos + Vector3(0, 0.012, 0.2), Vector3(1.36, 0.02, 2.25))
		for sx in [-0.66, 0.66]:
			_mark(root, paint, pos + Vector3(float(sx), 0.028, 0.2), Vector3(0.06, 0.015, 2.2))
		for sz in [-0.88, 1.28]:
			_mark(root, paint, pos + Vector3(0, 0.028, float(sz)), Vector3(1.36, 0.015, 0.06))


func _mark(parent: Node3D, mat: StandardMaterial3D, pos: Vector3, size: Vector3) -> void:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


func _spawn(id: String, slots: int) -> void:
	var cid := _next_id
	_next_id += 1
	var b = state.business(id)
	var duration := clampf(b.service_seconds() if b != null else 3.2, 1.4, 5.5)
	var queue_res := (_queues[id] as ServiceQueue).request(cid, duration)
	if queue_res == "rejected":
		return
	var slot_idx := mini(slots - 1, maxi(0, (_queues[id] as ServiceQueue).index_of(cid)))
	var target_pos := _bay_world_pos(id, slot_idx, slots) + Vector3(0, 0, 0.22)

	var kind := VehicleMesh.KINDS[_rng.randi_range(0, VehicleMesh.KINDS.size() - 1)]
	if TownEvents.spawns_monsters(state.active_event) and _rng.randf() < 0.65:
		kind = "monster"
	elif _rng.randf() < 0.38:
		kind = "camper"
	var col := VehicleMesh.PAINTS[_rng.randi_range(0, VehicleMesh.PAINTS.size() - 1)]
	var car := VehicleMesh.build(kind, col)
	car.position = ENTRY_POS
	add_child(car)

	# Floating 3D green service progress bar above the vehicle while serving!
	var bar_root := Node3D.new()
	bar_root.position = Vector3(0, 1.55, 0)
	bar_root.visible = false
	car.add_child(bar_root)
	var bg_mat := VehicleMesh.paint(Color(0.10, 0.12, 0.16), 0.9, 0.0)
	var fg_mat := StandardMaterial3D.new()
	fg_mat.albedo_color = Color(0.24, 0.90, 0.36)
	fg_mat.emission_enabled = true
	fg_mat.emission = Color(0.22, 0.86, 0.34)
	fg_mat.emission_energy_multiplier = 0.85
	_mark(bar_root, bg_mat, Vector3.ZERO, Vector3(1.05, 0.14, 0.06))
	var fill := MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(0.98, 0.10, 0.08)
	fill.mesh = fill_mesh
	fill.material_override = fg_mat
	bar_root.add_child(fill)

	agents.append({
		"cid": cid,
		"business_id": id,
		"node": car,
		"bar_root": bar_root,
		"bar_fill": fill,
		"phase": "arrive",
		"target": target_pos,
	})


func _paid(id: String, cid: int) -> void:
	for entry in agents:
		if int(entry["cid"]) == cid:
			entry["phase"] = "depart"
			(entry["bar_root"] as Node3D).visible = false
			var b = state.business(id)
			if b != null:
				var ticket: float = maxf(5.0, b.price() * state.income_multiplier() * state.event_income() * 0.25)
				_pop_cash((entry["node"] as Node3D).position + Vector3(0, 1.35, 0), ticket)
			break


func _pop_cash(at: Vector3, amount: float) -> void:
	var lbl := Label3D.new()
	var amt_txt: String = App.format_short(amount) if App != null else ("%d" % int(round(amount)))
	lbl.text = "+$" + amt_txt
	lbl.font_size = 48
	lbl.pixel_size = 0.0065
	lbl.modulate = Color(0.36, 0.96, 0.44)
	lbl.outline_modulate = Color(0.08, 0.12, 0.16)
	lbl.outline_size = 10
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = at
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", at.y + 1.15, 0.95).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.95)
	tw.chain().tween_callback(lbl.queue_free)


func _tick_agents(delta: float) -> void:
	var i := agents.size() - 1
	while i >= 0:
		var entry: Dictionary = agents[i]
		var car: Node3D = entry["node"]
		var phase := String(entry["phase"])
		if phase == "arrive":
			var target: Vector3 = entry["target"]
			if _drive_toward(car, target, DRIVE_SPEED * delta):
				car.rotation_degrees.y = 180.0
				entry["phase"] = "service"
		elif phase == "service":
			var id := String(entry["business_id"])
			var cid := int(entry["cid"])
			var q: ServiceQueue = _queues.get(id)
			if q == null or q.index_of(cid) < 0:
				entry["phase"] = "depart"
			else:
				var prog := clampf(q.progress_of(cid), 0.04, 1.0)
				var bar_root: Node3D = entry["bar_root"]
				var fill: MeshInstance3D = entry["bar_fill"]
				bar_root.visible = q.is_serving(cid)
				fill.scale.x = prog
				fill.position.x = -0.49 * (1.0 - prog)
		else:
			if _drive_toward(car, EXIT_POS, DRIVE_SPEED * 1.15 * delta):
				car.queue_free()
				agents.remove_at(i)
		i -= 1


func _drive_toward(car: Node3D, target: Vector3, max_step: float) -> bool:
	var diff := target - car.position
	diff.y = 0.0
	var dist := diff.length()
	if dist <= max_step + 0.04:
		car.position = Vector3(target.x, car.position.y, target.z)
		return true
	var dir := diff / dist
	car.position += dir * max_step
	car.rotation.y = atan2(dir.x, dir.z)
	VehicleMesh.roll(car, max_step)
	return false
