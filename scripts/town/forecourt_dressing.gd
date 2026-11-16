class_name ForecourtDressing
extends RefCounted
## Legible circulation, numbered parking, tactile paving and desert planting.
## Decoration stays OUT of the swept road and parking envelopes.


static func build(parent: Node3D, verge_color: Color) -> void:
	var bounds := ForecourtLayout.LOT_BOUNDS
	var center := bounds.get_center()
	SurfaceMaterials.paving(parent, "asphalt", Color(0.43, 0.47, 0.49), Vector3(center.x, 0.054, center.y), bounds.size)
	var curb := VehicleMesh.paint(Color(0.65, 0.65, 0.57), 0.94, 0.0)
	var stripe := VehicleMesh.paint(Color(0.71, 0.70, 0.58), 0.9, 0.0)
	for side in [-1.0, 1.0]:
		ServiceBayVisuals.mark(
			parent, curb, Vector3(float(side) * 10.8, 0.08, center.y), Vector3(0.16, 0.16, bounds.size.y)
		)
	ServiceBayVisuals.mark(parent, curb, Vector3(0, 0.08, 28.45), Vector3(21.7, 0.16, 0.16))
	for row in 4:
		var z := -1.2 + float(row) * 7.6
		for side in [-1.0, 1.0]:
			var x := float(side) * 4.6
			SurfaceMaterials.paving(
				parent, "concrete", Color(0.72, 0.69, 0.59), Vector3(x, 0.057, z + 1.15), Vector2(6.85, 0.95)
			)
			# A continuous pedestrian sill is safely behind the parked cars.
			for tile in 12:
				ServiceBayVisuals.mark(
					parent, curb, Vector3(x - 3.2 + float(tile) * 0.58, 0.062, z + 1.2), Vector3(0.018, 0.008, 0.80)
				)
			# Dashed stop line before the one-way spine.
			ServiceBayVisuals.mark(
				parent, stripe, Vector3(8.45, 0.064, z + ForecourtLayout.AISLE_Z), Vector3(0.08, 0.01, 1.0)
			)
		for x in [-7.9, 0.0, 7.9]:
			_ground_text(parent, "➜", Vector3(float(x), 0.074, z + ForecourtLayout.AISLE_Z), 0.015)
		_planter(parent, Vector3(0, 0, z - 0.1), verge_color)
		for side in [-1.0, 1.0]:
			var text := "↓" if side < 0.0 else "↑"
			_ground_text(parent, text, Vector3(float(side) * ForecourtLayout.DRIVE_X, 0.074, z + 0.4), 0.015)
	# These are the real driveways, not cosmetic entrances through a building.
	for side in [-1.0, 1.0]:
		var x := ForecourtLayout.DRIVE_X * float(side)
		SurfaceMaterials.paving(parent, "asphalt", Color(0.43, 0.47, 0.49), Vector3(x, 0.055, -4.8), Vector2(2.35, 2.7))
		for i in 5:
			ServiceBayVisuals.mark(
				parent, stripe, Vector3(x - 0.84 + float(i) * 0.42, 0.069, -4.25), Vector3(0.20, 0.012, 0.85)
			)
		_ground_text(parent, "IN" if side < 0.0 else "OUT", Vector3(x, 0.076, -2.9), 0.010)


static func _planter(parent: Node3D, at: Vector3, color: Color) -> void:
	var stone := VehicleMesh.paint(Color(0.55, 0.48, 0.35), 0.95, 0.0)
	var soil := VehicleMesh.paint(Color(0.32, 0.28, 0.19), 1.0, 0.0)
	ServiceBayVisuals.mark(parent, stone, at + Vector3(0, 0.12, 0), Vector3(1.45, 0.22, 2.4))
	ServiceBayVisuals.mark(parent, soil, at + Vector3(0, 0.24, 0), Vector3(1.24, 0.02, 2.16))
	var leaf := VehicleMesh.paint(color.darkened(0.32), 0.95, 0.0)
	for i in 3:
		var plant := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.16
		mesh.bottom_radius = 0.28
		mesh.height = 0.42
		mesh.radial_segments = 6
		plant.mesh = mesh
		plant.material_override = leaf
		plant.position = at + Vector3(0, 0.45, -0.72 + float(i) * 0.72)
		parent.add_child(plant)


static func _ground_text(parent: Node3D, text: String, at: Vector3, pixels: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 44
	label.pixel_size = pixels
	label.outline_size = 0
	label.modulate = Color(0.70, 0.69, 0.56, 0.70)
	label.rotation_degrees.x = -90.0
	label.position = at
	parent.add_child(label)
