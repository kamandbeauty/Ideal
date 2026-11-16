extends TestCase
## Safety properties use the same layout, envelopes and braking rules as play.


func test_service_does_not_begin_on_the_highway() -> void:
	var queue := ServiceQueue.new()
	queue.configure(2, 2)
	queue.request(1, 4.0, false)
	queue.request(2, 4.0, true)
	var paid := queue.tick(20.0)
	check(not paid.has(1), "travelling customers cannot finish their service")
	check(paid.has(2), "an actually parked customer can finish independently")
	almost(queue.progress_of(1), 0.0, "no service progress before parking")
	queue.mark_arrived(1)
	queue.tick(2.0)
	almost(queue.progress_of(1), 0.5, "service starts at the parking spot")
	check(queue.tick(2.1).has(1), "parked customer eventually pays")


func test_every_parking_slot_has_a_unique_safe_envelope() -> void:
	var positions: Array[Vector3] = []
	var size := VehicleMesh.footprint("monster")
	for id in BusinessData.ids():
		for slot in BusinessData.max_bays(id):
			var at := ForecourtLayout.bay_position(id, slot)
			check(ForecourtLayout.LOT_BOUNDS.has_point(DrivingRules.xz(at)), "bay inside the paved lot")
			for previous in positions:
				check(
					not DrivingRules.overlaps(DrivingRules.xz(at), size, PI, DrivingRules.xz(previous), size, PI, 0.15),
					"two bays must not share space"
				)
			positions.append(at)


func test_routes_go_around_buildings_not_through_them() -> void:
	var obstacles: Array[Rect2] = []
	for id in BusinessData.ids():
		obstacles.append(ForecourtLayout.building_rect(id))
		obstacles.append_array(ForecourtLayout.prop_rects(id, BusinessData.max_bays(id)))
	for kind in ["car", "camper", "monster"]:
		var size := VehicleMesh.footprint(kind)
		for id in BusinessData.ids():
			for slot in BusinessData.max_bays(id):
				for route in [
					ForecourtLayout.inbound(id, slot),
					ForecourtLayout.reverse_out(id, slot),
					ForecourtLayout.exit_approach(id, slot),
					ForecourtLayout.outbound(id, slot),
					ForecourtLayout.highway_merge()
				]:
					check(
						_clear_route(route, size, obstacles),
						"%s route for %s bay %d clears every solid object" % [kind, id, slot]
					)


func _clear_route(route: Array[Vector3], size: Vector2, obstacles: Array[Rect2]) -> bool:
	for i in range(route.size() - 1):
		var direction := route[i + 1] - route[i]
		var yaw := atan2(direction.x, direction.z)
		# Sample the long straight segments too, not only their end points.
		var samples := maxi(1, ceili(direction.length() / 0.20))
		for step in samples + 1:
			var at := DrivingRules.xz(route[i].lerp(route[i + 1], float(step) / float(samples)))
			for rect in obstacles:
				if DrivingRules.overlaps(at, size, yaw, rect.get_center(), rect.size, 0.0, 0.015):
					return false
	return true


func test_capacity_upgrades_do_not_move_existing_cars() -> void:
	for id in BusinessData.ids():
		var before := ForecourtLayout.bay_position(id, 0)
		var business := BusinessState.new(id, true)
		business.capacity_level = business.max_branch_for("capacity")
		equal(ForecourtLayout.bay_position(id, 0), before, "the first bay does not recenter after an upgrade")
		check(business.active_bays() > 1, "upgrade unlocks additional physical bays")


func test_braking_and_collision_layers() -> void:
	almost(DrivingRules.stopping_speed(0.1, 5.0), 0.0, "bumper gap forces a complete stop")
	check(DrivingRules.stopping_speed(1.0, 5.0) < 5.0, "short gap slows the car")
	almost(DrivingRules.stopping_speed(20.0, 5.0), 5.0, "clear road permits cruise speed")
	check(DrivingRules.approach_speed(0, 5, 0.1) < 1.0, "acceleration is gradual")
	var car := VehicleBody.new()
	car.setup("truck", Color.WHITE)
	equal(car.collision_layer, 2, "cars are on the traffic layer")
	equal(car.collision_mask, 6, "cars hit both scenery and other cars, not UI tap boxes")
	check(car.dimensions.y > 2.5, "long vehicles get a full-length collider")
	car.free()


func test_bevels_are_real_cached_geometry() -> void:
	var size := Vector3(2, 1, 3)
	var first := StylizedMesh.box(size)
	check(first == StylizedMesh.box(size), "identical bevel meshes are shared")
	equal(first.get_surface_count(), 1, "one material surface per chamfered mesh")
	check(first.get_aabb().size.is_equal_approx(size), "bevels retain the requested dimensions")
