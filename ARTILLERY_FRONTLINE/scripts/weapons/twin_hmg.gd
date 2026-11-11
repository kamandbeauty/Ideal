class_name TwinHmg
extends Weapon
## The mounted twin heavy machine gun: turns the cradle and tips the barrel
## group of the model, alternates barrels, and feeds rounds to the bullet
## pool. Cadence, ammunition and reload live in WeaponState.

## How far the gun sinks below the parapet while another weapon is in hand.
const STOW_DROP: float = 1.05

var model: Node3D
## The cradle turns on the pedestal; the barrel group tips inside the cradle.
var mount: Node3D
var pivot: Node3D
var recoilers: Array[Node3D] = []
var rest_z: Array[float] = []
var kick: Array[float] = [0.0, 0.0]
var muzzles: Array[Node3D] = []
var flashes: Array[MeshInstance3D] = []
var flash_left: Array[float] = [0.0, 0.0]
var casings: Array[CPUParticles3D] = []
var ammo_cans: Array[Node3D] = []
var can_rest: Array[Vector3] = []
var light: OmniLight3D
var barrel: int = 0


func _build() -> void:
	model = get_node("Model")
	pivot = find_child("BarrelPivot", true, false)
	mount = pivot.get_parent()
	for side: String in ["L", "R"]:
		var slide: Node3D = pivot.get_node("Recoil" + side)
		recoilers.append(slide)
		rest_z.append(slide.position.z)
		muzzles.append(slide.get_node("Muzzle" + side))
		var can: Node3D = pivot.get_node_or_null("AmmoCan" + side)
		if can:
			ammo_cans.append(can)
			can_rest.append(can.position)
		_build_flash(slide.get_node("Muzzle" + side))
		_build_casings(slide.get_node("Ejection" + side), -1.0 if side == "L" else 1.0)
	light = OmniLight3D.new()
	light.name = "MuzzleLight"
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 0.0
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.1, 2.0)
	pivot.add_child(light)


func _build_flash(muzzle: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.albedo_texture = EffectPool.soft_dot()
	material.albedo_color = Color(1.0, 0.74, 0.36, 0.95)
	material.disable_receive_shadows = true
	material.disable_fog = true
	material.no_depth_test = false
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.62, 0.62)
	mesh.material = material
	var flash := MeshInstance3D.new()
	flash.name = "Flash"
	flash.mesh = mesh
	flash.position = Vector3(0.0, 0.0, 0.16)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	muzzle.add_child(flash)
	flashes.append(flash)


func _build_casings(port: Node3D, side: float) -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.6, 0.28)
	brass.metallic = 0.85
	brass.roughness = 0.35
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.007
	mesh.bottom_radius = 0.007
	mesh.height = 0.06
	mesh.radial_segments = 5
	mesh.rings = 1
	mesh.material = brass
	var emitter := CPUParticles3D.new()
	emitter.name = "Casings"
	emitter.mesh = mesh
	emitter.emitting = false
	emitter.amount = 8
	emitter.lifetime = 0.7
	emitter.local_coords = false
	emitter.direction = Vector3(side, 0.55, -0.15)
	emitter.spread = 16.0
	emitter.initial_velocity_min = 2.0
	emitter.initial_velocity_max = 3.2
	emitter.gravity = Vector3(0.0, -9.8, 0.0)
	emitter.angular_velocity_min = -720.0
	emitter.angular_velocity_max = 720.0
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	port.add_child(emitter)
	casings.append(emitter)


func set_aim(yaw_degrees: float, pitch_degrees: float) -> void:
	# The model faces +Z and sits under a half-turn, which flips the sign of the tilt.
	mount.rotation.y = -deg_to_rad(yaw_degrees)
	pivot.rotation = Vector3(-deg_to_rad(pitch_degrees), 0.0, 0.0)


## Unit vector along the bores, in world space.
func bore_direction() -> Vector3:
	return pivot.global_basis.z.normalized()


func _fire_round() -> void:
	var muzzle: Node3D = muzzles[barrel]
	var origin: Vector3 = muzzle.global_position
	var direction: Vector3 = scatter((sight_point() - origin).normalized())
	if bullets:
		bullets.fire(origin, direction * data.muzzle_velocity, data.damage, data.max_range, state.shots % data.tracer_every == 0,
			data.penetration, data.penetration_damage_scale, data.headshot_multiplier)
	kick[barrel] = data.barrel_travel
	flash_left[barrel] = 0.05
	var flash: MeshInstance3D = flashes[barrel]
	flash.visible = true
	flash.scale = Vector3.ONE * rng.randf_range(0.75, 1.3)
	light.light_energy = 2.6
	Sound.play("hmg_shot", -5.0, rng.randf_range(0.95, 1.05))
	shot_fired.emit(barrel)
	barrel = 1 - barrel


func _animate(delta: float) -> void:
	for index: int in recoilers.size():
		kick[index] = move_toward(kick[index], 0.0, delta * 0.55)
		recoilers[index].position.z = rest_z[index] - kick[index]
		if flash_left[index] > 0.0:
			flash_left[index] -= delta
			if flash_left[index] <= 0.0:
				flashes[index].visible = false
	light.light_energy = move_toward(light.light_energy, 0.0, delta * 30.0)
	var firing: bool = since_shot < 0.12
	for emitter: CPUParticles3D in casings:
		if emitter.emitting != firing:
			emitter.emitting = firing
	# Swapping the belt boxes: they drop out of sight and come back up.
	var dip: float = sin(state.reload_progress() * PI) * 0.26 if state.reloading else 0.0
	for index: int in ammo_cans.size():
		ammo_cans[index].position = can_rest[index] + Vector3(0.0, -dip, 0.0)


func _pose() -> void:
	if model == null:
		return
	# Put away, the gun drops below the parapet: the gunner has stepped up to shoulder something else.
	var up: float = smoothstep(0.0, 1.0, readiness)
	model.position.y = -STOW_DROP * (1.0 - up)
	model.visible = readiness > 0.001
