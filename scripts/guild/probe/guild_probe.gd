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
const FLOOR_COLOR := Color(0.16, 0.17, 0.26)
const STONE := Color(0.32, 0.33, 0.44)
const WOOD := Color(0.3, 0.22, 0.18)
const GOLD := Color(0.9, 0.74, 0.36)
const RUG := Color(0.24, 0.16, 0.4)

var hero: GuildPlayer
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


## The pose this probe holds; the smoke run calls it before each capture.
func set_demo_pose(pose: String, carry: int = 0) -> void:
	_pose = pose
	_speed = 2.4 if pose in ["walk", "run"] else 0.0
	hero.state.carry = carry
	if carry_stack_kind() == "money":
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


func carry_stack_kind() -> String:
	return hero.carry_stack.kind


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
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.4, 0.62)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var key := DirectionalLight3D.new()
	key.name = "Key"
	key.rotation_degrees = Vector3(-46.0, 28.0, 0.0)
	key.light_color = Color(1.0, 0.95, 0.86)
	key.light_energy = 1.25
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 34.0
	add_child(key)

	var rim := OmniLight3D.new()
	rim.name = "Rim"
	rim.position = Vector3(-2.5, 3.2, -4.0)
	rim.light_color = Color(0.45, 0.72, 1.0)
	rim.light_energy = 6.0
	rim.omni_range = 14.0
	add_child(rim)

	var warm := OmniLight3D.new()
	warm.name = "Warm"
	warm.position = Vector3(3.4, 2.4, 3.2)
	warm.light_color = Color(1.0, 0.72, 0.42)
	warm.light_energy = 4.0
	warm.omni_range = 10.0
	add_child(warm)

	set_meta("environment", env)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.material_override = GuildMaterials.floor(FLOOR_COLOR)
	add_child(floor_mesh)

	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var rug_mesh := BoxMesh.new()
	rug_mesh.size = Vector3(7.4, 0.03, 4.4)
	rug.mesh = rug_mesh
	rug.material_override = GuildMaterials.flat(RUG)
	rug.position = Vector3(0.0, 0.015, 0.4)
	add_child(rug)

	for index in 5:
		var line := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(0.06, 0.04, 4.4)
		line.mesh = strip
		line.material_override = GuildMaterials.flat(GOLD.darkened(0.3))
		line.position = Vector3(-3.2 + index * 1.6, 0.035, 0.4)
		add_child(line)


func _build_props() -> void:
	for side in [-1.0, 1.0]:
		var pillar := Node3D.new()
		pillar.name = "Pillar"
		pillar.position = Vector3(4.4 * side, 0.0, -3.6)
		add_child(pillar)
		var shaft := MeshInstance3D.new()
		var shaft_mesh := CylinderMesh.new()
		shaft_mesh.top_radius = 0.3
		shaft_mesh.bottom_radius = 0.34
		shaft_mesh.height = 4.4
		shaft.mesh = shaft_mesh
		shaft.material_override = GuildMaterials.flat(STONE)
		shaft.position = Vector3(0.0, 2.2, 0.0)
		pillar.add_child(shaft)
		var capital := MeshInstance3D.new()
		var capital_mesh := BoxMesh.new()
		capital_mesh.size = Vector3(0.9, 0.22, 0.9)
		capital.mesh = capital_mesh
		capital.material_override = GuildMaterials.flat(STONE.lightened(0.1))
		capital.position = Vector3(0.0, 4.5, 0.0)
		pillar.add_child(capital)

	var counter := Node3D.new()
	counter.name = "Counter"
	counter.position = Vector3(-4.2, 0.0, 2.2)
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

	var banner := MeshInstance3D.new()
	banner.name = "Banner"
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(1.6, 2.6, 0.06)
	banner.mesh = banner_mesh
	banner.material_override = GuildMaterials.flat(Color(0.18, 0.2, 0.46))
	banner.position = Vector3(0.0, 3.1, -4.1)
	add_child(banner)


func _build_cast() -> void:
	hero = GuildPlayer.new()
	hero.set_physics_process(false)
	hero.position = Vector3(0.0, 0.0, 2.1)
	add_child(hero)

	for index in CAST.size():
		var style := CAST[index]
		var member := GuildCharacter.new(style, true)
		member.name = "Cast_" + style
		member.position = Vector3(-3.0 + index * 1.5, 0.0, -0.7)
		member.rotation.y = deg_to_rad(8.0 - index * 4.0)
		add_child(member)
		cast.append(member)
		member.animate(0.016, 0.0, "idle")


func _build_camera() -> void:
	camera_rig = GuildPlayerCamera.new()
	camera_rig.name = "CameraRig"
	camera_rig.yaw = 18.0
	camera_rig.pitch = 34.0
	camera_rig.distance = 11.5
	add_child(camera_rig)
	camera_rig.focus_on(Vector3(0.0, 1.1, 0.9))
	var env: Environment = get_meta("environment") as Environment
	if camera_rig.camera != null and env != null:
		camera_rig.camera.environment = env
		camera_rig.camera.current = true
