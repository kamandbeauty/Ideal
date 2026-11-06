extends RefCounted
## Exercises every remaining mission through the real scene, physics, AI and weapon.
func run(t: TestContext) -> void:
	Engine.time_scale = 5.0
	for id in ["sr02", "sr03", "sr04", "sr05"]:
		var mission: MissionData = load("res://resources/missions/%s.tres" % id)
		var battle: BattleController = load("res://scenes/battlefield/battle.tscn").instantiate()
		battle.mission = mission
		battle.active_on_ready = true
		t.tree.root.add_child(battle)
		await t.tree.physics_frame
		for target_id in mission.target_ids:
			var target: EnemyTarget
			for candidate in battle.battlefield.targets:
				if candidate.target_id == target_id:
					target = candidate
			var attempts: int = 0
			while is_instance_valid(target) and not target.health.is_destroyed and attempts < 8 and battle.active:
				battle.select_target(target_id)
				var preferred: String = "ap" if target.data.kind == "tank" else "he"
				if int(battle.loadout.counts.get(preferred, 0)) <= 0:
					preferred = "he" if preferred == "ap" else "ap"
				battle.select_ammunition(preferred)
				var ready_frames: int = 0
				while not battle.artillery.can_fire() and battle.active and ready_frames < 900:
					if battle.artillery.reload_remaining <= 0.0:
						battle.reload()
					await t.tree.physics_frame
					ready_frames += 1
				if not battle.active or not battle.artillery.can_fire():
					break
				t.check(battle.compute_solution(), "%s fire-control solves %s" % [id, target_id])
				t.check(battle.fire(), "%s fires at %s" % [id, target_id])
				var frames: int = 0
				while battle.projectiles.active_count() > 0 and frames < 600:
					await t.tree.physics_frame
					frames += 1
				while not battle.artillery.can_fire() and battle.active and frames < 900:
					await t.tree.physics_frame
					frames += 1
				attempts += 1
			t.check(is_instance_valid(target) and target.health.is_destroyed, "%s neutralizes required target %s" % [id, target_id])
		var wait: int = 0
		while battle.missions.active and wait < 180:
			await t.tree.physics_frame
			wait += 1
		t.check(battle.missions.result.get("success", false), "%s reaches a successful result" % id)
		t.equal(battle.missions.destroyed_ids.size(), mission.target_ids.size(), "%s completes every primary objective" % id)
		var supply: int = int(mission.ammunition.get("he", 0)) + int(mission.ammunition.get("ap", 0))
		t.check(battle.missions.shots > 0 and battle.missions.shots <= supply, "%s stays within its authored ammunition supply" % id)
		t.check(battle.projectiles.active_count() == 0, "%s returns all projectiles to the pool" % id)
		battle.free()
		await t.tree.physics_frame
	Engine.time_scale = 1.0
