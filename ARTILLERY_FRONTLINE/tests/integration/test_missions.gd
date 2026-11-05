extends RefCounted
func run(t: TestContext) -> void:
	var mission: MissionData = load("res://resources/missions/sr01.tres")
	var manager := MissionManager.new()
	t.tree.root.add_child(manager)
	manager.begin(mission)
	var shot: int = manager.register_shot()
	manager.register_damage("t01", shot, 50)
	manager.register_damage("t01", shot, 50)
	t.near(manager.accuracy(), 100, 0.001, "Multiple damage events count one accurate shell")
	manager.register_destroyed("t01")
	manager.tick(0.1)
	t.check(manager.active, "Mission waits for every primary objective")
	manager.register_destroyed("t03")
	manager.register_destroyed(mission.optional_crate_id)
	manager.tick(0.1)
	t.check(not manager.active and manager.result.success, "Mission completes on final objective")
	t.equal(manager.result.stars, 3, "Mission results include performance stars")
	t.check(manager.result.optional, "Optional objective integrated")
	manager.begin(mission)
	manager.check_ammunition(true, false, false)
	t.check(not manager.result.success, "Empty supply fails incomplete mission")
	manager.begin(mission)
	manager.tick(mission.time_limit + 1)
	t.check(not manager.result.success, "Time limit fails incomplete mission")
	manager.free()
	# Full scene integration: real terrain collision, aiming, shell flight and AI.
	Engine.time_scale = 5.0
	var battle: BattleController = load("res://scenes/battlefield/battle.tscn").instantiate()
	battle.mission = mission
	battle.active_on_ready = true
	t.tree.root.add_child(battle)
	var prediction_frames: int = 0
	while not battle.targeting.prediction_valid and prediction_frames < 60:
		await t.tree.physics_frame
		prediction_frames += 1
	t.check(battle.targeting.prediction_valid, "Trajectory preview finds real terrain collision")
	for id in mission.target_ids:
		var attempts: int = 0
		var target: EnemyTarget
		for candidate in battle.battlefield.targets:
			if candidate.target_id == id:
				target = candidate
		while not target.health.is_destroyed and attempts < 5 and battle.active:
			battle.select_target(id)
			t.check(battle.compute_solution(), "Scene fire-control produces a valid gun solution")
			t.check(battle.fire(), "Scene weapon fires supplied ammunition")
			var frames: int = 0
			while battle.projectiles.active_count() > 0 and frames < 240:
				await t.tree.physics_frame
				frames += 1
			while not battle.artillery.can_fire() and battle.active and frames < 360:
				await t.tree.physics_frame
				frames += 1
			attempts += 1
		t.check(target.health.is_destroyed, "Real ballistic mission neutralizes " + id)
	var wait: int = 0
	while battle.missions.active and wait < 120:
		await t.tree.physics_frame
		wait += 1
	t.check(battle.missions.result.get("success", false), "Complete battlefield mission reaches success result")
	t.check(battle.missions.shots >= 2 and battle.missions.accuracy() > 0, "Mission records actual shots and hits")
	t.check(battle.projectiles.active_count() == 0, "No leaked live projectiles at mission end")
	battle.free()
	Engine.time_scale = 1.0
