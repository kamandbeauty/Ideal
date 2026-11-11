class_name Defender
extends Node3D
## The gunner: a fixed firing position on the wall. The eye rides on a frame
## that turns and tips with the aim; the weapons follow that frame, and
## nothing else moves the player.

@export var aim_settings: AimSettings
@export var grenade_data: GrenadeData
## Height of the trunnion above the foot of the mount: the point the eye turns about.
@export_range(0.5, 3.0, 0.01) var pivot_height: float = 1.15

## Where a grenade leaves the hand, relative to the eye: right, up, back.
const THROW_HAND := Vector3(0.3, -0.25, -0.6)

var aim: AimController
## Every weapon under this node, in scene order; the first is the one in hand at the start.
var weapons: Array[Weapon] = []
var weapon: Weapon
var weapon_index: int = 0
## The frame turns with the yaw; the cradle inside it tips with the pitch and carries the eye.
var frame: Node3D
var cradle: Node3D
var camera: Camera3D
var grenades: GrenadePool
var grenade_count: int = 0
var grenade_cooldown: float = 0.0
## Height of the street below the wall, for a throw at nothing in particular.
var ground_height: float = 0.0
var input_enabled: bool = false
var touch_fire: bool = false
var shake: Vector3 = Vector3.ZERO
var rng := RandomNumberGenerator.new()
var aim_query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	if aim_settings == null:
		aim_settings = AimSettings.new()
	if grenade_data == null:
		grenade_data = GrenadeData.new()
	aim = AimController.new(aim_settings)
	frame = Node3D.new()
	frame.name = "Frame"
	frame.position = Vector3(0.0, pivot_height, 0.0)
	add_child(frame)
	cradle = Node3D.new()
	cradle.name = "Cradle"
	frame.add_child(cradle)
	camera = Camera3D.new()
	camera.name = "Eye"
	camera.fov = aim_settings.fov_degrees
	camera.near = 0.08
	camera.far = 700.0
	# Forward is -Z, so "behind the breech" is +Z.
	camera.position = aim_settings.eye_offset
	cradle.add_child(camera)
	camera.make_current()
	for child: Node in get_children():
		if child is Weapon:
			var item: Weapon = child
			item.camera = camera
			item.sight = cradle
			item.shot_fired.connect(_on_shot.bind(item))
			weapons.append(item)
	weapon = weapons[0]
	weapon_index = 0
	weapon.select(0.0, true)
	grenade_count = mini(grenade_data.carried, grenade_data.capacity)
	aim_query.collision_mask = Layers.BULLET_MASK
	aim_query.collide_with_areas = true
	rng.randomize()
	_apply_aim()


## Hands every weapon the pools it fires into.
func equip(bullet_pool: BulletPool, rocket_pool: RocketPool, grenade_pool: GrenadePool, effect_pool: EffectPool) -> void:
	grenades = grenade_pool
	for item: Weapon in weapons:
		item.bullets = bullet_pool
		item.rockets = rocket_pool
		item.effects = effect_pool


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		touch_fire = false
		for item: Weapon in weapons:
			item.set_trigger(false)


## Finger travel on the reference canvas, in pixels.
func add_drag(pixels: Vector2) -> void:
	if input_enabled:
		aim.drag(pixels, Profile.setting("sensitivity"), Profile.setting("invert_y"))


func set_fire(pressed: bool) -> void:
	touch_fire = pressed and input_enabled


func reload() -> void:
	if input_enabled:
		weapon.request_reload()


# -- Weapons -------------------------------------------------------------------------
func weapon_of(id: StringName) -> Weapon:
	for item: Weapon in weapons:
		if item.data.id == id:
			return item
	return null


## Puts the weapon in hand away and brings up another. False when that is not
## possible: no such weapon, already in hand, or nothing left to fire from it.
func select_weapon(index: int) -> bool:
	if not input_enabled or index < 0 or index >= weapons.size() or index == weapon_index:
		return false
	if weapons[index].state.is_spent():
		Sound.play("dry_fire", -8.0)
		Events.weapon_refused.emit(index)
		return false
	_switch_to(index)
	return true


func cycle_weapon() -> bool:
	for step: int in range(1, weapons.size()):
		var index: int = (weapon_index + step) % weapons.size()
		if not weapons[index].state.is_spent():
			return select_weapon(index)
	return false


func _switch_to(index: int) -> void:
	var previous: Weapon = weapon
	previous.deselect()
	weapon_index = index
	weapon = weapons[index]
	# The new weapon waits for the old one to clear the view.
	weapon.select(previous.data.lower_time * previous.readiness)
	Sound.play("weapon_switch", -7.0)
	Events.weapon_changed.emit(weapon_index, weapon)
	Events.ammo_changed.emit(weapon.state.ammo, weapon.data.magazine_size)


## Rockets and grenades handed over between waves. Returns what actually fitted: {"rockets", "grenades"}.
func resupply(rockets: int, grenade_amount: int) -> Dictionary:
	var rockets_taken: int = 0
	for item: Weapon in weapons:
		if item.data.kind == "rocket" and rockets_taken < rockets:
			rockets_taken += item.state.add_reserve(rockets - rockets_taken)
	var room: int = maxi(0, grenade_data.capacity - grenade_count)
	var grenades_taken: int = clampi(grenade_amount, 0, room)
	grenade_count += grenades_taken
	if grenades_taken > 0:
		Events.grenades_changed.emit(grenade_count, grenade_data.capacity)
	if rockets_taken > 0 and weapon.data.kind == "rocket":
		Events.ammo_changed.emit(weapon.state.ammo, weapon.data.magazine_size)
	return {"rockets": rockets_taken, "grenades": grenades_taken}


# -- Grenades ------------------------------------------------------------------------
func can_throw() -> bool:
	return input_enabled and grenades != null and grenade_count > 0 and grenade_cooldown <= 0.0


## 0 just after a throw, 1 when the next grenade may be thrown.
func throw_readiness() -> float:
	if grenade_data.cooldown <= 0.0:
		return 1.0
	return clampf(1.0 - grenade_cooldown / grenade_data.cooldown, 0.0, 1.0)


## Where a grenade thrown now would be sent: the spot under the crosshair,
## pulled inside the throwing range.
func throw_target() -> Vector3:
	var from: Vector3 = camera.global_position
	var forward: Vector3 = aim_direction()
	var flat := Vector3(forward.x, 0.0, forward.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	var target := Vector3(from.x + flat.x * grenade_data.max_range, ground_height, from.z + flat.z * grenade_data.max_range)
	if is_inside_tree():
		aim_query.from = from
		aim_query.to = from + forward * (grenade_data.max_range * 3.0)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(aim_query)
		if not hit.is_empty():
			target = hit.position
	var foot := Vector3(from.x, ground_height, from.z)
	var reachable: Vector3 = Ballistics.clamp_range(foot, target, grenade_data.min_range, grenade_data.max_range)
	if not reachable.is_equal_approx(target):
		# Out of reach: drop it on the street along the same bearing instead.
		reachable.y = ground_height
	return reachable


## Lobs a grenade at the spot under the crosshair. False when none can be thrown.
func throw_grenade() -> bool:
	if not can_throw():
		return false
	var target: Vector3 = throw_target()
	var origin: Vector3 = camera.global_position + cradle.global_basis * THROW_HAND
	var ground := Vector2(target.x - origin.x, target.z - origin.z).length()
	var time: float = Ballistics.flight_time(ground, grenade_data.throw_speed, grenade_data.min_flight_time,
		grenade_data.max_flight_time)
	var velocity: Vector3 = Ballistics.lob_velocity(origin, target, time, grenade_data.gravity)
	if grenades.throw_from(origin, velocity, grenade_data) < 0:
		return false
	grenade_count -= 1
	grenade_cooldown = grenade_data.cooldown
	# The swing of the arm is felt in the view.
	shake += Vector3(-0.5, 0.25, 0.3)
	Sound.play("grenade_throw", -4.0, rng.randf_range(0.95, 1.05))
	Events.grenades_changed.emit(grenade_count, grenade_data.capacity)
	Events.grenade_thrown.emit(target)
	return true


# -- Per-frame -----------------------------------------------------------------------
func _process(delta: float) -> void:
	grenade_cooldown = maxf(0.0, grenade_cooldown - delta)
	if input_enabled:
		var turn := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
			turn.x -= 1.0
		if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
			turn.x += 1.0
		if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
			turn.y += 1.0
		if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
			turn.y -= 1.0
		if turn != Vector2.ZERO:
			aim.turn(turn.x * aim_settings.key_turn_speed * delta, turn.y * aim_settings.key_turn_speed * delta)
		weapon.set_trigger(touch_fire or Input.is_physical_key_pressed(KEY_SPACE))
		if Input.is_physical_key_pressed(KEY_R):
			weapon.request_reload()
		# An empty launcher is no use on the shoulder: go back to a weapon that can still fire.
		if weapon.state.is_spent() and weapon.since_shot > 0.7:
			for index: int in weapons.size():
				if not weapons[index].state.is_spent():
					_switch_to(index)
					break
	aim.step(delta)
	shake = shake.lerp(Vector3.ZERO, 1.0 - exp(-18.0 * delta))
	_apply_aim()


func _apply_aim() -> void:
	var yaw: float = aim.aim_yaw()
	var pitch: float = aim.aim_pitch()
	frame.rotation.y = -deg_to_rad(yaw)
	cradle.rotation.x = deg_to_rad(pitch)
	# The shake is only in the picture: the weapons follow the cradle, so switching it off changes nothing about where rounds go.
	if bool(Profile.setting("screen_shake")):
		camera.rotation = Vector3(deg_to_rad(shake.x), deg_to_rad(shake.y), deg_to_rad(shake.z))
	else:
		camera.rotation = Vector3.ZERO
	for item: Weapon in weapons:
		item.set_aim(yaw, pitch)


func _on_shot(_barrel: int, source: Weapon) -> void:
	aim.kick(source.data.recoil_scale, rng.randf_range(-1.0, 1.0))
	var amount: float = aim_settings.camera_shake_degrees * maxf(1.0, sqrt(source.data.recoil_scale))
	shake += Vector3(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount), rng.randf_range(-amount, amount) * 1.5)


## Adds a jolt from outside the weapon: the gate falling, the wall being struck, a blast.
func jolt(degrees: float) -> void:
	shake += Vector3(rng.randf_range(-degrees, degrees), rng.randf_range(-degrees, degrees), rng.randf_range(-degrees, degrees))


func eye_position() -> Vector3:
	return camera.global_position


## Where the crosshair points, with the camera's shake.
func view_direction() -> Vector3:
	return -camera.global_basis.z


## Where the weapons point: the sight line without the shake.
func aim_direction() -> Vector3:
	return -cradle.global_basis.z.normalized()


## Yaw and pitch (degrees) that would put the crosshair on a world point.
func aim_for(target: Vector3) -> Vector2:
	return AimController.solve(frame.global_position, aim_settings.eye_offset.y, target)


## Whether the crosshair can be laid on a world point inside the aim limits.
func can_aim_at(target: Vector3) -> bool:
	var wanted: Vector2 = aim_for(target)
	return wanted.x >= aim_settings.yaw_min_degrees and wanted.x <= aim_settings.yaw_max_degrees \
		and wanted.y >= aim_settings.pitch_min_degrees and wanted.y <= aim_settings.pitch_max_degrees
