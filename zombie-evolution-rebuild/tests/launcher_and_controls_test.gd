extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func verify(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		printerr("FAIL: ", label)
		failures += 1

func find_start(node: Node) -> Button:
	if node is Button and node.text == "شروع بازی":
		return node
	for child in node.get_children():
		var found := find_start(child)
		if found:
			return found
	return null

func run_tests() -> void:
	var error := change_scene_to_file("res://scenes/launcher.tscn")
	verify(error == OK, "launcher scene requested")
	await process_frame
	await process_frame
	var start := find_start(current_scene)
	verify(start != null, "launcher contains start button")
	if start == null:
		quit(1)
		return
	start.pressed.emit()
	await process_frame
	await process_frame
	var level = current_scene
	verify(level != null and level.scene_file_path == "res://scenes/level/sky_bridge.tscn", "start button opens level")
	if level == null or level.scene_file_path != "res://scenes/level/sky_bridge.tscn":
		quit(1)
		return
	var start_z: float = level.hero.position.z
	for i in range(10):
		await physics_frame
	verify(level.hero.position.z > start_z, "automatic forward movement")
	var x_before: float = level.hero.position.x
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(75, 0)
	level._unhandled_input(drag)
	await physics_frame
	await physics_frame
	verify(level.hero.position.x > x_before, "touch drag moves hero")
	level.hero.position.x = -4.6
	var large_drag := InputEventScreenDrag.new()
	large_drag.relative = Vector2(-10000, 0)
	level._unhandled_input(large_drag)
	await physics_frame
	await physics_frame
	verify(level.hero.position.x >= -4.71, "touch movement stays on bridge")
	level.hero.apply_damage(10000)
	verify(not level.running and level.hud.end_panel.visible, "hero death shows defeat")
	print("Launcher/control test failures: ", failures)
	quit(1 if failures else 0)
