class_name CoastalBattlefield
extends Node3D
## First visual milestone: one coastal beachhead, ocean, mountains and defensive works.
var terrain_material: ShaderMaterial
var ocean_material: ShaderMaterial
var noise_texture: NoiseTexture2D
var sun: DirectionalLight3D
var environment: WorldEnvironment
var barrels: Array[CoastalBarrel] = []
var cover_points: Array[Vector3] = []
var landing_zones: Array[Vector3] = [Vector3(-42, 0, -46), Vector3(0, 0, -52), Vector3(44, 0, -44)]
var rng := RandomNumberGenerator.new()

static func height_at(x: float, z: float) -> float:
	return CoastalTerrain.height_at(x, z)

func _ready() -> void:
	name = "CoastalBeachhead"
	rng.seed = 51422
	add_to_group("quality_listener")
	_build_lighting()
	_build_terrain()
	_build_ocean()
	_build_mountains()
	_build_defenses()
	_build_structures()
	_build_scatter()
	apply_quality(Graphics.tier, Graphics.profile())

func _build_lighting() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	if ResourceLoader.exists("res://assets/textures/pbr/sky_panorama.jpg"):
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load("res://assets/textures/pbr/sky_panorama.jpg")
		panorama.energy_multiplier = 1.05
		sky.sky_material = panorama
	else:
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color(0.18, 0.34, 0.52)
		sky_material.sky_horizon_color = Color(0.72, 0.78, 0.80)
		sky_material.ground_bottom_color = Color(0.24, 0.26, 0.24)
		sky_material.ground_horizon_color = Color(0.66, 0.70, 0.68)
		sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.72, 0.76)
	env.fog_light_energy = 0.95
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.12
	env.fog_aerial_perspective = 0.42
	env.fog_sun_scatter = 0.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.96
	env.adjustment_contrast = 1.06
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.name = "CoastalSun"
	sun.rotation_degrees = Vector3(-36.0, -24.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.shadow_bias = 0.8
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_max_distance = 200.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

func _build_terrain() -> void:
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = load("res://shaders/beach.gdshader")
	var noise := FastNoiseLite.new()
	noise.seed = 912
	noise.frequency = 0.03
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
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var x_steps: int = 88
	var z_steps: int = 52
	var x_min: float = -230.0
	var x_max: float = 230.0
	var z_min: float = -70.0
	var z_max: float = 140.0
	for zi in range(z_steps + 1):
		for xi in range(x_steps + 1):
			var x: float = lerpf(x_min, x_max, float(xi) / x_steps)
			var z: float = lerpf(z_min, z_max, float(zi) / z_steps)
			var y: float = height_at(x, z)
			vertices.append(Vector3(x, y, z))
			var normal := Vector3(height_at(x - 1, z) - height_at(x + 1, z), 2.0, height_at(x, z - 1) - height_at(x, z + 1)).normalized()
			normals.append(normal)
			var shade: float = 0.9 + normal.y * 0.1
			colors.append(Color(shade, shade, shade))
			uvs.append(Vector2(x / 24.0, z / 24.0))
	for zi in range(z_steps):
		for xi in range(x_steps):
			var i: int = zi * (x_steps + 1) + xi
			indices.append_array(PackedInt32Array([i, i + 1, i + x_steps + 1, i + 1, i + x_steps + 2, i + x_steps + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, terrain_material)
	var instance := MeshInstance3D.new()
	instance.name = "BeachTerrain"
	instance.mesh = mesh
	add_child(instance)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _build_ocean() -> void:
	ocean_material = ShaderMaterial.new()
	ocean_material.shader = load("res://shaders/ocean.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(1500, 1100)
	plane.subdivide_width = 96
	plane.subdivide_depth = 96
	var ocean := MeshInstance3D.new()
	ocean.name = "Ocean"
	ocean.mesh = plane
	ocean.material_override = ocean_material
	ocean.position = Vector3(0, 0.0, -330)
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean)

func _build_mountains() -> void:
	var rock: StandardMaterial3D = MaterialLibrary.surface("rock", Color(0.62, 0.66, 0.7), 0.35)
	rock.cull_mode = BaseMaterial3D.CULL_DISABLED
	var x_steps: int = 120
	var z_steps: int = 18
	var x_min: float = -950.0
	var x_max: float = 950.0
	var z_min: float = -780.0
	var z_max: float = -470.0
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for zi in range(z_steps + 1):
		for xi in range(x_steps + 1):
			var x: float = lerpf(x_min, x_max, float(xi) / x_steps)
			var z: float = lerpf(z_min, z_max, float(zi) / z_steps)
			var y: float = _ridge_height(x, z, x_min, x_max, z_min, z_max)
			vertices.append(Vector3(x, y, z))
			var normal := Vector3(_ridge_height(x - 2, z, x_min, x_max, z_min, z_max) - _ridge_height(x + 2, z, x_min, x_max, z_min, z_max), 4.0, _ridge_height(x, z - 2, x_min, x_max, z_min, z_max) - _ridge_height(x, z + 2, x_min, x_max, z_min, z_max)).normalized()
			normals.append(normal)
			var altitude: float = clampf(y / 180.0, 0.0, 1.0)
			var color: Color = Color(0.34, 0.38, 0.34).lerp(Color(0.68, 0.71, 0.74), altitude)
			colors.append(color)
	for zi in range(z_steps):
		for xi in range(x_steps):
			var i: int = zi * (x_steps + 1) + xi
			indices.append_array(PackedInt32Array([i, i + 1, i + x_steps + 1, i + 1, i + x_steps + 2, i + x_steps + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = "DistantMountainRange"
	instance.mesh = mesh
	instance.material_override = rock
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _ridge_height(x: float, z: float, x_min: float, x_max: float, z_min: float, z_max: float) -> float:
	var peaks: Array[Vector3] = [Vector3(-720, 150, 190), Vector3(-430, 185, 230), Vector3(-140, 130, 180), Vector3(150, 205, 260), Vector3(430, 160, 210), Vector3(720, 140, 190)]
	var height: float = 0.0
	for peak in peaks:
		var dx: float = (x - peak.x) / peak.z
		height += peak.y * exp(-dx * dx)
	height += sin(x * 0.021) * 14.0 + sin(x * 0.053 + 1.7) * 7.0
	var zt: float = (z - z_min) / (z_max - z_min)
	var xt: float = (x - x_min) / (x_max - x_min)
	return maxf(0.0, height * sin(zt * PI) * smoothstep(0.0, 0.08, xt) * (1.0 - smoothstep(0.92, 1.0, xt)))

func _build_defenses() -> void:
	for x in [-70.0, -42.0, -14.0, 14.0, 42.0, 70.0]:
		var z: float = 30.0 + sin(x * 0.1) * 3.0
		var point := Vector3(x, height_at(x, z), z)
		MeshFactory.static_box(self, "ConcreteBarrier", point + Vector3.UP * 0.65, Vector3(3.4, 1.3, 0.9), Color(0.78, 0.76, 0.7), true, "concrete")
		cover_points.append(point + Vector3(0, 0, 3.2))
		_hedgehog(point + Vector3(rng.randf_range(-4, 4), 0, -5.0))
	for z in [12.0, -2.0]:
		for x in [-58.0, -28.0, 2.0, 32.0, 62.0]:
			_hedgehog(Vector3(x, height_at(x, z), z))
	_sandbag_line(Vector3(-10, 0, 52), 8.0, 10)
	_sandbag_line(Vector3(12, 0, 54), 7.0, 9)
	for point in [Vector3(-24, 0, 38), Vector3(26, 0, 40), Vector3(-6, 0, 24), Vector3(52, 0, 34), Vector3(-52, 0, 36)]:
		var barrel := CoastalBarrel.new()
		barrel.position = Vector3(point.x, height_at(point.x, point.z), point.z)
		add_child(barrel)
		barrels.append(barrel)

func _hedgehog(point: Vector3) -> void:
	var root := Node3D.new()
	root.position = point + Vector3.UP * 0.6
	root.rotation.y = rng.randf_range(0, TAU)
	add_child(root)
	for rotation in [Vector3(0, 0, 0.7), Vector3(0.7, 0, -0.7), Vector3(-0.7, 0, -0.7)]:
		var beam: MeshInstance3D = MeshFactory.box(root, "SteelBeam", Vector3.ZERO, Vector3(0.16, 0.16, 2.4), Color(0.42, 0.44, 0.4), true, "steel")
		beam.rotation = rotation

func _sandbag_line(center: Vector3, radius: float, count: int) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var bags := MultiMesh.new()
	bags.transform_format = MultiMesh.TRANSFORM_3D
	bags.mesh = mesh
	bags.instance_count = count * 2
	for row in range(2):
		for index in range(count):
			var angle: float = lerpf(-0.9, 0.9, float(index + row * 0.5) / count)
			var point := center + Vector3(sin(angle) * radius, 0, cos(angle) * radius * 0.35)
			point.y = height_at(point.x, point.z) + 0.28 + row * 0.45
			var basis := Basis(Vector3.UP, angle).scaled(Vector3(1.0, 0.28, 0.5))
			bags.set_instance_transform(row * count + index, Transform3D(basis, point))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = bags
	instance.material_override = MaterialLibrary.surface("fabric", Color(0.78, 0.74, 0.58), 1.7)
	add_child(instance)

func _build_structures() -> void:
	for point in [Vector3(-46, 0, 62), Vector3(48, 0, 66)]:
		var ground: float = height_at(point.x, point.z)
		var bunker := MeshFactory.static_box(self, "Bunker", Vector3(point.x, ground + 1.4, point.z), Vector3(8, 2.8, 6), Color(0.74, 0.72, 0.66), true, "concrete")
		MeshFactory.box(bunker, "Roof", Vector3(0, 0.55, 0), Vector3(1.12, 0.12, 1.12), Color(0.55, 0.56, 0.5), true, "concrete")
		MeshFactory.box(bunker, "Embrasure", Vector3(0, 0.1, -0.51), Vector3(0.5, 0.18, 0.02), Color(0.05, 0.06, 0.06), false, "black_bore")
	var tower := Node3D.new()
	tower.position = Vector3(78, height_at(78, 58), 58)
	add_child(tower)
	for x in [-1.6, 1.6]:
		for z in [-1.6, 1.6]:
			MeshFactory.box(tower, "Leg", Vector3(x, 3.5, z), Vector3(0.25, 7, 0.25), Color(0.45, 0.46, 0.4), true, "steel")
	MeshFactory.box(tower, "Cabin", Vector3(0, 7.4, 0), Vector3(3.8, 1.9, 3.8), Color(0.6, 0.6, 0.52), true, "paint_sand")
	MeshFactory.box(tower, "Roof", Vector3(0, 8.5, 0), Vector3(4.2, 0.25, 4.2), Color(0.4, 0.42, 0.38), true, "steel")
	for index in range(6):
		var point := Vector3(-18 + index % 3 * 3.0, 0, 66 + floorf(index / 3.0) * 2.6)
		MeshFactory.box(self, "SupplyCrate", Vector3(point.x, height_at(point.x, point.z) + 0.6, point.z), Vector3(1.8, 1.2, 1.6), Color(0.7, 0.58, 0.4), true, "wood")

func _build_scatter() -> void:
	var rock_material: StandardMaterial3D = MaterialLibrary.surface("rock", Color(0.8, 0.78, 0.7), 0.5)
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var rocks := MultiMesh.new()
	rocks.transform_format = MultiMesh.TRANSFORM_3D
	rocks.use_colors = true
	rocks.mesh = mesh
	rocks.instance_count = 120
	for index in range(120):
		var x: float = rng.randf_range(-180, 180)
		var z: float = rng.randf_range(-30, 110)
		if Vector2(x, z - 58).length() < 16:
			x += 28
		var size: float = rng.randf_range(0.35, 1.8)
		var point := Vector3(x, height_at(x, z) + size * 0.18, z)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(size * 1.3, size * 0.55, size))
		rocks.set_instance_transform(index, Transform3D(basis, point))
		rocks.set_instance_color(index, Color(0.8 + rng.randf() * 0.2, 0.78 + rng.randf() * 0.2, 0.7 + rng.randf() * 0.2))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = rocks
	instance.material_override = rock_material
	instance.visibility_range_end = 700.0
	add_child(instance)

func random_cover() -> Vector3:
	if cover_points.is_empty():
		return Vector3(0, height_at(0, 30), 30)
	return cover_points[rng.randi_range(0, cover_points.size() - 1)]

func apply_quality(tier: String, settings: Dictionary) -> void:
	if noise_texture:
		noise_texture.width = int(settings.texture_size)
		noise_texture.height = int(settings.texture_size)
	if terrain_material:
		terrain_material.set_shader_parameter("detail_enabled", int(settings.texture_size) >= 512)
	if ocean_material:
		ocean_material.set_shader_parameter("wave_height", 0.22 if tier != "low" else 0.14)
	if sun:
		sun.shadow_enabled = bool(settings.shadows)
		sun.directional_shadow_max_distance = float(settings.shadow_distance)
	if environment:
		var env: Environment = environment.environment
		var method: String = RenderingServer.get_current_rendering_method()
		env.ssao_enabled = bool(settings.get("ssao", false)) and (method == "gl_compatibility" or method == "forward_plus")
		env.ssao_radius = 1.2
		env.ssao_intensity = 1.5
		env.glow_enabled = bool(settings.get("glow", false))
		env.glow_intensity = 0.28
		env.fog_density = 0.0016 if tier != "low" else 0.0016
