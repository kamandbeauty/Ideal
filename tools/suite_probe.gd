extends SceneTree
## Loads and instantiates every suite without running a single test.
##
##     godot --headless --path . --script res://tools/suite_probe.gd
##
## The full runner only says "a suite hung" once a job times out. This prints one
## line per step (with stdbuf in CI, so the lines survive a kill) and stops at the
## first suite that will not come up, which is where the fault is.

func _initialize() -> void:
	var runner := load("res://tests/run_tests.gd")
	if runner == null:
		printerr("probe: the runner itself will not load")
		quit(1)
		return
	var suites: Array = runner.get_script_constant_map()["SUITES"]
	for path in suites:
		print("probe: load " + str(path))
		var script := load(path) as GDScript
		if script == null:
			printerr("probe: FAILED to load " + str(path))
			quit(1)
			return
		print("probe: new " + str(path))
		var suite: Object = script.new()
		if suite == null:
			printerr("probe: FAILED to instantiate " + str(path))
			quit(1)
			return
		print("probe: ok " + str(path))
		print("probe: methods %d on %s" % [suite.get_method_list().size(), path])
	print("SUITES OK")
	quit(0)
