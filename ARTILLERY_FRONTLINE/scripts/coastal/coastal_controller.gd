class_name CoastalController
extends Node3D
## Fixed-position combined-arms coastal wave defense. The camera never translates.
signal exit_requested
signal mission_finished(success: bool)

## The emplacement is hardened: a bigger health pool plus passive armour, so a
## few stray rounds no longer end the run.
const MAX_HEALTH: float = 6000.0
const DAMAGE_SCALE: float = 0.55
const REPAIR_AMOUNT: float = 1500.0
const AIRDROP_REPAIR: float = 1000.0
var battlefield: CoastalBattlefield
var effects: EffectPool
var bullets: CoastalBulletPool
var weapon: CoastalWeapon
var hud: CoastalHUD
var waves: WaveManager
var background: CoastalBackgroundAction
var camera: Camera3D
var aim_yaw: Node3D
var aim_pitch: Node3D
var craft: LandingCraft
var contact_called: bool = false
var soldiers: Array[EnemySoldier] = []
var vehicles: Array[EnemyVehicle] = []
var aircraft: Array[EnemyAircraft] = []
var crafts: Array[LandingCraft] = []
var active: bool = false
var paused: bool = false
var auto_fire: bool = false
var firing: bool = false
var zoomed: bool = false
var player_health: float = MAX_HEALTH
var elapsed: float = 0.0
var kills: int = 0
var yaw_target: float = 0.0
var pitch_target: float = -4.0
var yaw_current: float = 0.0
var pitch_current: float = -4.0
var support_timers: Dictionary = {"repair": 0.0, "airstrike": 0.0, "helicopter": 0.0, "airdrop": 0.0}
var support_charges: Dictionary = {"repair": 3, "airstrike": 2, "helicopter": 1, "airdrop": 2}
var airstrike_queue: Array[Dictionary] = []
var support_flights: Array[Dictionary] = []
var player_hitbox: StaticBody3D
var camera_shake: float = 0.0
var distant_clock: float = 0.0
var auto_reload_delay: float = -1.0
var emplacement := Vector3(0, 0, 58)
## Units waiting to leave a landing craft: {kind, craft, point, time}.
var disembark_queue: Array[Dictionary] = []
var current_wave: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	emplacement.y = CoastalTerrain.height_at(0, 58)
	battlefield = CoastalBattlefield.new()
	add_child(battlefield)
	for barrel in battlefield.barrels:
		barrel.exploded.connect(_on_barrel_exploded)
	effects = EffectPool.new()
	add_child(effects)
	bullets = CoastalBulletPool.new()
	add_child(bullets)
	bullets.impacted.connect(_on_bullet_impact)
	background = CoastalBackgroundAction.new()
	add_child(background)
	_build_camera()
	_build_player_hitbox()
	weapon = CoastalWeapon.new()
	camera.add_child(weapon)
	weapon.position = Vector3.ZERO
	weapon.fired.connect(_on_weapon_fired)
	hud = CoastalHUD.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	_connect_hud()
	waves = WaveManager.new()
	add_child(waves)
	waves.round_started.connect(_on_round_started)
	waves.mission_finished.connect(_on_mission_finished)
	start()

func _build_camera() -> void:
	aim_yaw = Node3D.new()
	aim_yaw.name = "AimYaw"
	aim_yaw.position = emplacement + Vector3.UP * 1.65
	add_child(aim_yaw)
	aim_pitch = Node3D.new()
	aim_pitch.name = "AimPitch"
	aim_yaw.add_child(aim_pitch)
	camera = Camera3D.new()
	camera.name = "FirstPersonCamera"
	camera.near = 0.05
	camera.far = 1600.0
	camera.fov = 60.0
	camera.current = true
	aim_pitch.add_child(camera)

func _build_player_hitbox() -> void:
	player_hitbox = StaticBody3D.new()
	player_hitbox.name = "PlayerEmplacement"
	player_hitbox.collision_layer = 8
	player_hitbox.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.2, 2.4)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 1.1
	player_hitbox.add_child(collision)
	player_hitbox.position = emplacement
	player_hitbox.set_meta("coastal_controller", self)
	add_child(player_hitbox)

func _connect_hud() -> void:
	hud.fire_down.connect(func(): firing = true)
	hud.fire_up.connect(func(): firing = false)
	hud.aim_pressed.connect(toggle_zoom)
	hud.weapon_pressed.connect(cycle_weapon)
	hud.reload_pressed.connect(reload)
	hud.rocket_pressed.connect(func(): weapon.select("rocket"))
	hud.auto_toggled.connect(set_auto_fire)
	hud.settings_pressed.connect(func(): set_paused(true))
	hud.support_pressed.connect(use_support)
	hud.resume_pressed.connect(func(): set_paused(false))
	hud.restart_pressed.connect(restart)
	hud.exit_pressed.connect(func(): exit_requested.emit())

func start() -> void:
	active = true
	paused = false
	player_health = MAX_HEALTH
	elapsed = 0.0
	kills = 0
	camera_shake = 0.0
	support_charges = {"repair": 3, "airstrike": 2, "helicopter": 1, "airdrop": 2}
	for id in support_timers:
		support_timers[id] = 0.0
	waves.start()

func restart() -> void:
	get_tree().paused = false
	for group in [soldiers, vehicles, aircraft, crafts]:
		for node in group:
			if is_instance_valid(node):
				node.queue_free()
	soldiers.clear()
	vehicles.clear()
	aircraft.clear()
	crafts.clear()
	craft = null
	for flight in support_flights:
		if is_instance_valid(flight.node):
			flight.node.queue_free()
	support_flights.clear()
	airstrike_queue.clear()
	disembark_queue.clear()
	bullets.clear()
	effects.clear()
	weapon.resupply()
	weapon.select("twin_hmg")
	yaw_target = 0.0
	pitch_target = -4.0
	hud.result_panel.visible = false
	hud.set_paused(false)
	start()

func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	hud.set_paused(value)

func aim_drag(relative: Vector2) -> void:
	if paused or not active:
		return
	var sensitivity: float = float(Profile.data.settings.sensitivity)
	yaw_target = wrapf(yaw_target - relative.x * 0.08 * sensitivity, -180.0, 180.0)
	pitch_target = clampf(pitch_target - relative.y * 0.06 * sensitivity, -35.0, 65.0)

func aim_at(world_point: Vector3) -> void:
	var direction: Vector3 = (world_point - camera.global_position).normalized()
	yaw_target = rad_to_deg(atan2(-direction.x, -direction.z))
	pitch_target = clampf(rad_to_deg(asin(clampf(direction.y, -1.0, 1.0))), -35.0, 65.0)

func set_auto_fire(enabled: bool) -> void:
	auto_fire = enabled
	if hud:
		hud.auto_check.button_pressed = enabled

func toggle_zoom() -> void:
	zoomed = not zoomed

## Magnification implied by the 60° → 30° field-of-view change (about 2.15×).
static func zoom_factor() -> float:
	return tan(deg_to_rad(30.0)) / tan(deg_to_rad(15.0))

func cycle_weapon() -> void:
	weapon.cycle()

func reload() -> void:
	weapon.start_reload()

func fire_once() -> bool:
	return weapon.try_fire()

func use_support(id: String) -> void:
	if not active or paused or not id in waves.supports():
		return
	if int(support_charges.get(id, 0)) <= 0 or float(support_timers.get(id, 0.0)) > 0.0:
		return
	if id == "repair" and player_health >= MAX_HEALTH:
		return
	support_charges[id] = int(support_charges[id]) - 1
	match id:
		"repair":
			player_health = minf(MAX_HEALTH, player_health + REPAIR_AMOUNT)
			support_timers[id] = 18.0
			Sound.play_ui("reload")
		"airstrike":
			support_timers[id] = 26.0
			var target: Vector3 = _strike_target()
			for index in range(5):
				airstrike_queue.append({"time": 1.1 + index * 0.18, "point": target + Vector3((index - 2) * 9.0, 0, -index * 4.0)})
			_spawn_support_flight("jet", target)
		"helicopter":
			support_timers[id] = 34.0
			_spawn_support_flight("helicopter", _strike_target())
		"airdrop":
			support_timers[id] = 30.0
			weapon.resupply()
			player_health = minf(MAX_HEALTH, player_health + AIRDROP_REPAIR)

func _strike_target() -> Vector3:
	if pitch_target > 12.0:
		var nearest: Node3D = _nearest_ground_target()
		if nearest:
			return nearest.global_position
	return _aim_ground_point(220.0)

func _nearest_ground_target() -> Node3D:
	var best: Node3D = null
	var best_distance: float = INF
	for group in [soldiers, vehicles, crafts]:
		for node in group:
			if is_instance_valid(node) and not node.is_dead():
				var distance: float = node.global_position.distance_to(emplacement)
				if distance < best_distance:
					best_distance = distance
					best = node
	return best

func _spawn_support_flight(kind: String, target: Vector3) -> void:
	var node := Node3D.new()
	var path: String = "res://assets/models/fighter.glb" if kind == "jet" else "res://assets/models/helicopter.glb"
	if ResourceLoader.exists(path):
		var model: Node3D = load(path).instantiate()
		node.add_child(model)
		MaterialLibrary.apply_to_model(model)
	else:
		MeshFactory.sphere(node, "SupportAircraft", Vector3.ZERO, Vector3(1.2, 1.0, 3.5), Color(0.35, 0.4, 0.34), "paint_olive")
	add_child(node)
	var direction := Vector3(1, 0, 0.25).normalized()
	var speed: float = 120.0 if kind == "jet" else 18.0
	var duration: float = 3.4 if kind == "jet" else 7.0
	node.global_position = target + Vector3(-direction.x * speed * duration * 0.5, 55.0 if kind == "jet" else 32.0, -direction.z * speed * duration * 0.5)
	node.rotation.y = atan2(direction.x, direction.z)
	support_flights.append({"node": node, "kind": kind, "age": 0.0, "duration": duration, "direction": direction, "speed": speed, "target": target, "next_strike": 0.8, "rotor": node.find_child("Rotor", true, false)})

func _aim_ground_point(max_distance: float) -> Vector3:
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_distance, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	var point: Vector3 = origin + direction * 120.0
	point.y = CoastalTerrain.height_at(point.x, point.z)
	return point

func _spawn_zones(round_number: int) -> Array[Vector3]:
	var zones: Array[Vector3] = battlefield.landing_zones.duplicate()
	if round_number >= 2:
		zones.append_array([Vector3(-92, 0, 24), Vector3(92, 0, 28)])
	if round_number >= 3:
		zones.append_array([Vector3(-40, 0, 104), Vector3(42, 0, 108)])
	return zones

func _on_round_started(round_number: int, setup: Dictionary) -> void:
	current_wave = round_number
	contact_called = false
	var zones: Array[Vector3] = _spawn_zones(round_number)
	var new_crafts: Array[LandingCraft] = []
	for index in range(int(setup.craft)):
		var x: float = -34.0 + index * 68.0
		var landing := LandingCraft.new()
		add_child(landing)
		landing.configure(Vector3(x, 0, -190.0 - index * 20.0), Vector3(x, 0, -12.0))
		landing.died.connect(_on_craft_destroyed)
		landing.arrived.connect(_unload)
		crafts.append(landing)
		new_crafts.append(landing)
		if craft == null:
			craft = landing
	_load_landing_cargo(setup, new_crafts, zones)
	for index in range(int(setup.helicopters)):
		_spawn_aircraft("helicopter", PI * 0.5 + index * 1.7)
	for index in range(int(setup.fighters)):
		_spawn_aircraft("fighter", PI * 1.2 + index * 2.1)

## Infantry and armour ride inside the landing craft and come ashore from the
## water. With no vessel in a wave they are landed directly on the beach instead.
func _load_landing_cargo(setup: Dictionary, new_crafts: Array[LandingCraft], zones: Array[Vector3]) -> void:
	var vehicles: Array[String] = []
	for index in range(int(setup.tanks)):
		vehicles.append("tank")
	for index in range(int(setup.transports)):
		vehicles.append("transport")
	var soldier_count: int = int(setup.soldiers)
	if new_crafts.is_empty():
		var time: float = 0.2
		for index in range(soldier_count):
			var zone: Vector3 = zones[index % zones.size()]
			var beach: Vector3 = zone + Vector3(randf_range(-12.0, 12.0), 0.0, randf_range(-8.0, 8.0) - index * 1.2)
			beach.y = CoastalTerrain.height_at(beach.x, beach.z)
			_queue_entry("soldier", null, beach, time)
			time += 0.4
		for index in range(vehicles.size()):
			var spawn := Vector3(-28.0 + index * 56.0, 0.0, 12.0 - index * 6.0)
			spawn.y = CoastalTerrain.height_at(spawn.x, spawn.z)
			_queue_entry(vehicles[index], null, spawn, time)
			time += 1.7
		return
	var loads: Array = []
	for landing in new_crafts:
		loads.append([])
	for index in range(vehicles.size()):
		loads[index % new_crafts.size()].append(vehicles[index])
	for index in range(soldier_count):
		loads[index % new_crafts.size()].append("soldier")
	for index in range(new_crafts.size()):
		var kinds: Array[String] = []
		for kind in loads[index]:
			kinds.append(String(kind))
		new_crafts[index].load_cargo(kinds)

## Empties a craft's hold onto the disembark queue, one unit at a time.
func _unload(landing: LandingCraft) -> void:
	if not is_instance_valid(landing):
		return
	var kinds: Array[String] = landing.unload()
	if kinds.has("soldier"):
		Sound.play_voice("move_out")
	if not kinds.is_empty():
		Sound.play_at("ramp_clank", landing.disembark_point(), -6.0)
	var time: float = 0.6
	for kind in kinds:
		_queue_entry(kind, landing, Vector3.ZERO, time)
		time += 1.7 if kind != "soldier" else 0.45

func _queue_entry(kind: String, landing: LandingCraft, point: Vector3, time: float) -> void:
	disembark_queue.append({"kind": kind, "craft": landing, "from_craft": landing != null, "point": point, "time": time})

func _tick_disembark(delta: float) -> void:
	var index: int = 0
	while index < disembark_queue.size():
		var entry: Dictionary = disembark_queue[index]
		entry.time = float(entry.time) - delta
		if float(entry.time) > 0.0:
			index += 1
			continue
		disembark_queue.remove_at(index)
		_spawn_entry(entry)

func _spawn_entry(entry: Dictionary) -> void:
	var point: Vector3 = entry.point
	if bool(entry.from_craft):
		var landing = entry.craft
		if not is_instance_valid(landing):
			return
		point = (landing as LandingCraft).disembark_point()
		Sound.play_at("splash", point, -10.0)
	if String(entry.kind) == "soldier":
		_spawn_soldier(point)
	else:
		_spawn_vehicle(point, String(entry.kind))

## Skips the landing sequence for headless tests and the smoke driver.
func disembark_all_now() -> void:
	for landing in crafts:
		if is_instance_valid(landing):
			landing.ground_now()
		_unload(landing)
	_tick_disembark(1000.0)

func _spawn_soldier(point: Vector3) -> void:
	var soldier := EnemySoldier.new()
	add_child(soldier)
	var spawn: Vector3 = point + Vector3(randf_range(-1.1, 1.1), 0.0, randf_range(-0.9, 0.9))
	soldier.configure(spawn, emplacement + Vector3(randf_range(-6, 6), 0, randf_range(-4, 4)), battlefield.random_cover())
	soldier.speed = 2.4 + current_wave * 0.3
	soldier.died.connect(func(_s): _register_kill())
	soldier.died.connect(_on_soldier_down)
	soldier.suppressed.connect(_on_soldier_suppressed)
	soldier.shoot_requested.connect(_on_enemy_shoot)
	soldiers.append(soldier)

func _spawn_vehicle(spawn: Vector3, kind: String) -> void:
	var vehicle := EnemyVehicle.new()
	add_child(vehicle)
	vehicle.configure(spawn, emplacement, kind)
	vehicle.died.connect(_on_vehicle_destroyed)
	vehicle.shoot_requested.connect(_on_enemy_heavy_shoot)
	vehicles.append(vehicle)

func _spawn_aircraft(kind: String, phase: float) -> void:
	var plane := EnemyAircraft.new()
	add_child(plane)
	plane.configure(emplacement, kind, phase)
	plane.died.connect(_on_aircraft_destroyed)
	plane.shoot_requested.connect(_on_enemy_heavy_shoot)
	aircraft.append(plane)

## Radio lines for infantry: a man going down is called out, sometimes with a medic request.
func _on_soldier_down(soldier: EnemySoldier) -> void:
	Sound.play_voice("man_down" if randf() < 0.6 else "medic")

## Near fire and blasts make the squad dive for cover; the radio channel rate-limits this.
func _on_soldier_suppressed(_soldier: EnemySoldier) -> void:
	Sound.play_voice("get_down" if randf() < 0.5 else "take_cover")

func _register_kill() -> void:
	kills += 1
	waves.register_kill()

func _on_vehicle_destroyed(vehicle: EnemyVehicle) -> void:
	_register_kill()
	_explode(vehicle.global_position + Vector3.UP * 1.2, Vector3.UP, 7.0)

func _on_aircraft_destroyed(plane: EnemyAircraft) -> void:
	_register_kill()
	effects.explode(plane.global_position, Vector3.UP, 8.0, CoastalTerrain.height_at(plane.global_position.x, plane.global_position.z))
	Sound.play_at("explosion", plane.global_position, -4.0)

func _on_craft_destroyed(landing: LandingCraft) -> void:
	_register_kill()
	_explode(landing.global_position + Vector3.UP, Vector3.UP, 8.0)
	# A craft sunk on the way in still lands its troops and vehicles in the surf.
	_unload(landing)

func _on_enemy_shoot(soldier: EnemySoldier, target: Vector3) -> void:
	if not active or soldier.is_dead():
		return
	soldier.play_fire()
	var muzzle: Node3D = soldier.find_child("Muzzle", true, false) as Node3D
	var origin: Vector3 = muzzle.global_position if muzzle else soldier.global_position + Vector3.UP * 1.45
	Sound.play_at("hmg", origin, -16.0, randf_range(0.94, 1.06))
	if not contact_called:
		contact_called = true
		Sound.play_voice("contact")
	var direction: Vector3 = (target + Vector3.UP * 1.2 - origin).normalized()
	var spread: float = deg_to_rad(1.1)
	direction = direction.rotated(Vector3.UP, randf_range(-spread, spread))
	direction = direction.rotated(Vector3.RIGHT, randf_range(-spread, spread)).normalized()
	# Real projectile damage: terrain/cover/player mask, never friendly infantry.
	bullets.launch(origin, direction * 300.0, randf_range(12.0, 22.0), 0.0, 13, [soldier.get_rid()])
	effects.explode(origin, direction, 0.4, origin.y, true)

func _on_enemy_heavy_shoot(origin: Vector3, target: Vector3, damage: float, blast: float) -> void:
	if not active:
		return
	var direction: Vector3 = (target + Vector3.UP * 1.2 - origin).normalized()
	Sound.play_at("cannon", origin, -12.0, 0.8)
	Sound.play_voice("incoming")
	bullets.launch(origin, direction * 160.0, damage * randf_range(0.85, 1.15), blast, 13)
	effects.explode(origin, direction, 1.2, origin.y, true)

func _on_weapon_fired(origin: Vector3, _direction: Vector3, weapon_id: String) -> void:
	var data: Dictionary = CoastalWeapon.WEAPONS[weapon_id]
	var aim_direction: Vector3 = -camera.global_transform.basis.z
	var target: Vector3 = camera.global_position + aim_direction * 500.0
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, target, 7)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = hit.position
	var direction: Vector3 = (target - origin).normalized()
	# Apply the weapon's cone once, around the camera's own axes, so vertical
	# aim does not turn horizontal spread into a world-Y corkscrew.
	var spread: float = deg_to_rad(float(data.spread))
	var basis: Basis = camera.global_transform.basis
	direction = direction.rotated(basis.y.normalized(), randf_range(-spread, spread))
	direction = direction.rotated(basis.x.normalized(), randf_range(-spread, spread)).normalized()
	bullets.launch(origin, direction * float(data.speed), float(data.damage), float(data.blast), 7)
	if float(data.blast) > 0.0:
		effects.explode(origin, direction, 1.4, origin.y, true)

func _on_barrel_exploded(point: Vector3, radius: float) -> void:
	_explode(point, Vector3.UP, radius)

func _on_bullet_impact(point: Vector3, normal: Vector3, collider: Object, damage: float, blast: float) -> void:
	var killed: bool = false
	if collider == player_hitbox:
		# The hitbox surrounds the camera, so world-space decals/smoke here would
		# stick to the lens. Feedback is the HUD damage flash + shake + sound;
		# blast still splashes nearby hostiles without painting the screen.
		_damage_player(damage)
		if blast > 0.0:
			_explode_damage(point, blast)
			camera_shake = maxf(camera_shake, 0.7)
			Sound.play_at("explosion", point, -6.0)
		else:
			camera_shake = maxf(camera_shake, 0.28)
			Sound.play_at("impact", point, -10.0)
		return
	if collider and collider.has_method("receive_damage") and damage > 0.0:
		if collider is EnemySoldier:
			collider.call("receive_damage", damage, point, -normal)
		else:
			collider.call("receive_damage", damage)
		if collider.has_method("is_dead"):
			killed = bool(collider.call("is_dead"))
		hud.confirm_hit(killed)
	if blast > 0.0:
		_explode(point, normal, blast)
		if not killed:
			hud.confirm_hit(false)
		return
	effects.explode(point, normal, 0.55, point.y, true)
	Sound.play_at("impact", point, -18.0)

## Ground blasts are anchored to the terrain or sea surface, so a shell that
## strikes a craft's hull or a tank's turret does not leave a cloud hanging in the air.
func _explode(point: Vector3, _normal: Vector3, radius: float) -> void:
	var grounded: Vector3 = _blast_point(point)
	effects.explode(grounded, Vector3.UP, radius, grounded.y - 0.08)
	Sound.play_at("explosion", grounded, -4.0)
	_explode_damage(grounded, radius)

func _blast_point(point: Vector3) -> Vector3:
	var ground: float = maxf(CoastalTerrain.height_at(point.x, point.z), 0.0)
	return Vector3(point.x, ground + 0.08, point.z)

func _explode_damage(point: Vector3, radius: float, hurt_player: bool = true) -> void:
	for soldier in soldiers:
		if is_instance_valid(soldier) and not soldier.is_dead():
			soldier.react_to_explosion(point, radius)
	for vehicle in vehicles:
		if is_instance_valid(vehicle) and not vehicle.is_dead():
			vehicle.react_to_explosion(point, radius)
	for plane in aircraft:
		if is_instance_valid(plane) and not plane.is_dead():
			plane.react_to_explosion(point, radius)
	for landing in crafts:
		if is_instance_valid(landing) and not landing.is_dead():
			landing.react_to_explosion(point, radius)
	for barrel in battlefield.barrels:
		if is_instance_valid(barrel) and not barrel.destroyed and barrel.global_position.distance_to(point) < radius * 1.4:
			barrel.receive_damage(80.0)
	if hurt_player and point.distance_to(emplacement) < radius * 0.8:
		_damage_player(120.0)

func _damage_player(amount: float) -> void:
	if not active:
		return
	player_health = maxf(0.0, player_health - amount * DAMAGE_SCALE)
	hud.flash_damage()
	if player_health <= 0.0:
		_finish(false)

func living_targets() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for group in [soldiers, vehicles, aircraft, crafts]:
		for node in group:
			if is_instance_valid(node) and not node.is_dead():
				result.append(node)
	return result

func _on_mission_finished(success: bool) -> void:
	_finish(success)

func _finish(success: bool) -> void:
	if not active:
		return
	active = false
	firing = false
	var survived: int = waves.round_index + 1 if success else waves.round_index
	hud.show_result(success, {"round": survived, "kills": kills, "time": elapsed})
	mission_finished.emit(success)

func _unhandled_input(event: InputEvent) -> void:
	if paused or not active:
		return
	if event is InputEventScreenDrag:
		aim_drag(event.relative)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		aim_drag(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		firing = event.pressed
	elif event is InputEventKey and event.keycode == KEY_SPACE:
		firing = event.pressed
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R: reload()
			KEY_Z: toggle_zoom()
			KEY_Q: cycle_weapon()
			KEY_F: set_auto_fire(not auto_fire)
			KEY_1: use_support("repair")
			KEY_2: use_support("airstrike")
			KEY_3: use_support("helicopter")
			KEY_4: use_support("airdrop")

func _process(delta: float) -> void:
	if paused:
		return
	_smooth_camera(delta)
	if not active:
		return
	elapsed += delta
	distant_clock += delta
	waves.tick(delta)
	background.tick(delta)
	for landing in crafts:
		if is_instance_valid(landing):
			landing.tick(delta)
	weapon.tick(delta)
	_tick_disembark(delta)
	for id in support_timers:
		support_timers[id] = maxf(0.0, float(support_timers[id]) - delta)
	_tick_airstrikes(delta)
	_tick_support_flights(delta)
	if (firing or auto_fire) and weapon.can_fire():
		weapon.try_fire()
	if weapon.ammo <= 0 and weapon.reload_remaining <= 0.0:
		if auto_reload_delay < 0.0:
			auto_reload_delay = 0.45
		auto_reload_delay -= delta
		if auto_reload_delay <= 0.0:
			weapon.start_reload()
			auto_reload_delay = -1.0
	else:
		auto_reload_delay = -1.0
	if distant_clock > 6.0:
		distant_clock = 0.0
		var point := Vector3(randf_range(-180, 180), 0.0, randf_range(-160, -80))
		point.y = maxf(0.0, CoastalTerrain.height_at(point.x, point.z))
		effects.explode(point, Vector3.UP, randf_range(3.0, 6.0), point.y)
	hud.update_state(_state())

func _tick_airstrikes(delta: float) -> void:
	for index in range(airstrike_queue.size() - 1, -1, -1):
		var strike: Dictionary = airstrike_queue[index]
		strike.time -= delta
		if strike.time <= 0.0:
			var point: Vector3 = strike.point
			point.y = CoastalTerrain.height_at(point.x, point.z)
			_explode(point, Vector3.UP, 9.0)
			airstrike_queue.remove_at(index)

func _tick_support_flights(delta: float) -> void:
	for index in range(support_flights.size() - 1, -1, -1):
		var flight: Dictionary = support_flights[index]
		var node: Node3D = flight.node
		if not is_instance_valid(node):
			support_flights.remove_at(index)
			continue
		flight.age += delta
		node.global_position += flight.direction * float(flight.speed) * delta
		if flight.rotor and is_instance_valid(flight.rotor):
			flight.rotor.rotation.y += delta * 24.0
		if flight.kind == "helicopter" and float(flight.age) >= float(flight.next_strike):
			flight.next_strike += 0.9
			var target: Node3D = _nearest_ground_target()
			if target:
				airstrike_queue.append({"time": 0.35, "point": target.global_position})
		if float(flight.age) >= float(flight.duration):
			node.queue_free()
			support_flights.remove_at(index)

func _smooth_camera(delta: float) -> void:
	var weight: float = 1.0 - exp(-delta * 10.0)
	yaw_current = wrapf(yaw_current + wrapf(yaw_target - yaw_current, -180.0, 180.0) * weight, -180.0, 180.0)
	pitch_current = lerpf(pitch_current, pitch_target, weight)
	aim_yaw.rotation.y = deg_to_rad(yaw_current)
	aim_pitch.rotation.x = deg_to_rad(pitch_current)
	camera.fov = lerpf(camera.fov, 30.0 if zoomed else 60.0, weight)
	if camera_shake > 0.0:
		camera_shake = maxf(0.0, camera_shake - delta * 2.4)
		var amp: float = camera_shake * 0.05
		camera.position = Vector3(randf_range(-amp, amp), randf_range(-amp, amp), 0.0)
		camera.rotation.z = randf_range(-amp, amp) * 0.5
	else:
		camera.position = Vector3.ZERO
		camera.rotation.z = 0.0

func _state() -> Dictionary:
	var bearing: float = 0.0
	var distance: float = 0.0
	var nearest: Node3D = null
	var best: float = INF
	for node in living_targets():
		var d: float = node.global_position.distance_to(emplacement)
		if d < best:
			best = d
			nearest = node
	if nearest:
		var offset: Vector3 = nearest.global_position - camera.global_position
		bearing = wrapf(rad_to_deg(atan2(-offset.x, -offset.z)) - yaw_current, -180.0, 180.0)
		distance = best
	return {"zoomed": zoomed, "zoom_factor": zoom_factor(), "mission": "TIDE WALL", "label": waves.current_label(), "remaining": waves.remaining, "round": waves.round_index + 1, "rounds": waves.total_rounds(), "time": elapsed, "health": player_health, "health_max": MAX_HEALTH, "ammo": weapon.ammo, "magazine": int(weapon.config().magazine), "reserve": weapon.reserve, "weapon": String(weapon.config().display), "weapon_id": weapon.weapon_id, "reloading": weapon.reload_remaining > 0.0, "auto": auto_fire, "supports": waves.supports(), "support_cooldowns": support_timers.duplicate(), "support_charges": support_charges.duplicate(), "intermission": waves.intermission, "threat_bearing": bearing, "threat_distance": distance}
