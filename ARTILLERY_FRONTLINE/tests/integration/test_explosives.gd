extends RefCounted
## The launcher, its rocket, the hand grenade and the blast they share, played
## through the real level: switching weapons, flight, area damage, supply and
## the touch controls for all of it.

const TICK: float = 1.0 / 60.0


func run(t: TestContext) -> void:
	await _switching_and_launch(t)
	await _rocket_blast(t)
	await _grenades(t)
	await _supply(t)
	await _controls(t)


func _level(t: TestContext) -> CityLevel:
	var level: CityLevel = t.make_level()
	await t.frames(2)
	level.begin_match()
	# These tests place their own zombies; the waves stay out of it.
	level.director.stop()
	return level


## A walker that stays where it is put.
func _stand(level: CityLevel, at: Vector3, health: float = -1.0) -> Zombie:
	var zombie: Zombie = level.horde.spawn(&"walker", "avenue_left", "gate")
	zombie.position = at
	zombie.speed = 0.0
	if health > 0.0:
		zombie.health = health
	return zombie


func _aim(defender: Defender, point: Vector3) -> void:
	var wanted: Vector2 = defender.aim_for(point)
	defender.aim.set_aim(wanted.x, wanted.y)
	defender.shake = Vector3.ZERO
	defender._apply_aim()


func _bring_up(t: TestContext, defender: Defender, index: int) -> int:
	defender.select_weapon(index)
	var waited: int = 0
	while not defender.weapon.is_ready() and waited < 240:
		await t.physics_frames(1)
		waited += 1
	await t.frames(1)
	return waited


func _press_fire(t: TestContext, defender: Defender) -> void:
	defender.set_fire(true)
	await t.frames(1)
	await t.physics_frames(2)
	defender.set_fire(false)
	await t.frames(1)


func _switching_and_launch(t: TestContext) -> void:
	var level: CityLevel = await _level(t)
	var defender: Defender = level.defender
	t.equal(defender.weapons.size(), 2, "the gunner carries two weapons")
	var gun: TwinHmg = defender.weapons[0] as TwinHmg
	var launcher: RocketLauncher = defender.weapons[1] as RocketLauncher
	t.check(gun != null and launcher != null, "they are the twin machine gun and the launcher")
	t.check(defender.weapon == gun and gun.is_ready(), "the match starts behind the machine gun, ready to fire")
	t.check(not launcher.selected and launcher.readiness <= 0.0 and not launcher.holder.visible, "the launcher starts put away and out of sight")
	t.check(defender.weapon_of(&"rpg_launcher") == launcher and defender.weapon_of(&"nothing") == null, "weapons are found by id")
	t.check(defender.camera.get_parent() == defender.cradle and defender.cradle.get_parent() == defender.frame,
		"the eye rides on the aiming frame, not on a weapon")
	t.equal(defender.grenade_count, defender.grenade_data.carried, "the belt starts with the configured grenades")
	# The cradle of the mounted gun turns with the aim, so it looks the same at every bearing.
	_aim(defender, Vector3(15.0, 1.0, -19.0))
	t.near(gun.mount.rotation.y, -deg_to_rad(defender.aim.aim_yaw()), 0.0001, "the gun's cradle turns with the yaw")
	t.near(gun.pivot.rotation.y, 0.0, 0.0001, "the barrel group only tips inside the cradle")
	t.check(gun.bore_direction().dot(defender.aim_direction()) > 0.99999, "the bores lie along the sight line")

	var changes: Array = []
	var on_change := func(index: int, _weapon: Node) -> void: changes.append(index)
	Events.weapon_changed.connect(on_change)
	t.check(defender.select_weapon(1), "the launcher can be selected")
	t.check(defender.weapon == launcher and defender.weapon_index == 1, "it becomes the weapon in hand at once")
	t.equal(changes, [1], "the interface is told about the change")
	t.check(not launcher.is_ready(), "but it is not ready the same instant")
	t.check(not defender.select_weapon(1), "selecting the weapon already in hand does nothing")
	t.check(not defender.select_weapon(7) and not defender.select_weapon(-1), "there is no weapon outside the list")
	defender.set_fire(true)
	await t.frames(1)
	await t.physics_frames(3)
	t.equal(level.rockets.launched, 0, "nothing fires while the launcher is still coming up")
	t.equal(level.bullets.launched, 0, "and the machine gun is no longer firing either")
	defender.set_fire(false)
	await t.frames(1)
	var waited: int = 3
	while not launcher.is_ready() and waited < 240:
		await t.physics_frames(1)
		waited += 1
	var expected: float = gun.data.lower_time + launcher.data.raise_time
	t.check(launcher.is_ready() and absf(float(waited) * TICK - expected) < 0.2,
		"the switch takes the time to put one away and bring the other up (%.2f s, expected %.2f)" % [float(waited) * TICK, expected])
	await t.frames(2)
	t.check(gun.readiness <= 0.0 and not gun.model.visible, "the machine gun has dropped out of view")
	t.check(launcher.holder.visible and launcher.warhead.visible, "the loaded launcher is in view")
	var local: Vector3 = defender.camera.global_transform.affine_inverse() * launcher.muzzle_position()
	t.check(local.x > 0.05 and local.y < -0.05 and local.z < -0.3, "the tube lies low on the right, pointing away (%s)" % str(local.snapped(Vector3.ONE * 0.01)))

	# One press, one rocket, exactly where the crosshair rests.
	var ground := Vector3(7.0, 0.0, -28.0)
	_aim(defender, ground)
	await t.frames(1)
	var bursts: Array = []
	var on_burst := func(at: Vector3, _radius: float, _kills: int) -> void: bursts.append(at)
	Events.explosion.connect(on_burst)
	var origin: Vector3 = launcher.muzzle_position()
	await _press_fire(t, defender)
	t.equal(level.rockets.launched, 1, "one press launches one rocket")
	t.equal(launcher.state.ammo, 0, "the tube is empty")
	t.check(launcher.state.reloading, "and the next round is being loaded")
	t.check(not launcher.warhead.visible, "the round has left the tube")
	t.equal(level.stats.rockets, 1, "the rocket is counted")
	t.equal(level.stats.shots, 0, "but not as a machine-gun round: accuracy stays honest")
	t.check(defender.aim.recoil_pitch > 0.0, "the launch kicks the aim")
	var ticks: int = 2
	while level.rockets.active_count > 0 and ticks < 400:
		await t.physics_frames(1)
		ticks += 1
	t.equal(bursts.size(), 1, "the rocket bursts once")
	if bursts.size() == 1:
		t.check((bursts[0] as Vector3).distance_to(ground) < 0.6, "it bursts where the crosshair rested (%.2f m off)" % (bursts[0] as Vector3).distance_to(ground))
	var flight: float = origin.distance_to(ground) / launcher.data.muzzle_velocity
	t.check(absf(float(ticks) * TICK - flight) < 0.15, "the flight takes distance over speed (%.2f s, expected %.2f)" % [float(ticks) * TICK, flight])
	t.equal(level.explosions.detonations, 1, "one detonation was resolved")
	t.equal(level.rockets.detonated, 1, "the pool retired the round")
	await t.frames(2)
	t.check(level.explosions.burning() >= 1, "a pooled flash is burning")
	# What the blast leaves to look at: fire, smoke and debris from the pool, a ring and a scorch mark on the ground.
	var mark: MeshInstance3D = level.explosions.scorches[0]
	t.check(mark.visible and absf(mark.position.y) < 0.1, "a scorch mark lies on the ground")
	t.check(Vector2(mark.position.x - ground.x, mark.position.z - ground.z).length() < 0.8, "under the blast")
	t.check(mark.scale.x >= launcher.data.explosion.radius * 0.75, "about as wide as the blast")
	t.check(level.explosions.rings[0].visible and level.explosions.flashes[0].visible, "a shock ring and a flash are showing")
	var bursts_before: int = level.effects.bursts
	var high := Vector3(0.0, 40.0, -60.0)
	level.explosions.detonate(high, launcher.data.explosion)
	t.check(level.effects.bursts - bursts_before >= 4, "every blast draws its fire, smoke, debris and sparks from the effect pool")
	t.check(not level.explosions.scorches[1].visible and not level.explosions.rings[1].visible, "a burst high in the air marks no ground")
	for kind: String in ["fireball", "blast_smoke", "debris"]:
		t.check(level.effects.emitters.has(kind) and level.effects.emitters[kind].size() >= Explosions.BLASTS,
			"the effect pool holds %s for as many blasts as can burn at once" % kind)
	bursts.clear()

	# A rocket that meets nothing bursts at the end of its range.
	var start := Vector3(0.0, 30.0, 0.0)
	var slot: int = level.rockets.launch(start, Vector3.UP, launcher.data)
	t.check(slot >= 0, "a round is free in the pool")
	var guard: int = 0
	var trailing_at: float = -1.0
	while level.rockets.active_count > 0 and guard < 2000:
		level.rockets._physics_process(0.02)
		if trailing_at < 0.0 and level.rockets.trails[slot].emitting:
			trailing_at = level.rockets.travelled[slot]
		guard += 1
	t.check(bursts.size() == 1 and absf((bursts[0] as Vector3).y - start.y - launcher.data.max_range) < 0.5, "it bursts at its maximum range")
	t.check(trailing_at >= RocketPool.TRAIL_START and trailing_at < RocketPool.TRAIL_START + 3.0,
		"the smoke trail starts clear of the gunner (%.1f m out)" % trailing_at)
	t.check(not level.rockets.trails[slot].emitting and not level.rockets.nodes[slot].visible, "the round and its trail stop at the burst")
	# The pool never grows.
	var nodes: int = level.rockets.get_child_count()
	for index: int in RocketPool.CAPACITY + 3:
		level.rockets.launch(start, Vector3.UP, launcher.data)
	t.equal(level.rockets.active_count, RocketPool.CAPACITY, "only the pooled rounds can be in flight")
	t.equal(level.rockets.launch(start, Vector3.UP, launcher.data), -1, "a launch with no round free is refused")
	t.equal(level.rockets.get_child_count(), nodes, "no node was created by launching")
	level.rockets.clear()
	t.equal(level.rockets.active_count, 0, "clear retires every round")

	# The launcher keeps loading while it is put away.
	launcher.state.reload_left = 0.1
	t.check(defender.select_weapon(0), "back to the machine gun")
	await t.physics_frames(10)
	t.check(defender.weapon == gun and launcher.state.ammo == 1 and not launcher.state.reloading, "the round was seated while the launcher was put away")
	Events.weapon_changed.disconnect(on_change)
	Events.explosion.disconnect(on_burst)
	await t.discard(level)


func _rocket_blast(t: TestContext) -> void:
	var level: CityLevel = await _level(t)
	var defender: Defender = level.defender
	var launcher: RocketLauncher = defender.weapons[1] as RocketLauncher
	var blast: ExplosionData = launcher.data.explosion
	var walker: ZombieData = level.zombie_types[0]
	var centre := Vector3(7.0, 0.0, -28.0)
	var lethal: float = blast.reach_for(walker.max_health)
	var struck: Zombie = _stand(level, centre)
	var beside: Zombie = _stand(level, centre + Vector3(2.0, 0.0, 0.0))
	var wounded: Zombie = _stand(level, centre + Vector3(0.0, 0.0, lethal + 1.2))
	var spared: Zombie = _stand(level, centre + Vector3(-(blast.radius + 2.0), 0.0, 0.0))
	await t.physics_frames(2)
	await _bring_up(t, defender, 1)
	var reports: Array = []
	var on_burst := func(at: Vector3, radius: float, kills: int) -> void: reports.append([at, radius, kills])
	Events.explosion.connect(on_burst)
	var gate_before: float = level.defense.gate_health
	var wall_before: float = level.defense.wall_health
	var effects_before: int = level.effects.pool_size()
	var blast_nodes: int = level.explosions.get_child_count()
	_aim(defender, centre + Vector3(0.0, 0.9, 0.0))
	await t.frames(1)
	await _press_fire(t, defender)
	var ticks: int = 0
	while level.rockets.active_count > 0 and ticks < 400:
		await t.physics_frames(1)
		ticks += 1
	t.equal(reports.size(), 1, "the rocket bursts in the crowd")
	t.check(not struck.alive, "the zombie it strikes dies")
	t.check(not beside.alive, "the one beside it dies in the blast")
	t.check(wounded.alive and wounded.health < wounded.full_health, "one farther out is wounded but lives")
	t.check(spared.alive and is_equal_approx(spared.health, spared.full_health), "one outside the radius is untouched")
	if reports.size() == 1:
		var at: Vector3 = reports[0][0]
		t.check(at.distance_to(centre + Vector3(0.0, 0.9, 0.0)) < 0.8, "the blast is centred on the struck zombie")
		t.equal(int(reports[0][2]), 2, "the blast reports its kills")
		var distance: float = Explosions.distance_to_body(at, wounded)
		t.near(wounded.full_health - wounded.health, blast.damage_at(distance), 0.5, "the wound follows the falloff at %.1f m" % distance)
		t.check(Explosions.distance_to_body(at, spared) > blast.radius, "the spared one really stood outside")
	t.equal(level.stats.kills, 2, "blast kills count as kills")
	t.equal(level.stats.blast_kills, 2, "and are tallied as explosive kills")
	t.equal(level.stats.hits, 0, "a blast is not a machine-gun hit")
	t.equal(level.horde.alive_count(), 2, "the horde knows two are left")
	# Thrown and reeling.
	t.check(beside.knock.x > 0.2 and beside.knock.length() <= blast.knockback + 0.001, "the dead are thrown away from the blast (%s)" % str(beside.knock.snapped(Vector3.ONE * 0.01)))
	var thrown_from: Vector3 = beside.position
	for index: int in 30:
		beside.tick(TICK)
	t.check(beside.position.x - thrown_from.x > 0.2, "the body travels as it falls")
	t.check(wounded.reel_left > 0.0, "the survivor reels")
	wounded.speed = 2.0
	var held: Vector3 = wounded.position
	wounded.tick(0.1)
	t.check(wounded.position.is_equal_approx(held), "a reeling zombie does not walk")
	var guard: int = 0
	while wounded.reel_left > 0.0 and guard < 200:
		wounded.tick(0.05)
		guard += 1
	wounded.tick(0.3)
	t.check(not wounded.position.is_equal_approx(held), "and walks on once it has recovered")
	t.check(is_equal_approx(level.defense.gate_health, gate_before) and is_equal_approx(level.defense.wall_health, wall_before),
		"the wall and the gate are unharmed")
	t.equal(level.effects.pool_size(), effects_before, "the particle pool did not grow")
	t.equal(level.explosions.get_child_count(), blast_nodes, "the flash pool did not grow")

	# A direct hit adds the round's own damage to the blast.
	var tough: Zombie = _stand(level, Vector3(-7.0, 0.0, -30.0), 2000.0)
	await t.physics_frames(2)
	launcher.state.reload_left = 0.02
	var settle: int = 0
	while not launcher.state.can_fire() and settle < 120:
		await t.physics_frames(1)
		settle += 1
	t.equal(launcher.state.ammo, 1, "the launcher is loaded again")
	reports.clear()
	_aim(defender, tough.position + Vector3(0.0, 0.9, 0.0))
	await t.frames(1)
	await _press_fire(t, defender)
	ticks = 0
	while level.rockets.active_count > 0 and ticks < 400:
		await t.physics_frames(1)
		ticks += 1
	t.near(2000.0 - tough.health, launcher.data.damage + blast.damage, 1.0, "a direct hit deals the round's damage plus the full blast")
	t.check(tough.alive and tough.reel_left > 0.0, "a zombie that survives a direct hit reels")

	# A blast against the wall never throws a body into it.
	var cornered: Zombie = _stand(level, Vector3(level.layout.court_half_width - 1.2, 0.0, -10.0))
	await t.physics_frames(1)
	level.explosions.detonate(cornered.position + Vector3(-1.0, 0.5, 0.0), blast)
	t.check(not cornered.alive, "the cornered zombie dies")
	for index: int in 40:
		cornered.tick(TICK)
	t.check(cornered.position.x <= level.layout.court_half_width - 0.89, "its body stays inside the court (x %.2f)" % cornered.position.x)

	# The knob for friendly fire works when a designer turns it on.
	var harsh: ExplosionData = blast.duplicate()
	harsh.structure_damage = 100.0
	var beside_gate: Vector3 = level.layout.gate_center + Vector3(-1.0, 0.0, 0.0)
	level.explosions.detonate(beside_gate, harsh)
	t.near(gate_before - level.defense.gate_health, 100.0, 0.5, "a blast with structure damage hurts the gate beside it")
	level.explosions.detonate(beside_gate + Vector3(-(harsh.radius + 3.0), 0.0, 0.0), harsh)
	t.near(gate_before - level.defense.gate_health, 100.0, 0.5, "but not from beyond its radius")
	# More blasts than pooled flashes: the pool cycles instead of growing.
	for index: int in Explosions.BLASTS + 3:
		level.explosions.detonate(Vector3(float(index) * 2.0 - 8.0, 0.2, -36.0), blast)
	await t.frames(1)
	t.equal(level.explosions.get_child_count(), blast_nodes, "a barrage reuses the pooled flashes and scorch marks")
	t.check(level.explosions.burning() <= Explosions.BLASTS, "never more flashes than the pool holds")
	Events.explosion.disconnect(on_burst)
	await t.discard(level)


func _grenades(t: TestContext) -> void:
	var level: CityLevel = await _level(t)
	var defender: Defender = level.defender
	var data: GrenadeData = defender.grenade_data
	var blast: ExplosionData = data.explosion
	var spot := Vector3(-8.0, 0.0, -22.0)
	var close: Zombie = _stand(level, spot + Vector3(1.2, 0.0, 0.0))
	var other: Zombie = _stand(level, spot + Vector3(-1.5, 0.0, 1.0))
	var far: Zombie = _stand(level, spot + Vector3(0.0, 0.0, -(blast.radius + 4.0)))
	await t.physics_frames(2)
	_aim(defender, spot)
	await t.frames(1)
	var target: Vector3 = defender.throw_target()
	t.check(target.distance_to(spot) < 0.4, "the throw is aimed at the spot under the crosshair (%.2f m off)" % target.distance_to(spot))
	t.check(defender.can_throw() and is_equal_approx(defender.throw_readiness(), 1.0), "a grenade is ready")
	var thrown_at: Array = []
	var on_throw := func(at: Vector3) -> void: thrown_at.append(at)
	Events.grenade_thrown.connect(on_throw)
	var counts: Array = []
	var on_count := func(count: int, _capacity: int) -> void: counts.append(count)
	Events.grenades_changed.connect(on_count)
	var gate_before: float = level.defense.gate_health
	var nodes: int = level.grenades.get_child_count()
	t.check(defender.throw_grenade(), "the grenade is thrown")
	t.equal(defender.grenade_count, data.carried - 1, "one grenade is gone from the belt")
	t.equal(counts, [data.carried - 1], "the interface is told the new count")
	t.equal(thrown_at.size(), 1, "the throw is announced")
	t.equal(level.grenades.thrown, 1, "the pool has one grenade in the air")
	t.equal(level.stats.grenades, 1, "the throw is counted")
	t.check(not defender.throw_grenade(), "a second throw has to wait for the cooldown")
	t.check(defender.throw_readiness() < 1.0, "the cooldown is under way")
	t.equal(level.grenades.active_count, 1, "the refused throw launched nothing")
	var hand_height: float = level.grenades.nodes[0].position.y
	var apex: float = hand_height
	var steps: int = 0
	while level.grenades.active_count > 0 and steps < 900:
		level.grenades._physics_process(TICK)
		apex = maxf(apex, level.grenades.nodes[0].position.y)
		steps += 1
	var burst: Vector3 = level.grenades.last_burst
	var seconds: float = float(steps) * TICK
	t.equal(level.grenades.detonated, 1, "the grenade goes off")
	t.check(apex > hand_height + 0.08, "it rises out of the hand before it falls (%.2f m)" % (apex - hand_height))
	t.check(level.grenades.bounces >= 1, "it bounces before it bursts")
	t.check(Vector2(burst.x - spot.x, burst.z - spot.z).length() < 2.5, "it bursts within two and a half metres of the aim (%.2f m)" % Vector2(burst.x - spot.x, burst.z - spot.z).length())
	t.check(burst.y < 1.0, "on the ground (%.2f m up)" % burst.y)
	t.check(seconds >= data.min_flight_time and seconds < data.max_life, "flight and fuze take a believable time (%.2f s)" % seconds)
	t.check(not close.alive and not other.alive, "the zombies around the burst die")
	t.check(far.alive and is_equal_approx(far.health, far.full_health), "one well away is untouched")
	t.equal(level.stats.blast_kills, 2, "grenade kills are tallied as explosive kills")
	t.check(is_equal_approx(level.defense.gate_health, gate_before), "the gate is unharmed")
	t.equal(level.grenades.get_child_count(), nodes, "no node was created by the throw")

	# Out of reach: the grenade is dropped at the longest range on the same bearing.
	_aim(defender, Vector3(2.0, 0.0, -95.0))
	var eye: Vector3 = defender.eye_position()
	var long_throw: Vector3 = defender.throw_target()
	t.near(Vector2(long_throw.x - eye.x, long_throw.z - eye.z).length(), data.max_range, 0.05, "a far aim is pulled in to the longest throw")
	t.near(long_throw.y, 0.0, 0.001, "and comes down on the street")
	t.near(atan2(long_throw.x - eye.x, -(long_throw.z - eye.z)), atan2(2.0 - eye.x, 95.0 + eye.z), 0.03, "along the bearing of the aim")
	defender.aim.set_aim(20.0, 30.0)
	defender._apply_aim()
	var sky_throw: Vector3 = defender.throw_target()
	t.near(Vector2(sky_throw.x - eye.x, sky_throw.z - eye.z).length(), data.max_range, 0.6, "aimed at the sky, it still goes to the longest range")
	t.near(sky_throw.y, 0.0, 0.001, "and to the ground")
	# Every reachable throw leaves the hand rising, so the parapet never catches it.
	var rising: bool = true
	for distance: float in [data.min_range, 12.0, 20.0, 30.0, data.max_range]:
		var landing := Vector3(0.0, 0.0, -distance)
		var hand: Vector3 = eye + Defender.THROW_HAND
		var time: float = Ballistics.flight_time(distance, data.throw_speed, data.min_flight_time, data.max_flight_time)
		if Ballistics.lob_velocity(hand, landing, time, data.gravity).y < 1.0:
			rising = false
	t.check(rising, "throws at every range leave the hand rising")

	# The belt runs dry.
	var more: int = 0
	defender.grenade_cooldown = 0.0
	while defender.throw_grenade():
		more += 1
		defender.grenade_cooldown = 0.0
	t.equal(more, data.carried - 1, "the rest of the belt can be thrown")
	t.check(defender.grenade_count == 0 and not defender.can_throw(), "then there are none left")
	t.check(not defender.throw_grenade(), "an empty belt throws nothing")
	steps = 0
	while level.grenades.active_count > 0 and steps < 900:
		level.grenades._physics_process(TICK)
		steps += 1
	t.equal(level.grenades.detonated, data.carried, "every grenade thrown went off")
	t.equal(level.grenades.get_child_count(), nodes, "the grenade pool never grew")
	# Nothing can be thrown once the match has taken the controls away.
	defender.grenade_count = 1
	defender.set_input_enabled(false)
	t.check(not defender.throw_grenade() and not defender.select_weapon(1), "no throwing or switching without control")
	Events.grenade_thrown.disconnect(on_throw)
	Events.grenades_changed.disconnect(on_count)
	await t.discard(level)


func _supply(t: TestContext) -> void:
	var level: CityLevel = await _level(t)
	var defender: Defender = level.defender
	var launcher: RocketLauncher = defender.weapons[1] as RocketLauncher
	var state: WeaponState = launcher.state
	var data: GrenadeData = defender.grenade_data
	var handed: Array = []
	var on_supply := func(rockets: int, grenades: int) -> void: handed.append([rockets, grenades])
	Events.resupplied.connect(on_supply)
	var first: WaveData = level.wave_set.waves[0]
	t.check(first.resupply_rockets > 0 or first.resupply_grenades > 0, "the first wave of the shipped siege hands something out")
	var reserve_before: int = state.reserve
	var grenades_before: int = defender.grenade_count
	Events.wave_cleared.emit(0, level.wave_set.waves.size())
	t.equal(state.reserve, mini(reserve_before + first.resupply_rockets, launcher.data.reserve_max), "clearing a wave brings rockets")
	t.equal(defender.grenade_count, mini(grenades_before + first.resupply_grenades, data.capacity), "and grenades")
	t.equal(handed.size(), 1, "the hand-over is announced once")
	if handed.size() == 1:
		t.equal(handed[0], [state.reserve - reserve_before, defender.grenade_count - grenades_before], "with what actually arrived")
	# No room, no hand-over.
	state.reserve = launcher.data.reserve_max
	defender.grenade_count = data.capacity
	Events.wave_cleared.emit(1, level.wave_set.waves.size())
	t.check(state.reserve == launcher.data.reserve_max and defender.grenade_count == data.capacity, "nothing is carried beyond the limits")
	t.equal(handed.size(), 1, "and nothing is announced when nothing fitted")
	# Nothing after the last wave.
	state.reserve = 0
	defender.grenade_count = 0
	Events.wave_cleared.emit(level.wave_set.waves.size() - 1, level.wave_set.waves.size())
	t.check(state.reserve == 0 and defender.grenade_count == 0, "the last wave hands nothing out")

	# A spent launcher cannot be taken up.
	state.ammo = 0
	state.reserve = 0
	state.reloading = false
	var refused: Array = []
	var on_refuse := func(index: int) -> void: refused.append(index)
	Events.weapon_refused.connect(on_refuse)
	t.check(state.is_spent() and not defender.select_weapon(1), "a launcher with nothing left is refused")
	t.equal(refused, [1], "and the interface is told why")
	t.check(not defender.cycle_weapon(), "cycling finds no other usable weapon")
	t.equal(defender.weapon_index, 0, "the machine gun stays in hand")
	var taken: Dictionary = defender.resupply(2, 1)
	t.equal(taken, {"rockets": 2, "grenades": 1}, "a resupply reports what fitted")
	t.check(state.reloading, "the empty launcher starts loading as soon as rockets arrive")
	t.check(defender.cycle_weapon() and defender.weapon_index == 1, "now it can be taken up, even while it loads")
	state.reload_left = 0.02
	var waited: int = 0
	while not (launcher.is_ready() and state.ammo == 1) and waited < 240:
		await t.physics_frames(1)
		waited += 1
	t.check(launcher.is_ready() and state.ammo == 1, "it comes up loaded")
	# The last rocket: the gunner goes back to the machine gun by himself.
	state.reserve = 0
	_aim(defender, Vector3(6.0, 0.0, -30.0))
	await t.frames(1)
	await _press_fire(t, defender)
	t.check(state.is_spent(), "the last rocket is gone")
	waited = 0
	while defender.weapon_index != 0 and waited < 240:
		await t.frames(1)
		waited += 1
	t.equal(defender.weapon_index, 0, "the gunner returns to the machine gun when the launcher is spent")
	waited = 0
	while not defender.weapon.is_ready() and waited < 240:
		await t.physics_frames(1)
		waited += 1
	t.check(defender.weapon.is_ready(), "and it is ready to fire again")
	Events.resupplied.disconnect(on_supply)
	Events.weapon_refused.disconnect(on_refuse)
	await t.discard(level)


func _key(t: TestContext, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	t.tree.root.push_input(event, true)
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.keycode = code
	release.pressed = false
	t.tree.root.push_input(release, true)


func _controls(t: TestContext) -> void:
	t.tree.root.get_node("Profile").persist = false
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(3)
	game.start_match()
	await t.frames(3)
	var hud: Hud = game.hud
	var level: CityLevel = game.level
	var defender: Defender = level.defender
	level.director.stop()
	var view: Vector2 = hud.get_viewport().get_visible_rect().size
	t.equal(hud.weapon_slots.size(), defender.weapons.size(), "the HUD shows a card for every weapon")
	var fire: Vector2 = hud.fire_button.center()
	var reload: Vector2 = hud.reload_button.center()
	var grenade: Vector2 = hud.grenade_button.center()
	var card_gun: Vector2 = hud.weapon_slots[0].center()
	var card_launcher: Vector2 = hud.weapon_slots[1].center()
	t.equal(hud.role_at(grenade), "grenade", "a touch on the grenade button throws")
	t.equal(hud.role_at(card_gun), "weapon_0", "a touch on the first card takes the machine gun")
	t.equal(hud.role_at(card_launcher), "weapon_1", "a touch on the second card takes the launcher")
	t.equal(hud.role_at(fire), "fire", "FIRE is still FIRE")
	t.equal(hud.role_at(view * 0.5), "aim", "the middle of the screen still aims")
	t.check(hud.grenade_button.radius >= 44.0, "the grenade button is thumb-sized")
	t.check(grenade.distance_to(fire) > hud.grenade_button.radius * 1.2 + hud.fire_button.radius * 1.15, "the grenade button is clear of FIRE")
	t.check(grenade.distance_to(reload) > hud.grenade_button.radius * 1.2 + hud.reload_button.radius * 1.25, "and of RELOAD")
	t.check(absf(card_gun.x - card_launcher.x) >= Hud.SLOT_SIZE.x, "the weapon cards do not overlap")
	var inside: bool = true
	for point: Vector2 in [fire, reload, grenade, card_gun, card_launcher]:
		if point.x < 30.0 or point.x > view.x - 30.0 or point.y < 30.0 or point.y > view.y - 20.0:
			inside = false
	t.check(inside, "every control lies inside the screen")
	t.check(card_gun.x < view.x * 0.4 and grenade.x > view.x * 0.6, "weapons under the left thumb, grenade under the right")
	t.equal(hud.weapon_label.text, Loc.t("weapon_twin_hmg"), "the HUD names the machine gun")
	t.equal(hud.crosshair.style, "cross", "with its cross sight")
	t.equal(hud.grenade_label.text, Loc.number(defender.grenade_count), "the grenade count is shown")
	await t.frames(2)
	t.check(hud.weapon_slots[0].active and not hud.weapon_slots[1].active, "the card of the weapon in hand is lit")
	t.equal(hud.slot_labels[0].text, "", "an endless belt shows no count on its card")
	t.equal(hud.slot_labels[1].text, Loc.number(defender.weapons[1].state.rounds_left()), "the launcher's card counts its rockets")

	# Switching by touch.
	hud.touch_down(5, card_launcher)
	hud.touch_drag(5, Vector2(80.0, 0.0))
	hud.touch_up(5)
	t.equal(defender.weapon_index, 1, "touching the launcher's card takes the launcher")
	t.near(defender.aim.target_yaw, defender.aim_settings.start_yaw_degrees, 0.0001, "a finger on a card does not drag the aim")
	await t.frames(2)
	t.equal(hud.weapon_label.text, Loc.t("weapon_rpg"), "the HUD names the launcher")
	t.equal(hud.crosshair.style, "rocket", "and switches to the ring sight")
	t.check(hud.weapon_slots[1].active and not hud.weapon_slots[0].active, "the launcher's card is lit")
	t.equal(hud.ammo_label.text, Loc.number(1), "one round is loaded")
	t.equal(hud.magazine_label.text, "/ " + Loc.number(defender.weapons[1].state.reserve), "and the spare rockets are shown beside it")
	hud.touch_down(5, card_gun)
	hud.touch_up(5)
	await t.frames(2)
	t.check(defender.weapon_index == 0 and hud.crosshair.style == "cross", "touching the first card goes back to the machine gun")
	t.equal(hud.magazine_label.text, "/ " + Loc.number(defender.weapon.data.magazine_size), "the belt read-out returns")

	# The grenade button.
	var belt: int = defender.grenade_count
	hud.touch_down(6, grenade)
	t.check(hud.grenade_button.held, "the grenade button shows the press")
	t.equal(defender.grenade_count, belt - 1, "one touch throws one grenade")
	hud.touch_up(6)
	t.check(not hud.grenade_button.held, "and releases")
	await t.frames(2)
	t.equal(hud.grenade_label.text, Loc.number(belt - 1), "the count on the button follows")
	t.check(hud.grenade_button.progress < 1.0, "the button shows the cooldown")
	hud.touch_down(6, grenade)
	hud.touch_up(6)
	t.equal(defender.grenade_count, belt - 1, "a touch during the cooldown throws nothing")

	# Keyboard, for desktop play and for TV boxes.
	_key(t, KEY_2)
	t.equal(defender.weapon_index, 1, "key 2 takes the launcher")
	_key(t, KEY_1)
	t.equal(defender.weapon_index, 0, "key 1 takes the machine gun")
	_key(t, KEY_Q)
	t.equal(defender.weapon_index, 1, "Q cycles to the next weapon")
	_key(t, KEY_Q)
	t.equal(defender.weapon_index, 0, "and round again")
	defender.grenade_cooldown = 0.0
	_key(t, KEY_G)
	t.equal(defender.grenade_count, belt - 2, "G throws a grenade")

	# Supply and refusal on the HUD.
	Events.resupplied.emit(2, 1)
	t.check(hud.sub_banner.text.contains(Loc.t("resupply_rockets", [2])) and hud.sub_banner.text.contains(Loc.t("resupply_grenades", [1])),
		"a hand-over is written under the banner")
	t.check(hud.sub_banner.modulate.a > 0.9, "and shown")
	var state: WeaponState = defender.weapons[1].state
	state.ammo = 0
	state.reserve = 0
	state.reloading = false
	hud.banner_left = 0.0
	hud.touch_down(5, card_launcher)
	hud.touch_up(5)
	t.equal(defender.weapon_index, 0, "a spent launcher cannot be taken by touch")
	t.check(hud.weapon_slots[1].refused > 0.0, "its card flashes")
	t.equal(hud.banner.text, Loc.t("out_of_rockets"), "and the HUD says why")
	await t.frames(2)
	t.check(hud.weapon_slots[1].spent, "the card of a spent weapon is dimmed")
	defender.grenade_count = 0
	await t.frames(2)
	t.check(hud.grenade_button.dim, "the grenade button dims when the belt is empty")
	t.equal(hud.grenade_label.text, Loc.number(0), "and shows zero")

	# Left-handed play mirrors both hands.
	Profile.set_setting("left_handed", true)
	await t.frames(2)
	t.check(hud.grenade_button.center().x < view.x * 0.4 and hud.fire_button.center().x < view.x * 0.4, "left-handed: FIRE and the grenade move left")
	t.check(hud.weapon_slots[0].center().x > view.x * 0.6 and hud.weapon_slots[1].center().x > view.x * 0.6, "and the weapon cards move right")
	t.check(hud.weapon_slots[1].center().x < view.x - 30.0, "still inside the screen")
	t.check(hud.grenade_button.center().distance_to(hud.fire_button.center()) > hud.grenade_button.radius * 1.2 + hud.fire_button.radius * 1.15,
		"and still clear of each other")
	t.equal(hud.role_at(hud.grenade_button.center()), "grenade", "the mirrored grenade button still answers")
	Profile.set_setting("left_handed", false)
	await t.frames(2)

	# Screen cut-outs: the controls step in from under the camera notch.
	t.equal(Hud.insets_for(Vector2(1800.0, 810.0), Rect2i(0, 0, 2400, 1080), Rect2i(0, 0, 2400, 1080)), Vector2.ZERO, "no cut-out, no inset")
	var notched: Vector2 = Hud.insets_for(Vector2(1800.0, 810.0), Rect2i(0, 0, 2400, 1080), Rect2i(90, 0, 2220, 1080))
	t.near(notched.x, 67.5, 0.001, "a notch on the left is converted to canvas units")
	t.near(notched.y, 67.5, 0.001, "and the matching margin on the right")
	t.equal(Hud.insets_for(Vector2(1440.0, 810.0), Rect2i(200, 100, 1440, 810), Rect2i(0, 0, 1920, 1050)), Vector2.ZERO,
		"a desktop window inside its screen has no inset")
	t.near(Hud.insets_for(Vector2(1800.0, 810.0), Rect2i(0, 0, 2400, 1080), Rect2i(900, 0, 1500, 1080)).x, 225.0, 0.001,
		"an absurd cut-out is capped at an eighth of the width")
	t.equal(Hud.insets_for(Vector2(1800.0, 810.0), Rect2i(0, 0, 0, 0), Rect2i(0, 0, 0, 0)), Vector2.ZERO, "no window, no inset")

	# Android's back button walks one step back at a time.
	t.equal(game.mode, 1, "the match is still in play")
	t.check(game.go_back() and game.mode == 2 and t.tree.paused, "back during play pauses")
	game.menus.show_settings("pause")
	t.check(game.go_back() and game.menus.screen == "pause" and game.mode == 2, "back in settings returns to the pause menu")
	t.check(game.go_back() and game.mode == 1 and not t.tree.paused, "back in the pause menu resumes")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	t.check(game.mode == 2 and t.tree.paused, "the system back request reaches the same path")
	game.resume()
	Events.match_finished.emit(false, level.stats.to_dict())
	t.equal(game.mode, 3, "the match is over")
	t.check(game.go_back() and game.mode == 0 and game.menus.screen == "main", "back on the result screen returns to the title")
	game.menus.show_settings("main")
	t.check(game.go_back() and game.menus.screen == "main", "back in the title's settings returns to the title")
	t.check(not game.go_back(), "back on the title has nowhere left to go, so the app closes")
	t.check(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back")), "the engine leaves the back button to the game")
	await t.discard(game)
