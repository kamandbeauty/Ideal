class_name CustomerFlow
extends Node3D
## Physical visits: reserve a stable slot -> drive in -> park -> service ->
## wait for a row manoeuvre -> reverse out -> yield/merge onto the highway.
## Inbound and outbound row locks are never held by a parked customer.

const MAX_AGENTS := 9
const DRIVE_SPEED := 4.2
const PARKING_SPEED := 1.8
const CUSTOMER_KINDS: Array[String] = ["car", "suv", "pickup", "camper"]

var agents: Array[Dictionary] = []
var max_agents := MAX_AGENTS
var state: TownState
var served_visits := 0
var completed_visits := 0
var spawned_visits := 0
var visits_by_business: Dictionary = {}
var _queues: Dictionary = {}
var _timers: Dictionary = {}
var _occupied: Dictionary = {}
var _row_owners: Dictionary = {}
var _departures: Dictionary = {}
var _bay_roots: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _spawn_cursor := 0


func setup(town_state: TownState) -> void:
	state = town_state
	_rng.seed = 77123
	if state == null:
		return
	for id in state.business_ids():
		_queues[id] = ServiceQueue.new()
		_timers[id] = _rng.randf_range(0.3, 1.8)
		_occupied[id] = {}


func slots_for(id: String) -> int:
	var b := state.business(id) if state != null else null
	return b.active_bays() if b != null and b.unlocked else 0


func _physics_process(delta: float) -> void:
	if state == null:
		return
	for id in state.business_ids():
		_tick_business(id, delta)
	# Departures take priority over new arrivals, so a row cannot starve.
	_tick_agents(delta)
	_try_spawn_next()


func _tick_business(id: String, delta: float) -> void:
	var slots := slots_for(id)
	if slots <= 0:
		return
	var queue: ServiceQueue = _queues[id]
	queue.configure(slots, slots)
	if not _bay_roots.has(id) or int((_bay_roots[id] as Node3D).get_meta("slots", 0)) != slots:
		if _bay_roots.has(id):
			(_bay_roots[id] as Node3D).queue_free()
		var bays := ServiceBayVisuals.build(id, slots)
		add_child(bays)
		_bay_roots[id] = bays
	for finished in queue.tick(delta):
		_paid(id, int(finished))
	_timers[id] = maxf(-1.0, float(_timers[id]) - delta)


func _try_spawn_next() -> void:
	if agents.size() >= max_agents:
		return
	var ids := state.business_ids()
	for offset in ids.size():
		var index := (_spawn_cursor + offset) % ids.size()
		var id: String = ids[index]
		var slots := slots_for(id)
		if slots <= 0 or float(_timers[id]) > 0.0:
			continue
		var row := ForecourtLayout.row_for(id)
		if _row_owners.has(row) or not (_departures.get(row, []) as Array).is_empty():
			continue
		var free_slot := -1
		for slot in slots:
			if not (_occupied[id] as Dictionary).has(slot):
				free_slot = slot
				break
		if free_slot < 0:
			continue
		if _spawn(id, free_slot):
			_spawn_cursor = (index + 1) % ids.size()
			_timers[id] = _rng.randf_range(2.4, 4.5)
			return


func _spawn(id: String, slot: int) -> bool:
	var kind := CUSTOMER_KINDS[_rng.randi_range(0, CUSTOMER_KINDS.size() - 1)]
	if TownEvents.spawns_monsters(state.active_event) and _rng.randf() < 0.65:
		kind = "monster"
	var route := ForecourtLayout.inbound(id, slot)
	if not VehicleBody.spawn_clear(self, kind, route[0], PI * 0.5):
		return false
	var cid := _next_id
	_next_id += 1
	var b := state.business(id)
	var duration := clampf(b.service_seconds(), 2.4, 6.5)
	# Reserve now; the service clock MUST NOT tick while driving to the bay.
	if (_queues[id] as ServiceQueue).request(cid, duration, false) == "rejected":
		return false
	(_occupied[id] as Dictionary)[slot] = cid
	_row_owners[ForecourtLayout.row_for(id)] = cid
	var car := VehicleBody.new()
	car.name = "Customer%d_%s" % [cid, id]
	car.setup(kind, VehicleMesh.PAINTS[_rng.randi_range(0, VehicleMesh.PAINTS.size() - 1)])
	car.position = route[0]
	car.rotation.y = PI * 0.5
	add_child(car)
	car.set_route(route)
	var bar := ServiceBayVisuals.progress_bar()
	car.add_child(bar)
	(
		agents
		. append(
			{
				"cid": cid,
				"business_id": id,
				"slot": slot,
				"node": car,
				"bar_root": bar,
				"phase": "arrive",
				"bay_released": false,
			}
		)
	)
	spawned_visits += 1
	return true


func _paid(id: String, cid: int) -> void:
	for entry in agents:
		if int(entry["cid"]) != cid:
			continue
		entry["phase"] = "wait_depart"
		var row := ForecourtLayout.row_for(id)
		if not _departures.has(row):
			_departures[row] = []
		(_departures[row] as Array).append(cid)
		(entry["bar_root"] as Node3D).visible = false
		var b := state.business(id)
		var ticket := maxf(5.0, b.price() * state.income_multiplier() * state.event_income() * 0.25)
		_pop_cash((entry["node"] as Node3D).position + Vector3(0, 1.35, 0), ticket)
		visits_by_business[id] = int(visits_by_business.get(id, 0)) + 1
		served_visits += 1
		break


func _tick_agents(delta: float) -> void:
	for i in range(agents.size() - 1, -1, -1):
		var entry: Dictionary = agents[i]
		var car: VehicleBody = entry["node"]
		var id := String(entry["business_id"])
		var row := ForecourtLayout.row_for(id)
		var slot := int(entry["slot"])
		match String(entry["phase"]):
			"arrive":
				car.drive(delta, DRIVE_SPEED)
				if car.arrived():
					entry["phase"] = "service"
					(_queues[id] as ServiceQueue).mark_arrived(int(entry["cid"]))
					_release_row(entry)
			"service":
				car.hold(delta)
				var bar: Node3D = entry["bar_root"]
				bar.visible = true
				ServiceBayVisuals.set_progress(bar, (_queues[id] as ServiceQueue).progress_of(int(entry["cid"])))
			"wait_depart":
				car.hold(delta)
				var waiting: Array = _departures.get(row, [])
				if not _row_owners.has(row) and not waiting.is_empty() and int(waiting[0]) == int(entry["cid"]):
					waiting.pop_front()
					_row_owners[row] = int(entry["cid"])
					entry["phase"] = "reverse"
					car.set_route(ForecourtLayout.reverse_out(id, slot))
			"reverse":
				car.drive(delta, PARKING_SPEED, true)
				if car.arrived():
					entry["phase"] = "depart"
					car.set_route(ForecourtLayout.outbound(id, slot))
			"depart":
				car.drive(delta, DRIVE_SPEED)
				if car.position.x > ForecourtLayout.DRIVE_X - 0.1 and not bool(entry["bay_released"]):
					_release_row(entry)
					(_occupied[id] as Dictionary).erase(slot)
					entry["bay_released"] = true
				if car.arrived():
					entry["phase"] = "yield"
					car.merge_requested = true
			"yield":
				car.hold(delta)
				if _merge_clear(car):
					entry["phase"] = "merge"
					car.set_route(ForecourtLayout.highway_merge())
			"merge":
				car.drive(delta, DRIVE_SPEED)
				if car.position.x > ForecourtLayout.DRIVE_X + 4.3:
					car.merge_requested = false
				if car.arrived():
					car.merge_requested = false
					car.collision_layer = 0
					car.queue_free()
					agents.remove_at(i)
					completed_visits += 1


func _merge_clear(car: VehicleBody) -> bool:
	var highway := get_parent().get_node_or_null("Traffic") as Traffic
	if highway == null or not highway.can_merge():
		return false
	for other in get_tree().get_nodes_in_group(VehicleBody.GROUP):
		var peer := other as VehicleBody
		if peer == car or not peer.visible or peer.collision_layer == 0:
			continue
		if absf(peer.position.z - ForecourtLayout.NEAR_LANE_Z) > 1.2:
			continue
		var rear := peer.position.x - peer.dimensions.y * 0.5
		var nose := peer.position.x + peer.dimensions.y * 0.5
		if nose > ForecourtLayout.DRIVE_X - 3.3 and rear < ForecourtLayout.DRIVE_X + 4.0:
			return false
	return true


func _release_row(entry: Dictionary) -> void:
	var row := ForecourtLayout.row_for(String(entry["business_id"]))
	if int(_row_owners.get(row, -1)) == int(entry["cid"]):
		_row_owners.erase(row)


func _pop_cash(at: Vector3, amount: float) -> void:
	var label := Label3D.new()
	label.text = "+$" + App.format_short(amount)
	label.font_size = 44
	label.pixel_size = 0.0065
	label.modulate = Color(0.36, 0.96, 0.44)
	label.outline_modulate = Color(0.08, 0.12, 0.16)
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", at.y + 1.15, 0.95).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate:a", 0.0, 0.95)
	tween.chain().tween_callback(label.queue_free)
