extends RefCounted

func run(t: TestContext) -> void:
	t.check(CoastalWeapon.ORDER.size() == 5, "Five mounted weapon types include machine guns, cannon, rocket, bazooka and autocannon")
	t.check(bool(CoastalWeapon.WEAPONS.twin_hmg.automatic), "Twin heavy machine gun supports automatic fire")
	t.check(float(CoastalWeapon.WEAPONS.rocket.blast) > 0.0, "Rocket ammunition has blast radius")
	t.check(float(CoastalWeapon.WEAPONS.bazooka.damage) > float(CoastalWeapon.WEAPONS.rocket.damage), "Bazooka is a distinct heavier anti-armor weapon")
	t.equal(WaveManager.target_count(WaveManager.ROUNDS[0]), 11, "First wave combines infantry, armor, aircraft and landing craft")
	t.check(TargetLock.bracket_size(10.0) == 84.0 and TargetLock.bracket_size(5000.0) == 26.0, "Target lock brackets clamp between 26 and 84 px")
	t.check(TargetLock.bracket_size(20.0) > TargetLock.bracket_size(30.0), "Target lock brackets shrink with range")
	t.equal(WaveManager.target_count(WaveManager.ROUNDS[1]), 20, "Armored push adds a second helicopter and fighter pair")
	t.equal(WaveManager.target_count(WaveManager.ROUNDS[2]), 29, "Final assault brings 20 infantry, two tanks and four aircraft")
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
	t.equal(waves.remaining, 20, "Second wave increases combined-arms pressure")
	for round_index in range(1, 3):
		for index in range(waves.remaining):
			waves.register_kill()
		waves.tick(WaveManager.INTERMISSION + 0.1)
	t.equal(finished, [true], "Surviving all rounds completes the mission")
	var soldier := EnemySoldier.new()
	t.tree.root.add_child(soldier)
	soldier.configure(Vector3(0, 0, -20), Vector3(0, 0, 40), Vector3(4, 0, 20))
	t.equal(soldier.max_health, EnemySoldier.BASE_HEALTH, "Infantry uses the reduced health pool")
	t.check(soldier.max_health <= float(CoastalWeapon.WEAPONS.twin_hmg.damage), "One heavy-MG body hit is enough to drop infantry")
	soldier.receive_damage(float(CoastalWeapon.WEAPONS.twin_hmg.damage))
	t.check(soldier.is_dead(), "One heavy-MG body hit kills infantry")
	t.check(EnemyVehicle.TANK_HEALTH <= 2.0 * 0.9 * float(CoastalWeapon.WEAPONS.cannon.damage) and EnemyVehicle.TANK_HEALTH > 0.9 * float(CoastalWeapon.WEAPONS.cannon.damage), "Two cannon hits destroy a tank")
	t.check(EnemyVehicle.TRANSPORT_HEALTH <= 0.9 * float(CoastalWeapon.WEAPONS.cannon.damage), "One cannon hit destroys a transport")
	t.check(ExplosionEffect.SMOKE_LIFE <= 3.5 and ExplosionEffect.EFFECT_LIFE <= 4.0, "Explosion smoke fades out within a few seconds")
	soldier.queue_free()
	var head_target := EnemySoldier.new()
	t.tree.root.add_child(head_target)
	head_target.configure(Vector3(0, 0, -20), Vector3(0, 0, 40), Vector3(4, 0, 20))
	head_target.receive_damage(float(CoastalWeapon.WEAPONS.twin_hmg.damage), head_target.global_position + Vector3.UP * 1.6)
	t.check(head_target.is_dead(), "A heavy-MG head hit drops infantry immediately")
	head_target.queue_free()
	var scene: CoastalController = load("res://scenes/coastal/coastal_milestone.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	t.check(scene.soldiers.size() == 0 and scene.crafts[0].cargo.size() >= 9, "Infantry and armour wait inside the landing craft until it grounds")
	scene.disembark_all_now()
	t.check(scene.soldiers.size() >= 8, "Playable milestone spawns animated infantry")
	t.check(scene.disembark_queue.is_empty(), "Every unit leaves the landing craft")
	t.check(scene.vehicles.size() >= 1, "Playable milestone includes a destructible tank")
	t.check(scene.aircraft.size() >= 1, "Playable milestone includes a hostile aircraft")
	t.check(scene.crafts.size() >= 1, "Playable milestone includes landing craft")
	t.equal(scene.living_targets().size(), scene.waves.remaining, "Enemy counter matches living hostile targets")
	var grounded: Vector3 = scene._blast_point(Vector3(3.0, 7.0, 20.0))
	t.near(grounded.y, CoastalTerrain.height_at(3.0, 20.0) + 0.08, 0.001, "A shell burst on the beach is anchored to the ground, not the air")
	var sea_burst: Vector3 = scene._blast_point(Vector3(0.0, 3.0, -40.0))
	t.near(sea_burst.y, 0.08, 0.001, "A burst over the sea sits on the water surface")
	var bounds: Rect2 = scene.weapon.screen_bounds(scene.camera)
	var viewport_size: Vector2 = scene.get_viewport().get_visible_rect().size
	var viewport_height: float = viewport_size.y
	t.check(bounds.position.y > viewport_height * 0.35, "Weapon viewmodel stays in the lower foreground instead of covering the battlefield")
	t.check(scene.weapon.recoil_nodes.size() >= 1, "Weapon exposes at least one recoil pivot")
	if scene.weapon.model_root and scene.weapon.model_root.find_child("RecoilL", true, false):
		t.equal(scene.weapon.recoil_nodes.size(), 2, "Twin HMG animates each barrel independently")
		t.equal(scene.weapon.cover_nodes.size(), 2, "Twin HMG has hinged feed covers for reload")
		t.equal(scene.weapon.ejection_markers.size(), 2, "Twin HMG ejects brass from receiver ports")
	var muzzle_screens: Array[Vector2] = []
	for muzzle in scene.weapon.muzzles:
		muzzle_screens.append(scene.camera.unproject_position(muzzle.global_position))
	if muzzle_screens.size() == 2:
		t.check(absf(muzzle_screens[0].x - muzzle_screens[1].x) > viewport_size.x * 0.04, "Twin muzzles remain visually separated on screen")
		for point in muzzle_screens:
			t.check(point.y > viewport_height * 0.42 and point.y < viewport_height * 0.82, "Muzzle sits in the lower aiming band, not over the horizon")
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
	var advancing_tank: EnemyVehicle = scene.vehicles[0]
	advancing_tank.set_physics_process(false)
	var tank_spawn := Vector3(-28.0, CoastalTerrain.height_at(-28.0, 12.0), 12.0)
	advancing_tank.configure(tank_spawn, scene.emplacement, "tank")
	advancing_tank.shoot_cooldown = 10000.0
	var flat_spawn := Vector3(tank_spawn.x, 0.0, tank_spawn.z)
	var flat_target := Vector3(scene.emplacement.x, 0.0, scene.emplacement.z)
	t.near(advancing_tank.stop_distance, flat_spawn.distance_to(flat_target) * 0.5, 0.001, "Tank hold line is half the spawn-to-emplacement distance")
	for index in range(1200):
		advancing_tank._physics_process(1.0 / 60.0)
	var hold_offset: Vector3 = scene.emplacement - advancing_tank.global_position
	hold_offset.y = 0.0
	t.check(advancing_tank.holding, "Tank advances out of its spawn and enters the hold state")
	t.near(hold_offset.length(), advancing_tank.stop_distance, 0.02, "Tank stops at the half-way line without overshooting")
	var held_position: Vector3 = advancing_tank.global_position
	for index in range(120):
		advancing_tank._physics_process(1.0 / 60.0)
	t.check(held_position.is_equal_approx(advancing_tank.global_position), "Tank remains parked at the half-way line")
	var transport := EnemyVehicle.new()
	t.tree.root.add_child(transport)
	transport.configure(tank_spawn, scene.emplacement, "transport")
	t.equal(transport.stop_distance, 28.0, "Transport stand-off distance is unchanged")
	transport.queue_free()
	scene.weapon.cooldown = 0.0
	var ammo: int = scene.weapon.ammo
	t.check(scene.fire_once(), "Mounted weapon fires")
	for index in range(40):
		scene.weapon.tick(0.05)
	for cover in scene.weapon.cover_nodes:
		t.check(absf(cover.rotation.x) < 0.001, "Feed cover returns closed after the firing cycle")
	t.equal(scene.weapon.ammo, ammo - 1, "Firing consumes ammunition")
	scene.set_auto_fire(true)
	t.check(scene.auto_fire, "Automatic fire toggle state is exposed")
	scene.set_auto_fire(false)
	scene.use_support("airstrike")
	t.check(scene.airstrike_queue.size() == 5, "Airstrike queues a bomb run in round one")
	t.equal(int(scene.support_charges.airstrike), 1, "Support consumes a charge")
	t.equal(CoastalController.MAX_HEALTH, CoastalHUD.DEFAULT_HEALTH, "HUD and controller agree on maximum health")
	var player_before: float = scene.player_health
	scene._damage_player(500.0)
	t.near(scene.player_health, player_before - 500.0 * CoastalController.DAMAGE_SCALE, 0.001, "Emplacement armour scales incoming damage")
	scene.use_support("repair")
	t.near(scene.player_health, minf(CoastalController.MAX_HEALTH, player_before - 500.0 * CoastalController.DAMAGE_SCALE + CoastalController.REPAIR_AMOUNT), 0.001, "Repair restores the configured amount")
	t.check(scene.player_health > 2500.0, "Repair remains usable while airstrike is cooling down")
	var tank: EnemyVehicle = scene.vehicles[0]
	tank.receive_damage(10000.0)
	t.check(tank.is_dead(), "Tank can be destroyed by player damage")
	for round_index in range(3):
		scene.disembark_all_now()
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
	scene.waves.round_index = WaveManager.ROUNDS.size() - 1
	scene._damage_player(2000.0)
	var before_airdrop: float = scene.player_health
	scene.weapon.ammo = 0
	scene.use_support("airdrop")
	t.near(scene.player_health, minf(CoastalController.MAX_HEALTH, before_airdrop + CoastalController.AIRDROP_REPAIR), 0.001, "Airdrop repairs the hardened emplacement")
	t.check(scene.weapon.ammo > 0, "Airdrop also resupplies the weapon")
	scene.queue_free()
	await t.tree.process_frame
