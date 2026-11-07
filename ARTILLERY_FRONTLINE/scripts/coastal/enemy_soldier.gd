class_name EnemySoldier
extends CharacterBody3D
## Animated infantry for the coastal defense milestone. Not a static prop.
signal died(soldier: EnemySoldier)
signal damaged(soldier: EnemySoldier, ratio: float)
signal shoot_requested(soldier: EnemySoldier, target: Vector3)

enum State { ADVANCE, COVER, STAGGER, DEAD }
var state: State = State.ADVANCE
var health: float = 100.0
var max_health: float = 100.0
var speed: float = 4.4
var objective: Vector3 = Vector3.ZERO
var cover_point: Vector3 = Vector3.ZERO
var stagger_time: float = 0.0
var clock: float = 0.0
var shoot_cooldown: float = 0.0
var model_root: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var torso: Node3D
var knee_l: Node3D
var knee_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var head_node: Node3D
var rifle_node: Node3D
var rifle_rest: Vector3 = Vector3.ZERO
var arm_l_rest: Vector3 = Vector3.ZERO
var arm_r_rest: Vector3 = Vector3.ZERO
var fire_kick: float = 0.0
var muzzle_flash: MeshInstance3D
var muzzle_light: OmniLight3D
var collision: CollisionShape3D
var player_position: Vector3 = Vector3.ZERO
var torso_rest_y: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("damageable")
	collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.75
	collision.shape = shape
	collision.position.y = 0.88
	add_child(collision)
	_build_model()
	shoot_cooldown = randf_range(1.0, 2.6)

func configure(spawn: Vector3, target: Vector3, cover: Vector3) -> void:
	global_position = spawn
	objective = target
	cover_point = cover
	player_position = target

func _build_model() -> void:
	var path: String = "res://assets/models/soldier.glb"
	if ResourceLoader.exists(path):
		model_root = load(path).instantiate()
		add_child(model_root)
		MaterialLibrary.apply_to_model(model_root)
		leg_l = model_root.find_child("LegL", true, false) as Node3D
		leg_r = model_root.find_child("LegR", true, false) as Node3D
		arm_l = model_root.find_child("ArmL", true, false) as Node3D
		arm_r = model_root.find_child("ArmR", true, false) as Node3D
		torso = model_root.find_child("Torso", true, false) as Node3D
		if torso:
			torso_rest_y = torso.position.y
		knee_l = model_root.find_child("KneeL", true, false) as Node3D
		knee_r = model_root.find_child("KneeR", true, false) as Node3D
		elbow_l = model_root.find_child("ElbowL", true, false) as Node3D
		elbow_r = model_root.find_child("ElbowR", true, false) as Node3D
		head_node = model_root.find_child("Head", true, false) as Node3D
		rifle_node = model_root.find_child("Rifle", true, false) as Node3D
		if rifle_node:
			rifle_rest = rifle_node.position
		if arm_l:
			arm_l_rest = arm_l.rotation
		if arm_r:
			arm_r_rest = arm_r.rotation
		_build_muzzle_flash()
	if model_root == null:
		model_root = Node3D.new()
		add_child(model_root)
		var uniform: Color = Color(0.42, 0.46, 0.34)
		MeshFactory.box(model_root, "Torso", Vector3(0, 1.12, 0), Vector3(0.46, 0.62, 0.28), uniform, true, "fabric")
		MeshFactory.sphere(model_root, "Head", Vector3(0, 1.62, 0), Vector3(0.16, 0.19, 0.17), Color(0.62, 0.47, 0.36))
		MeshFactory.sphere(model_root, "Helmet", Vector3(0, 1.7, 0), Vector3(0.19, 0.12, 0.2), uniform.darkened(0.2), "paint_olive")
		leg_l = _fallback_limb("LegL", Vector3(-0.13, 0.82, 0), Vector3(0.15, 0.8, 0.17), uniform.darkened(0.15))
		leg_r = _fallback_limb("LegR", Vector3(0.13, 0.82, 0), Vector3(0.15, 0.8, 0.17), uniform.darkened(0.15))
		arm_l = _fallback_limb("ArmL", Vector3(-0.31, 1.38, 0), Vector3(0.12, 0.58, 0.14), uniform)
		arm_r = _fallback_limb("ArmR", Vector3(0.31, 1.38, 0), Vector3(0.12, 0.58, 0.14), uniform)
		MeshFactory.box(model_root, "Rifle", Vector3(0.18, 1.18, -0.28), Vector3(0.07, 0.09, 0.8), Color(0.12, 0.12, 0.1), true, "steel")

func _build_muzzle_flash() -> void:
	if model_root == null:
		return
	var muzzle: Node3D = model_root.find_child("Muzzle", true, false) as Node3D
	if muzzle == null:
		return
	muzzle_flash = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	muzzle_flash.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.78, 0.35, 0.9)
	var flash_texture: Texture2D = MaterialLibrary.texture("muzzle_flash.png")
	if flash_texture:
		material.albedo_texture = flash_texture
	muzzle_flash.material_override = material
	muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_flash.visible = false
	muzzle.add_child(muzzle_flash)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.62, 0.25)
	muzzle_light.omni_range = 4.0
	muzzle_light.light_energy = 0.0
	muzzle.add_child(muzzle_light)

func play_fire() -> void:
	fire_kick = 1.0
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash.rotation.z = randf_range(0.0, TAU)
	if muzzle_light:
		muzzle_light.light_energy = 2.0

func _fallback_limb(name: String, pivot: Vector3, size: Vector3, color: Color) -> Node3D:
	var limb := Node3D.new()
	limb.name = name
	limb.position = pivot
	model_root.add_child(limb)
	MeshFactory.box(limb, "Mesh", Vector3(0, -size.y * 0.5, 0), size, color, true, "fabric")
	return limb

func receive_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	health = maxf(0.0, health - amount)
	damaged.emit(self, health / max_health)
	if health <= 0.0:
		_die()
	else:
		stagger_time = maxf(stagger_time, 0.18)
		if state != State.COVER and health < max_health * 0.45:
			state = State.COVER

func react_to_explosion(point: Vector3, radius: float) -> void:
	if state == State.DEAD:
		return
	var distance: float = global_position.distance_to(point)
	if distance < radius * 1.8:
		stagger_time = maxf(stagger_time, 0.9)
		state = State.STAGGER
		if distance < radius * 0.75:
			receive_damage(65.0 * (1.0 - distance / (radius * 1.8)))

func is_dead() -> bool:
	return state == State.DEAD

func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	collision.set_deferred("disabled", true)
	set_physics_process(false)
	var tween: Tween = create_tween().set_parallel(True)
	tween.tween_property(model_root, "rotation:x", -0.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(model_root, "position:y", -0.62, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for knee in [knee_l, knee_r]:
		if knee:
			tween.tween_property(knee, "rotation:x", 1.15, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if torso:
		tween.tween_property(torso, "rotation:x", 0.55, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if head_node:
		tween.tween_property(head_node, "rotation:x", 0.4, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	died.emit(self)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	clock += delta
	shoot_cooldown -= delta
	if stagger_time > 0.0:
		stagger_time -= delta
		if stagger_time <= 0.0 and state == State.STAGGER:
			state = State.ADVANCE
		_animate(delta, 0.2)
		return
	var target: Vector3 = objective if state == State.ADVANCE else cover_point
	var offset: Vector3 = target - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	var wounded: float = 0.55 if health < max_health * 0.4 else 1.0
	if distance > (1.2 if state == State.COVER else 2.5):
		var direction: Vector3 = offset.normalized()
		global_position += direction * speed * wounded * delta
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 6.0)
		_animate(delta, speed * wounded)
	else:
		_animate(delta, 0.0)
	global_position.y = CoastalTerrain.height_at(global_position.x, global_position.z)
	if shoot_cooldown <= 0.0 and global_position.distance_to(player_position) < 150.0:
		shoot_cooldown = randf_range(1.6, 3.2)
		shoot_requested.emit(self, player_position)

func _animate(delta: float, move_speed: float) -> void:
	var amplitude: float = clampf(move_speed / 4.4, 0.0, 1.0)
	var phase: float = clock * (6.2 + move_speed * 0.9)
	var stride: float = sin(phase) * 0.58 * amplitude
	var bounce: float = absf(sin(phase)) * 0.03 * amplitude
	fire_kick = maxf(0.0, fire_kick - delta * 7.0)
	if muzzle_flash and fire_kick < 0.72:
		muzzle_flash.visible = false
	if muzzle_light:
		muzzle_light.light_energy = maxf(0.0, muzzle_light.light_energy - delta * 24.0)
	if leg_l:
		leg_l.rotation.x = stride
	if leg_r:
		leg_r.rotation.x = -stride
	if knee_l:
		knee_l.rotation.x = maxf(0.0, -sin(phase)) * 0.85 * amplitude + 0.06
	if knee_r:
		knee_r.rotation.x = maxf(0.0, sin(phase)) * 0.85 * amplitude + 0.06
	if arm_l:
		arm_l.rotation = arm_l_rest + Vector3(-0.08 * amplitude * sin(phase) - fire_kick * 0.10, 0.0, 0.02 * amplitude * cos(phase))
	if arm_r:
		arm_r.rotation = arm_r_rest + Vector3(0.08 * amplitude * sin(phase) - fire_kick * 0.14, 0.0, -0.02 * amplitude * cos(phase))
	if elbow_l:
		elbow_l.rotation.x = -0.55 - 0.08 * amplitude - fire_kick * 0.08
	if elbow_r:
		elbow_r.rotation.x = -0.55 - 0.08 * amplitude - fire_kick * 0.10
	if torso:
		torso.position.y = torso_rest_y + bounce
		torso.rotation.x = 0.06 * amplitude - fire_kick * 0.05
		torso.rotation.y = 0.04 * amplitude * sin(phase)
	if head_node:
		head_node.rotation.x = -0.04 * amplitude + fire_kick * 0.03
	if rifle_node:
		rifle_node.position = rifle_rest + Vector3(0.0, 0.0, bounce * 0.5 + fire_kick * 0.025)
		rifle_node.rotation.x = -0.12 - fire_kick * 0.06
