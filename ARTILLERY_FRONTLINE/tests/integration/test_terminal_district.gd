extends RefCounted
## A dedicated terminal scene without changing the proven combat contract.

func run(t: TestContext) -> void:
	var city: LevelLayout = load("res://resources/levels/city_siege_layout.tres")
	for stage: int in range(15, 18):
		var level: CityLevel = t.make_level(stage)
		await t.frames(2)
		t.check(Campaign.scene(stage).ends_with("terminal_siege.tscn"), "terminal stage uses its own scene")
		t.equal(level.layout.routes, city.routes, "routes and widths remain unchanged")
		t.equal(level.layout.attack_lines, city.attack_lines, "attack slots remain unchanged")
		t.equal(level.layout.breach_routes, city.breach_routes, "breach routes remain unchanged")
		t.equal(level.layout.mount_position, city.mount_position, "mount remains unchanged")
		t.equal(level.layout.eye_position, city.eye_position, "eye remains unchanged")
		t.equal(level.layout.gate_center, city.gate_center, "gate remains unchanged")
		t.equal(level.layout.patch_center, city.patch_center, "patch remains unchanged")
		t.equal(level.director.wave_count(), 3, "terminal stages have three waves")
		t.equal(level.defense.wall_health, 1000.0, "wall starts at full health")
		t.equal(level.defense.gate_health, 700.0, "gate starts at full health")
		t.check(level.geometry.get_node_or_null("TerminalGround") != null and level.geometry.get_node_or_null("TerminalPlatform") != null, "road and defender platform exist")
		t.check(level.geometry.get_node_or_null("TerminalHallSign") is Label3D, "station sign exists")
		for batch_name: String in ["TerminalCladding", "TerminalFrame", "TerminalGlass", "TerminalSigns", "TerminalRoadMarks", "TerminalLights", "TerminalDetailFrames", "TerminalPosterBackings", "TerminalPosters", "TerminalHighlights", "TerminalSurfaceWear"]:
			var batch: MultiMeshInstance3D = level.geometry.get_node_or_null(batch_name) as MultiMeshInstance3D
			t.check(batch != null and batch.multimesh.instance_count > 0, "terminal detail is batched: " + batch_name)
			if batch:
				t.check(batch.find_children("*", "CollisionObject3D", true, false).is_empty(), "terminal detail does not collide")
		var ground: MeshInstance3D = level.geometry.get_node_or_null("TerminalGround") as MeshInstance3D
		var cladding: MultiMeshInstance3D = level.geometry.get_node_or_null("TerminalCladding") as MultiMeshInstance3D
		if ground and cladding:
			var ground_mat: StandardMaterial3D = ground.material_override as StandardMaterial3D
			var facade_mat: StandardMaterial3D = cladding.multimesh.mesh.material as StandardMaterial3D
			t.check(ground_mat != null and ground_mat.albedo_texture != null and ground_mat.albedo_texture.resource_path.ends_with("terminal_asphalt.jpg"), "district asphalt is loaded")
			t.check(facade_mat != null and facade_mat.albedo_texture != null and facade_mat.albedo_texture.resource_path.ends_with("terminal_panel.jpg"), "district cladding is loaded")
		var glass: MultiMeshInstance3D = level.geometry.get_node_or_null("TerminalGlass") as MultiMeshInstance3D
		var posters: MultiMeshInstance3D = level.geometry.get_node_or_null("TerminalPosters") as MultiMeshInstance3D
		if glass and posters:
			var glass_mat: StandardMaterial3D = glass.multimesh.mesh.material as StandardMaterial3D
			var poster_mat: StandardMaterial3D = posters.multimesh.mesh.material as StandardMaterial3D
			t.check(glass_mat != null and glass_mat.albedo_texture != null and glass_mat.albedo_texture.resource_path.ends_with("terminal_glass.jpg"), "station uses weathered glass")
			t.check(poster_mat != null and poster_mat.albedo_texture != null and poster_mat.albedo_texture.resource_path.ends_with("terminal_poster.jpg"), "travel posters use their own artwork")
		t.check(level.geometry.get_node_or_null("TerminalHallSubtitle") is Label3D, "the station has bilingual signage")
		var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
		# Platform furniture has a conservative radius that contains its canopy.
		for side: float in [-1.0, 1.0]:
			var shelter := Vector2(side * 28.5, -105.0)
			for route: String in level.layout.route_names():
				var points: PackedVector3Array = level.layout.routes[route].points
				var widths: PackedFloat32Array = level.layout.routes[route].widths
				for i: int in range(1, points.size()):
					var a := Vector2(points[i - 1].x, points[i - 1].z)
					var b := Vector2(points[i].x, points[i].z)
					var closest: Vector2 = Geometry2D.get_closest_point_to_segment(shelter, a, b)
					t.check(shelter.distance_to(closest) > 4.0 + maxf(widths[i - 1], widths[i]), "waiting shelter stays outside the route envelope")
		for bus_name: String in ["WestBus", "EastBus"]:
			var bus: Node3D = level.geometry.get_node_or_null(bus_name) as Node3D
			t.check(bus != null, "terminal bus exists: " + bus_name)
			if bus:
				var batches: Array[Node] = bus.find_children("*", "MultiMeshInstance3D", true, false)
				t.equal(batches.size(), 6, "bus has six bounded material batches")
				t.check(bus.find_children("*", "CollisionObject3D", true, false).is_empty(), "bus has no collision")
				for batch: Node in batches:
					t.check((batch as MultiMeshInstance3D).multimesh.instance_count > 0, "bus batch is populated")
				var bus_body: MultiMeshInstance3D = bus.get_node_or_null("BusBody") as MultiMeshInstance3D
				if bus_body:
					var body_mat: StandardMaterial3D = bus_body.multimesh.mesh.material as StandardMaterial3D
					t.check(body_mat != null and body_mat.albedo_texture != null and body_mat.albedo_texture.resource_path.ends_with("terminal_faded_paint.jpg"), "bus body uses weathered paint")
				var center := Vector2(bus.position.x, bus.position.z)
				for route: String in level.layout.route_names():
					var points: PackedVector3Array = level.layout.routes[route].points
					var widths: PackedFloat32Array = level.layout.routes[route].widths
					for i: int in range(1, points.size()):
						var a := Vector2(points[i - 1].x, points[i - 1].z)
						var b := Vector2(points[i].x, points[i].z)
						var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, a, b)
						t.check(center.distance_to(closest) > 5.2 + maxf(widths[i - 1], widths[i]), "bus is outside the route envelope")
				for point: Vector3 in [bus.position + Vector3(0, 2.75, 3.95), bus.position + Vector3(0, 3.6, 1.0)]:
					var sight := PhysicsRayQueryParameters3D.create(level.layout.eye_position, point, Layers.WORLD)
					t.check(space.intersect_ray(sight).is_empty(), "near defenses do not hide the bus from the player")
		for route: String in level.layout.route_names():
			for lateral: float in [-1.0, 0.0, 1.0]:
				var path: PackedVector3Array = level.layout.path_for(route, lateral, "left" if route.ends_with("left") else "right")
				for i: int in range(1, path.size()):
					var query := PhysicsRayQueryParameters3D.create(path[i - 1] + Vector3.UP, path[i] + Vector3.UP, Layers.WORLD)
					t.check(space.intersect_ray(query).is_empty(), "route %s offset %.1f segment %d is clear" % [route, lateral, i])
		for wave: WaveData in level.wave_set.waves:
			for group: SpawnGroup in wave.groups:
				t.check(level.horde.has_type(group.zombie), "terminal can spawn every planned type")
				for route: String in group.routes:
					t.check(level.layout.has_route(route), "planned route exists")
		level.horde.rng.seed = 1600 + stage
		level.director.rng.seed = 1700 + stage
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
		t.check(level.over and not level.defense.breached, "real director can finish the terminal stage")
		t.equal(started, [0, 1, 2], "waves start in order")
		t.equal(level.horde.spawned_total, level.wave_set.total_zombies(), "all scheduled attackers spawn")
		t.equal(level.stats.waves_cleared, 3, "three waves are recorded")
		Events.wave_started.disconnect(on_wave)
		await t.discard(level)
	# A real attack against the unchanged destructible gate and breach path.
	var undefended: CityLevel = t.make_level(15)
	await t.frames(2)
	undefended.horde.rng.seed = 1722
	undefended.begin_match()
	undefended.director.stop()
	for index: int in 10:
		undefended.horde.spawn(&"brute" if index < 4 else &"walker", "ring_right", "gate")
	var elapsed: float = 0.0
	while undefended.horde.entered_total == 0 and not undefended.over and elapsed < 700.0:
		t.simulate(undefended, 1.0)
		elapsed += 1.0
	t.check(undefended.defense.gate_destroyed, "undefended terminal gate can be destroyed")
	t.check(undefended.horde.entered_total > 0, "attackers enter through the destroyed gate")
	t.check(undefended.defense.wall_health < undefended.defense.data.wall_max_health, "wall takes damage after entry")
	await t.discard(undefended)
