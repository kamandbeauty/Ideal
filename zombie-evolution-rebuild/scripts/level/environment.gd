extends Node3D

const LENGTH := 180.0
const HALF_WIDTH := 6.0
var box_meshes: Dictionary = {}

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var atmosphere := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.055, 0.13, 0.23)
	sky_material.sky_horizon_color = Color(0.48, 0.61, 0.70)
	sky_material.ground_bottom_color = Color(0.24, 0.34, 0.44)
	sky_material.ground_horizon_color = Color(0.70, 0.79, 0.84)
	atmosphere.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = atmosphere
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.82, 0.90)
	env.ambient_light_energy = 0.82
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.61, 0.68, 0.73)
	env.fog_density = 0.0032
	world.environment = env
	add_child(world)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-42, -28, 0)
	sunlight.light_color = Color(1.0, 0.88, 0.73)
	sunlight.light_energy = 1.35
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 78.0
	add_child(sunlight)

	var concrete := asphalt_material(Color(0.50, 0.54, 0.57))
	var alternate := asphalt_material(Color(0.45, 0.49, 0.52))
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
		add_box(Vector3(0, -0.5, z), Vector3(12, 1, 8.0), concrete if i % 3 != 0 else alternate)
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
	create_bridge_superstructure(steel, edge, amber)
	create_city_entrance()
	# Two batched MultiMeshes keep the layered cloud banks to two draw calls.
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 1.0
	cloud_mesh.height = 2.0
	cloud_mesh.radial_segments = 24
	cloud_mesh.rings = 12
	var cloud_mat := new_material(Color(0.79, 0.86, 0.92), 1.0)
	var cloud_highlight := new_material(Color(0.94, 0.97, 1.0), 1.0)
	var random := RandomNumberGenerator.new()
	random.seed = 473
	var cloud_cores := MultiMesh.new()
	cloud_cores.transform_format = MultiMesh.TRANSFORM_3D
	cloud_cores.mesh = cloud_mesh
	cloud_cores.instance_count = 48
	var cloud_lobes := MultiMesh.new()
	cloud_lobes.transform_format = MultiMesh.TRANSFORM_3D
	cloud_lobes.mesh = cloud_mesh
	cloud_lobes.instance_count = 96
	for i in range(48):
		var side := -1.0 if i % 2 == 0 else 1.0
		var bank_position := Vector3(side * random.randf_range(14, 21), random.randf_range(-4.5, -2.0), float(i / 2) * 8.0 - 8.0)
		var core_scale := Vector3(random.randf_range(5.5, 7.0), random.randf_range(2.0, 2.8), random.randf_range(5.0, 6.5))
		cloud_cores.set_instance_transform(i, Transform3D(Basis.from_scale(core_scale), bank_position))
		for lobe_index in range(2):
			var offset := Vector3(-2.2 if lobe_index == 0 else 2.0, 0.25, 0.8 if lobe_index == 0 else -0.9)
			var lobe_scale := Vector3(4.1, 2.0, 3.8)
			cloud_lobes.set_instance_transform(i * 2 + lobe_index, Transform3D(Basis.from_scale(lobe_scale), bank_position + offset))
	var cloud_core_batch := MultiMeshInstance3D.new()
	cloud_core_batch.name = "CloudCoreBatch"
	cloud_core_batch.multimesh = cloud_cores
	cloud_core_batch.material_override = cloud_mat
	add_child(cloud_core_batch)
	var cloud_lobe_batch := MultiMeshInstance3D.new()
	cloud_lobe_batch.name = "CloudHighlightBatch"
	cloud_lobe_batch.multimesh = cloud_lobes
	cloud_lobe_batch.material_override = cloud_highlight
	add_child(cloud_lobe_batch)


func create_bridge_superstructure(steel: StandardMaterial3D, edge: StandardMaterial3D, amber: StandardMaterial3D) -> void:
	# Lightweight suspension-bridge trusses add a strong silhouette without
	# changing the collision deck, player route, or enemy navigation.
	var structure := Node3D.new()
	structure.name = "BridgeSuperstructure"
	add_child(structure)
	var cable := new_material(Color(0.075, 0.105, 0.13), 0.34)
	var brace := new_material(Color(0.23, 0.29, 0.32), 0.48)
	for z in range(12, 157, 24):
		var portal := Node3D.new()
		portal.name = "SuspensionPortal_%03d" % z
		portal.position.z = float(z)
		structure.add_child(portal)
		for side in [-1.0, 1.0]:
			add_box(Vector3(side * 5.36, 3.55, 0), Vector3(0.26, 5.8, 0.30), steel, portal)
			add_box(Vector3(side * 5.36, 6.55, 0), Vector3(0.38, 0.20, 0.40), edge, portal)
			add_beam(Vector3(side * 5.36, 1.2, -4.0), Vector3(side * 5.36, 6.35, 0), 0.12, brace, portal)
			add_beam(Vector3(side * 5.36, 6.35, 0), Vector3(side * 5.36, 1.2, 4.0), 0.12, brace, portal)
			add_box(Vector3(side * 5.36, 3.25, -6.0), Vector3(0.08, 4.8, 0.08), cable, portal)
			add_box(Vector3(side * 5.36, 3.25, 6.0), Vector3(0.08, 4.8, 0.08), cable, portal)
			add_box(Vector3(side * 5.36, 6.42, 0), Vector3(0.10, 0.10, 24.0), cable, portal)
		add_box(Vector3(0, 6.55, 0), Vector3(10.9, 0.16, 0.24), steel, portal)
		add_box(Vector3(0, -0.12, 0), Vector3(11.5, 0.14, 0.28), edge, portal)
	# Roadside lighting and deck joints provide readable scale and rhythm.
	for z in range(18, 157, 36):
		for side in [-1.0, 1.0]:
			add_box(Vector3(side * 4.95, 2.05, float(z)), Vector3(0.10, 2.0, 0.10), steel, structure)
			add_box(Vector3(side * 4.72, 3.0, float(z)), Vector3(0.55, 0.10, 0.10), steel, structure)
			add_box(Vector3(side * 4.48, 2.92, float(z)), Vector3(0.18, 0.12, 0.24), amber, structure)
	for z in range(8, 168, 8):
		add_box(Vector3(0, 0.025, float(z)), Vector3(11.2, 0.035, 0.10), edge, structure)

func add_beam(start: Vector3, finish: Vector3, width: float, material: Material, parent: Node3D) -> void:
	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, start.distance_to(finish))
	beam.mesh = mesh
	beam.material_override = material
	beam.position = (start + finish) * 0.5
	beam.basis = Basis.looking_at((finish - start).normalized(), Vector3.UP)
	parent.add_child(beam)

func create_city_entrance() -> void:
	# A distant entrance at the end of the bridge; no collision blocks the run.
	var entrance := Node3D.new()
	entrance.name = "CityEntrance"
	entrance.position.z = 169.0
	add_child(entrance)
	var stone := concrete_material(Color(0.64, 0.69, 0.70))
	var trim := new_material(Color(0.22, 0.28, 0.32), 0.74)
	var metal := new_material(Color(0.11, 0.18, 0.22), 0.55)
	var light := new_material(Color(1.0, 0.61, 0.22), 0.45)
	light.emission_enabled = true
	light.emission = Color(0.85, 0.27, 0.04)
	for side in [-1, 1]:
		add_box(Vector3(side * 6.5, 5.1, 0), Vector3(2.0, 10.2, 3.1), stone, entrance)
		add_box(Vector3(side * 6.5, 10.25, 0), Vector3(2.3, 0.40, 3.4), trim, entrance)
		add_box(Vector3(side * 5.38, 4.3, -0.7), Vector3(0.28, 8.6, 1.5), trim, entrance)
		add_box(Vector3(side * 6.5, 0.65, -0.15), Vector3(2.35, 1.30, 3.5), trim, entrance)
		for height in [2.0, 4.2, 6.4]:
			add_box(Vector3(side * 6.5, height, -1.57), Vector3(2.03, 0.10, 0.12), trim, entrance)
		for x_offset in [-0.76, 0.76]:
			add_box(Vector3(side * 6.5 + x_offset, 4.7, -1.59), Vector3(0.12, 8.0, 0.12), trim, entrance)
		add_box(Vector3(side * 6.5, 7.5, -1.58), Vector3(0.7, 1.5, 0.12), metal, entrance)
		add_box(Vector3(side * 6.5, 7.55, -1.68), Vector3(0.3, 0.6, 0.1), light, entrance)
		for offset in [-0.72, 0.0, 0.72]:
			add_box(Vector3(side * 6.5 + offset, 10.8, -0.95), Vector3(0.4, 0.9, 0.5), stone, entrance)
		# Silhouettes hint at the city beyond without replacing the cloud setting.
		add_box(Vector3(side * 10.0, 4.3, 8.5), Vector3(4.0, 8.6, 4.0), trim, entrance)
		add_box(Vector3(side * 10.0, 8.75, 8.5), Vector3(4.2, 0.35, 4.2), stone, entrance)
	# Visible building fronts sit beyond the arch, beside a clear central road.
	var buildings := Node3D.new()
	buildings.name = "CityBuildings"
	entrance.add_child(buildings)
	var facade := concrete_material(Color(0.72, 0.74, 0.72))
	var windows := new_material(Color(0.17, 0.30, 0.35), 0.28)
	add_box(Vector3(0, -0.14, 8.0), Vector3(11.0, 0.22, 12.0), trim, buildings)
	for side in [-1, 1]:
		add_box(Vector3(side * 4.0, 3.5, 10.0), Vector3(3.5, 7.0, 3.8), facade, buildings)
		add_box(Vector3(side * 4.0, 7.15, 10.0), Vector3(3.7, 0.30, 4.0), trim, buildings)
		for floor_height in [0.85, 2.75, 4.60, 6.45]:
			add_box(Vector3(side * 4.0, floor_height, 8.0), Vector3(3.55, 0.10, 0.15), trim, buildings)
		for floor_index in range(3):
			for horizontal in [-0.75, 0.75]:
				add_box(Vector3(side * 4.0 + horizontal, 1.6 + floor_index * 1.85, 8.03), Vector3(0.70, 1.05, 0.14), windows, buildings)
				add_box(Vector3(side * 4.0 + horizontal, 1.05 + floor_index * 1.85, 7.94), Vector3(0.85, 0.08, 0.22), trim, buildings)
		add_box(Vector3(side * 4.0, 7.8, 10.0), Vector3(1.8, 1.3, 2.0), trim, buildings)
	add_box(Vector3(0, 8.9, 0), Vector3(11.5, 1.6, 2.0), stone, entrance)
	add_box(Vector3(0, 8.05, -1.06), Vector3(11.1, 0.22, 0.22), trim, entrance)
	add_box(Vector3(0, 9.8, -1.06), Vector3(11.1, 0.22, 0.22), trim, entrance)
	var sign := Label3D.new()
	sign.font = preload("res://assets/fonts/DejaVuSans.ttf")
	sign.text = "ورودی شهر"
	sign.font_size = 80
	sign.pixel_size = 0.009
	sign.outline_size = 8
	sign.outline_modulate = Color(0.03, 0.05, 0.08)
	sign.position = Vector3(0, 8.9, -1.15)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	entrance.add_child(sign)

func concrete_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/city_concrete.gdshader")
	material.set_shader_parameter("concrete_texture", preload("res://assets/environment/city_concrete.png"))
	material.set_shader_parameter("tint", color)
	return material

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

func add_box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> void:
	var box := MeshInstance3D.new()
	if not box_meshes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		box_meshes[size] = mesh
	box.mesh = box_meshes[size]
	box.material_override = mat
	box.position = pos
	if parent == null:
		add_child(box)
	else:
		parent.add_child(box)
