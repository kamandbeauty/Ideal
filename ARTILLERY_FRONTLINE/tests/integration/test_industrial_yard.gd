extends RefCounted
## The factory scene must preserve the proven city combat contract and support
## real wave completion and a real undefended gate breach.

func run(t: TestContext) -> void:
	var city: LevelLayout = load("res://resources/levels/city_siege_layout.tres")
	for stage: int in range(9, 12):
		var level: CityLevel = t.make_level(stage)
		await t.frames(2)
		t.check(Campaign.scene(stage).ends_with("industrial_siege.tscn"), "factory stage loads its dedicated scene")
		t.equal(level.layout.mount_position, city.mount_position, "the player mount is unchanged")
		t.equal(level.layout.eye_position, city.eye_position, "the camera eye is unchanged")
		t.equal(level.layout.routes, city.routes, "the established attack routes and widths are unchanged")
		t.equal(level.layout.attack_lines, city.attack_lines, "the defense attack slots are unchanged")
		t.equal(level.layout.breach_routes, city.breach_routes, "breach routes are unchanged")
		t.equal(level.layout.gate_center, city.gate_center, "the gate remains in place")
		t.equal(level.layout.patch_center, city.patch_center, "the wall patch remains in place")
		t.equal(level.director.wave_count(), 3, "the factory stage has three waves")
		t.equal(level.defense.wall_health, 1000.0, "the wall starts at full health")
		t.equal(level.defense.gate_health, 700.0, "the gate starts at full health")
		t.check(level.geometry.get_node_or_null("IndustrialGround") != null and level.geometry.get_node_or_null("IndustrialPlatform") != null, "factory ground and gunner platform exist")
		for batch_name: String in ["FactorySteel", "FactoryCaution", "FactoryDarkPanels"]:
			var batch: MultiMeshInstance3D = level.geometry.get_node_or_null(batch_name) as MultiMeshInstance3D
			t.check(batch != null and batch.multimesh.instance_count > 0, "yard details are batched: " + batch_name)
			if batch:
				t.check(batch.find_children("*", "CollisionObject3D", true, false).is_empty(), "yard details have no collision")
		# Rays follow each route center and both outer offsets at waist height.
		# They detect new WORLD collision, not transparent decorative meshes.
		var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
		for route: String in level.layout.route_names():
			for lateral: float in [-1.0, 0.0, 1.0]:
				var path: PackedVector3Array = level.layout.path_for(route, lateral, "left" if route.ends_with("left") else "right")
				for i: int in range(1, path.size()):
					var query := PhysicsRayQueryParameters3D.create(path[i - 1] + Vector3.UP, path[i] + Vector3.UP, Layers.WORLD)
					t.check(space.intersect_ray(query).is_empty(), "route %s offset %.1f segment %d is clear" % [route, lateral, i])
		level.horde.rng.seed = 500 + stage
		level.director.rng.seed = 600 + stage
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
		t.check(level.over and not level.defense.breached, "the real director can complete the factory stage")
		t.equal(started, [0, 1, 2], "the factory waves start in order")
		t.equal(level.horde.spawned_total, level.wave_set.total_zombies(), "all scheduled attackers spawn")
		t.equal(level.stats.waves_cleared, 3, "all three waves are recorded")
		t.equal(level.stats.bosses, 1 if stage == 11 else 0, "the director counts the boss only on the last industrial stage")
		Events.wave_started.disconnect(on_wave)
		await t.discard(level)
	# Isolate a real gate assault: unmodified waves can destroy the wall first,
	# so that scenario alone cannot prove behavior after the gate falls.
	var undefended: CityLevel = t.make_level(9)
	await t.frames(2)
	undefended.horde.rng.seed = 722
	undefended.begin_match()
	undefended.director.stop()
	for index: int in 10:
		undefended.horde.spawn(&"brute" if index < 4 else &"walker", "ring_right", "gate")
	var elapsed: float = 0.0
	while undefended.horde.entered_total == 0 and not undefended.over and elapsed < 700.0:
		t.simulate(undefended, 1.0)
		elapsed += 1.0
	t.check(undefended.defense.gate_destroyed, "an undefended factory gate falls under a real attack")
	t.check(undefended.horde.entered_total > 0, "attackers enter through the fallen factory gate")
	t.check(undefended.defense.wall_health < undefended.defense.data.wall_max_health, "the factory wall takes damage after entry")
	await t.discard(undefended)
