extends SceneTree
## Headless test runner.
##
##     godot --headless --path . --script res://tests/run_tests.gd
##
## Runs every `test_*` method in every suite, prints a short table, writes
## documentation/qa/test-results.json and exits non-zero on failure. Nothing
## here needs a window, a renderer or the `App` autoload.

const SUITES := [
	"res://tests/suites/test_localization.gd",
	"res://tests/suites/test_business_data.gd",
	"res://tests/suites/test_economy.gd",
	"res://tests/suites/test_save.gd",
	"res://tests/suites/test_decor.gd",
	"res://tests/suites/test_missions_events.gd",
	"res://tests/suites/test_customer_flow.gd",
	"res://tests/suites/test_auto_upgrade.gd",
	"res://tests/suites/test_profile.gd",
	"res://tests/suites/test_daily_and_tips.gd",
	"res://tests/suites/test_guild_locale.gd",
	"res://tests/suites/test_guild_rig.gd",
	"res://tests/suites/test_guild_player.gd",
	"res://tests/suites/test_guild_hall.gd",
	"res://tests/suites/test_guild_economy.gd",
	"res://tests/suites/test_guild_hud.gd",
	"res://tests/suites/test_guild_customers.gd",
	"res://tests/suites/test_guild_missions.gd",
	"res://tests/suites/test_guild_save.gd",
]
const REPORT_PATH := "res://documentation/qa/test-results.json"


func _initialize() -> void:
	var checks := 0
	var failures: Array[String] = []
	var suites: Array = []
	var methods := 0

	for path in SUITES:
		var script := load(path) as GDScript
		if script == null:
			failures.append("%s: suite could not be loaded" % path)
			continue
		var suite := script.new() as TestCase
		if suite == null:
			failures.append("%s: suite is not a TestCase" % path)
			continue
		suite.suite_name = path.get_file().get_basename()
		var suite_methods := 0
		for method in suite.get_method_list():
			var method_name := str(method["name"])
			if method_name.begins_with("test_"):
				suite_methods += 1
				methods += 1
				suite.call(method_name)
		checks += suite.checks
		failures.append_array(suite.failures)
		suites.append({
			"name": suite.suite_name,
			"methods": suite_methods,
			"checks": suite.checks,
			"failures": suite.failures.size(),
		})
		print("%-22s %3d checks  %d failures" % [suite.suite_name, suite.checks, suite.failures.size()])

	var report := {
		"passed": failures.is_empty(),
		"engine": str(Engine.get_version_info().get("string", "")),
		"suites": suites,
		"methods": methods,
		"checks": checks,
		"failures": failures,
		"timestamp": Time.get_datetime_string_from_system(true),
	}
	_write_report(report)
	print(JSON.stringify(report, "  "))

	if failures.is_empty():
		print("ALL TESTS PASSED (%d checks in %d suites)" % [checks, suites.size()])
		quit(0)
	else:
		printerr("TESTS FAILED (%d failures)" % failures.size())
		for failure in failures:
			printerr("  - " + failure)
		quit(1)


func _write_report(report: Dictionary) -> void:
	var directory := ProjectSettings.globalize_path(REPORT_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % REPORT_PATH)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
