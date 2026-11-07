class_name SoldierRagdoll
extends RefCounted
## Builds a constrained PhysicalBone ragdoll from an imported Skeleton3D.
## Corpses collide with terrain only, sleep quickly, and keep their final pose.

const CORPSE_LAYER: int = 16
const TERRAIN_MASK: int = 1
const BONES: Array[String] = [
	"Hips", "Torso", "Head",
	"LegL", "KneeL", "LegR", "KneeR",
	"ArmL", "ElbowL", "ArmR", "ElbowR"
]
const MASS: Dictionary = {
	"Hips": 12.0, "Torso": 18.0, "Head": 5.0,
	"LegL": 7.0, "KneeL": 4.5, "LegR": 7.0, "KneeR": 4.5,
	"ArmL": 3.0, "ElbowL": 2.0, "ArmR": 3.0, "ElbowR": 2.0
}

static func build(skeleton: Skeleton3D) -> PhysicalBoneSimulator3D:
	var simulator := PhysicalBoneSimulator3D.new()
	simulator.name = "RagdollSimulator"
	skeleton.add_child(simulator)
	for bone_name in BONES:
		var index: int = skeleton.find_bone(bone_name)
		if index < 0:
			continue
		var body := PhysicalBone3D.new()
		body.name = "PB_" + bone_name
		body.bone_name = bone_name
		body.collision_layer = CORPSE_LAYER
		body.collision_mask = TERRAIN_MASK
		body.mass = float(MASS.get(bone_name, 4.0))
		body.friction = 0.85
		body.bounce = 0.02
		body.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		body.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		body.linear_damp = 0.35
		body.angular_damp = 0.65
		body.can_sleep = true
		var child_indices: PackedInt32Array = skeleton.get_bone_children(index)
		var offset := Transform3D.IDENTITY
		var shape: Shape3D
		if bone_name == "Head":
			var head := SphereShape3D.new()
			head.radius = 0.13
			shape = head
			offset.origin = Vector3(0, 0.08, 0)
		elif child_indices.is_empty():
			var box := BoxShape3D.new()
			box.size = Vector3(0.12, 0.16, 0.12)
			shape = box
			offset.origin = Vector3(0, -0.08, 0)
		else:
			var child_rest: Transform3D = skeleton.get_bone_rest(child_indices[0])
			var direction: Vector3 = child_rest.origin
			var length: float = maxf(direction.length(), 0.12)
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.09 if bone_name.begins_with("Arm") or bone_name.begins_with("Elbow") else 0.12
			capsule.height = length + capsule.radius * 1.5
			shape = capsule
			offset.origin = direction * 0.5
		body.body_offset = offset
		if bone_name == "Hips":
			body.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		elif bone_name == "KneeL" or bone_name == "KneeR" or bone_name == "ElbowL" or bone_name == "ElbowR":
			body.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			body.set("joint_constraints/angular_limit_enabled", true)
			body.set("joint_constraints/angular_limit_upper", 5.0)
			body.set("joint_constraints/angular_limit_lower", -110.0)
			body.set("joint_constraints/angular_limit_bias", 0.3)
			body.set("joint_constraints/angular_limit_softness", 0.8)
		else:
			body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			body.set("joint_constraints/swing_span", 40.0 if bone_name == "Torso" else 65.0)
			body.set("joint_constraints/twist_span", 25.0)
			body.set("joint_constraints/bias", 0.3)
			body.set("joint_constraints/softness", 0.8)
			body.set("joint_constraints/relaxation", 1.0)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		if shape is CapsuleShape3D and not child_indices.is_empty():
			var direction: Vector3 = skeleton.get_bone_rest(child_indices[0]).origin
			if direction.length_squared() > 0.0001:
				collision.rotation_quaternion = Quaternion(Vector3.UP, direction.normalized())
		body.add_child(collision)
		simulator.add_child(body)
	simulator.active = true
	return simulator

static func start(simulator: PhysicalBoneSimulator3D, impulse: Vector3, hit_point: Vector3) -> void:
	if simulator == null:
		return
	simulator.physical_bones_start_simulation()
	var chest: PhysicalBone3D = _find_body(simulator, "Torso")
	var hips: PhysicalBone3D = _find_body(simulator, "Hips")
	if chest:
		chest.apply_central_impulse(impulse * 0.65)
		chest.apply_impulse(impulse * 0.35, hit_point - chest.global_position)
	if hips:
		hips.apply_central_impulse(impulse * 0.35)

static func settle(simulator: PhysicalBoneSimulator3D) -> void:
	if simulator == null:
		return
	simulator.physical_bones_stop_simulation()
	for child in simulator.get_children():
		var body: PhysicalBone3D = child as PhysicalBone3D
		if body:
			body.set_deferred("collision_layer", 0)
			body.set_deferred("collision_mask", 0)

static func _find_body(simulator: PhysicalBoneSimulator3D, bone_name: String) -> PhysicalBone3D:
	for child in simulator.get_children():
		var body: PhysicalBone3D = child as PhysicalBone3D
		if body and body.bone_name == bone_name:
			return body
	return null
