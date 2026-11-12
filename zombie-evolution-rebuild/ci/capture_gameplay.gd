extends SceneTree

const AudioProbe = preload("res://ci/audio_probe.gd")

# Normal screenshots come from natural play. If both runs win, capture a clearly
# labeled test-only defeat through the real damage and defeat transition.
var captured := {}
var output_dir := ""

func _initialize() -> void:
	call_deferred("run_capture")

func snapshot(name: String) -> void:
	if captured.has(name):
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("FAIL: renderer returned an empty image for ", name)
		return
	var result := image.save_png(output_dir.path_join(name + ".png"))
	if result != OK:
		printerr("FAIL: could not save ", name, " error=", result)
		return
	captured[name] = true
	print("CAPTURE ", name, " size=", image.get_size())

func find_start(node: Node) -> Button:
	if node is Button and node.text == "شروع بازی":
		return node
	for child in node.get_children():
		var found := find_start(child)
		if found:
			return found
	return null

func run_capture() -> void:
	output_dir = OS.get_environment("CI_SCREENSHOT_DIR")
	if output_dir.is_empty() or not output_dir.is_absolute_path():
		printerr("FAIL: CI_SCREENSHOT_DIR must be an absolute path")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		printerr("FAIL: cannot create screenshot directory")
		quit(1)
		return
	for attempt in range(2):
		if change_scene_to_file("res://scenes/launcher.tscn") != OK:
			printerr("FAIL: launcher could not be loaded")
			quit(1)
			return
		await process_frame
		await process_frame
		if attempt == 0:
			await snapshot("01-launcher")
		var start := find_start(current_scene)
		if start == null:
			printerr("FAIL: launcher start button is missing")
			quit(1)
			return
		start.pressed.emit()
		await process_frame
		await process_frame
		var level = current_scene
		if level == null or level.scene_file_path != "res://scenes/level/sky_bridge.tscn":
			printerr("FAIL: launcher did not open gameplay")
			quit(1)
			return
		if attempt == 0:
			await snapshot("02-initial-bridge")
		else:
			# The second run chooses the left lane via the normal input action.
			Input.action_press("ui_left")
		var frame := 0
		while level.running and frame < 9000:
			await process_frame
			frame += 1
			if attempt == 1 and frame == 30:
				Input.action_release("ui_left")
			if not is_instance_valid(level.hero):
				continue
			if level.hero.muzzle_flash.visible and not captured.has("08-firing"):
				await snapshot("08-firing")
			if not captured.has("03-zombie-encounter"):
				for enemy in level.enemies:
					if is_instance_valid(enemy) and enemy.position.z > level.hero.position.z and enemy.position.distance_to(level.hero.position) < 22:
						await snapshot("03-zombie-encounter")
						break
			if is_instance_valid(level.gate) and not level.gate.finished and level.hero.position.z > level.gate.position.z - 12.0:
				await snapshot("04-glass-gate")
			if level.soldiers.size() > 0:
				await snapshot("05-recruited-soldiers")
			if level.hero.position.z > 139.0 and not captured.has("09-city-entrance"):
				for enemy in level.enemies:
					if is_instance_valid(enemy) and enemy.role == "brute" and not enemy.dead:
						await snapshot("09-city-entrance")
						break
		Input.action_release("ui_left")
		if not level.running:
			if is_instance_valid(level.hero) and level.hero.health > 0 and level.enemies.is_empty():
				await snapshot("06-victory")
			else:
				await snapshot("07-defeat")
		print("ATTEMPT ", attempt + 1, " frames=", frame, " running=", level.running)
	if not captured.has("07-defeat"):
		print("TEST-ONLY: applying lethal damage in the real level to capture defeat")
		if change_scene_to_file("res://scenes/launcher.tscn") != OK:
			printerr("FAIL: could not reload launcher for test-only defeat")
			quit(1)
			return
		await process_frame
		await process_frame
		var retry := find_start(current_scene)
		if retry == null:
			printerr("FAIL: start button missing for test-only defeat")
			quit(1)
			return
		retry.pressed.emit()
		await process_frame
		await process_frame
		var level = current_scene
		if level == null or level.scene_file_path != "res://scenes/level/sky_bridge.tscn" or not is_instance_valid(level.hero):
			printerr("FAIL: level missing for test-only defeat")
			quit(1)
			return
		level.hero.apply_damage(level.hero.health + 1.0)
		if level.running or not level.hud.end_panel.visible:
			printerr("FAIL: actual defeat transition was not activated")
			quit(1)
			return
		await snapshot("07-defeat-test-only")
	var required := ["01-launcher", "02-initial-bridge", "03-zombie-encounter", "04-glass-gate", "05-recruited-soldiers", "06-victory", "08-firing", "09-city-entrance"]
	if captured.has("07-defeat"):
		required.append("07-defeat")
	else:
		required.append("07-defeat-test-only")
	var missing := 0
	for name in required:
		if not captured.has(name):
			printerr("FAIL: requested capture was not produced: ", name)
			missing += 1
	print("Captured ", captured.size(), "/", required.size(), "; missing=", missing)
	if current_scene != null and current_scene.get("sound") != null:
		current_scene.sound.stop_all()
	if not await AudioProbe.drain(self):
		missing += 1
	quit(1 if missing else 0)
