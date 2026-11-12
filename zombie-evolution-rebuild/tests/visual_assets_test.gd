extends SceneTree

const Character = preload("res://scripts/level/character.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		printerr("FAIL: ", description)

func run_tests() -> void:
	var background = load("res://assets/ui/sky_bridge_background.png")
	check(background is Texture2D, "menu background imports as a texture")
	var road = load("res://assets/environment/road_asphalt_tile.png")
	check(road is Texture2D and road.get_width() == 512 and road.get_height() == 512, "road tile imports at mobile-conscious resolution")
	var environment = load("res://scripts/level/environment.gd").new()
	var road_material = environment.asphalt_material(Color.WHITE)
	check(road_material.get_shader_parameter("asphalt_texture") == road, "bridge material uses the generated road tile")
	environment.free()
	for role in ["hero", "zombie", "runner", "brute"]:
		var actor = Character.new()
		root.add_child(actor)
		actor.setup(role)
		check(is_instance_valid(actor.visual_root) and actor.visual_root.get_child_count() == 1, role + " model imports and instantiates")
		actor.update_animation(0.016, true)
		actor.update_animation(0.016, false)
		actor.queue_free()
	await process_frame
	print("Visual asset import failures: ", failures)
	quit(1 if failures else 0)
