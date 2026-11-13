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
	await process_frame
	print("User zombie rig failures: ", failures)
	quit(1 if failures else 0)
