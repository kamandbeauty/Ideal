extends TestCase
## The map data: path, pads and core must agree with each other.


func _distance_to_path(point: Vector3) -> float:
	var best := INF
	for i in LevelData.PATH.size() - 1:
		var closest := Geometry3D.get_closest_point_to_segment(
			point, LevelData.PATH[i], LevelData.PATH[i + 1]
		)
		best = minf(best, Vector2(point.x - closest.x, point.z - closest.z).length())
	return best


func test_path_is_a_usable_route() -> void:
	check(LevelData.PATH.size() >= 3, "the path has corners")
	equal(LevelData.PATH[0], LevelData.SPAWN_POSITION, "the path starts at the portal")
	equal(LevelData.PATH[LevelData.PATH.size() - 1], LevelData.CORE_POSITION, "the path ends at the core")
	for i in LevelData.PATH.size() - 1:
		var step := LevelData.PATH[i + 1] - LevelData.PATH[i]
		check(Vector2(step.x, step.z).length() > 1.0, "segment %d has length" % i)
	var route := LevelData.route()
	equal(route.size(), LevelData.PATH.size(), "route() copies the path")


func test_pads_are_on_the_ground_and_inside_the_island() -> void:
	check(LevelData.PADS.size() >= 4, "there are enough build pads")
	var limit := LevelData.GROUND_SIZE * 0.5 - LevelData.PAD_RADIUS
	for pad in LevelData.PADS:
		almost(pad.y, 0.0, "pads sit on the ground")
		check(absf(pad.x) < limit, "pad x inside the island")
		check(absf(pad.z) < limit, "pad z inside the island")


func test_pads_do_not_block_the_path() -> void:
	var clearance := LevelData.PAD_RADIUS + LevelData.PATH_WIDTH * 0.5
	for pad in LevelData.PADS:
		var distance := _distance_to_path(pad)
		check(distance > clearance, "pad at %s leaves the path clear (%.2f)" % [str(pad), distance])


func test_pads_are_not_stacked() -> void:
	for i in LevelData.PADS.size():
		for j in range(i + 1, LevelData.PADS.size()):
			var distance := Vector2(
				LevelData.PADS[i].x - LevelData.PADS[j].x, LevelData.PADS[i].z - LevelData.PADS[j].z
			).length()
			check(distance > LevelData.PAD_RADIUS * 2.0, "pads %d and %d do not overlap" % [i, j])


func test_pads_are_in_range_of_the_path() -> void:
	var useful := 0
	for pad in LevelData.PADS:
		if _distance_to_path(pad) <= TowerData.range_for("sentry", 1):
			useful += 1
	check(useful >= LevelData.PADS.size() - 1, "almost every pad can shoot the path")
