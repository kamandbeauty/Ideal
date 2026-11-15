class_name GuildProbe
extends Node3D
## A small, honest visual test of the Phase 2 art and rig: the guild manager
## carrying goods, the five customer classes, the follow camera and the cel
## materials, on a lit floor. It is what CI photographs, so the look is never
## assumed - if the outlines, the palette or the proportions break, the capture
## shows it.
##
## This is a probe, not the guild hall: the hall itself (nine named zones,
## navigation, spawn points) is Phase 2's next slice.

const CAST: Array[String] = ["warrior", "mage", "archer", "rogue", "knight"]
const FLOOR_COLOR := Color(0.11, 0.12, 0.19)
const STONE := Color(0.34, 0.35, 0.47)
const WOOD := Color(0.31, 0.22, 0.17)
const GOLD := Color(0.92, 0.76, 0.38)
const RUG := Color(0.21, 0.15, 0.36)

var hero: GuildPlayer
var control_rig: GuildCharacter
var camera_rig: GuildPlayerCamera
var cast: Array[GuildCharacter] = []

var follow_hero := false
var _pose := "idle"
var _speed := 0.0


func _ready() -> void:
	_build_lighting()
	_build_floor()
	_build_props()
	_build_cast()
	_build_camera()
	print("SMOKE: probe ready, " + describe())


## The pose this probe holds; the smoke run calls it before each capture.
func set_demo_pose(pose: String, carry: int = 0) -> void:
	_pose = pose
	_speed = 2.4 if pose in ["walk", "run"] else 0.0
	hero.state.carry = carry
	if hero.carry_stack.kind == "money":
		hero.carry_stack.show_money(hero.state.money)
	else:
		hero.carry_stack.show_items(carry)
	_animate_hero(0.5)


## Coins in the hands, for the deposit beat.
func set_demo_money(amount: float, pose: String = "deposit") -> void:
	_pose = pose
	_speed = 0.0
	hero.state.money = amount
	hero.carry_stack.show_money(amount)
	_animate_hero(0.5)


## Tight, slightly low shot of the guild master: the carrying loop's money shot.
func focus_hero() -> void:
	if camera_rig == null:
		return
	camera_rig.distance = GuildPlayerCamera.MIN_DISTANCE
	camera_rig.pitch = 30.0
	camera_rig.yaw = 14.0
	camera_rig.focus_on(Vector3(hero.position.x, 1.08, hero.position.z))


## A one-line health check of the rig, mirrored into the CI log.
func describe() -> String:
	var meshes := hero.character.find_children("*", "MeshInstance3D", true, false)
	var shown := 0
	for mesh in meshes:
		if (mesh as MeshInstance3D).is_visible_in_tree():
			shown += 1
	return "hero_parts=%d hero_meshes=%d hero_visible=%d hero_pos=%s cast=%d stack=%d control=%d" % [
		hero.character.parts.size(),
		meshes.size(),
		shown,
		str(hero.global_position),
		cast.size(),
		hero.carry_stack.visible_count(),
		control_rig.find_children("*", "MeshInstance3D", true, false).size(),
	]


## A full dump of the player rig, written next to the captures so a missing mesh
## can be diagnosed from the repo instead of guessed at.
func hero_report() -> String:
	var lines: Array[String] = []
	lines.append("hero in_tree=%s visible=%s pos=%s rot_y=%.3f children=%d" % [
		str(hero.is_inside_tree()),
		str(hero.visible),
		str(hero.global_position),
		hero.rotation.y,
		hero.get_child_count(),
	])
	if hero.character == null:
		lines.append("hero.character is NULL")
		return "\n".join(lines)
	lines.append("rig parts=%d body_children=%d" % [
		hero.character.parts.size(),
		hero.character.get_child_count(),
	])
	for part_name in hero.character.parts:
		var node := hero.character.parts[part_name] as Node3D
		if node == null:
			lines.append("  part %s: not a Node3D" % str(part_name))
			continue
		lines.append("  part %s visible=%s meshes=%d global=%s" % [
			str(part_name),
			str(node.visible),
			node.find_children("*", "MeshInstance3D", true, false).size(),
			str(node.global_position),
		])
	lines.append("stack kind=%s total=%d visible=%d global=%s" % [
		hero.carry_stack.kind,
		hero.carry_stack.total,
		hero.carry_stack.visible_count(),
		str(hero.carry_stack.global_position),
	])
	return "\n".join(lines)


func _process(delta: float) -> void:
	_animate_hero(delta)
	if follow_hero and camera_rig != null:
		camera_rig.follow_feet(hero.global_position, delta)


func _animate_hero(delta: float) -> void:
	if hero == null:
		return
	hero.character.animate(delta, _speed, _pose)


# --- construction ----------------------------------------------------------

func _build_lighting() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.06, 0.07, 0.16)
	sky_material.sky_horizon_color = Color(0.24, 0.2, 0.38)
	sky_material.ground_bottom_color = Color(0.05, 0.05, 0.09)
	sky_material.ground_horizon_color = Color(0.18, 0.15, 0.3)
	sky_material.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.2, 0.36)
	env.fog_density = 0.012
	env.glow_enabled = true
	env.glow_intensity = 0.4

	var key := DirectionalLight3D.new()
	key.name = "Key"
	key.rotation_degrees = Vector3(-42.0, 34.0, 0.0)
	key.light_color = Color(1.0, 0.94, 0.84)
	key.light_energy = 1.7
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 30.0
	add_child(key)

	var rim := OmniLight3D.new()
	rim.name = "Rim"
	rim.position = Vector3(-3.0, 3.4, -3.6)
	rim.light_color = Color(0.45, 0.75, 1.0)
	rim.light_energy = 9.0
	rim.omni_range = 16.0
	add_child(rim)

	var warm := OmniLight3D.new()
	warm.name = "Warm"
	warm.position = Vector3(3.6, 2.6, 2.8)
	warm.light_color = Color(1.0, 0.74, 0.44)
	warm.light_energy = 7.0
	warm.omni_range = 12.0
	add_child(warm)

	set_meta("environment", env)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(44.0, 44.0)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.material_override = GuildMaterials.floor(FLOOR_COLOR)
	add_child(floor_mesh)

	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var rug_mesh := BoxMesh.new()
	rug_mesh.size = Vector3(6.6, 0.04, 4.2)
	rug.mesh = rug_mesh
	rug.material_override = GuildMaterials.flat(RUG)
	rug.position = Vector3(0.0, 0.02, 0.2)
	add_child(rug)

	# A thin gold border instead of a grid: it frames the cast without looking
	# like a car park.
	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(6.2, 0.05, 0.09)
		edge.mesh = edge_mesh
		edge.material_override = GuildMaterials.metal(GOLD.darkened(0.15))
		edge.position = Vector3(0.0, 0.045, 0.2 + 1.95 * side)
		add_child(edge)
		var side_edge := MeshInstance3D.new()
		var side_mesh := BoxMesh.new()
		side_mesh.size = Vector3(0.09, 0.05, 3.9)
		side_edge.mesh = side_mesh
		side_edge.material_override = GuildMaterials.metal(GOLD.darkened(0.15))
		side_edge.position = Vector3(3.05 * side, 0.045, 0.2)
		add_child(side_edge)


func _build_props() -> void:
	for side in [-1.0, 1.0]:
		var pillar := Node3D.new()
		pillar.name = "Pillar"
		pillar.position = Vector3(4.6 * side, 0.0, -3.4)
		add_child(pillar)
		var shaft := MeshInstance3D.new()
		var shaft_mesh := CylinderMesh.new()
		shaft_mesh.top_radius = 0.3
		shaft_mesh.bottom_radius = 0.34
		shaft_mesh.height = 4.6
		shaft.mesh = shaft_mesh
		shaft.material_override = GuildMaterials.flat(STONE)
		shaft.position = Vector3(0.0, 2.3, 0.0)
		pillar.add_child(shaft)
		var capital := MeshInstance3D.new()
		var capital_mesh := BoxMesh.new()
		capital_mesh.size = Vector3(0.94, 0.22, 0.94)
		capital.mesh = capital_mesh
		capital.material_override = GuildMaterials.flat(STONE.lightened(0.12))
		capital.position = Vector3(0.0, 4.7, 0.0)
		pillar.add_child(capital)
		var lantern := MeshInstance3D.new()
		var lantern_mesh := SphereMesh.new()
		lantern_mesh.radius = 0.16
		lantern_mesh.height = 0.34
		lantern.mesh = lantern_mesh
		lantern.material_override = GuildMaterials.glow(Color(1.0, 0.78, 0.42), 2.4)
		lantern.position = Vector3(0.0, 3.6, 0.34 * side)
		pillar.add_child(lantern)

	var counter := Node3D.new()
	counter.name = "Counter"
	counter.position = Vector3(-4.3, 0.0, 2.0)
	add_child(counter)
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(2.4, 0.14, 0.9)
	top.mesh = top_mesh
	top.material_override = GuildMaterials.flat(WOOD)
	top.position = Vector3(0.0, 1.0, 0.0)
	counter.add_child(top)
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.14, 1.0, 0.7)
		leg.mesh = leg_mesh
		leg.material_override = GuildMaterials.flat(WOOD.darkened(0.2))
		leg.position = Vector3(0.9 * side, 0.5, 0.0)
		counter.add_child(leg)
	for index in 3:
		var parcel := MeshInstance3D.new()
		var parcel_mesh := BoxMesh.new()
		parcel_mesh.size = Vector3(0.2, 0.1, 0.16)
		parcel.mesh = parcel_mesh
		parcel.material_override = GuildMaterials.flat(Color(0.58, 0.36, 0.72).darkened(0.06 * index))
		parcel.position = Vector3(-0.4 + index * 0.28, 1.12, 0.1)
		counter.add_child(parcel)

	var banner := MeshInstance3D.new()
	banner.name = "Banner"
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(1.7, 2.8, 0.06)
	banner.mesh = banner_mesh
	banner.material_override = GuildMaterials.flat(Color(0.2, 0.22, 0.5))
	banner.position = Vector3(0.0, 3.2, -3.9)
	add_child(banner)
	var emblem := MeshInstance3D.new()
	var emblem_mesh := SphereMesh.new()
	emblem_mesh.radius = 0.3
	emblem_mesh.height = 0.6
	emblem.mesh = emblem_mesh
	emblem.material_override = GuildMaterials.metal(GOLD)
	emblem.position = Vector3(0.0, 3.4, -3.82)
	emblem.scale = Vector3(1.0, 1.0, 0.4)
	add_child(emblem)


func _build_cast() -> void:
	hero = GuildPlayer.new()
	hero.set_physics_process(false)
	hero.position = Vector3(1.9, 0.0, 1.5)
	hero.rotation.y = deg_to_rad(-14.0)
	add_child(hero)

	for index in CAST.size():
		var style := CAST[index]
		var member := GuildCharacter.new(style, true)
		member.name = "Cast_" + style
		member.position = Vector3(-2.9 + index * 1.45, 0.0, -0.9)
		member.rotation.y = deg_to_rad(-10.0 + index * 4.0)
		add_child(member)
		cast.append(member)
		member.animate(0.016, 0.0, "idle")

	# A plain rig next to the player controller: if one of the two disappears from
	# the capture, the CI log says which one, instead of the art being blamed.
	control_rig = GuildCharacter.new("guildmaster", true)
	control_rig.name = "ControlGuildMaster"
	control_rig.position = Vector3(-1.7, 0.0, 1.6)
	control_rig.rotation.y = deg_to_rad(16.0)
	add_child(control_rig)
	print("SMOKE: hero node children=%d, rig parts=%d" % [hero.get_child_count(), hero.character.parts.size()])


func _build_camera() -> void:
	camera_rig = GuildPlayerCamera.new()
	camera_rig.name = "CameraRig"
	camera_rig.yaw = 20.0
	camera_rig.pitch = 33.0
	camera_rig.distance = 10.4
	add_child(camera_rig)
	camera_rig.focus_on(Vector3(0.35, 1.15, 0.45))
	var env: Environment = get_meta("environment") as Environment
	if camera_rig.camera != null and env != null:
		camera_rig.camera.environment = env
		camera_rig.camera.current = true
