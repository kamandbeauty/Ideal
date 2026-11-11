class_name EnemyVehicle
extends CharacterBody3D
## Destructible armored threat with rolling road wheels, tracked suspension,
## independently aiming turret, recoiling gun, muzzle flash and persistent wreck.
signal died(vehicle: EnemyVehicle)
signal damaged(vehicle: EnemyVehicle, ratio: float)
signal shoot_requested(origin: Vector3, target: Vector3, damage: float, blast: float)
## Boss tanks report 1 at 60% health and 2 at 30%, so the controller can show the damage.
signal stage_changed(vehicle: EnemyVehicle, stage: int)
## Fired a moment after a vehicle that carries ammunition is destroyed (tanks, APCs, the boss).
signal cook_off(vehicle: EnemyVehicle, radius: float)

var kind: String = "tank"
## Armour is light enough that two cannon hits (or two rockets) stop a tank and
## one cannon hit stops a transport.
const TANK_HEALTH: float = 260.0
const TRANSPORT_HEALTH: float = 120.0
const JEEP_HEALTH: float = 90.0
const APC_HEALTH: float = 220.0
const BOSS_HEALTH: float = 900.0
const WADE_FLOOR: float = -0.35
## Seconds between a vehicle's destruction and its ammunition cooking off.
const COOK_OFF_DELAY: float = 0.9
## Health ratios at which the wreck starts smoking and then burning.
const SMOKE_THRESHOLD: float = 0.6
const FIRE_THRESHOLD: float = 0.3
## Aim height above the emplacement's ground, matching the infantry sight line.
const AIM_HEIGHT: float = 1.2
## Seconds a holding vehicle waits with a blocked gun before it looks for a firing spot.
const REPOSITION_AFTER: float = 1.2
## A vehicle counts as arrived this close (m) to its firing spot.
const REPOSITION_ARRIVE: float = 1.5
## Candidate firing spots, as bearings (degrees) from the current spot around the stand-off circle.
const REPOSITION_ANGLES := [12.0, -12.0, 24.0, -24.0, 36.0, -36.0, 48.0, -48.0]
## Seconds between the first and later cook-off bursts of a destroyed carrier.
const BURST_SPACING: float = 1.3
## Lateral speed (m/s) of a jeep circling its target.
const STRAFE_SPEED: float = 5.0
## A circling jeep keeps strafing anywhere inside this band; the approach only runs outside it.
## Without a band, the tangential step pushes it just past the stand-off, and the approach
## branch then pulls it straight back in each frame, so it never actually circles.
const STRAFE_BAND: float = 2.0
var health: float = TANK_HEALTH
var max_health: float = TANK_HEALTH
var speed: float = 3.2
var objective: Vector3 = Vector3.ZERO
var model_root: Node3D
var turret: Node3D
var barrel_pivot: Node3D
var recoil_node: Node3D
var recoil_rest: Vector3 = Vector3.ZERO
var muzzle: Node3D
var wheels: Array[Node3D] = []
var collision: CollisionShape3D
var dead: bool = false
var shoot_cooldown: float = 3.0
var clock: float = 0.0
var stop_distance: float = 46.0
## Tanks close half the distance from their spawn to the emplacement, then hold
## that line and fire instead of parking at the beach or driving into the gun.
const ADVANCE_FRACTION: float = 0.5
const MIN_HOLD_DISTANCE: float = 16.0
var advance_origin: Vector3 = Vector3.ZERO
var advance_span: float = 0.0
var holding: bool = false
var recoil_offset: float = 0.0
var recoil_velocity: float = 0.0
var muzzle_flash: MeshInstance3D
var muzzle_light: OmniLight3D
var flash_timer: float = 0.0
var suspension_phase: float = 0.0
var turret_rest_y: float = 0.0
## True for procedural models: their turret and gun face -Z and elevate with +X rotation.
var procedural_aim: bool = false
## True when the model comes from VehicleModels rather than a GLB file.
var built_procedurally: bool = false
var stage: int = 0
## Angle (rad) between the turret and the bearing to the target. The gun only fires inside aim_tolerance.
var aim_error: float = 0.0
## Direction of a jeep's circling, flipped every few seconds.
var strafe_sign: float = 1.0
var strafe_timer: float = 2.0
## Hull pitch kick from the last hit, decaying over time.
var hit_jolt: float = 0.0
var hit_jolt_phase: float = 0.0
var smoke_plume: CPUParticles3D
var fire_plume: CPUParticles3D
## Where a holding vehicle is driving to get a clear line of fire (Vector3.INF when not repositioning).
var reposition_point: Vector3 = Vector3.INF
## Seconds the gun has been ready to fire but blocked by terrain or cover.
var blocked_time: float = 0.0
## Test and tuning hook: false keeps a blocked vehicle in place instead of repositioning.
var can_reposition: bool = true

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("damageable")
	collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = hull_size()
	collision.shape = shape
	collision.position.y = hull_size().y * 0.5
	add_child(collision)
	_build_model()

func configure(spawn: Vector3, target: Vector3, vehicle_kind: String = "tank") -> void:
	var changed: bool = vehicle_kind != kind or model_root == null
	kind = vehicle_kind
	objective = target
	global_position = spawn
	if changed and is_inside_tree():
		if model_root:
			model_root.queue_free()
		model_root = null
		wheels.clear()
		turret = null
		barrel_pivot = null
		recoil_node = null
		muzzle = null
		procedural_aim = false
		built_procedurally = false
		var shape := BoxShape3D.new()
		shape.size = hull_size()
		collision.shape = shape
		collision.position.y = hull_size().y * 0.5
		_build_model()
	advance_origin = spawn
	var flat_spawn := Vector3(spawn.x, 0.0, spawn.z)
	var flat_target := Vector3(target.x, 0.0, target.z)
	advance_span = flat_spawn.distance_to(flat_target)
	health = health_for(kind)
	speed = cruise_speed()
	stage = 0
	if is_armoured():
		stop_distance = maxf(MIN_HOLD_DISTANCE, advance_span * ADVANCE_FRACTION)
	elif kind == "jeep":
		# The jeep circles at a wider stand-off than a transport parks at.
		stop_distance = 40.0
	else:
		stop_distance = 28.0
	holding = false
	max_health = health
	shoot_cooldown = randf_range(2.5, 4.5)
	suspension_phase = randf() * TAU
	hit_jolt = 0.0
	aim_error = 0.0
	strafe_timer = randf_range(1.0, 2.0)
	strafe_sign = 1.0 if randf() < 0.5 else -1.0
	if smoke_plume != null:
		smoke_plume.queue_free()
		smoke_plume = null
	if fire_plume != null:
		fire_plume.queue_free()
		fire_plume = null

func _build_model() -> void:
	var procedural: Node3D = VehicleModels.build_kind(kind)
	if procedural:
		# Procedural models already face -Z, which is this node's forward direction.
		model_root = procedural
		add_child(model_root)
		built_procedurally = true
		muzzle = model_root.find_child("Muzzle", true, false) as Node3D
		# "*Wheel*" also catches the boss track wheels, which are named TrackWheel_N.
		for child in model_root.find_children("*Wheel*", "Node3D", true, false):
			wheels.append(child as Node3D)
		# Jeep, APC and boss carry a turret pivot with a gun pivot inside it.
		turret = model_root.find_child("TurretPivot", true, false) as Node3D
		if turret:
			turret_rest_y = turret.position.y
			barrel_pivot = turret.find_child("GunPivot", true, false) as Node3D
			procedural_aim = true
		_build_muzzle_flash()
		return
	var path: String = "res://assets/models/warden.glb" if kind == "tank" else "res://assets/models/nomad.glb"
	if ResourceLoader.exists(path):
		model_root = load(path).instantiate()
		model_root.rotation.y = PI
		model_root.scale = Vector3.ONE * (0.72 if kind == "tank" else 0.62)
		add_child(model_root)
		MaterialLibrary.apply_to_model(model_root)
		turret = model_root.find_child("Turret", true, false) as Node3D
		if turret:
			turret_rest_y = turret.position.y
		barrel_pivot = model_root.find_child("BarrelPivot", true, false) as Node3D
		recoil_node = model_root.find_child("RecoilAssembly", true, false) as Node3D
		if recoil_node:
			recoil_rest = recoil_node.position
		muzzle = model_root.find_child("Muzzle", true, false) as Node3D
		for child in model_root.find_children("Wheel*", "Node3D", true, false):
			wheels.append(child as Node3D)
		_build_muzzle_flash()
	if model_root == null:
		model_root = Node3D.new()
		model_root.rotation.y = PI
		add_child(model_root)
		MeshFactory.box(model_root, "Hull", Vector3(0, 1.1, 0), Vector3(3.2, 1.6, 6.0), Color(0.3, 0.34, 0.24), true, "paint_olive")
		turret = Node3D.new()
		turret.name = "Turret"
		turret.position = Vector3(0, 2.2, -0.4)
		model_root.add_child(turret)
		MeshFactory.box(turret, "TurretBody", Vector3.ZERO, Vector3(2.0, 0.9, 2.4), Color(0.28, 0.32, 0.22), true, "paint_olive")
		MeshFactory.cylinder(turret, "Gun", Vector3(0, 0, -2.6), 0.12, 3.4, Color(0.2, 0.22, 0.18), 16, "steel").rotation.x = PI * 0.5
		turret_rest_y = turret.position.y

func _build_muzzle_flash() -> void:
	if muzzle == null:
		return
	muzzle_flash = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6) if is_heavy() else Vector2(0.7, 0.7)
	muzzle_flash.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.78, 0.35, 0.95)
	var texture: Texture2D = MaterialLibrary.texture("muzzle_flash.png")
	if texture:
		material.albedo_texture = texture
	muzzle_flash.material_override = material
	muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_flash.visible = false
	muzzle.add_child(muzzle_flash)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.62, 0.25)
	muzzle_light.omni_range = 9.0
	muzzle_light.light_energy = 0.0
	muzzle.add_child(muzzle_light)

func is_dead() -> bool:
	return dead

## Formal armour rating. Every vehicle is full plate (1.0), so hits are resisted as before.
var armor: float = 1.0

## Fraction of an incoming hit this vehicle removes; see DamageModel.
func damage_resistance_for(amount: float) -> float:
	return DamageModel.damage_resistance(amount, armor)

## Returns the health actually removed after armour (and the critical multiplier), for damage readouts.
func receive_damage(amount: float, critical: bool = false) -> float:
	if dead:
		return 0.0
	var before: float = health
	health = maxf(0.0, health - DamageModel.taken(amount, armor) * DamageModel.critical_scale(critical))
	var removed: float = before - health
	# A hit rocks the hull; a bigger share of health lost gives a bigger kick.
	if removed > 0.0:
		hit_jolt = maxf(hit_jolt, clampf(removed / max_health * 0.5, 0.01, 0.06))
	damaged.emit(self, health / max_health)
	_update_damage_state()
	_check_stages()
	if health <= 0.0:
		_die()
	return removed

## Smoke from the engine deck below 60% health, flames below 30%. Each plume is built once.
func _update_damage_state() -> void:
	var ratio: float = health / max_health
	if smoke_plume == null and ratio <= SMOKE_THRESHOLD:
		smoke_plume = _make_plume(false)
	if fire_plume == null and ratio <= FIRE_THRESHOLD:
		fire_plume = _make_plume(true)

func _make_plume(burning: bool) -> CPUParticles3D:
	var profile: Dictionary = wreck_profile(kind)
	var plume_scale: float = float(profile.fire) if burning else float(profile.smoke)
	return DamagePlume.make(self, Vector3(0.0, hull_size().y + 0.3, -0.6), burning, plume_scale)

func _check_stages() -> void:
	if kind != "boss" or dead:
		return
	var ratio: float = health / max_health
	if stage < 1 and ratio <= 0.6:
		stage = 1
		stage_changed.emit(self, stage)
	if stage < 2 and ratio <= 0.3:
		stage = 2
		stage_changed.emit(self, stage)

func react_to_explosion(point: Vector3, radius: float) -> void:
	if dead:
		return
	var distance: float = global_position.distance_to(point)
	if distance < radius * 1.7:
		receive_damage(190.0 * (1.0 - distance / (radius * 1.7)))

func _die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision.set_deferred("disabled", true)
	set_physics_process(false)
	reposition_point = Vector3.INF
	if muzzle_flash:
		muzzle_flash.visible = false
	if muzzle_light:
		muzzle_light.light_energy = 0.0
	# Destruction sequence: the wreck keeps smoking (and burning, since health is already at zero),
	# and carriers of ammunition cook off one or more times after a short fuse.
	var profile: Dictionary = wreck_profile(kind)
	if smoke_plume == null:
		smoke_plume = _make_plume(false)
	if fire_plume == null:
		fire_plume = _make_plume(true)
	var fuse_radius: float = cook_off_radius(kind)
	# Only vehicles that carry ammunition cook off (cook_off_radius is 0 for jeeps and transports).
	var bursts: int = int(profile.bursts) if fuse_radius > 0.0 else 0
	for index in range(bursts):
		var fuse: Tween = create_tween()
		fuse.tween_interval(COOK_OFF_DELAY + float(index) * BURST_SPACING)
		fuse.tween_callback(_cook_off.bind(fuse_radius))
	# Each wreck settles on its own tilt: a jeep rolls over, a tank barely leans.
	var lean: float = float(profile.tilt) * (1.0 if randf() < 0.5 else -1.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(model_root, "rotation:z", lean, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(model_root, "position:y", -0.08, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if barrel_pivot:
		# Procedural guns elevate with +X, so a droop is a negative angle there.
		var droop: float = -0.12 if procedural_aim else 0.12
		tween.tween_property(barrel_pivot, "rotation:x", droop, 1.2)
	if turret:
		tween.tween_property(turret, "rotation:z", randf_range(-0.05, 0.05), 1.2)
	died.emit(self)

## Destruction look per vehicle type: how far it tilts, how many cook-off bursts it throws,
## and how large its smoke and fire are.
static func wreck_profile(vehicle_kind: String) -> Dictionary:
	match vehicle_kind:
		"boss":
			return {"tilt": 0.05, "bursts": 2, "smoke": 1.6, "fire": 1.4}
		"tank":
			return {"tilt": 0.06, "bursts": 1, "smoke": 1.0, "fire": 1.0}
		"apc":
			return {"tilt": 0.14, "bursts": 1, "smoke": 0.9, "fire": 1.1}
		"transport":
			return {"tilt": 0.12, "bursts": 0, "smoke": 0.8, "fire": 0.9}
		"jeep":
			return {"tilt": 0.26, "bursts": 0, "smoke": 0.7, "fire": 1.2}
	return {"tilt": 0.05, "bursts": 0, "smoke": 1.0, "fire": 1.0}

func _cook_off(radius: float) -> void:
	if fire_plume == null:
		fire_plume = _make_plume(true)
	cook_off.emit(self, radius)

func muzzle_position() -> Vector3:
	if muzzle:
		return muzzle.global_position
	return global_position + Vector3.UP * 2.2 - global_transform.basis.z * 3.0

func _fire() -> void:
	if dead:
		return
	recoil_velocity += 7.0 if is_heavy() else 3.5
	flash_timer = 0.07 if is_heavy() else 0.045
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash.rotation.z = randf_range(0.0, TAU)
		muzzle_flash.scale = Vector3.ONE * randf_range(0.85, 1.25)
	if muzzle_light:
		muzzle_light.light_energy = 4.0 if is_heavy() else 2.0
	shoot_requested.emit(muzzle_position(), objective, shell_damage(), shell_blast())

func _physics_process(delta: float) -> void:
	if dead:
		return
	clock += delta
	shoot_cooldown -= delta
	var offset: Vector3 = objective - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	var direction: Vector3 = offset / distance if distance > 0.001 else -global_transform.basis.z
	var desired_yaw: float = atan2(-direction.x, -direction.z)
	var current_speed: float = 0.0
	if reposition_point != Vector3.INF:
		# Blocked from the firing line: swing along the stand-off circle to a spot with a clear shot.
		current_speed = _drive_to_firing_point(delta)
	elif strafes(kind) and distance <= stop_distance + STRAFE_BAND:
		# The jeep does not park: it circles its target at the stand-off distance.
		current_speed = _strafe(delta, direction, distance, desired_yaw)
	elif distance > stop_distance:
		holding = false
		var error: float = absf(angle_difference(rotation.y, desired_yaw))
		rotation.y = _turn_toward(rotation.y, desired_yaw, turn_rate(kind) * delta)
		# Turn before driving: full speed when roughly facing the target, a pivot when far off.
		var drive: float = clampf((1.6 - error) / 1.0, 0.0, 1.0)
		current_speed = speed * drive
		if current_speed > 0.0:
			# Clamp the last step so even a slow physics frame cannot overshoot the
			# half-way hold line and oscillate around it.
			global_position += direction * minf(current_speed * delta, distance - stop_distance)
	else:
		holding = true
		rotation.y = _turn_toward(rotation.y, desired_yaw, turn_rate(kind) * delta)
	# Hulls follow the beach and wade out of the surf; they drop from a landing
	# craft's ramp rather than teleporting to the sand.
	var ground: float = maxf(CoastalTerrain.height_at(global_position.x, global_position.z), WADE_FLOOR)
	global_position.y = move_toward(global_position.y, ground, 2.2 * delta)
	_roll_wheels(delta, current_speed)
	_suspension(delta, current_speed)
	_aim_turret(delta)
	_tick_recoil(delta)
	_tick_firing(delta, distance)

## Attack timing and line of sight: the gun fires only when it is on the bearing, its cooldown is ready,
## and nothing solid stands between the muzzle and the emplacement.
func _tick_firing(delta: float, distance: float) -> void:
	if shoot_cooldown > 0.0 or distance >= 170.0 or aim_error > aim_tolerance(kind):
		return
	if line_of_fire_clear():
		blocked_time = 0.0
		shoot_cooldown = fire_interval()
		_fire()
		return
	# Blocked: hold fire rather than shoot into cover. A holding vehicle looks for a spot with a clear line.
	# A jeep keeps circling, which already changes its line, so it does not reposition.
	blocked_time += delta
	if blocked_time > REPOSITION_AFTER and holding and can_reposition and reposition_point == Vector3.INF and not strafes(kind):
		_seek_firing_position()

## Where the gun aims: the emplacement's ground plus the aim height.
func aim_point() -> Vector3:
	return Vector3(objective.x, CoastalTerrain.height_at(objective.x, objective.z) + AIM_HEIGHT, objective.z)

## True when the straight line from the muzzle to the emplacement is free of terrain and cover.
func line_of_fire_clear() -> bool:
	return _line_clear_from(muzzle_position())

func _line_clear_from(origin: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	return FireControl.line_clear(space, origin, aim_point())

## Looks round the stand-off circle for the nearest bearing with a clear line, and drives there.
func _seek_firing_position() -> void:
	var from_objective: Vector3 = global_position - objective
	from_objective.y = 0.0
	if from_objective.length_squared() < 0.01:
		blocked_time = 0.0
		return
	var bearing: float = atan2(from_objective.x, from_objective.z)
	# Sidestep along the current stand-off circle, so the vehicle keeps its distance from the emplacement.
	var radius: float = from_objective.length()
	for angle in REPOSITION_ANGLES:
		var heading: float = bearing + deg_to_rad(angle)
		var spot := objective + Vector3(sin(heading), 0.0, cos(heading)) * radius
		spot.y = CoastalTerrain.height_at(spot.x, spot.z)
		if spot.y <= -0.25:
			continue
		if _line_clear_from(spot + Vector3.UP * (hull_size().y + 0.8)):
			reposition_point = spot
			blocked_time = 0.0
			return
	# No clear spot on this circle: wait a while before looking again.
	blocked_time = 0.0

## Drives toward the firing spot with the same turn-before-drive rule as the approach.
func _drive_to_firing_point(delta: float) -> float:
	holding = false
	var offset: Vector3 = reposition_point - global_position
	offset.y = 0.0
	var remaining: float = offset.length()
	if remaining <= REPOSITION_ARRIVE:
		reposition_point = Vector3.INF
		blocked_time = 0.0
		return 0.0
	var direction: Vector3 = offset / remaining
	var desired_yaw: float = atan2(-direction.x, -direction.z)
	var error: float = absf(angle_difference(rotation.y, desired_yaw))
	rotation.y = _turn_toward(rotation.y, desired_yaw, turn_rate(kind) * delta)
	var drive: float = clampf((1.6 - error) / 1.0, 0.0, 1.0)
	var current_speed: float = speed * drive
	if current_speed > 0.0:
		global_position += direction * minf(current_speed * delta, remaining)
	return current_speed

## Circling for a jeep: a tangential run with a radial correction back to the stand-off distance.
func _strafe(delta: float, direction: Vector3, distance: float, desired_yaw: float) -> float:
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_sign = -strafe_sign
		strafe_timer = randf_range(2.5, 3.5)
	var tangent: Vector3 = Vector3(-direction.z, 0.0, direction.x) * strafe_sign * STRAFE_SPEED
	var radial: Vector3 = direction * clampf((distance - stop_distance) * 0.8, -3.0, 3.0)
	var velocity: Vector3 = tangent + radial
	global_position += velocity * delta
	rotation.y = _turn_toward(rotation.y, desired_yaw, turn_rate(kind) * delta)
	holding = false
	return velocity.length()

## Moves an angle toward a target by at most max_step radians (shortest way round).
static func _turn_toward(current: float, target: float, max_step: float) -> float:
	return current + clampf(angle_difference(current, target), -max_step, max_step)

func _roll_wheels(delta: float, current_speed: float) -> void:
	if current_speed <= 0.0:
		return
	# Procedural wheels have their axle along local Y, so they spin about Y. Rotating
	# about X would swing the axle and make the wheel tumble. GLB wheels keep their axis.
	var axis: Vector3 = Vector3.UP if built_procedurally else Vector3.RIGHT
	for wheel in wheels:
		var radius: float = float(wheel.get_meta("roll_radius", wheel_radius()))
		wheel.rotate_object_local(axis, current_speed / radius * delta)

func _suspension(delta: float, current_speed: float) -> void:
	suspension_phase += delta * (2.0 + current_speed * 1.5)
	var amplitude: float = 0.015 * clampf(current_speed / maxf(speed, 0.1), 0.0, 1.0)
	hit_jolt = move_toward(hit_jolt, 0.0, delta * 0.2)
	hit_jolt_phase += delta * 24.0
	var jolt: float = -hit_jolt * sin(hit_jolt_phase)
	if turret:
		turret.position.y = turret_rest_y + sin(suspension_phase) * amplitude
	if model_root:
		model_root.rotation.x = sin(suspension_phase * 0.7) * amplitude * 0.35 + jolt

func _aim_turret(delta: float) -> void:
	if turret == null:
		aim_error = 0.0
		return
	if procedural_aim:
		_aim_procedural_turret(delta)
		return
	var local_target: Vector3 = model_root.to_local(objective + Vector3.UP * 1.2)
	var desired: float = atan2(local_target.x, local_target.z)
	aim_error = absf(angle_difference(turret.rotation.y, desired))
	turret.rotation.y = _turn_toward(turret.rotation.y, desired, traverse_rate(kind) * delta)
	if barrel_pivot:
		var horizontal: float = Vector2(local_target.x, local_target.z).length()
		var pitch: float = clampf(atan2(local_target.y - barrel_pivot.position.y, horizontal), -0.12, 0.22)
		barrel_pivot.rotation.x = lerpf(barrel_pivot.rotation.x, -pitch, delta * 2.0)

## Procedural turrets face -Z, so the yaw that points their front at the target is atan2(-x, -z).
## Elevation is positive when the gun rises, because -Z rotates upward around +X.
func _aim_procedural_turret(delta: float) -> void:
	# Target relative to the turret pivot, in model space (the pivot itself is unrotated).
	var offset: Vector3 = model_root.to_local(objective + Vector3.UP * 1.2) - turret.position
	var yaw: float = atan2(-offset.x, -offset.z)
	aim_error = absf(angle_difference(turret.rotation.y, yaw))
	turret.rotation.y = _turn_toward(turret.rotation.y, yaw, traverse_rate(kind) * delta)
	if barrel_pivot:
		var horizontal: float = Vector2(offset.x, offset.z).length()
		var elevation: float = atan2(offset.y - barrel_pivot.position.y, horizontal)
		barrel_pivot.rotation.x = lerpf(barrel_pivot.rotation.x, clampf(elevation, -0.12, 0.22), delta * 2.0)

func _tick_recoil(delta: float) -> void:
	recoil_velocity += (-recoil_offset * 140.0 - recoil_velocity * 16.0) * delta
	recoil_offset += recoil_velocity * delta
	if recoil_node:
		recoil_node.position = recoil_rest + Vector3(0, 0, -recoil_offset * 0.10)
	flash_timer = maxf(0.0, flash_timer - delta)
	if muzzle_flash and flash_timer <= 0.0:
		muzzle_flash.visible = false
	if muzzle_light:
		muzzle_light.light_energy = maxf(0.0, muzzle_light.light_energy - delta * 40.0)

## Per-kind stats. Armour stays the same for every hull, so anti-armour weapons
## (cannon, rocket, bazooka) are what break a boss; small arms only scratch it.
static func health_for(vehicle_kind: String) -> float:
	match vehicle_kind:
		"boss":
			return BOSS_HEALTH
		"apc":
			return APC_HEALTH
		"jeep":
			return JEEP_HEALTH
		"transport":
			return TRANSPORT_HEALTH
	return TANK_HEALTH

func hull_size() -> Vector3:
	match kind:
		"boss":
			return Vector3(3.4, 3.0, 8.6)
		"apc":
			return Vector3(3.0, 2.6, 6.2)
		"jeep":
			return Vector3(2.0, 2.0, 3.6)
		"transport":
			return Vector3(3.0, 2.6, 6.8)
	return Vector3(3.4, 2.6, 6.2)

## Handling per vehicle role. Heavy hulls turn and traverse slowly and must line up before they fire;
## light vehicles turn quickly, and the jeep keeps moving.
static func turn_rate(vehicle_kind: String) -> float:
	match vehicle_kind:
		"boss":
			return 0.35
		"tank":
			return 0.6
		"apc":
			return 0.8
		"jeep":
			return 2.4
	return 1.0

## Turret traverse in radians per second.
static func traverse_rate(vehicle_kind: String) -> float:
	match vehicle_kind:
		"boss":
			return 0.3
		"tank":
			return 0.7
		"apc":
			return 0.9
		"jeep":
			return 2.2
	return 1.0

## Angle (rad) the turret must be within before the gun fires.
static func aim_tolerance(vehicle_kind: String) -> float:
	match vehicle_kind:
		"boss":
			return 0.05
		"tank":
			return 0.04
		"apc":
			return 0.06
		"jeep":
			return 0.12
	return 0.1

## Blast radius when the vehicle's ammunition cooks off after its destruction; zero for unarmoured carriers.
static func cook_off_radius(vehicle_kind: String) -> float:
	match vehicle_kind:
		"boss":
			return 8.0
		"tank":
			return 5.0
		"apc":
			return 3.0
	return 0.0

static func strafes(vehicle_kind: String) -> bool:
	return vehicle_kind == "jeep"

func is_heavy() -> bool:
	return kind == "tank" or kind == "boss"

## Armoured hulls advance to a hold line; light vehicles stop at a fixed range.
func is_armoured() -> bool:
	return kind == "tank" or kind == "boss" or kind == "apc"

func cruise_speed() -> float:
	match kind:
		"boss":
			return 2.4
		"apc":
			return 3.8
		"jeep":
			return 6.0
		"transport":
			return 5.0
	return 3.0

func wheel_radius() -> float:
	match kind:
		"boss", "tank":
			return 0.55
		"apc":
			return 0.6
		"jeep":
			return 0.5
	return 0.45

func fire_interval() -> float:
	match kind:
		"boss":
			return 3.8
		"tank":
			return 4.6
		"apc":
			return 3.2
		"jeep":
			return 2.0
	return 2.6

func shell_damage() -> float:
	match kind:
		"boss":
			return 220.0
		"tank":
			return 150.0
		"apc":
			return 40.0
		"jeep":
			return 14.0
	return 22.0

func shell_blast() -> float:
	match kind:
		"boss":
			return 6.0
		"tank":
			return 5.0
		"apc":
			return 2.5
	return 0.0
