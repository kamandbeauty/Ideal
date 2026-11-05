extends Node
## Software-rendered end-to-end smoke driver. Not Android/device certification.
var game: Node
var checks: Array[Dictionary] = []
var failures: int = 0
var output: String = "res://documentation/qa"

func _ready() -> void:
	call_deferred("run")

func check(name: String, passed: bool) -> void:
	checks.append({"name": name, "passed": passed})
	if not passed:
		failures += 1
		push_error("SMOKE FAIL: " + name)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png(output + "/" + name + ".png")
	check("capture " + name, error == OK and image.get_width() > 500)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Graphics.apply_tier("medium")
	await get_tree().create_timer(1.8).timeout
	game.start_mission("sr01")
	await get_tree().create_timer(1.0).timeout
	var battle: BattleController = game.battle
	check("battlefield initialized", battle.battlefield.targets.size() == 6)
	check("HUD visible", game.hud.visible)
	await capture("battlefield")
	for id in battle.mission.target_ids:
		var attempts: int = 0
		var target: EnemyTarget
		for candidate in battle.battlefield.targets:
			if candidate.target_id == id:
				target = candidate
		while not target.health.is_destroyed and attempts < 5 and battle.active:
			battle.select_target(id)
			check("fire control " + id, battle.compute_solution())
			await get_tree().create_timer(0.3).timeout
			check("fire " + id, battle.fire())
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
	await get_tree().create_timer(1.0).timeout
	check("mission results displayed", game.menus.current == "results" and battle.missions.result.get("success", false))
	await capture("mission-results")
	game.menus.show_screen("upgrades")
	await get_tree().create_timer(0.3).timeout
	await capture("upgrades")
	var report: Dictionary = {"scope": "Desktop Godot 4.7.2 Compatibility renderer under Xvfb/llvmpipe; not Android hardware", "checks": checks, "failures": failures, "passed": failures == 0, "performance": Graphics.snapshot(), "mission": battle.missions.result}
	var file: FileAccess = FileAccess.open(output + "/smoke-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("ARTILLERY_SMOKE_REPORT ", JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)
