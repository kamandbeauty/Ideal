class_name DesertCanyon
extends RefCounted
## The hub's scenery builder keeps its legacy name for scene compatibility.
## Art direction is now a sunny toy-town: lime lawns, white kerbs, orange roofs,
## faceted trees and cool roads. No new prop occupies a drivable envelope.

const HIGHWAY_Z := -6.8
const HIGHWAY_WIDTH := 3.4
const HIGHWAY_LENGTH := 64.0


static func build_all(root: Node3D, town_id: String, night_materials: Array[StandardMaterial3D]) -> void:
	var scenery := Node3D.new()
	scenery.name = "CartoonNeighborhood"
	root.add_child(scenery)
	_build_highway(scenery, TownData.verge_color(town_id))
	ForecourtDressing.build(scenery, TownData.verge_color(town_id))
	_build_neighborhood(scenery, town_id)
	_build_lamps(scenery, night_materials)
	_build_landmarks(scenery)


static func _build_highway(parent: Node3D, verge_col: Color) -> void:
	var asphalt := SurfaceMaterials.textured("asphalt", CartoonPalette.ASPHALT, Vector2(32, 1.7))
	var verge := VehicleMesh.paint(verge_col, 0.95, 0.0)
	var curb := VehicleMesh.paint(CartoonPalette.WHITE, 0.95, 0.0)
	for side in [-1.0, 1.0]:
		_box(
			parent, verge, Vector3(0, 0.015, HIGHWAY_Z + float(side) * 2.35), Vector3(HIGHWAY_LENGTH, 0.03, 1.4), false
		)
	_box(parent, asphalt, Vector3(0, 0.03, HIGHWAY_Z), Vector3(HIGHWAY_LENGTH, 0.05, HIGHWAY_WIDTH), false)
	_box(parent, curb, Vector3(0, 0.055, HIGHWAY_Z - 1.75), Vector3(HIGHWAY_LENGTH, 0.05, 0.12), false)
	for x in [-22.0, 22.0]:
		_box(parent, curb, Vector3(float(x), 0.055, HIGHWAY_Z + 1.75), Vector3(15, 0.05, 0.12), false)
	for i in 29:
		_box(parent, curb, Vector3(-28.0 + float(i) * 2.0, 0.066, HIGHWAY_Z), Vector3(0.90, 0.012, 0.09), false)


static func _build_neighborhood(parent: Node3D, town_id: String) -> void:
	var lawn := VehicleMesh.paint(TownData.verge_color(town_id), 0.95, 0.0)
	var kerb := VehicleMesh.paint(CartoonPalette.WHITE, 0.95, 0.0)
	SurfaceMaterials.paving(parent, "asphalt", CartoonPalette.ASPHALT, Vector3(0, 0.023, -14.0), Vector2(64.0, 3.4))
	for edge in [-1.0, 1.0]:
		_box(parent, kerb, Vector3(0, 0.045, -14.0 + float(edge) * 1.76), Vector3(64, 0.04, 0.11), false)
	# Repeated houses form a calm, low-poly backdrop instead of the orange cliff wall.
	for i in 7:
		var x := -25.5 + float(i) * 8.5
		_box(parent, kerb, Vector3(x, 0.026, -10.55), Vector3(7.55, 0.04, 3.14), false)
		_box(parent, lawn, Vector3(x, 0.050, -10.55), Vector3(7.36, 0.018, 2.95), false)
		var house := CartoonBuildings.cottage(i)
		house.position = Vector3(x, 0.045, -10.65)
		house.rotation_degrees.y = 180.0
		parent.add_child(house)
	for side in [-1.0, 1.0]:
		SurfaceMaterials.paving(
			parent, "asphalt", CartoonPalette.ASPHALT, Vector3(float(side) * 17.4, 0.02, 14), Vector2(3.2, 40)
		)
		for row in 3:
			var at := Vector3(float(side) * 13.3, 0.025, 6.0 + float(row) * 9.0)
			_box(parent, kerb, at, Vector3(4.2, 0.04, 6.3), false)
			_box(parent, lawn, at + Vector3(0, 0.023, 0), Vector3(4.0, 0.016, 6.1), false)
			var house := CartoonBuildings.cottage(row + 7)
			house.position = at + Vector3(0, 0.04, 0)
			house.rotation_degrees.y = -90.0 * float(side)
			parent.add_child(house)
	for i in 7:
		_tree(parent, Vector3(-24.0 + float(i) * 8.0, 0, -18.2), i)


static func _build_lamps(parent: Node3D, night_materials: Array[StandardMaterial3D]) -> void:
	var metal := VehicleMesh.paint(CartoonPalette.FOUNDATION, 0.9, 0.0)
	var lamp_glow := StandardMaterial3D.new()
	lamp_glow.albedo_color = CartoonPalette.WHITE
	lamp_glow.emission_enabled = true
	lamp_glow.emission = Color("#fff2ca")
	lamp_glow.emission_energy_multiplier = 0.0
	night_materials.append(lamp_glow)
	for lp in [Vector3(-8.1, 0, -2.5), Vector3(8.1, 0, -2.5), Vector3(8.1, 0, 6.0), Vector3(-8.1, 0, 6.0)]:
		_box(parent, metal, lp + Vector3(0, 0.13, 0), Vector3(0.28, 0.16, 0.28))
		_box(parent, metal, lp + Vector3(0, 1.35, 0), Vector3(0.10, 2.7, 0.10))
		_box(parent, metal, lp + Vector3(0.28, 2.68, 0), Vector3(0.65, 0.09, 0.14))
		_box(parent, lamp_glow, lp + Vector3(0.52, 2.61, 0), Vector3(0.27, 0.08, 0.20), false)


static func _build_landmarks(parent: Node3D) -> void:
	# The existing water tower is still a useful visual landmark in the green hub.
	var red := VehicleMesh.paint(CartoonPalette.ROOF_STRIPE, 0.95, 0.0)
	var cream := VehicleMesh.paint(CartoonPalette.FRAME, 0.95, 0.0)
	var wt := Vector3(-12.4, 0, -3.2)
	for x in [-0.55, 0.55]:
		for z in [-0.55, 0.55]:
			_box(parent, red, wt + Vector3(float(x), 1.3, float(z)), Vector3(0.12, 2.6, 0.12))
	var tank := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.92
	cylinder.bottom_radius = 0.88
	cylinder.height = 1.35
	cylinder.radial_segments = 12
	tank.mesh = cylinder
	tank.material_override = red
	tank.position = wt + Vector3(0, 3.15, 0)
	parent.add_child(tank)
	_box(parent, cream, wt + Vector3(0, 3.86, 0), Vector3(1.95, 0.12, 1.95))
	for i in 6:
		_tree(parent, Vector3(-20.0 + float(i) * 8.0, 0, -3.4), i + 1)
	var bin := VehicleMesh.paint(CartoonPalette.BLUE_DARK, 0.95, 0.0)
	for x in [-6.2, 6.2]:
		_box(parent, bin, Vector3(float(x), 0.30, -2.2), Vector3(0.57, 0.55, 0.44))
		_box(parent, cream, Vector3(float(x), 0.60, -2.2), Vector3(0.61, 0.06, 0.48))


static func _tree(parent: Node3D, at: Vector3, index: int) -> void:
	var wood := VehicleMesh.paint(Color("#99734e"), 0.95, 0.0)
	_box(parent, wood, at + Vector3(0, 0.58, 0), Vector3(0.20, 1.16, 0.20))
	for i in 2:
		var crown := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.30 if i == 1 else 0.56
		mesh.bottom_radius = 0.72 if i == 1 else 0.84
		mesh.height = 0.80
		mesh.radial_segments = 7
		crown.mesh = mesh
		crown.material_override = VehicleMesh.paint(
			CartoonPalette.LEAF if (i + index) % 2 == 0 else CartoonPalette.LEAF_DARK, 0.95, 0.0
		)
		crown.position = at + Vector3(0, 1.18 + float(i) * 0.57, 0)
		parent.add_child(crown)


static func _box(
	parent: Node3D, mat: StandardMaterial3D, pos: Vector3, size: Vector3, shadows: bool = true
) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = StylizedMesh.box(size, minf(0.06, minf(size.x, minf(size.y, size.z)) * 0.15))
	inst.material_override = mat
	inst.position = pos
	if not shadows:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst
