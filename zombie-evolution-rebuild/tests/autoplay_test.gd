extends SceneTree

const AudioProbe = preload("res://ci/audio_probe.gd")

# Exercises a real, unmodified level loop without changing health, damage or positions.
func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var result := change_scene_to_file("res://scenes/launcher.tscn")
	if result != OK:
		printerr("Cannot load launcher: ", result)
		quit(1)
		return
	await process_frame
	await process_frame
	var start: Button = find_start(current_scene)
	if start == null:
		printerr("Start button not found")
		quit(1)
		return
	start.pressed.emit()
	await process_frame
	await process_frame
	var level = current_scene
	var fire := InputEventAction.new()
	fire.action = "fire"
	fire.pressed = true
	level._input(fire)
	var max_soldiers := 0
	var frame := 0
	while level.running and frame < 9000:
		await physics_frame
		max_soldiers = maxi(max_soldiers, level.soldiers.size())
		frame += 1
	var survived: bool = is_instance_valid(level.hero) and level.hero.health > 0
	var won: bool = not level.running and survived and level.enemies.is_empty()
	print("Autoplay frames=", frame, " won=", won, " survived=", survived, " kills=", level.kills, " max_soldiers=", max_soldiers, " enemies_remaining=", level.enemies.size())
	level.sound.stop_all()
	var cleaned: bool = await AudioProbe.drain(self)
	quit(0 if won and max_soldiers >= 1 and cleaned else 1)

func find_start(node: Node) -> Button:
	if node is Button and node.text == "شروع بازی":
		return node
	for child in node.get_children():
		var button := find_start(child)
		if button != null:
			return button
	return null
