extends RefCounted
## The level's gameplay geometry: routes, mouths, attack places, aim reach.


func run(t: TestContext) -> void:
	var layout: LevelLayout = load("res://resources/levels/city_siege_layout.tres")
	t.check(layout != null, "city_siege_layout.tres loads as LevelLayout")
	var aim: AimSettings = load("res://resources/aim/default_aim.tres")
	t.check(layout.routes.size() >= 6, "the level has at least six routes (got %d)" % layout.routes.size())
	t.check(layout.mouths.has("left") and layout.mouths.has("right"), "both court mouths exist")
	t.check(layout.breach_routes.has("gate") and layout.breach_routes.has("wall"), "breach routes exist for the gate and the wall")

	var lefts: int = 0
	var rights: int = 0
	for route: String in layout.route_names():
		var points: PackedVector3Array = layout.routes[route].points
		var widths: PackedFloat32Array = layout.routes[route].widths
		t.check(points.size() >= 3, "route %s has at least three waypoints" % route)
		t.equal(widths.size(), points.size(), "route %s has one width per waypoint" % route)
		var flat: bool = true
		var positive: bool = true
		for index: int in points.size():
			if absf(points[index].y) > 0.001:
				flat = false
			if widths[index] <= 0.0:
				positive = false
		t.check(flat and positive, "route %s is on the ground with positive widths" % route)
		# The spawn is outside the court and farther from the gun than the court mouth.
		t.check(points[0].z < -50.0, "route %s spawns beyond the court" % route)
		t.check(points[0].length() > points[points.size() - 1].length(), "route %s walks toward the wall" % route)
		t.check(layout.route_length(route, "right") > 20.0, "route %s is a real walk" % route)
		if route.ends_with("left"):
			lefts += 1
		elif route.ends_with("right"):
			rights += 1
	t.check(lefts >= 3 and lefts == rights, "routes come in left/right pairs")

	# Lateral offsets stay inside the lane and end at the chosen mouth.
	var centre: PackedVector3Array = layout.path_for("avenue_left", 0.0, "right")
	var edge: PackedVector3Array = layout.path_for("avenue_left", 1.0, "right")
	t.equal(centre.size(), layout.routes.avenue_left.points.size() + 1, "a path is the route plus the court mouth")
	var inside: bool = true
	for index: int in layout.routes.avenue_left.points.size():
		var shift: float = centre[index].distance_to(edge[index])
		if shift > layout.routes.avenue_left.widths[index] + 0.001 or shift < 0.01:
			inside = false
	t.check(inside, "a full lateral offset moves each waypoint by its half-width")
	t.check(centre[centre.size() - 1].x > 0.0, "the right mouth is on the right")
	t.check(layout.path_for("avenue_left", 0.0, "left")[centre.size() - 1].x < 0.0, "the left mouth is on the left")
	t.check(layout.path_for("no_such_route", 0.0, "left").is_empty(), "an unknown route gives an empty path")
	var mouth_gap: float = (layout.mouths.right.position as Vector3).x - float(layout.mouths.right.width)
	t.check(mouth_gap >= 3.0, "the walking lanes leave the middle of the court free for wrecks")

	# Every standing place can be hit with the shipped aim limits.
	var eye: Vector3 = layout.eye_position
	var lines := AttackLines.new()
	lines.setup(layout)
	var worst_pitch: float = 0.0
	var worst_yaw: float = 0.0
	var nearest: float = INF
	for line_name: String in lines.lines:
		for slot: AttackLines.Slot in lines.lines[line_name].slots:
			var chest: Vector3 = slot.position + Vector3(0.0, 1.2, 0.0) - eye
			var yaw: float = rad_to_deg(atan2(chest.x, -chest.z))
			var pitch: float = rad_to_deg(atan2(chest.y, Vector2(chest.x, chest.z).length()))
			worst_pitch = minf(worst_pitch, pitch)
			worst_yaw = maxf(worst_yaw, absf(yaw))
			nearest = minf(nearest, Vector2(chest.x, chest.z).length())
	t.check(worst_pitch >= aim.pitch_min_degrees, "every attacker's chest is within the depression limit (worst %.1f°)" % worst_pitch)
	t.check(worst_yaw <= aim.yaw_max_degrees, "every attack place is within the yaw limit (worst %.1f°)" % worst_yaw)
	t.check(nearest >= 17.0, "no attack place sits in the dead ground under the gun (nearest %.1f m)" % nearest)
	print("    aim reach: worst pitch %.1f°, worst yaw %.1f°, nearest slot %.1f m" % [worst_pitch, worst_yaw, nearest])

	# Gate and patch volumes.
	t.check(layout.gate_size.y > 3.0 and layout.gate_size.z > 5.0, "the gate plate covers the gate opening")
	t.check(layout.gate_center.x > 10.0 and layout.patch_center.x < -10.0, "the gate is on the right arm and the patch on the left")
	t.check(layout.mount_position.y > 3.0, "the gun stands on top of the wall")
	t.near(eye.y - layout.mount_position.y, 1.58, 0.1, "the eye is at standing height behind the gun")
	t.check(layout.fires.size() >= 3 and layout.smokes.size() >= 3 and layout.lamps.size() >= 2, "effect anchors are present")
	var through: PackedVector3Array = layout.breach_path("gate", 0.0)
	t.check(through.size() == 2 and through[1].x > layout.gate_center.x + 2.0, "the gate breach route ends inside the city")
