extends RefCounted
## A dedicated stadium while preserving city routes and defense rules.

func run(t: TestContext) -> void:
	var city: LevelLayout = load("res://resources/levels/city_siege_layout.tres")
	for stage: int in range(21, 24):
		var level: CityLevel = t.make_level(stage)
		await t.frames(2)
		t.check(Campaign.scene(stage).ends_with("stadium_siege.tscn"), "stadium stage selects its own scene")
		t.equal(level.layout.routes, city.routes, "route geometry and widths remain unchanged")
		t.equal(level.layout.attack_lines, city.attack_lines, "attack positions remain unchanged")
		t.equal(level.layout.breach_routes, city.breach_routes, "breach routes remain unchanged")
		t.equal(level.layout.mount_position, city.mount_position, "mount remains unchanged")
		t.equal(level.layout.eye_position, city.eye_position, "eye remains unchanged")
		t.equal(level.layout.gate_center, city.gate_center, "gate remains unchanged")
		t.equal(level.layout.patch_center, city.patch_center, "wall patch remains unchanged")
		t.equal(level.defense.wall_health, 1000.0, "wall starts intact")
		t.equal(level.defense.gate_health, 700.0, "gate starts intact")
		t.equal(level.director.wave_count(), 3, "three original waves")
		var ground: MeshInstance3D = level.geometry.get_node_or_null("StadiumGround") as MeshInstance3D
		t.check(ground != null and level.geometry.get_node_or_null("StadiumPlatform") != null, "stadium ground and platform load")
		if ground:
			var material: StandardMaterial3D = ground.material_override as StandardMaterial3D
			t.check(material != null and material.albedo_texture != null and material.albedo_texture.resource_path.ends_with("stadium_grass.jpg"), "stadium pitch uses its grass texture")
			if material and material.albedo_texture:
				t.check(material.albedo_texture.get_image().has_mipmaps(), "pitch texture contains mipmaps")
				t.equal(material.texture_filter, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "pitch uses mipmap filtering")
		t.check(level.geometry.get_node_or_null("DistrictLandmarks7") != null, "stadium floodlight skyline exists")
		t.check(level.geometry.get_node_or_null("StadiumCenterCircle") is MeshInstance3D, "pitch has a center circle")
		for batch_name: String in ["StadiumTerraces", "StadiumStructures", "StadiumBlueSeats", "StadiumRedSeats", "StadiumPitchLines", "StadiumGoal", "StadiumScoreboard", "StadiumFloodlights"]:
			var batch: MultiMeshInstance3D = level.geometry.get_node_or_null(batch_name) as MultiMeshInstance3D
			t.check(batch != null and batch.multimesh.instance_count > 0, "populated batched stadium detail: " + batch_name)
			if batch:
				t.check(batch.find_children("*", "CollisionObject3D", true, false).is_empty(), "decoration has no collision")
		var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
		for route: String in level.layout.route_names():
			var points: PackedVector3Array = level.layout.routes[route].points
			var widths: PackedFloat32Array = level.layout.routes[route].widths
			# The physical route ray and a conservative visual envelope catch both
			# hidden colliders and decorative seating crossing a lane.
			for lateral: float in [-1.0, 0.0, 1.0]:
				var path: PackedVector3Array = level.layout.path_for(route, lateral, "left" if route.ends_with("left") else "right")
				for i: int in range(1, path.size()):
					var query := PhysicsRayQueryParameters3D.create(path[i - 1] + Vector3.UP, path[i] + Vector3.UP, Layers.WORLD)
					t.check(space.intersect_ray(query).is_empty(), "route segment remains free of obstacles")
			for i: int in range(1, points.size()):
				var a := Vector2(points[i - 1].x, points[i - 1].z)
				var b := Vector2(points[i].x, points[i].z)
				var margin: float = maxf(widths[i - 1], widths[i])
				for side: int in [-1, 1]:
					var box := Rect2(-51.25 if side < 0 else 38.75, -135, 12.5, 54).grow(margin)
					t.check(not _segment_intersects_rect(a, b, box), "terraces stay outside expanded route")
				for fire: Dictionary in level.layout.fires:
					var p: Vector3 = fire.position
					var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b)
					t.check(Vector2(p.x, p.z).distance_to(nearest) > margin + 2.0, "stadium fire is outside lane")
		for wave: WaveData in level.wave_set.waves:
			for group: SpawnGroup in wave.groups:
				t.check(level.horde.has_type(group.zombie), "every wave type is available")
				for route: String in group.routes:
					t.check(level.layout.has_route(route), "wave route is available")
		level.horde.rng.seed = 2200 + stage
		level.director.rng.seed = 2300 + stage
		var started: Array[int] = []
		var on_wave := func(index: int, _total: int) -> void: started.append(index)
		Events.wave_started.connect(on_wave)
		level.begin_match()
		var elapsed: float = 0.0
		while not level.over and elapsed < 900.0:
			t.simulate(level, 1.0)
			elapsed += 1.0
			for zombie: Zombie in level.horde.active.duplicate():
				if zombie.alive:
					zombie.kill()
		t.check(level.over and not level.defense.breached, "director completes the stage")
		t.equal(started, [0, 1, 2], "three waves start in order")
		t.equal(level.horde.spawned_total, level.wave_set.total_zombies(), "all scheduled enemies spawn")
		t.equal(level.stats.waves_cleared, 3, "three waves are recorded")
		Events.wave_started.disconnect(on_wave)
		await t.discard(level)
	var undefended: CityLevel = t.make_level(21)
	await t.frames(2)
	undefended.horde.rng.seed = 2222
	undefended.begin_match()
	undefended.director.stop()
	for index: int in 10:
		undefended.horde.spawn(&"brute" if index < 4 else &"walker", "ring_right", "gate")
	var elapsed: float = 0.0
	while undefended.horde.entered_total == 0 and not undefended.over and elapsed < 700.0:
		t.simulate(undefended, 1.0)
		elapsed += 1.0
	t.check(undefended.defense.gate_destroyed, "undefended gate can be destroyed")
	t.check(undefended.horde.entered_total > 0, "attackers enter through destroyed gate")
	await t.discard(undefended)


func _segment_intersects_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var tl: Vector2 = rect.position
	var br: Vector2 = rect.end
	var tr := Vector2(br.x, tl.y)
	var bl := Vector2(tl.x, br.y)
	for edge: Array in [[tl, tr], [tr, br], [br, bl], [bl, tl]]:
		if Geometry2D.segment_intersects_segment(a, b, edge[0], edge[1]) != null:
			return true
	return false
