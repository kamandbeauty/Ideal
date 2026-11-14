extends SceneTree
## Headless test runner: every suite in tests/unit and tests/integration.
##
##     godot --headless --path . --script res://tests/run_tests.gd [-- --only=test_aim --report=/tmp/report.json]
##
## Exits non-zero when any check fails and writes documentation/qa/test-results.json
## (or the --report path, so a local run does not touch the evidence CI records).

const REPORT_PATH: String = "res://documentation/qa/test-results.json"

var context := TestContext.new()


func _initialize() -> void:
	_run.call_deferred()


func _suites() -> Array[String]:
	var found: Array[String] = []
	for folder: String in ["res://tests/unit", "res://tests/integration"]:
		var names: PackedStringArray = DirAccess.get_files_at(folder)
		names.sort()
		for file_name: String in names:
			if file_name.begins_with("test_") and file_name.ends_with(".gd"):
				found.append(folder + "/" + file_name)
	return found


func _run() -> void:
	context.tree = self
	# Autoloads are not visible to the main-loop script at compile time; reach them through the tree.
	var profile: Node = root.get_node("Profile")
	profile.persist = false
	profile.load_profile()
	# Loaded after autoloads exist. Naming class_name Zombie here would compile
	# zombie.gd as a dependency of this --script, before Graphics is registered.
	var zombie_script: GDScript = load("res://scripts/zombies/zombie.gd")
	zombie_script.mix_extras = false
	var only: String = ""
	var report_path: String = REPORT_PATH
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
		elif argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
	var residents: Array[Node] = root.get_children()
	for path: String in _suites():
		if only != "" and not path.contains(only):
			continue
		# A suite that stopped on an error may have left its level behind; it must not leak into the next one.
		var leftovers: int = 0
		for node: Node in root.get_children():
			if not residents.has(node):
				node.queue_free()
				leftovers += 1
		if leftovers > 0:
			paused = false
			Engine.time_scale = 1.0
			await process_frame
			await process_frame
		context.suite = path.get_file().get_basename()
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			context.check(false, "suite failed to compile")
			_write_report(report_path, false)
			continue
		var instance: RefCounted = script.new()
		await instance.run(context)
		var ran: int = int(context.per_suite.get(context.suite, 0))
		if ran == 0:
			context.check(false, "suite ran no checks (did it stop on a script error?)")
		print("  %-28s %4d checks" % [context.suite, ran])
		# Written after every suite so a later crash still leaves a valid JSON report.
		_write_report(report_path, false)
	_write_report(report_path, true)
	quit(0 if context.failures.is_empty() else 1)


func _write_report(report_path: String, announce: bool) -> void:
	var report: Dictionary = {
		"game": ProjectSettings.get_setting("application/config/name"),
		"version": ProjectSettings.get_setting("application/config/version"),
		"engine": Engine.get_version_info().string,
		"checks": context.checks,
		"suites": context.per_suite,
		"failures": context.failures,
		"passed": context.failures.is_empty(),
		"scope": "Headless logic and scene integration on desktop; not an Android device run",
	}
	if announce:
		print("LASTWALL_TEST_REPORT " + JSON.stringify(report))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
