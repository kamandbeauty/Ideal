extends SceneTree

const Experiment = preload("res://ci/motus_rifle_experiment.gd")

func _initialize() -> void:
	call_deferred("capture")

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
	environment.ambient_light_color = Color(0.85, 0.90, 1.0)
	environment.ambient_light_energy = 1.0
	world.environment = environment
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -25, 0)
	light.light_energy = 1.4
	stage.add_child(light)
	var rig = Experiment.new()
	stage.add_child(rig)
	if not rig.ready_ok:
		printerr("FAIL: experimental rig did not initialize")
		quit(1)
		return
	var camera := Camera3D.new()
	camera.position = Vector3(4.5, 1.25, -0.8)
	camera.fov = 36
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.05, 0), Vector3.UP)
	camera.current = true
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var left_index: int = rig.skeleton.find_bone("LeftHand")
	var left_position: Vector3 = rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(left_index).origin)
	var right_position: Vector3 = rig.right_attachment.global_position
	var grip_position: Vector3 = rig.rifle.to_global(rig.RIGHT_GRIP)
	print("RIFLE EXPERIMENT right=", right_position, " right grip=", grip_position, " right distance=", right_position.distance_to(grip_position), " left=", left_position, " target=", rig.support_target.global_position, " left distance=", left_position.distance_to(rig.support_target.global_position), " solver=", rig.solver.is_running())
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join("17-rifle-grip-experiment-test-only.png")) != OK:
		printerr("FAIL: could not save rifle experiment")
		quit(1)
		return
	print("CAPTURE TEST-ONLY: animated mannequin, rifle and support-hand IK")
	stage.queue_free()
	await process_frame
	quit(0)
