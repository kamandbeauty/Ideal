class_name DesertCanyon
extends RefCounted
## Builds the authentic Roadside Empire environment: warm golden canyon mesas,
## the diagonal two-lane highway along z = -6.8 with wooden fences & overhead
## telegraph wires, crosswalk driveways, saguaro cacti, red water tower and
## the paved concrete-curbed station forecourt!

const HIGHWAY_Z := -6.8
const HIGHWAY_WIDTH := 3.4
const HIGHWAY_LENGTH := 64.0


static func build_all(root: Node3D, town_id: String, night_materials: Array[StandardMaterial3D]) -> void:
	var canyon := Node3D.new()
	canyon.name = "DesertCanyon"
	root.add_child(canyon)

	_build_mesas(canyon, TownData.cliff_color(town_id))
	_build_highway(canyon, TownData.verge_color(town_id))
	_build_forecourt(canyon, TownData.verge_color(town_id))
	_build_poles_and_fences(canyon, night_materials)
	_build_landmarks(canyon, town_id)


static func _build_mesas(parent: Node3D, cliff_col: Color) -> void:
	var mat_base := SurfaceMaterials.textured("sand", cliff_col.darkened(0.24), Vector2(3, 2))
	var mat_mid := VehicleMesh.paint(cliff_col.darkened(0.12), 0.92, 0.0)
	var mat_cap := VehicleMesh.paint(cliff_col, 0.90, 0.0)

	# Upper-horizon canyon wall behind the highway (z < -11), plus side buttes.
	var specs := [
		Vector4(-22.0, -15.5, 11.0, 5.4),
		Vector4(-12.5, -14.8, 9.5, 6.8),
		Vector4(-3.5, -15.2, 10.5, 7.6),
		Vector4(6.5, -14.6, 11.0, 6.4),
		Vector4(16.5, -15.0, 11.5, 5.8),
		Vector4(25.0, -14.2, 10.0, 4.8),
		Vector4(-16.5, -6.0, 6.0, 3.8),
		Vector4(17.5, -4.5, 6.5, 4.2),
	]
	for s in specs:
		var cx := float(s.x)
		var cz := float(s.y)
		var w := float(s.z)
		var h := float(s.w)
		_box(parent, mat_base, Vector3(cx, h * 0.28, cz), Vector3(w, h * 0.56, 6.2))
		_box(parent, mat_mid, Vector3(cx + 0.3, h * 0.64, cz + 0.2), Vector3(w * 0.78, h * 0.42, 4.8))
		_box(parent, mat_cap, Vector3(cx - 0.2, h * 0.92, cz + 0.1), Vector3(w * 0.54, h * 0.24, 3.4))


static func _build_highway(parent: Node3D, verge_col: Color) -> void:
	var asphalt := SurfaceMaterials.textured("asphalt", Color(0.39, 0.43, 0.45), Vector2(32, 1.7))
	var verge := VehicleMesh.paint(verge_col, 0.92, 0.0)
	var curb := VehicleMesh.paint(Color(0.80, 0.78, 0.72), 0.88, 0.0)
	var dash_mat := VehicleMesh.paint(Color(0.78, 0.75, 0.58), 0.75, 0.0)

	# Grass verges flanking the highway.
	_box(parent, verge, Vector3(0.0, 0.015, HIGHWAY_Z - 2.35), Vector3(HIGHWAY_LENGTH, 0.03, 1.4), false)
	_box(parent, verge, Vector3(0.0, 0.015, HIGHWAY_Z + 2.35), Vector3(HIGHWAY_LENGTH, 0.03, 1.4), false)
	# Highway tarmac & concrete edge curbs.
	_box(parent, asphalt, Vector3(0.0, 0.03, HIGHWAY_Z), Vector3(HIGHWAY_LENGTH, 0.05, HIGHWAY_WIDTH), false)
	_box(parent, curb, Vector3(0.0, 0.055, HIGHWAY_Z - 1.75), Vector3(HIGHWAY_LENGTH, 0.06, 0.14), false)
	_box(parent, curb, Vector3(-22.0, 0.055, HIGHWAY_Z + 1.75), Vector3(15.0, 0.06, 0.14), false)
	_box(parent, curb, Vector3(22.0, 0.055, HIGHWAY_Z + 1.75), Vector3(15.0, 0.06, 0.14), false)

	# Crisp white dashed center line along the highway.
	for i in 28:
		var dx := -27.0 + float(i) * 2.0
		_box(parent, dash_mat, Vector3(dx, 0.062, HIGHWAY_Z), Vector3(0.95, 0.015, 0.10), false)


static func _build_forecourt(parent: Node3D, verge_col: Color) -> void:
	ForecourtDressing.build(parent, verge_col)


static func _build_poles_and_fences(parent: Node3D, night_materials: Array[StandardMaterial3D]) -> void:
	var wood := VehicleMesh.paint(Color(0.56, 0.36, 0.20), 0.92, 0.0)
	var wire := VehicleMesh.paint(Color(0.14, 0.14, 0.16), 0.85, 0.0)
	var pole_metal := VehicleMesh.paint(Color(0.46, 0.48, 0.62), 0.55, 0.25)
	var lamp_glow := StandardMaterial3D.new()
	lamp_glow.albedo_color = Color(1.0, 0.95, 0.78)
	lamp_glow.emission_enabled = true
	lamp_glow.emission = Color(1.0, 0.90, 0.62)
	lamp_glow.emission_energy_multiplier = 0.0
	night_materials.append(lamp_glow)

	# Wooden roadside split-rail fences along the back of the highway.
	for i in 12:
		var fx := -16.5 + float(i) * 3.0
		_box(parent, wood, Vector3(fx, 0.34, HIGHWAY_Z - 2.05), Vector3(0.12, 0.68, 0.12))
		_box(parent, wood, Vector3(fx + 1.5, 0.34, HIGHWAY_Z - 2.05), Vector3(0.12, 0.68, 0.12))
		_box(parent, wood, Vector3(fx + 0.75, 0.52, HIGHWAY_Z - 2.05), Vector3(1.55, 0.08, 0.06))
		_box(parent, wood, Vector3(fx + 0.75, 0.28, HIGHWAY_Z - 2.05), Vector3(1.55, 0.08, 0.06))

	# Iconic Roadside Empire utility poles + draped overhead wires across the top!
	var pole_xs: Array[float] = [-15.0, -9.5, -4.0, 1.5, 7.0, 12.5]
	for i in pole_xs.size():
		var px := pole_xs[i]
		_box(parent, wood, Vector3(px, 2.1, HIGHWAY_Z - 2.6), Vector3(0.16, 4.2, 0.16))
		_box(parent, wood, Vector3(px, 3.85, HIGHWAY_Z - 2.6), Vector3(1.1, 0.10, 0.12))
		if i < pole_xs.size() - 1:
			var nx := pole_xs[i + 1]
			var mid_x := (px + nx) * 0.5
			var span := nx - px
			for w_off in [-0.42, 0.42]:
				_box(
					parent,
					wire,
					Vector3(mid_x, 3.72, HIGHWAY_Z - 2.6 + float(w_off)),
					Vector3(span, 0.035, 0.035),
					false
				)

	# Forecourt purple-grey street lamps.
	for lp in [Vector3(-8.1, 0, -2.5), Vector3(8.1, 0, -2.5), Vector3(8.1, 0, 6.0), Vector3(-8.1, 0, 6.0)]:
		_box(parent, pole_metal, lp + Vector3(0, 1.35, 0), Vector3(0.11, 2.7, 0.11))
		_box(parent, pole_metal, lp + Vector3(0.28, 2.68, 0), Vector3(0.65, 0.09, 0.11))
		_box(parent, lamp_glow, lp + Vector3(0.52, 2.60, 0), Vector3(0.24, 0.08, 0.18), false)


static func _build_landmarks(parent: Node3D, _town_id: String) -> void:
	# Red water tower in the upper-left corner (signature Roadside Empire prop!).
	var red_steel := VehicleMesh.paint(Color(0.86, 0.30, 0.22), 0.65, 0.2)
	var cap_col := VehicleMesh.paint(Color(0.76, 0.74, 0.72), 0.6, 0.25)
	var wt := Vector3(-12.4, 0.0, -3.2)
	for lx in [-0.55, 0.55]:
		for lz in [-0.55, 0.55]:
			_box(parent, red_steel, wt + Vector3(float(lx), 1.3, float(lz)), Vector3(0.12, 2.6, 0.12))
	var tank := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.92
	cyl.bottom_radius = 0.88
	cyl.height = 1.35
	tank.mesh = cyl
	tank.material_override = red_steel
	tank.position = wt + Vector3(0, 3.15, 0)
	parent.add_child(tank)
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.08
	cone.bottom_radius = 1.02
	cone.height = 0.55
	roof.mesh = cone
	roof.material_override = cap_col
	roof.position = wt + Vector3(0, 4.08, 0)
	parent.add_child(roof)

	# Saguaro cacti & orange dumpsters around the desert station!
	var cactus_spots := [
		Vector3(12.2, 0, 0.6),
		Vector3(12.5, 0, 7.2),
		Vector3(-12.2, 0, 3.5),
		Vector3(-12.0, 0, 11.4),
		Vector3(12.2, 0, 15.5),
		Vector3(-4.2, 0, -9.2),
		Vector3(3.4, 0, -9.4),
		Vector3(9.8, 0, -9.0),
	]
	for cp in cactus_spots:
		_saguaro(parent, cp)

	var dump_mat := VehicleMesh.paint(Color(0.88, 0.52, 0.18), 0.78, 0.1)
	var lid_mat := VehicleMesh.paint(Color(0.18, 0.18, 0.22), 0.8, 0.05)
	for dp in [Vector3(6.2, 0, -2.2), Vector3(-6.2, 0, -2.2)]:
		_box(parent, dump_mat, dp + Vector3(0, 0.32, 0), Vector3(0.75, 0.62, 0.56))
		_box(parent, lid_mat, dp + Vector3(0, 0.65, 0), Vector3(0.78, 0.07, 0.58))


static func _saguaro(parent: Node3D, at: Vector3) -> void:
	var green := VehicleMesh.paint(Color(0.36, 0.68, 0.24), 0.86, 0.0)
	_box(parent, green, at + Vector3(0, 0.78, 0), Vector3(0.28, 1.56, 0.28))
	_box(parent, green, at + Vector3(0.26, 0.82, 0), Vector3(0.28, 0.18, 0.22))
	_box(parent, green, at + Vector3(0.36, 1.08, 0), Vector3(0.20, 0.58, 0.20))
	_box(parent, green, at + Vector3(-0.24, 0.64, 0), Vector3(0.26, 0.18, 0.22))
	_box(parent, green, at + Vector3(-0.34, 0.88, 0), Vector3(0.20, 0.48, 0.20))


static func _box(
	parent: Node3D, mat: StandardMaterial3D, pos: Vector3, size: Vector3, shadows: bool = true
) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = StylizedMesh.box(size, minf(0.10, minf(size.x, minf(size.y, size.z)) * 0.15))
	inst.material_override = mat
	inst.position = pos
	if not shadows:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst
