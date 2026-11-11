extends Node3D

const LENGTH := 180.0
const HALF_WIDTH := 6.0

func _ready() -> void:
	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.41, 0.72, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.88, 1.0)
	env.ambient_light_energy = 0.85
	sky.environment = env
	add_child(sky)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-50, -35, 0)
	sunlight.light_energy = 1.1
	add_child(sunlight)
	var stone := new_material(Color(0.64, 0.60, 0.51))
	var steel := new_material(Color(0.39, 0.45, 0.49))
	var dark := new_material(Color(0.29, 0.33, 0.35))
	# A single collision body provides a continuous surface despite visible seams.
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
		add_box(Vector3(0, -0.5, z), Vector3(12, 1, 7.94), stone if i < 12 else steel)
		for side in [-1, 1]:
			add_box(Vector3(side * 5.85, 0.15, z), Vector3(0.3, 0.3, 8), dark)
			if i % 5 != 0:
				add_box(Vector3(side * 5.85, 0.8, z), Vector3(0.25, 1.4, 0.3), dark)
	# Low-poly shared cloud mesh; every cloud stays beyond the playable surface.
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 1.0
	cloud_mesh.height = 2.0
	cloud_mesh.radial_segments = 10
	cloud_mesh.rings = 5
	var cloud_mat := new_material(Color(0.97, 0.98, 1.0))
	var random := RandomNumberGenerator.new()
	random.seed = 473
	for i in range(58):
		var cloud := MeshInstance3D.new()
		cloud.mesh = cloud_mesh
		cloud.material_override = cloud_mat
		var side := -1.0 if i % 2 == 0 else 1.0
		cloud.position = Vector3(side * random.randf_range(15, 26), random.randf_range(-6, -3), float(i / 2) * 7.0 - 5.0)
		cloud.scale = Vector3(random.randf_range(5, 8), random.randf_range(2, 4), random.randf_range(5, 8))
		add_child(cloud)

func new_material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	return result

func add_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.position = pos
	box.material_override = mat
	add_child(box)
