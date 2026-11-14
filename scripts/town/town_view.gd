class_name TownView
extends Node3D
## The 3D roadside town: desert ground, a highway with traffic, one plot per
## business and the selection ring.

const BUSINESS_SCALE := 2.4
const ROAD_WIDTH := 3.0
const ROAD_SEGMENTS := 13
const ROAD_STEP := 3.0
const PROP_MODELS: Array[String] = [
	"grass-trees-tall", "grass-trees", "grass-trees", "grass-trees-tall",
	"grass-trees", "grass-trees-tall",
]
const PROP_SPOTS: Array[Vector3] = [
	Vector3(-9.5, 0, -13.0), Vector3(9.5, 0, -13.0),
	Vector3(-10.0, 0, -4.0), Vector3(10.0, 0, -4.0),
	Vector3(-9.5, 0, 12.0), Vector3(9.5, 0, 12.0),
]

var state: TownState
var buildings: Dictionary = {}
var pips: Dictionary = {}
var ring: MeshInstance3D
var highlight_id := ""
var _locked_material: StandardMaterial3D


func setup(town_state: TownState) -> void:
	state = town_state
	_locked_material = StandardMaterial3D.new()
	_locked_material.albedo_color = Color(0.55, 0.56, 0.6, 0.55)
	_locked_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_locked_material.roughness = 1.0

	_build_environment()
	_build_ground()
	_build_road()
	_build_props()
	_build_businesses()
	_build_ring()
	refresh_all()


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	var top := TownData.sky_color(state.town_id)
	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = top.lightened(0.45)
	sky_material.ground_horizon_color = TownData.ground_color(state.town_id)
	sky_material.ground_bottom_color = Color(0.4, 0.34, 0.26)
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = TownData.ground_color(state.town_id)
	material.roughness = 1.0
	ground.material_override = material
	ground.position.y = -0.02
	add_child(ground)


func _build_road() -> void:
	var plain: PackedScene = load(BusinessData.MODELS["road-straight"])
	var lit: PackedScene = load(BusinessData.MODELS["road-straight-lightposts"])
	var pavement: PackedScene = load(BusinessData.MODELS["pavement"])

	for i in ROAD_SEGMENTS:
		var z := -ROAD_STEP * (ROAD_SEGMENTS - 1) * 0.5 + i * ROAD_STEP
		var source: PackedScene = lit if i % 4 == 0 else plain
		if source != null:
			var piece: Node3D = source.instantiate()
			piece.position = Vector3(0, 0, z)
			piece.scale = Vector3(ROAD_WIDTH, 1.0, ROAD_STEP)
			add_child(piece)
		if pavement != null:
			for side in [-1.0, 1.0]:
				var walk: Node3D = pavement.instantiate()
				walk.position = Vector3(1.75 * side - 0.35 * side, 0.01, z)
				walk.scale = Vector3(1.6, 1.0, ROAD_STEP)
				add_child(walk)

	var traffic := Traffic.new()
	traffic.name = "Traffic"
	add_child(traffic)


func _build_props() -> void:
	for i in PROP_SPOTS.size():
		var path: String = BusinessData.MODELS.get(PROP_MODELS[i % PROP_MODELS.size()], "")
		if path.is_empty():
			continue
		var scene: PackedScene = load(path)
		if scene == null:
			continue
		var prop: Node3D = scene.instantiate()
		prop.position = PROP_SPOTS[i]
		prop.scale = Vector3.ONE * 2.0
		prop.rotation_degrees.y = float(i) * 47.0
		add_child(prop)


func _build_businesses() -> void:
	for id in state.business_ids():
		var plot := BusinessData.plot(id)
		var node := Node3D.new()
		node.name = "Business_%s" % id
		node.position = Vector3(plot.x, 0, plot.y)
		add_child(node)

		_build_plot_ground(node)
		_build_model(node, id)
		_build_sign(node, id)
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
	parent.add_child(model)


func _build_sign(parent: Node3D, id: String) -> void:
	var sign := MeshInstance3D.new()
	sign.name = "Sign"
	var board := BoxMesh.new()
	board.size = Vector3(1.5, 0.5, 0.08)
	sign.mesh = board
	var material := StandardMaterial3D.new()
	material.albedo_color = BusinessData.accent(id)
	material.emission_enabled = true
	material.emission = BusinessData.accent(id)
	material.emission_energy_multiplier = 0.5
	sign.material_override = material
	sign.position = Vector3(0, 1.9, -1.35)
	parent.add_child(sign)


func _build_pips(parent: Node3D, id: String) -> void:
	var group: Array[MeshInstance3D] = []
	for i in BusinessData.MAX_LEVEL - 1:
		var pip := MeshInstance3D.new()
		pip.name = "Pip%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.3, 0.18)
		pip.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = BusinessData.accent(id)
		pip.material_override = material
		pip.position = Vector3(-0.4 + 0.27 * float(i), 0.16, 1.5)
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
	var model: Node3D = node.get_node_or_null("Model")
	if model != null:
		for mesh in _mesh_instances(model):
			mesh.material_override = _locked_material if locked else null
	var sign_node: Node3D = node.get_node_or_null("Sign")
	if sign_node != null:
		sign_node.visible = not locked
	var group: Array = pips.get(id, [])
	for i in group.size():
		group[i].visible = (not locked) and business.level > i + 1


func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		found.append(root)
	for child in root.get_children():
		found.append_array(_mesh_instances(child))
	return found


func set_selected(id: String) -> void:
	highlight_id = id
	if ring == null:
		return
	if id.is_empty() or not buildings.has(id):
		ring.visible = false
		return
	var plot := BusinessData.plot(id)
	ring.position = Vector3(plot.x, 0.09, plot.y)
	var material := StandardMaterial3D.new()
	var accent := BusinessData.accent(id)
	material.albedo_color = accent
	material.emission_enabled = true
	material.emission = accent
	material.emission_energy_multiplier = 1.2
	ring.material_override = material
	ring.visible = true


## Returns the business id under the screen point, or "" for empty ground.
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
