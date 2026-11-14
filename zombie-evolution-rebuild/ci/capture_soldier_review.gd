extends SceneTree

# Test-only close-up of a candidate asset, not a gameplay frame.
func _initialize() -> void:
	call_deferred("capture")

func find_node_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := find_node_type(child, type_name)
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
	environment.ambient_light_color = Color(0.85, 0.90, 1.0)
	environment.ambient_light_energy = 1.0
	world.environment = environment
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -25, 0)
	light.light_energy = 1.4
	stage.add_child(light)
	var model := preload("res://assets/models/soldier-bamen-reference.glb").instantiate() as Node3D
	stage.add_child(model)
	var camera := Camera3D.new()
	camera.position = Vector3(2.8, 1.75, -4.3)
	camera.fov = 36
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.05, 0), Vector3.UP)
	camera.current = true
	var animation := find_node_type(model, "AnimationPlayer") as AnimationPlayer
	var skeleton := find_node_type(model, "Skeleton3D") as Skeleton3D
	if animation == null or skeleton == null or not animation.has_animation("aim_walk"):
		printerr("FAIL: candidate aim walk clip or skeleton missing")
		quit(1)
		return
	animation.play("aim_walk")
	animation.advance(0.4)
	await process_frame
	var hand := -1
	for i in range(skeleton.get_bone_count()):
		if skeleton.get_bone_name(i).ends_with("RightHand"):
			hand = i
			break
	if hand < 0:
		printerr("FAIL: right hand bone missing")
		quit(1)
		return
	var weapon := Node3D.new()
	stage.add_child(weapon)
	weapon.global_position = skeleton.to_global(skeleton.get_bone_global_pose(hand) * Vector3(0, 5, 0))
	var rifle := preload("res://assets/models/rifle-quaternius.glb").instantiate() as Node3D
	rifle.scale = Vector3.ONE * 0.3
	rifle.rotation.y = -PI / 2.0
	rifle.position = Vector3(0, -0.05, -0.18)
	weapon.add_child(rifle)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join("13-soldier-candidate-test-only.png")) != OK:
		printerr("FAIL: could not save candidate review")
		quit(1)
		return
	print("CAPTURE TEST-ONLY: candidate soldier and approximate rifle mount ", image.get_size(), " hand ", skeleton.get_bone_name(hand))
	stage.queue_free()
	await process_frame
	quit(0)
