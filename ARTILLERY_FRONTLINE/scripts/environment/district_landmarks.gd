class_name DistrictLandmarks
extends Node3D
## Seven new skyline sets over the established city lanes. Decorative, never
## colliders: the wave routes and the two destructible defenses stay intact.

var steel: StandardMaterial3D
var concrete: StandardMaterial3D
var warning: StandardMaterial3D


func build(district: int) -> void:
	name = "DistrictLandmarks%d" % district
	steel = _material(Color(0.26, 0.27, 0.25), "metal")
	concrete = _material(Color(0.76, 0.73, 0.68), "district_facade_detail")
	warning = _material(Color(0.52, 0.27, 0.14), "metal")
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

	_build_details(district)


## Shared unit-box batches: windows, metalwork and pale fittings. These add
## readable architecture without one draw call per pane, and have no collision.
func _build_details(district: int) -> void:
	var panes: Array[Transform3D] = []
	var trim: Array[Transform3D] = []
	var fittings: Array[Transform3D] = []
	for side: int in [-1, 1]:
		match district:
			3: # factory windows, lintels and chimney collars
				for floor_index: int in 3:
					for col: int in 4:
						_detail(panes, Vector3(side * 39 + (col - 1.5) * 4.5, 5.0 + floor_index * 6.0, -99.9), Vector3(3.2, 3.2, 0.16))
					_detail(trim, Vector3(side * 39, 3.0 + floor_index * 6.0, -99.75), Vector3(20.0, 0.24, 0.28))
				for offset: int in [-1, 1]:
					for y: float in [24.0, 33.0, 42.0]:
						_detail(trim, Vector3(side * 39 + offset * 6, y, -116.9), Vector3(4.2, 0.4, 0.3))
			4: # bazaar openings and repeated stone piers
				for col: int in 5:
					var x: float = side * 38 + (col - 2) * 4.5
					_detail(panes, Vector3(x, 9.0, -90.9), Vector3(3.2, 9.0, 0.16))
					_detail(trim, Vector3(x, 14.0, -90.75), Vector3(3.7, 0.4, 0.3))
					_detail(fittings, Vector3(x - 2.0, 9.0, -90.75), Vector3(0.35, 12.0, 0.3))
				_detail(trim, Vector3(side * 38, 17.2, -90.7), Vector3(25.0, 0.5, 0.35))
			5: # station bays, timetable boards and canopy ribs
				for col: int in 4:
					var x: float = side * 37 + (col - 1.5) * 4.6
					_detail(panes, Vector3(x, 20.7, -109.3), Vector3(4.0, 4.0, 0.2))
					_detail(fittings, Vector3(x, 20.7, -109.1), Vector3(0.13, 3.5, 0.25))
				for z: float in [-122.0, -113.0, -104.0, -95.0]:
					_detail(trim, Vector3(side * 37, 17.0, z), Vector3(23.0, 0.45, 0.45))
			6: # apartment windows and ledges: nine storeys
				for floor_index: int in 9:
					for col: int in 4:
						var x: float = side * 41 + (col - 1.5) * 4.0
						var y: float = 5.0 + floor_index * 7.0
						_detail(panes, Vector3(x, y, -109.85), Vector3(2.5, 3.4, 0.16))
						_detail(fittings, Vector3(x, y - 1.85, -109.65), Vector3(3.0, 0.25, 0.45))
			7: # light housings and railings over the stands
				for col: int in 5:
					var x: float = side * 43 + (col - 2) * 2.3
					_detail(fittings, Vector3(x, 59.0, -113.9), Vector3(1.65, 2.5, 0.18))
				for step: int in 4:
					_detail(trim, Vector3(side * (33 + step * 3), 8.0 + step * 4.0, -113), Vector3(0.22, 1.8, 36.0))
			8: # tank ladders, seams and pipe brackets
				for y: float in [5.0, 12.0, 19.0, 26.0]:
					_detail(trim, Vector3(side * 40, y, -98.9), Vector3(18.0, 0.32, 0.25))
				for rung: int in 10:
					_detail(fittings, Vector3(side * 40, 2.5 + rung * 2.5, -98.65), Vector3(2.0, 0.2, 0.3))
				for x_offset: float in [-1.0, 1.0]:
					_detail(trim, Vector3(side * 40 + x_offset, 14.0, -98.7), Vector3(0.2, 26.0, 0.3))
			9: # fortress narrow openings and masonry courses
				for floor_index: int in 4:
					for col: int in 3:
						_detail(panes, Vector3(side * 38 + (col - 1) * 6.0, 8.0 + floor_index * 8.0, -101.9), Vector3(1.3, 4.0, 0.2))
					_detail(trim, Vector3(side * 38, 4.0 + floor_index * 8.0, -101.75), Vector3(23.5, 0.3, 0.25))
	_batch_details("DistrictWindows", panes, _plain(Color(0.07, 0.10, 0.11)))
	_batch_details("DistrictMetalwork", trim, steel)
	_batch_details("DistrictFittings", fittings, _plain(Color(0.54, 0.51, 0.42)))


func _detail(items: Array[Transform3D], at: Vector3, dimensions: Vector3) -> void:
	items.append(Transform3D(Basis.IDENTITY.scaled(dimensions), at))


func _batch_details(batch_name: String, items: Array[Transform3D], material: Material) -> void:
	if items.is_empty():
		return
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	unit.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = unit
	multi.instance_count = items.size()
	for i: int in items.size():
		multi.set_instance_transform(i, items[i])
	var batch := MultiMeshInstance3D.new()
	batch.name = batch_name
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)


func _plain(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _material(color: Color, texture: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = load("res://assets/textures/world/" + texture + ".jpg")
	material.uv1_scale = Vector3(4.0, 4.0, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
