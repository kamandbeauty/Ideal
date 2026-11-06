class_name DesertBattlefield
extends Node3D
## Authored Sable Ridge sector: chunked LOD terrain, shared scenery, base architecture.
const CHUNK_SIZE: float = 140.0
var terrain_material: ShaderMaterial
var noise_texture: NoiseTexture2D
var road_material: ShaderMaterial
var targets: Array[EnemyTarget] = []
var destructibles: Array[Destructible] = []
var radar: Node3D
var sun: DirectionalLight3D
var environment: WorldEnvironment
var rng := RandomNumberGenerator.new()
var tree_points: Array[Vector3] = []
var enemy_definitions: Dictionary = {
	"t01": {"type": "emplacement", "position": Vector3(-38, 0, -175), "route": []},
	"t02": {"type": "tank", "position": Vector3(35, 0, -245), "route": [Vector3(35, 0, -245), Vector3(80, 0, -270), Vector3(55, 0, -315), Vector3(5, 0, -285)]},
	"t03": {"type": "transport", "position": Vector3(-65, 0, -315), "route": [Vector3(-65, 0, -315), Vector3(-20, 0, -340), Vector3(-20, 0, -285), Vector3(-65, 0, -260)]},
	"t04": {"type": "tank", "position": Vector3(85, 0, -365), "route": [Vector3(85, 0, -365), Vector3(30, 0, -390), Vector3(0, 0, -350), Vector3(60, 0, -330)]},
	"t05": {"type": "emplacement", "position": Vector3(105, 0, -220), "route": []},
	"t06": {"type": "transport", "position": Vector3(-110, 0, -390), "route": [Vector3(-110, 0, -390), Vector3(-60, 0, -420), Vector3(-20, 0, -390), Vector3(-70, 0, -360)]}
}
var crate_definitions: Dictionary = {
	"crate01": Vector3(-48, 0, -183), "crate02": Vector3(55, 0, -257),
	"crate03": Vector3(-55, 0, -328), "crate04": Vector3(96, 0, -233),
	"crate05": Vector3(-100, 0, -403)
}

static func height_at(x: float, z: float) -> float:
	return TerrainSampler.height_at(x, z)

func _ready() -> void:
	name = "SableRidge"
	rng.seed = 74129
	add_to_group("quality_listener")
	_build_lighting()
	_build_terrain()
	_build_roads()
	_build_base()
	_build_gun_position()
	_build_scatter()
	_build_targets()
	_build_destructibles()
	_batch_static_boxes()
	apply_quality(Graphics.tier, Graphics.profile())

func _process(delta: float) -> void:
	if radar:
		radar.rotation.y += delta * 0.32

func _build_lighting() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	if ResourceLoader.exists("res://assets/textures/pbr/sky_panorama.jpg"):
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load("res://assets/textures/pbr/sky_panorama.jpg")
		panorama.energy_multiplier = 1.0
		sky.sky_material = panorama
	else:
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color(0.20, 0.34, 0.48)
		sky_material.sky_horizon_color = Color(0.78, 0.73, 0.62)
		sky_material.ground_bottom_color = Color(0.30, 0.26, 0.21)
		sky_material.ground_horizon_color = Color(0.72, 0.66, 0.54)
		sky_material.sun_angle_max = 6.0
		sky_material.sun_curve = 0.14
		sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.46
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.70, 0.72)
	env.fog_light_energy = 0.9
	env.fog_density = 0.00055
	env.fog_sky_affect = 0.06
	env.fog_aerial_perspective = 0.22
	env.fog_sun_scatter = 0.16
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.94
	env.adjustment_contrast = 1.07
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	sun.rotation_degrees = Vector3(-32.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.shadow_bias = 0.85
	sun.shadow_normal_bias = 1.6
	sun.shadow_opacity = 0.88
	sun.directional_shadow_fade_start = 0.82
	sun.directional_shadow_max_distance = 230.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

func _build_terrain() -> void:
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = load("res://shaders/terrain.gdshader")
	var noise := FastNoiseLite.new()
	noise.seed = 421
	noise.frequency = 0.035
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise_texture = NoiseTexture2D.new()
	noise_texture.noise = noise
	noise_texture.seamless = true
	noise_texture.width = 256
	noise_texture.height = 256
	terrain_material.set_shader_parameter("ground_noise", noise_texture)
	terrain_material.set_shader_parameter("sand_albedo", MaterialLibrary.texture("sand_albedo.jpg"))
	terrain_material.set_shader_parameter("sand_normal", MaterialLibrary.texture("sand_normal.png"))
	terrain_material.set_shader_parameter("sand_orm", MaterialLibrary.texture("sand_orm.png"))
	for cz in range(-4, 4):
		for cx in range(-4, 4):
			_build_chunk(cx * CHUNK_SIZE, cz * CHUNK_SIZE)

func _build_chunk(start_x: float, start_z: float) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var subdivisions: int = 20
	var stride: int = subdivisions + 1
	for z in range(stride):
		for x in range(stride):
			var wx: float = start_x + float(x) / subdivisions * CHUNK_SIZE
			var wz: float = start_z + float(z) / subdivisions * CHUNK_SIZE
			vertices.append(Vector3(wx, height_at(wx, wz), wz))
			var normal := Vector3(height_at(wx - 1, wz) - height_at(wx + 1, wz), 2.0, height_at(wx, wz - 1) - height_at(wx, wz + 1)).normalized()
			normals.append(normal)
			var shade: float = 0.88 + normal.y * 0.12
			colors.append(Color(shade, shade, shade, 1))
			uvs.append(Vector2(wx / 30.0, wz / 30.0))
	for z in range(subdivisions):
		for x in range(subdivisions):
			var i: int = z * stride + x
			indices.append_array(PackedInt32Array([i, i + 1, i + stride, i + 1, i + stride + 1, i + stride]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(25.0, 60.0, [])
	var mesh: ArrayMesh = importer.get_mesh()
	mesh.surface_set_material(0, terrain_material)
	var chunk := MeshInstance3D.new()
	chunk.name = "Terrain_%d_%d" % [start_x, start_z]
	chunk.mesh = mesh
	chunk.visibility_range_end = 1450.0
	chunk.visibility_range_end_margin = 80.0
	add_child(chunk)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var terrain_shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	terrain_shape.backface_collision = true
	collision.shape = terrain_shape
	body.add_child(collision)
	add_child(body)

func _build_roads() -> void:
	road_material = ShaderMaterial.new()
	road_material.shader = load("res://shaders/road.gdshader")
	road_material.set_shader_parameter("gravel_albedo", MaterialLibrary.texture("gravel_albedo.jpg"))
	road_material.set_shader_parameter("gravel_normal", MaterialLibrary.texture("gravel_normal.png"))
	road_material.set_shader_parameter("gravel_orm", MaterialLibrary.texture("gravel_orm.png"))
	road_material.set_shader_parameter("edge_noise", noise_texture)
	_road_strip(Vector3(0, 0, 160), Vector3(0, 0, -470), 13.0, Color(0.40, 0.35, 0.27))
	_road_strip(Vector3(-145, 0, -280), Vector3(145, 0, -280), 10.0, Color(0.43, 0.37, 0.28))
	_road_strip(Vector3(-110, 0, -280), Vector3(-110, 0, -435), 8.0, Color(0.43, 0.37, 0.28))
	_road_strip(Vector3(100, 0, -280), Vector3(100, 0, -420), 8.0, Color(0.43, 0.37, 0.28))
	for side in [-1.0, 1.0]:
		_road_strip(Vector3(side * 3.0, 0, 80), Vector3(side * 3.0, 0, -455), 0.65, Color(0.32, 0.29, 0.23), 0.20)
	var center := Vector3(34, height_at(34, -182) + 0.08, -182)
	MeshFactory.cylinder(self, "Helipad", center, 18.0, 0.10, Color(0.72, 0.70, 0.62), 64, "concrete")
	var ring := TorusMesh.new()
	ring.inner_radius = 14.5
	ring.outer_radius = 15.1
	ring.rings = 48
	ring.ring_segments = 4
	var marking := MeshInstance3D.new()
	marking.mesh = ring
	marking.material_override = MaterialLibrary.surface("concrete", Color(0.85, 0.82, 0.66), 0.5)
	marking.position = center + Vector3.UP * 0.08
	marking.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marking)
	for x in [-3.0, 3.0]:
		MeshFactory.box(self, "HelipadH", center + Vector3(x, 0.10, 0), Vector3(1.0, 0.04, 9), Color(0.72, 0.69, 0.53), false)
	MeshFactory.box(self, "HelipadH", center + Vector3(0, 0.10, 0), Vector3(6, 0.04, 1), Color(0.72, 0.69, 0.53), false)

func _road_strip(from: Vector3, to: Vector3, width: float, color: Color, lift: float = 0.14) -> void:
	# Conform to the height field in both axes. A two-vertex-wide strip can sink
	# below the terrain between samples and produce severe z-fighting bands.
	var direction: Vector3 = (to - from).normalized()
	var side := Vector3(-direction.z, 0, direction.x) * width * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var length_steps: int = maxi(2, ceili(from.distance_to(to) / 3.0))
	var width_steps: int = maxi(2, ceili(width / 3.0))
	var stride: int = width_steps + 1
	for row in range(length_steps + 1):
		var center: Vector3 = from.lerp(to, float(row) / length_steps)
		for column in range(stride):
			var point: Vector3 = center + side * (float(column) / width_steps * 2.0 - 1.0)
			point.y = height_at(point.x, point.z) + lift
			vertices.append(point)
			uvs.append(Vector2(float(column) / width_steps, float(row) / length_steps * from.distance_to(to) / 6.0))
			normals.append(Vector3(height_at(point.x - 1.0, point.z) - height_at(point.x + 1.0, point.z), 2.0, height_at(point.x, point.z - 1.0) - height_at(point.x, point.z + 1.0)).normalized())
			if row < length_steps and column < width_steps:
				var i: int = row * stride + column
				indices.append_array(PackedInt32Array([i, i + 1, i + stride, i + 1, i + stride + 1, i + stride]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material: ShaderMaterial = road_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("tint", Vector3(color.r * 3.1, color.g * 3.0, color.b * 2.9))
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _build_base() -> void:
	_hangar(Vector3(-88, 0, -245), PI * 0.5, 0.85)
	_hangar(Vector3(72, 0, -310), -PI * 0.5, 1.0)
	_building(Vector3(-135, 0, -330), Vector3(22, 6, 14), "BarracksWest")
	_building(Vector3(135, 0, -360), Vector3(24, 7, 15), "BarracksEast")
	_building(Vector3(-25, 0, -440), Vector3(26, 8, 14), "CommandPost")
	for point in [Vector3(-155, 0, -195), Vector3(155, 0, -195), Vector3(-155, 0, -440), Vector3(155, 0, -440)]:
		_watchtower(point)
	for point in [Vector3(-38, 0, -210), Vector3(110, 0, -320), Vector3(-90, 0, -425)]:
		var section := Destructible.new()
		section.position = Vector3(point.x, height_at(point.x, point.z), point.z)
		add_child(section)
		section.configure("bunker%d" % destructibles.size(), "bunker", Vector3(9, 4.5, 8))
		destructibles.append(section)
	_fence(Vector3(-160, 0, -185), Vector3(160, 0, -185))
	_fence(Vector3(-160, 0, -185), Vector3(-160, 0, -460))
	_fence(Vector3(160, 0, -185), Vector3(160, 0, -460))
	_fence(Vector3(-160, 0, -460), Vector3(160, 0, -460))
	var mast := Node3D.new()
	mast.position = Vector3(-8, height_at(-8, -430), -430)
	add_child(mast)
	MeshFactory.cylinder(mast, "RadioMast", Vector3(0, 13, 0), 0.25, 26, Color(0.24, 0.27, 0.24))
	for height in [6.0, 12.0, 18.0]:
		MeshFactory.box(mast, "Crossbeam", Vector3(0, height, 0), Vector3(5, 0.15, 0.15), Color(0.28, 0.30, 0.26))
	radar = Node3D.new()
	radar.position.y = 25.0
	mast.add_child(radar)
	var dish: MeshInstance3D = MeshFactory.sphere(radar, "RadarDish", Vector3.ZERO, Vector3(3.2, 2.0, 0.25), Color(0.38, 0.41, 0.34))
	dish.rotation.x = 0.35
	MeshFactory.box(radar, "Receiver", Vector3(0, 0, -1.5), Vector3(0.2, 0.2, 3), Color(0.18, 0.21, 0.18))
	for index in range(6):
		var z: float = 40.0 - index * 72.0
		var pole := Node3D.new()
		pole.position = Vector3(18, height_at(18, z), z)
		add_child(pole)
		MeshFactory.cylinder(pole, "UtilityPole", Vector3(0, 5, 0), 0.16, 10, Color(0.55, 0.45, 0.32), 10, "wood")
		MeshFactory.box(pole, "Crossarm", Vector3(0, 9.4, 0), Vector3(3.2, 0.18, 0.18), Color(0.25, 0.27, 0.23))
		if index < 5:
			var wire := ImmediateMesh.new()
			wire.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for step in range(17):
				var t: float = step / 16.0
				wire.surface_add_vertex(Vector3(18, lerpf(height_at(18, z), height_at(18, z - 72), t) + 9.4 - sin(t * PI) * 1.5, z - t * 72.0))
			wire.surface_end()
			var wire_instance := MeshInstance3D.new()
			wire_instance.mesh = wire
			wire_instance.material_override = MeshFactory.material(Color(0.15, 0.17, 0.14))
			wire_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(wire_instance)

func _hangar(point: Vector3, yaw: float, size_scale: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(point.x, height_at(point.x, point.z), point.z)
	root.rotation.y = yaw
	root.scale = Vector3.ONE * size_scale
	add_child(root)
	if ResourceLoader.exists("res://assets/models/hangar.glb"):
		var hangar_model: Node3D = load("res://assets/models/hangar.glb").instantiate()
		hangar_model.rotation.y = PI
		root.add_child(hangar_model)
		MaterialLibrary.apply_to_model(hangar_model)
	else:
		MeshFactory.box(root, "Hangar", Vector3(0, 4, 0), Vector3(22, 8, 30), Color(0.72, 0.70, 0.60), true, "paint_sand")
		MeshFactory.box(root, "Door", Vector3(0, 3, 15.1), Vector3(14, 6, 0.15), Color(0.15, 0.18, 0.15))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for side in [-1.0, 1.0]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 7, 30)
		shape.shape = box
		shape.position = Vector3(side * 10.5, 3.5, 0)
		body.add_child(shape)
	var roof := CollisionShape3D.new()
	var roof_box := BoxShape3D.new()
	roof_box.size = Vector3(21, 1, 30)
	roof.shape = roof_box
	roof.position.y = 8.5
	body.add_child(roof)

func _building(point: Vector3, size: Vector3, building_name: String) -> void:
	var ground: float = height_at(point.x, point.z)
	var body: StaticBody3D = MeshFactory.static_box(self, building_name, Vector3(point.x, ground + size.y * 0.5, point.z), size, Color(0.82, 0.79, 0.70), true, "concrete")
	MeshFactory.box(body, "RoofLip", Vector3(0, 0.52, 0), Vector3(1.05, 0.05, 1.05), Color(0.55, 0.57, 0.50), true, "steel")
	for index in range(4):
		var x: float = (index - 1.5) * 0.21
		MeshFactory.box(body, "WindowFrame", Vector3(x, 0.1, 0.505), Vector3(0.12, 0.27, 0.015), Color(0.28, 0.29, 0.23))
		MeshFactory.box(body, "WindowGlass", Vector3(x, 0.1, 0.52), Vector3(0.095, 0.21, 0.01), Color.WHITE, true, "glass")
	MeshFactory.box(body, "Door", Vector3(0, -0.5 + 1.5 / size.y, 0.515), Vector3(2.0 / size.x, 3.0 / size.y, 0.01), Color(0.23, 0.27, 0.22))
	for index in range(2):
		MeshFactory.box(body, "RoofVent", Vector3((index - 0.5) * 0.25, 0.6, 0), Vector3(0.12, 0.15, 0.15), Color(0.34, 0.36, 0.30))

func _watchtower(point: Vector3) -> void:
	var root := Node3D.new()
	root.position = Vector3(point.x, height_at(point.x, point.z), point.z)
	add_child(root)
	for x in [-2.0, 2.0]:
		for z in [-2.0, 2.0]:
			MeshFactory.box(root, "TowerLeg", Vector3(x, 4.5, z), Vector3(0.3, 9, 0.3), Color(0.25, 0.28, 0.23))
	MeshFactory.box(root, "Platform", Vector3(0, 8, 0), Vector3(5.5, 0.4, 5.5), Color(0.35, 0.37, 0.29))
	MeshFactory.box(root, "Cabin", Vector3(0, 9.3, 0), Vector3(4.6, 2.3, 4.6), Color(0.43, 0.43, 0.32))
	MeshFactory.box(root, "Window", Vector3(0, 9.55, 2.32), Vector3(3.8, 1.0, 0.05), Color(0.12, 0.19, 0.19))
	MeshFactory.box(root, "Roof", Vector3(0, 10.6, 0), Vector3(5.5, 0.3, 5.5), Color(0.24, 0.28, 0.22))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5, 11, 5)
	collision.shape = shape
	collision.position.y = 5.5
	body.add_child(collision)

func _fence(from: Vector3, to: Vector3) -> void:
	var direction: Vector3 = (to - from).normalized()
	var length: float = from.distance_to(to)
	var count: int = int(length / 8.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	posts.mesh = mesh
	posts.instance_count = count + 1
	for index in range(count + 1):
		var point: Vector3 = from.lerp(to, float(index) / count)
		point.y = height_at(point.x, point.z) + 1.4
		posts.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.13, 2.8, 0.13)), point))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = posts
	instance.material_override = MaterialLibrary.surface("steel", Color(0.62, 0.64, 0.56), 1.5)
	add_child(instance)
	for height in [0.7, 1.5, 2.5]:
		var center: Vector3 = (from + to) * 0.5
		center.y = height_at(center.x, center.z) + height
		var rail: MeshInstance3D = MeshFactory.box(self, "FenceRail", center, Vector3(0.055, 0.055, length), Color(0.34, 0.35, 0.29), false)
		rail.rotation.y = atan2(direction.x, direction.z)

func _build_gun_position() -> void:
	MeshFactory.cylinder(self, "GunApron", Vector3(0, 1.91, 105), 12.0, 0.18, Color(0.70, 0.68, 0.60), 64, "concrete")
	_sandbags(Vector3(0, 2, 105), 14.0, 18, 0.25, PI - 0.25)
	for index in range(5):
		var crate := Destructible.new()
		crate.position = Vector3(13 + index % 2 * 2.7, 2.0, 110 + floorf(index / 2.0) * 2.7)
		add_child(crate)
		crate.configure("friendly_crate%d" % index, "crate", Vector3(2.3, 1.8, 2.0))
		destructibles.append(crate)
	MeshFactory.box(self, "FieldRadio", Vector3(-9, 2.8, 112), Vector3(1.5, 1.4, 0.8), Color(0.75, 0.78, 0.68), true, "paint_olive")
	MeshFactory.cylinder(self, "RadioAntenna", Vector3(-9.5, 5.5, 112), 0.025, 5.0, Color(0.12, 0.15, 0.12), 6)

func _sandbags(center: Vector3, radius: float, count: int, start: float, end: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var bags := MultiMesh.new()
	bags.transform_format = MultiMesh.TRANSFORM_3D
	bags.mesh = mesh
	bags.instance_count = count * 2
	for row in range(2):
		for index in range(count):
			var angle: float = lerpf(start, end, float(index + row * 0.5) / count)
			var point := center + Vector3(sin(angle) * radius, 0, cos(angle) * radius)
			point.y = height_at(point.x, point.z) + 0.35 + row * 0.58
			var basis := Basis(Vector3.UP, angle).scaled(Vector3(1.25, 0.36, 0.65))
			bags.set_instance_transform(row * count + index, Transform3D(basis, point))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = bags
	instance.material_override = MaterialLibrary.surface("fabric", Color(0.78, 0.73, 0.58), 1.6)
	add_child(instance)

func _build_scatter() -> void:
	for index in range(56):
		var x: float = rng.randf_range(-430, 430)
		var z: float = rng.randf_range(-540, 240)
		if absf(x) < 190 and z < -150 and z > -480:
			x += 240.0 if x >= 0 else -240.0
		if Vector2(x, z - 105).length() < 40:
			x += 70
		tree_points.append(Vector3(x, height_at(x, z), z))
	var rock_material: StandardMaterial3D = MaterialLibrary.surface("rock", Color(0.86, 0.82, 0.72), 0.55).duplicate() as StandardMaterial3D
	rock_material.vertex_color_use_as_albedo = true
	_scatter_mesh(_make_rock_mesh(17), rock_material, 240, 0)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.38
	trunk.height = 1.0
	trunk.radial_segments = 10
	_scatter_mesh(trunk, MaterialLibrary.surface("wood", Color(0.52, 0.44, 0.32), 1.8), tree_points.size(), 1)
	var canopy := SphereMesh.new()
	canopy.radius = 1.0
	canopy.height = 2.0
	canopy.radial_segments = 12
	canopy.rings = 7
	_scatter_mesh(canopy, MaterialLibrary.surface("foliage", Color(0.78, 0.82, 0.62), 0.8), tree_points.size() * 4, 2)
	var shrub := SphereMesh.new()
	shrub.radius = 1.0
	shrub.height = 2.0
	shrub.radial_segments = 10
	shrub.rings = 6
	_scatter_mesh(shrub, MaterialLibrary.surface("foliage", Color(0.72, 0.70, 0.48), 1.2), 120, 3)
	var grass := QuadMesh.new()
	grass.size = Vector2(1.7, 1.25)
	var grass_material := ShaderMaterial.new()
	grass_material.shader = load("res://shaders/vegetation.gdshader")
	grass_material.set_shader_parameter("card", MaterialLibrary.texture("grass_card.png"))
	_scatter_mesh(grass, grass_material, 420, 4)

func _make_rock_mesh(seed_value: int) -> ArrayMesh:
	var source := SphereMesh.new()
	source.radius = 1.0
	source.height = 2.0
	source.radial_segments = 14
	source.rings = 9
	var arrays: Array = source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	for index in range(vertices.size()):
		var direction: Vector3 = vertices[index].normalized()
		var noise: float = sin(direction.x * 9.0 + seed_value) * 0.10 + sin(direction.y * 13.0 + direction.z * 7.0) * 0.08 + sin(direction.z * 17.0 + seed_value * 0.3) * 0.05
		vertices[index] = direction * (1.0 + noise) * Vector3(1.0, 0.78, 1.0)
		var shade: float = 0.82 + 0.18 * (noise + 0.23) / 0.46
		colors.append(Color(shade, shade * 0.97, shade * 0.90))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _scatter_mesh(mesh: Mesh, material: Material, count: int, kind: int) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = count
	for index in range(count):
		var size: float = rng.randf_range(0.7, 2.8)
		var point := Vector3.ZERO
		var scale := Vector3.ONE
		if kind == 1 or kind == 2:
			point = tree_points[index % tree_points.size()]
			if kind == 1:
				scale = Vector3(1, 5 + size * 2, 1)
				point.y += scale.y * 0.5
			else:
				var cluster: int = index / tree_points.size()
				var offsets: Array[Vector3] = [Vector3(0, 0.4, 0), Vector3(2.6, -0.2, 1.2), Vector3(-2.4, 0.1, -1.0), Vector3(0.8, -0.5, -2.5)]
				point += offsets[cluster % offsets.size()] * (0.8 + size * 0.25)
				point.y += 5.2 + size * 1.7
				scale = Vector3(2.8 + size, 0.9 + size * 0.2, 2.5 + size)
		else:
			var x: float = rng.randf_range(-470, 470)
			var z: float = rng.randf_range(-580, 330)
			if index < 24:
				x = (30.0 + rng.randf() * 65.0) * (1.0 if index % 2 == 0 else -1.0)
				z = 90.0 - rng.randf() * 230.0
			if absf(x) < 180 and z < -160 and z > -475 and index >= 24:
				x += 220.0 if x >= 0 else -220.0
			if Vector2(x, z - 105).length() < 30:
				x += 60
			point = Vector3(x, height_at(x, z), z)
			if kind == 0:
				scale = Vector3(size * 1.5, size * 0.6, size)
				point.y += scale.y * 0.35
			elif kind == 4:
				scale = Vector3(size * 1.1, size * 0.9, 1.0)
				point.y += scale.y * 0.55
			else:
				scale = Vector3(size, size * 0.4, size * 0.8)
				point.y += scale.y * 0.4
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(scale)
		instances.set_instance_transform(index, Transform3D(basis, point))
		instances.set_instance_color(index, Color(0.84 + rng.randf() * 0.16, 0.86 + rng.randf() * 0.14, 0.80 + rng.randf() * 0.18))
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	node.material_override = material
	node.set_meta("full_count", count)
	node.set_meta("detail_kind", kind)
	node.add_to_group("environment_detail")
	node.visibility_range_end = 520.0 if kind >= 3 else 1200.0
	node.visibility_range_end_margin = 80.0
	add_child(node)

func _build_targets() -> void:
	for id in enemy_definitions:
		var definition: Dictionary = enemy_definitions[id]
		var resource: EnemyData = load("res://resources/enemies/%s.tres" % definition.type)
		var target := EnemyTarget.new()
		var point: Vector3 = definition.position
		point.y = height_at(point.x, point.z) + 0.08
		target.position = point
		var route := PackedVector3Array()
		for route_point in definition.route:
			route.append(Vector3(route_point.x, height_at(route_point.x, route_point.z), route_point.z))
		target.configure(resource, id, route, false)
		add_child(target)
		targets.append(target)

func _build_destructibles() -> void:
	for id in crate_definitions:
		var point: Vector3 = crate_definitions[id]
		var crate := Destructible.new()
		crate.position = Vector3(point.x, height_at(point.x, point.z), point.z)
		add_child(crate)
		crate.configure(id, "crate", Vector3(3.2, 3.0, 3.2))
		destructibles.append(crate)
	for point in [Vector3(-120, 0, -220), Vector3(125, 0, -265), Vector3(15, 0, -410)]:
		for index in range(3):
			MeshFactory.cylinder(self, "FuelDrum", Vector3(point.x + index * 1.3, height_at(point.x, point.z) + 0.8, point.z), 0.55, 1.6, Color(0.62, 0.66, 0.52), 20, "paint_olive")

func _batch_static_boxes() -> void:
	var groups: Dictionary = {}
	for node in find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh != MeshFactory.box_mesh or instance.material_override == null:
			continue
		var ancestor: Node = instance
		var dynamic: bool = false
		while ancestor != null and ancestor != self:
			if ancestor is Destructible or ancestor is EnemyTarget or ancestor == radar:
				dynamic = true
				break
			ancestor = ancestor.get_parent()
		if dynamic:
			continue
		var key: String = str(instance.material_override.get_instance_id()) + ":" + str(instance.cast_shadow)
		if not groups.has(key):
			groups[key] = {"material": instance.material_override, "shadow": instance.cast_shadow, "nodes": []}
		groups[key].nodes.append(instance)
	for key in groups:
		var group: Dictionary = groups[key]
		var nodes: Array = group.nodes
		if nodes.size() < 2:
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = MeshFactory.box_mesh
		multi.instance_count = nodes.size()
		for index in range(nodes.size()):
			var instance: MeshInstance3D = nodes[index]
			multi.set_instance_transform(index, global_transform.affine_inverse() * instance.global_transform)
			instance.queue_free()
		var batch := MultiMeshInstance3D.new()
		batch.name = "StaticBatch_" + key.get_slice(":", 0)
		batch.multimesh = multi
		batch.material_override = group.material
		batch.cast_shadow = group.shadow
		add_child(batch)

func configure_mission(mission: MissionData) -> void:
	for target in targets:
		target.required = target.target_id in mission.target_ids
	for crate in destructibles:
		crate.optional = crate.target_id == mission.optional_crate_id

func apply_quality(tier: String, settings: Dictionary) -> void:
	if noise_texture:
		var size: int = int(settings.texture_size)
		noise_texture.width = size
		noise_texture.height = size
	if sun:
		sun.shadow_enabled = bool(settings.shadows)
		sun.directional_shadow_max_distance = float(settings.shadow_distance)
	if environment:
		var env: Environment = environment.environment
		var method: String = RenderingServer.get_current_rendering_method()
		var ssao_supported: bool = method == "gl_compatibility" or method == "forward_plus"
		env.ssao_enabled = bool(settings.get("ssao", false)) and ssao_supported
		env.ssao_radius = 1.35
		env.ssao_intensity = 1.75
		env.ssao_light_affect = 0.22
		env.ssao_detail = 0.65
		env.glow_enabled = bool(settings.get("glow", false))
		env.glow_intensity = 0.32
		env.glow_bloom = 0.06
		env.glow_hdr_threshold = 1.05
		env.glow_hdr_scale = 1.4
		env.fog_density = 0.00055 if tier != "low" else 0.0009
		env.fog_aerial_perspective = 0.22 if tier != "low" else 0.12
	for node in get_tree().get_nodes_in_group("environment_detail"):
		if is_ancestor_of(node):
			var count: int = int(node.get_meta("full_count", 1))
			node.multimesh.visible_instance_count = maxi(1, int(count * float(settings.detail)))
			node.visibility_range_end = float(settings.visibility) * (0.38 if int(node.get_meta("detail_kind", 0)) >= 3 else 1.0)
