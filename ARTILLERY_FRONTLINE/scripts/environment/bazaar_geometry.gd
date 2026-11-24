extends "res://scripts/environment/hospital_geometry.gd"
## A bazaar district on the proven city routes. Architecture, shopfronts and
## market stalls are visual-only; only the ground and defense walls collide.

const MARKET_STALLS: Array[Vector3] = [Vector3(-20.5, 0, -69), Vector3(20.5, 0, -69)]

func _ready() -> void:
	_setup_materials()
	(materials["concrete"] as StandardMaterial3D).albedo_color = Color(0.68, 0.59, 0.46)
	(materials["red"] as StandardMaterial3D).albedo_color = Color(0.08, 0.36, 0.35)
	(materials["road"] as StandardMaterial3D).albedo_color = Color(0.50, 0.48, 0.43)
	_textured("road", "bazaar_tiles", Vector3(17, 22, 1))
	materials["bazaar_stone"] = _material(Color(0.86, 0.80, 0.69))
	_textured("bazaar_stone", "bazaar_stone", Vector3(2, 2, 1))
	materials["bazaar_dark"] = _material(Color(0.12, 0.12, 0.10))
	(materials["bazaar_dark"] as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["bazaar_blue"] = _material(Color(0.06, 0.39, 0.39))
	materials["bazaar_cloth"] = _material(Color(0.52, 0.13, 0.095))
	materials["bazaar_wood"] = _material(Color(0.29, 0.19, 0.12))
	materials["bazaar_mosaic"] = _material(Color(0.78, 0.82, 0.77))
	_textured("bazaar_mosaic", "bazaar_mosaic", Vector3(2, 1, 1))
	materials["bazaar_carpet"] = _material(Color(0.82, 0.78, 0.70))
	_textured("bazaar_carpet", "bazaar_carpet", Vector3.ONE)
	materials["bazaar_canvas"] = _material(Color(0.72, 0.65, 0.51))
	materials["bazaar_terracotta"] = _material(Color(0.59, 0.28, 0.14))
	materials["bazaar_fruit"] = _material(Color(0.88, 0.48, 0.10))
	materials["bazaar_lantern"] = _material(Color(1.0, 0.64, 0.20))
	var lantern: StandardMaterial3D = materials["bazaar_lantern"]
	lantern.emission_enabled = true
	lantern.emission = Color(1.0, 0.36, 0.06)
	lantern.emission_energy_multiplier = 0.6
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
	var mosaic: Array[Transform3D] = []
	var carpets: Array[Transform3D] = []
	var canvas: Array[Transform3D] = []
	var pottery: Array[Transform3D] = []
	var fruit: Array[Transform3D] = []
	var lanterns: Array[Transform3D] = []
	var arch_tops: Array[Transform3D] = []
	# A distant five-arched market facade, behind all existing spawn positions.
	_detail(masonry, Vector3(0, 8, -153), Vector3(62, 16, 1.2))
	for x: float in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		_detail(shade, Vector3(x, 4.1, -152.3), Vector3(7.8, 8.2, 0.12))
		arch_tops.append(Transform3D(Basis.IDENTITY, Vector3(x, 8.2, -152.20)))
		_detail(mosaic, Vector3(x, 12.6, -151.65), Vector3(8.5, 1.0, 0.18))
		# Recessed timber shutters and gold lamps give the openings depth.
		_detail(wood, Vector3(x, 3.0, -152.0), Vector3(5.7, 5.8, 0.15))
		for offset: float in [-2.0, 0.0, 2.0]:
			_detail(shade, Vector3(x + offset, 3.0, -151.89), Vector3(0.14, 5.5, 0.05))
		_detail(lanterns, Vector3(x, 7.0, -151.8), Vector3(0.4, 0.7, 0.3))
		for sign_value: float in [-1.0, 1.0]:
			_detail(masonry, Vector3(x + sign_value * 4.3, 4.3, -152.0), Vector3(0.8, 8.6, 0.5))
		# Segmented semicircle reads as an arch from the gunner's view.
		for i: int in 11:
			var angle: float = PI * float(i) / 10.0
			var at := Vector3(x + cos(angle) * 4.3, 8.6 + sin(angle) * 3.0, -152.0)
			var rotation := Basis(Vector3.FORWARD, angle - PI / 2.0)
			masonry.append(Transform3D(rotation * Basis.from_scale(Vector3(1.35, 0.7, 0.5)), at))
		_detail(blue, Vector3(x, 13.35, -151.9), Vector3(8.5, 0.18, 0.5))
	_detail(masonry, Vector3(0, 16.3, -153), Vector3(64, 0.8, 2.0))
	# Side arcades create depth without closing the central firing lane.
	for side: int in [-1, 1]:
		var sx: float = float(side)
		_detail(masonry, Vector3(sx * 32, 10.8, -105), Vector3(8, 1, 55))
		_detail(blue, Vector3(sx * 24.0, 10.6, -111), Vector3(0.25, 0.6, 47))
		for z: float in [-130.0, -119.0, -108.0, -97.0]:
			_detail(shade, Vector3(sx * 31.7, 4.3, z), Vector3(0.18, 8.3, 8.2))
			for offset: float in [-4.8, 4.8]:
				_detail(masonry, Vector3(sx * 24.0, 4.0, z + offset), Vector3(0.8, 8, 0.8))
			for i: int in 9:
				var angle: float = PI * float(i) / 8.0
				var at := Vector3(sx * 24.0, 8.0 + sin(angle) * 2.3, z + cos(angle) * 4.8)
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
		# A hanging woven rug, timber framing, and striped canvas valance are
		# turned toward the gunner rather than hiding on top of the awning.
		_detail(carpets, Vector3(stall_x, 3.72, stall_z + 0.92), Vector3(2.6, 2.8, 0.08))
		_detail(wood, Vector3(stall_x, 2.48, stall_z + 1.18), Vector3(4.4, 0.24, 0.45))
		for stripe: int in 8:
			var px: float = stall_x - 1.9 + float(stripe) * 0.54
			_detail(canvas if stripe % 2 == 0 else cloth, Vector3(px, 5.06, stall_z + 1.68), Vector3(0.53, 0.58, 0.10))
		# Two crates of wares and several clay vessels, all visual-only.
		for offset: float in [-1.4, 1.4]:
			_detail(wood, Vector3(stall_x + offset, 2.72, stall_z + 1.16), Vector3(1.0, 0.38, 0.65))
			for i: int in 3:
				_detail(fruit, Vector3(stall_x + offset - 0.30 + float(i) * 0.3, 3.0, stall_z + 1.18), Vector3(0.26, 0.26, 0.26))
			_detail(pottery, Vector3(stall_x + offset * 0.75, 3.06, stall_z + 0.65), Vector3(0.60, 0.75, 0.60))
		_detail(wood, Vector3(stall_x, 4.86, stall_z + 1.66), Vector3(0.08, 0.48, 0.08))
		_detail(lanterns, Vector3(stall_x, 4.48, stall_z + 1.67), Vector3(0.30, 0.42, 0.3))
		# Patterned frieze on the visible front of each distant market wing.
		_detail(mosaic, Vector3(sx * 38.0, 15.6, -90.60), Vector3(24, 1.2, 0.12))
		for ox: float in [-7.5, 0.0, 7.5]:
			_detail(wood, Vector3(sx * 38.0 + ox, 5.3, -90.58), Vector3(3.3, 7.4, 0.10))
			_detail(lanterns, Vector3(sx * 38.0 + ox, 10.0, -90.46), Vector3(0.40, 0.7, 0.22))
	# High colored bunting frames the skyline; nothing hangs at enemy height.
	_detail(wood, Vector3(0, 15.0, -108), Vector3(46, 0.07, 0.07))
	for i: int in 13:
		var x: float = -21.0 + float(i) * 3.5
		_detail(cloth if i % 2 == 0 else blue, Vector3(x, 14.1, -108), Vector3(1.5, 1.8, 0.06))
	_batch_arch_tops(arch_tops, materials["bazaar_dark"])
	_batch("BazaarMosaic", mosaic, materials["bazaar_mosaic"])
	_batch("BazaarRugs", carpets, materials["bazaar_carpet"])
	_batch("BazaarCanvas", canvas, materials["bazaar_canvas"])
	_batch("BazaarLanterns", lanterns, materials["bazaar_lantern"])
	_batch_round("BazaarPottery", pottery, materials["bazaar_terracotta"], false)
	_batch_round("BazaarProduce", fruit, materials["bazaar_fruit"], true)
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


## Semicircular dark recesses complete the arched openings on the rear facade.
func _batch_arch_tops(items: Array[Transform3D], material: Material) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i: int in 12:
		var a: float = PI * float(i) / 12.0
		var b: float = PI * float(i + 1) / 12.0
		vertices.append(Vector3.ZERO)
		vertices.append(Vector3(cos(a) * 3.9, sin(a) * 3.0, 0))
		vertices.append(Vector3(cos(b) * 3.9, sin(b) * 3.0, 0))
		for _v: int in 3:
			normals.append(Vector3.FORWARD)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	_multimesh("BazaarArchRecesses", items, mesh)


## Two instanced low-poly meshes replace per-item props and add no physics.
func _batch_round(batch_name: String, items: Array[Transform3D], material: Material, spherical: bool) -> void:
	var mesh: PrimitiveMesh
	if spherical:
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh = sphere
	else:
		var pot := CylinderMesh.new()
		pot.top_radius = 0.30
		pot.bottom_radius = 0.48
		pot.height = 1.0
		pot.radial_segments = 10
		mesh = pot
	mesh.material = material
	_multimesh(batch_name, items, mesh)


func _multimesh(batch_name: String, items: Array[Transform3D], mesh: Mesh) -> void:
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
