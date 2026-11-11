extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func run_tests() -> void:
	var launcher = load("res://scenes/launcher.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	check(launcher.layout_direction == Control.LAYOUT_DIRECTION_RTL, "launcher RTL layout")
	var font: Font = load("res://assets/fonts/DejaVuSans.ttf")
	var sample := "سلامتی تعداد نیروها مرحله ۰۱۲۳۴۵۶۷۸۹"
	var all_present := true
	for i in range(sample.length()):
		if not font.has_char(sample.unicode_at(i)):
			all_present = false
	check(all_present, "font contains Persian sample and digit glyphs")
	var level = load("res://scenes/level/sky_bridge.tscn").instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	level.hud.update_status(100, 3, 15, 30, "")
	check(level.hud.info.text_direction == Control.TEXT_DIRECTION_RTL, "HUD text direction")
	check("۱۰۰" in level.hud.info.text and "۳" in level.hud.info.text, "HUD uses Persian digits")
	launcher.queue_free()
	level.queue_free()
	print("Persian UI property checks failed: ", failures)
	quit(1 if failures else 0)
