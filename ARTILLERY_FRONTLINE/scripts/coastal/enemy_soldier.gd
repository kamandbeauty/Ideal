class_name EnemySoldier
extends CharacterBody3D
## Skinned infantry with anatomical gait, authored weapon grips and a physical
## constrained ragdoll death. The corpse keeps its final pose on the terrain.
signal died(soldier: EnemySoldier)
signal damaged(soldier: EnemySoldier, ratio: float)
signal shoot_requested(soldier: EnemySoldier, target: Vector3)
## Fired whenever fire or a blast makes this soldier take cover or stagger.
signal suppressed(soldier: EnemySoldier)

enum State { ADVANCE, COVER, STAGGER, DEAD }
var state: State = State.ADVANCE
## Infantry is soft-skinned: one heavy-MG body hit drops a rifleman.
const BASE_HEALTH: float = 20.0
## Ground below this depth is treated as deep water: infantry wade at the surface.
const WADE_FLOOR: float = -0.45
const HEADSHOT_MULTIPLIER: float = 2.2
const HEAD_HEIGHT: float = 1.45
## Seconds between rounds of one burst.
const BURST_GAP: float = 0.14
## Seconds without a clear line before a firing-line unit looks for another firing position.
const REPOSITION_AFTER: float = 1.2
## Height of the eyes/muzzle used for line-of-fire checks.
const EYE_HEIGHT: float = 1.5
## Infantry role (rifle, heavy, RPG). Set with set_role before the unit enters a wave.
var role_kind: int = InfantryRole.Kind.RIFLE
## Test hook for line of fire: -1 uses the physics and terrain check, 0 forces blocked, 1 forces clear.
var sight_override: int = -1
var holding_position: bool = false
var reposition_point: Vector3 = Vector3.INF
var setup_timer: float = 0.0
var burst_left: int = 0
var burst_gap: float = 0.0
var reload_timer: float = 0.0
var blocked_time: float = 0.0
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
## Movement state: real infantry accelerates, weaves, halts to look around and
## bunches up less, rather than marching in a ruler-straight line at constant speed.
var current_speed: float = 0.0
var bound_timer: float = 0.0
var bound_pausing: bool = false
var lateral_phase: float = 0.0
var lateral_strength: float = 0.25

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("damageable")
	add_to_group("infantry")
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
	lateral_phase = randf() * TAU
	lateral_strength = randf_range(0.16, 0.32)
	bound_timer = randf_range(0.5, 2.5)

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

## Formal armour rating. Riflemen wear no plate, so 0: the unit takes the full hit. Heavy infantry: 0.5.
var armor: float = 0.0

## Applies the role's health, armour and hit-reaction values. Call before the unit is used.
func set_role(kind: int) -> void:
	role_kind = kind
	max_health = InfantryRole.max_health(kind)
	health = max_health
	armor = InfantryRole.armor(kind)
	shoot_cooldown = randf_range(1.0, 2.6)

## Fraction of an incoming hit this unit removes (0 for infantry); see DamageModel.
func damage_resistance_for(amount: float) -> float:
	return DamageModel.damage_resistance(amount, armor)

## Returns the health actually removed (after the headshot and critical multipliers), for damage readouts.
func receive_damage(amount: float, hit_point: Vector3 = Vector3.INF, hit_direction: Vector3 = Vector3.ZERO, critical: bool = false) -> float:
	if state == State.DEAD or amount <= 0.0:
		return 0.0
	last_hit_damage = amount
	if hit_point != Vector3.INF:
		last_hit_point = hit_point
	if hit_direction.length_squared() > 0.0001:
		last_hit_direction = hit_direction.normalized()
	var scale: float = 1.0
	if hit_point != Vector3.INF and hit_point.y - global_position.y >= HEAD_HEIGHT:
		scale = HEADSHOT_MULTIPLIER
	scale *= DamageModel.critical_scale(critical)
	var before: float = health
	health = maxf(0.0, health - DamageModel.taken(amount * scale, armor))
	damaged.emit(self, health / max_health)
	if health <= 0.0:
		_die()
	else:
		stagger_time = maxf(stagger_time, InfantryRole.stagger_time(role_kind))
		suppressed.emit(self)
		if state != State.COVER and health < max_health * 0.45:
			state = State.COVER
	return before - health

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
		suppressed.emit(self)
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
	_settle_height(delta)
	if stagger_time > 0.0:
		stagger_time -= delta
		if stagger_time <= 0.0 and state == State.STAGGER:
			state = State.ADVANCE
		current_speed = move_toward(current_speed, 0.0, 9.0 * delta)
		_animate(delta, current_speed)
		return
	_tick_reposition()
	var target: Vector3 = _movement_target()
	var offset: Vector3 = target - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	_update_hold(distance)
	var stop_at: float = _stop_distance()
	var wounded: float = 0.55 if health < max_health * 0.4 else 1.0
	var pausing: bool = _update_bounding(delta, distance)
	var wants_move: bool = distance > stop_at and not pausing and not holding_position
	var target_speed: float = speed * wounded * _wade_factor() if wants_move else 0.0
	current_speed = move_toward(current_speed, target_speed, (5.0 if target_speed > current_speed else 8.0) * delta)
	var heading: Vector3 = offset.normalized() if distance > 0.01 else Vector3.FORWARD
	if wants_move:
		if state == State.ADVANCE and reposition_point == Vector3.INF:
			heading = _weave(heading, distance)
		heading = _avoid_neighbours(heading)
		if current_speed > 0.02:
			var step: float = minf(current_speed * delta, maxf(0.0, distance - stop_at))
			global_position += heading * step
		rotation.y = lerp_angle(rotation.y, atan2(heading.x, heading.z), delta * 5.0)
	else:
		# Halted: turn to face the emplacement while the squad covers.
		var to_player: Vector3 = player_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.z), delta * 3.0)
	_animate(delta, current_speed)
	var to_target: Vector3 = player_position - global_position
	aim_blend = lerpf(aim_blend, 1.0 if to_target.length() < 150.0 else 0.0, delta * 3.0)
	# Infantry climb out of the surf before they open fire.
	var ashore: bool = CoastalTerrain.height_at(global_position.x, global_position.z) > -0.25
	_tick_combat(delta, to_target, ashore)

## Where the unit is trying to get to: a firing position, the objective, or its cover point.
func _movement_target() -> Vector3:
	if reposition_point != Vector3.INF:
		return reposition_point
	return objective if state == State.ADVANCE else cover_point

## Stop distance for the current movement goal.
func _stop_distance() -> float:
	if reposition_point != Vector3.INF:
		return 0.8
	if state == State.COVER:
		return 1.2
	if state == State.ADVANCE and InfantryRole.holds(role_kind):
		return InfantryRole.hold_distance(role_kind)
	return 2.5

## Firing-line roles stop at their hold distance and stay put until they are ordered elsewhere.
func _update_hold(distance: float) -> void:
	if state == State.ADVANCE and reposition_point == Vector3.INF and InfantryRole.holds(role_kind):
		holding_position = distance <= InfantryRole.hold_distance(role_kind)
	else:
		holding_position = false

func _tick_reposition() -> void:
	if reposition_point == Vector3.INF:
		return
	var to_spot: Vector3 = reposition_point - global_position
	to_spot.y = 0.0
	if to_spot.length() < 1.0:
		reposition_point = Vector3.INF
		blocked_time = 0.0

## Combat timing: wait for cooldown, reload, a clear line and the role's set-up time, then fire.
func _tick_combat(delta: float, to_target: Vector3, ashore: bool) -> void:
	if reload_timer > 0.0:
		reload_timer = maxf(0.0, reload_timer - delta)
		if reload_timer <= 0.0 and state == State.COVER and role_kind == InfantryRole.Kind.RPG and health >= max_health * 0.45:
			state = State.ADVANCE
	if burst_left > 0:
		burst_gap -= delta
		if burst_gap <= 0.0:
			burst_left -= 1
			burst_gap = BURST_GAP
			shoot_requested.emit(self, player_position)
		return
	# Firing-line roles only shoot from their position: they do not open fire while still walking in.
	var on_line: bool = holding_position or not InfantryRole.holds(role_kind)
	if shoot_cooldown > 0.0 or reload_timer > 0.0 or not ashore or not on_line or to_target.length() >= InfantryRole.fire_range(role_kind):
		setup_timer = 0.0
		return
	if not _line_of_fire_from(global_position):
		# No clear line: hold fire. Firing-line roles look for a position with a clear line.
		setup_timer = 0.0
		blocked_time += delta
		if blocked_time > REPOSITION_AFTER and reposition_point == Vector3.INF and role_kind != InfantryRole.Kind.RIFLE:
			_seek_firing_position()
		return
	blocked_time = 0.0
	var setup: float = InfantryRole.setup_time(role_kind)
	if setup_timer < setup:
		setup_timer += delta
		return
	setup_timer = 0.0
	_fire_volley()

func _fire_volley() -> void:
	if role_kind == InfantryRole.Kind.RPG:
		# One rocket, then fall back to cover to reload.
		reload_timer = InfantryRole.reload_time(role_kind)
		_retreat_to_cover()
		shoot_requested.emit(self, player_position)
		return
	if role_kind == InfantryRole.Kind.HEAVY:
		shoot_cooldown = InfantryRole.fire_interval(role_kind)
		burst_left = InfantryRole.burst_size(role_kind) - 1
		burst_gap = BURST_GAP
		shoot_requested.emit(self, player_position)
		return
	shoot_cooldown = randf_range(1.6, 3.2)
	shoot_requested.emit(self, player_position)

## Shoot-and-scoot: a few metres back from the emplacement, out of the line of fire.
func _retreat_to_cover() -> void:
	var away: Vector3 = global_position - player_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.BACK
	cover_point = global_position + away.normalized() * 7.0
	state = State.COVER
	holding_position = false

## Line of fire from a ground point to the emplacement. The test hook overrides it when set.
func _line_of_fire_from(point: Vector3) -> bool:
	if sight_override >= 0:
		return sight_override == 1
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	return FireControl.line_clear(space, point + Vector3.UP * EYE_HEIGHT, player_position + Vector3.UP * 1.2)

## Picks the first nearby point with a clear line: forward first, then flanks, then further out.
func _seek_firing_position() -> void:
	var forward: Vector3 = player_position - global_position
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		return
	forward = forward.normalized()
	var side: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	var candidates: Array[Vector3] = [forward * 6.0, side * 6.0, -side * 6.0, forward * 12.0, side * 12.0, -side * 12.0]
	for offset in candidates:
		var spot: Vector3 = global_position + offset
		spot.y = CoastalTerrain.height_at(spot.x, spot.z)
		if CoastalTerrain.height_at(spot.x, spot.z) <= -0.25:
			continue
		if _line_of_fire_from(spot):
			reposition_point = spot
			holding_position = false
			return
	blocked_time = 0.0

## Bounded advance: run, then stop and crouch to look around, as squads do.
func _update_bounding(delta: float, distance: float) -> bool:
	if state != State.ADVANCE or distance < 8.0:
		bound_pausing = false
		return false
	bound_timer -= delta
	if bound_timer <= 0.0:
		bound_pausing = not bound_pausing
		bound_timer = randf_range(0.6, 1.3) if bound_pausing else randf_range(2.2, 4.0)
	return bound_pausing

## Gentle sideways drift so the approach does not look scripted.
func _weave(heading: Vector3, distance: float) -> Vector3:
	var side: Vector3 = Vector3(-heading.z, 0.0, heading.x)
	var amount: float = sin(clock * 0.8 + lateral_phase) * lateral_strength * clampf(distance / 12.0, 0.0, 1.0)
	return (heading + side * amount).normalized()

## Soft separation from squad mates so infantry spread out instead of stacking.
func _avoid_neighbours(heading: Vector3) -> Vector3:
	var push: Vector3 = Vector3.ZERO
	for node in get_tree().get_nodes_in_group("infantry"):
		var mate: EnemySoldier = node as EnemySoldier
		if mate == null or mate == self or mate.is_dead():
			continue
		var offset: Vector3 = global_position - mate.global_position
		offset.y = 0.0
		var length: float = offset.length()
		if length > 0.001 and length < 1.0:
			push += offset / length * (1.0 - length)
	if push.length_squared() < 0.0001:
		return heading
	return (heading + push * 0.9).normalized()

func _ground_height() -> float:
	return maxf(CoastalTerrain.height_at(global_position.x, global_position.z), WADE_FLOOR)

## Feet follow the terrain (or the surf) with a short drop when leaving a landing craft.
func _settle_height(delta: float) -> void:
	global_position.y = move_toward(global_position.y, _ground_height(), 2.2 * delta)

## Waist-deep water slows the squad; the beach is full speed.
func _wade_factor() -> float:
	var depth: float = maxf(0.0, -CoastalTerrain.height_at(global_position.x, global_position.z))
	return lerpf(1.0, 0.55, clampf(depth / 1.2, 0.0, 1.0))

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
