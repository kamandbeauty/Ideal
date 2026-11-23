extends "res://scripts/environment/hospital_geometry.gd"
## Factory yard using the existing defense contract. All yard architecture is
## decoration: no new collision or obstacles across the established routes.

func _ready() -> void:
	_setup_materials()
	(materials["concrete"] as StandardMaterial3D).albedo_color = Color(0.40, 0.39, 0.34)
	(materials["trim"] as StandardMaterial3D).albedo_color = Color(0.28, 0.24, 0.20)
	(materials["yellow"] as StandardMaterial3D).albedo_color = Color(0.78, 0.54, 0.14)
	_box("IndustrialGround", Vector3(0, -0.25, -77), Vector3(150, 0.5, 190), "road", true)
	# Same mount, gate and attack lines as the existing city level.
	_box("IndustrialPlatform", Vector3(0, 1.9, 5), Vector3(31, 3.8, 16), "concrete", true)
	_box("IndustrialPlatformTop", Vector3(0, 3.95, 5), Vector3(32, 0.1, 16), "concrete")
	_factory_defenses()
	_factory_yard()


func _factory_defenses() -> void:
	_wall_segment("WestWallFar", -16.8, -39.0, 18.0)
	_wall_segment("WestWallNear", -16.8, -12.0, 22.0)
	_wall_segment("EastWallFar", 16.65, -35.25, 25.5)
	_wall_segment("EastWallNear", 16.65, -7.0, 17.0)
	_box("WallPatch", Vector3(-16.8, 1.9, -26.5), Vector3(0.6, 3.8, 7), "trim")
	_box("GateLeafA", Vector3(16.65, 2.1, -20.75), Vector3(0.4, 4.2, 3.5), "trim")
	_box("GateLeafB", Vector3(16.65, 2.1, -17.25), Vector3(0.4, 4.2, 3.5), "trim")
	for side: int in [-1, 1]:
		var z: float = -26.5 if side < 0 else -19.0
		_box("FactoryGateHeader%d" % side, Vector3(side * 16.7, 4.5, z), Vector3(0.8, 0.6, 8), "yellow")
		for offset: float in [-3.7, 3.7]:
			_box("FactoryGatePost%d_%s" % [side, offset], Vector3(side * 16.7, 2.0, z + offset), Vector3(0.8, 4, 0.35), "trim")


## Large structures are behind the routes, with overhead gantries above head
## and projectile height. All repeated details are three fixed MultiMeshes.
func _factory_yard() -> void:
	var steel: Array[Transform3D] = []
	var caution: Array[Transform3D] = []
	var dark: Array[Transform3D] = []
	for side: int in [-1, 1]:
		var x: float = float(side)
		# Low warehouses frame the approach, leaving side route mouths open.
		_detail(steel, Vector3(x * 46, 7, -76), Vector3(16, 14, 22))
		_detail(dark, Vector3(x * 46, 6, -64.9), Vector3(9, 9, 0.15))
		_detail(caution, Vector3(x * 46, 12.3, -64.75), Vector3(12, 0.7, 0.2))
		for bay: int in 4:
			_detail(steel, Vector3(x * 46 + (bay - 1.5) * 2.3, 6, -64.65), Vector3(0.18, 8.5, 0.16))
		# Yard machinery is well off the central firing lane.
		for i: int in 3:
			_detail(dark, Vector3(x * (26.5 + float(i) * 2.0), 1.2, -103), Vector3(1.3, 2.4, 1.3))
			_detail(caution, Vector3(x * (26.5 + float(i) * 2.0), 1.9, -102.25), Vector3(1.1, 0.3, 0.12))
		for z: float in [-118.0, -103.0, -88.0]:
			_detail(steel, Vector3(x * 29, 9.0, z), Vector3(0.6, 18, 0.6))
			_detail(caution, Vector3(x * 29, 3.2, z + 0.35), Vector3(0.65, 0.8, 0.12))
		_detail(steel, Vector3(x * 29, 18.3, -103), Vector3(0.8, 0.8, 31))
		# Safety paint is flush to the ground and cannot obstruct enemies.
		for i: int in 8:
			_detail(caution, Vector3(x * 12.5, 0.012, -55.0 - i * 8.0), Vector3(0.35, 0.024, 3.5))
	# A high overhead gantry and short suspended cable define the central yard.
	_detail(steel, Vector3(0, 18.3, -118), Vector3(59, 1.2, 1.2))
	_detail(caution, Vector3(0, 17.55, -117.3), Vector3(12, 0.3, 0.15))
	_detail(steel, Vector3(0, 16.4, -118), Vector3(0.2, 3.0, 0.2))
	_batch_yard("FactorySteel", steel, materials["trim"])
	_batch_yard("FactoryCaution", caution, materials["yellow"])
	_batch_yard("FactoryDarkPanels", dark, materials["glass"])


func _detail(items: Array[Transform3D], at: Vector3, dimensions: Vector3) -> void:
	items.append(Transform3D(Basis.IDENTITY.scaled(dimensions), at))


func _batch_yard(batch_name: String, items: Array[Transform3D], material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = items.size()
	for index: int in items.size():
		multi.set_instance_transform(index, items[index])
	var batch := MultiMeshInstance3D.new()
	batch.name = batch_name
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
