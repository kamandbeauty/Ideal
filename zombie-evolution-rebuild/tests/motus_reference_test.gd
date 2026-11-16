extends SceneTree

const Reference = preload("res://assets/models/motus-pistol-reference.glb")
var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := find_type(child, type_name)
		if found:
			return found
	return null

func run_tests() -> void:
	var model := Reference.instantiate()
	root.add_child(model)
	var skeleton := find_type(model, "Skeleton3D") as Skeleton3D
	var animation := find_type(model, "AnimationPlayer") as AnimationPlayer
	check(skeleton != null and animation != null, "Motus reference imports skeleton and animation player")
	if skeleton and animation:
		check(skeleton.get_bone_count() >= 50, "Motus humanoid has detailed skeleton")
		check(skeleton.find_bone("LeftHand") >= 0 and skeleton.find_bone("RightHand") >= 0, "Motus rig includes both hands")
		print("Motus imported animations: ", animation.get_animation_list())
		for clip in ["PistolAimIdle", "PistolAimWalk", "PistolFire"]:
			check(animation.has_animation(clip), clip + " imports")
			if animation.has_animation(clip):
				animation.play(clip)
				animation.advance(0.0)
				var before: Array[Transform3D] = []
				for bone in range(skeleton.get_bone_count()):
					before.append(skeleton.get_bone_pose(bone))
				animation.advance(0.17)
				var moved := false
				for bone in range(skeleton.get_bone_count()):
					if not before[bone].is_equal_approx(skeleton.get_bone_pose(bone)):
						moved = true
						break
				check(moved, clip + " changes skeletal pose")
	model.queue_free()
	await process_frame
	print("Motus reference failures: ", failures)
	quit(1 if failures else 0)
