extends RefCounted
## Dedicated scenery must retain the city's routes, defenses and playable waves.

const BAZAAR_GEOMETRY = preload("res://scripts/environment/bazaar_geometry.gd")

func run(t: TestContext) -> void:
	var city: LevelLayout = load("res://resources/levels/city_siege_layout.tres")
	for stage: int in range(12, 15):
		var level: CityLevel = t.make_level(stage)
		await t.frames(2)
		t.check(Campaign.scene(stage).ends_with("bazaar_siege.tscn"), "bazaar stage uses its own scene")
		t.equal(level.layout.routes, city.routes, "routes and widths remain unchanged")
		t.equal(level.layout.attack_lines, city.attack_lines, "attack lines remain unchanged")
		t.equal(level.layout.breach_routes, city.breach_routes, "breach routes remain unchanged")
		t.equal(level.layout.mount_position, city.mount_position, "mount remains unchanged")
		t.equal(level.layout.eye_position, city.eye_position, "eye remains unchanged")
		t.equal(level.layout.gate_center, city.gate_center, "gate remains unchanged")
		t.equal(level.layout.patch_center, city.patch_center, "patch remains unchanged")
		t.equal(level.director.wave_count(), 3, "three waves")
		t.check(level.geometry.get_node_or_null("BazaarGround") != null and level.geometry.get_node_or_null("BazaarPlatform") != null, "market ground and defender platform exist")
		for batch_name: String in ["BazaarMasonry", "BazaarOpenings", "BazaarTile", "BazaarAwnings", "BazaarWood", "BazaarMosaic", "BazaarRugs", "BazaarCanvas", "BazaarLanterns", "BazaarPottery", "BazaarProduce", "BazaarArchRecesses"]:
			var batch: MultiMeshInstance3D = level.geometry.get_node_or_null(batch_name) as MultiMeshInstance3D
			t.check(batch != null and batch.multimesh.instance_count > 0, "market detail is batched: " + batch_name)
			if batch:
				t.check(batch.find_children("*", "CollisionObject3D", true, false).is_empty(), "market details have no collision")
		var ground: MeshInstance3D = level.geometry.get_node_or_null("BazaarGround") as MeshInstance3D
		if ground:
			var mat: StandardMaterial3D = ground.material_override as StandardMaterial3D
			t.check(mat != null and mat.albedo_texture != null and mat.albedo_texture.resource_path.ends_with("bazaar_tiles.jpg"), "market uses its own paving texture")
		var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
		for stall: Vector3 in BAZAAR_GEOMETRY.MARKET_STALLS:
			var sight := PhysicsRayQueryParameters3D.create(level.layout.eye_position, stall + Vector3(0, 4.0, 1.6), Layers.WORLD)
			t.check(space.intersect_ray(sight).is_empty(), "stall awning is visible from the player")
			for route: String in level.layout.route_names():
				var points: PackedVector3Array = level.layout.routes[route].points
				var widths: PackedFloat32Array = level.layout.routes[route].widths
				for i: int in range(1, points.size()):
					var a := Vector2(points[i - 1].x, points[i - 1].z)
					var b := Vector2(points[i].x, points[i].z)
					var closest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(stall.x, stall.z), a, b)
					t.check(Vector2(stall.x, stall.z).distance_to(closest) > 3.8 + maxf(widths[i - 1], widths[i]), "market stall remains outside route envelope")
		for route: String in level.layout.route_names():
			for lateral: float in [-1.0, 0.0, 1.0]:
				var path: PackedVector3Array = level.layout.path_for(route, lateral, "left" if route.ends_with("left") else "right")
				for i: int in range(1, path.size()):
					var query := PhysicsRayQueryParameters3D.create(path[i - 1] + Vector3.UP, path[i] + Vector3.UP, Layers.WORLD)
					t.check(space.intersect_ray(query).is_empty(), "route %s offset %.1f segment %d is clear" % [route, lateral, i])
		level.horde.rng.seed = 1300 + stage
		level.director.rng.seed = 1400 + stage
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
		t.check(level.over and not level.defense.breached, "director completes the bazaar stage")
		t.equal(started, [0, 1, 2], "waves start in order")
		t.equal(level.horde.spawned_total, level.wave_set.total_zombies(), "all scheduled attackers spawn")
		t.equal(level.stats.waves_cleared, 3, "all waves are recorded")
		t.equal(level.stats.bosses, 1 if stage == 14 else 0, "only the last market stage counts the boss")
		Events.wave_started.disconnect(on_wave)
		await t.discard(level)
