class_name WeaponPreview
extends SubViewportContainer
## A still studio view of the actual selected weapon scene, including its in-game
## materials and dressing. Render only on selection; no second world during play.

var viewport: SubViewport
var stand: Node3D
var camera: Camera3D
var weapon: Weapon
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
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	stand.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -32, 0)
	key.light_energy = 1.5
	stand.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_color = Color(0.65, 0.77, 1.0)
	fill.light_energy = 0.7
	stand.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stand.add_child(camera)
	camera.current = true


func show_weapon(id: String) -> void:
	if not Profile.GUNS.has(id) or stand == null:
		return
	if is_instance_valid(weapon):
		stand.remove_child(weapon)
		weapon.queue_free()
	weapon = (load("res://scenes/weapons/%s.tscn" % id) as PackedScene).instantiate() as Weapon
	stand.add_child(weapon)
	weapon.readiness = 1.0
	weapon._pose()
	weapon.set_process(false)
	weapon.set_physics_process(false)
	displayed_id = id
	# Combine visible model geometry in the weapon's coordinates; hide ephemeral
	# flashes and particles and frame the real model, not hard-coded dimensions.
	var bounds := AABB()
	var first := true
	for node: Node in weapon.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var part: AABB = (weapon.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = part if first else bounds.merge(part)
		first = false
	var center: Vector3 = bounds.get_center()
	var extent: float = maxf(bounds.size.length(), 1.0)
	camera.position = center + Vector3(1.35, 0.95, 1.6).normalized() * extent * 2.5
	camera.look_at(center, Vector3.UP)
	camera.size = extent * 1.15
	camera.far = extent * 10.0 + 20.0
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
