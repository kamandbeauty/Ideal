extends SceneTree
## Dependency-free test runner. Run after the editor has scanned global classes.

var checks: int = 0
var failures: Array[String] = []
var _hit: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\nARTILLERY FRONTLINE — automated tests")
	_test_ballistics()
	_test_damage()
	_test_weapon_state()
	_test_mission()
	_test_save_recovery()
	_test_quality_policy()
	await _test_projectile_collision_and_prediction()
	await _test_vertical_slice()
	print("\n%d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("  PASS ", description)
	else:
		failures.append(description)
		printerr("  FAIL ", description)


func _test_ballistics() -> void:
	print("[ballistics]")
	var position := Vector3(1, 2, 3)
	var velocity := Vector3(5, 20, -12)
	var initial_position := position
	var initial_velocity := velocity
	for i in range(180):
		var state := Ballistics.advance(position, velocity, 1.0 / 60.0, 9.81)
		position = state.position
		velocity = state.velocity
	var expected := initial_position + initial_velocity * 3.0 + Vector3.DOWN * 0.5 * 9.81 * 9.0
	_check(position.distance_to(expected) < 0.01, "fixed-step trajectory matches analytic parabola")
	_check(absf(velocity.y - (20.0 - 9.81 * 3.0)) < 0.001, "gravity updates velocity")
	var no_drag := Ballistics.advance(Vector3.ZERO, Vector3(10, 0, 0), 1.0, 9.81, 0.0)
	var with_drag := Ballistics.advance(Vector3.ZERO, Vector3(10, 0, 0), 1.0, 9.81, 0.2)
	_check(with_drag.position.x < no_drag.position.x, "optional drag reduces travel")


func _test_damage() -> void:
	print("[damage]")
	_check(
		is_equal_approx(DamageModel.blast_damage(100, 10, 8, true), 100),
		"direct impact receives full damage"
	)
	_check(
		is_equal_approx(DamageModel.blast_damage(100, 10, 5, false), 50),
		"splash falls off linearly"
	)
	_check(DamageModel.blast_damage(100, 10, 10, false) == 0, "outside blast radius is safe")
	_check(DamageModel.blast_damage(100, 0, 0, false) == 0, "zero radius avoids division by zero")
	_check(DamageModel.range_factor(100, 145) == 1.0, "full damage inside effective range")
	_check(DamageModel.range_factor(290, 145) == 0.5, "damage falls off beyond effective range")


func _test_weapon_state() -> void:
	print("[weapon and reload]")
	var weapon := WeaponConfig.new()
	weapon.reload_seconds = 2.0
	var he := AmmoConfig.new()
	he.id = "he"
	he.starting_rounds = 2
	var ap := AmmoConfig.new()
	ap.id = "ap"
	ap.starting_rounds = 1
	var weapon_state := WeaponState.new()
	var types: Array[AmmoConfig] = [he, ap]
	weapon_state.setup(weapon, types)
	_check(weapon_state.can_fire(), "weapon starts chambered")
	_check(weapon_state.ammunition.size() == 2, "weapon accepts configured compatible ammunition")
	_check(
		weapon_state.fire() and weapon_state.current_rounds() == 1,
		"firing consumes exactly one round"
	)
	_check(not weapon_state.fire(), "cannot fire an empty chamber")
	_check(weapon_state.request_reload(), "reload starts")
	weapon_state.advance(1.9)
	_check(not weapon_state.can_fire(), "reload is not ready early")
	weapon_state.advance(0.11)
	_check(weapon_state.can_fire(), "reload chambers after configured duration")
	_check(
		weapon_state.select_ammo(1) and not weapon_state.can_fire(),
		"switching ammunition requires reloading"
	)
	_check(weapon_state.request_reload(), "new ammunition can be chambered")
	weapon_state.advance(2.0)
	_check(
		weapon_state.fire() and weapon_state.current_rounds() == 0,
		"selected ammunition uses its own inventory"
	)
	_check(not weapon_state.request_reload(), "cannot reload when the selected type is exhausted")


func _test_mission() -> void:
	print("[mission]")
	var state := MissionState.new()
	state.setup(2)
	state.record_shot()
	state.record_hit()
	state.target_destroyed(1)
	state.target_destroyed(1)
	_check(
		not state.is_complete and state.destroyed_ids.size() == 1,
		"duplicate target deaths do not advance objective"
	)
	state.target_destroyed(2)
	_check(
		state.is_complete and state.rating() == 3,
		"all objectives complete the mission and award a rating"
	)


func _test_save_recovery() -> void:
	print("[save and recovery]")
	var store := SaveStore.new()
	store.path = "user://frontline-automated-test.json"
	_clean_save(store.path)
	var data := store.load_data()
	_check(
		store.last_status == "new" and data.version == SaveStore.VERSION,
		"missing save produces versioned defaults"
	)
	data.settings.graphics = "HIGH"
	_check(store.save_data(data), "first local save succeeds")
	data.settings.graphics = "LOW"
	_check(store.save_data(data), "second save rotates backup")
	_check(store.load_data().settings.graphics == "LOW", "primary save round trips")
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	var recovered := store.load_data()
	_check(
		store.last_status == "backup" and recovered.settings.graphics == "HIGH",
		"corrupt primary recovers last good backup"
	)
	_check(store.save_data(recovered), "saving recovered data succeeds")
	file = FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string("invalid again")
	file.close()
	_check(
		store.load_data().settings.graphics == "HIGH",
		"recovery never overwrites the valid backup with corruption"
	)
	_clean_save(store.path)


func _test_quality_policy() -> void:
	print("[quality]")
	var policy := QualityPolicy.new()
	policy.configure("LOW", 30)
	_check(
		policy.profile().name == "LOW" and policy.profile().scale == 0.70,
		"manual low profile selects lower resolution"
	)
	policy.configure("HIGH", 60)
	_check(
		policy.profile().name == "HIGH" and policy.profile().shadows,
		"manual high profile enables shadows"
	)
	policy.configure("AUTO", 60)
	for i in range(220):
		policy.sample_frame(1.0 / 20.0)
	_check(policy.level == 0, "auto quality drops only after sustained slow windows")
	for i in range(1800):
		policy.sample_frame(1.0 / 80.0)
	_check(policy.level >= 1, "auto quality can recover after sustained headroom")


func _test_projectile_collision_and_prediction() -> void:
	print("[projectile integration]")
	var world := Node3D.new()
	root.add_child(world)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	world.add_child(ground)
	var shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(100, 1, 100)
	shape.shape = ground_box
	shape.position.y = -0.5
	ground.add_child(shape)
	await physics_frame
	await physics_frame
	var origin := Vector3(0, 3, 0)
	var velocity := Vector3(0, 0, -25)
	var prediction := Ballistics.trace(
		world.get_world_3d().direct_space_state, origin, velocity, 9.81
	)
	_check(
		prediction.hit and prediction.collider == ground, "trajectory ray detects world collision"
	)
	var projectile := ShellProjectile.new()
	world.add_child(projectile)
	_hit = {}
	projectile.impacted.connect(
		func(_p: ShellProjectile, point: Vector3, collider: Object, _a: AmmoConfig) -> void:
			_hit = {"point": point, "collider": collider}
	)
	projectile.launch(origin, velocity, AmmoConfig.new(), 9.81, 0.0)
	for i in range(120):
		await physics_frame
		if not _hit.is_empty():
			break
	_check(
		not _hit.is_empty() and _hit.get("collider") == ground,
		"live projectile reports swept collision"
	)
	if not _hit.is_empty():
		_check(
			(_hit.point as Vector3).distance_to(prediction.position) < 0.15,
			"predicted impact closely matches the live projectile"
		)
	else:
		_check(false, "predicted impact closely matches the live projectile")
	# A very fast shell crosses a thin body in a single frame; ray sweep must still hit.
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	world.add_child(wall)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(5, 5, 0.1)
	wall_shape.shape = wall_box
	wall_shape.position = Vector3(0, 2.5, -4)
	wall.add_child(wall_shape)
	await physics_frame
	await physics_frame
	_hit = {}
	projectile.launch(Vector3(0, 2, 0), Vector3(0, 0, -480), AmmoConfig.new(), 0.0, 0.0)
	for i in range(10):
		await physics_frame
		if not _hit.is_empty():
			break
	_check(
		not _hit.is_empty() and _hit.get("collider") == wall,
		"swept collision catches fast projectiles and thin targets"
	)
	world.queue_free()
	await process_frame


func _test_vertical_slice() -> void:
	print("[vertical slice integration]")
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	game.save_store.path = "user://frontline-integration-test.json"
	_clean_save(game.save_store.path)
	game.save_data = game.save_store.defaults()
	await physics_frame
	await physics_frame
	_check(
		game.gun != null and game.preview != null and game.projectiles.projectiles.size() == 6,
		"battlefield, artillery, prediction and bounded projectile pool initialize"
	)
	_check(get_nodes_in_group("damageable").size() == 3, "all three target types spawn")
	game.hud._open_licenses()
	_check(
		(
			game.hud._licenses_screen.visible
			and game.hud._licenses_text.text.contains("SIL OPEN FONT LICENSE")
			and game.hud._licenses_text.text.contains("Godot Engine")
		),
		"font and engine license notices are accessible in the menu"
	)
	game.hud.show_menu()
	game._start_mission()
	_check(game.mode == "active", "deploy starts the mission")
	var start_yaw: float = game.gun.yaw_degrees
	game.gun.aim_by_pixels(Vector2(30, -15))
	_check(game.gun.yaw_degrees != start_yaw, "aim input moves independent gun axes")
	var tank := game.get_node("Tank") as BattlefieldTarget
	var transport := game.get_node("Transport") as BattlefieldTarget
	var tank_start_x := tank.position.x
	game.gun.set_aim(0, 26)
	await physics_frame
	await physics_frame
	var before: int = game.gun.state.current_rounds()
	game._fire()
	_check(
		game.gun.state.current_rounds() == before - 1 and game.mission.shots_fired == 1,
		"fire action spawns a shell and consumes ammunition"
	)
	game._reload()
	_check(game.gun.state.reload_remaining > 0, "reload action starts the timer")
	var radar: BattlefieldTarget = game.get_node("Radar") as BattlefieldTarget
	for i in range(360):
		await physics_frame
		if radar.is_destroyed:
			break
	_check(
		radar.is_destroyed and game.mission.hits == 1,
		"fired shell actually destroys the radar target"
	)
	_check(absf(tank.position.x - tank_start_x) > 0.1, "patrolling targets move during combat")
	game._select_ammo(1)
	_check(await _fire_at_target(game, tank), "AP shell actually destroys the moving tank")
	_check(
		await _fire_at_target(game, transport), "AP shell actually destroys the moving transport"
	)
	_check(
		game.mission.is_complete and game.mode == "finishing",
		"destroying objectives triggers the result flow"
	)
	_check(FileAccess.file_exists(game.save_store.path), "mission completion writes a local record")
	await create_timer(1.5).timeout
	_check(game.mode == "results" and paused, "mission results appear after the final impact")
	paused = false
	_clean_save(game.save_store.path)
	game.queue_free()
	await process_frame


func _fire_at_target(game: Node3D, target: BattlefieldTarget) -> bool:
	game._reload()
	for i in range(200):
		await physics_frame
		if game.gun.state.can_fire():
			break
	if not game.gun.state.can_fire():
		return false
	var offset: Vector3 = target.global_position - game.gun.global_position
	var aimed := false
	# Lead a live patrol using its predicted future position. Search the actual
	# sampled chamber trajectory; this test never modifies target health or motion.
	for step in range(8 * 4, 65 * 4 + 1):
		var elevation: float = step * 0.25
		var yaw := rad_to_deg(atan2(-offset.x, -offset.z))
		var origin: Vector3
		var velocity: Vector3
		var flight_time := 0.0
		for iteration in range(4):
			game.gun.set_aim(yaw, elevation)
			origin = game.gun.muzzle_position()
			velocity = game.gun.launch_velocity()
			flight_time = (target.global_position.z - origin.z) / velocity.z
			var future_x := _patrol_x_at_time(target, flight_time)
			yaw = rad_to_deg(atan2(-(future_x - game.gun.global_position.x), -offset.z))
		if flight_time <= 0.0:
			continue
		var end_x := origin.x + velocity.x * flight_time
		var end_y: float = (
			origin.y
			+ velocity.y * flight_time
			- 0.5 * game.gun.config.gravity * flight_time * flight_time
		)
		if (
			absf(end_x - _patrol_x_at_time(target, flight_time)) < 1.5
			and end_y > 0.8
			and end_y < 3.4
		):
			aimed = true
			break
	if not aimed:
		return false
	game._fire()
	for i in range(480):
		await physics_frame
		if target.is_destroyed:
			return true
	return false


func _patrol_x_at_time(target: BattlefieldTarget, time: float) -> float:
	var x := target.position.x
	var direction := target._patrol_direction
	var minimum := target._home.x - target.patrol_extent
	var maximum := target._home.x + target.patrol_extent
	for i in range(maxi(0, int(ceil(time / Ballistics.STEP)))):
		x += direction * target.patrol_speed * Ballistics.STEP
		if x >= maximum:
			x = maximum
			direction = -1.0
		elif x <= minimum:
			x = minimum
			direction = 1.0
	return x


func _clean_save(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
