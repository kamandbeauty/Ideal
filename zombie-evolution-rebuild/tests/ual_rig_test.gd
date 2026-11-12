extends SceneTree

const RigScene = preload("res://assets/models/ual-reference-rig.glb")
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
		var result := find_type(child, type_name)
		if result != null:
			return result
	return null

func run_tests() -> void:
	var model := RigScene.instantiate()
	root.add_child(model)
	var skeleton := find_type(model, "Skeleton3D") as Skeleton3D
	var player := find_type(model, "AnimationPlayer") as AnimationPlayer
	check(skeleton != null and player != null, "reference model imports with skeleton and animation player")
	if skeleton and player:
		check(skeleton.get_bone_count() >= 50, "reference rig includes detailed humanoid skeleton")
		var hand_exists := false
		for bone in range(skeleton.get_bone_count()):
			if "hand" in skeleton.get_bone_name(bone).to_lower():
				hand_exists = true
		check(hand_exists, "reference rig has hand bones")
		for requested in ["Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Pistol_Shoot", "Hit_Chest", "Death01"]:
			var found := ""
			for clip_name in player.get_animation_list():
				if String(clip_name).ends_with(requested):
					found = String(clip_name)
					break
			check(not found.is_empty(), requested + " authored clip imports")
			if not found.is_empty():
				player.play(found)
				player.advance(0.0)
				var before: Array[Transform3D] = []
				for bone in range(skeleton.get_bone_count()):
					before.append(skeleton.get_bone_pose(bone))
				player.advance(0.17)
				var moved := false
				for bone in range(skeleton.get_bone_count()):
					if not skeleton.get_bone_pose(bone).is_equal_approx(before[bone]):
						moved = true
						break
				check(moved, requested + " changes skeletal pose")
	model.queue_free()
	await process_frame
	print("Reference rig failures: ", failures)
	quit(1 if failures else 0)
