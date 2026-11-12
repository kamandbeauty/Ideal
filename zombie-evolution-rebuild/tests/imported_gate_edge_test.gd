extends SceneTree

# Adapted from the independent prototype rule and game-logic tests. Exercise
# the active scene's real gate signals and recruitment instead of importing its
# incompatible rule implementation.
const GateScript = preload("res://scripts/level/gates.gd")
var failures := 0
var crossings := 0
var last_effect := ""

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func record_crossing(effect: String) -> void:
	crossings += 1
	last_effect = effect

func run_tests() -> void:
	var level = load("res://scenes/level/sky_bridge.tscn").instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	await physics_frame
	check(level.soldiers.is_empty(), "formation starts without soldiers")
	level.on_gate_crossed("double")
	check(level.soldiers.size() == 1, "doubling a solo hero adds one soldier")
	level.on_gate_crossed("double")
	check(level.soldiers.size() == 3, "doubling includes the hero")
	level.on_gate_crossed("double")
	check(level.soldiers.size() == 7, "repeated doubling includes the hero")
	level.on_gate_crossed("add3")
	level.on_gate_crossed("add3")
	check(level.soldiers.size() == 10, "recruitment never exceeds the squad cap")
	check(level.hud.digits(120) == "۱۲۰", "multi-digit Persian conversion")
	check(level.hud.digits(0) == "۰", "zero uses a Persian digit")

	var gate = GateScript.new()
	gate.position.z = 10.0
	root.add_child(gate)
	gate.crossed.connect(record_crossing)
	gate.check_crossing(9.0)
	check(crossings == 0 and not gate.finished, "gate does not fire before crossing")
	gate.select(-1)
	gate.select(1)
	gate.check_crossing(10.0)
	gate.check_crossing(11.0)
	check(crossings == 1 and last_effect == "double", "locked gate emits the selected effect exactly once")

	var unselected = GateScript.new()
	unselected.position.z = 10.0
	root.add_child(unselected)
	unselected.crossed.connect(record_crossing)
	unselected.check_crossing(10.0)
	unselected.check_crossing(11.0)
	check(unselected.finished and crossings == 1, "unselected gate grants no effect")
	level.queue_free()
	print("Imported gate edge tests failed: ", failures)
	quit(1 if failures else 0)
