extends SceneTree
## Dependency-free test runner. Exit code is nonzero on any failed assertion.
var context := TestContext.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	context.tree = self
	var suites: Array[String] = [
		"res://tests/unit/test_ballistics.gd", "res://tests/unit/test_damage.gd",
		"res://tests/unit/test_weapon.gd", "res://tests/unit/test_save.gd",
		"res://tests/unit/test_progression.gd", "res://tests/unit/test_graphics.gd",
		"res://tests/unit/test_resources.gd", "res://tests/unit/test_localization.gd", "res://tests/unit/test_return_fire.gd",
		"res://tests/integration/test_combat.gd",
		"res://tests/integration/test_missions.gd",
		"res://tests/integration/test_campaign.gd",
		"res://tests/integration/test_ui.gd",
		"res://tests/integration/test_coastal.gd",
		"res://tests/integration/test_coastal_pass3.gd",
		"res://tests/integration/test_enemy_behaviour.gd",
		"res://tests/integration/test_wave_balance.gd",
		"res://tests/integration/test_aircraft_balance.gd",
		"res://tests/integration/test_weapon_balance.gd",
		"res://tests/integration/test_cleanup_and_guidance.gd"
	]
	for path in suites:
		if not ResourceLoader.exists(path):
			continue
		context.suite = path.get_file().get_basename()
		var script: Script = load(path)
		if not script.can_instantiate():
			context.check(false, "Suite failed to compile")
			continue
		var instance: RefCounted = script.new()
		await instance.run(context)
	var report: Dictionary = {"engine": Engine.get_version_info().string, "checks": context.checks, "failures": context.failures, "passed": context.failures.is_empty(), "scope": "Headless desktop logic and scene integration; NOT Android device validation"}
	print("ARTILLERY_TEST_REPORT " + JSON.stringify(report))
	var file: FileAccess = FileAccess.open("res://../artillery-test-results.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
	quit(0 if context.failures.is_empty() else 1)
