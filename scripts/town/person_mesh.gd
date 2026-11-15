class_name PersonMesh
extends RefCounted
## A small, shared character rig: torso, head, two legs and two arms on pivots.
## The pivots are returned as metadata so whoever owns the character can drive
## the walk cycle, the idle sway and the carrying pose.

const SHIRTS: Array[Color] = [
	Color(0.86, 0.32, 0.28), Color(0.24, 0.44, 0.78), Color(0.94, 0.76, 0.3),
	Color(0.34, 0.66, 0.48), Color(0.72, 0.46, 0.8),
]
const SKIN: Array[Color] = [
	Color(0.96, 0.8, 0.66), Color(0.8, 0.6, 0.46), Color(0.6, 0.42, 0.3),
]
const PANTS: Array[Color] = [
	Color(0.24, 0.26, 0.32), Color(0.32, 0.3, 0.26), Color(0.2, 0.26, 0.36),
]


## `crew` is the fixed cast index; every member keeps the same colours so the
## player starts recognising the cashier or the mechanic.
static func build(crew: int) -> Node3D:
	var agent := Node3D.new()
	agent.name = "Person%d" % crew
	agent.set_meta("crew", crew)

	var shirt: Color = SHIRTS[crew % SHIRTS.size()]
	var skin: Color = SKIN[crew % SKIN.size()]
	var pants: Color = PANTS[crew % PANTS.size()]

	var legs := Node3D.new()
	legs.position.y = 0.34
	agent.add_child(legs)
	var leg_pivots: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position.x = 0.075 * side
		legs.add_child(pivot)
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.11, 0.32, 0.13)
		leg.mesh = leg_mesh
		leg.material_override = flat(pants)
		leg.position.y = -0.16
		pivot.add_child(leg)
		leg_pivots.append(pivot)

	var body := MeshInstance3D.new()
	var torso := CapsuleMesh.new()
	torso.radius = 0.16
	torso.height = 0.54
	body.mesh = torso
	body.material_override = flat(shirt)
	body.position.y = 0.66
	agent.add_child(body)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.115
	sphere.height = 0.25
	head.mesh = sphere
	head.material_override = flat(skin)
	head.position.y = 1.02
	agent.add_child(head)

	var arms := Node3D.new()
	arms.position.y = 0.78
	agent.add_child(arms)
	var arm_pivots: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position.x = 0.18 * side
		arms.add_child(pivot)
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.08, 0.3, 0.1)
		arm.mesh = arm_mesh
		arm.material_override = flat(shirt)
		arm.position.y = -0.15
		pivot.add_child(arm)
		arm_pivots.append(pivot)

	# A parcel the character only shows while carrying something out.
	var parcel := MeshInstance3D.new()
	var parcel_mesh := BoxMesh.new()
	parcel_mesh.size = Vector3(0.24, 0.2, 0.18)
	parcel.mesh = parcel_mesh
	parcel.material_override = flat(Color(0.78, 0.62, 0.36))
	parcel.position = Vector3(0, 0.74, 0.22)
	parcel.visible = false
	agent.add_child(parcel)

	agent.set_meta("legs", leg_pivots)
	agent.set_meta("arms", arm_pivots)
	agent.set_meta("parcel", parcel)
	return agent


## Drives every shared state from one call: `walk` 0 = standing, 1 = striding.
static func animate(agent: Node3D, phase: float, walk: float, carry: bool = false) -> void:
	var legs: Array = agent.get_meta("legs", [])
	for i in legs.size():
		var pivot: Node3D = legs[i]
		pivot.rotation.x = sin(phase + PI * float(i)) * 0.55 * walk
	var arms: Array = agent.get_meta("arms", [])
	for i in arms.size():
		var pivot: Node3D = arms[i]
		if carry:
			pivot.rotation.x = -1.25
		else:
			pivot.rotation.x = sin(phase + PI * float(i) + PI) * 0.45 * walk
	var parcel: MeshInstance3D = agent.get_meta("parcel")
	if parcel != null:
		parcel.visible = carry


static func flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material
