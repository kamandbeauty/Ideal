class_name BusinessDecor
extends RefCounted
## Roadside Empire 3D props: derelict junkyard lots (tires, crates, barricades)
## before unlocking, and bespoke themed equipment, 3D rooftop signs, yellow fuel
## pump canopies, locked pump padlocks and wash foam after unlocking!

const STAGE_LEVELS: Array[int] = [2, 3, 4, 5]


## Kept compatible with `test_decor.gd`: builds visible prop stages 2..5.
static func build_stage(id: String, stage: int, accent: Color = Color.WHITE) -> Node3D:
	var root := Node3D.new()
	root.name = "Stage%d" % stage
	var nights: Array[StandardMaterial3D] = []
	var col := accent if accent != Color.WHITE else BusinessData.accent(id)
	var bays := clampi(stage - 1, 1, BusinessData.max_bays(id))
	_populate_open_props(root, id, stage, bays, col, nights)
	root.set_meta("night_materials", nights)
	return root


## Derelict junkyard lot shown on every locked/unbuilt facility plot!
static func build_junkyard(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Junkyard_" + id
	var sand := VehicleMesh.paint(Color(0.84, 0.72, 0.52), 0.96, 0.0)
	var crate_mat := VehicleMesh.paint(Color(0.62, 0.44, 0.26), 0.90, 0.0)
	var tire_mat := VehicleMesh.paint(Color(0.16, 0.17, 0.20), 0.88, 0.04)
	var red_bar := VehicleMesh.paint(Color(0.88, 0.22, 0.20), 0.72, 0.05)
	var white_bar := VehicleMesh.paint(Color(0.96, 0.95, 0.92), 0.72, 0.05)
	var hazard := VehicleMesh.paint(Color(0.96, 0.78, 0.14), 0.70, 0.05)

	_box(root, sand, Vector3(0, 0.03, 0), Vector3(3.4, 0.05, 3.2), false)
	# Wooden crates & rubble piles.
	_box(root, crate_mat, Vector3(-0.95, 0.34, -0.75), Vector3(0.68, 0.68, 0.68))
	_box(root, crate_mat, Vector3(-0.22, 0.26, -0.85), Vector3(0.54, 0.52, 0.54))
	_box(root, crate_mat, Vector3(0.88, 0.28, -0.60), Vector3(0.60, 0.56, 0.56))
	# Stacks of old black tires!
	for tp in [Vector3(-0.7, 0.0, 0.45), Vector3(0.55, 0.0, 0.35), Vector3(1.05, 0.0, 0.75)]:
		for h in 3:
			_tire(root, tire_mat, tp + Vector3(0, 0.10 + float(h) * 0.15, 0))
	# Red-and-white construction barricades & yellow hazard tape along the front!
	for bx in [-0.85, 0.85]:
		_box(root, red_bar, Vector3(float(bx), 0.42, 1.28), Vector3(0.95, 0.16, 0.10))
		_box(root, white_bar, Vector3(float(bx), 0.42, 1.30), Vector3(0.42, 0.17, 0.11))
		_box(root, crate_mat, Vector3(float(bx) - 0.36, 0.22, 1.28), Vector3(0.08, 0.44, 0.08))
		_box(root, crate_mat, Vector3(float(bx) + 0.36, 0.22, 1.28), Vector3(0.08, 0.44, 0.08))
	_box(root, hazard, Vector3(0.0, 0.38, 1.28), Vector3(0.75, 0.06, 0.04))
	return root


## Full dressed facility props matching the player's current level & active bays.
static func build_facility(
	id: String, level: int, active_bays: int, night_materials: Array[StandardMaterial3D]
) -> Node3D:
	var root := Node3D.new()
	root.name = "FacilityDecor_" + id
	var stage := BusinessData.renovation_stage(level)
	_populate_open_props(root, id, stage, active_bays, BusinessData.accent(id), night_materials)
	return root


static func _populate_open_props(
	root: Node3D,
	id: String,
	stage: int,
	active_bays: int,
	accent: Color,
	nights: Array[StandardMaterial3D]
) -> void:
	# Bold 3D Rooftop Sign (GAS, WASH, AUTO, WC, BBQ, EV, HOTEL, CINEMA)!
	_rooftop_sign(root, BusinessData.sign_text(id), accent, stage, nights)

	var bay_off := BusinessData.bay_offset(id)
	var max_b := BusinessData.max_bays(id)
	if id == "gas_station" or id == "restaurant":
		_build_gas_props(root, stage, active_bays, max_b, bay_off, nights)
	elif id == "car_wash":
		_build_wash_props(root, stage, active_bays, bay_off, nights)
	elif id == "auto_service" or id == "workshop":
		_build_auto_props(root, stage, bay_off, nights)
	elif id == "toilets" or id == "store":
		_build_toilet_props(root, stage, accent, nights)
	elif id == "diner":
		_build_diner_props(root, stage, nights)
	elif id == "electric_charger":
		_build_ev_props(root, stage, active_bays, bay_off, nights)
	elif id == "motel":
		_build_motel_props(root, stage, nights)
	else:
		_build_cinema_props(root, stage, nights)


static func _rooftop_sign(
	root: Node3D, text: String, accent: Color, stage: int, nights: Array[StandardMaterial3D]
) -> void:
	var board_mat := _emissive(accent, nights, 0.85)
	var frame_mat := VehicleMesh.paint(Color(0.97, 0.96, 0.94), 0.35, 0.1)
	var y_top := 2.45 + float(stage >= 4) * 0.18
	_box(root, frame_mat, Vector3(0, y_top, 0.82), Vector3(1.95, 0.76, 0.22))
	_box(root, board_mat, Vector3(0, y_top, 0.85), Vector3(1.78, 0.60, 0.24))

	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 56
	lbl.pixel_size = 0.0085
	lbl.modulate = Color(1.0, 1.0, 1.0)
	lbl.outline_modulate = Color(0.14, 0.12, 0.18)
	lbl.outline_size = 10
	lbl.position = Vector3(0, y_top, 0.99)
	root.add_child(lbl)


static func _build_gas_props(
	root: Node3D,
	stage: int,
	active_bays: int,
	max_b: int,
	bay_off: Vector2,
	nights: Array[StandardMaterial3D]
) -> void:
	# Red rooftop propane cylinder + grey AC unit just like Screenshots 3 & 4!
	var red_tank := VehicleMesh.paint(Color(0.90, 0.22, 0.20), 0.45, 0.2)
	var ac_mat := VehicleMesh.paint(Color(0.54, 0.58, 0.66), 0.65, 0.2)
	var tank := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.36
	cyl.bottom_radius = 0.36
	cyl.height = 1.45
	tank.mesh = cyl
	tank.rotation_degrees.z = 90.0
	tank.material_override = red_tank
	tank.position = Vector3(-0.35, 2.35, -0.75)
	root.add_child(tank)
	_box(root, ac_mat, Vector3(0.75, 2.18, -0.55), Vector3(0.62, 0.36, 0.58))

	# Yellow single-post angled canopies for unlocked fuel pumps + dark padlocks for locked!
	var yellow := _emissive(Color(0.98, 0.82, 0.14), nights, 0.55)
	var pump_red := VehicleMesh.paint(Color(0.92, 0.30, 0.18), 0.45, 0.15)
	var post_grey := VehicleMesh.paint(Color(0.72, 0.74, 0.78), 0.5, 0.25)
	var lock_dark := VehicleMesh.paint(Color(0.18, 0.18, 0.22), 0.8, 0.1)

	for i in max_b:
		var offset_x := bay_off.x + (float(i) - float(max_b - 1) * 0.5) * 1.65
		var p := Vector3(offset_x, 0.0, bay_off.y)
		if i < active_bays:
			_box(root, post_grey, p + Vector3(0, 0.06, -0.55), Vector3(0.76, 0.10, 0.48), false)
			_box(root, pump_red, p + Vector3(0, 0.44, -0.55), Vector3(0.42, 0.68, 0.28))
			_box(root, post_grey, p + Vector3(0.24, 0.98, -0.55), Vector3(0.12, 1.75, 0.12))
			var canopy := _box(root, yellow, p + Vector3(-0.08, 1.84, -0.15), Vector3(1.15, 0.14, 1.55))
			canopy.rotation_degrees.z = 8.0
		else:
			_box(root, post_grey, p + Vector3(0, 0.05, -0.45), Vector3(0.68, 0.08, 0.52), false)
			_box(root, lock_dark, p + Vector3(0, 0.48, -0.45), Vector3(0.28, 0.78, 0.20))

	if stage >= 3:
		var glow := _emissive(Color(1.0, 0.58, 0.18), nights, 0.9)
		_box(root, glow, Vector3(0, 1.98, 1.24), Vector3(2.5, 0.09, 0.09), false)


static func _build_wash_props(
	root: Node3D, stage: int, active_bays: int, bay_off: Vector2, nights: Array[StandardMaterial3D]
) -> void:
	var cyan := _emissive(Color(0.14, 0.76, 0.90), nights, 0.7)
	var foam := VehicleMesh.paint(Color(0.97, 0.99, 1.0), 0.35, 0.0)
	for i in maxi(1, active_bays):
		var ox := bay_off.x + (float(i) - float(maxi(1, active_bays) - 1) * 0.5) * 1.65
		var p := Vector3(ox, 0.0, bay_off.y)
		_box(root, cyan, p + Vector3(-0.62, 0.95, 0), Vector3(0.16, 1.9, 0.24))
		_box(root, cyan, p + Vector3(0.62, 0.95, 0), Vector3(0.16, 1.9, 0.24))
		_box(root, cyan, p + Vector3(0, 1.88, 0), Vector3(1.42, 0.20, 0.30))
		# Sudsy foam bubbles!
		for b_i in 3:
			var bub := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.20 + float(b_i) * 0.04
			sph.height = sph.radius * 2.0
			bub.mesh = sph
			bub.material_override = foam
			bub.position = p + Vector3(-0.25 + float(b_i) * 0.25, 0.55 + float(b_i % 2) * 0.22, 0.15)
			root.add_child(bub)
	if stage >= 3:
		_box(root, cyan, Vector3(0, 2.05, 1.15), Vector3(2.3, 0.10, 0.10), false)


static func _build_auto_props(
	root: Node3D, stage: int, bay_off: Vector2, nights: Array[StandardMaterial3D]
) -> void:
	var yellow := _emissive(Color(0.96, 0.72, 0.16), nights, 0.6)
	var dark := VehicleMesh.paint(Color(0.18, 0.20, 0.24), 0.85, 0.1)
	var red_box := VehicleMesh.paint(Color(0.88, 0.24, 0.22), 0.5, 0.2)
	var p := Vector3(bay_off.x, 0.0, bay_off.y)
	_box(root, yellow, p + Vector3(-0.55, 0.85, -0.55), Vector3(0.16, 1.7, 0.16))
	_box(root, yellow, p + Vector3(-0.55, 0.85, 0.55), Vector3(0.16, 1.7, 0.16))
	_box(root, dark, p + Vector3(0.0, 0.12, 0.0), Vector3(1.4, 0.08, 0.9))
	_box(root, red_box, Vector3(0.95, 0.42, 1.15), Vector3(0.55, 0.82, 0.38))
	for h in (2 + mini(2, stage)):
		_tire(root, dark, Vector3(-1.05, 0.10 + float(h) * 0.15, 1.15))


static func _build_toilet_props(
	root: Node3D, _stage: int, accent: Color, nights: Array[StandardMaterial3D]
) -> void:
	var neon := _emissive(accent, nights, 0.9)
	var door := VehicleMesh.paint(Color(0.24, 0.56, 0.86), 0.6, 0.1)
	for i in 3:
		_box(root, door, Vector3(-0.65 + float(i) * 0.65, 0.72, 1.16), Vector3(0.46, 1.35, 0.08))
	_box(root, neon, Vector3(0, 1.85, 1.20), Vector3(1.9, 0.14, 0.12), false)


static func _build_diner_props(
	root: Node3D, stage: int, nights: Array[StandardMaterial3D]
) -> void:
	var smoker := VehicleMesh.paint(Color(0.16, 0.16, 0.20), 0.75, 0.25)
	var umbrella := _emissive(Color(0.94, 0.30, 0.26), nights, 0.55)
	var cream := VehicleMesh.paint(Color(0.97, 0.94, 0.86), 0.65, 0.0)
	_box(root, smoker, Vector3(-1.15, 0.48, 1.15), Vector3(0.85, 0.62, 0.52))
	_box(root, smoker, Vector3(-1.42, 1.05, 1.15), Vector3(0.12, 0.75, 0.12))
	for side in [-0.75, 0.75]:
		_box(root, cream, Vector3(float(side), 0.38, 1.65), Vector3(0.58, 0.08, 0.58))
		_box(root, umbrella, Vector3(float(side), 1.25, 1.65), Vector3(0.95, 0.14, 0.95))
	if stage >= 3:
		_box(root, umbrella, Vector3(0, 1.95, 1.20), Vector3(2.2, 0.12, 0.12), false)


static func _build_ev_props(
	root: Node3D, _stage: int, active_bays: int, bay_off: Vector2, nights: Array[StandardMaterial3D]
) -> void:
	var green_glow := _emissive(Color(0.20, 0.92, 0.56), nights, 1.1)
	var white_mat := VehicleMesh.paint(Color(0.95, 0.97, 0.98), 0.3, 0.15)
	for i in maxi(1, active_bays):
		var ox := bay_off.x + (float(i) - float(maxi(1, active_bays) - 1) * 0.5) * 1.55
		var p := Vector3(ox, 0.0, bay_off.y)
		_box(root, white_mat, p + Vector3(0, 0.62, -0.55), Vector3(0.38, 1.22, 0.22))
		_box(root, green_glow, p + Vector3(0, 0.72, -0.42), Vector3(0.22, 0.68, 0.05), false)


static func _build_motel_props(
	root: Node3D, _stage: int, nights: Array[StandardMaterial3D]
) -> void:
	var water := _emissive(Color(0.18, 0.78, 0.92), nights, 0.65)
	var rim := VehicleMesh.paint(Color(0.94, 0.92, 0.86), 0.6, 0.0)
	_box(root, rim, Vector3(0.0, 0.08, 1.85), Vector3(2.2, 0.14, 1.25), false)
	_box(root, water, Vector3(0.0, 0.16, 1.85), Vector3(1.88, 0.05, 0.95), false)


static func _build_cinema_props(
	root: Node3D, _stage: int, nights: Array[StandardMaterial3D]
) -> void:
	var screen_glow := _emissive(Color(0.92, 0.95, 1.0), nights, 1.0)
	var frame := VehicleMesh.paint(Color(0.22, 0.20, 0.30), 0.65, 0.2)
	_box(root, frame, Vector3(0.0, 1.85, -1.15), Vector3(3.1, 2.1, 0.18))
	_box(root, screen_glow, Vector3(0.0, 1.92, -1.03), Vector3(2.8, 1.75, 0.06), false)


static func _tire(parent: Node3D, mat: StandardMaterial3D, pos: Vector3) -> void:
	var inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.24
	cyl.bottom_radius = 0.24
	cyl.height = 0.14
	cyl.radial_segments = 10
	inst.mesh = cyl
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)


static func _emissive(
	color: Color, nights: Array[StandardMaterial3D], energy: float
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.38
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	nights.append(mat)
	return mat


static func _box(
	parent: Node3D,
	mat: StandardMaterial3D,
	pos: Vector3,
	size: Vector3,
	shadows: bool = true
) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	if not shadows:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst
