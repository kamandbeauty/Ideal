extends RefCounted
## The apartment district uses the established route and combat contract.

func run(t: TestContext) -> void:
	var city: LevelLayout = load("res://resources/levels/city_siege_layout.tres")
	for stage: int in range(18, 21):
		var level: CityLevel = t.make_level(stage)
		await t.frames(2)
		t.check(Campaign.scene(stage).ends_with("residential_siege.tscn"), "residential stage selects its scene")
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
		t.check(level.geometry.get_node_or_null("ResidentialGround") != null and level.geometry.get_node_or_null("ResidentialPlatform") != null, "residential ground and platform load")
		t.check(level.geometry.get_node_or_null("DistrictLandmarks6") != null, "residential towers are present")
		for batch_name: String in ["ResidentialFacades", "ResidentialWindows", "ResidentialTrim", "ResidentialBalconies", "ResidentialAccents", "ResidentialTrunks", "ResidentialFoliage", "ResidentialCarA", "ResidentialCarB", "ResidentialCarGlass", "ResidentialCarTires"]:
			var batch: MultiMeshInstance3D = level.geometry.get_node_or_null(batch_name) as MultiMeshInstance3D
			t.check(batch != null and batch.multimesh.instance_count > 0, "populated batched detail: " + batch_name)
			if batch:
				t.check(batch.find_children("*", "CollisionObject3D", true, false).is_empty(), "decoration has no collision")
		var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
		# The cars and trees remain clear of every route, including its width.
		for prop: Array in [[Vector3(-20, 0, -69), 4.3], [Vector3(20, 0, -69), 4.3], [Vector3(-29, 0, -105), 3.0], [Vector3(29, 0, -105), 3.0]]:
			var p: Vector3 = prop[0]
			var center := Vector2(p.x, p.z)
			for route: String in level.layout.route_names():
				var points: PackedVector3Array = level.layout.routes[route].points
				var widths: PackedFloat32Array = level.layout.routes[route].widths
				for i: int in range(1, points.size()):
					var a := Vector2(points[i - 1].x, points[i - 1].z)
					var b := Vector2(points[i].x, points[i].z)
					var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, a, b)
					t.check(center.distance_to(closest) > float(prop[1]) + maxf(widths[i - 1], widths[i]), "props stay outside lane envelope")
		for route: String in level.layout.route_names():
			for lateral: float in [-1.0, 0.0, 1.0]:
				var path: PackedVector3Array = level.layout.path_for(route, lateral, "left" if route.ends_with("left") else "right")
				for i: int in range(1, path.size()):
					var query := PhysicsRayQueryParameters3D.create(path[i - 1] + Vector3.UP, path[i] + Vector3.UP, Layers.WORLD)
					t.check(space.intersect_ray(query).is_empty(), "route segment remains clear")
		for wave: WaveData in level.wave_set.waves:
			for group: SpawnGroup in wave.groups:
				t.check(level.horde.has_type(group.zombie), "every wave type is available")
				for route: String in group.routes:
					t.check(level.layout.has_route(route), "wave route is available")
		level.horde.rng.seed = 1900 + stage
		level.director.rng.seed = 2000 + stage
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
		t.equal(level.stats.waves_cleared, 3, "all three waves are recorded")
		Events.wave_started.disconnect(on_wave)
		await t.discard(level)
	var undefended: CityLevel = t.make_level(18)
	await t.frames(2)
	undefended.horde.rng.seed = 1919
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
