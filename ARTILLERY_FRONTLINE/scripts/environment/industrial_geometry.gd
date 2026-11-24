extends "res://scripts/environment/hospital_geometry.gd"
## Factory yard using the existing defense contract. All yard architecture is
## decoration: no new collision or obstacles across the established routes.

# Locations and fire anchors are also used by the scene integration tests. Both
# vehicles sit outside the route envelopes rather than on the firing line.
const FORKLIFT_AT := Vector3(-19.5, 0.0, -68.0)
const TRUCK_AT := Vector3(19.5, 0.0, -68.5)
var fire_accents: Array[MeshInstance3D] = []
var fire_clock: float = 0.0

func _ready() -> void:
	_setup_materials()
	(materials["concrete"] as StandardMaterial3D).albedo_color = Color(0.40, 0.39, 0.34)
	(materials["trim"] as StandardMaterial3D).albedo_color = Color(0.28, 0.24, 0.20)
	(materials["yellow"] as StandardMaterial3D).albedo_color = Color(0.78, 0.54, 0.14)
	# Purpose-made 512px industrial surfaces are used only in this district.
	# Keep them mipmapped on mobile and distinct from the shared city assets.
	(materials["road"] as StandardMaterial3D).albedo_color = Color(0.66, 0.66, 0.62)
	_textured("road", "industrial_yard", Vector3(18, 18, 1))
	materials["factory_cladding"] = _material(Color(0.78, 0.74, 0.68), 0.12)
	_textured("factory_cladding", "industrial_cladding", Vector3(2, 1, 1))
	materials["factory_rust"] = _material(Color(0.35, 0.17, 0.10), 0.3)
	materials["factory_char"] = _material(Color(0.075, 0.075, 0.067), 0.15)
	materials["factory_hub"] = _material(Color(0.45, 0.42, 0.33), 0.45)
	_box("IndustrialGround", Vector3(0, -0.25, -77), Vector3(150, 0.5, 190), "road", true)
	# Same mount, gate and attack lines as the existing city level.
	_box("IndustrialPlatform", Vector3(0, 1.9, 5), Vector3(31, 3.8, 16), "concrete", true)
	_box("IndustrialPlatformTop", Vector3(0, 3.95, 5), Vector3(32, 0.1, 16), "concrete")
	_factory_defenses()
	_factory_yard()
	_vehicle_scenery()


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
## and projectile height. Repeated details use a small number of MultiMeshes.
func _factory_yard() -> void:
	var steel: Array[Transform3D] = []
	var caution: Array[Transform3D] = []
	var dark: Array[Transform3D] = []
	var rust: Array[Transform3D] = []
	var ground_marks: Array[Transform3D] = []
	var cladding: Array[Transform3D] = []
	var structural: Array[Transform3D] = []
	for side: int in [-1, 1]:
		var x: float = float(side)
		# Low warehouses frame the approach, leaving side route mouths open.
		_detail(cladding, Vector3(x * 46, 7, -76), Vector3(16, 14, 22))
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
		# Rusted pipes and bands on the distant factory-facing walls.
		for z: float in [-113.0, -106.0, -99.0, -92.0]:
			_detail(rust, Vector3(x * 28.0, 7.4, z), Vector3(0.35, 14.0, 0.35))
			_detail(steel, Vector3(x * 27.75, 5.0, z), Vector3(0.3, 0.35, 1.5))
		for i: int in 3:
			_detail(ground_marks, Vector3(x * (8.0 + i * 3.0), 0.015, -62.0 - i * 18.0), Vector3(2.7 + i * 0.7, 0.018, 5.0))
		# Safety paint is flush to the ground and cannot obstruct enemies.
		for i: int in 8:
			_detail(caution, Vector3(x * 12.5, 0.012, -55.0 - i * 8.0), Vector3(0.35, 0.024, 3.5))
	# A high overhead gantry and short suspended cable define the central yard.
	_detail(steel, Vector3(0, 18.3, -118), Vector3(59, 1.2, 1.2))
	_detail(caution, Vector3(0, 17.55, -117.3), Vector3(12, 0.3, 0.15))
	_detail(steel, Vector3(0, 16.4, -118), Vector3(0.2, 3.0, 0.2))
	for x: float in [-24.0, -18.0, -12.0, -6.0, 0.0, 6.0, 12.0, 18.0, 24.0]:
		_detail(rust, Vector3(x, 17.4, -118.0), Vector3(0.25, 1.4, 0.5))
	# Open web of girders: readable depth above the shooting lane, with no
	# wall or visual clutter at zombie height.
	_detail(steel, Vector3(0, 15.2, -118), Vector3(59, 0.35, 0.55))
	for i: int in 19:
		var x: float = -27.0 + float(i) * 3.0
		var lean: float = 0.72 if i % 2 == 0 else -0.72
		structural.append(Transform3D(Basis(Vector3.FORWARD, lean) * Basis.from_scale(Vector3(0.18, 4.0, 0.22)), Vector3(x, 16.8, -117.6)))
	# A distant loading hall gives the horizon a purpose. Its opening and
	# everything here are visual only; spawns remain in front of the backdrop.
	for side: int in [-1, 1]:
		_detail(cladding, Vector3(side * 19.0, 8.0, -151.0), Vector3(25.0, 16.0, 1.0))
		for i: int in 4:
			_detail(dark, Vector3(side * 19.0 + (i - 1.5) * 4.8, 10.0, -150.35), Vector3(3.1, 3.0, 0.2))
	_detail(steel, Vector3(0.0, 16.2, -151.0), Vector3(63.0, 1.2, 1.2))
	_detail(rust, Vector3(0.0, 7.4, -151.0), Vector3(13.0, 14.0, 0.8))
	_detail(caution, Vector3(0.0, 14.5, -150.3), Vector3(14.0, 0.65, 0.25))
	for x: float in [-6.7, 6.7]:
		_detail(steel, Vector3(x, 7.2, -150.25), Vector3(0.3, 14.2, 0.3))
	for x: float in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		_detail(dark, Vector3(x, 7.4, -150.5), Vector3(0.16, 13.0, 0.18))
	# Shallow drainage grates and worn, low-contrast oil marks sit on the
	# floor, never masking a zombie or adding collision.
	for z: float in [-57.0, -76.0, -95.0, -114.0]:
		_detail(ground_marks, Vector3(0, 0.02, z), Vector3(2.6, 0.025, 0.7))
		for i: int in 5:
			_detail(steel, Vector3(-1.0 + i * 0.5, 0.04, z), Vector3(0.12, 0.025, 0.65))
	_batch_yard("FactoryCladding", cladding, materials["factory_cladding"])
	_batch_yard("FactoryTrusses", structural, materials["factory_rust"])
	_batch_yard("FactorySteel", steel, materials["trim"])
	_batch_yard("FactoryCaution", caution, materials["yellow"])
	_batch_yard("FactoryDarkPanels", dark, materials["glass"])
	_batch_yard("FactoryRust", rust, materials["factory_rust"])
	_batch_yard("FactoryGroundWear", ground_marks, materials["factory_char"])


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


## Two lightweight modular vehicles: each color/shape is one MultiMesh.
## No collider or physics body is created; hitboxes and walking routes stay as
## they were. Fire is supplied by the existing quality-governed layout.
func _vehicle_scenery() -> void:
	_forklift()
	_burnt_truck()


func _forklift() -> void:
	var root := Node3D.new()
	root.name = "IndustrialForklift"
	root.position = FORKLIFT_AT
	add_child(root)
	var yellow: Array[Transform3D] = []
	var frame: Array[Transform3D] = []
	var rubber: Array[Transform3D] = []
	var hubs: Array[Transform3D] = []
	# Compact body, counterweight and open operator cage.
	_detail(yellow, Vector3(0, 0.95, -0.35), Vector3(2.4, 1.1, 3.2))
	_detail(yellow, Vector3(0, 1.4, -1.35), Vector3(2.4, 1.0, 0.8))
	_detail(yellow, Vector3(0, 3.15, -0.2), Vector3(2.45, 0.2, 2.35))
	_detail(frame, Vector3(0, 1.45, 0.25), Vector3(1.3, 0.18, 1.3))
	_detail(frame, Vector3(0, 2.0, -0.45), Vector3(1.05, 0.95, 0.25))
	for x: float in [-1.05, 1.05]:
		for z: float in [-1.15, 0.7]:
			_detail(frame, Vector3(x, 2.35, z), Vector3(0.14, 1.7, 0.14))
		# Twin lift rails and low forks point toward the defender.
		_detail(frame, Vector3(x * 0.8, 1.95, 1.55), Vector3(0.18, 3.25, 0.2))
		_detail(frame, Vector3(x * 0.65, 0.2, 2.35), Vector3(0.24, 0.18, 2.2))
		for z: float in [-1.1, 0.95]:
			_wheel(rubber, Vector3(x * 1.15, 0.5, z))
			_wheel(hubs, Vector3(x * 1.33, 0.5, z))
	_detail(frame, Vector3(0, 2.9, 1.55), Vector3(2.0, 0.18, 0.22))
	_detail(frame, Vector3(0, 1.0, 1.68), Vector3(2.1, 0.3, 0.18))
	# Hydraulic ram, crossbars and rail stops distinguish the lift mechanism.
	_detail(frame, Vector3(0, 1.45, 1.62), Vector3(0.18, 2.25, 0.18))
	_detail(frame, Vector3(0, 2.4, 1.6), Vector3(1.7, 0.12, 0.12))
	for x: float in [-0.6, 0.6]:
		_detail(yellow, Vector3(x, 1.05, 1.48), Vector3(0.35, 0.18, 0.18))
	_detail(yellow, Vector3(0.9, 3.36, -0.8), Vector3(0.25, 0.22, 0.25))
	_vehicle_boxes(root, "ForkliftYellow", yellow, materials["yellow"])
	_vehicle_boxes(root, "ForkliftFrame", frame, materials["factory_char"])
	_vehicle_wheels(root, "ForkliftTires", rubber, materials["rubber"], 0.5, 0.38)
	_vehicle_wheels(root, "ForkliftHubs", hubs, materials["factory_hub"], 0.23, 0.05)


func _burnt_truck() -> void:
	var root := Node3D.new()
	root.name = "IndustrialBurntTruck"
	root.position = TRUCK_AT
	add_child(root)
	var burnt: Array[Transform3D] = []
	var rust: Array[Transform3D] = []
	var glass: Array[Transform3D] = []
	var trim: Array[Transform3D] = []
	var rubber: Array[Transform3D] = []
	var hubs: Array[Transform3D] = []
	# A fire-scorched delivery cab with a long open flatbed behind it.
	_detail(burnt, Vector3(0, 0.9, -0.5), Vector3(3.4, 0.7, 7.8))
	_detail(rust, Vector3(0, 1.9, 2.05), Vector3(3.25, 2.6, 2.8))
	_detail(burnt, Vector3(0, 1.25, 3.55), Vector3(3.2, 1.0, 1.0))
	_detail(burnt, Vector3(0, 3.3, 2.1), Vector3(3.4, 0.24, 2.9))
	_detail(glass, Vector3(0, 2.35, 3.48), Vector3(2.7, 1.1, 0.12))
	_detail(trim, Vector3(0, 2.35, 3.57), Vector3(0.16, 1.15, 0.12))
	_detail(trim, Vector3(0, 0.9, 4.12), Vector3(3.55, 0.28, 0.22))
	_detail(glass, Vector3(0, 1.4, 4.08), Vector3(1.8, 0.5, 0.1))
	_detail(rust, Vector3(0, 1.36, -2.25), Vector3(3.35, 0.35, 5.0))
	for x: float in [-1.55, 1.55]:
		_detail(glass, Vector3(x * 1.05, 2.3, 1.9), Vector3(0.12, 1.05, 1.55))
		_detail(rust, Vector3(x, 1.9, -2.25), Vector3(0.16, 1.1, 5.0))
		for z: float in [-4.25, -2.3, -0.3]:
			_detail(trim, Vector3(x, 2.0, z), Vector3(0.18, 1.1, 0.18))
		for z: float in [-3.2, -1.3, 2.5]:
			_wheel(rubber, Vector3(x * 1.08, 0.65, z))
			_wheel(hubs, Vector3(x * 1.22, 0.65, z))
		_detail(trim, Vector3(x * 0.7, 1.45, 4.1), Vector3(0.45, 0.32, 0.08))
	_detail(trim, Vector3(0, 2.0, -4.7), Vector3(3.1, 1.1, 0.16))
	# Grille slats, window frame, wipers and mirrors keep the burned cab
	# readable as a truck from a mobile-sized screen.
	for y: float in [1.25, 1.38, 1.51, 1.64]:
		_detail(trim, Vector3(0, y, 4.15), Vector3(1.7, 0.045, 0.06))
	for x: float in [-1.25, 1.25]:
		_detail(burnt, Vector3(x, 2.35, 3.57), Vector3(0.12, 1.2, 0.1))
		_detail(burnt, Vector3(x * 1.35, 2.35, 2.9), Vector3(0.3, 0.46, 0.16))
	_detail(burnt, Vector3(0, 1.8, 3.59), Vector3(2.7, 0.12, 0.1))
	_detail(burnt, Vector3(-0.58, 1.95, 3.62), Vector3(1.1, 0.06, 0.06))
	_detail(burnt, Vector3(0.58, 1.95, 3.62), Vector3(1.1, 0.06, 0.06))
	_vehicle_boxes(root, "TruckCharredMetal", burnt, materials["factory_char"])
	_vehicle_boxes(root, "TruckRust", rust, materials["factory_rust"])
	_vehicle_boxes(root, "TruckBrokenWindows", glass, materials["glass"])
	_vehicle_boxes(root, "TruckTrim", trim, materials["factory_hub"])
	_vehicle_wheels(root, "TruckTires", rubber, materials["rubber"], 0.65, 0.42)
	_vehicle_wheels(root, "TruckHubs", hubs, materials["factory_hub"], 0.28, 0.05)


func _wheel(items: Array[Transform3D], at: Vector3) -> void:
	items.append(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), at))


func _vehicle_boxes(parent: Node3D, node_name: String, items: Array[Transform3D], material: Material) -> void:
	var mesh := BoxMesh.new()
	_vehicle_batch(parent, node_name, items, mesh, material)


func _vehicle_wheels(parent: Node3D, node_name: String, items: Array[Transform3D], material: Material, radius: float, width: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = 10
	_vehicle_batch(parent, node_name, items, mesh, material)


func _vehicle_batch(parent: Node3D, node_name: String, items: Array[Transform3D], mesh: PrimitiveMesh, material: Material) -> void:
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = items.size()
	for i: int in items.size():
		multi.set_instance_transform(i, items[i])
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(batch)


## A tiny, animated stylized flame silhouette complements the existing
## particles. A smoke particle can be hard to see from the distant gunner on a
## phone, so the burning vehicle should remain readable even between bursts.
## The accent is parented to the existing fire root: its quality cap, pause
## behavior and cleanup remain exactly the same as the surrounding fire.
func setup_industrial_fire_accents(fires: Array[Node3D]) -> void:
	var mesh := _flame_mesh()
	for index: int in mini(fires.size(), 2):
		var accent := MeshInstance3D.new()
		accent.name = "VehicleFlameAccent"
		accent.mesh = mesh
		accent.scale = Vector3.ONE * (1.0 if index == 0 else 0.55)
		accent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fires[index].add_child(accent)
		fire_accents.append(accent)


func _flame_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var ember := Color(0.95, 0.20, 0.01, 0.85)
	var orange := Color(1.0, 0.43, 0.025, 0.8)
	var gold := Color(1.0, 0.82, 0.24, 0.9)
	_flame_tongue(vertices, colors, Vector3(-1.1, 0, 0), Vector3(0.2, 0, 0), Vector3(-0.72, 2.4, 0), ember, orange)
	_flame_tongue(vertices, colors, Vector3(-0.75, 0, 0), Vector3(0.9, 0, 0), Vector3(0.1, 3.1, 0), ember, orange)
	_flame_tongue(vertices, colors, Vector3(0.0, 0, 0), Vector3(1.2, 0, 0), Vector3(0.8, 2.2, 0), ember, orange)
	_flame_tongue(vertices, colors, Vector3(-0.72, 0.02, 0.02), Vector3(0.35, 0.02, 0.02), Vector3(-0.35, 1.55, 0.02), gold, orange)
	_flame_tongue(vertices, colors, Vector3(-0.25, 0.02, 0.025), Vector3(0.75, 0.02, 0.025), Vector3(0.45, 1.35, 0.025), gold, orange)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh


func _flame_tongue(vertices: PackedVector3Array, colors: PackedColorArray, left: Vector3, right: Vector3, top: Vector3, base: Color, tip: Color) -> void:
	vertices.append_array(PackedVector3Array([left, right, top]))
	colors.append_array(PackedColorArray([base, base, tip]))


func _process(delta: float) -> void:
	fire_clock += delta
	for index: int in fire_accents.size():
		var factor: float = 1.0 if index == 0 else 0.55
		var flicker: float = fire_clock * 7.0 + float(index) * 1.7
		fire_accents[index].scale = Vector3(factor * (0.92 + 0.08 * sin(flicker)), factor * (0.93 + 0.07 * sin(flicker * 1.3)), factor)
