extends "res://scripts/environment/hospital_geometry.gd"
## Apartment district on the existing city lanes. Architecture, trees, and
## parked cars are visual-only; only the ground and defense walls collide.

const CARS: Array[Vector3] = [Vector3(-20.0, 0, -69), Vector3(20.0, 0, -69)]
const TREES: Array[Vector3] = [Vector3(-29.0, 0, -105), Vector3(29.0, 0, -105)]


func _ready() -> void:
	_setup_materials()
	(materials["concrete"] as StandardMaterial3D).albedo_color = Color(0.48, 0.47, 0.44)
	(materials["red"] as StandardMaterial3D).albedo_color = Color(0.46, 0.31, 0.23)
	(materials["road"] as StandardMaterial3D).albedo_color = Color(0.65, 0.65, 0.62)
	_textured("road", "residential_asphalt", Vector3(18, 22, 1))
	materials["apartment"] = _material(Color(0.80, 0.77, 0.69))
	_textured("apartment", "district_facade_detail", Vector3(3, 3, 1))
	materials["apartment_trim"] = _material(Color(0.32, 0.29, 0.26))
	materials["apartment_window"] = _material(Color(0.10, 0.16, 0.17), 0.15)
	materials["apartment_warm"] = _material(Color(0.68, 0.44, 0.26))
	materials["leaf"] = _material(Color(0.23, 0.32, 0.19))
	materials["trunk"] = _material(Color(0.29, 0.23, 0.17))
	materials["car"] = _material(Color(0.32, 0.39, 0.36), 0.15)
	materials["car_second"] = _material(Color(0.52, 0.35, 0.26), 0.15)
	_box("ResidentialGround", Vector3(0, -0.25, -77), Vector3(150, 0.5, 190), "road", true)
	_box("ResidentialPlatform", Vector3(0, 1.9, 5), Vector3(31, 3.8, 16), "concrete", true)
	_box("ResidentialPlatformTop", Vector3(0, 3.95, 5), Vector3(32, 0.1, 16), "concrete")
	_defenses()
	_apartment_block()


func _defenses() -> void:
	_wall_segment("WestWallFar", -16.8, -39.0, 18.0)
	_wall_segment("WestWallNear", -16.8, -12.0, 22.0)
	_wall_segment("EastWallFar", 16.65, -35.25, 25.5)
	_wall_segment("EastWallNear", 16.65, -7.0, 17.0)
	_box("WallPatch", Vector3(-16.8, 1.9, -26.5), Vector3(0.6, 3.8, 7), "trim")
	_box("GateLeafA", Vector3(16.65, 2.1, -20.75), Vector3(0.4, 4.2, 3.5), "trim")
	_box("GateLeafB", Vector3(16.65, 2.1, -17.25), Vector3(0.4, 4.2, 3.5), "trim")
	for side: int in [-1, 1]:
		var z: float = -26.5 if side < 0 else -19.0
		_box("ResidentialGateHeader%d" % side, Vector3(side * 16.7, 4.5, z), Vector3(0.8, 0.6, 8), "apartment_warm")
		for offset: float in [-3.7, 3.7]:
			_box("ResidentialGatePost%d_%s" % [side, offset], Vector3(side * 16.7, 2.0, z + offset), Vector3(0.8, 4, 0.35), "concrete")


func _apartment_block() -> void:
	var walls: Array[Transform3D] = []
	var windows: Array[Transform3D] = []
	var trim: Array[Transform3D] = []
	var balcony: Array[Transform3D] = []
	var warm: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	var car_a: Array[Transform3D] = []
	var car_b: Array[Transform3D] = []
	var car_glass: Array[Transform3D] = []
	var tires: Array[Transform3D] = []
	# Rear housing sits behind all spawn positions; details face the player.
	for x: float in [-25.0, 0.0, 25.0]:
		_detail(walls, Vector3(x, 19, -153), Vector3(23, 38, 3))
		_detail(trim, Vector3(x, 38.3, -152), Vector3(24, 0.65, 4))
		for floor_index: int in 7:
			var y: float = 4.3 + floor_index * 4.8
			_detail(trim, Vector3(x, y - 1.9, -151.35), Vector3(22, 0.22, 0.22))
			for col: int in 4:
				var wx: float = x - 8.1 + col * 5.4
				_detail(windows, Vector3(wx, y, -151.35), Vector3(3.0, 2.7, 0.12))
				_detail(trim, Vector3(wx, y, -151.22), Vector3(0.12, 2.7, 0.15))
			if floor_index > 0:
				_detail(balcony, Vector3(x, y - 1.5, -150.5), Vector3(8, 0.22, 2.0))
				_detail(trim, Vector3(x, y - 0.75, -149.55), Vector3(8, 0.12, 0.12))
				for post: int in 5:
					_detail(trim, Vector3(x - 3.8 + post * 1.9, y - 1.1, -149.55), Vector3(0.10, 0.9, 0.10))
	# Two side blocks frame the street and have windows on their visible ends.
	for side: int in [-1, 1]:
		var sx: float = side * 39.0
		_detail(walls, Vector3(sx, 15, -99), Vector3(15, 30, 32))
		_detail(trim, Vector3(sx, 30.3, -99), Vector3(16, 0.6, 33))
		for floor_index: int in 5:
			var y: float = 5.0 + floor_index * 5.0
			for col: int in 3:
				var x: float = sx - 4.5 + col * 4.5
				_detail(windows, Vector3(x, y, -82.95), Vector3(2.8, 2.9, 0.12))
				_detail(warm, Vector3(x, y - 1.75, -82.7), Vector3(3.2, 0.25, 0.45))
			for col: int in 4:
				var z: float = -111.0 + col * 7.0
				_detail(windows, Vector3(side * 31.45, y, z), Vector3(0.12, 2.9, 3.2))
				_detail(balcony, Vector3(side * 31.0, y - 1.6, z), Vector3(1.0, 0.18, 3.6))
		_detail(windows, Vector3(sx, 2.1, -82.8), Vector3(3.8, 4.1, 0.15))
		_detail(warm, Vector3(sx, 4.35, -81.8), Vector3(7.5, 0.25, 2.4))
	for at: Vector3 in TREES:
		_detail(trunks, at + Vector3(0, 2.3, 0), Vector3(0.7, 4.6, 0.7))
		_detail(leaves, at + Vector3(0, 6.0, 0), Vector3(4.3, 4.5, 4.3))
		_detail(leaves, at + Vector3(1.3, 5.6, 0), Vector3(2.8, 3.0, 3.0))
	for index: int in CARS.size():
		var at: Vector3 = CARS[index]
		var body: Array[Transform3D] = car_a if index == 0 else car_b
		_detail(body, at + Vector3(0, 1.0, 0), Vector3(3.1, 1.15, 6.3))
		_detail(body, at + Vector3(0, 1.7, -0.5), Vector3(2.8, 0.8, 2.8))
		_detail(car_glass, at + Vector3(0, 1.75, 0.95), Vector3(2.6, 0.65, 0.08))
		for side: int in [-1, 1]:
			for z: float in [-1.9, 1.9]:
				_detail(tires, at + Vector3(side * 1.55, 0.55, z), Vector3(0.35, 1.0, 1.0))
		_detail(warm, at + Vector3(0, 0.95, 3.18), Vector3(2.6, 0.2, 0.07))
	_batch_boxes("ResidentialFacades", walls, materials["apartment"])
	_batch_boxes("ResidentialWindows", windows, materials["apartment_window"])
	_batch_boxes("ResidentialTrim", trim, materials["apartment_trim"])
	_batch_boxes("ResidentialBalconies", balcony, materials["concrete"])
	_batch_boxes("ResidentialAccents", warm, materials["apartment_warm"])
	_batch_boxes("ResidentialTrunks", trunks, materials["trunk"])
	_batch_boxes("ResidentialCarA", car_a, materials["car"])
	_batch_boxes("ResidentialCarB", car_b, materials["car_second"])
	_batch_boxes("ResidentialCarGlass", car_glass, materials["apartment_window"])
	_batch_boxes("ResidentialCarTires", tires, materials["rubber"])
	var foliage := SphereMesh.new()
	foliage.radius = 0.5
	foliage.height = 1.0
	foliage.radial_segments = 10
	foliage.rings = 5
	_batch_mesh("ResidentialFoliage", leaves, foliage, materials["leaf"])


func _detail(items: Array[Transform3D], at: Vector3, size: Vector3) -> void:
	items.append(Transform3D(Basis.from_scale(size), at))


func _batch_boxes(batch_name: String, items: Array[Transform3D], material: Material) -> void:
	_batch_mesh(batch_name, items, BoxMesh.new(), material)


func _batch_mesh(batch_name: String, items: Array[Transform3D], mesh: PrimitiveMesh, material: Material) -> void:
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = items.size()
	for index: int in items.size():
		multi.set_instance_transform(index, items[index])
	var node := MultiMeshInstance3D.new()
	node.name = batch_name
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
