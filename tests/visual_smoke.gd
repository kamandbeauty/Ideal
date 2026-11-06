extends SceneTree
## Runs with a real renderer under Xvfb/desktop, not --headless.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	_capture("build/visual-menu.png")
	game._start_mission()
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	_capture("build/visual-gameplay.png")
	var frame_count := 0
	var sample_start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - sample_start < 1000000:
		await process_frame
		frame_count += 1
	var sample_seconds := float(Time.get_ticks_usec() - sample_start) / 1000000.0
	print(
		(
			"Software rendering observation: %.1f FPS at 1280x720 (%.1f s)"
			% [frame_count / sample_seconds, sample_seconds]
		)
	)

	# A touch beginning on FIRE must activate the button, not the aim drag.
	var fire_point: Vector2 = game.hud._fire_button.get_global_rect().get_center()
	var initial_yaw: float = game.gun.yaw_degrees
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.position = fire_point
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = fire_point + Vector2(8, 0)
	drag.relative = Vector2(8, 0)
	Input.parse_input_event(drag)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 1
	release.position = fire_point + Vector2(8, 0)
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	_check(game.gun.yaw_degrees == initial_yaw, "dragging a fire-button touch does not aim")
	_check(game.mission.shots_fired == 1, "touching FIRE launches one shell")

	# A separate touch on the world should traverse the gun.
	touch = InputEventScreenTouch.new()
	touch.index = 2
	touch.position = Vector2(640, 300)
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	drag = InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(690, 300)
	drag.relative = Vector2(50, 0)
	Input.parse_input_event(drag)
	await process_frame
	release = InputEventScreenTouch.new()
	release.index = 2
	release.position = Vector2(690, 300)
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	_check(game.gun.yaw_degrees != initial_yaw, "touch drag on the battlefield aims the gun")
	game.gun.set_aim(0, 26)
	var radar := game.get_node("Radar") as BattlefieldTarget
	for i in range(420):
		await physics_frame
		if radar.is_destroyed:
			break
	_check(radar.is_destroyed, "touch-fired shell hits and destroys the radar")
	if radar.is_destroyed:
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		_capture("build/visual-impact.png")
		var effect_active := false
		for effect in game.effects._explosions:
			effect_active = effect_active or effect.active
		_check(effect_active, "pooled impact effect is active after a hit")

	game.queue_free()
	await process_frame
	for failure in failures:
		printerr("FAIL: ", failure)
	print("Visual smoke: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _capture(path: String) -> void:
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(path)
	_check(error == OK and image.get_width() > 0, "rendered screenshot: " + path)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  PASS ", description)
	else:
		failures.append(description)
