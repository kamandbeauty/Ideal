extends CharacterBody3D

signal defeated(character)

var role := "hero"
var health := 100.0
var max_health := 100.0
var speed := 2.0
var attack_timer := 0.0
var fire_timer := 0.0
var run_clock := 0.0
var gait_blend := 0.0
var left_leg: Node3D
var right_leg: Node3D
var weapon: Node3D
var dead := false
var visual_root: Node3D
var muzzle_flash: MeshInstance3D
var muzzle_time := 0.0
var rig: Skeleton3D
var animation_player: AnimationPlayer
var current_animation := ""
var gun_recoil := 0.0
var combat_animation_time := 0.0
var hit_reaction_time := 0.0
var hit_direction := 1.0
var enemy_action_time := 0.0

# The hero uses the custom procedural rig, squad members use the authored CC0 soldier with combat clips, and enemies use the supplied animated zombie rig.
const MODEL_CONFIG := {
	"hero": ["res://assets/models/hero-2630-procedural-rig.glb", 0.026, -0.011, 0.0],
	"soldier": ["res://assets/models/soldier-quaternius.glb", 0.026, 0.0, 0.0],
	"zombie": ["res://assets/models/zombie-user-animated.glb", 0.01, 0.0, PI],
	"runner": ["res://assets/models/zombie-user-animated.glb", 0.01, 0.0, PI],
	"brute": ["res://assets/models/zombie-user-animated.glb", 0.01, 0.0, PI],
}

func setup(kind: String) -> void:
	role = kind
	if kind == "soldier":
		health = 55
	elif kind == "zombie":
		health = 55
		speed = 2.0
	elif kind == "runner":
		health = 75
		speed = 3.1
	elif kind == "brute":
		health = 400
		speed = 1.1
	max_health = health
	collision_layer = 4 if is_enemy() else 2
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 1
	add_child(collider)
	if not create_model(kind):
		create_placeholder()
	if not is_enemy():
		create_weapon()
	if role == "brute":
		scale = Vector3(1.6, 1.6, 1.6)

func create_model(kind: String) -> bool:
	if not MODEL_CONFIG.has(kind):
		return false
	var config: Array = MODEL_CONFIG[kind]
	var resource = load(config[0])
	if not resource is PackedScene:
		push_warning("Character model unavailable; using prototype visual for " + kind)
		return false
	visual_root = Node3D.new()
	add_child(visual_root)
	var model = resource.instantiate()
	visual_root.add_child(model)
	model.scale = Vector3.ONE * float(config[1])
	if kind == "brute":
		# Distinguish the larger stage enemy without changing its skeleton.
		model.scale.x *= 1.25
		model.scale.z *= 1.15
	model.position.y = float(config[2])
	model.rotation.y = float(config[3])
	if kind == "hero" or kind == "soldier" or is_enemy():
		rig = find_skeleton(model)
		animation_player = find_animation_player(model)
		if rig == null:
			push_warning("Character skeleton was not imported: " + kind)
	return true

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null

func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := find_animation_player(child)
		if found != null:
			return found
	return null

func create_placeholder() -> void:
	var clothes := Color(0.32, 0.42, 0.28) if is_enemy() else Color(0.22, 0.32, 0.3)
	var skin := Color(0.48, 0.64, 0.36) if is_enemy() else Color(0.75, 0.56, 0.44)
	add_part(self, Vector3(0, 1.35, 0), Vector3(0.8, 0.85, 0.45), clothes)
	add_part(self, Vector3(0, 2, 0), Vector3(0.48, 0.48, 0.48), skin)
	for side in [-1, 1]:
		add_part(self, Vector3(side * 0.52, 1.3, 0), Vector3(0.24, 0.75, 0.28), skin)
	left_leg = make_leg(-0.23)
	right_leg = make_leg(0.23)
	if not is_enemy():
		add_part(self, Vector3(0, 1.4, -0.3), Vector3(0.55, 0.55, 0.2), Color(0.29, 0.27, 0.19))

func create_weapon() -> void:
	# A lightweight rifle assembled from shared-purpose primitive components.
	weapon = Node3D.new()
	weapon.position = Vector3(-0.28, 1.25, 0.44)
	add_child(weapon)
	# CC0 low-poly assault rifle. Its source length axis is +X.
	var rifle_scene: PackedScene = load("res://assets/models/rifle-quaternius.glb")
	if rifle_scene:
		var rifle := rifle_scene.instantiate() as Node3D
		rifle.scale = Vector3.ONE * 0.30
		rifle.rotation.y = -PI / 2.0
		# The rifle's +X axis points from stock to muzzle. Place its grip at
		# the hand anchor instead of centering the model on the wrist.
		rifle.position = Vector3(0, -0.05, -0.18)
		weapon.add_child(rifle)
	muzzle_flash = MeshInstance3D.new()
	var flash_mesh := QuadMesh.new()
	flash_mesh.size = Vector2(0.7, 0.7)
	muzzle_flash.mesh = flash_mesh
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.86, 0.62)
	glow.albedo_texture = preload("res://assets/effects/muzzle_star.png")
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.4, 0.05)
	muzzle_flash.material_override = glow
	muzzle_flash.position = Vector3(0, 0.08, 0.695)
	muzzle_flash.visible = false
	weapon.add_child(muzzle_flash)

func aim_weapon(destination: Vector3) -> void:
	if not is_instance_valid(weapon):
		return
	var direction := destination - weapon.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		weapon.rotation.y = atan2(direction.x, direction.z)

func show_shot() -> void:
	gun_recoil = 0.2
	combat_animation_time = 0.22
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_time = 0.07

func is_enemy() -> bool:
	return role == "zombie" or role == "runner" or role == "brute"

func make_leg(x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0.9, 0)
	add_child(pivot)
	add_part(pivot, Vector3(0, -0.4, 0), Vector3(0.3, 0.8, 0.35), Color(0.18, 0.2, 0.2))
	return pivot

func add_part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	node.position = pos
	parent.add_child(node)
	return node

func update_animation(delta: float, moving: bool) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var speed_factor := clampf(planar_speed / 2.6, 0.0, 1.8) if moving else 0.0
	run_clock += delta * speed_factor
	gait_blend = move_toward(gait_blend, 1.0 if moving else 0.0, delta * 6.0)
	if not dead:
		hit_reaction_time = maxf(0.0, hit_reaction_time - delta)
	if visual_root and not dead and not is_enemy():
		var sway := sin(run_clock * 7) * 0.025 if moving and role != "soldier" else 0.0
		var hit_lean := hit_direction * hit_reaction_time * 0.8
		visual_root.rotation.z = sway + hit_lean
		if role != "soldier":
			visual_root.position.y = absf(sin(run_clock * 7)) * 0.035 if moving else 0.0
	if rig and (role == "hero" or role == "soldier"):
		var stride := sin(run_clock * 9.0) * 0.55 * gait_blend
		pose_bone("LegRight", Quaternion(Vector3.RIGHT, stride))
		pose_bone("LegLeft", Quaternion(Vector3.RIGHT, -stride))
		# Bring the static outstretched arms forward into a two-handed aiming pose.
		pose_bone("ArmRight", Quaternion(Vector3.UP, 1.2))
		pose_bone("ArmLeft", Quaternion(Vector3.UP, -1.2))
	if left_leg and right_leg:
		left_leg.rotation.x = sin(run_clock * 9) * 0.55 if moving else 0.0
		right_leg.rotation.x = -left_leg.rotation.x
	if muzzle_time > 0:
		muzzle_time = maxf(0.0, muzzle_time - delta)
		if muzzle_time == 0.0 and muzzle_flash:
			muzzle_flash.visible = false
	attack_timer = maxf(0, attack_timer - delta)
	fire_timer = maxf(0, fire_timer - delta)
	gun_recoil = move_toward(gun_recoil, 0.0, delta * 2.0)
	combat_animation_time = maxf(0.0, combat_animation_time - delta)
	if role == "soldier" and animation_player:
		play_soldier_motion(moving)
	if is_enemy() and animation_player and not dead:
		enemy_action_time = maxf(0.0, enemy_action_time - delta)
		if enemy_action_time <= 0.0:
			var motion := "Run" if role == "runner" else "Walk"
			play_zombie_clip(motion if moving else "Idle", true)
			animation_player.speed_scale = clampf(planar_speed / speed, 0.65, 1.3) if moving else 1.0
	if weapon and rig and (role == "hero" or role == "soldier"):
		var arm := rig.find_bone("ArmRight")
		if arm >= 0:
			var hand_in_rig: Vector3 = rig.get_bone_global_pose(arm) * Vector3(-18, -13, 0)
			weapon.position = to_local(rig.to_global(hand_in_rig))
			weapon.position.z -= gun_recoil

func play_zombie_clip(clip_name: String, loop: bool = false) -> void:
	if not animation_player or not animation_player.has_animation(clip_name):
		return
	if current_animation == clip_name and animation_player.is_playing():
		return
	var clip := animation_player.get_animation(clip_name)
	clip.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	animation_player.play(clip_name, 0.15)
	current_animation = clip_name

func play_zombie_action(clip_name: String, hold: float) -> void:
	if not is_enemy() or dead:
		return
	enemy_action_time = hold
	if animation_player:
		animation_player.speed_scale = 1.0
	play_zombie_clip(clip_name)

func play_soldier_motion(moving: bool) -> void:
	var wanted := "Shoot_OneHanded" if combat_animation_time > 0.0 else ("Walk_Carry" if moving else "Idle")
	if current_animation != wanted:
		for name in animation_player.get_animation_list():
			if String(name).ends_with(wanted):
				var clip := animation_player.get_animation(name)
				clip.loop_mode = Animation.LOOP_NONE if wanted == "Shoot_OneHanded" else Animation.LOOP_LINEAR
				animation_player.play(name, 0.15)
				current_animation = wanted
				break
	animation_player.speed_scale = clampf(Vector2(velocity.x, velocity.z).length() / 2.6, 0.6, 2.0) if moving and wanted == "Walk_Carry" else 1.0

func pose_bone(bone_name: String, rotation: Quaternion) -> void:
	var bone := rig.find_bone(bone_name)
	if bone >= 0:
		rig.set_bone_pose_rotation(bone, rotation)

func step_motion(horizontal: Vector3, delta: float) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -2.0 if is_on_floor() else velocity.y - 12.0 * delta
	move_and_slide()
	position.x = clampf(position.x, -5.0, 5.0)

func apply_damage(amount: float, impact_direction: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	health -= amount
	hit_direction = -hit_direction
	hit_reaction_time = 0.18
	if health > 0 and is_enemy():
		play_zombie_action("Hit", 0.35)
	if health <= 0:
		dead = true
		defeated.emit(self)
		# Remove collision immediately without delaying the gameplay defeat signal.
		collision_layer = 0
		collision_mask = 0
		if is_enemy() and visual_root:
			# Visual knockback is independent of gameplay collision and kill timing.
			var launch := Vector3(impact_direction.x, 0, impact_direction.z)
			if launch.length_squared() < 0.001:
				launch = Vector3.FORWARD
			launch = (global_transform.basis.inverse() * launch).normalized()
			launch.y = 0
			var initial := visual_root.position
			var landing := initial + launch * (0.55 if role == "brute" else 1.0)
			var flight := create_tween()
			flight.set_parallel(true)
			flight.tween_property(visual_root, "position:x", landing.x, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			flight.tween_property(visual_root, "position:z", landing.z, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			var arc := create_tween()
			arc.tween_property(visual_root, "position:y", initial.y + 0.24, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			arc.tween_property(visual_root, "position:y", initial.y, 0.27).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			if animation_player and animation_player.has_animation("Death"):
				animation_player.speed_scale = 6.0
				play_zombie_clip("Death")
				get_tree().create_timer(animation_player.get_animation("Death").length / 6.0 + 0.15).timeout.connect(queue_free)
			else:
				flight.tween_property(visual_root, "rotation:x", -1.25, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				flight.chain().tween_callback(queue_free)
		elif visual_root:
			var fall := create_tween()
			fall.tween_property(visual_root, "rotation:x", -1.25, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fall.tween_callback(queue_free)
		else:
			queue_free()
