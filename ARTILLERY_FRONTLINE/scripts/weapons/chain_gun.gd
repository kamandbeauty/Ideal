class_name ChainGun
extends Weapon
## A single-barrel chain gun on the mount: the Bushmaster. It fires as soon as
## the trigger is held, with a heavier round and a longer wait between shots
## than the twin gun. Cadence, ammunition and reload live in WeaponState.

const STOW_DROP: float = 1.05
const FLASH_TIME: float = 0.03
const FLASH_LIGHT: float = 1.6

var model: Node3D
var mount: Node3D
var pivot: Node3D
var muzzle: Node3D
var port: Node3D
var ammo_can: Node3D
var can_rest := Vector3.ZERO
var flash: MeshInstance3D
var flash_left: float = 0.0
var flash_fresh: bool = false
var light: OmniLight3D
var light_fresh: bool = false
var lights_on: bool = true
var casings: CasingPool
var smoke_due: int = 0
var burst: int = 0


func _build() -> void:
	model = get_node("Model")
	pivot = find_child("BarrelPivot", true, false)
	mount = pivot.get_parent()
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
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 0.0
	light.omni_range = 8.0
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.45, -3.2)
	light.light_specular = 0.1
	light.visible = lights_on
	pivot.add_child(light)
	_enrich_surfaces(model)
	_dress_chain()


func _dress_chain() -> void:
	var steel := Color(0.08, 0.078, 0.07)
	var dark := Color(0.03, 0.032, 0.03)
	var brass := Color(0.6, 0.46, 0.18)
	_kit_box(pivot, Vector3(0.0, 0.2, -0.2), Vector3(0.048, 0.016, 0.42), steel, 0.9, 0.26)
	_kit_box(pivot, Vector3(0.0, 0.245, -0.42), Vector3(0.014, 0.055, 0.016), dark, 0.35, 0.7)
	_kit_box(pivot, Vector3(0.0, 0.12, 0.08), Vector3(0.11, 0.06, 0.2), steel, 0.86, 0.32)
	_kit_box(pivot, Vector3(0.06, 0.04, -0.05), Vector3(0.04, 0.05, 0.24), dark, 0.2, 0.82)
	for z: float in [-0.7, -1.15, -1.6]:
		_kit_cyl(pivot, Vector3(0.0, 0.02, z), 0.032, 0.022, dark, 0.4, 0.6, "z")
	_kit_cyl(pivot, Vector3(0.0, 0.16, -0.1), 0.01, 0.024, brass, 0.9, 0.3)
	_kit_cyl(pivot, Vector3(0.0, 0.0, -1.85), 0.026, 0.05, steel, 0.88, 0.25, "z")


func _build_flash() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = EffectPool.flare(6)
	material.albedo_color = Color(2.7, 1.7, 0.75, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	material.disable_fog = true
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.5, 0.5)
	mesh.material = material
	flash = MeshInstance3D.new()
	flash.name = "Flash"
	flash.mesh = mesh
	flash.position = Vector3(0.0, 0.0, -0.16)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	muzzle.add_child(flash)
	var corona_mat: StandardMaterial3D = material.duplicate()
	corona_mat.albedo_color = Color(1.8, 0.65, 0.18, 0.7)
	var corona_mesh := QuadMesh.new()
	corona_mesh.size = Vector2(0.82, 0.3)
	corona_mesh.material = corona_mat
	var corona := MeshInstance3D.new()
	corona.name = "Corona"
	corona.mesh = corona_mesh
	corona.position = Vector3(0.0, 0.0, -0.02)
	corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.add_child(corona)


func apply_quality(_tier: String, settings: Dictionary) -> void:
	lights_on = bool(settings.get("lights", true))
	if light:
		light.visible = lights_on


func set_aim(yaw_degrees: float, pitch_degrees: float) -> void:
	mount.rotation.y = -deg_to_rad(yaw_degrees)
	pivot.rotation = Vector3(deg_to_rad(pitch_degrees), 0.0, 0.0)


func bore_direction() -> Vector3:
	return -pivot.global_basis.z.normalized()


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
	flash.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
	flash.rotation.z = rng.randf() * TAU
	light.light_energy = FLASH_LIGHT
	_eject()
	burst += 1
	smoke_due += 1
	if effects and smoke_due >= 4:
		smoke_due = 0
		effects.burst("wisp", origin + bore_direction() * 0.3, Vector3.UP)
	Sound.play("hmg_shot", -2.8, rng.randf_range(0.84, 0.92))
	shot_fired.emit(0)


func _eject() -> void:
	if casings == null or port == null:
		return
	var forward: Vector3 = bore_direction()
	var right: Vector3 = forward.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var velocity: Vector3 = right * rng.randf_range(2.2, 3.4) + Vector3.UP * rng.randf_range(0.5, 1.3) + forward * rng.randf_range(0.1, 0.7)
	casings.eject(port.global_position, velocity)


func _animate(delta: float) -> void:
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
		light.light_energy = move_toward(light.light_energy, 0.0, delta * 28.0)
	if burst > 0 and since_shot > data.fire_interval * 1.8:
		if burst >= 3:
			Sound.play("hmg_tail", -8.0, rng.randf_range(0.92, 1.02))
		burst = 0
	if since_shot > 0.7:
		smoke_due = 0
	if ammo_can:
		var dip: float = sin(state.reload_progress() * PI) * 0.26 if state.reloading else 0.0
		ammo_can.position = can_rest + Vector3(0.0, -dip, 0.0)


func _pose() -> void:
	if model == null:
		return
	var up: float = smoothstep(0.0, 1.0, readiness)
	model.position.y = -STOW_DROP * (1.0 - up)
	model.visible = readiness > 0.001
