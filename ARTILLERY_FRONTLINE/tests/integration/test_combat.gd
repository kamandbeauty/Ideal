extends RefCounted
## Projectile collision: rounds against zombies, the gate and the world, plus
## the gun firing through the pool.


func _still(level: CityLevel, at: Vector3) -> Zombie:
	var zombie: Zombie = level.horde.spawn(&"walker", "ring_right", "gate")
	zombie.position = at
	zombie.rotation = Vector3.ZERO
	zombie.speed = 0.0
	zombie.scale = Vector3.ONE
	return zombie


func run(t: TestContext) -> void:
	var level: CityLevel = t.make_level()
	await t.frames(2)
	await t.physics_frames(3)
	var bullets: BulletPool = level.bullets
	var walker: ZombieData = level.zombie_types[0]
	var nodes_before: int = bullets.get_child_count()

	# Body hit.
	var target: Zombie = _still(level, Vector3(8.0, 0.0, -30.0))
	await t.physics_frames(3)
	var full: float = target.health
	t.near(full, walker.max_health, 0.001, "a fresh zombie has full health")
	var slot: int = bullets.fire(Vector3(8.0, 1.0, -12.0), Vector3(0.0, 0.0, -700.0), 34.0, 400.0, true, 0, 0.5, 2.5)
	t.check(slot >= 0 and bullets.active_count == 1, "firing takes a pooled round")
	await t.physics_frames(4)
	t.near(target.health, full - 34.0, 0.001, "a body hit takes the round's damage")
	t.equal(bullets.active_count, 0, "the round is returned to the pool on impact")
	t.equal(bullets.hits, 1, "the hit is counted")
	t.check(target.alive, "one body shot does not kill a walker")

	# Miss: a round passing a metre to the side does nothing.
	bullets.fire(Vector3(9.4, 1.0, -12.0), Vector3(0.0, 0.0, -700.0), 34.0, 60.0, true, 0, 0.5, 2.5)
	await t.physics_frames(8)
	t.near(target.health, full - 34.0, 0.001, "a round that passes beside the zombie misses")

	# Headshot.
	var kills: Array = []
	var on_kill := func(zombie: Node3D, headshot: bool) -> void: kills.append([zombie, headshot])
	Events.zombie_killed.connect(on_kill)
	var head: Vector3 = target.head_area.global_position
	t.check(head.y > 1.3 and head.y < 1.9, "the head volume is at head height (%.2f m)" % head.y)
	var origin: Vector3 = head + Vector3(0.3, 0.2, 14.0)
	bullets.fire(origin, (head - origin).normalized() * 700.0, 34.0, 400.0, true, 0, 0.5, 2.5)
	await t.physics_frames(4)
	t.check(not target.alive and target.state == Zombie.State.DYING, "a headshot kills the wounded walker")
	t.check(kills.size() == 1 and kills[0][0] == target and kills[0][1] == true, "the kill is reported as a headshot")
	t.equal(target.body_area.collision_layer, 0, "a dead zombie no longer stops bullets")
	var hits_before: int = bullets.hits
	bullets.fire(Vector3(8.0, 1.0, -12.0), Vector3(0.0, 0.0, -700.0), 34.0, 60.0, true, 0, 0.5, 2.5)
	await t.physics_frames(8)
	t.equal(bullets.hits, hits_before, "rounds pass through a corpse")

	# Penetration.
	var front: Zombie = _still(level, Vector3(-8.0, 0.0, -30.0))
	var rear: Zombie = _still(level, Vector3(-8.0, 0.0, -33.0))
	await t.physics_frames(3)
	bullets.fire(Vector3(-8.0, 1.0, -12.0), Vector3(0.0, 0.0, -700.0), 34.0, 400.0, true, 1, 0.6, 2.5)
	await t.physics_frames(4)
	t.near(front.health, walker.max_health - 34.0, 0.001, "a piercing round damages the first zombie")
	t.near(rear.health, walker.max_health - 34.0 * 0.6, 0.001, "and carries reduced damage into the one behind")
	bullets.fire(Vector3(-8.0, 1.0, -12.0), Vector3(0.0, 0.0, -700.0), 10.0, 400.0, true, 0, 0.6, 2.5)
	await t.physics_frames(4)
	t.near(rear.health, walker.max_health - 34.0 * 0.6, 0.001, "without penetration the one behind is shielded")
	t.near(front.health, walker.max_health - 44.0, 0.001, "the shielding zombie takes that round")

	# The world and the gate stop rounds.
	var bursts: int = level.effects.bursts
	bullets.fire(Vector3(0.0, 5.0, -20.0), Vector3(0.0, -700.0, 0.0), 34.0, 400.0)
	await t.physics_frames(3)
	t.equal(bullets.active_count, 0, "a round fired at the ground stops there")
	t.check(level.effects.bursts > bursts, "the impact raises a pooled effect")
	var inside: Zombie = _still(level, Vector3(24.5, 0.0, -19.0))
	await t.physics_frames(3)
	bullets.fire(Vector3(8.0, 1.1, -19.0), Vector3(700.0, 0.0, 0.0), 34.0, 400.0)
	await t.physics_frames(4)
	t.near(inside.health, walker.max_health, 0.001, "the closed gate stops rounds")
	level.defense.apply_damage("gate", 100000.0)
	t.equal(level.gate_body.collision_layer, 0, "the fallen gate no longer blocks")
	await t.physics_frames(3)
	bullets.fire(Vector3(8.0, 1.1, -19.0), Vector3(700.0, 0.0, 0.0), 34.0, 400.0)
	await t.physics_frames(4)
	t.near(inside.health, walker.max_health - 34.0, 0.001, "rounds pass through the opening once the gate is down")
	bullets.fire(Vector3(-10.0, 2.0, -26.5), Vector3(-700.0, 0.0, 0.0), 34.0, 400.0)
	await t.physics_frames(3)
	t.equal(bullets.active_count, 0, "the wall patch stops rounds")

	# Range and pool capacity.
	bullets.fire(Vector3(0.0, 6.0, 0.0), Vector3(0.0, 300.0, 0.0), 34.0, 20.0)
	await t.physics_frames(8)
	t.equal(bullets.active_count, 0, "a round expires at its maximum range")
	var accepted: int = 0
	var refused: int = 0
	for index: int in BulletPool.CAPACITY + 12:
		if bullets.fire(Vector3(0.0, 8.0, 0.0), Vector3(0.0, 1.0, 0.0), 1.0, 100000.0) >= 0:
			accepted += 1
		else:
			refused += 1
	t.equal(accepted, BulletPool.CAPACITY, "the pool hands out exactly its capacity")
	t.equal(refused, 12, "extra rounds are refused instead of allocated")
	t.equal(bullets.get_child_count(), nodes_before, "firing creates no nodes")
	bullets.clear()
	t.equal(bullets.active_count, 0, "clear returns every round")

	# The gun firing through the pool.
	Events.zombie_killed.disconnect(on_kill)
	var weapon: TwinHmg = level.defender.weapon
	weapon.data = weapon.data.duplicate()
	weapon.data.spread_degrees = 0.0
	weapon.state = WeaponState.new(weapon.data)
	level.defender.set_input_enabled(true)
	level.defender.aim.set_aim(12.0, -6.0)
	level.defender._apply_aim()
	var ammo_events: Array = []
	var on_ammo := func(ammo: int, _size: int) -> void: ammo_events.append(ammo)
	Events.ammo_changed.connect(on_ammo)
	var launched: int = bullets.launched
	level.defender.set_fire(true)
	await t.physics_frames(60)
	level.defender.set_fire(false)
	await t.frames(2)
	var shots: int = weapon.state.shots
	var expected: float = 1.0 / weapon.data.fire_interval
	t.check(absf(float(shots) - expected) <= 2.5, "one second of fire is about %.0f rounds (got %d)" % [expected, shots])
	t.equal(bullets.launched - launched, shots, "every shot launches one pooled round")
	t.equal(weapon.state.ammo, weapon.data.magazine_size - shots, "ammunition drops by the shots fired")
	t.equal(ammo_events.size(), shots, "the HUD is told about every shot")
	t.equal(level.stats.shots, shots, "match statistics count the shots")
	t.check(level.defender.aim.recoil_pitch > 0.0, "firing kicks the aim upward")
	# Convergence: with no spread, a round from either muzzle heads for the crosshair point.
	var sight: Vector3 = weapon.sight_point()
	var view: Vector3 = level.defender.view_direction()
	var eye: Vector3 = level.defender.camera.global_position
	t.check((sight - eye).normalized().dot(view) > 0.9999, "the convergence point lies on the sight line")
	t.check(eye.distance_to(sight) >= weapon.data.min_convergence - 0.01, "convergence is never closer than the configured minimum")
	weapon.request_reload()
	t.check(weapon.state.reloading, "the reload button starts a reload")
	level.defender.set_fire(true)
	await t.physics_frames(10)
	level.defender.set_fire(false)
	t.equal(weapon.state.shots, shots, "the gun does not fire while reloading")
	Events.ammo_changed.disconnect(on_ammo)
	await t.discard(level)
