extends SceneTree

# Test-only isolated asset review, not gameplay footage.
func _initialize() -> void:
	call_deferred("capture")

func find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := find_player(child)
		if found:
			return found
	return null

func capture() -> void:
	var output := OS.get_environment("CI_SCREENSHOT_DIR")
	if output.is_empty() or not output.is_absolute_path():
		printerr("FAIL: missing screenshot output directory")
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.26, 0.32, 0.37)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.82, 0.90)
	environment.ambient_light_energy = 0.9
	world.environment = environment
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -25, 0)
	light.light_energy = 1.3
	stage.add_child(light)
	var model := preload("res://assets/models/zombie-user-animated.glb").instantiate() as Node3D
	model.scale = Vector3.ONE * 0.01
	stage.add_child(model)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.2, -4.5)
	camera.fov = 36
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	camera.current = true
	var animation := find_player(model)
	if animation == null or not animation.has_animation("Walk"):
		printerr("FAIL: user zombie walk clip missing")
		quit(1)
		return
	animation.play("Walk")
	animation.advance(0.4)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join("10-user-zombie-test-only.png")) != OK:
		printerr("FAIL: could not save zombie review")
		quit(1)
		return
	print("CAPTURE TEST-ONLY: user zombie model walk pose ", image.get_size())
	stage.queue_free()
	await process_frame
	quit(0)
