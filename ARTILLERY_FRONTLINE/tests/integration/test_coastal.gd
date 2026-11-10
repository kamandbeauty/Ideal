extends RefCounted

func run(t: TestContext) -> void:
	var jeep: Node3D = VehicleModels.build_jeep()
	t.equal(jeep.find_children("Wheel_*", "MeshInstance3D", true, false).size(), 4, "Military jeep has four road wheels")
	t.check(jeep.find_children("Barrel_*", "MeshInstance3D", true, false).size() == 1, "Military jeep carries a roof machine gun")
	jeep.free()
	var apc: Node3D = VehicleModels.build_apc()
	t.equal(apc.find_children("Wheel_*", "MeshInstance3D", true, false).size(), 8, "APC has eight wheels")
	t.check(apc.find_child("Turret", true, false) != null, "APC has a roof turret")
	apc.free()
	var boss: Node3D = VehicleModels.build_boss_tank()
	t.equal(boss.find_children("Barrel_*", "MeshInstance3D", true, false).size(), 2, "Boss tank has twin cannon barrels")
	t.equal(boss.find_children("TrackWheel_*", "MeshInstance3D", true, false).size(), 12, "Boss tank has twelve track wheels")
	boss.free()
	t.check(int(WaveManager.ROUNDS[2]["bosses"]) == 1, "Final assault fields one boss tank")
	t.check(int(WaveManager.ROUNDS[1]["jeeps"]) == 1, "Armored push fields a light jeep")
	t.check(EnemyVehicle.health_for("boss") > EnemyVehicle.health_for("tank") * 3.0, "Boss tank outlasts a standard tank several times over")
	var boss_unit := EnemyVehicle.new()
	t.tree.root.add_child(boss_unit)
	boss_unit.configure(Vector3(0, 0, 60), Vector3(0, 0, 40), "boss")
	var boss_stages: Array = []
	boss_unit.stage_changed.connect(func(_vehicle, stage_value): boss_stages.append(stage_value))
	boss_unit.receive_damage(400.0)
	boss_unit.receive_damage(400.0)
	t.equal(boss_stages, [1, 2], "Boss tank reports damage stages at 60% and 30% health")
	boss_unit.queue_free()
	# Turrets must turn their guns onto the target, not away from it, and a high target must raise the barrel.
	for turret_kind in ["jeep", "apc", "boss"]:
		var gunner := EnemyVehicle.new()
		t.tree.root.add_child(gunner)
		gunner.configure(Vector3(0, 0, 60), Vector3(30, 0, 20), turret_kind)
		for step in range(300):
			gunner._aim_turret(0.05)
		var aim_point: Vector3 = Vector3(30, 0, 20) + Vector3.UP * 1.2
		var forward: Vector3 = -gunner.turret.global_transform.basis.z
		forward.y = 0.0
		var to_target: Vector3 = aim_point - gunner.turret.global_position
		to_target.y = 0.0
		t.check(forward.normalized().dot(to_target.normalized()) > 0.99, "%s turret turns its gun onto a target to the side" % turret_kind)
		gunner.objective = Vector3(0, 30, 20)
		for step in range(300):
			gunner._aim_turret(0.05)
		var gun_forward: Vector3 = -gunner.barrel_pivot.global_transform.basis.z
		t.check(gunner.barrel_pivot.rotation.x > 0.2 and gun_forward.y > 0.1, "%s gun elevates toward a high target" % turret_kind)
		gunner.queue_free()
	# Procedural wheels roll about their axle: the axle direction stays fixed while the wheel turns.
	var rolling := EnemyVehicle.new()
	t.tree.root.add_child(rolling)
	rolling.configure(Vector3(0, 0, 60), Vector3(0, 0, 0), "jeep")
	var tyre: Node3D = rolling.wheels[0]
	var axle_before: Vector3 = tyre.global_transform.basis.y
	var spin_before: Vector3 = tyre.global_transform.basis.x
	rolling._roll_wheels(0.5, 4.0)
	t.check(axle_before.dot(tyre.global_transform.basis.y) > 0.999, "Jeep wheels spin about their axle without tumbling")
	t.check(spin_before.dot(tyre.global_transform.basis.x) < 0.99, "Jeep wheels visibly turn while rolling")
	rolling.queue_free()
	# Target panel: the aimed hostile is the one nearest the crosshair axis inside the cone.
	var centre_target := Node3D.new()
	centre_target.position = Vector3(0, 0, -50)
	var side_target := Node3D.new()
	side_target.position = Vector3(5, 0, -50)
	t.tree.root.add_child(centre_target)
	t.tree.root.add_child(side_target)
	t.check(TargetInfo.aimed_target(Vector3.ZERO, Vector3(0, 0, -1), [side_target, centre_target], 3.0) == centre_target, "Aim picks the hostile nearest the crosshair axis")
	t.check(TargetInfo.aimed_target(Vector3.ZERO, Vector3(0, 0, -1), [side_target], 3.0) == null, "Hostiles outside the aim cone are not aimed at")
	centre_target.queue_free()
	side_target.queue_free()
	var boss_kind := EnemyVehicle.new()
	boss_kind.kind = "boss"
	t.equal(TargetInfo.kind_key(boss_kind), "target_boss", "Target panel names the boss tank")
	boss_kind.health = 450.0
	boss_kind.max_health = 900.0
	t.check(absf(TargetInfo.health_ratio(boss_kind) - 0.5) < 0.001, "Target panel reports remaining health as a ratio")
	boss_kind.free()
	var plane := EnemyAircraft.new()
	plane.kind = "fighter"
	t.equal(TargetInfo.kind_key(plane), "target_fighter", "Target panel names fighters")
	plane.free()
	t.check(TargetInfo.status(true, false) == Loc.t("target_auto_fire"), "Status reports automatic fire on the target")
	# Aim assist: a capped pull toward a hostile inside the capture cone with a clear line of sight.
	var open_sight: Callable = func(_point: Vector3) -> bool: return true
	var blocked_sight: Callable = func(_point: Vector3) -> bool: return false
	var near_target := Node3D.new()
	near_target.position = Vector3(0.6, 0, -50)
	var far_target := Node3D.new()
	far_target.position = Vector3(1.7, 0, -50)
	t.tree.root.add_child(near_target)
	t.tree.root.add_child(far_target)
	t.check(AimAssist.choose(Vector3.ZERO, 0.0, 0.0, [near_target], open_sight, null) == near_target, "Aim assist picks a hostile near the crosshair")
	t.check(AimAssist.choose(Vector3.ZERO, 0.0, 0.0, [near_target], blocked_sight, null) == null, "Aim assist never picks a hostile without line of sight")
	t.check(AimAssist.choose(Vector3.ZERO, 0.0, 0.0, [near_target, far_target], open_sight, far_target) == far_target, "Aim assist keeps its current target while it stays in the cone")
	t.check(AimAssist.choose(Vector3.ZERO, 0.0, 0.0, [near_target, far_target], open_sight, null) == near_target, "Aim assist without a lock picks the closest to the crosshair")
	var step: Vector2 = AimAssist.pull(Vector2(1.0, -0.5), 1.0, 0.1)
	t.check(step.x > 0.0 and step.y < 0.0 and step.x <= AimAssist.MAX_PULL_DEG_PER_S * 0.1 + 0.0001, "Aim assist pulls toward the target with a capped step")
	t.check(AimAssist.pull(Vector2(1.0, 0.0), 0.0, 0.1) == Vector2.ZERO, "Aim assist does nothing at zero strength")
	t.check(AimAssist.pull(Vector2(6.0, 0.0), 1.0, 0.1) == Vector2.ZERO, "Aim assist ignores hostiles outside the capture cone")
	near_target.queue_free()
	far_target.queue_free()
	# Cover on physics layer 1 blocks both the aim pull and the bullet; a hostile behind it is never struck.
	var cover := StaticBody3D.new()
	cover.collision_layer = 1
	cover.collision_mask = 0
	var cover_shape := CollisionShape3D.new()
	var cover_box := BoxShape3D.new()
	cover_box.size = Vector3(12, 4, 0.6)
	cover_shape.shape = cover_box
	cover.add_child(cover_shape)
	cover.position = Vector3(0, 2, -10)
	var hostile := StaticBody3D.new()
	hostile.collision_layer = 2
	hostile.collision_mask = 0
	var hostile_shape := CollisionShape3D.new()
	var hostile_box := BoxShape3D.new()
	hostile_box.size = Vector3(1, 2, 1)
	hostile_shape.shape = hostile_box
	hostile.add_child(hostile_shape)
	hostile.position = Vector3(0, 1.0, -20)
	t.tree.root.add_child(cover)
	t.tree.root.add_child(hostile)
	await t.tree.physics_frame
	await t.tree.physics_frame
	t.check(not AimAssist.line_clear(t.tree.root.get_world_3d(), Vector3(0, 1.65, 0), Vector3(0, 1.2, -20)), "Cover blocks the line of sight to a hostile behind it")
	t.check(AimAssist.line_clear(t.tree.root.get_world_3d(), Vector3(0, 1.65, 0), Vector3(0, 1.2, -5)), "Open ground in front of cover keeps line of sight")
	var shooter := CoastalBullet.new()
	t.tree.root.add_child(shooter)
	var struck: Array = []
	shooter.impacted.connect(func(_point, _normal, collider, _dmg, _blast): struck.append(collider))
	shooter.launch(Vector3(0, 2, 0), Vector3(0, 0, -60), 20.0, 0.0, 7)
	for frame in range(40):
		await t.tree.physics_frame
	t.check(struck.size() == 1 and struck[0] == cover, "A bullet stops at cover and never reaches the hostile behind it")
	shooter.queue_free()
	cover.queue_free()
	hostile.queue_free()
	# Impact surfaces: each kind of hit gets its own feedback.
	var soldier_unit := EnemySoldier.new()
	var tank_unit := EnemyVehicle.new()
	var sand := StaticBody3D.new()
	t.equal(ImpactSurface.kind_for(soldier_unit), ImpactSurface.FLESH, "Infantry hits read as flesh")
	t.equal(ImpactSurface.kind_for(tank_unit), ImpactSurface.METAL, "Vehicle hits read as metal")
	t.equal(ImpactSurface.kind_for(sand), ImpactSurface.GROUND, "Ground hits read as ground")
	t.check(float(ImpactSurface.profile(ImpactSurface.METAL).volume_db) > float(ImpactSurface.profile(ImpactSurface.GROUND).volume_db), "Metal rings louder than sand")
	t.check(float(ImpactSurface.profile(ImpactSurface.FLESH).radius) < float(ImpactSurface.profile(ImpactSurface.GROUND).radius), "A body hit puffs smaller than a ground hit")
	soldier_unit.free()
	tank_unit.free()
	sand.free()
	t.check(TargetInfo.status(true, true) == Loc.t("target_reloading"), "Reloading takes priority in the status line")
	t.check(CoastalWeapon.ORDER.size() == 5, "Five mounted weapon types include machine guns, cannon, rocket, bazooka and autocannon")
	t.check(bool(CoastalWeapon.WEAPONS.twin_hmg.automatic), "Twin heavy machine gun supports automatic fire")
	t.check(float(CoastalWeapon.WEAPONS.rocket.blast) > 0.0, "Rocket ammunition has blast radius")
	t.check(float(CoastalWeapon.WEAPONS.bazooka.damage) > float(CoastalWeapon.WEAPONS.rocket.damage), "Bazooka is a distinct heavier anti-armor weapon")
	t.equal(WaveManager.target_count(WaveManager.ROUNDS[0]), 11, "First wave combines infantry, armor, aircraft and landing craft")
	t.check(TargetLock.bracket_size(10.0) == 84.0 and TargetLock.bracket_size(5000.0) == 26.0, "Target lock brackets clamp between 26 and 84 px")
	t.check(TargetLock.bracket_size(20.0) > TargetLock.bracket_size(30.0), "Target lock brackets shrink with range")
	t.equal(WaveManager.target_count(WaveManager.ROUNDS[1]), 20, "Armored push adds a second helicopter and fighter pair")
	t.equal(WaveManager.target_count(WaveManager.ROUNDS[2]), 29, "Final assault brings 20 infantry, a tank, an APC, a boss tank and four aircraft")
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
	var min_x: float = INF
	var max_x: float = -INF
	for unit in scene.soldiers:
		min_x = minf(min_x, unit.global_position.x)
		max_x = maxf(max_x, unit.global_position.x)
	t.check(max_x - min_x >= 3.0, "Infantry step ashore across a spread of the craft front, not one point")
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
	t.check(CoastalController.is_head_hit(0.0, 1.6) and not CoastalController.is_head_hit(0.0, 0.8), "Head hits register only above the head line")
	var numbers_before: int = scene.hud.damage_layer.get_child_count()
	scene.hud.show_damage_number(Vector2(400, 300), 120.0, true)
	t.equal(scene.hud.damage_layer.get_child_count(), numbers_before + 1, "A hit adds one damage readout over the target")
	t.check(scene.auto_fire, "Automatic fire is on by default")
	t.check(CoastalController.within_cone(Vector3.FORWARD, Vector3(0, 0, -10), 3.0), "A target dead ahead is inside the auto-fire cone")
	t.check(not CoastalController.within_cone(Vector3.FORWARD, Vector3(10, 0, -10), 3.0), "A target 45 degrees off-axis stays outside the auto-fire cone")
	t.check(not CoastalController.within_cone(Vector3.FORWARD, Vector3(0, 0, 10), 3.0), "A target behind the emplacement is not auto-fired at")
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
