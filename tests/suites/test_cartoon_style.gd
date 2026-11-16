extends TestCase
## The reference-inspired art remains bright, readable and physically honest.


func test_reference_palette_is_lime_grey_and_orange() -> void:
	check(CartoonPalette.GRASS.g > 0.80, "lawns must stay bright lime")
	check(CartoonPalette.GRASS.b < 0.40, "lawns are yellow-green, not teal")
	check(CartoonPalette.ROOF.r > 0.90 and CartoonPalette.ROOF.g < 0.55, "orange roof tiles")
	check(CartoonPalette.ASPHALT.b > CartoonPalette.ASPHALT.r, "neutral cool-grey roads")
	check(CartoonPalette.WHITE.get_luminance() > 0.94, "white kerbs and markings")
	for id in TownData.ORDER:
		var grass := TownData.ground_color(id)
		check(grass.g > grass.r and grass.g > grass.b, id + " keeps the planted toy-town palette")


func test_light_theme_text_has_readable_contrast() -> void:
	for color in [UiTheme.TEXT, UiTheme.MUTED, UiTheme.GOOD, UiTheme.GOLD, UiTheme.ACCENT, UiTheme.GEM_PINK]:
		check(_contrast(color, UiTheme.PANEL) >= 4.5, "small panel text needs 4.5:1 contrast: " + color.to_html())
	check(_contrast(UiTheme.TEXT, UiTheme.ORANGE) >= 4.5, "orange header needs dark, readable text")
	var theme := UiTheme.build()
	var nav := theme.get_stylebox("normal", "NavButton") as StyleBoxFlat
	check(nav.bg_color.r > 0.95, "navigation is a white illustrated tile")
	equal(nav.border_color, CartoonPalette.INK, "navigation has a charcoal keyline")
	var primary := theme.get_stylebox("normal", "BlueButton") as StyleBoxFlat
	equal(primary.bg_color, CartoonPalette.BLUE, "primary actions use the reference blue")


func test_all_eight_shells_have_real_gables_inside_the_solids() -> void:
	for id in BusinessData.ids():
		for stage in [1, 4, 5]:
			var nights: Array[StandardMaterial3D] = []
			var shell := CartoonBuildings.build(id, stage, nights)
			check(shell.has_node("GabledRoof"), id + " needs a pitched orange roof")
			check(not nights.is_empty(), id + " windows must still support night lighting")
			var points := PackedVector3Array()
			_collect_points(shell, Transform3D.IDENTITY, points)
			check(not points.is_empty(), id + " has actual geometry")
			var fits := true
			for point in points:
				if absf(point.x) > 1.70 or absf(point.z) > 1.60 or point.y > 3.90:
					fits = false
			check(fits, "%s stage %d visible shell must fit its existing physical building" % [id, stage])
			shell.free()


func test_roof_and_sign_heights_match_the_actual_renovation() -> void:
	for level in [1, 10, 25, 50, 75, 100]:
		var stage := BusinessData.renovation_stage(level)
		almost(
			CartoonBuildings.sign_height(stage),
			CartoonBuildings.wall_height(stage) + 0.47,
			"sign sits on the gable at level %d" % level
		)


func test_maps_preserve_the_palette_and_mobile_materials() -> void:
	for kind in ["grass", "asphalt", "concrete", "plaster"]:
		var material := SurfaceMaterials.textured(kind, CartoonPalette.GRASS)
		check(material.albedo_texture != null, kind + " has a baked map")
		equal(material.albedo_texture.get_width(), 256, kind + " stays a small map")
		equal(material.specular_mode, BaseMaterial3D.SPECULAR_DISABLED, kind + " is matte")
		check(material.roughness >= 0.90, kind + " cannot produce glaring highlights")
	var car_paint := VehicleMesh.paint(Color.RED, 0.2, 0.8)
	almost(car_paint.roughness, 0.70, "toy paint clamps the highlight roughness", 0.0001)
	check(car_paint.metallic <= 0.1601, "toy cars are not glossy metal blocks")


func test_orthographic_camera_zoom_remains_interactive() -> void:
	var rig := IsometricCamera.new()
	rig._ready()
	equal(rig.camera.projection, Camera3D.PROJECTION_ORTHOGONAL, "parallel roads match the reference")
	equal(rig.camera.keep_aspect, Camera3D.KEEP_WIDTH, "tall phones show more town, not a cropped gas office")
	almost(rig.camera.size, rig.zoom * IsometricCamera.ORTHO_SCALE, "ortho size follows the existing zoom")
	rig.zoom_by(0.8)
	almost(rig.camera.size, rig.zoom * IsometricCamera.ORTHO_SCALE, "pinch still changes the projection")
	rig.reset_view()
	almost(rig.zoom, IsometricCamera.DEFAULT_ZOOM, "reset returns to the portrait composition")
	rig.free()


func test_navigation_illustrations_ship_and_background_is_bounded() -> void:
	for name in ["map", "cases", "boost", "managers", "build"]:
		var icon: Texture2D = load("res://assets/ui/nav-%s.svg" % name)
		check(icon != null and icon.get_width() == 64, name + " has a lightweight original icon")
	var house := CartoonBuildings.cottage(0)
	check(_mesh_count(house) <= 40, "background cottages have a strict draw budget")
	house.free()


func _contrast(a: Color, b: Color) -> float:
	var one := a.srgb_to_linear().get_luminance()
	var two := b.srgb_to_linear().get_luminance()
	return (maxf(one, two) + 0.05) / (minf(one, two) + 0.05)


func _collect_points(node: Node3D, inherited: Transform3D, points: PackedVector3Array) -> void:
	var pose := inherited * node.transform
	if node is MeshInstance3D and node.name != "ContactShadow":
		var instance := node as MeshInstance3D
		var bounds := instance.mesh.get_aabb()
		for i in 8:
			points.append(pose * bounds.get_endpoint(i))
	for child in node.get_children():
		if child is Node3D:
			_collect_points(child as Node3D, pose, points)


func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _mesh_count(child)
	return count
