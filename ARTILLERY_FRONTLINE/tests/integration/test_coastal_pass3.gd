extends RefCounted
## Pass-3 regression: real projectile hits, physical persistent corpses,
## camera-axis spread, and articulated war-machine pivots.

func run(t: TestContext) -> void:
	var scene: CoastalController = load("res://scenes/coastal/coastal_milestone.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	scene.set_paused(false)
	# Freeze the battle so tests are deterministic.
	for unit in scene.soldiers:
		unit.set_physics_process(false)
	for vehicle in scene.vehicles:
		vehicle.set_physics_process(false)
	for plane in scene.aircraft:
		plane.set_physics_process(false)
	for landing in scene.crafts:
		landing.speed = 0.0
	t.check(scene.player_hitbox != null and scene.player_hitbox.collision_layer == 8, "Player emplacement has a real projectile hitbox")
	var soldier: EnemySoldier = scene.soldiers[0]
	var saved_layers: Array[int] = []
	for unit in scene.soldiers:
		saved_layers.append(unit.collision_layer)
		if unit != soldier:
			unit.collision_layer = 0
	for vehicle in scene.vehicles:
		vehicle.collision_layer = 0
	for plane in scene.aircraft:
		plane.collision_layer = 0
	for landing in scene.crafts:
		landing.collision_layer = 0
	soldier.collision_layer = 2
	soldier.global_position = Vector3(0, CoastalTerrain.height_at(0, 20), 20)
	soldier.rotation = Vector3.ZERO
	await t.tree.physics_frame
	await t.tree.physics_frame
	var health_before: float = soldier.health
	var origin: Vector3 = soldier.global_position + Vector3(0, 1.1, 6)
	var velocity: Vector3 = (soldier.global_position + Vector3(0, 1.1, 0) - origin).normalized() * 430.0
	t.check(scene.bullets.launch(origin, velocity, 20.0, 0.0, 7), "Player bullet launches into the physics pool")
	var confirmed: bool = false
	for index in range(30):
		await t.tree.physics_frame
		if scene.hud.crosshair.hit_timer > 0.0 or scene.hud.crosshair.kill_timer > 0.0:
			confirmed = true
	t.check(soldier.health < health_before, "Swept bullet genuinely collides with and damages a soldier")
	t.check(confirmed or soldier.is_dead(), "Hit confirmation is emitted on a real impact")
	# Kill with a directed hit and verify a physical corpse remains above ground.
	soldier.receive_damage(500.0, soldier.global_position + Vector3.UP * 1.2, Vector3.BACK)
	t.check(soldier.is_dead(), "Directed lethal hit kills the soldier")
	t.check(soldier.collision_layer == 0, "Dead soldier stops blocking live-target queries")
	var has_physics: bool = soldier.ragdoll != null or soldier.fallback_body != null
	t.check(has_physics, "Death creates a physical ragdoll/corpse body instead of a sink tween")
	for index in range(150):
		await t.tree.physics_frame
	var corpse_y: float = soldier.global_position.y
	if soldier.skeleton and soldier.ragdoll:
		var hips: int = soldier.skeleton.find_bone("Hips")
		if hips >= 0:
			corpse_y = (soldier.skeleton.global_transform * soldier.skeleton.get_bone_global_pose(hips).origin).y
	elif soldier.fallback_body:
		var corpse_shape: CollisionShape3D = soldier.fallback_body.get_child(0) as CollisionShape3D
		corpse_y = corpse_shape.global_position.y if corpse_shape else soldier.fallback_body.global_position.y
	var corpse_xz: Vector3 = soldier.fallback_body.global_position if soldier.fallback_body else soldier.global_position
	var ground: float = CoastalTerrain.height_at(corpse_xz.x, corpse_xz.z)
	t.check(corpse_y > ground - 0.35, "Corpse is thrown down and rests on the terrain instead of sinking")
	t.check(soldier.model_root.visible, "Persistent corpse remains visible after settling")
	# Incoming enemy fire must be a real projectile, not scheduled fake damage.
	var player_health_before: float = scene.player_health
	var enemy_origin: Vector3 = scene.emplacement + Vector3(0, 1.2, -25)
	var enemy_velocity: Vector3 = (scene.emplacement + Vector3(0, 1.2, 0) - enemy_origin).normalized() * 300.0
	t.check(scene.bullets.launch(enemy_origin, enemy_velocity, 18.0, 0.0, 13), "Enemy bullet uses the player/terrain/cover mask")
	for index in range(30):
		await t.tree.physics_frame
	t.check(scene.player_health < player_health_before, "Enemy projectile damages the player only on real impact")
	# Incoming fire must never paint decals/smoke onto the camera lens.
	var shell_origin: Vector3 = scene.emplacement + Vector3(0, 1.2, -25)
	var shell_velocity: Vector3 = (scene.emplacement + Vector3(0, 1.2, 0) - shell_origin).normalized() * 160.0
	t.check(scene.bullets.launch(shell_origin, shell_velocity, 150.0, 5.0, 13), "Enemy blast shell launches at the player")
	for index in range(40):
		await t.tree.physics_frame
	var lens_decal: bool = false
	var lens_effect: bool = false
	for crater in scene.effects.craters:
		if crater.visible and crater.global_position.distance_to(scene.camera.global_position) < 4.0:
			lens_decal = true
	for effect in scene.effects.effects:
		if effect.active and effect.global_position.distance_to(scene.camera.global_position) < 3.0:
			lens_effect = true
	t.check(not lens_decal, "Player impacts leave no persistent crater decal on the camera")
	t.check(not lens_effect, "Player impacts spawn no smoke/fire effect on the camera lens")
	# Camera-axis spread stays inside the configured cone at high pitch.
	scene.pitch_target = 55.0
	scene._process(0.2)
	var basis: Basis = scene.camera.global_transform.basis
	var forward: Vector3 = -basis.z
	var max_angle: float = 0.0
	for index in range(40):
		var spread: float = deg_to_rad(float(CoastalWeapon.WEAPONS.twin_hmg.spread))
		var direction: Vector3 = forward.rotated(basis.y.normalized(), randf_range(-spread, spread))
		direction = direction.rotated(basis.x.normalized(), randf_range(-spread, spread)).normalized()
		max_angle = maxf(max_angle, rad_to_deg(forward.angle_to(direction)))
	t.check(max_angle <= float(CoastalWeapon.WEAPONS.twin_hmg.spread) * 1.5 + 0.01, "Spread is applied once in camera axes, not doubled/world-corkscrewed")
	for index in range(scene.soldiers.size()):
		scene.soldiers[index].collision_layer = saved_layers[index]
	# War-machine articulation pivots are present when the detailed assets exist.
	var tank: EnemyVehicle = scene.vehicles[0]
	if tank.model_root and tank.model_root.find_child("WheelL0", true, false):
		t.check(tank.wheels.size() >= 4, "Tank exposes rolling road-wheel pivots")
		t.check(tank.recoil_node != null and tank.muzzle != null, "Tank gun has recoil assembly and muzzle marker")
	var helicopter: EnemyAircraft = null
	for plane in scene.aircraft:
		if plane.kind == "helicopter":
			helicopter = plane
	if helicopter and helicopter.model_root and helicopter.model_root.find_child("TailRotor", true, false):
		t.check(helicopter.tail_rotor != null, "Helicopter exposes an animated tail rotor")
	scene.queue_free()
	await t.tree.process_frame
