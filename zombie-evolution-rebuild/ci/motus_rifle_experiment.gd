extends Node3D

# Isolated experiment: attach a rifle to the right hand and solve the left arm
# towards a support point. This is not wired to gameplay or a finished asset.
const Model = preload("res://assets/models/motus-fbx2gltf-reference.glb")
const Rifle = preload("res://assets/models/rifle-quaternius.glb")
const RIFLE_SCALE := 0.30
const RIGHT_GRIP := Vector3(0.70, 0.45, 0.0)
const SUPPORT_GRIP := Vector3(0.95, 0.20, -0.25)
var model: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var right_attachment: BoneAttachment3D
var left_attachment: BoneAttachment3D
var support_target: Node3D
var rifle: Node3D
var solver: SkeletonIK3D
var ready_ok := false
var solved_hand: Vector3 = Vector3.ZERO
var solved_target: Vector3 = Vector3.ZERO
var solved_root: Vector3 = Vector3.ZERO
var solved_elbow: Vector3 = Vector3.ZERO
var solved_frames := 0

func find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := find_type(child, type_name)
		if found:
			return found
	return null

func _ready() -> void:
	model = Model.instantiate() as Node3D
	add_child(model)
	skeleton = find_type(model, "Skeleton3D") as Skeleton3D
	animation = find_type(model, "AnimationPlayer") as AnimationPlayer
	if skeleton == null or animation == null:
		push_error("Experimental rifle rig is missing skeleton or animation")
		return
	for bone in ["RightHand", "LeftArm", "LeftHand", "Spine2"]:
		if skeleton.find_bone(bone) < 0:
			push_error("Experimental rifle rig is missing bone: " + bone)
			return
	right_attachment = BoneAttachment3D.new()
	right_attachment.name = "RightHandAttachment"
	right_attachment.bone_name = "RightHand"
	skeleton.add_child(right_attachment)
	left_attachment = BoneAttachment3D.new()
	left_attachment.name = "LeftHandAttachment"
	left_attachment.bone_name = "LeftHand"
	skeleton.add_child(left_attachment)
	rifle = Rifle.instantiate() as Node3D
	rifle.name = "ExperimentalRifle"
	add_child(rifle)
	support_target = Node3D.new()
	support_target.name = "SupportGripTarget"
	add_child(support_target)
	solver = SkeletonIK3D.new()
	solver.name = "SupportHandIK"
	solver.root_bone = "LeftArm"
	solver.tip_bone = "LeftHand"
	solver.override_tip_basis = false
	solver.interpolation = 1.0
	skeleton.add_child(solver)
	solver.modification_processed.connect(_on_ik_processed)
	solver.target_node = solver.get_path_to(support_target)
	solver.max_iterations = 30
	solver.min_distance = 0.001
	animation.play("PistolAimWalk")
	animation.advance(0.4)
	ready_ok = true
	update_mount()
	solver.start()

func update_mount() -> void:
	if not ready_ok:
		return
	var spine := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Spine2")).origin)
	var right := right_attachment.global_position
	var forward := right - spine
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()
	var basis := Basis(forward, Vector3.UP, forward.cross(Vector3.UP).normalized())
	rifle.global_transform = Transform3D(basis.scaled(Vector3.ONE * RIFLE_SCALE), right - basis * (RIGHT_GRIP * RIFLE_SCALE))
	support_target.global_position = rifle.to_global(SUPPORT_GRIP)

# Read the modified bone pose during the modifier callback; Godot restores the
# animation pose after modification, so normal-frame bone queries are misleading.
func _on_ik_processed() -> void:
	solved_hand = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin)
	solved_elbow = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("LeftForeArm")).origin)
	solved_root = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("LeftArm")).origin)
	solved_target = support_target.global_position
	solved_frames += 1

func _process(_delta: float) -> void:
	update_mount()
