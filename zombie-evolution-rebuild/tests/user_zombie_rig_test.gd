extends SceneTree

const ZombieScene = preload("res://assets/models/zombie-user-animated.glb")
var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := find_type(child, type_name)
		if found != null:
			return found
	return null

func run_tests() -> void:
	var model := ZombieScene.instantiate()
	root.add_child(model)
	var skeleton := find_type(model, "Skeleton3D") as Skeleton3D
	var player := find_type(model, "AnimationPlayer") as AnimationPlayer
	check(skeleton != null and player != null, "user zombie imports with rig and animation player")
	if skeleton and player:
		check(skeleton.get_bone_count() >= 40, "zombie skeleton has detailed bone hierarchy")
		print("Imported zombie animation names: ", player.get_animation_list())
		for clip in ["Idle", "Walk", "Run", "Attack", "Hit", "Death"]:
			check(player.has_animation(clip), clip + " source clip imports")
			if not player.has_animation(clip):
				continue
			player.play(clip)
			player.advance(0.0)
			var before: Array[Transform3D] = []
			for bone in range(skeleton.get_bone_count()):
				before.append(skeleton.get_bone_pose(bone))
			player.advance(0.2)
			var moved := false
			for bone in range(skeleton.get_bone_count()):
				if not skeleton.get_bone_pose(bone).is_equal_approx(before[bone]):
					moved = true
					break
			check(moved, clip + " moves skeletal bones")
	model.queue_free()
	var actor = preload("res://scripts/level/character.gd").new()
	root.add_child(actor)
	actor.setup("zombie")
	check(is_instance_valid(actor.animation_player) and is_instance_valid(actor.rig), "gameplay zombie uses supplied rig")
	actor.update_animation(0.1, true)
	check(actor.current_animation == "Walk", "moving zombie plays supplied walk clip")
	actor.update_animation(0.1, false)
	check(actor.current_animation == "Idle", "stationary zombie plays idle clip")
	actor.play_zombie_action("Attack", 0.7)
	check(actor.current_animation == "Attack", "attack plays supplied clip")
	actor.apply_damage(1)
	check(actor.current_animation == "Hit", "damage plays supplied hit clip")
	var death_start: Vector3 = actor.visual_root.position
	actor.apply_damage(999, Vector3(0, 0, 1))
	check(actor.dead and actor.current_animation == "Death", "defeat plays supplied death clip")
	check(actor.collision_layer == 0 and actor.animation_player.speed_scale == 6.0, "death disables collision and accelerates animation")
	await create_timer(0.25).timeout
	check(actor.visual_root.position.z > death_start.z + 0.3, "lethal impact throws zombie away from shooter")
	await create_timer(1.2).timeout
	check(not is_instance_valid(actor), "defeated zombie is cleaned up after the accelerated death")
	await process_frame
	print("User zombie rig failures: ", failures)
	quit(1 if failures else 0)
