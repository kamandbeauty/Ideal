extends RefCounted

func run(t: TestContext) -> void:
	t.check(CoastalWeapon.ORDER.size() == 5, "Five mounted weapon types include machine guns, cannon, rocket, bazooka and autocannon")
	t.check(bool(CoastalWeapon.WEAPONS.twin_hmg.automatic), "Twin heavy machine gun supports automatic fire")
	t.check(float(CoastalWeapon.WEAPONS.rocket.blast) > 0.0, "Rocket ammunition has blast radius")
	t.check(float(CoastalWeapon.WEAPONS.bazooka.damage) > float(CoastalWeapon.WEAPONS.rocket.damage), "Bazooka is a distinct heavier anti-armor weapon")
	t.equal(WaveManager.target_count(WaveManager.ROUNDS[0]), 11, "First wave combines infantry, armor, aircraft and landing craft")
	t.check("airstrike" in WaveManager.ROUNDS[0].support, "Airstrike is available in the first playable scene")
	var waves := WaveManager.new()
	var finished: Array[bool] = []
	waves.mission_finished.connect(func(success): finished.append(success))
	waves.start()
	t.equal(waves.remaining, 11, "First landing wave fields eleven destructible targets")
	for index in range(waves.remaining):
		waves.register_kill()
	t.check(waves.intermission > 0.0, "Clearing a wave starts an intermission")
	waves.tick(WaveManager.INTERMISSION + 0.1)
	t.equal(waves.round_index, 1, "Clearing a wave advances the round")
	t.equal(waves.remaining, 18, "Second wave increases combined-arms pressure")
	for round_index in range(1, 3):
		for index in range(waves.remaining):
			waves.register_kill()
		waves.tick(WaveManager.INTERMISSION + 0.1)
	t.equal(finished, [true], "Surviving all rounds completes the mission")
	var soldier := EnemySoldier.new()
	t.tree.root.add_child(soldier)
	soldier.configure(Vector3(0, 0, -20), Vector3(0, 0, 40), Vector3(4, 0, 20))
	soldier.receive_damage(200.0)
	t.check(soldier.is_dead(), "Soldier health state reaches death")
	soldier.queue_free()
	var scene: CoastalController = load("res://scenes/coastal/coastal_milestone.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	t.check(scene.soldiers.size() >= 8, "Playable milestone spawns animated infantry")
	t.check(scene.vehicles.size() >= 1, "Playable milestone includes a destructible tank")
	t.check(scene.aircraft.size() >= 1, "Playable milestone includes a hostile aircraft")
	t.check(scene.crafts.size() >= 1, "Playable milestone includes landing craft")
	t.equal(scene.living_targets().size(), scene.waves.remaining, "Enemy counter matches living hostile targets")
	var bounds: Rect2 = scene.weapon.screen_bounds(scene.camera)
	var viewport_height: float = scene.get_viewport().get_visible_rect().size.y
	t.check(bounds.position.y > viewport_height * 0.35, "Weapon viewmodel stays in the lower foreground instead of covering the battlefield")
	for muzzle in scene.weapon.muzzles:
		t.check(scene.weapon.to_local(muzzle.global_position).z < -1.0, "Muzzle remains forward of the first-person camera")
	for index in range(30):
		scene.weapon.tick(0.05)
	for muzzle in scene.weapon.muzzles:
		t.check(scene.weapon.to_local(muzzle.global_position).z < -1.0, "Twin barrels do not rotate backward into the camera")
	var anchor: Vector3 = scene.aim_yaw.global_position
	scene.aim_drag(Vector2(240.0, -40.0))
	scene._process(0.1)
	t.check(scene.aim_yaw.global_position.is_equal_approx(anchor), "Player remains at a fixed defensive position")
	var zones: Array[Vector3] = scene._spawn_zones(3)
	var left: bool = false
	var right: bool = false
	for zone in zones:
		var offset: Vector3 = zone - scene.emplacement
		var bearing: float = rad_to_deg(atan2(-offset.x, -offset.z))
		left = left or bearing > 60.0
		right = right or bearing < -60.0
	t.check(left and right, "Later waves attack from multiple flanking directions")
	scene.weapon.cooldown = 0.0
	var ammo: int = scene.weapon.ammo
	t.check(scene.fire_once(), "Mounted weapon fires")
	t.equal(scene.weapon.ammo, ammo - 1, "Firing consumes ammunition")
	scene.set_auto_fire(true)
	t.check(scene.auto_fire, "Automatic fire toggle state is exposed")
	scene.set_auto_fire(false)
	scene.use_support("airstrike")
	t.check(scene.airstrike_queue.size() == 5, "Airstrike queues a bomb run in round one")
	t.equal(int(scene.support_charges.airstrike), 1, "Support consumes a charge")
	scene._damage_player(500.0)
	scene.use_support("repair")
	t.check(scene.player_health > 2500.0, "Repair remains usable while airstrike is cooling down")
	var tank: EnemyVehicle = scene.vehicles[0]
	tank.receive_damage(10000.0)
	t.check(tank.is_dead(), "Tank can be destroyed by player damage")
	for round_index in range(3):
		for target in scene.living_targets():
			if is_instance_valid(target) and not target.is_dead():
				target.receive_damage(100000.0)
		scene.waves.tick(WaveManager.INTERMISSION + 0.1)
	t.check(not scene.active, "Mission stops after the final wave")
	t.check(scene.hud.result_panel.visible, "Victory results are presented")
	t.check(scene.kills >= 50, "Success requires destroying the combined-arms waves")
	scene.restart()
	t.check(scene.active and scene.waves.remaining == 11, "Restart rebuilds a fresh first wave")
	t.equal(int(scene.support_charges.airstrike), 2, "Restart restores support charges")
	scene.queue_free()
	await t.tree.process_frame
