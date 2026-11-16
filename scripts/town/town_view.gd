class_name TownView
extends Node3D
## Sunny, low-poly Roadside Empire hub. The cartoon art pass changes only
## rendering: all building solids, bay coordinates and traffic remain shared
## with the validated driving layout.

const BUSINESS_SCALE := 2.25
const SEED := 20261115
# Compatibility Lambert lighting needs headroom to retain the reference sRGB hues.
const DAYLIGHT_GAIN := 0.37

var state: TownState
var buildings: Dictionary = {}
var ring: MeshInstance3D
var highlight_id := ""
var staff: TownStaff
var customers: CustomerFlow
var _plot_roots: Dictionary = {}
var _plot_lights: Dictionary = {}
var _physical_props: Dictionary = {}
var _building_nights: Dictionary = {}
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

	var q_preset: String = App.quality if App != null else Quality.DEFAULT
	customers = CustomerFlow.new()
	customers.name = "Customers"
	customers.max_agents = Quality.agent_cap(q_preset)
	add_child(customers)
	customers.setup(state)

	var walkers := Pedestrians.new()
	walkers.name = "Pedestrians"
	walkers.state = state
	walkers.count = Quality.pedestrian_count(q_preset)
	add_child(walkers)

	staff = TownStaff.new()
	staff.name = "Staff"
	add_child(staff)
	staff.setup(state)
	refresh_all()
	apply_quality(q_preset)


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
	env.ambient_light_color = Color(0.96, 0.98, 1.0)
	env.ambient_light_energy = 0.60 * DAYLIGHT_GAIN
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.0
	env.fog_enabled = true
	env.fog_light_color = TownData.ground_color(state.town_id).lightened(0.12)
	env.fog_light_energy = 0.45
	env.fog_density = 0.0008
	env.fog_sky_affect = 0.10
	world.environment = env
	_env = env
	add_child(world)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_energy = 0.82 * DAYLIGHT_GAIN
	_sun.light_color = Color(1.0, 0.99, 0.96)
	_sun.rotation_degrees = Vector3(-52, -36, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 68.0
	_sun.shadow_blur = 1.15
	_sun.shadow_opacity = 0.46
	_sun.shadow_bias = 0.04
	_sun.shadow_normal_bias = 1.0
	add_child(_sun)

	_fill = DirectionalLight3D.new()
	_fill.name = "Fill"
	_fill.light_energy = 0.12 * DAYLIGHT_GAIN
	_fill.light_color = Color(0.68, 0.82, 1.0)
	_fill.rotation_degrees = Vector3(-34, 142, 0)
	_fill.shadow_enabled = false
	add_child(_fill)


func _build_ground() -> void:
	SurfaceMaterials.paving(
		self, "grass", TownData.ground_color(state.town_id), Vector3(0, -0.01, 0), Vector2(160, 160)
	)


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
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("business_id", id)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.6, 2.8, 3.6)
		shape.shape = box
		shape.position = Vector3(0, 1.4, 0)
		body.add_child(shape)
		slot.add_child(body)
		# Touch targets are NOT road obstacles; solid geometry has its own layer.
		_add_solid(self, ForecourtLayout.building_rect(id), "Building_" + id, 3.9)
		var props := Node3D.new()
		props.name = "PhysicalProps_" + id
		add_child(props)
		_physical_props[id] = props

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

	var physical: Node3D = _physical_props[id]
	for child in physical.get_children():
		physical.remove_child(child)
		child.queue_free()
	if b.unlocked:
		for rect in ForecourtLayout.prop_rects(id, bays):
			_add_solid(physical, rect, "Equipment_" + id, 2.15)
	_building_nights[id] = []
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
			tw.tween_property(visual, "scale", Vector3.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if staff != null:
		staff.refresh_business(id)


func _populate_unlocked_building(visual: Node3D, id: String, b: BusinessState, stage: int, bays: int) -> void:
	var nights: Array[StandardMaterial3D] = []
	visual.add_child(CartoonBuildings.build(id, stage, nights))
	visual.add_child(BusinessDecor.build_facility(id, b.level, bays, nights))
	_building_nights[id] = nights


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
	var amt_txt: String = App.format_short(amount) if App != null else ("%d" % int(round(amount)))
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
	var turf := TownData.ground_color(state.town_id)
	var sky_day := TownData.sky_color(state.town_id)
	var lighting_gain := lerpf(DAYLIGHT_GAIN, 1.0, night)

	if _sun != null:
		_sun.rotation_degrees = Vector3(-(32.0 + 26.0 * day), -36.0, 0)
		_sun.light_energy = (0.12 + 0.66 * day + 0.12 * dusk) * lighting_gain
		var sun_col := Color(1.0, 0.99, 0.96).lerp(Color(1.0, 0.89, 0.74), dusk * 0.45)
		_sun.light_color = sun_col.lerp(Color(0.72, 0.78, 0.96), night * 0.6)
	if _fill != null:
		_fill.light_energy = (0.12 + 0.02 * day) * lighting_gain
	if _env != null:
		_env.ambient_light_energy = (0.58 - 0.12 * night) * lighting_gain
		var amb := Color(0.96, 0.98, 1.0).lerp(Color(1.0, 0.96, 0.87), dusk * 0.30)
		_env.ambient_light_color = amb.lerp(Color(0.58, 0.67, 0.85), night)
		_env.fog_light_color = turf.lightened(0.22).lerp(Color(0.14, 0.18, 0.32), night)
	if _sky_material != null:
		_sky_material.sky_top_color = sky_day.lerp(Color(0.08, 0.12, 0.24), night)
		var hor := sky_day.lightened(0.25).lerp(Color(1.0, 0.58, 0.34), dusk * 0.85)
		_sky_material.sky_horizon_color = hor.lerp(Color(0.14, 0.18, 0.32), night)

	var glow := 0.02 + 0.82 * night
	for materials in _building_nights.values():
		for mat in materials:
			(mat as StandardMaterial3D).emission_energy_multiplier = glow
	for mat in _night_materials:
		if is_instance_valid(mat):
			mat.emission_enabled = true
			mat.emission_energy_multiplier = glow
	var lit := 0
	var light_limit := Quality.light_budget(App.quality)
	for id in _plot_lights.keys():
		var light: OmniLight3D = _plot_lights[id]
		var b := state.business(id)
		light.visible = (b != null and b.unlocked) and night > 0.2 and lit < light_limit
		if light.visible:
			lit += 1
		light.light_energy = 0.85 * clampf(night * 1.4, 0.0, 1.0)


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
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return ""
	var collider: Object = hit.get("collider")
	if collider == null:
		return ""
	return str(collider.get_meta("business_id", ""))


func _add_solid(parent: Node3D, rect: Rect2, label: String, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = VehicleBody.SOLID_LAYER
	body.collision_mask = VehicleBody.VEHICLE_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x, height, rect.size.y)
	shape.shape = box
	var center := rect.get_center()
	body.position = Vector3(center.x, height * 0.5, center.y)
	body.add_child(shape)
	parent.add_child(body)


func apply_quality(preset: String) -> void:
	var traffic := get_node_or_null("Traffic") as Traffic
	if traffic != null:
		traffic.count = Quality.highway_count(preset)
	_sun.shadow_enabled = Quality.normalise(preset) != "low"
	get_viewport().msaa_3d = Viewport.MSAA_2X if preset == "high" else Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = (
		Viewport.SCREEN_SPACE_AA_FXAA if preset == "medium" else Viewport.SCREEN_SPACE_AA_DISABLED
	)
