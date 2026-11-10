extends Node
## Software-rendered end-to-end smoke driver. Not Android/device certification.
var game: Node
var checks: Array[Dictionary] = []
var failures: int = 0
var output: String = "res://documentation/qa"
# Shots fired at each mission target, and every damage event, so a short run can be explained.
var engagements: Dictionary = {}
var damage_events: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("run")

func check(name: String, passed: bool) -> void:
	checks.append({"name": name, "passed": passed})
	if not passed:
		failures += 1
		push_error("SMOKE FAIL: " + name)

func capture(name: String) -> void:
	# Menus fade and step in; photograph the settled layout, not a mid-motion frame.
	if game.menus and game.menus.visible:
		game.menus.settle()
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png(output + "/" + name + ".png")
	check("capture " + name, error == OK and image.get_width() > 500)

func run() -> void:
	Engine.max_physics_steps_per_frame = 32
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Profile.data.settings.quality = "high"
	Graphics.apply_preference()
	# Photograph the Persian command interface before entering combat.
	await get_tree().create_timer(0.35).timeout
	await capture("menu-splash")
	game.menus.show_screen("main")
	await get_tree().create_timer(0.35).timeout
	await capture("menu-home")
	check("home screen active", game.menus.current == "main")
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	check("menu layer covers the full viewport", game.menu_root.get_global_rect().is_equal_approx(viewport_rect))
	check("home page covers the full viewport", game.menus.screens["main"].get_global_rect().is_equal_approx(viewport_rect))
	check("old battlefield is hidden behind menus", not game.world.visible)
	game.navigate("campaign")
	await get_tree().create_timer(0.25).timeout
	await capture("menu-campaign")
	game.menus.show_briefing("sr01")
	await get_tree().create_timer(0.25).timeout
	await capture("menu-briefing")
	game.navigate("arsenal")
	await get_tree().create_timer(0.25).timeout
	await capture("menu-arsenal")
	game.navigate("settings")
	await get_tree().create_timer(0.25).timeout
	await capture("menu-settings")
	game.menus.show_screen("upgrades")
	await get_tree().create_timer(0.25).timeout
	await capture("menu-upgrades")
	game.start_mission("sr01")
	await get_tree().create_timer(1.0).timeout
	var battle: BattleController = game.battle
	battle.combat.damage_dealt.connect(func(target_id: String, amount: float, direct: bool, shot_id: int) -> void:
		damage_events.append({"target": target_id, "amount": snappedf(amount, 0.1), "direct": direct, "shot": shot_id, "time": snappedf(battle.missions.elapsed, 0.1)}))
	check("battlefield initialized", battle.battlefield.targets.size() == 6)
	check("HUD visible", game.hud.visible)
	check("battlefield returns when menus close", game.world.visible and not game.menus.visible)
	check("artillery fire button is on the physical right", game.hud.fire_button.get_global_rect().get_center().x > viewport_rect.size.x * 0.5)
	game.pause_game()
	await get_tree().create_timer(0.25).timeout
	await capture("menu-pause")
	check("pause hides the old battlefield and HUD", not game.world.visible and not game.hud.visible)
	check("pause page covers the full viewport", game.menus.screens["pause"].get_global_rect().is_equal_approx(viewport_rect))
	game.resume_game()
	await get_tree().create_timer(0.5).timeout
	check("trajectory predicts ground impact", battle.targeting.prediction_valid and battle.targeting.predicted_time > 1.0)
	var yaw_before: float = battle.artillery.yaw_degrees
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(40, -15)
	game.aim_input._gui_input(drag)
	check("touch aiming surface changes traverse", not is_equal_approx(yaw_before, battle.artillery.yaw_degrees))
	await capture("battlefield")
	Profile.data.settings.quality = "ultra"
	Graphics.apply_preference()
	await get_tree().create_timer(0.8).timeout
	await capture("battlefield-ultra")
	# Gameplay assertions run at the performance tier so software rendering cannot
	# starve the fixed-step simulation; visual evidence above stays high/ultra.
	Profile.data.settings.quality = "low"
	Graphics.apply_preference()
	await get_tree().create_timer(0.6).timeout
	for id in battle.mission.target_ids:
		var attempts: int = 0
		var target: EnemyTarget
		for candidate in battle.battlefield.targets:
			if candidate.target_id == id:
				target = candidate
		while not target.health.is_destroyed and attempts < 5 and battle.active:
			battle.select_target(id)
			game.hud.solution_requested.emit()
			var prediction_wait: float = 0.0
			while not battle.targeting.prediction_valid and prediction_wait < 8.0:
				await get_tree().create_timer(0.15).timeout
				prediction_wait += 0.15
			if not battle.targeting.prediction_valid:
				game.hud.solution_requested.emit()
				var retry_wait: float = 0.0
				while not battle.targeting.prediction_valid and retry_wait < 3.0:
					await get_tree().create_timer(0.15).timeout
					retry_wait += 0.15
			check("fire control " + id, battle.targeting.prediction_valid)
			await get_tree().create_timer(0.3).timeout
			var shots_before: int = battle.missions.shots
			game.hud.fire_button.pressed.emit()
			check("fire " + id, battle.missions.shots == shots_before + 1)
			engagements[id] = int(engagements.get(id, 0)) + 1
			var elapsed: float = 0.0
			while battle.projectiles.active_count() > 0 and elapsed < 20.0:
				await get_tree().create_timer(0.1).timeout
				elapsed += 0.1
			await get_tree().create_timer(0.5).timeout
			if attempts == 0:
				await capture("impact_" + id)
			while not battle.artillery.can_fire() and battle.active:
				await get_tree().create_timer(0.1).timeout
			attempts += 1
		check("target destroyed " + id, target.health.is_destroyed)
	for id in battle.mission.target_ids:
		check("engaged " + id, int(engagements.get(id, 0)) >= 1)
	game.present_smoke_results()
	await get_tree().create_timer(1.0).timeout
	check("mission results displayed", game.menus.current == "results" and battle.missions.result.get("success", false))
	await capture("mission-results")
	var upgrade_before: int = int(Profile.data.upgrades.reload)
	game.menus.upgrade_requested.emit("reload")
	check("upgrade purchase persists", int(Profile.data.upgrades.reload) > upgrade_before and int(SaveManager.read_with_recovery(Profile.SAVE_PATH).data.upgrades.reload) > upgrade_before)
	game.menus.show_screen("upgrades")
	await get_tree().create_timer(0.3).timeout
	await capture("upgrades")
	var report: Dictionary = {"scope": "Desktop Godot 4.7.2 Compatibility renderer under Xvfb/llvmpipe; not Android hardware", "checks": checks, "failures": failures, "passed": failures == 0, "performance": Graphics.snapshot(), "mission": battle.missions.result, "engagements": engagements, "damage_events": damage_events}
	var file: FileAccess = FileAccess.open(output + "/smoke-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("ARTILLERY_SMOKE_REPORT ", JSON.stringify(report))
	Sound.stop_all()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0 if failures == 0 else 1)
