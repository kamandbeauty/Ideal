class_name EnemySoldier
extends CharacterBody3D
## Skinned infantry with anatomical gait, authored weapon grips and a physical
## constrained ragdoll death. The corpse keeps its final pose on the terrain.
signal died(soldier: EnemySoldier)
signal damaged(soldier: EnemySoldier, ratio: float)
signal shoot_requested(soldier: EnemySoldier, target: Vector3)

enum State { ADVANCE, COVER, STAGGER, DEAD }
var state: State = State.ADVANCE
## Infantry is soft-skinned: two heavy-MG rounds drop a rifleman, one head hit.
const BASE_HEALTH: float = 40.0
const HEADSHOT_MULTIPLIER: float = 2.2
const HEAD_HEIGHT: float = 1.45
var health: float = BASE_HEALTH
var max_health: float = BASE_HEALTH
var speed: float = 4.4
var objective: Vector3 = Vector3.ZERO
var cover_point: Vector3 = Vector3.ZERO
var stagger_time: float = 0.0
var clock: float = 0.0
var shoot_cooldown: float = 0.0
var model_root: Node3D
var skeleton: Skeleton3D
var ragdoll: PhysicalBoneSimulator3D
var death_time: float = 0.0
var ragdoll_settled: bool = false
var last_hit_point: Vector3 = Vector3.INF
var last_hit_direction: Vector3 = Vector3.BACK
var last_hit_damage: float = 0.0
var bone_indices: Dictionary = {}
var bone_rest: Dictionary = {}
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
var rifle_rest: Transform3D = Transform3D.IDENTITY
var arm_l_rest: Vector3 = Vector3.ZERO
var arm_r_rest: Vector3 = Vector3.ZERO
var elbow_l_rest: Vector3 = Vector3.ZERO
var elbow_r_rest: Vector3 = Vector3.ZERO
var fire_kick: float = 0.0
var muzzle_flash: MeshInstance3D
var muzzle_light: OmniLight3D
var collision: CollisionShape3D
var player_position: Vector3 = Vector3.ZERO
var torso_rest_y: float = 0.0
var gait_phase: float = 0.0
var aim_blend: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("damageable")
	collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.78
	collision.shape = shape
	collision.position.y = 0.89
	add_child(collision)
	_build_model()
	shoot_cooldown = randf_range(1.0, 2.6)
	gait_phase = randf() * TAU

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
		skeleton = _find_skeleton(model_root)
		if skeleton:
			for bone_name in SoldierRagdoll.BONES:
				var index: int = skeleton.find_bone(bone_name)
				if index >= 0:
					bone_indices[bone_name] = index
					bone_rest[bone_name] = skeleton.get_bone_rest(index)
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
			rifle_rest = rifle_node.transform
		if arm_l:
			arm_l_rest = arm_l.rotation
		if arm_r:
			arm_r_rest = arm_r.rotation
		if elbow_l:
			elbow_l_rest = elbow_l.rotation
		if elbow_r:
			elbow_r_rest = elbow_r.rotation
		_build_muzzle_flash()
	if model_root == null:
		_build_fallback_model()

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found:
			return found
	return null

func _build_fallback_model() -> void:
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
	torso = model_root.find_child("Torso", true, false) as Node3D
	head_node = model_root.find_child("Head", true, false) as Node3D
	MeshFactory.box(model_root, "Rifle", Vector3(0.18, 1.18, -0.28), Vector3(0.07, 0.09, 0.8), Color(0.12, 0.12, 0.1), true, "steel")
	rifle_node = model_root.find_child("Rifle", true, false) as Node3D
	if rifle_node:
		rifle_rest = rifle_node.transform

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
	if state == State.DEAD:
		return
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

func receive_damage(amount: float, hit_point: Vector3 = Vector3.INF, hit_direction: Vector3 = Vector3.ZERO) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	last_hit_damage = amount
	if hit_point != Vector3.INF:
		last_hit_point = hit_point
	if hit_direction.length_squared() > 0.0001:
		last_hit_direction = hit_direction.normalized()
	var scale: float = 1.0
	if hit_point != Vector3.INF and hit_point.y - global_position.y >= HEAD_HEIGHT:
		scale = HEADSHOT_MULTIPLIER
	health = maxf(0.0, health - amount * scale)
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
	var offset: Vector3 = global_position + Vector3.UP * 0.9 - point
	var distance: float = offset.length()
	if distance < radius * 1.8:
		stagger_time = maxf(stagger_time, 0.9)
		state = State.STAGGER
		last_hit_point = point
		last_hit_direction = offset.normalized() if distance > 0.01 else Vector3.UP
		if distance < radius * 0.75:
			receive_damage(65.0 * (1.0 - distance / (radius * 1.8)), point, last_hit_direction)

func is_dead() -> bool:
	return state == State.DEAD

func _die() -> void:
	state = State.DEAD
	death_time = 0.0
	ragdoll_settled = false
	collision_layer = 0
	collision.set_deferred("disabled", true)
	if muzzle_flash:
		muzzle_flash.visible = false
	if muzzle_light:
		muzzle_light.light_energy = 0.0
	var impulse: Vector3 = last_hit_direction * clampf(last_hit_damage * 1.6, 24.0, 95.0)
	impulse.y += 12.0
	var hit_point: Vector3 = last_hit_point if last_hit_point != Vector3.INF else global_position + Vector3.UP * 1.2
	if skeleton:
		ragdoll = SoldierRagdoll.build(skeleton)
		SoldierRagdoll.start(ragdoll, impulse, hit_point)
	else:
		_start_fallback_ragdoll(impulse, hit_point)
	died.emit(self)

var fallback_body: RigidBody3D

func _start_fallback_ragdoll(impulse: Vector3, hit_point: Vector3) -> void:
	# Missing-asset safety net: a physical body instead of the old sink tween.
	fallback_body = RigidBody3D.new()
	fallback_body.name = "FallbackCorpse"
	fallback_body.collision_layer = SoldierRagdoll.CORPSE_LAYER
	fallback_body.collision_mask = SoldierRagdoll.TERRAIN_MASK
	fallback_body.mass = 70.0
	fallback_body.friction = 0.9
	fallback_body.linear_damp = 0.4
	fallback_body.angular_damp = 0.8
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.7
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	collision_shape.position.y = 0.85
	fallback_body.add_child(collision_shape)
	var parent: Node = get_parent()
	parent.add_child(fallback_body)
	fallback_body.global_transform = global_transform
	model_root.reparent(fallback_body)
	fallback_body.apply_impulse(impulse, hit_point - fallback_body.global_position)
	fallback_body.apply_torque_impulse(Vector3(randf_range(-8, 8), randf_range(-4, 4), randf_range(-8, 8)))

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_tick_corpse(delta)
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
	var moving: bool = distance > (1.2 if state == State.COVER else 2.5)
	if moving:
		var direction: Vector3 = offset.normalized()
		global_position += direction * speed * wounded * delta
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 6.0)
		_animate(delta, speed * wounded)
	else:
		_animate(delta, 0.0)
	global_position.y = CoastalTerrain.height_at(global_position.x, global_position.z)
	var to_player: Vector3 = player_position - global_position
	aim_blend = lerpf(aim_blend, 1.0 if to_player.length() < 150.0 else 0.0, delta * 3.0)
	if shoot_cooldown <= 0.0 and to_player.length() < 150.0:
		shoot_cooldown = randf_range(1.6, 3.2)
		shoot_requested.emit(self, player_position)

func _tick_corpse(delta: float) -> void:
	death_time += delta
	if ragdoll_settled:
		return
	var settle_after: float = 4.0 if Graphics.tier == "low" else 7.0
	var asleep: bool = true
	if ragdoll:
		for child in ragdoll.get_children():
			var body: PhysicalBone3D = child as PhysicalBone3D
			if body and body.is_simulating_physics() and body.linear_velocity.length_squared() > 0.04:
				asleep = false
				break
	if death_time >= settle_after or (death_time > 1.5 and asleep):
		ragdoll_settled = true
		SoldierRagdoll.settle(ragdoll)
		if fallback_body:
			fallback_body.sleeping = true
			fallback_body.collision_layer = 0
			fallback_body.collision_mask = 0
		set_physics_process(false)

func _animate(delta: float, move_speed: float) -> void:
	var amplitude: float = clampf(move_speed / 4.4, 0.0, 1.0)
	gait_phase += delta * (5.4 + move_speed * 1.15)
	var phase: float = gait_phase
	fire_kick = maxf(0.0, fire_kick - delta * 7.0)
	if muzzle_flash and fire_kick < 0.72:
		muzzle_flash.visible = false
	if muzzle_light:
		muzzle_light.light_energy = maxf(0.0, muzzle_light.light_energy - delta * 24.0)
	if skeleton and not bone_indices.is_empty():
		_animate_skeleton(delta, amplitude, phase)
		return
	_animate_rigid_fallback(amplitude, phase)

func _set_bone_rotation(bone_name: String, rotation_offset: Quaternion) -> void:
	if not bone_indices.has(bone_name):
		return
	var index: int = int(bone_indices[bone_name])
	var rest: Transform3D = bone_rest[bone_name]
	skeleton.set_bone_pose_rotation(index, rest.basis.get_rotation_quaternion() * rotation_offset)

func _set_bone_position(bone_name: String, offset: Vector3) -> void:
	if not bone_indices.has(bone_name):
		return
	var index: int = int(bone_indices[bone_name])
	var rest: Transform3D = bone_rest[bone_name]
	skeleton.set_bone_pose_position(index, rest.origin + offset)

func _animate_skeleton(delta: float, amplitude: float, phase: float) -> void:
	# Contralateral gait: pelvis rotation/obliquity, spine counter-rotation,
	# stance knee flexion and swing clearance. Arms keep the authored rifle grip.
	var stride: float = sin(phase) * 0.52 * amplitude
	var bounce: float = absf(sin(phase)) * 0.028 * amplitude
	var pelvic_roll: float = sin(phase) * 0.045 * amplitude
	var pelvic_yaw: float = sin(phase) * 0.07 * amplitude
	var spine_counter: float = -sin(phase) * 0.05 * amplitude
	var lean: float = 0.05 * amplitude + aim_blend * 0.03 - fire_kick * 0.045
	_set_bone_position("Hips", Vector3(0, bounce, 0))
	_set_bone_rotation("Hips", Quaternion(Vector3.RIGHT, lean * 0.35) * Quaternion(Vector3.UP, pelvic_yaw) * Quaternion(Vector3.FORWARD, pelvic_roll))
	_set_bone_rotation("Torso", Quaternion(Vector3.RIGHT, lean) * Quaternion(Vector3.UP, spine_counter) * Quaternion(Vector3.FORWARD, -pelvic_roll * 0.6))
	_set_bone_rotation("Head", Quaternion(Vector3.RIGHT, -lean * 0.55 + fire_kick * 0.03) * Quaternion(Vector3.UP, -spine_counter * 0.5 + aim_blend * 0.02))
	_set_bone_rotation("LegL", Quaternion(Vector3.RIGHT, stride))
	_set_bone_rotation("LegR", Quaternion(Vector3.RIGHT, -stride))
	var knee_l_flex: float = maxf(0.0, -sin(phase)) * 0.85 * amplitude + 0.07 + amplitude * 0.05
	var knee_r_flex: float = maxf(0.0, sin(phase)) * 0.85 * amplitude + 0.07 + amplitude * 0.05
	_set_bone_rotation("KneeL", Quaternion(Vector3.RIGHT, knee_l_flex))
	_set_bone_rotation("KneeR", Quaternion(Vector3.RIGHT, knee_r_flex))
	# Tiny shoulder/elbow compliance only; never overwrite the authored IK grip.
	var sway: float = sin(phase) * 0.018 * amplitude
	_set_bone_rotation("ArmL", Quaternion(Vector3.RIGHT, -sway - fire_kick * 0.025))
	_set_bone_rotation("ArmR", Quaternion(Vector3.RIGHT, sway - fire_kick * 0.035))
	_set_bone_rotation("ElbowL", Quaternion(Vector3.RIGHT, -fire_kick * 0.015))
	_set_bone_rotation("ElbowR", Quaternion(Vector3.RIGHT, -fire_kick * 0.02))
	if rifle_node and not rifle_node is BoneAttachment3D:
		var recoil: Transform3D = Transform3D(Basis(Vector3.RIGHT, -fire_kick * 0.05), Vector3(0, 0, fire_kick * 0.025))
		rifle_node.transform = rifle_rest * recoil

func _animate_rigid_fallback(amplitude: float, phase: float) -> void:
	var stride: float = sin(phase) * 0.52 * amplitude
	var bounce: float = absf(sin(phase)) * 0.028 * amplitude
	if leg_l:
		leg_l.rotation.x = stride
	if leg_r:
		leg_r.rotation.x = -stride
	if knee_l:
		knee_l.rotation.x = maxf(0.0, -sin(phase)) * 0.85 * amplitude + 0.07
	if knee_r:
		knee_r.rotation.x = maxf(0.0, sin(phase)) * 0.85 * amplitude + 0.07
	if arm_l:
		arm_l.rotation = arm_l_rest + Vector3(-0.025 * amplitude * sin(phase) - fire_kick * 0.03, 0.0, 0.0)
	if arm_r:
		arm_r.rotation = arm_r_rest + Vector3(0.025 * amplitude * sin(phase) - fire_kick * 0.04, 0.0, 0.0)
	if elbow_l:
		elbow_l.rotation = elbow_l_rest + Vector3(-fire_kick * 0.02, 0.0, 0.0)
	if elbow_r:
		elbow_r.rotation = elbow_r_rest + Vector3(-fire_kick * 0.025, 0.0, 0.0)
	if torso:
		torso.position.y = torso_rest_y + bounce
		torso.rotation.x = 0.05 * amplitude - fire_kick * 0.04
		torso.rotation.y = -0.05 * amplitude * sin(phase)
	if head_node:
		head_node.rotation.x = -0.03 * amplitude + fire_kick * 0.03
	if rifle_node and not rifle_node is BoneAttachment3D:
		rifle_node.transform = rifle_rest * Transform3D(Basis(Vector3.RIGHT, -fire_kick * 0.05), Vector3(0, 0, fire_kick * 0.025))
