extends Node3D

const LENGTH := 180.0
const HALF_WIDTH := 6.0
var box_meshes: Dictionary = {}

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var atmosphere := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.22, 0.35)
	sky_material.sky_horizon_color = Color(0.64, 0.70, 0.74)
	sky_material.ground_bottom_color = Color(0.24, 0.34, 0.44)
	sky_material.ground_horizon_color = Color(0.64, 0.70, 0.74)
	atmosphere.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = atmosphere
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.78, 0.88)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.61, 0.68, 0.73)
	env.fog_density = 0.0025
	world.environment = env
	add_child(world)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-42, -28, 0)
	sunlight.light_color = Color(1.0, 0.88, 0.73)
	sunlight.light_energy = 1.25
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 60.0
	add_child(sunlight)

	var concrete := asphalt_material(Color(1.0, 1.0, 1.0))
	var alternate := asphalt_material(Color(0.94, 0.95, 0.96))
	var steel := new_material(Color(0.19, 0.25, 0.29), 0.6)
	var edge := new_material(Color(0.12, 0.17, 0.20), 0.8)
	var lane := new_material(Color(0.75, 0.66, 0.40), 0.95)
	var amber := new_material(Color(1.0, 0.46, 0.12), 0.5)
	amber.emission_enabled = true
	amber.emission = Color(0.65, 0.15, 0.02)
	# Collision dimensions and bridge route remain unchanged.
	var surface := StaticBody3D.new()
	surface.collision_layer = 1
	surface.collision_mask = 0
	var shape := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(12, 1, LENGTH)
	shape.shape = floor_shape
	shape.position = Vector3(0, -0.5, LENGTH / 2.0 - 5)
	surface.add_child(shape)
	add_child(surface)
	for i in range(23):
		var z := float(i) * 8.0
		add_box(Vector3(0, -0.5, z), Vector3(12, 1, 7.94), concrete if i % 3 != 0 else alternate)
		# A restrained centre marking makes speed and perspective easier to read.
		add_box(Vector3(0, 0.012, z), Vector3(0.10, 0.02, 3.2), lane)
		for side in [-1, 1]:
			add_box(Vector3(side * 5.34, 0.014, z), Vector3(0.08, 0.025, 7.94), lane)
			add_box(Vector3(side * 5.78, 0.18, z), Vector3(0.38, 0.36, 8), edge)
			add_box(Vector3(side * 5.78, 1.12, z), Vector3(0.12, 0.12, 8), steel)
			for offset in [-2.5, 2.5]:
				add_box(Vector3(side * 5.78, 0.58, z + offset), Vector3(0.16, 1.16, 0.16), steel)
			if i % 3 == 0:
				add_box(Vector3(side * 5.58, 0.38, z), Vector3(0.08, 0.18, 0.48), amber)
	# Clouds stay outside the playable bridge on both sides.
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 1.0
	cloud_mesh.height = 2.0
	cloud_mesh.radial_segments = 16
	cloud_mesh.rings = 8
	var cloud_mat := new_material(Color(0.78, 0.84, 0.87), 1.0)
	var random := RandomNumberGenerator.new()
	random.seed = 473
	for i in range(72):
		var cloud := MeshInstance3D.new()
		cloud.mesh = cloud_mesh
		cloud.material_override = cloud_mat
		var side := -1.0 if i % 2 == 0 else 1.0
		cloud.position = Vector3(side * random.randf_range(15, 27), random.randf_range(-7, -3.5), float(i / 2) * 6.0 - 8.0)
		cloud.scale = Vector3(random.randf_range(5, 9), random.randf_range(2, 4), random.randf_range(5, 9))
		add_child(cloud)

func asphalt_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/bridge_asphalt.gdshader")
	material.set_shader_parameter("asphalt_texture", preload("res://assets/environment/road_asphalt_tile.png"))
	material.set_shader_parameter("asphalt_color", color)
	return material

func new_material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result

func add_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var box := MeshInstance3D.new()
	if not box_meshes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		box_meshes[size] = mesh
	box.mesh = box_meshes[size]
	box.material_override = mat
	box.position = pos
	add_child(box)
