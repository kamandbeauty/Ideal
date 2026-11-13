class_name RotaryGun
extends Weapon
## The six-barrel rotary gun on the mount. A motor turns the barrels, so the
## gun needs a moment to run up before its first round and coasts down after
## the last; in between it fires more than twice as fast as the twin gun, with
## a lighter round. Cadence, ammunition and reload live in WeaponState.

## How far the gun sinks below the parapet while another weapon is in hand.
const STOW_DROP: float = 1.05
## How long the muzzle flame stays after the frame that first shows it.
const FLASH_TIME: float = 0.03
## Energy of the light a round throws on the gun and the parapet.
const FLASH_LIGHT: float = 1.2
## Seconds the barrels take to coast to a stop once the trigger is let go.
const RUN_DOWN: float = 0.9
## Six barrels, one round each per turn.
const BARRELS: int = 6

var model: Node3D
## The whole gun turns on its pedestal; the barrel group tips on the trunnions; the rotor spins in it.
var mount: Node3D
var pivot: Node3D
var rotor: Node3D
var muzzle: Node3D
var port: Node3D
var ammo_can: Node3D
var can_rest := Vector3.ZERO
var flash: MeshInstance3D
var flash_left: float = 0.0
## A flame that has not been drawn yet: its time runs from the frame that first shows it.
var flash_fresh: bool = false
var light: OmniLight3D
var light_fresh: bool = false
var lights_on: bool = true
var casings: CasingPool
## 0 = barrels at rest, 1 = at firing speed.
var spin: float = 0.0
## The motor is driving the barrels (the trigger is held and there is something to fire).
var driving: bool = false
var smoke_due: int = 0
## Rounds in the burst being fired; when it stops, its report rolls on down the street.
var burst: int = 0


func _build() -> void:
	model = get_node("Model")
	pivot = find_child("BarrelPivot", true, false)
	mount = pivot.get_parent()
	rotor = pivot.get_node("Rotor")
	muzzle = pivot.get_node("Muzzle")
	port = pivot.get_node("Ejection")
	ammo_can = pivot.get_node_or_null("AmmoCan")
	if ammo_can:
		can_rest = ammo_can.position
	_build_flash()
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
	# Ahead of the muzzle and above the bore, with next to no highlight: it warms the stone of the
	# parapet and leaves the gun metal alone (see TwinHmg).
	light.position = Vector3(0.0, 0.45, -3.0)
	light.light_specular = 0.1
	light.visible = lights_on
	pivot.add_child(light)
	_enrich_surfaces(model)
	var steel := Color(0.07, 0.075, 0.08)
	_kit_box(pivot, Vector3(0.0, 0.22, -0.15), Vector3(0.04, 0.014, 0.42), steel)
	_kit_box(pivot, Vector3(0.0, 0.255, -0.32), Vector3(0.012, 0.045, 0.014), steel)


func _build_flash() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = EffectPool.flare(6)
	# Brighter than white, so the tone mapper leaves the heart of the flame burnt out.
	material.albedo_color = Color(2.2, 1.6, 0.8, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	material.disable_fog = true
	var mesh := QuadMesh.new()
	# Small enough that even its longest ray ends below the sight line.
	mesh.size = Vector2(0.5, 0.5)
	mesh.material = material
	flash = MeshInstance3D.new()
	flash.name = "Flash"
	flash.mesh = mesh
	flash.position = Vector3(0.0, 0.0, -0.14)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	muzzle.add_child(flash)


func apply_quality(_tier: String, settings: Dictionary) -> void:
	lights_on = bool(settings.get("lights", true))
	if light:
		light.visible = lights_on


func set_aim(yaw_degrees: float, pitch_degrees: float) -> void:
	# The model faces -Z, as the gunner does: no half-turn, and a raised muzzle is a positive tilt.
	mount.rotation.y = -deg_to_rad(yaw_degrees)
	pivot.rotation = Vector3(deg_to_rad(pitch_degrees), 0.0, 0.0)


## Unit vector along the bores, in world space.
func bore_direction() -> Vector3:
	return -pivot.global_basis.z.normalized()


## 0 with the barrels at rest, 1 at firing speed.
func spin_fraction() -> float:
	return spin


func _tick(delta: float) -> void:
	var wanted: bool = trigger and is_ready() and not state.reloading and state.ammo > 0
	if wanted and not driving and spin < 0.5:
		Sound.play("rotary_spin", -8.0, rng.randf_range(0.97, 1.03))
	driving = wanted
	if driving:
		spin = minf(1.0, spin + delta / maxf(data.spin_up_time, 0.001))
	else:
		spin = maxf(0.0, spin - delta / RUN_DOWN)


func _may_fire() -> bool:
	return spin >= 1.0


func _fire_round() -> void:
	var origin: Vector3 = muzzle.global_position
	var direction: Vector3 = scatter((sight_point() - origin).normalized())
	if bullets:
		bullets.fire(origin, direction * data.muzzle_velocity, data.damage, data.max_range, state.shots % data.tracer_every == 0,
			data.penetration, data.penetration_damage_scale, data.headshot_multiplier)
	flash_left = FLASH_TIME
	flash_fresh = true
	light_fresh = true
	flash.visible = true
	# Never the same flame twice: a new size and a new turn about the bore for every round.
	flash.scale = Vector3.ONE * rng.randf_range(0.75, 1.2)
	flash.rotation.z = rng.randf() * TAU
	light.light_energy = FLASH_LIGHT
	_eject()
	burst += 1
	smoke_due += 1
	if effects and smoke_due >= 9:
		smoke_due = 0
		effects.burst("wisp", origin + bore_direction() * 0.25, Vector3.UP)
	# One clip holds two reports, 40 ms apart: at this rate of fire single shots would run together
	# and take every voice the mixer has.
	if burst % 2 == 1:
		Sound.play("rotary_shot", -3.0, rng.randf_range(0.96, 1.05))
	shot_fired.emit(0)


## Throws the spent case out to the gunner's right, a little up and forward, clear of the picture.
func _eject() -> void:
	if casings == null or port == null:
		return
	var forward: Vector3 = bore_direction()
	var right: Vector3 = forward.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var velocity: Vector3 = right * rng.randf_range(2.0, 3.2) + Vector3.UP * rng.randf_range(0.4, 1.2) + forward * rng.randf_range(0.1, 0.8)
	casings.eject(port.global_position, velocity)


func _animate(delta: float) -> void:
	# One round per barrel: at full speed the cluster turns once for every six rounds.
	if spin > 0.0 and rotor:
		rotor.rotate_z(-TAU / (float(BARRELS) * data.fire_interval) * spin * delta)
	if flash.visible:
		if flash_fresh:
			flash_fresh = false
		else:
			flash_left -= delta
			if flash_left <= 0.0:
				flash.visible = false
	if light_fresh:
		light_fresh = false
	else:
		light.light_energy = move_toward(light.light_energy, 0.0, delta * 30.0)
	if burst > 0 and since_shot > data.fire_interval * 2.5:
		if burst >= 4:
			Sound.play("rotary_tail", -8.0, rng.randf_range(0.96, 1.04))
		burst = 0
	if since_shot > 0.6:
		smoke_due = 0
	# Changing the belt box: it drops out of sight and comes back up.
	if ammo_can:
		var dip: float = sin(state.reload_progress() * PI) * 0.26 if state.reloading else 0.0
		ammo_can.position = can_rest + Vector3(0.0, -dip, 0.0)


func _pose() -> void:
	if model == null:
		return
	# Put away, the gun drops below the parapet: the gunner has stepped up to shoulder something else.
	var up: float = smoothstep(0.0, 1.0, readiness)
	model.position.y = -STOW_DROP * (1.0 - up)
	model.visible = readiness > 0.001
