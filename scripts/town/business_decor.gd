class_name BusinessDecor
extends RefCounted
## Bespoke station equipment, aligned to the very same bays used by traffic.
## Warm metal, painted trim and small neon accents replace flat glowing blocks.

const STAGE_LEVELS: Array[int] = [2, 3, 4, 5]


static func build_stage(id: String, stage: int, accent: Color = Color.WHITE) -> Node3D:
	var nights: Array[StandardMaterial3D] = []
	var root := Node3D.new()
	var color := BusinessData.accent(id) if accent == Color.WHITE else accent
	_populate(root, id, stage, clampi(stage - 1, 1, BusinessData.max_bays(id)), color, nights)
	root.set_meta("night_materials", nights)
	return root


static func build_junkyard(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Junkyard_" + id
	var sand := SurfaceMaterials.textured("sand", Color(0.74, 0.64, 0.47))
	var wood := VehicleMesh.paint(Color(0.43, 0.29, 0.17), 0.95, 0.0)
	var plank := VehicleMesh.paint(Color(0.61, 0.45, 0.26), 0.9, 0.0)
	var tire := VehicleMesh.paint(Color(0.11, 0.13, 0.14), 0.95, 0.0)
	var red := VehicleMesh.paint(Color(0.70, 0.22, 0.16), 0.85, 0.0)
	var cream := VehicleMesh.paint(Color(0.79, 0.76, 0.62), 0.9, 0.0)
	_box(root, sand, Vector3(0, 0.045, 0), Vector3(3.4, 0.035, 3.2), false)
	for at in [Vector3(-0.95, 0.32, -0.65), Vector3(-0.20, 0.25, -0.8), Vector3(0.88, 0.28, -0.5)]:
		_box(root, plank, at, Vector3(0.60, at.y * 2, 0.56))
		for side in [-0.21, 0.21]:
			_box(root, wood, at + Vector3(float(side), 0, 0.289), Vector3(0.045, at.y * 2, 0.02), false)
		_box(root, wood, at + Vector3(0, 0, 0.30), Vector3(0.59, 0.06, 0.02), false)
	for at in [Vector3(-0.7, 0, 0.45), Vector3(0.55, 0, 0.35), Vector3(1.05, 0, 0.75)]:
		for h in 3:
			_tire(root, tire, at + Vector3(0, 0.10 + float(h) * 0.15, 0))
	for bx in [-0.85, 0.85]:
		var x := float(bx)
		_box(root, cream, Vector3(x, 0.42, 1.28), Vector3(0.95, 0.16, 0.10))
		for stripe in [-0.30, 0.0, 0.30]:
			var band := _box(root, red, Vector3(x + float(stripe), 0.42, 1.34), Vector3(0.12, 0.16, 0.014), false)
			band.rotation_degrees.z = -18.0
		for side in [-0.36, 0.36]:
			_box(root, wood, Vector3(x + float(side), 0.22, 1.28), Vector3(0.07, 0.44, 0.07))
	return root


static func build_facility(id: String, level: int, bays: int, nights: Array[StandardMaterial3D]) -> Node3D:
	var root := Node3D.new()
	root.name = "FacilityDecor_" + id
	_populate(root, id, BusinessData.renovation_stage(level), bays, BusinessData.accent(id), nights)
	return root


static func _populate(
	root: Node3D, id: String, stage: int, bays: int, accent: Color, nights: Array[StandardMaterial3D]
) -> void:
	_rooftop_sign(root, BusinessData.sign_text(id), accent, stage, nights)
	match id:
		"gas_station":
			_gas_roof(root)
			_equipment(root, id, bays, nights)
		"car_wash", "auto_service", "electric_charger":
			_equipment(root, id, bays, nights)
		"toilets":
			var door := VehicleMesh.paint(Color(0.16, 0.37, 0.43), 0.65, 0.0)
			for i in 3:
				_box(root, door, Vector3(-0.65 + float(i) * 0.65, 0.74, 1.06), Vector3(0.47, 1.32, 0.08))
		"diner":
			_diner(root, nights)
		"motel":
			_roof_pool(root, nights)
		"drive_in":
			var screen := _emissive(Color(0.58, 0.72, 0.75), nights, 0.6)
			_box(
				root, VehicleMesh.paint(Color(0.14, 0.18, 0.22), 0.8), Vector3(0, 2.75, -0.8), Vector3(3.1, 1.75, 0.16)
			)
			_box(root, screen, Vector3(0, 2.75, -0.7), Vector3(2.82, 1.48, 0.025), false)


static func _rooftop_sign(
	root: Node3D, text: String, color: Color, stage: int, nights: Array[StandardMaterial3D]
) -> void:
	var y := 2.45 + float(stage >= 4) * 0.22
	var metal := VehicleMesh.paint(Color(0.61, 0.64, 0.60), 0.5, 0.35)
	var panel := VehicleMesh.paint(color.darkened(0.22), 0.6, 0.0)
	var neon := _emissive(Color(0.97, 0.82, 0.52), nights, 0.55)
	for x in [-0.72, 0.72]:
		_box(root, metal, Vector3(float(x), y - 0.34, 0.78), Vector3(0.07, 0.60, 0.07))
	_box(root, metal, Vector3(0, y, 0.82), Vector3(2.0, 0.72, 0.18))
	_box(root, panel, Vector3(0, y, 0.93), Vector3(1.89, 0.61, 0.06))
	for side in [-1.0, 1.0]:
		_box(root, neon, Vector3(0, y + 0.30 * float(side), 0.975), Vector3(1.89, 0.025, 0.02), false)
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.008
	label.modulate = Color(0.98, 0.91, 0.70)
	label.outline_modulate = Color(0.10, 0.15, 0.18)
	label.outline_size = 5
	label.position = Vector3(0, y, 0.98)
	root.add_child(label)


static func _gas_roof(root: Node3D) -> void:
	var tank_mat := VehicleMesh.paint(Color(0.66, 0.23, 0.16), 0.55, 0.20)
	var tank := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.30
	cylinder.bottom_radius = 0.30
	cylinder.height = 1.35
	cylinder.radial_segments = 16
	tank.mesh = cylinder
	tank.rotation_degrees.z = 90.0
	tank.material_override = tank_mat
	tank.position = Vector3(-0.35, 2.32, -0.65)
	root.add_child(tank)
	var steel := VehicleMesh.paint(Color(0.38, 0.43, 0.45), 0.65, 0.35)
	_box(root, steel, Vector3(0.76, 2.20, -0.54), Vector3(0.58, 0.32, 0.52))
	for i in 5:
		_box(
			root,
			VehicleMesh.paint(Color(0.14, 0.19, 0.22), 0.85),
			Vector3(0.76, 2.37, -0.73 + float(i) * 0.09),
			Vector3(0.44, 0.018, 0.025),
			false
		)


static func _equipment(root: Node3D, id: String, bays: int, nights: Array[StandardMaterial3D]) -> void:
	var plot := BusinessData.plot(id)
	var steel := VehicleMesh.paint(Color(0.44, 0.48, 0.48), 0.5, 0.35)
	var cream := VehicleMesh.paint(Color(0.76, 0.76, 0.67), 0.6, 0.0)
	var dark := VehicleMesh.paint(Color(0.10, 0.15, 0.18), 0.65, 0.0)
	var accent := VehicleMesh.paint(BusinessData.accent(id).darkened(0.12), 0.55, 0.1)
	var glow := _emissive(BusinessData.accent(id).lightened(0.2), nights, 0.45)
	for i in bays:
		var world := ForecourtLayout.bay_position(id, i)
		var at := Vector3(world.x - plot.x, 0, ForecourtLayout.BAY_Z)
		if id == "gas_station":
			var pump := at + Vector3(-0.82, 0, -0.12)
			_box(root, cream, pump + Vector3(0, 0.07, 0), Vector3(0.24, 0.08, 0.54), false)
			_box(root, accent, pump + Vector3(0, 0.47, 0), Vector3(0.16, 0.76, 0.34))
			_box(root, dark, pump + Vector3(0, 0.63, 0.18), Vector3(0.16, 0.18, 0.025), false)
			_box(root, steel, pump + Vector3(0, 1.25, -0.10), Vector3(0.10, 2.15, 0.10))
			_box(
				root,
				VehicleMesh.paint(Color(0.83, 0.63, 0.20), 0.65, 0.1),
				at + Vector3(0, 2.22, 0),
				Vector3(1.62, 0.17, 2.15)
			)
			_box(root, glow, at + Vector3(0, 2.13, 0.8), Vector3(1.30, 0.025, 0.035), false)
		elif id == "car_wash" or id == "auto_service":
			for side in [-0.80, 0.80]:
				_box(root, accent, at + Vector3(float(side), 1.08, 0.12), Vector3(0.10, 2.12, 0.22))
			_box(root, cream, at + Vector3(0, 2.12, 0.12), Vector3(1.70, 0.18, 0.28))
			_box(root, glow, at + Vector3(0, 2.08, 0.28), Vector3(1.25, 0.035, 0.025), false)
			if id == "car_wash":
				for side in [-0.66, 0.66]:
					_box(
						root,
						VehicleMesh.paint(Color(0.13, 0.32, 0.37), 0.9, 0.0),
						at + Vector3(float(side), 0.58, -0.1),
						Vector3(0.08, 0.90, 0.34)
					)
		else:
			_box(root, cream, at + Vector3(-0.82, 0.69, 0), Vector3(0.16, 1.30, 0.32))
			_box(root, glow, at + Vector3(-0.82, 0.78, 0.18), Vector3(0.15, 0.52, 0.025), false)


static func _diner(root: Node3D, nights: Array[StandardMaterial3D]) -> void:
	var red := VehicleMesh.paint(Color(0.71, 0.25, 0.16), 0.70, 0.0)
	var cream := VehicleMesh.paint(Color(0.83, 0.78, 0.62), 0.8, 0.0)
	var dark := VehicleMesh.paint(Color(0.12, 0.15, 0.17), 0.8, 0.20)
	for x in [-0.75, 0.75]:
		_box(root, cream, Vector3(float(x), 0.38, 1.32), Vector3(0.54, 0.08, 0.45))
		_box(root, red, Vector3(float(x), 1.63, 1.22), Vector3(0.96, 0.12, 0.76))
		_box(root, dark, Vector3(float(x), 0.18, 1.32), Vector3(0.07, 0.36, 0.07))
	_box(root, dark, Vector3(-0.85, 2.35, -0.65), Vector3(0.15, 0.85, 0.15))
	_box(root, _emissive(Color(0.93, 0.56, 0.20), nights, 0.4), Vector3(0, 1.9, 1.12), Vector3(2.45, 0.04, 0.04), false)


static func _roof_pool(root: Node3D, nights: Array[StandardMaterial3D]) -> void:
	var rim := VehicleMesh.paint(Color(0.70, 0.74, 0.68), 0.7, 0.0)
	var water := _emissive(Color(0.14, 0.48, 0.58), nights, 0.4)
	_box(root, rim, Vector3(0, 2.12, -0.2), Vector3(2.0, 0.15, 1.28), false)
	_box(root, water, Vector3(0, 2.21, -0.2), Vector3(1.72, 0.03, 1.0), false)


static func _tire(parent: Node3D, mat: StandardMaterial3D, at: Vector3) -> void:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.11
	mesh.outer_radius = 0.25
	mesh.rings = 10
	mesh.ring_segments = 6
	instance.mesh = mesh
	instance.scale.y = 0.65
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)


static func _emissive(color: Color, nights: Array[StandardMaterial3D], energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.12)
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	nights.append(mat)
	return mat


static func _box(
	parent: Node3D, mat: StandardMaterial3D, at: Vector3, size: Vector3, shadows: bool = true
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = StylizedMesh.box(size, minf(0.035, minf(size.x, minf(size.y, size.z)) * 0.2))
	instance.material_override = mat
	instance.position = at
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
