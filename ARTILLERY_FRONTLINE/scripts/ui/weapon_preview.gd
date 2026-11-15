class_name WeaponPreview
extends SubViewportContainer
## A still studio view of the actual selected weapon scene, including its in-game
## materials and dressing. Render only on selection; no second world during play.

var viewport: SubViewport
var stand: Node3D
var camera: Camera3D
var weapon: Weapon
var displayed_model: Node3D
var displayed_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	custom_minimum_size = Vector2(430, 310)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 440)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	stand = Node3D.new()
	viewport.add_child(stand)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.055, 0.067, 0.072)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.74, 0.79, 0.83)
	settings.ambient_light_energy = 1.15
	environment.environment = settings
	stand.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -32, 0)
	key.light_energy = 2.0
	stand.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_color = Color(0.65, 0.77, 1.0)
	fill.light_energy = 1.0
	stand.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stand.add_child(camera)
	camera.current = true


func show_weapon(id: String) -> void:
	if not Profile.EQUIPMENT.has(id) or stand == null:
		return
	if is_instance_valid(displayed_model):
		stand.remove_child(displayed_model)
		displayed_model.queue_free()
	weapon = null
	if id == "frag_grenade":
		displayed_model = (load("res://assets/models/weapons/frag_grenade.glb") as PackedScene).instantiate() as Node3D
	else:
		weapon = (load("res://scenes/weapons/%s.tscn" % id) as PackedScene).instantiate() as Weapon
		displayed_model = weapon
	stand.add_child(displayed_model)
	if weapon != null:
		weapon.readiness = 1.0
		weapon._pose()
		weapon.set_process(false)
		weapon.set_physics_process(false)
	displayed_id = id
	# Combine visible model geometry in the weapon's coordinates; hide ephemeral
	# flashes and particles and frame the real model, not hard-coded dimensions.
	var bounds := AABB()
	var first := true
	for node: Node in displayed_model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		# In an isolated studio there is no city to reflect in metal. Give only
		# this preview a soft fill so black/gilded variants remain legible.
		for surface: int in mesh.mesh.get_surface_count():
			var source: Material = mesh.get_active_material(surface)
			if source is StandardMaterial3D:
				var material: StandardMaterial3D = source.duplicate()
				material.metallic *= 0.35
				material.emission_enabled = true
				material.emission = material.albedo_color
				material.emission_energy_multiplier = 0.18
				mesh.set_surface_override_material(surface, material)
		var part: AABB = (displayed_model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = part if first else bounds.merge(part)
		first = false
	var center: Vector3 = bounds.get_center()
	var extent: float = maxf(bounds.size.length(), 0.04)
	camera.near = maxf(0.005, extent * 0.02)
	camera.position = center + Vector3(1.35, 0.95, 1.6).normalized() * extent * 2.5
	camera.look_at(center, Vector3.UP)
	camera.size = extent * 1.15
	camera.far = extent * 10.0 + 20.0
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
