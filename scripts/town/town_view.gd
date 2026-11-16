class_name TownView
extends Node3D
## The 3D Roadside Empire compound: warm sunlit desert canyon, diagonal highway
## with traffic, derelict tire/crate junkyards for unbuilt plots, custom-dressed
## facilities with 3D rooftop signs & fuel pump bays, attendants and customers!

const BUSINESS_SCALE := 2.25
const SEED := 20261115

var state: TownState
var buildings: Dictionary = {}
var ring: MeshInstance3D
var highlight_id := ""
var staff: TownStaff
var customers: CustomerFlow
var _plot_roots: Dictionary = {}
var _plot_lights: Dictionary = {}
var _built_signature: Dictionary = {}
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _env: Environment
var _sky_material: ProceduralSkyMaterial
var _night_materials: Array[StandardMaterial3D] = []
var _rng := RandomNumberGenerator.new()


func setup(town_state: TownState) -> void:
	state = town_state
	_rng.seed = SEED
	_build_environment()
	_build_ground()
	DesertCanyon.build_all(self, state.town_id, _night_materials)
	_build_businesses()
	_build_ring()

	var traffic := Traffic.new()
	traffic.name = "Traffic"
	add_child(traffic)

	var q_preset := App.quality if App != null else Quality.MEDIUM
	customers = CustomerFlow.new()
	customers.name = "Customers"
	customers.max_agents = Quality.agent_cap(q_preset)
	add_child(customers)
	customers.setup(state)

	var walkers := Pedestrians.new()
	walkers.name = "Pedestrians"
	walkers.count = Quality.pedestrian_count(q_preset)
	add_child(walkers)

	staff = TownStaff.new()
	staff.name = "Staff"
	add_child(staff)
	staff.setup(state)
	refresh_all()


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "World"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var top := TownData.sky_color(state.town_id)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = top.lightened(0.28)
	sky_mat.ground_horizon_color = TownData.ground_color(state.town_id).lightened(0.14)
	sky_mat.ground_bottom_color = TownData.ground_color(state.town_id).darkened(0.32)
	sky_mat.sun_angle_max = 16.0
	sky.sky_material = sky_mat
	_sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.94, 0.84)
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.78
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.16
	env.adjustment_contrast = 1.06
	env.fog_enabled = true
	env.fog_light_color = TownData.ground_color(state.town_id).lightened(0.12)
	env.fog_light_energy = 0.45
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.10
	world.environment = env
	_env = env
	add_child(world)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_energy = 1.05
	_sun.light_color = Color(1.0, 0.94, 0.80)
	_sun.rotation_degrees = Vector3(-52, -36, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 56.0
	add_child(_sun)

	_fill = DirectionalLight3D.new()
	_fill.name = "Fill"
	_fill.light_energy = 0.22
	_fill.light_color = Color(0.68, 0.82, 1.0)
	_fill.rotation_degrees = Vector3(-34, 142, 0)
	_fill.shadow_enabled = false
	add_child(_fill)


func _build_ground() -> void:
	var plane := MeshInstance3D.new()
	plane.name = "DesertFloor"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(160.0, 160.0)
	plane.mesh = mesh

	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.frequency = 0.035
	var ramp := Gradient.new()
	var base := TownData.ground_color(state.town_id)
	ramp.set_color(0, base.darkened(0.08))
	ramp.set_color(1, base.lightened(0.08))
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(14.0, 14.0, 1.0)
	mat.roughness = 0.96
	plane.material_override = mat
	add_child(plane)


func _build_businesses() -> void:
	for id in state.business_ids():
		var plot := BusinessData.plot(id)
		var slot := Node3D.new()
		slot.name = "Plot_" + id
		slot.position = Vector3(plot.x, 0.0, plot.y)
		add_child(slot)
		buildings[id] = slot

		# Tap collider covering both building & bay apron for effortless mobile taps!
		var body := StaticBody3D.new()
		body.name = "Hit_" + id
		body.set_meta("business_id", id)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.6, 2.8, 3.6)
		shape.shape = box
		shape.position = Vector3(0, 1.4, 0)
		body.add_child(shape)
		slot.add_child(body)

		var visual := Node3D.new()
		visual.name = "Visual"
		slot.add_child(visual)
		_plot_roots[id] = visual

		var omni := OmniLight3D.new()
		omni.light_color = Color(1.0, 0.86, 0.62)
		omni.omni_range = 4.5
		omni.light_energy = 0.0
		omni.visible = false
		omni.position = Vector3(0, 1.8, 1.2)
		slot.add_child(omni)
		_plot_lights[id] = omni


func _build_ring() -> void:
	ring = MeshInstance3D.new()
	ring.name = "SelectionRing"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.05
	cyl.bottom_radius = 2.05
	cyl.height = 0.05
	cyl.radial_segments = 28
	ring.mesh = cyl
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func refresh_all() -> void:
	for id in state.business_ids():
		refresh_business(id)
	if staff != null:
		staff.refresh()


func refresh_business(id: String) -> void:
	if not _plot_roots.has(id):
		return
	var b := state.business(id)
	if b == null:
		return
	var stage := BusinessData.renovation_stage(b.level)
	var bays := b.active_bays()
	var sig := "%s:%d:%d" % [str(b.unlocked), stage, bays]
	if str(_built_signature.get(id, "")) == sig:
		return
	var was_locked := str(_built_signature.get(id, "false")).begins_with("false")
	_built_signature[id] = sig

	var visual: Node3D = _plot_roots[id]
	for child in visual.get_children():
		child.queue_free()

	if not b.unlocked:
		visual.add_child(BusinessDecor.build_junkyard(id))
	else:
		_populate_unlocked_building(visual, id, b, stage, bays)
		if was_locked:
			visual.scale = Vector3.ONE * 0.25
			var tw := create_tween()
			tw.tween_property(visual, "scale", Vector3.ONE, 0.42) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if staff != null:
		staff.refresh_business(id)


func _populate_unlocked_building(
	visual: Node3D, id: String, _b: BusinessState, stage: int, bays: int
) -> void:
	var d := BusinessData.data(id)
	var wall_col: Color = d.get("accent", Color(0.95, 0.45, 0.20))
	var roof_col: Color = d.get("roof", Color(0.24, 0.28, 0.56))

	# Crisp concrete pad + stylized Roadside Empire building block + kit detail!
	var pad_mat := VehicleMesh.paint(Color(0.76, 0.75, 0.72), 0.88, 0.0)
	var wall_mat := VehicleMesh.paint(wall_col.lerp(Color(0.96, 0.78, 0.54), 0.35), 0.65, 0.05)
	var roof_mat := VehicleMesh.paint(roof_col, 0.55, 0.12)
	var trim_mat := VehicleMesh.paint(wall_col, 0.45, 0.15)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.50, 0.80, 0.98)
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(0.45, 0.76, 0.98)
	glass_mat.emission_energy_multiplier = 0.45
	_night_materials.append(glass_mat)

	var h := 1.75 + float(stage >= 4) * 0.22
	_add_box(visual, pad_mat, Vector3(0, 0.05, 0), Vector3(3.1, 0.10, 2.6), false)
	_add_box(visual, wall_mat, Vector3(0, 0.10 + h * 0.5, 0), Vector3(2.55, h, 2.05))
	_add_box(visual, roof_mat, Vector3(0, 0.12 + h, 0), Vector3(2.78, 0.24, 2.28))
	_add_box(visual, trim_mat, Vector3(0, 0.24 + h, 0), Vector3(2.42, 0.16, 1.92))
	# Glowing storefront windows along the front!
	for wx in [-0.72, 0.0, 0.72]:
		_add_box(visual, glass_mat, Vector3(float(wx), 0.88, 1.04), Vector3(0.48, 0.68, 0.05), false)

	visual.add_child(BusinessDecor.build_facility(id, stage * 20, bays, _night_materials))


func _add_box(
	parent: Node3D, mat: StandardMaterial3D, pos: Vector3, size: Vector3, shadows: bool = true
) -> void:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	if not shadows:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


func sparkle(id: String) -> void:
	if not buildings.has(id):
		return
	var particles := CPUParticles3D.new()
	particles.amount = 20
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 1.0
	particles.direction = Vector3.UP
	particles.spread = 55.0
	particles.initial_velocity_min = 1.4
	particles.initial_velocity_max = 2.8
	particles.gravity = Vector3(0, -2.8, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, 0.09)
	particles.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.96, 0.44)
	mat.emission_enabled = true
	mat.emission = Color(0.32, 0.96, 0.44)
	mat.emission_energy_multiplier = 2.0
	particles.material_override = mat
	var plot := BusinessData.plot(id)
	particles.position = Vector3(plot.x, 1.1, plot.y)
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func pop_income(id: String, amount: float) -> void:
	if not buildings.has(id) or amount < 1.0:
		return
	var label := Label3D.new()
	var amt_txt := App.format_short(amount) if App != null else L10n.format_short("en", amount)
	label.text = "+$" + amt_txt
	label.font_size = 62
	label.pixel_size = 0.0058
	label.modulate = Color(0.36, 0.98, 0.46)
	label.outline_size = 12
	label.outline_modulate = Color(0.06, 0.10, 0.14, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var plot := BusinessData.plot(id)
	label.position = Vector3(plot.x, 2.2, plot.y)
	add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", 3.4, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(label, "modulate:a", 0.0, 1.2)
	tw.chain().tween_callback(label.queue_free)


func apply_time(t: float) -> void:
	var elevation := sin(t * TAU)
	var day := clampf(elevation, 0.0, 1.0)
	var night := clampf(-elevation * 2.4, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(elevation) * 2.4, 0.0, 1.0)
	var sand := TownData.ground_color(state.town_id)
	var sky_day := TownData.sky_color(state.town_id)

	if _sun != null:
		_sun.rotation_degrees = Vector3(-(18.0 + 62.0 * day), -38.0 + 360.0 * t, 0)
		_sun.light_energy = 0.50 + 0.62 * day + 0.14 * dusk
		var sun_col := Color(1.0, 0.95, 0.84).lerp(Color(1.0, 0.56, 0.28), dusk)
		_sun.light_color = sun_col.lerp(Color(0.72, 0.78, 0.96), night * 0.6)
	if _fill != null:
		_fill.light_energy = 0.16 + 0.12 * day
	if _env != null:
		_env.ambient_light_energy = 0.62 - 0.16 * day
		var amb := Color(0.96, 0.92, 0.86).lerp(Color(1.0, 0.78, 0.60), dusk * 0.75)
		_env.ambient_light_color = amb.lerp(Color(0.46, 0.50, 0.68), night)
		_env.fog_light_color = sand.lightened(0.22).lerp(Color(0.14, 0.18, 0.32), night)
	if _sky_material != null:
		_sky_material.sky_top_color = sky_day.lerp(Color(0.08, 0.12, 0.24), night)
		var hor := sky_day.lightened(0.25).lerp(Color(1.0, 0.58, 0.34), dusk * 0.85)
		_sky_material.sky_horizon_color = hor.lerp(Color(0.14, 0.18, 0.32), night)

	var glow := 0.25 + 1.15 * night
	for mat in _night_materials:
		if is_instance_valid(mat):
			mat.emission_enabled = true
			mat.emission_energy_multiplier = glow
	for id in _plot_lights.keys():
		var light: OmniLight3D = _plot_lights[id]
		var b := state.business(id)
		light.visible = (b != null and b.unlocked) and night > 0.2
		light.light_energy = 1.3 * clampf(night * 1.4, 0.0, 1.0)


func set_selected(id: String) -> void:
	highlight_id = id
	if ring == null:
		return
	if id.is_empty() or not buildings.has(id):
		ring.visible = false
		return
	var plot := BusinessData.plot(id)
	ring.position = Vector3(plot.x, 0.08, plot.y)
	var mat := StandardMaterial3D.new()
	var acc := BusinessData.accent(id)
	mat.albedo_color = acc
	mat.emission_enabled = true
	mat.emission = acc
	mat.emission_energy_multiplier = 1.5
	ring.material_override = mat
	ring.visible = true


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
