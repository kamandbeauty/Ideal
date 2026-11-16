class_name DistrictLandmarks
extends Node3D
## Seven new skyline sets over the established city lanes. Decorative, never
## colliders: the wave routes and the two destructible defenses stay intact.

var steel: StandardMaterial3D
var concrete: StandardMaterial3D
var warning: StandardMaterial3D


func build(district: int) -> void:
	name = "DistrictLandmarks%d" % district
	steel = _material(Color(0.20, 0.23, 0.23))
	concrete = _material(Color(0.44, 0.42, 0.38))
	warning = _material(Color(0.60, 0.27, 0.12))
	match district:
		3: # factories and tall chimneys
			for side: int in [-1, 1]:
				_box(Vector3(side * 39, 12, -111), Vector3(22, 24, 22), concrete)
				for offset: int in [-1, 1]:
					_cylinder(Vector3(side * 39 + offset * 6, 35, -119), 2.0, 48.0, steel)
					_box(Vector3(side * 39 + offset * 6, 54, -119), Vector3(4.5, 3, 4.5), warning)
		4: # bazaar: arcaded roofs and domes
			for side: int in [-1, 1]:
				_box(Vector3(side * 38, 10, -106), Vector3(26, 20, 30), concrete)
				for index: int in 3:
					_dome(Vector3(side * 38, 20, -116 + index * 10), 6.5, warning)
		5: # terminal canopies and sign masts
			for side: int in [-1, 1]:
				_box(Vector3(side * 37, 18, -110), Vector3(24, 2, 35), steel)
				for z: int in [-122, -100]:
					_box(Vector3(side * 37, 9, z), Vector3(2, 18, 2), concrete)
				_box(Vector3(side * 37, 25, -110), Vector3(20, 7, 1), warning)
		6: # high-rise apartment towers, with illuminated bands
			for side: int in [-1, 1]:
				_box(Vector3(side * 41, 35, -120), Vector3(18, 70, 20), concrete)
				for floor_index: int in 8:
					_box(Vector3(side * 41, 9 + floor_index * 7, -109.5), Vector3(17, 1.3, 0.5), steel)
		7: # stadium floodlights and terraced stands
			for side: int in [-1, 1]:
				for step: int in 4:
					_box(Vector3(side * (33 + step * 3), 5 + step * 4, -113), Vector3(5, 5, 38), concrete)
				_box(Vector3(side * 43, 37, -115), Vector3(2, 44, 2), steel)
				_box(Vector3(side * 43, 59, -115), Vector3(14, 6, 2), warning)
		8: # refinery storage tanks, pipes and stacks
			for side: int in [-1, 1]:
				_cylinder(Vector3(side * 40, 15, -110), 11.0, 30.0, steel)
				_cylinder(Vector3(side * 48, 34, -129), 3.0, 60.0, warning)
				_box(Vector3(side * 40, 29, -110), Vector3(23, 2, 2), warning)
		9: # fortress towers and crenellated parapets
			for side: int in [-1, 1]:
				_box(Vector3(side * 38, 22, -113), Vector3(24, 44, 22), concrete)
				for offset: int in [-8, 0, 8]:
					_box(Vector3(side * 38 + offset, 47, -101), Vector3(4, 6, 4), concrete)
				_box(Vector3(side * 38, 29, -101.5), Vector3(4, 11, 1), steel)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material


func _box(at: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	_add(mesh, at, material)


func _cylinder(at: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	_add(mesh, at, material)


func _dome(at: Vector3, radius: float, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	_add(mesh, at, material)


func _add(mesh: Mesh, at: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
