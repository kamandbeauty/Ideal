class_name CartoonBuildings
extends RefCounted
## Chunky, low-poly cottages: a real striped gable, broad cream eaves, blue
## plinths and framed windows. Entire shells fit the existing solid footprints.

const ROOF_WIDTH := 3.08
const ROOF_DEPTH := 2.48
const ROOF_RISE := 0.82


static func build(id: String, stage: int, nights: Array[StandardMaterial3D]) -> Node3D:
	var root := Node3D.new()
	root.name = "CartoonShell_" + id
	var h := wall_height(stage)
	var wall := SurfaceMaterials.textured("plaster", CartoonPalette.wall_color(id))
	var frame := VehicleMesh.paint(CartoonPalette.FRAME, 0.95, 0.0)
	var plinth := VehicleMesh.paint(CartoonPalette.FOUNDATION, 0.95, 0.0)
	var glass := VehicleMesh.paint(CartoonPalette.WINDOW, 0.8, 0.0).duplicate() as StandardMaterial3D
	glass.emission_enabled = true
	glass.emission = Color("#ffe0a0")
	glass.emission_energy_multiplier = 0.0
	nights.append(glass)

	_box(root, plinth, Vector3(0, 0.14, 0), Vector3(2.83, 0.24, 2.32))
	_box(root, wall, Vector3(0, 0.20 + h * 0.5, 0), Vector3(2.55, h, 2.05))
	_box(root, frame, Vector3(0, 0.33, 1.06), Vector3(2.61, 0.10, 0.12))
	_gable_roof(root, wall, 0.20 + h)

	# Front door and chunky window frames are legible at phone scale.
	_box(root, frame, Vector3(0, 0.88, 1.07), Vector3(0.57, 1.28, 0.12))
	_box(
		root,
		VehicleMesh.paint(CartoonPalette.ROOF_RIDGE, 0.95, 0.0),
		Vector3(0, 0.88, 1.14),
		Vector3(0.43, 1.12, 0.035)
	)
	_box(root, glass, Vector3(0, 1.12, 1.17), Vector3(0.29, 0.46, 0.02), false)
	_box(root, plinth, Vector3(0, 0.23, 1.25), Vector3(0.72, 0.14, 0.38))
	for x in [-0.80, 0.80]:
		_front_window(root, frame, glass, Vector3(float(x), 1.03, 1.06))
	for side in [-1.0, 1.0]:
		for z in [-0.53, 0.45]:
			var holder := Node3D.new()
			holder.position = Vector3(float(side) * 1.29, 1.05, float(z))
			holder.rotation_degrees.y = 90.0 * float(side)
			root.add_child(holder)
			_front_window(holder, frame, glass, Vector3.ZERO)

	var shadow := SurfaceMaterials.contact_shadow(Vector2(3.55, 3.15))
	shadow.position.y = 0.10
	root.add_child(shadow)
	return root


static func wall_height(stage: int) -> float:
	return 1.52 + (0.18 if stage >= 4 else 0.0)


static func sign_height(stage: int) -> float:
	return wall_height(stage) + 0.47


static func _front_window(parent: Node3D, frame: Material, glass: Material, at: Vector3) -> void:
	_box(parent, frame, at, Vector3(0.53, 0.70, 0.10))
	_box(parent, glass, at + Vector3(0, 0.015, 0.061), Vector3(0.39, 0.54, 0.025), false)
	_box(parent, frame, at + Vector3(0, -0.35, 0.08), Vector3(0.62, 0.07, 0.20), false)
	_box(parent, frame, at + Vector3(0, 0.0, 0.079), Vector3(0.39, 0.035, 0.025), false)


static func _gable_roof(parent: Node3D, wall: Material, base_y: float) -> void:
	var roof := Node3D.new()
	roof.name = "GabledRoof"
	roof.position.y = base_y
	parent.add_child(roof)
	var half := ROOF_WIDTH * 0.5
	var slope := atan2(ROOF_RISE, half)
	var slope_width := Vector2(half, ROOF_RISE).length()
	var cream := VehicleMesh.paint(CartoonPalette.FRAME, 0.95, 0.0)
	var tile := VehicleMesh.paint(CartoonPalette.ROOF, 0.95, 0.0)
	var stripe := VehicleMesh.paint(CartoonPalette.ROOF_STRIPE, 0.95, 0.0)
	var ridge := VehicleMesh.paint(CartoonPalette.ROOF_RIDGE, 0.95, 0.0)
	# Triangular front/back walls close the roof, rather than floating panels.
	for end in [-1.0, 1.0]:
		var gable := MeshInstance3D.new()
		gable.name = "Gable"
		gable.mesh = _triangle(float(end), ROOF_RISE * 2.55 / ROOF_WIDTH)
		gable.material_override = wall
		gable.position.z = float(end) * 1.025
		roof.add_child(gable)
	for side in [-1.0, 1.0]:
		for band in 5:
			var panel := _box(
				roof,
				tile if band % 2 == 0 else stripe,
				Vector3(
					float(side) * half * 0.5,
					ROOF_RISE * 0.5,
					-ROOF_DEPTH * 0.5 + (float(band) + 0.5) * ROOF_DEPTH / 5.0
				),
				Vector3(slope_width, 0.12, ROOF_DEPTH / 5.0 + 0.01)
			)
			panel.rotation.z = -float(side) * slope
		for end in [-1.0, 1.0]:
			var fascia := _box(
				roof,
				cream,
				Vector3(float(side) * half * 0.5, ROOF_RISE * 0.5 - 0.025, float(end) * (ROOF_DEPTH * 0.5 + 0.025)),
				Vector3(slope_width + 0.06, 0.11, 0.11)
			)
			fascia.rotation.z = -float(side) * slope
		_box(roof, cream, Vector3(float(side) * (half + 0.01), -0.02, 0), Vector3(0.10, 0.10, ROOF_DEPTH + 0.10))
	_box(roof, ridge, Vector3(0, ROOF_RISE + 0.035, 0), Vector3(0.16, 0.15, ROOF_DEPTH + 0.12))


static func _triangle(end: float, rise: float) -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3(-1.275, 0, 0), Vector3(1.275, 0, 0), Vector3(0, rise, 0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3(0, 0, end), Vector3(0, 0, end), Vector3(0, 0, end)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1] if end > 0.0 else [0, 1, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Small distant houses are decoration only, outside every driveable corridor.
static func cottage(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Cottage_%d" % index
	var colors: Array[Color] = [CartoonPalette.WALL, Color("#c8c77a"), Color("#95b878")]
	var wall := VehicleMesh.paint(colors[posmod(index, colors.size())], 0.95, 0.0)
	var frame := VehicleMesh.paint(CartoonPalette.FRAME, 0.95, 0.0)
	var base := VehicleMesh.paint(CartoonPalette.FOUNDATION, 0.95, 0.0)
	var glass := VehicleMesh.paint(CartoonPalette.WINDOW, 0.95, 0.0)
	_box(root, base, Vector3(0, 0.13, 0), Vector3(2.83, 0.26, 2.30))
	_box(root, wall, Vector3(0, 0.93, 0), Vector3(2.55, 1.52, 2.05))
	_gable_roof(root, wall, 1.69)
	_front_window(root, frame, glass, Vector3(-0.73, 1.02, 1.065))
	_front_window(root, frame, glass, Vector3(0.73, 1.02, 1.065))
	_box(root, frame, Vector3(0, 0.83, 1.08), Vector3(0.48, 1.18, 0.10))
	_box(root, base, Vector3(0, 0.78, 1.14), Vector3(0.34, 1.02, 0.035))
	var chimney := VehicleMesh.paint(CartoonPalette.ROOF_RIDGE, 0.95, 0.0)
	_box(root, chimney, Vector3(-0.68, 2.30, -0.25), Vector3(0.37, 0.70, 0.37))
	_box(root, chimney, Vector3(-0.68, 2.65, -0.25), Vector3(0.48, 0.13, 0.48))
	return root


static func _box(parent: Node3D, mat: Material, at: Vector3, size: Vector3, shadows: bool = true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = StylizedMesh.box(size, minf(0.035, minf(size.x, minf(size.y, size.z)) * 0.16))
	instance.material_override = mat
	instance.position = at
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
