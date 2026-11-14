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
const PARKED_CARS := [
	{"id": "gas_station", "offset": Vector3(1.85, 0, -1.25), "yaw": 92.0,
		"color": Color(0.82, 0.28, 0.24)},
	{"id": "motel", "offset": Vector3(-1.85, 0, 1.15), "yaw": -88.0,
		"color": Color(0.26, 0.46, 0.8)},
	{"id": "store", "offset": Vector3(1.8, 0, 1.3), "yaw": 6.0,
		"color": Color(0.9, 0.78, 0.32)},
]

var state: TownState
var buildings: Dictionary = {}
var pips: Dictionary = {}
var ring: MeshInstance3D
var highlight_id := ""
var _locked_material: StandardMaterial3D
var _plot_points: Array[Vector2] = []
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _env: Environment
var _sky_material: ProceduralSkyMaterial
var _night_materials: Array[StandardMaterial3D] = []
var _pool_materials: Array[StandardMaterial3D] = []
var _stages: Dictionary = {}
var _totem_materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(town_state: TownState) -> void:
	state = town_state
	_rng.seed = SEED
	_plot_points.clear()
	for id in state.business_ids():
		_plot_points.append(BusinessData.plot(id))
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
	_sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.46
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.84
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	# Depth haze: it separates the dunes from the play area and costs nothing.
	env.fog_enabled = true
	env.fog_light_color = TownData.ground_color(state.town_id).lightened(0.35)
	env.fog_light_energy = 0.7
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.25
	world.environment = env
	_env = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 0.88
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.rotation_degrees = Vector3(-50, -38, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.04
	_sun = sun
	add_child(sun)

	# Cool bounce from the opposite side so shadowed faces keep their shape.
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_energy = 0.22
	fill.light_color = Color(0.66, 0.78, 1.0)
	fill.rotation_degrees = Vector3(-24, 150, 0)
	fill.shadow_enabled = false
	_fill = fill
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
		var distance := _rng.randf_range(31.0, 46.0)
		dune.position = Vector3(cos(angle) * distance, -0.55, sin(angle) * distance)
		var stretch := _rng.randf_range(9.0, 18.0)
		dune.scale = Vector3(stretch, _rng.randf_range(1.6, 3.2), stretch * _rng.randf_range(0.6, 1.0))
		dune.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
		dune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dune)


# --- Scatter ---------------------------------------------------------------

func _is_free_ground(point: Vector3) -> bool:
	if absf(point.x) < ROAD_CORRIDOR and absf(point.z) < 24.0:
		return false
	for plot in _plot_points:
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
		if i % 3 == 0:
			for side in [-1.0, 1.0]:
				_lamp(Vector3(1.62 * side, 2.1, z))
		if pavement != null:
			for side in [-1.0, 1.0]:
				var walk: Node3D = pavement.instantiate()
				walk.position = Vector3(1.4 * side, 0.01, z)
				walk.scale = Vector3(1.6, 1.0, ROAD_STEP)
				add_child(walk)

	var traffic := Traffic.new()
	traffic.name = "Traffic"
	add_child(traffic)

	var pedestrians := Pedestrians.new()
	pedestrians.name = "Pedestrians"
	add_child(pedestrians)


func _lamp(position: Vector3) -> void:
	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	lamp.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.94, 0.78)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.9, 0.68)
	material.emission_energy_multiplier = 0.4
	lamp.material_override = material
	lamp.position = position
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamp)
	_night_materials.append(material)


# --- Businesses ------------------------------------------------------------

func _build_businesses() -> void:
	for id in state.business_ids():
		var plot := BusinessData.plot(id)
		var node := Node3D.new()
		node.name = "Business_%s" % id
		node.position = Vector3(plot.x, 0, plot.y)
		add_child(node)

		_build_plot_ground(node)
		_build_light_pool(node, id)
		_build_model(node, id)
		_build_stages(node, id)
		_build_totem(node, id)
		_build_pips(node, id)
		_build_collider(node, id)
		buildings[id] = node

	for spot in PARKED_CARS:
		var host: Node3D = buildings.get(str(spot["id"]))
		if host != null:
			_add_parked_car(host, spot)

	_add_barrels(buildings.get("workshop"))


func _build_plot_ground(parent: Node3D) -> void:
	var apron := MeshInstance3D.new()
	apron.name = "Apron"
	var apron_mesh := BoxMesh.new()
	apron_mesh.size = Vector3(3.9, 0.08, 3.9)
	apron.mesh = apron_mesh
	apron.material_override = _sand_material(
		TownData.ground_color(state.town_id).darkened(0.28)
	)
	apron.position.y = -0.01
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(apron)

	var path: String = BusinessData.MODELS["pavement"]
	var scene: PackedScene = load(path)
	if scene == null:
		return
	var plot: Node3D = scene.instantiate()
	plot.name = "Plot"
	plot.scale = Vector3(3.4, 1.0, 3.4)
	plot.position.y = 0.01
	parent.add_child(plot)


## A soft additive disc on the ground; its alpha follows the night factor.
func _build_light_pool(parent: Node3D, id: String) -> void:
	var pool := MeshInstance3D.new()
	pool.name = "LightPool"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.7
	disc.bottom_radius = 1.9
	disc.height = 0.02
	disc.radial_segments = 20
	pool.mesh = disc
	var material := StandardMaterial3D.new()
	var accent := BusinessData.accent(id)
	material.albedo_color = Color(accent.r, accent.g, accent.b, 0.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	pool.material_override = material
	pool.position.y = 0.05
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(pool)
	_pool_materials.append(material)


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


func _build_stages(parent: Node3D, id: String) -> void:
	var list: Array[Node3D] = []
	for stage in BusinessDecor.STAGE_LEVELS:
		var node := BusinessDecor.build_stage(id, stage, BusinessData.accent(id))
		node.name = "Stage%d" % stage
		node.visible = false
		parent.add_child(node)
		list.append(node)
		for material in node.get_meta("night_materials", []):
			_night_materials.append(material as StandardMaterial3D)
	_stages[id] = list


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
	var board_material := StandardMaterial3D.new()
	board_material.roughness = 0.6
	board.material_override = board_material
	totem.add_child(board)

	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.7, 0.16, 0.05)
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(0, 1.22, 0.05)
	var lamp_material := StandardMaterial3D.new()
	lamp.material_override = lamp_material
	totem.add_child(lamp)

	_totem_materials[id] = {"board": board_material, "lamp": lamp_material}
	_night_materials.append(board_material)
	_night_materials.append(lamp_material)


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


func _add_parked_car(parent: Node3D, spot: Dictionary) -> void:
	var car := Node3D.new()
	car.name = "Parked"
	car.position = spot["offset"]
	car.rotation_degrees.y = float(spot["yaw"])
	car.scale = Vector3(0.9, 0.9, 0.9)
	parent.add_child(car)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.55, 0.3, 1.05)
	body.mesh = body_mesh
	body.position.y = 0.3
	body.material_override = _carlike(spot["color"], 0.4, 0.2)
	car.add_child(body)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(0.5, 0.26, 0.5)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0, 0.56, -0.05)
	cabin.material_override = _carlike(Color(0.16, 0.2, 0.26), 0.15, 0.4)
	car.add_child(cabin)

	for side in [-1.0, 1.0]:
		for axle in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.13
			cylinder.bottom_radius = 0.13
			cylinder.height = 0.09
			cylinder.radial_segments = 10
			wheel.mesh = cylinder
			wheel.rotation_degrees.z = 90.0
			wheel.position = Vector3(0.3 * side, 0.13, 0.33 * axle)
			wheel.material_override = _carlike(Color(0.09, 0.1, 0.12), 0.6, 0.1)
			car.add_child(wheel)


func _add_barrels(host: Node3D) -> void:
	if host == null:
		return
	var colors := [Color(0.62, 0.35, 0.2), Color(0.3, 0.45, 0.6), Color(0.45, 0.5, 0.3)]
	for i in colors.size():
		var barrel := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.22
		mesh.bottom_radius = 0.22
		mesh.height = 0.6
		mesh.radial_segments = 12
		barrel.mesh = mesh
		barrel.position = Vector3(-1.5 + 0.55 * float(i), 0.3, -1.45)
		barrel.material_override = _carlike(colors[i], 0.55, 0.3)
		host.add_child(barrel)


func _carlike(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


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
		elif not locked:
			# Each level makes the building itself a little more substantial.
			var growth := 1.0 + 0.025 * float(business.level - 1)
			model.scale = Vector3.ONE * BUSINESS_SCALE * growth

	var stages: Array = _stages.get(id, [])
	for i in stages.size():
		var stage_node: Node3D = stages[i]
		var should_show := (not locked) and business.level >= i + 2
		if should_show and not stage_node.visible:
			stage_node.visible = true
			stage_node.scale = Vector3.ONE * 0.2
			var stage_tween := create_tween()
			stage_tween.tween_property(stage_node, "scale", Vector3.ONE, 0.4) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif not should_show:
			stage_node.visible = false

	var materials: Dictionary = _totem_materials.get(id, {})
	if not materials.is_empty():
		var board_material: StandardMaterial3D = materials["board"]
		board_material.albedo_color = Color(0.55, 0.53, 0.46) if locked else accent
		board_material.emission = accent
		var lamp_material: StandardMaterial3D = materials["lamp"]
		lamp_material.albedo_color = Color(0.5, 0.48, 0.42) if locked else Color(1, 0.96, 0.86)
		lamp_material.emission = Color(1.0, 0.9, 0.7)

	var group: Array = pips.get(id, [])
	for i in group.size():
		group[i].visible = (not locked) and business.level > i + 1


func sparkle(id: String) -> void:
	if not buildings.has(id):
		return
	var particles := CPUParticles3D.new()
	particles.name = "Sparkle"
	particles.amount = 20
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 1.1
	particles.direction = Vector3.UP
	particles.spread = 55.0
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 2.6
	particles.gravity = Vector3(0, -2.6, 0)
	particles.scale_amount_min = 0.05
	particles.scale_amount_max = 0.13
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	particles.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.83, 0.35)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.3)
	material.emission_energy_multiplier = 2.4
	particles.material_override = material
	var plot := BusinessData.plot(id)
	particles.position = Vector3(plot.x, 0.9, plot.y)
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func pop_income(id: String, amount: float) -> void:
	if not buildings.has(id) or amount < 1.0:
		return
	var label := Label3D.new()
	label.name = "Income"
	label.text = "+%d" % int(round(amount))
	label.font_size = 64
	label.pixel_size = 0.0055
	label.modulate = Color(1.0, 0.85, 0.42)
	label.outline_size = 14
	label.outline_modulate = Color(0.05, 0.06, 0.09, 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var plot := BusinessData.plot(id)
	label.position = Vector3(plot.x, 1.7, plot.y)
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", 2.8, 1.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate:a", 0.0, 1.3)
	tween.chain().tween_callback(label.queue_free)


## 0 = sunrise, 0.25 = noon, 0.5 = sunset, 0.75 = midnight.
func apply_time(t: float) -> void:
	var elevation := sin(t * TAU)
	var day := clampf(elevation, 0.0, 1.0)
	var night := clampf(-elevation * 2.6, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(elevation) * 3.4, 0.0, 1.0)
	var sand := TownData.ground_color(state.town_id)
	var sky_day := TownData.sky_color(state.town_id)

	if _sun != null:
		# The same light doubles as the moon after sunset, so the town never
		# turns into a black silhouette.
		_sun.rotation_degrees = Vector3(
			-(12.0 + 68.0 * day), -40.0 + 360.0 * t, 0
		)
		_sun.light_energy = 0.26 + 0.72 * day
		var sun_color := Color(0.62, 0.72, 1.0)
		sun_color = sun_color.lerp(Color(1.0, 0.58, 0.32), dusk * 0.9)
		sun_color = sun_color.lerp(Color(1.0, 0.94, 0.84), day)
		_sun.light_color = sun_color
	if _fill != null:
		_fill.light_energy = 0.16 + 0.12 * day
		_fill.light_color = Color(0.45, 0.55, 0.85).lerp(Color(0.66, 0.78, 1.0), day)
	if _env != null:
		_env.ambient_light_energy = 0.34 + 0.2 * day
		_env.ambient_light_color = Color(0.32, 0.4, 0.62).lerp(Color(0.86, 0.92, 1.0), day)
		_env.fog_light_color = sand.lightened(0.3).lerp(Color(0.14, 0.18, 0.32), night)
		_env.fog_density = 0.0038 + 0.0012 * night
	if _sky_material != null:
		_sky_material.sky_top_color = sky_day.lerp(Color(0.07, 0.1, 0.22), night)
		var horizon := sky_day.lightened(0.22)
		horizon = horizon.lerp(Color(1.0, 0.56, 0.32), dusk * 0.85)
		_sky_material.sky_horizon_color = horizon.lerp(Color(0.13, 0.17, 0.3), night)
		_sky_material.ground_horizon_color = horizon.lerp(sand.lightened(0.15), 0.4 * day)
		_sky_material.ground_bottom_color = sand.darkened(0.45).lerp(
			Color(0.05, 0.06, 0.1), night
		)

	var glow := 0.2 + 1.05 * night
	for material in _night_materials:
		material.emission_enabled = night > 0.08
		material.emission_energy_multiplier = glow
	for material in _pool_materials:
		var tint := material.albedo_color
		material.albedo_color = Color(tint.r, tint.g, tint.b, 0.34 * night)


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
