extends "res://scripts/environment/hospital_geometry.gd"
## A bazaar district on the proven city routes. Architecture, shopfronts and
## market stalls are visual-only; only the ground and defense walls collide.

func _ready() -> void:
	_setup_materials()
	(materials["concrete"] as StandardMaterial3D).albedo_color = Color(0.68, 0.59, 0.46)
	(materials["red"] as StandardMaterial3D).albedo_color = Color(0.08, 0.36, 0.35)
	(materials["road"] as StandardMaterial3D).albedo_color = Color(0.48, 0.44, 0.37)
	_textured("road", "concrete", Vector3(14, 18, 1))
	materials["bazaar_stone"] = _material(Color(0.86, 0.80, 0.69))
	_textured("bazaar_stone", "bazaar_stone", Vector3(2, 2, 1))
	materials["bazaar_dark"] = _material(Color(0.12, 0.12, 0.10))
	materials["bazaar_blue"] = _material(Color(0.06, 0.39, 0.39))
	materials["bazaar_cloth"] = _material(Color(0.52, 0.13, 0.095))
	materials["bazaar_wood"] = _material(Color(0.29, 0.19, 0.12))
	_box("BazaarGround", Vector3(0, -0.25, -77), Vector3(150, 0.5, 190), "road", true)
	_box("BazaarPlatform", Vector3(0, 1.9, 5), Vector3(31, 3.8, 16), "concrete", true)
	_box("BazaarPlatformTop", Vector3(0, 3.95, 5), Vector3(32, 0.1, 16), "concrete")
	_defenses()
	_market()


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
		_box("BazaarGateHeader%d" % side, Vector3(side * 16.7, 4.5, z), Vector3(0.8, 0.6, 8), "bazaar_blue")
		for offset: float in [-3.7, 3.7]:
			_box("BazaarGatePost%d_%s" % [side, offset], Vector3(side * 16.7, 2.0, z + offset), Vector3(0.8, 4, 0.35), "concrete")


func _market() -> void:
	var masonry: Array[Transform3D] = []
	var shade: Array[Transform3D] = []
	var blue: Array[Transform3D] = []
	var cloth: Array[Transform3D] = []
	var wood: Array[Transform3D] = []
	# A distant five-arched market facade, behind all existing spawn positions.
	_detail(masonry, Vector3(0, 8, -153), Vector3(62, 16, 1.2))
	for x: float in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		_detail(shade, Vector3(x, 5.0, -152.3), Vector3(7.8, 10, 0.12))
		for sign_value: float in [-1.0, 1.0]:
			_detail(masonry, Vector3(x + sign_value * 4.3, 4.3, -152.0), Vector3(0.8, 8.6, 0.5))
		# Segmented semicircle reads as an arch from the gunner's view.
		for i: int in 11:
			var angle: float = PI * float(i) / 10.0
			var at := Vector3(x + cos(angle) * 4.3, 8.6 + sin(angle) * 3.0, -152.0)
			var rotation := Basis(Vector3.FORWARD, angle - PI / 2.0)
			masonry.append(Transform3D(rotation * Basis.from_scale(Vector3(1.35, 0.7, 0.5)), at))
		_detail(blue, Vector3(x, 12.6, -151.9), Vector3(8.5, 0.45, 0.5))
	_detail(masonry, Vector3(0, 16.3, -153), Vector3(64, 0.8, 2.0))
	# Side arcades create depth without closing the central firing lane.
	for side: int in [-1, 1]:
		var sx: float = float(side)
		_detail(masonry, Vector3(sx * 32, 10.8, -105), Vector3(8, 1, 55))
		_detail(blue, Vector3(sx * 27.8, 10.6, -105), Vector3(0.25, 0.6, 55))
		for z: float in [-126.0, -114.0, -102.0, -90.0]:
			_detail(shade, Vector3(sx * 31.7, 4.3, z), Vector3(0.18, 8.3, 8.2))
			for offset: float in [-4.8, 4.8]:
				_detail(masonry, Vector3(sx * 27.8, 4.0, z + offset), Vector3(0.8, 8, 0.8))
			for i: int in 9:
				var angle: float = PI * float(i) / 8.0
				var at := Vector3(sx * 27.8, 8.0 + sin(angle) * 2.3, z + cos(angle) * 4.8)
				var rotation := Basis(Vector3.RIGHT, PI / 2.0 - angle)
				masonry.append(Transform3D(rotation * Basis.from_scale(Vector3(0.8, 0.7, 1.8)), at))
		# Small shop stalls flank the view at a safe distance from route centers.
		var stall_x: float = sx * 20.5
		var stall_z: float = -69.0
		_detail(wood, Vector3(stall_x, 1.2, stall_z), Vector3(4.0, 2.4, 2.0))
		for offset: float in [-1.8, 1.8]:
			_detail(wood, Vector3(stall_x + offset, 2.8, stall_z), Vector3(0.16, 5.5, 0.16))
		_detail(cloth, Vector3(stall_x, 5.3, stall_z), Vector3(4.6, 0.25, 3.3))
		for offset: float in [-1.5, -0.5, 0.5, 1.5]:
			_detail(blue, Vector3(stall_x + offset, 5.44, stall_z), Vector3(0.48, 0.04, 3.3))
		_detail(blue, Vector3(stall_x, 2.3, stall_z + 1.05), Vector3(3.5, 0.28, 0.12))
	_batch("BazaarMasonry", masonry, materials["bazaar_stone"])
	_batch("BazaarOpenings", shade, materials["bazaar_dark"])
	_batch("BazaarTile", blue, materials["bazaar_blue"])
	_batch("BazaarAwnings", cloth, materials["bazaar_cloth"])
	_batch("BazaarWood", wood, materials["bazaar_wood"])


func _detail(items: Array[Transform3D], at: Vector3, size: Vector3) -> void:
	items.append(Transform3D(Basis.from_scale(size), at))


func _batch(batch_name: String, items: Array[Transform3D], material: Material) -> void:
	var mesh := BoxMesh.new()
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
