class_name TownView
extends Node3D
## The 3D roadside town: textured desert, dunes, scattered rocks and shrubs, a
## highway with traffic, one dressed plot per business and the selection ring.

const BUSINESS_SCALE := 2.4
const ROAD_WIDTH := 3.0
const ROAD_SEGMENTS := 13
const ROAD_STEP := 3.0
const PLOT_RADIUS := 3.6
const ROAD_CORRIDOR := 4.6
const TREE_SPOTS := 46
const ROCK_SPOTS := 34
const SHRUB_SPOTS := 90
const DUNE_COUNT := 9
const SEED := 20251114

const PROP_MODELS: Array[String] = ["grass-trees", "grass-trees-tall"]

var state: TownState
var buildings: Dictionary = {}
var pips: Dictionary = {}
var ring: MeshInstance3D
var highlight_id := ""
var _locked_material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func setup(town_state: TownState) -> void:
	state = town_state
	_rng.seed = SEED
	_locked_material = StandardMaterial3D.new()
	_locked_material.albedo_color = Color(0.52, 0.5, 0.44, 0.6)
	_locked_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_locked_material.roughness = 1.0

	_build_environment()
	_build_ground()
	_build_dunes()
	_build_scatter()
	_build_road()
	_build_businesses()
	_build_ring()
	refresh_all()


# --- Environment -----------------------------------------------------------

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "World"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	var top := TownData.sky_color(state.town_id)
	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = top.lightened(0.22)
	sky_material.ground_horizon_color = TownData.ground_color(state.town_id).lightened(0.18)
	sky_material.ground_bottom_color = TownData.ground_color(state.town_id).darkened(0.4)
	sky_material.sun_angle_max = 14.0
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	# Depth haze: it separates the dunes from the play area and costs nothing.
	env.fog_enabled = true
	env.fog_light_color = TownData.ground_color(state.town_id).lightened(0.35)
	env.fog_light_energy = 0.7
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.25
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.rotation_degrees = Vector3(-50, -38, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.04
	add_child(sun)

	# Cool bounce from the opposite side so shadowed faces keep their shape.
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_energy = 0.22
	fill.light_color = Color(0.66, 0.78, 1.0)
	fill.rotation_degrees = Vector3(-24, 150, 0)
	fill.shadow_enabled = false
	add_child(fill)


func _sand_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0
	material.metallic = 0.0
	return material


# --- Ground ----------------------------------------------------------------

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(150, 150)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	ground.mesh = plane

	var base := TownData.ground_color(state.town_id)
	var material := _sand_material(Color(1, 1, 1))
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, base.darkened(0.22))
	ramp.set_color(1, base.lightened(0.12))
	texture.color_ramp = ramp
	material.albedo_texture = texture
	material.uv1_scale = Vector3(22, 22, 1)
	ground.material_override = material
	ground.position.y = -0.03
	add_child(ground)


func _build_dunes() -> void:
	var material := _sand_material(TownData.ground_color(state.town_id).lightened(0.06))
	for i in DUNE_COUNT:
		var dune := MeshInstance3D.new()
		dune.name = "Dune%d" % i
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 16
		sphere.rings = 8
		dune.mesh = sphere
		dune.material_override = material
		var angle := TAU * float(i) / float(DUNE_COUNT) + _rng.randf_range(-0.2, 0.2)
		var distance := _rng.randf_range(26.0, 42.0)
		dune.position = Vector3(cos(angle) * distance, -0.55, sin(angle) * distance)
		var stretch := _rng.randf_range(9.0, 18.0)
		dune.scale = Vector3(stretch, _rng.randf_range(1.6, 3.2), stretch * _rng.randf_range(0.6, 1.0))
		dune.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
		add_child(dune)


# --- Scatter ---------------------------------------------------------------

func _is_free_ground(point: Vector3) -> bool:
	if absf(point.x) < ROAD_CORRIDOR and absf(point.z) < 24.0:
		return false
	for id in state.business_ids():
		var plot := BusinessData.plot(id)
		if Vector2(point.x - plot.x, point.z - plot.y).length() < PLOT_RADIUS:
			return false
	return true


func _build_scatter() -> void:
	var tree_meshes: Array[Mesh] = []
	for path in PROP_MODELS:
		var mesh := _load_mesh("res://assets/models/%s.glb" % path)
		if mesh != null:
			tree_meshes.append(mesh)
	for i in tree_meshes.size():
		_scatter_mesh(tree_meshes[i], TREE_SPOTS / tree_meshes.size(), 2.0, 0.85, 1.35, true)

	# Dry shrubs: a five-sided cone reads as desert scrub at any distance.
	var shrub := CylinderMesh.new()
	shrub.top_radius = 0.03
	shrub.bottom_radius = 0.26
	shrub.height = 0.6
	shrub.radial_segments = 5
	shrub.rings = 1
	_scatter_mesh(shrub, SHRUB_SPOTS, 2.0, 0.7, 1.5, false,
		_sand_material(Color(0.45, 0.48, 0.3)))

	# Rocks.
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 0.8
	rock.radial_segments = 6
	rock.rings = 3
	_scatter_mesh(rock, ROCK_SPOTS, 2.0, 0.6, 1.8, true,
		_sand_material(Color(0.56, 0.47, 0.36)))


func _scatter_mesh(
	mesh: Mesh,
	count: int,
	area: float,
	min_scale: float,
	max_scale: float,
	shadow: bool,
	material: Material = null
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 12:
		attempts += 1
		var point := Vector3(
			_rng.randf_range(-area * 7.5, area * 7.5), 0.0, _rng.randf_range(-20.0, 20.0)
		)
		if not _is_free_ground(point):
			continue
		var scale_value := _rng.randf_range(min_scale, max_scale)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		basis = basis.scaled(Vector3(scale_value, scale_value, scale_value))
		multimesh.set_instance_transform(placed, Transform3D(basis, point))
		placed += 1
	multimesh.instance_count = placed
	var instance := MultiMeshInstance3D.new()
	instance.name = "Scatter"
	instance.multimesh = multimesh
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	if material != null:
		instance.material_override = material
	add_child(instance)


func _load_mesh(path: String) -> Mesh:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var instance := scene.instantiate()
	var mesh := _first_mesh(instance)
	instance.free()
	return mesh


func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var mesh := _first_mesh(child)
		if mesh != null:
			return mesh
	return null


# --- Road and traffic ------------------------------------------------------

func _build_road() -> void:
	var plain: PackedScene = load(BusinessData.MODELS["road-straight"])
	var lit: PackedScene = load(BusinessData.MODELS["road-straight-lightposts"])
	var pavement: PackedScene = load(BusinessData.MODELS["pavement"])

	for i in ROAD_SEGMENTS:
		var z := -ROAD_STEP * (ROAD_SEGMENTS - 1) * 0.5 + i * ROAD_STEP
		var source: PackedScene = lit if i % 3 == 0 else plain
		if source != null:
			var piece: Node3D = source.instantiate()
			piece.position = Vector3(0, 0, z)
			piece.scale = Vector3(ROAD_WIDTH, 1.0, ROAD_STEP)
			add_child(piece)
		if pavement != null:
			for side in [-1.0, 1.0]:
				var walk: Node3D = pavement.instantiate()
				walk.position = Vector3(1.4 * side, 0.01, z)
				walk.scale = Vector3(1.6, 1.0, ROAD_STEP)
				add_child(walk)

	var traffic := Traffic.new()
	traffic.name = "Traffic"
	add_child(traffic)


# --- Businesses ------------------------------------------------------------

func _build_businesses() -> void:
	for id in state.business_ids():
		var plot := BusinessData.plot(id)
		var node := Node3D.new()
		node.name = "Business_%s" % id
		node.position = Vector3(plot.x, 0, plot.y)
		add_child(node)

		_build_plot_ground(node)
		_build_model(node, id)
		_build_totem(node, id)
		_build_pips(node, id)
		_build_collider(node, id)
		buildings[id] = node


func _build_plot_ground(parent: Node3D) -> void:
	var path: String = BusinessData.MODELS["pavement"]
	var scene: PackedScene = load(path)
	if scene == null:
		return
	var plot: Node3D = scene.instantiate()
	plot.name = "Plot"
	plot.scale = Vector3(3.4, 1.0, 3.4)
	plot.position.y = 0.01
	parent.add_child(plot)


func _build_model(parent: Node3D, id: String) -> void:
	var path := BusinessData.model_path(id)
	if path.is_empty():
		return
	var scene: PackedScene = load(path)
	if scene == null:
		return
	var model: Node3D = scene.instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * BUSINESS_SCALE
	model.position.y = 0.05
	parent.add_child(model)


## A roadside totem: post, glowing board in the business colour. Locked plots
## show an empty lot with a pale board until the player buys in.
func _build_totem(parent: Node3D, id: String) -> void:
	var totem := Node3D.new()
	totem.name = "Totem"
	var to_road := -signf(BusinessData.plot(id).x)
	totem.position = Vector3(1.45 * to_road, 0, 1.55)
	parent.add_child(totem)

	var post := MeshInstance3D.new()
	post.name = "Post"
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.09, 1.6, 0.09)
	post.mesh = post_mesh
	post.material_override = _sand_material(Color(0.22, 0.24, 0.28))
	post.position.y = 0.8
	totem.add_child(post)

	var board := MeshInstance3D.new()
	board.name = "Board"
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.95, 0.5, 0.07)
	board.mesh = board_mesh
	board.position.y = 1.62
	totem.add_child(board)

	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.7, 0.16, 0.05)
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(0, 1.22, 0.05)
	totem.add_child(lamp)


func _build_pips(parent: Node3D, id: String) -> void:
	var group: Array[MeshInstance3D] = []
	for i in BusinessData.MAX_LEVEL - 1:
		var pip := MeshInstance3D.new()
		pip.name = "Pip%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.26, 0.18)
		pip.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = BusinessData.accent(id)
		material.emission_enabled = true
		material.emission = BusinessData.accent(id)
		material.emission_energy_multiplier = 0.35
		pip.material_override = material
		pip.position = Vector3(-0.4 + 0.27 * float(i), 0.15, 1.5)
		pip.visible = false
		parent.add_child(pip)
		group.append(pip)
	pips[id] = group


func _build_collider(parent: Node3D, id: String) -> void:
	var body := StaticBody3D.new()
	body.name = "TapArea"
	body.set_meta("business_id", id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 3.0)
	shape.shape = box
	shape.position.y = 1.2
	body.add_child(shape)
	parent.add_child(body)


func _build_ring() -> void:
	ring = MeshInstance3D.new()
	ring.name = "SelectionRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.35
	torus.outer_radius = 1.5
	ring.mesh = torus
	ring.visible = false
	add_child(ring)


# --- State -----------------------------------------------------------------

func refresh_all() -> void:
	for id in state.business_ids():
		refresh_business(id)


func refresh_business(id: String) -> void:
	var node: Node3D = buildings.get(id)
	if node == null:
		return
	var business := state.business(id)
	if business == null:
		return
	var locked := not business.unlocked
	var accent := BusinessData.accent(id)

	var model: Node3D = node.get_node_or_null("Model")
	if model != null:
		var was_visible := model.visible
		model.visible = not locked
		if not locked and not was_visible:
			model.scale = Vector3.ONE * BUSINESS_SCALE * 0.6
			var tween := create_tween()
			tween.tween_property(
				model, "scale", Vector3.ONE * BUSINESS_SCALE, 0.45
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var totem := node.get_node_or_null("Totem")
	if totem != null:
		var board: MeshInstance3D = totem.get_node_or_null("Board")
		var lamp: MeshInstance3D = totem.get_node_or_null("Lamp")
		if board != null:
			var board_material := StandardMaterial3D.new()
			board_material.albedo_color = Color(0.55, 0.53, 0.46) if locked else accent
			board_material.emission_enabled = not locked
			board_material.emission = accent
			board_material.emission_energy_multiplier = 0.45
			board_material.roughness = 0.6
			board.material_override = board_material
		if lamp != null:
			var lamp_material := StandardMaterial3D.new()
			lamp_material.albedo_color = Color(0.5, 0.48, 0.42) if locked else Color(1, 0.96, 0.86)
			lamp_material.emission_enabled = not locked
			lamp_material.emission = Color(1.0, 0.9, 0.7)
			lamp_material.emission_energy_multiplier = 0.8
			lamp.material_override = lamp_material

	var group: Array = pips.get(id, [])
	for i in group.size():
		group[i].visible = (not locked) and business.level > i + 1


func set_selected(id: String) -> void:
	highlight_id = id
	if ring == null:
		return
	if id.is_empty() or not buildings.has(id):
		ring.visible = false
		return
	var plot := BusinessData.plot(id)
	ring.position = Vector3(plot.x, 0.09, plot.y)
	ring.scale = Vector3.ONE
	var material := StandardMaterial3D.new()
	var accent := BusinessData.accent(id)
	material.albedo_color = accent
	material.emission_enabled = true
	material.emission = accent
	material.emission_energy_multiplier = 1.6
	ring.material_override = material
	ring.visible = true
	var tween := create_tween().set_loops()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.06, 0.8)
	tween.tween_property(ring, "scale", Vector3.ONE, 0.8)


func select_at(camera: Camera3D, screen_point: Vector2) -> String:
	if camera == null or get_world_3d() == null:
		return ""
	var from := camera.project_ray_origin(screen_point)
	var to := from + camera.project_ray_normal(screen_point) * 220.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return ""
	var collider: Object = hit.get("collider")
	if collider == null:
		return ""
	return str(collider.get_meta("business_id", ""))
