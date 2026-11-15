extends Node3D
## A self-contained hospital district. Repeated windows share a MultiMesh;
## only the ground and permanent barriers need collision. Gate and patch
## projectile plates are owned by CityLevel and disappear on breach.

var materials: Dictionary = {}


func _ready() -> void:
	_setup_materials()
	_build_hospital()
	_build_shared_defenses()


func _setup_materials() -> void:
	materials["concrete"] = _material(Color(0.52, 0.53, 0.50))
	materials["wall"] = _material(Color(0.68, 0.69, 0.64))
	materials["trim"] = _material(Color(0.29, 0.34, 0.34))
	materials["glass"] = _material(Color(0.09, 0.16, 0.18), 0.35)
	materials["road"] = _material(Color(0.20, 0.22, 0.22))
	materials["red"] = _material(Color(0.58, 0.045, 0.035))
	materials["white"] = _material(Color(0.78, 0.79, 0.74))
	materials["yellow"] = _material(Color(0.82, 0.63, 0.24))
	materials["rubber"] = _material(Color(0.055, 0.055, 0.055))
	_textured("road", "asphalt", Vector3(35, 35, 1))
	_textured("concrete", "concrete", Vector3(4, 3, 1))
	_textured("wall", "plaster", Vector3(8, 4, 1))
	_textured("trim", "metal", Vector3(4, 2, 1))


func _build_hospital() -> void:
	_box("HospitalGround", Vector3(0, -0.25, -77), Vector3(150, 0.5, 190), "road", true)
	# The emergency building stands behind the entry routes, not across them.
	_box("HospitalMain", Vector3(0, 13, -151), Vector3(76, 26, 15), "wall", true)
	_box("HospitalRoof", Vector3(0, 26.5, -151), Vector3(78, 1, 17), "trim")
	_box("HospitalEntry", Vector3(0, 4.2, -141.8), Vector3(28, 8.4, 5), "trim")
	_box("EmergencySign", Vector3(0, 19.5, -143.25), Vector3(18, 6, 0.35), "white")
	_box("MedicalCrossVertical", Vector3(0, 19.5, -143.0), Vector3(1.6, 4.2, 0.16), "red")
	_box("MedicalCrossHorizontal", Vector3(0, 19.5, -142.9), Vector3(4.2, 1.6, 0.16), "red")
	_windows()
	# Weathered entrance canopy and structural features, all clear of paths.
	_box("EntranceCanopy", Vector3(0, 9.0, -138.8), Vector3(31, 0.7, 9), "concrete")
	for x: float in [-13.5, 13.5]:
		_box("CanopyPillar%s" % x, Vector3(x, 4.3, -135.0), Vector3(1, 8.6, 1), "concrete")
	for x: float in [-30.0, -22.0, 22.0, 30.0]:
		_box("FacadeColumn%s" % x, Vector3(x, 12, -143.35), Vector3(0.55, 23, 0.6), "concrete")
	for y: float in [4.5, 10.0, 15.3, 20.6]:
		_box("FacadeSill%s" % y, Vector3(0, y, -143.32), Vector3(73, 0.4, 0.5), "concrete")
	_box("EntranceDoors", Vector3(0, 3.0, -139.15), Vector3(10, 6.0, 0.15), "glass")
	_box("EntranceDoorMullion", Vector3(0, 3.0, -139.02), Vector3(0.35, 6, 0.15), "trim")
	# Two damaged wings frame the forecourt without blocking the avenue.
	_box("WestClinic", Vector3(-39, 7.5, -95), Vector3(14, 15, 38), "concrete", true)
	_box("EastClinic", Vector3(39, 7.5, -95), Vector3(14, 15, 38), "concrete", true)
	_box("WestClinicStripe", Vector3(-31.9, 7, -95), Vector3(0.2, 1.2, 36), "red")
	_box("EastClinicStripe", Vector3(31.9, 7, -95), Vector3(0.2, 1.2, 36), "red")
	for side: int in [-1, 1]:
		for index: int in 5:
			_box("ClinicWindow%d_%d" % [side, index], Vector3(side * 31.85, 10, -110 + index * 6), Vector3(0.2, 2.4, 2.7), "glass")
		_box("ClinicRoof%d" % side, Vector3(side * 39, 15.2, -95), Vector3(15, 0.6, 39), "trim")
	# Two ambulances frame the battlefield, away from the walkable center lanes.
	_ambulance(Vector3(-22.0, 0, -70), "WestAmbulance")
	_ambulance(Vector3(22.0, 0, -70), "EastAmbulance")
	for index: int in 8:
		_box("RoadMark%d" % index, Vector3(0, 0.02, -58.0 - index * 9.0), Vector3(0.25, 0.04, 4.2), "yellow")
	for index: int in 4:
		var x: float = -14.0 + index * 9.0
		_box("QuarantineBlock%d" % index, Vector3(x, 0.5, -49), Vector3(2.5, 1.0, 0.5), "concrete")
		_box("QuarantineWarning%d" % index, Vector3(x, 0.7, -48.7), Vector3(2.2, 0.28, 0.1), "yellow")
	# Small wreckage around the shoulders, not across the firing lanes.
	for side: int in [-1, 1]:
		for index: int in 4:
			_box("Debris%d_%d" % [side, index], Vector3(side * (24.0 + index * 1.4), 0.3, -50 - index * 8), Vector3(2.2, 0.6, 1.4), "concrete")


func _build_shared_defenses() -> void:
	# Defenses line the sides of the court with actual openings at gate and patch.
	_wall_segment("WestWallFar", -16.8, -39.0, 18.0)
	_wall_segment("WestWallNear", -16.8, -12.0, 22.0)
	_wall_segment("EastWallFar", 16.65, -35.25, 25.5)
	_wall_segment("EastWallNear", 16.65, -7.0, 17.0)
	_box("WallPatch", Vector3(-16.8, 1.9, -26.5), Vector3(0.6, 3.8, 7), "concrete")
	_box("GateLeafA", Vector3(16.65, 2.1, -20.75), Vector3(0.4, 4.2, 3.5), "trim")
	_box("GateLeafB", Vector3(16.65, 2.1, -17.25), Vector3(0.4, 4.2, 3.5), "trim")

func _textured(key: String, texture_name: String, scale: Vector3) -> void:
	var material: StandardMaterial3D = materials[key]
	material.albedo_texture = load("res://assets/textures/world/" + texture_name + ".jpg")
	material.uv1_scale = scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	material.metallic = metallic
	return material


func _box(part_name: String, at: Vector3, dimensions: Vector3, material_key: String, collidable: bool = false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.material_override = materials[material_key]
	part.position = at
	add_child(part)
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = dimensions
		shape.shape = box
		body.add_child(shape)
		part.add_child(body)
	return part


func _wall_segment(part_name: String, x: float, z: float, length: float) -> void:
	_box(part_name, Vector3(x, 2.3, z), Vector3(0.65, 4.6, length), "concrete", true)
	_box(part_name + "Stripe", Vector3(x - signf(x) * 0.38, 3.2, z), Vector3(0.10, 0.35, length - 0.1), "red")


func _windows() -> void:
	var windows := MultiMeshInstance3D.new()
	windows.name = "HospitalWindows"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.3, 2.4, 0.18)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 33
	for floor_index: int in 3:
		for col: int in 11:
			multi.set_instance_transform(floor_index * 11 + col, Transform3D(Basis.IDENTITY, Vector3(-32.0 + col * 6.4, 7.0 + floor_index * 5.3, -143.35)))
	windows.multimesh = multi
	windows.material_override = materials["glass"]
	add_child(windows)


func _ambulance(at: Vector3, prefix: String) -> void:
	_box(prefix + "Body", at + Vector3(0, 1.6, 0), Vector3(4.1, 2.5, 7.0), "white")
	_box(prefix + "Cab", at + Vector3(0, 2.35, 2.1), Vector3(3.8, 1.25, 2.4), "glass")
	_box(prefix + "Stripe", at + Vector3(0, 1.65, 0), Vector3(4.18, 0.46, 6.85), "red")
	_box(prefix + "Light", at + Vector3(0, 3.05, 1.8), Vector3(1.2, 0.2, 0.35), "red")
	for side: int in [-1, 1]:
		for front: int in [-1, 1]:
			_box(prefix + "Wheel%d%d" % [side, front], at + Vector3(side * 2.1, 0.65, front * 2.25), Vector3(0.5, 1.25, 1.25), "rubber")
		_box(prefix + "CrossV%d" % side, at + Vector3(side * 2.13, 2.35, -1.4), Vector3(0.08, 0.9, 0.3), "red")
		_box(prefix + "CrossH%d" % side, at + Vector3(side * 2.14, 2.35, -1.4), Vector3(0.08, 0.3, 0.9), "red")
