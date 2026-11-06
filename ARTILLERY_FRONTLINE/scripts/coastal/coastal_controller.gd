class_name CoastalController
extends Node3D
## Playable first visual milestone: first-person mounted weapons on a coastal beachhead.
signal exit_requested
signal mission_finished(success: bool)

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
var soldiers: Array[EnemySoldier] = []
var active: bool = false
var paused: bool = false
var auto_fire: bool = false
var firing: bool = false
var zoomed: bool = false
var player_health: float = 100.0
var elapsed: float = 0.0
var kills: int = 0
var yaw_target: float = 0.0
var pitch_target: float = -4.0
var yaw_current: float = 0.0
var pitch_current: float = -4.0
var support_timers: Dictionary = {"repair": 0.0, "airstrike": 0.0, "helicopter": 0.0, "airdrop": 0.0}
var airstrike_queue: Array[Dictionary] = []
var distant_clock: float = 0.0
var auto_reload_delay: float = -1.0
var emplacement := Vector3(0, 0, 58)

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
	weapon = CoastalWeapon.new()
	camera.add_child(weapon)
	weapon.position = Vector3(0.0, -0.48, -0.85)
	weapon.fired.connect(_on_weapon_fired)
	hud = CoastalHUD.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	_connect_hud()
	waves = WaveManager.new()
	add_child(waves)
	waves.round_started.connect(_on_round_started)
	waves.mission_finished.connect(_on_mission_finished)
	craft = LandingCraft.new()
	add_child(craft)
	craft.configure(Vector3(0, 0, -190), Vector3(0, 0, -18))
	start()

func _build_camera() -> void:
	aim_yaw = Node3D.new()
	aim_yaw.name = "AimYaw"
	aim_yaw.position = emplacement + Vector3.UP * 1.2
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
	player_health = 100.0
	elapsed = 0.0
	kills = 0
	waves.start()

func restart() -> void:
	get_tree().paused = false
	for soldier in soldiers:
		if is_instance_valid(soldier):
			soldier.queue_free()
	soldiers.clear()
	bullets.clear()
	effects.clear()
	weapon.resupply()
	hud.result_panel.visible = false
	hud.set_paused(false)
	craft.has_arrived = false
	craft.progress = 0.0
	craft.global_position = craft.start
	start()

func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	hud.set_paused(value)

func aim_drag(relative: Vector2) -> void:
	if paused or not active:
		return
	var sensitivity: float = float(Profile.data.settings.sensitivity)
	yaw_target = clampf(yaw_target - relative.x * 0.08 * sensitivity, -78.0, 78.0)
	pitch_target = clampf(pitch_target - relative.y * 0.06 * sensitivity, -28.0, 32.0)

func set_auto_fire(enabled: bool) -> void:
	auto_fire = enabled

func toggle_zoom() -> void:
	zoomed = not zoomed

func cycle_weapon() -> void:
	weapon.cycle()

func reload() -> void:
	weapon.start_reload()

func fire_once() -> bool:
	return weapon.try_fire()

func use_support(id: String) -> void:
	if not active or paused or not id in waves.supports() or float(support_timers.get(id, 0.0)) > 0.0:
		return
	match id:
		"repair":
			player_health = minf(100.0, player_health + 38.0)
			support_timers[id] = 18.0
			Sound.play_ui("reload")
		"airstrike":
			support_timers[id] = 26.0
			var target: Vector3 = _aim_ground_point(180.0)
			for index in range(5):
				airstrike_queue.append({"time": 1.1 + index * 0.18, "point": target + Vector3((index - 2) * 9.0, 0, -index * 4.0)})
		"helicopter":
			support_timers[id] = 34.0
			for soldier in soldiers:
				if is_instance_valid(soldier) and not soldier.is_dead():
					airstrike_queue.append({"time": 0.6 + randf() * 1.2, "point": soldier.global_position})
		"airdrop":
			support_timers[id] = 30.0
			weapon.resupply()
			player_health = minf(100.0, player_health + 12.0)

func _aim_ground_point(max_distance: float) -> Vector3:
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_distance, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	return origin + direction * 120.0

func _on_round_started(round_number: int, setup: Dictionary) -> void:
	var count: int = int(setup.soldiers)
	for index in range(count):
		var zone: Vector3 = battlefield.landing_zones[index % battlefield.landing_zones.size()]
		var spawn: Vector3 = zone + Vector3(randf_range(-14.0, 14.0), 0.0, randf_range(-8.0, 8.0) - index * 1.5)
		spawn.y = CoastalTerrain.height_at(spawn.x, spawn.z)
		var soldier := EnemySoldier.new()
		add_child(soldier)
		soldier.configure(spawn, emplacement + Vector3(randf_range(-8, 8), 0, randf_range(-4, 4)), battlefield.random_cover())
		soldier.died.connect(_on_soldier_died)
		soldier.shoot_requested.connect(_on_enemy_shoot)
		soldiers.append(soldier)
	if round_number == 1:
		craft.configure(Vector3(0, 0, -190), Vector3(0, 0, -18))
	else:
		craft.has_arrived = false
		craft.progress = 0.0
		craft.configure(Vector3(-42, 0, -200), Vector3(-42, 0, -24))

func _on_soldier_died(_soldier: EnemySoldier) -> void:
	kills += 1
	waves.register_kill()

func _on_enemy_shoot(soldier: EnemySoldier, target: Vector3) -> void:
	if not active or soldier.is_dead():
		return
	var origin: Vector3 = soldier.global_position + Vector3.UP * 1.45
	var direction: Vector3 = (target + Vector3.UP * 1.2 - origin).normalized()
	bullets.launch(origin, direction * 300.0, 0.0, 0.0)
	var distance: float = origin.distance_to(target)
	if randf() < clampf(0.55 - distance / 400.0, 0.08, 0.5):
		player_health = maxf(0.0, player_health - randf_range(1.5, 3.5))
		hud.flash_damage()
		if player_health <= 0.0:
			_finish(false)

func _on_weapon_fired(origin: Vector3, direction: Vector3, weapon_id: String) -> void:
	var data: Dictionary = CoastalWeapon.WEAPONS[weapon_id]
	bullets.launch(origin, direction * float(data.speed), float(data.damage), float(data.blast))
	if float(data.blast) > 0.0:
		effects.explode(origin, direction, 1.4, origin.y, true)

func _on_barrel_exploded(point: Vector3, radius: float) -> void:
	_explode(point, Vector3.UP, radius)

func _on_bullet_impact(point: Vector3, normal: Vector3, collider: Object, damage: float, blast: float) -> void:
	if blast > 0.0:
		_explode(point, normal, blast)
		return
	if collider and collider.has_method("receive_damage"):
		collider.call("receive_damage", damage)
	effects.explode(point, normal, 0.55, point.y, true)
	Sound.play_at("impact", point, -18.0)

func _explode(point: Vector3, normal: Vector3, radius: float) -> void:
	effects.explode(point, normal, radius, CoastalTerrain.height_at(point.x, point.z))
	Sound.play_at("explosion", point, -4.0)
	for soldier in soldiers:
		if is_instance_valid(soldier) and not soldier.is_dead():
			soldier.react_to_explosion(point, radius)
	for barrel in battlefield.barrels:
		if is_instance_valid(barrel) and barrel.global_position.distance_to(point) < radius * 1.4:
			barrel.receive_damage(80.0)
	if point.distance_to(emplacement) < radius * 0.8:
		player_health = maxf(0.0, player_health - 12.0)
		hud.flash_damage()

func _on_mission_finished(success: bool) -> void:
	_finish(success)

func _finish(success: bool) -> void:
	if not active:
		return
	active = false
	firing = false
	hud.show_result(success, {"round": waves.round_index + 1, "kills": kills, "time": elapsed})
	mission_finished.emit(success)

func _unhandled_input(event: InputEvent) -> void:
	if paused or not active:
		return
	if event is InputEventScreenDrag:
		aim_drag(event.relative)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		aim_drag(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: firing = true
			KEY_R: reload()
			KEY_Z: toggle_zoom()
			KEY_Q: cycle_weapon()
			KEY_F: set_auto_fire(not auto_fire)

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
	craft.tick(delta)
	weapon.tick(delta)
	for id in support_timers:
		support_timers[id] = maxf(0.0, float(support_timers[id]) - delta)
	for index in range(airstrike_queue.size() - 1, -1, -1):
		var strike: Dictionary = airstrike_queue[index]
		strike.time -= delta
		if strike.time <= 0.0:
			var point: Vector3 = strike.point
			point.y = CoastalTerrain.height_at(point.x, point.z)
			_explode(point, Vector3.UP, 8.0)
			airstrike_queue.remove_at(index)
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
	if distant_clock > 5.0:
		distant_clock = 0.0
		var point := Vector3(randf_range(-180, 180), 0.0, randf_range(-160, -80))
		point.y = maxf(0.0, CoastalTerrain.height_at(point.x, point.z))
		effects.explode(point, Vector3.UP, randf_range(3.0, 6.0), point.y)
	hud.update_state(_state())

func _smooth_camera(delta: float) -> void:
	var weight: float = 1.0 - exp(-delta * 10.0)
	yaw_current = lerpf(yaw_current, yaw_target, weight)
	pitch_current = lerpf(pitch_current, pitch_target, weight)
	aim_yaw.rotation.y = deg_to_rad(yaw_current)
	aim_pitch.rotation.x = deg_to_rad(pitch_current)
	camera.fov = lerpf(camera.fov, 30.0 if zoomed else 60.0, weight)

func _state() -> Dictionary:
	var any_cooldown: bool = false
	for id in support_timers:
		if float(support_timers[id]) > 0.0:
			any_cooldown = true
	return {"mission": "TIDE WALL", "remaining": waves.remaining, "round": waves.round_index + 1, "rounds": waves.total_rounds(), "time": elapsed, "health": player_health, "ammo": weapon.ammo, "magazine": int(weapon.config().magazine), "weapon": String(weapon.config().display), "weapon_id": weapon.weapon_id, "reloading": weapon.reload_remaining > 0.0, "auto": auto_fire, "supports": waves.supports(), "support_cooldown": any_cooldown}
