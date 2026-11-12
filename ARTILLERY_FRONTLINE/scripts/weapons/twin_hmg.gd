class_name TwinHmg
extends Weapon
## The mounted twin heavy machine gun: turns the cradle and tips the barrel
## group of the model, alternates barrels, and feeds rounds to the bullet
## pool. Cadence, ammunition and reload live in WeaponState.

## How far the gun sinks below the parapet while another weapon is in hand.
const STOW_DROP: float = 1.05
## How long a muzzle flash stays after the frame that first shows it: one more frame at 60 a second, none at 30.
const FLASH_TIME: float = 0.03
## Energy of the light a round throws on the gun and the parapet; a flicker by day, not a floodlight.
const FLASH_LIGHT: float = 1.4

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
## A flash that has not been drawn yet. Rounds leave in the physics step and the picture is drawn later:
## on a slow frame a flash timed from the shot would be over before anyone saw it.
var flash_fresh: Array[bool] = [false, false]
var light_fresh: bool = false
## Where each barrel throws its brass, and which way is outward from there (-1 left, +1 right of the gunner).
var ports: Array[Node3D] = []
var port_sides: Array[float] = []
var casings: CasingPool
## Rounds since the muzzles last smoked.
var smoke_due: int = 0
## Rounds in the burst being fired; when it stops, its report rolls on down the street.
var burst: int = 0
var lights_on: bool = true
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
		ports.append(slide.get_node("Ejection" + side))
		# The model faces +Z under a half-turn, so its own +X is the gunner's left.
		port_sides.append(-signf(slide.get_node("Ejection" + side).position.x - slide.get_node("Muzzle" + side).position.x))
	casings = CasingPool.new()
	casings.name = "Casings"
	add_child(casings)
	add_to_group("quality_listener")
	lights_on = bool(Graphics.profile().get("lights", true))
	light = OmniLight3D.new()
	light.name = "MuzzleLight"
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 0.0
	light.omni_range = 7.0
	light.shadow_enabled = false
	# Well ahead of the muzzles and above the bores, and with next to no highlight: gun metal shows a
	# light only as its highlight, and a full one turned both barrels gold with every round, in broad
	# daylight. What is left warms the stone of the parapet and little else.
	light.position = Vector3(0.0, 0.45, 3.4)
	light.light_specular = 0.1
	light.visible = lights_on
	pivot.add_child(light)


func _build_flash(muzzle: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = EffectPool.flare(6)
	# Brighter than white, so the tone mapper leaves the heart of the flash burnt out.
	material.albedo_color = Color(2.2, 1.6, 0.8, 1.0)
	# The gunner looks at the flash from behind the gun, along the bore.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	material.disable_fog = true
	var mesh := QuadMesh.new()
	# Small enough that even its longest ray ends below the sight line.
	mesh.size = Vector2(0.52, 0.52)
	mesh.material = material
	var flash := MeshInstance3D.new()
	flash.name = "Flash"
	flash.mesh = mesh
	flash.position = Vector3(0.0, 0.0, 0.16)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	muzzle.add_child(flash)
	flashes.append(flash)


func apply_quality(_tier: String, settings: Dictionary) -> void:
	lights_on = bool(settings.get("lights", true))
	if light:
		light.visible = lights_on


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
	flash_left[barrel] = FLASH_TIME
	flash_fresh[barrel] = true
	light_fresh = true
	var flash: MeshInstance3D = flashes[barrel]
	flash.visible = true
	# Never the same flash twice: a new size and a new turn about the bore for every round.
	flash.scale = Vector3.ONE * rng.randf_range(0.7, 1.25)
	flash.rotation.z = rng.randf() * TAU
	light.light_energy = FLASH_LIGHT
	_eject(barrel)
	burst += 1
	smoke_due += 1
	if effects and smoke_due >= 5:
		smoke_due = 0
		effects.burst("wisp", origin + bore_direction() * 0.25, Vector3.UP)
	Sound.play("hmg_shot", -5.0, rng.randf_range(0.95, 1.05))
	shot_fired.emit(barrel)
	barrel = 1 - barrel


## Throws the spent case out of the port of the barrel that fired: outward, a little up and forward,
## so it leaves the picture to the side instead of crossing it.
func _eject(index: int) -> void:
	if casings == null or index >= ports.size():
		return
	var forward: Vector3 = bore_direction()
	var right: Vector3 = forward.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var velocity: Vector3 = right * port_sides[index] * rng.randf_range(1.9, 3.0) + Vector3.UP * rng.randf_range(0.7, 1.5) \
		+ forward * rng.randf_range(0.1, 0.8)
	casings.eject(ports[index].global_position, velocity)


func _animate(delta: float) -> void:
	for index: int in recoilers.size():
		kick[index] = move_toward(kick[index], 0.0, delta * 0.55)
		recoilers[index].position.z = rest_z[index] - kick[index]
		if flashes[index].visible:
			# The frame that first shows a flash is free; its time runs from there.
			if flash_fresh[index]:
				flash_fresh[index] = false
			else:
				flash_left[index] -= delta
				if flash_left[index] <= 0.0:
					flashes[index].visible = false
	if light_fresh:
		light_fresh = false
	else:
		light.light_energy = move_toward(light.light_energy, 0.0, delta * 30.0)
	if burst > 0 and since_shot > data.fire_interval * 1.7:
		if burst >= 3:
			Sound.play("hmg_tail", -9.0, rng.randf_range(0.94, 1.06))
		burst = 0
	if since_shot > 0.6:
		smoke_due = 0
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
