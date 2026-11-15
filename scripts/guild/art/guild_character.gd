class_name GuildCharacter
extends Node3D
## A procedural, modular anime-proportioned character built from primitives.
##
## No imported model is needed: the body is boxes, capsules and spheres with a
## matte cel material and an inverted-hull ink outline, arranged on pivots so the
## same rig can walk, carry, pick up and deposit. Every style (the guild master
## and the five customer classes) is palette-driven, so a new class is a new entry
## in `STYLES` rather than a new model.
##
## The rig exposes named parts (`parts`), hand pivots and two anchors: `stack_anchor`
## where carried goods are stacked and `money_anchor` where coins pile up. Replacing
## this with a licensed glTF later means implementing the same three accessors.

const STYLES := {
	"guildmaster": {
		"coat": Color(0.23, 0.27, 0.6),
		"trim": Color(0.94, 0.78, 0.4),
		"pants": Color(0.15, 0.16, 0.26),
		"skin": Color(0.96, 0.82, 0.72),
		"hair": Color(0.12, 0.11, 0.17),
		"accent": Color(0.33, 0.86, 0.87),
		"cape": true,
		"hood": false,
		"weapon": "none",
	},
	"warrior": {
		"coat": Color(0.5, 0.2, 0.24),
		"trim": Color(0.85, 0.63, 0.32),
		"pants": Color(0.22, 0.2, 0.24),
		"skin": Color(0.9, 0.74, 0.62),
		"hair": Color(0.28, 0.17, 0.12),
		"accent": Color(0.95, 0.72, 0.35),
		"cape": false,
		"hood": false,
		"weapon": "sword",
	},
	"mage": {
		"coat": Color(0.27, 0.21, 0.5),
		"trim": Color(0.48, 0.84, 0.9),
		"pants": Color(0.18, 0.17, 0.3),
		"skin": Color(0.93, 0.8, 0.74),
		"hair": Color(0.72, 0.76, 0.85),
		"accent": Color(0.42, 0.9, 0.95),
		"cape": true,
		"hood": true,
		"weapon": "staff",
	},
	"archer": {
		"coat": Color(0.18, 0.38, 0.3),
		"trim": Color(0.78, 0.68, 0.42),
		"pants": Color(0.16, 0.23, 0.2),
		"skin": Color(0.87, 0.72, 0.58),
		"hair": Color(0.42, 0.26, 0.15),
		"accent": Color(0.6, 0.9, 0.55),
		"cape": false,
		"hood": true,
		"weapon": "bow",
	},
	"rogue": {
		"coat": Color(0.17, 0.17, 0.23),
		"trim": Color(0.62, 0.32, 0.78),
		"pants": Color(0.12, 0.12, 0.16),
		"skin": Color(0.82, 0.66, 0.56),
		"hair": Color(0.1, 0.1, 0.14),
		"accent": Color(0.76, 0.42, 0.92),
		"cape": false,
		"hood": true,
		"weapon": "dagger",
	},
	"knight": {
		"coat": Color(0.52, 0.56, 0.66),
		"trim": Color(0.9, 0.78, 0.42),
		"pants": Color(0.34, 0.37, 0.45),
		"skin": Color(0.9, 0.78, 0.68),
		"hair": Color(0.3, 0.3, 0.34),
		"accent": Color(0.95, 0.85, 0.5),
		"cape": true,
		"hood": false,
		"weapon": "shield",
	},
}

const POSES: Array[String] = ["idle", "walk", "run", "pickup", "carry", "receive", "deliver", "deposit"]

var style_id := "guildmaster"
var palette: Dictionary = {}
var parts: Dictionary = {}
var current_pose := "idle"
var _phase := 0.0
var _outlined := true
var _body: Node3D


func _init(style: String = "guildmaster", outlined: bool = true) -> void:
	style_id = style if STYLES.has(style) else "guildmaster"
	palette = STYLES[style_id]
	_outlined = outlined
	name = "GuildCharacter_" + style_id
	_build()


## The pivot that carried goods are stacked on.
func stack_anchor() -> Node3D:
	return parts.get("stack_anchor", null) as Node3D


## The pivot where earned coins pile up.
func money_anchor() -> Node3D:
	return parts.get("money_anchor", null) as Node3D


func part(part_name: String) -> Node3D:
	return parts.get(part_name, null) as Node3D


## One frame of procedural animation. `move_speed` is metres per second, so the
## walk cycle slows down when the player walks and speeds up when they run.
func animate(delta: float, move_speed: float = 0.0, pose: String = "idle") -> void:
	current_pose = pose if POSES.has(pose) else "idle"
	var stride := maxf(move_speed, 0.0)
	_phase = fmod(_phase + delta * stride * 2.1, TAU)

	var swing := 0.0
	if stride > 0.05:
		swing = walk_swing(_phase, clampf(stride / 4.2, 0.25, 1.0) * 0.62)

	var arm_x := -0.06 + sin(_phase * 1.0) * 0.03
	var fore_x := -0.12
	var lean := 0.0
	match current_pose:
		"walk":
			arm_x = -swing
			fore_x = -0.2 - absf(swing) * 0.2
		"run":
			lean = 0.16
			fore_x = -0.55
		"pickup":
			lean = 0.5
			arm_x = -1.15
			fore_x = -0.3
		"carry", "deliver", "deposit":
			lean = 0.04
			arm_x = -1.32
			fore_x = -0.52
			if current_pose == "deposit":
				arm_x = -1.48
				fore_x = -0.36
		_:
			pass

	_rotate("leg_l", swing)
	_rotate("leg_r", -swing)
	_rotate("arm_l", -arm_x)
	_rotate("arm_r", arm_x)
	_rotate("fore_l", fore_x)
	_rotate("fore_r", fore_x)

	var torso := part("torso")
	if torso != null:
		torso.rotation.x = lerpf(torso.rotation.x, lean, minf(1.0, delta * 10.0))
	if _body != null:
		var bob := 0.0
		if stride > 0.05:
			bob = absf(sin(_phase)) * 0.022
		_body.position.y = lerpf(_body.position.y, bob, minf(1.0, delta * 12.0))


## The shared stride curve, exposed so tests can pin the shape of the cycle.
static func walk_swing(phase: float, amplitude: float = 0.6) -> float:
	return sin(phase) * amplitude


func _rotate(part_name: String, angle: float) -> void:
	var node := part(part_name)
	if node != null:
		node.rotation.x = angle


# --- construction ----------------------------------------------------------

func _build() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var coat: Color = palette["coat"]
	var trim: Color = palette["trim"]
	var pants: Color = palette["pants"]
	var skin: Color = palette["skin"]
	var hair: Color = palette["hair"]
	var accent: Color = palette["accent"]

	_build_legs(pants, trim)
	_build_torso(coat, trim, accent)
	_build_arms(coat, skin, trim)
	_build_head(skin, hair, accent)
	if bool(palette["cape"]):
		_build_cape(coat)
	_build_weapon(str(palette["weapon"]), trim, accent)

	var stack_anchor := Node3D.new()
	stack_anchor.name = "stack_anchor"
	stack_anchor.position = Vector3(0.0, 1.16, 0.36)
	_body.add_child(stack_anchor)
	parts["stack_anchor"] = stack_anchor

	var money_anchor := Node3D.new()
	money_anchor.name = "money_anchor"
	money_anchor.position = Vector3(0.16, 1.02, 0.4)
	_body.add_child(money_anchor)
	parts["money_anchor"] = money_anchor


func _build_legs(pants: Color, boots: Color) -> void:
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "Leg" + ("L" if side < 0.0 else "R")
		pivot.position = Vector3(0.105 * side, 0.9, 0.0)
		_body.add_child(pivot)
		_part(pivot, _box(Vector3(0.145, 0.44, 0.16)), pants, Vector3(0.0, -0.21, 0.0))
		_part(pivot, _box(Vector3(0.12, 0.4, 0.14)), pants, Vector3(0.0, -0.62, 0.0))
		_part(pivot, _box(Vector3(0.15, 0.11, 0.26)), boots, Vector3(0.0, -0.85, 0.04))
		parts["leg_l" if side < 0.0 else "leg_r"] = pivot


func _build_torso(coat: Color, trim: Color, accent: Color) -> void:
	var torso := Node3D.new()
	torso.name = "torso"
	torso.position = Vector3(0.0, 0.98, 0.0)
	_body.add_child(torso)
	parts["torso"] = torso

	_part(torso, _box(Vector3(0.34, 0.18, 0.22)), coat.darkened(0.12), Vector3(0.0, 0.02, 0.0))
	_part(torso, _capsule(0.185, 0.6), coat, Vector3(0.0, 0.3, 0.0))
	_part(torso, _box(Vector3(0.4, 0.36, 0.3)), coat.darkened(0.06), Vector3(0.0, -0.1, 0.0))
	_part(torso, _box(Vector3(0.37, 0.07, 0.25)), trim, Vector3(0.0, 0.02, 0.0))
	_part(torso, _box(Vector3(0.1, 0.42, 0.26)), trim, Vector3(0.0, 0.33, 0.0))
	_part(torso, _sphere(0.055, 0.06), accent, Vector3(0.0, 0.36, 0.14))
	for side in [-1.0, 1.0]:
		_part(torso, _sphere(0.095, 0.11), coat.lightened(0.08), Vector3(0.235 * side, 0.5, 0.0))


func _build_arms(coat: Color, skin: Color, trim: Color) -> void:
	for side in [-1.0, 1.0]:
		var side_name := "l" if side < 0.0 else "r"
		var arm := Node3D.new()
		arm.name = "Arm" + ("L" if side < 0.0 else "R")
		arm.position = Vector3(0.245 * side, 1.46, 0.0)
		_body.add_child(arm)
		_part(arm, _box(Vector3(0.105, 0.32, 0.115)), coat, Vector3(0.0, -0.16, 0.0))

		var fore := Node3D.new()
		fore.name = "Fore" + ("L" if side < 0.0 else "R")
		fore.position = Vector3(0.0, -0.32, 0.0)
		arm.add_child(fore)
		_part(fore, _box(Vector3(0.095, 0.3, 0.1)), coat.darkened(0.1), Vector3(0.0, -0.15, 0.0))

		var hand := Node3D.new()
		hand.name = "Hand" + ("L" if side < 0.0 else "R")
		hand.position = Vector3(0.0, -0.32, 0.0)
		fore.add_child(hand)
		_part(hand, _sphere(0.062, 0.09), skin, Vector3.ZERO)
		_part(hand, _box(Vector3(0.1, 0.05, 0.11)), trim, Vector3(0.0, 0.04, 0.0))

		parts["arm_" + side_name] = arm
		parts["fore_" + side_name] = fore
		parts["hand_" + side_name] = hand


func _build_head(skin: Color, hair: Color, accent: Color) -> void:
	_part(_body, _cylinder(0.052, 0.06, 0.1), skin, Vector3(0.0, 1.575, 0.0))
	var head := _part(_body, _sphere(0.155, 0.33), skin, Vector3(0.0, 1.74, 0.01), "head")
	head.scale = Vector3(1.0, 1.0, 0.94)

	var cap := _part(_body, _hemisphere(0.168, 0.19), hair, Vector3(0.0, 1.78, 0.005))
	cap.scale = Vector3(1.02, 1.0, 1.04)
	_part(_body, _box(Vector3(0.3, 0.075, 0.1)), hair, Vector3(0.0, 1.85, 0.115))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.055, 0.24, 0.08)), hair, Vector3(0.15 * side, 1.72, -0.01))

	for side in [-1.0, 1.0]:
		var eye := _part(_body, _box(Vector3(0.045, 0.075, 0.02)), accent, Vector3(0.062 * side, 1.73, 0.148))
		eye.material_override = GuildMaterials.glow(accent, 1.1)

	if bool(palette["hood"]):
		var hood := _part(_body, _sphere(0.2, 0.32), palette["coat"], Vector3(0.0, 1.79, -0.02), "hood")
		hood.scale = Vector3(1.0, 0.95, 1.02)
		hood.rotation.x = -0.12


func _build_cape(coat: Color) -> void:
	var cape := _part(_body, _box(Vector3(0.42, 0.78, 0.035)), coat.darkened(0.22), Vector3(0.0, 1.2, -0.17))
	cape.rotation.x = -0.07
	parts["cape"] = cape


func _build_weapon(kind: String, trim: Color, accent: Color) -> void:
	if kind == "none":
		return
	var hand := part("hand_r")
	if hand == null:
		return
	var weapon := Node3D.new()
	weapon.name = "Weapon"
	hand.add_child(weapon)
	match kind:
		"sword":
			_part(weapon, _box(Vector3(0.05, 0.78, 0.022)), Color(0.82, 0.86, 0.92), Vector3(0.0, 0.34, 0.02))
			_part(weapon, _box(Vector3(0.2, 0.05, 0.06)), trim, Vector3(0.0, -0.05, 0.02))
		"staff":
			_part(weapon, _cylinder(0.022, 0.026, 1.5), Color(0.32, 0.24, 0.2), Vector3(0.0, 0.42, 0.03))
			var gem := _part(weapon, _sphere(0.075, 0.15), accent, Vector3(0.0, 1.2, 0.03))
			gem.material_override = GuildMaterials.glow(accent, 1.8)
		"bow":
			_part(weapon, _torus(0.24, 0.275), Color(0.4, 0.29, 0.18), Vector3(0.0, 0.05, 0.05))
			_part(weapon, _box(Vector3(0.008, 0.5, 0.008)), Color(0.85, 0.85, 0.8), Vector3(0.0, 0.05, 0.26))
		"dagger":
			_part(weapon, _box(Vector3(0.04, 0.34, 0.018)), Color(0.78, 0.8, 0.86), Vector3(0.0, 0.14, 0.02))
			_part(weapon, _box(Vector3(0.12, 0.04, 0.05)), palette["trim"], Vector3(0.0, -0.04, 0.02))
		"shield":
			_part(weapon, _box(Vector3(0.36, 0.44, 0.05)), Color(0.44, 0.48, 0.58), Vector3(0.06, 0.02, 0.06))
			_part(weapon, _box(Vector3(0.3, 0.06, 0.06)), trim, Vector3(0.06, 0.12, 0.065))
		_:
			pass
	parts["weapon"] = weapon


# --- primitives and helpers ------------------------------------------------

func _part(parent: Node3D, mesh: Mesh, color: Color, position: Vector3, key: String = "") -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = GuildMaterials.flat(color)
	instance.position = position
	if _outlined:
		var ink := MeshInstance3D.new()
		ink.name = "Ink"
		ink.mesh = mesh
		ink.material_override = GuildMaterials.outline()
		ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.add_child(ink)
	parent.add_child(instance)
	if not key.is_empty():
		parts[key] = instance
	return instance


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


func _hemisphere(radius: float, height: float) -> SphereMesh:
	var mesh := _sphere(radius, height)
	mesh.is_hemisphere = true
	return mesh


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return mesh


func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	return mesh
