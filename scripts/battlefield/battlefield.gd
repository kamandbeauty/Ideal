class_name Battlefield
extends Node3D
## One authored desert outpost. Distant dressing is batched and can be disabled.

var sun: DirectionalLight3D
var detail_group: Node3D
var _sand: Material
var _stone: Material
var _dark: Material
var _road: Material
var _olive: Material
var _metal: Material
var _warm: Material


func _ready() -> void:
	name = "DustlineBattlefield"
	_sand = ShapeFactory.material(Color("b69a71"))
	_stone = ShapeFactory.material(Color("85745d"))
	_dark = ShapeFactory.material(Color("373d34"))
	_road = ShapeFactory.material(Color("5c5849"))
	_olive = ShapeFactory.material(Color("656d50"))
	_metal = ShapeFactory.material(Color("38443c"), 0.45, 0.7)
	_warm = ShapeFactory.material(Color("d1b47f"))
	_build_environment()
	_build_ground()
	_build_outpost()
	_build_distant_dressing()


func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4b6d76")
	sky_material.sky_horizon_color = Color("c2b18f")
	sky_material.ground_bottom_color = Color("514b3c")
	sky_material.ground_horizon_color = Color("c4b18a")
	sky_material.sun_angle_max = 22.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c6c3ac")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("b8a58a")
	environment.fog_density = 0.0022
	environment_node.environment = environment
	add_child(environment_node)

	sun = DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-49.0, -27.0, 0.0)
	sun.light_color = Color("ffe5bd")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = Vector3(360.0, 1.0, 360.0)
	shape.shape = cube
	shape.position = Vector3(0.0, -0.5, -35.0)
	ground.add_child(shape)
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://shaders/desert_ground.gdshader")
	ShapeFactory.box(ground, Vector3(360.0, 1.0, 360.0), Vector3(0.0, -0.5, -35.0), ground_mat)

	# The road and painted markings sit just above the collision plane.
	ShapeFactory.box(self, Vector3(18.0, 0.04, 210.0), Vector3(0.0, 0.02, -39.0), _road)
	for z in range(-130, 65, 14):
		ShapeFactory.box(self, Vector3(0.22, 0.02, 6.0), Vector3(0.0, 0.05, float(z)), _warm)
	for side in [-1.0, 1.0]:
		ShapeFactory.box(self, Vector3(0.18, 0.02, 210.0), Vector3(side * 8.2, 0.05, -39.0), _sand)


func _build_outpost() -> void:
	# Low buildings and defensive walls frame, but never obstruct, the firing lane.
	_build_warehouse(Vector3(-30, 0, -84), Vector3(15, 8, 19))
	_build_warehouse(Vector3(31, 0, -108), Vector3(18, 9, 16))
	_build_warehouse(Vector3(-38, 0, -123), Vector3(12, 6, 13))
	for side in [-1.0, 1.0]:
		for z in [-42.0, -47.0, -52.0, -100.0, -105.0]:
			ShapeFactory.box(self, Vector3(2.8, 1.15, 4.3), Vector3(side * 17.0, 0.575, z), _sand)
			ShapeFactory.box(self, Vector3(2.95, 0.15, 4.4), Vector3(side * 17.0, 1.2, z), _warm)
		for z in [-28.0, -75.0, -116.0]:
			_build_pole(Vector3(side * 12.5, 0.0, z))
	# Shell crates close to the player's firing position.
	for i in range(3):
		var x := -8.0 - float(i % 2) * 2.2
		var z := 46.0 + float(i / 2) * 2.2
		ShapeFactory.box(self, Vector3(1.8, 1.15, 1.5), Vector3(x, 0.6, z), _olive)
		ShapeFactory.box(self, Vector3(1.9, 0.1, 1.6), Vector3(x, 1.2, z), _metal)
	for x in [-13.0, 13.0]:
		for z in [33.0, 36.0, 39.0, 42.0, 45.0, 48.0]:
			ShapeFactory.box(self, Vector3(2.2, 0.7, 2.65), Vector3(x, 0.35, z), _sand)


func _build_warehouse(pos: Vector3, dimensions: Vector3) -> void:
	var building := Node3D.new()
	building.position = pos
	add_child(building)
	ShapeFactory.box(building, dimensions, Vector3(0, dimensions.y * 0.5, 0), _sand)
	ShapeFactory.box(
		building,
		Vector3(dimensions.x + 1.0, 0.45, dimensions.z + 1.0),
		Vector3(0, dimensions.y + 0.15, 0),
		_stone
	)
	# Dark loading bays and small horizontal windows provide scale.
	ShapeFactory.box(
		building,
		Vector3(dimensions.x * 0.42, dimensions.y * 0.62, 0.12),
		Vector3(0, dimensions.y * 0.31, dimensions.z * 0.5 + 0.07),
		_dark
	)
	for side in [-1.0, 1.0]:
		ShapeFactory.box(
			building,
			Vector3(dimensions.x * 0.2, 0.45, 0.13),
			Vector3(side * dimensions.x * 0.32, dimensions.y * 0.75, dimensions.z * 0.5 + 0.07),
			_metal
		)
	ShapeFactory.box(
		building,
		Vector3(2.0, 1.0, 2.0),
		Vector3(dimensions.x * 0.3, dimensions.y + 0.75, 0),
		_metal
	)


func _build_pole(pos: Vector3) -> void:
	ShapeFactory.cylinder(self, 0.16, 7.0, pos + Vector3(0, 3.5, 0), _metal, 8)
	ShapeFactory.box(self, Vector3(2.0, 0.12, 0.12), pos + Vector3(0, 6.8, 0), _metal)


func _build_distant_dressing() -> void:
	detail_group = Node3D.new()
	detail_group.name = "EnvironmentalDetail"
	add_child(detail_group)
	# Clustered hills are deliberately non-colliding, away from the artillery lane.
	for side in [-1.0, 1.0]:
		for i in range(6):
			var x: float = side * (65.0 + float(i % 3) * 35.0)
			var z := -55.0 - float(i) * 25.0
			var hill := ShapeFactory.sphere(
				detail_group, Vector3(62, 24 + i * 2, 57), Vector3(x, -6, z), _stone, 10
			)
			hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(8):
		var x: float = -160.0 + i * 45.0
		var mountain := ShapeFactory.sphere(
			self, Vector3(70, 40 + (i % 3) * 12, 55), Vector3(x, -7, -180), _stone, 10
		)
		mountain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scatter_rocks()
	for side in [-1.0, 1.0]:
		for i in range(6):
			_build_scrub_tree(
				Vector3(side * (23.0 + float(i % 3) * 11.0), 0, -20.0 - float(i) * 22.0)
			)


func _scatter_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1729
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 7
	mesh.rings = 4
	mesh.material = _stone
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = 140
	for i in range(batch.instance_count):
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * rng.randf_range(22, 130), 0.0, rng.randf_range(-150, 75))
		var size := rng.randf_range(0.5, 3.2)
		p.y = size * 0.17
		var basis := Basis.from_euler(Vector3(0, rng.randf_range(0, TAU), 0)).scaled(
			Vector3(size, size * 0.45, size * 0.8)
		)
		batch.set_instance_transform(i, Transform3D(basis, p))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	detail_group.add_child(instance)


func _build_scrub_tree(pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.position = pos
	detail_group.add_child(tree)
	var trunk := ShapeFactory.cylinder(tree, 0.25, 4.6, Vector3(0, 2.3, 0), _stone, 7)
	trunk.rotation_degrees.z = 7.0
	for i in range(3):
		var crown := ShapeFactory.sphere(
			tree, Vector3(4.6, 1.4, 2.5), Vector3(0, 4.4 + i * 0.35, 0), _olive, 8
		)
		crown.rotation.y = i * TAU / 3.0
		crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
