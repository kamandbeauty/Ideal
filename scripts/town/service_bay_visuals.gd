class_name ServiceBayVisuals
extends RefCounted
## Parking markings and equipment use exactly the same stable coordinates as
## the traffic reservations, so upgrades never move a car underneath a pump.


static func build(id: String, slots: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Bays_" + id
	root.set_meta("slots", slots)
	var stripe := VehicleMesh.paint(CartoonPalette.WHITE, 0.95, 0.0)
	var pad := SurfaceMaterials.textured("asphalt", CartoonPalette.PARKING)
	for i in slots:
		var at := ForecourtLayout.bay_position(id, i)
		at.y = 0.063
		mark(root, pad, at, Vector3(1.52, 0.012, 2.66))
		for sx in [-0.76, 0.76]:
			mark(root, stripe, at + Vector3(float(sx), 0.016, 0), Vector3(0.035, 0.012, 2.68))
		mark(root, stripe, at + Vector3(0, 0.016, -1.33), Vector3(1.55, 0.012, 0.045))
		var number := Label3D.new()
		number.text = "%02d" % (i + 1)
		number.font_size = 40
		number.pixel_size = 0.006
		number.outline_size = 0
		number.modulate = CartoonPalette.WHITE
		number.rotation_degrees.x = -90.0
		number.position = at + Vector3(0, 0.03, 1.11)
		root.add_child(number)
	return root


static func progress_bar() -> Node3D:
	var root := Node3D.new()
	root.name = "ServiceProgress"
	root.position.y = 1.8
	root.visible = false
	mark(root, VehicleMesh.paint(Color(0.08, 0.11, 0.16), 0.9, 0.0), Vector3.ZERO, Vector3(1.05, 0.14, 0.06))
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.24, 0.90, 0.36)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fill := mark(root, fill_mat, Vector3.ZERO, Vector3(0.98, 0.10, 0.08))
	root.set_meta("fill", fill)
	return root


static func set_progress(bar: Node3D, progress: float) -> void:
	var fill: MeshInstance3D = bar.get_meta("fill")
	var value := clampf(progress, 0.02, 1.0)
	fill.scale.x = value
	fill.position.x = -0.49 * (1.0 - value)


static func mark(parent: Node3D, mat: Material, at: Vector3, size: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
