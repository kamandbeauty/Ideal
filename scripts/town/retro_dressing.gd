class_name RetroDressing
extends RefCounted
## Everything that turns a plain kit building into a 1950s roadside stop:
## chrome skirting, a candy-striped awning, roof neon, warm lit windows, a soft
## halo card and one small interior light. All of it lives here so the town view
## stays readable and the dressing can be retuned in one place.


## Dresses one plot and returns what the day cycle needs to switch on:
## `night` materials, additive `halo` cards and the plot's `light`.
static func dress(parent: Node3D, id: String, to_road: float) -> Dictionary:
	var accent := BusinessData.accent(id)
	var night: Array[StandardMaterial3D] = []
	var halo: Array[StandardMaterial3D] = []

	RetroStyle.chrome_skirt(parent, Vector3(0, 0.09, 0), Vector3(2.7, 0.1, 2.7), night)
	RetroStyle.awning(parent, Vector3(1.22 * to_road, 1.16, 0.3), 2.05, 0.62, to_road, night)
	RetroStyle.roof_neon(parent, Vector3(1.24 * to_road, 2.32, 0.2), 2.1, to_road, accent, night)
	var second: Color = RetroStyle.NEON_TEAL
	if accent == RetroStyle.TURQUOISE or accent == RetroStyle.TEAL:
		second = RetroStyle.NEON_RED
	RetroStyle.roof_neon(parent, Vector3(1.24 * to_road, 1.98, 0.2), 2.1, to_road, second, night)

	_windows(parent, to_road, night)
	halo.append(_halo(parent, Vector3(1.3 * to_road, 2.15, 0.2), to_road))
	var light := _interior_light(parent, Vector3(1.9 * to_road, 1.6, 0.6))
	return {"night": night, "halo": halo, "light": light}


## Two rows of warm panes on the road-facing wall.
static func _windows(parent: Node3D, to_road: float, night: Array[StandardMaterial3D]) -> void:
	var material := RetroStyle.neon(Color(1.0, 0.82, 0.5), 1.05)
	for row in 2:
		for i in 3:
			var pane := MeshInstance3D.new()
			var mesh := QuadMesh.new()
			mesh.size = Vector2(0.3, 0.34)
			pane.mesh = mesh
			pane.material_override = material
			pane.rotation_degrees.y = 90.0
			pane.position = Vector3(
				1.235 * to_road, 0.95 + 0.55 * float(row), -0.62 + 0.62 * float(i)
			)
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(pane)
	night.append(material)


## A soft additive card behind the neon bars: glow without a real bloom pass.
static func _halo(parent: Node3D, at: Vector3, to_road: float) -> StandardMaterial3D:
	var halo := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.5, 0.85)
	halo.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.42, 0.34, 0.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.material_override = material
	halo.position = at
	halo.rotation_degrees.y = 90.0 * (1.0 if to_road > 0.0 else -1.0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(halo)
	return material


## One small warm light per plot; short range, no shadows.
static func _interior_light(parent: Node3D, at: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(1.0, 0.76, 0.46)
	light.light_energy = 0.0
	light.omni_range = 3.6
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.visible = false
	parent.add_child(light)
	return light


## The googie pylon sign: chrome post, cream board frame, neon ring.
static func draw_totem(parent: Node3D, to_road: float, night: Array[StandardMaterial3D]) -> Dictionary:
	var totem := Node3D.new()
	totem.name = "Totem"
	totem.position = Vector3(1.45 * to_road, 0, 1.55)
	parent.add_child(totem)

	var post := MeshInstance3D.new()
	post.name = "Post"
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.05
	post_mesh.bottom_radius = 0.07
	post_mesh.height = 2.35
	post_mesh.radial_segments = 10
	post.mesh = post_mesh
	post.material_override = RetroStyle.enamel(RetroStyle.CHROME)
	post.position.y = 1.18
	totem.add_child(post)

	for side in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(0.5, 0.05, 0.05)
		fin.mesh = fin_mesh
		fin.material_override = RetroStyle.enamel(RetroStyle.CHERRY)
		fin.position = Vector3(0.22 * side, 2.16, 0)
		fin.rotation_degrees.z = -24.0 * side
		totem.add_child(fin)

	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(1.2, 0.72, 0.08)
	frame.mesh = frame_mesh
	frame.material_override = RetroStyle.matte(RetroStyle.CREAM, 0.6)
	frame.position.y = 1.68
	totem.add_child(frame)

	var board := MeshInstance3D.new()
	board.name = "Board"
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(1.05, 0.58, 0.1)
	board.mesh = board_mesh
	board.position = Vector3(0, 1.68, 0.02)
	var board_material := StandardMaterial3D.new()
	board_material.roughness = 0.5
	board.material_override = board_material
	totem.add_child(board)

	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.85, 0.13, 0.06)
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(0, 1.34, 0.06)
	var lamp_material := StandardMaterial3D.new()
	lamp.material_override = lamp_material
	totem.add_child(lamp)

	var neon := RetroStyle.neon(RetroStyle.NEON_RED, 1.7)
	for side in [-1.0, 1.0]:
		var upright := RetroStyle.box(
			totem, Vector3(0.045, 0.66, 0.05), Vector3(0.64 * side, 1.68, 0.06), neon
		)
		upright.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y in [1.3, 2.06]:
		var bar := RetroStyle.box(
			totem, Vector3(1.32, 0.045, 0.05), Vector3(0, float(y), 0.06), neon
		)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	night.append(neon)
	night.append(board_material)
	night.append(lamp_material)

	return {"board": board_material, "lamp": lamp_material}
