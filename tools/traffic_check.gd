extends Node
## Real headless PhysicsServer3D integration test, not a mocked movement test.
## Runs six simulated minutes: low cap, live capacity changes, then monster
## traffic/high cap. Fails on penetration, double-booking, or a stalled system.

const DURATION := 360.0
var _view: TownView
var _state: TownState
var _finished := false
var _start_ms := 0
var _last_progress := 0.0
var _last_completed := 0
var _next_log := 30.0
var _service_seen: Dictionary = {}
var _quality_stage := 0


func _ready() -> void:
	_start_ms = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 8.0
	App.set_quality("high")
	Engine.max_fps = 0
	_state = TownState.new("desert")
	for id in _state.business_ids():
		var business := _state.business(id)
		business.unlocked = true
		business.level = 1
	_view = TownView.new()
	add_child(_view)
	_view.setup(_state)
	_view.customers.max_agents = 3
	var elapsed := 0.0
	var upgraded := false
	var high_cap := false
	while elapsed < DURATION and not _finished:
		await get_tree().physics_frame
		elapsed += Engine.time_scale / float(Engine.physics_ticks_per_second)
		if elapsed > 35.0 and not upgraded:
			upgraded = true
			for id in _state.business_ids():
				var business := _state.business(id)
				business.capacity_level = business.max_branch_for("capacity")
			_view.refresh_all()
		if elapsed > 100.0 and not high_cap:
			high_cap = true
			_view.customers.max_agents = 9
			_state.start_event("monster_hills")
		# Existing customers must immediately follow quality changes without
		# restarting service or rebuilding their collision bodies.
		if _quality_stage < 3 and elapsed > 145.0 + float(_quality_stage) * 25.0:
			App.set_quality(["low", "medium", "high"][_quality_stage])
			Engine.max_fps = 0
			_quality_stage += 1
		_check_world(elapsed)
		if elapsed >= _next_log:
			print(
				(
					"TRAFFIC %.0fs: spawned=%d served=%d exited=%d visits=%s"
					% [
						elapsed,
						_view.customers.spawned_visits,
						_view.customers.served_visits,
						_view.customers.completed_visits,
						str(_view.customers.visits_by_business)
					]
				)
			)
			_next_log += 30.0
	if _finished:
		return
	var flow := _view.customers
	if flow.completed_visits < 12:
		_fail("Too few complete visits: %d" % flow.completed_visits)
		return
	for id in _state.business_ids():
		if int(flow.visits_by_business.get(id, 0)) == 0:
			_fail("No customer reached " + id + ": " + _diagnostics())
			return
		if not _service_seen.has(id):
			_fail("No actual service feedback observed for " + id)
			return
	print("TRAFFIC FX: all 8 facility animations observed; low/medium/high budgets and lifecycle gates checked")
	print(
		(
			"TRAFFIC OK: 360s, no penetrations or double bookings; %d completed visits across all 8 businesses"
			% flow.completed_visits
		)
	)
	_finished = true
	get_tree().quit(0)


func _check_world(elapsed: float) -> void:
	var bodies := get_tree().get_nodes_in_group(VehicleBody.GROUP)
	for i in bodies.size():
		var car := bodies[i] as VehicleBody
		if car == null or not car.visible or car.collision_layer == 0:
			continue
		for j in range(i + 1, bodies.size()):
			var other := bodies[j] as VehicleBody
			if not other.visible or other.collision_layer == 0:
				continue
			if DrivingRules.overlaps(
				DrivingRules.xz(car.position),
				car.dimensions,
				car.rotation.y,
				DrivingRules.xz(other.position),
				other.dimensions,
				other.rotation.y,
				-0.025
			):
				_fail(
					(
						"Vehicle penetration at %.1fs: %s %s / %s %s"
						% [elapsed, car.name, str(car.position), other.name, str(other.position)]
					)
				)
				return
		for id in _state.business_ids():
			var obstacles: Array[Rect2] = [ForecourtLayout.building_rect(id)]
			obstacles.append_array(ForecourtLayout.prop_rects(id, _state.business(id).active_bays()))
			for rect in obstacles:
				if DrivingRules.overlaps(
					DrivingRules.xz(car.position),
					car.dimensions,
					car.rotation.y,
					rect.get_center(),
					rect.size,
					0.0,
					-0.025
				):
					_fail("Scenery penetration at %.1fs: %s inside %s" % [elapsed, car.name, id])
					return
	var claimed := {}
	for entry in _view.customers.agents:
		_check_service_feedback(entry)
		if _finished:
			return
		var key := "%s:%d" % [String(entry["business_id"]), int(entry["slot"])]
		if bool(entry["bay_released"]):
			continue
		if claimed.has(key):
			_fail("Double-booked bay: " + key)
			return
		claimed[key] = true
	if _view.customers.completed_visits > _last_completed:
		_last_completed = _view.customers.completed_visits
		_last_progress = elapsed
	if elapsed - _last_progress > 90.0:
		_fail("Traffic made no exit progress for 90s: " + _diagnostics())


func _check_service_feedback(entry: Dictionary) -> void:
	var car: VehicleBody = entry["node"]
	var effects: ServiceEffects = entry.get("service_fx")
	var bar: Node3D = entry["bar_root"]
	var active := String(entry["phase"]) == "service"
	var id := String(entry["business_id"])
	if effects == null:
		_fail("Missing service feedback for " + car.name)
		return
	if effects.servicing != active or effects.visible != active or bar.visible != active:
		_fail("Feedback is not synchronized with " + car.name + ": " + String(entry["phase"]))
		return
	if effects.particle_count() != Quality.service_particle_count(App.quality):
		_fail("Service particle budget did not follow the live preset")
		return
	var expected_activations := 0 if String(entry["phase"]) == "arrive" else 1
	if effects.activation_count != expected_activations:
		_fail("Service animation restarted or ran before arrival: " + car.name)
		return
	if active:
		if car.position.distance_to(ForecourtLayout.bay_position(id, int(entry["slot"]))) > 0.06 or car.speed > 0.001:
			_fail("An effect started before its car was parked: " + car.name)
			return
		if not effects.global_basis.is_equal_approx(Basis.IDENTITY):
			_fail("Service equipment rotated away from its world-aligned bay: " + car.name)
			return
		_service_seen[id] = true


func _diagnostics() -> String:
	if _view == null or _view.customers == null:
		return "Scenario setup did not complete"
	var entries: Array[String] = []
	for entry in _view.customers.agents:
		var car: VehicleBody = entry["node"]
		entries.append(
			"%s %s at %s wait %.1fs" % [car.name, str(entry["phase"]), str(car.position), car.waiting_seconds]
		)
	var traffic: Traffic = _view.get_node("Traffic")
	for entry in traffic.cars:
		var car: VehicleBody = entry["node"]
		entries.append(
			(
				"%s at %s speed %.2f gate %s pass %s"
				% [
					car.name,
					str(car.position),
					car.speed,
					str(entry.get("gate_seen", false)),
					str(entry.get("merge_pass", false))
				]
			)
		)
	return "; ".join(entries)


func _fail(message: String) -> void:
	printerr("TRAFFIC FAILED: " + message)
	_finished = true
	get_tree().quit(1)


func _process(_delta: float) -> void:
	if not _finished and Time.get_ticks_msec() - _start_ms > 150000:
		_fail("Wall-clock timeout: " + _diagnostics())
