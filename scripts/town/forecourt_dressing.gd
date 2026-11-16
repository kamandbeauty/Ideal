class_name ForecourtDressing
extends RefCounted
## Lime lawn islands and white kerbs break up the cool grey forecourt.
## All planting stays behind the parking/turning envelopes; routes are unchanged.

const LAWN_SIZE := Vector2(7.05, 3.50)
const LAWN_OFFSET_Z := -0.99


static func build(parent: Node3D, verge_color: Color) -> void:
	var bounds := ForecourtLayout.LOT_BOUNDS
	var center := bounds.get_center()
	SurfaceMaterials.paving(parent, "asphalt", CartoonPalette.ASPHALT, Vector3(center.x, 0.054, center.y), bounds.size)
	var curb := VehicleMesh.paint(CartoonPalette.WHITE, 0.95, 0.0)
	var stripe := VehicleMesh.paint(CartoonPalette.WHITE, 0.95, 0.0)
	var grass := VehicleMesh.paint(verge_color, 0.95, 0.0)
	for side in [-1.0, 1.0]:
		ServiceBayVisuals.mark(
			parent, curb, Vector3(float(side) * 10.8, 0.065, center.y), Vector3(0.13, 0.06, bounds.size.y)
		)
	ServiceBayVisuals.mark(parent, curb, Vector3(0, 0.065, 30.15), Vector3(21.7, 0.06, 0.13))
	for row in 4:
		var z := -1.2 + float(row) * ForecourtLayout.ROW_PITCH
		for side in [-1.0, 1.0]:
			var x := float(side) * 4.6
			var island := Node3D.new()
			island.name = "LawnIsland_%d_%d" % [row, int(side)]
			parent.add_child(island)
			ServiceBayVisuals.mark(
				island,
				curb,
				Vector3(x, 0.057, z + LAWN_OFFSET_Z),
				Vector3(LAWN_SIZE.x + 0.17, 0.012, LAWN_SIZE.y + 0.17)
			)
			ServiceBayVisuals.mark(
				island, grass, Vector3(x, 0.064, z + LAWN_OFFSET_Z), Vector3(LAWN_SIZE.x, 0.012, LAWN_SIZE.y)
			)
			SurfaceMaterials.paving(
				parent, "concrete", CartoonPalette.SIDEWALK, Vector3(x, 0.071, z + 1.15), Vector2(7.22, 0.78)
			)
			# Painted stop lines do not create a physical barrier.
			ServiceBayVisuals.mark(
				parent, stripe, Vector3(8.45, 0.074, z + ForecourtLayout.AISLE_Z), Vector3(0.10, 0.01, 1.0)
			)
		for x in [-7.9, 0.0, 7.9]:
			_ground_text(parent, "➜", Vector3(float(x), 0.078, z + ForecourtLayout.AISLE_Z), 0.015)
		_planter(parent, Vector3(0, 0, z - 0.10), verge_color)
		for side in [-1.0, 1.0]:
			var text := "↓" if side < 0.0 else "↑"
			_ground_text(parent, text, Vector3(float(side) * ForecourtLayout.DRIVE_X, 0.078, z + 0.4), 0.015)
	for side in [-1.0, 1.0]:
		var x := ForecourtLayout.DRIVE_X * float(side)
		SurfaceMaterials.paving(parent, "asphalt", CartoonPalette.ASPHALT, Vector3(x, 0.055, -4.8), Vector2(2.35, 2.7))
		for i in 5:
			ServiceBayVisuals.mark(
				parent, stripe, Vector3(x - 0.84 + float(i) * 0.42, 0.076, -4.25), Vector3(0.20, 0.012, 0.85)
			)
		_ground_text(parent, "IN" if side < 0.0 else "OUT", Vector3(x, 0.078, -2.9), 0.010)


static func _planter(parent: Node3D, at: Vector3, color: Color) -> void:
	var stone := VehicleMesh.paint(CartoonPalette.WHITE, 0.95, 0.0)
	var turf := VehicleMesh.paint(color, 0.95, 0.0)
	ServiceBayVisuals.mark(parent, stone, at + Vector3(0, 0.07, 0), Vector3(1.45, 0.06, 2.4))
	ServiceBayVisuals.mark(parent, turf, at + Vector3(0, 0.11, 0), Vector3(1.26, 0.02, 2.18))
	var leaf := VehicleMesh.paint(CartoonPalette.LEAF, 0.95, 0.0)
	for i in 3:
		var plant := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.14
		mesh.bottom_radius = 0.28
		mesh.height = 0.40
		mesh.radial_segments = 7
		plant.mesh = mesh
		plant.material_override = leaf
		plant.position = at + Vector3(0, 0.32, -0.72 + float(i) * 0.72)
		parent.add_child(plant)


static func _ground_text(parent: Node3D, text: String, at: Vector3, pixels: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 44
	label.pixel_size = pixels
	label.outline_size = 0
	label.modulate = CartoonPalette.WHITE
	label.rotation_degrees.x = -90.0
	label.position = at
	parent.add_child(label)
