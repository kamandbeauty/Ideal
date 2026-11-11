extends RefCounted
## Runner, brute and boss in the real level: how each moves, takes damage,
## takes its place at the wall and is shown on the HUD.

const TICK: float = 1.0 / 30.0


func run(t: TestContext) -> void:
	await _pools_and_volumes(t)
	await _movement_and_damage(t)
	await _wide_places(t)
	await _boss(t)


func _level(t: TestContext) -> CityLevel:
	var level: CityLevel = t.make_level()
	await t.frames(2)
	level.begin_match()
	level.director.stop()
	level.horde.rng.seed = 7
	return level


func _until(t: TestContext, level: CityLevel, limit: float, done: Callable) -> float:
	var elapsed: float = 0.0
	while elapsed < limit and not done.call():
		t.simulate(level, 0.25)
		elapsed += 0.25
	return elapsed


func _pools_and_volumes(t: TestContext) -> void:
	var level: CityLevel = await _level(t)
	var horde: Horde = level.horde
	t.equal(level.zombie_types.size(), 4, "the level knows four zombie types")
	for data: ZombieData in level.zombie_types:
		var id: String = String(data.id)
		t.check(horde.has_type(data.id), "the horde can spawn the %s" % id)
		t.equal(horde.pooled[data.id].size(), data.prewarm, "the %s pool is built before the match" % id)
		var zombie: Zombie = horde.spawn(data.id, "ring_right", "gate")
		t.check(zombie != null and zombie.alive and zombie.data == data, "a %s spawns" % id)
		await t.physics_frames(2)
		t.near(zombie.health, data.max_health, 0.001, "the %s starts with its type's health" % id)
		t.near(zombie.health_fraction(), 1.0, 0.0001, "and reports it as full")
		var capsule: CapsuleShape3D = (zombie.body_area.get_child(0) as CollisionShape3D).shape
		var sphere: SphereShape3D = (zombie.head_area.get_child(0) as CollisionShape3D).shape
		t.near(capsule.radius, data.body_radius, 0.0001, "the %s body volume has its type's radius" % id)
		t.near(sphere.radius, data.head_radius, 0.0001, "and its head volume its type's size")
		var head: Vector3 = zombie.head_area.get_child(0).global_position - zombie.global_position
		var size: float = zombie.scale.y
		t.check(head.y > data.body_height * size * 0.82 and head.y < data.height() * size * 1.05,
			"the %s head volume sits on its shoulders (%.2f m up)" % [id, head.y])
		t.near(zombie.anim.speed_scale, zombie.speed / data.stride_speed, 0.001, "the %s walk clip is paced to its ground speed" % id)
		t.check(zombie.body_mesh != null and zombie.body_mesh.material_override != null, "the %s wears one of its skins" % id)
	t.equal(horde.alive_count(), 4, "one of each is on the field")
	t.check(horde.boss != null and horde.boss.data.is_boss, "the horde knows which one is the boss")
	await t.discard(level)


func _movement_and_damage(t: TestContext) -> void:
	var level: CityLevel = await _level(t)
	var horde: Horde = level.horde
	var walker: Zombie = horde.spawn(&"walker", "avenue_left", "gate")
	var runner: Zombie = horde.spawn(&"runner", "avenue_left", "gate")
	var brute: Zombie = horde.spawn(&"brute", "avenue_left", "gate")
	var boss: Zombie = horde.spawn(&"boss", "avenue_left", "gate")
	var starts: Dictionary = {}
	for zombie: Zombie in [walker, runner, brute, boss]:
		starts[zombie] = zombie.position
	t.simulate(level, 6.0)
	var covered: Dictionary = {}
	for zombie: Zombie in [walker, runner, brute, boss]:
		covered[zombie] = (zombie.position - (starts[zombie] as Vector3)).length()
	t.check(covered[runner] > covered[walker] * 1.8, "a runner covers about twice a walker's ground (%.1f m against %.1f m in 6 s)" % [covered[runner], covered[walker]])
	t.check(covered[brute] < covered[walker] and covered[boss] < covered[walker], "the brute and the boss are slower than a walker")
	t.near(covered[runner], runner.speed * 6.0, runner.speed * 1.2, "a runner moves at its own speed")

	# Bullets: a body round staggers a walker and slows it; a brute walks through it.
	var gun: WeaponData = level.defender.weapons[0].data
	walker.take_hit(gun.damage, false, walker.position, Vector3.FORWARD)
	brute.take_hit(gun.damage, false, brute.position, Vector3.FORWARD)
	boss.take_hit(gun.damage, false, boss.position, Vector3.FORWARD)
	t.check(walker.stagger_left > 0.0, "a round staggers a walker")
	t.check(is_zero_approx(brute.stagger_left) and is_zero_approx(boss.stagger_left), "but not a brute or the boss")
	var from_walker: Vector3 = walker.position
	var from_brute: Vector3 = brute.position
	var from_boss: Vector3 = boss.position
	t.simulate(level, 0.2)
	t.near((walker.position - from_walker).length(), walker.speed * 0.2 * walker.data.flinch_slow, 0.06, "a hit walker slows to its flinch pace")
	t.near((brute.position - from_brute).length(), brute.speed * 0.2 * brute.data.flinch_slow, 0.03, "a hit brute keeps nearly all of its pace")
	t.near((boss.position - from_boss).length(), boss.speed * 0.2, 0.02, "the boss does not slow at all")
	# Head shots: the boss's skull lets only part of the bonus through.
	var head_hit: float = gun.damage * gun.headshot_multiplier
	var boss_before: float = boss.health
	var brute_before: float = brute.health
	boss.take_hit(head_hit, true, boss.position, Vector3.FORWARD)
	brute.take_hit(head_hit, true, brute.position, Vector3.FORWARD)
	t.near(boss_before - boss.health, head_hit * boss.data.head_damage_scale, 0.01, "a head shot on the boss does %.0f%% of its damage" % (boss.data.head_damage_scale * 100.0))
	t.near(brute_before - brute.health, head_hit, 0.01, "a head shot on a brute does all of it")
	t.check(not runner.take_hit(gun.damage, false, runner.position, Vector3.FORWARD) and runner.take_hit(gun.damage, false, runner.position, Vector3.FORWARD),
		"the second body round kills a runner")

	# Blasts: who reels, who is thrown.
	var blast: ExplosionData = (level.defender.weapons[1] as Weapon).data.explosion
	var second: Zombie = horde.spawn(&"walker", "avenue_left", "gate")
	second.health = 5000.0
	for zombie: Zombie in [second, brute, boss]:
		zombie.reel_left = 0.0
	var boss_health: float = boss.health
	second.take_blast(50.0, second.position + Vector3(0.5, 0.0, 0.0), 1.0, blast)
	brute.take_blast(50.0, brute.position + Vector3(0.5, 0.0, 0.0), 1.0, blast)
	boss.take_blast(50.0, boss.position + Vector3(0.5, 0.0, 0.0), 1.0, blast)
	t.near(second.reel_left, blast.stagger_time, 0.001, "a walker caught at the heart of a blast reels for its full time")
	t.near(brute.reel_left, blast.stagger_time * brute.data.blast_reel_scale, 0.001, "a brute shakes it off sooner")
	t.check(is_zero_approx(boss.reel_left), "the boss does not reel")
	t.near(boss_health - boss.health, 50.0 * boss.data.blast_damage_scale, 0.001, "though the blast still hurts it")
	var boss_held: Vector3 = boss.position
	t.simulate(level, 0.3)
	t.check(boss.position.distance_to(boss_held) > 0.2, "and it keeps walking through it")
	# Killed by a blast: a walker is thrown, a brute barely, the boss drops where it stood.
	second.health = 1.0
	brute.health = 1.0
	boss.health = 1.0
	# Out in the open street, where no wall is in the way of a thrown body.
	for zombie: Zombie in [second, brute, boss]:
		zombie.position = Vector3(0.0, 0.0, -70.0)
	var kills_before: Dictionary = horde.kills_by_type.duplicate()
	second.take_blast(100.0, second.position + Vector3(1.0, 0.0, 0.0), 1.0, blast)
	brute.take_blast(100.0, brute.position + Vector3(1.0, 0.0, 0.0), 1.0, blast)
	boss.take_blast(100.0, boss.position + Vector3(1.0, 0.0, 0.0), 1.0, blast)
	t.check(not second.alive and not brute.alive and not boss.alive, "a blast that empties their health kills all three")
	t.near(second.knock.length(), blast.knockback, 0.01, "a walker is thrown the blast's full distance")
	t.near(brute.knock.length(), blast.knockback * brute.data.knockback_scale, 0.01, "a brute a fraction of it")
	t.check(boss.knock.length() < 0.001, "the boss falls where it stood")
	t.equal(int(horde.kills_by_type.get(&"brute", 0)) - int(kills_before.get(&"brute", 0)), 1, "kills are tallied by type")
	t.equal(level.stats.special_kills, 3, "runner, brute and boss count as special kills")
	t.equal(level.stats.bosses, 1, "and the boss as a boss")
	t.check(horde.boss == null, "the horde no longer has a boss")
	await t.discard(level)


func _wide_places(t: TestContext) -> void:
	var level: CityLevel = await _level(t)
	var horde: Horde = level.horde
	var columns: int = horde.lines.lines.gate.columns
	var walkers: Array[Zombie] = []
	for index: int in columns:
		walkers.append(horde.spawn(&"walker", "ring_right", "gate"))
	var front: int = 0
	for zombie: Zombie in walkers:
		if zombie.slot != null and zombie.slot.line == "gate" and zombie.slot.row == 0:
			front += 1
	t.equal(front, columns, "walkers fill the front row of the gate")
	var brute: Zombie = horde.spawn(&"brute", "ring_right", "gate")
	t.check(brute.slot == null, "a brute claims no place when it sets out")
	_until(t, level, 200.0, func() -> bool:
		for zombie: Zombie in walkers:
			if zombie.state != Zombie.State.ATTACK:
				return false
		return true)
	t.equal(horde.attackers("gate"), columns, "the walkers are all striking the gate")
	var took: float = _until(t, level, 200.0, func() -> bool: return brute.state == Zombie.State.ATTACK)
	t.equal(brute.state, Zombie.State.ATTACK, "the brute reaches the gate and strikes it (%.0f s later)" % took)
	t.check(brute.slot != null and brute.slot.members.size() == 2 and brute.slot.row == 0 and brute.slot.line == "gate",
		"it holds two places in the front row")
	t.check(brute.position.distance_to(brute.slot.position) < 0.05, "and stands between them")
	t.simulate(level, 4.0)
	# Nobody shares a place, nobody was lost, and those pushed aside have somewhere to be.
	var holders: Dictionary = {}
	var shared: bool = false
	for line_name: String in horde.lines.lines:
		for slot: AttackLines.Slot in horde.lines.lines[line_name].slots:
			if slot.occupant == null:
				continue
			if slot.occupant != brute and holders.has(slot.occupant):
				shared = true
			holders[slot.occupant] = true
	t.check(not shared, "no walker holds two places")
	var placed: int = 0
	var crowding: bool = false
	for zombie: Zombie in walkers:
		if zombie.alive and (zombie.slot != null or zombie.state == Zombie.State.WAIT or zombie.state == Zombie.State.ADVANCE):
			placed += 1
		if zombie.state == Zombie.State.ATTACK and absf(zombie.position.z - brute.position.z) < 0.9 and absf(zombie.position.x - brute.position.x) < 0.5:
			crowding = true
	t.equal(placed, columns, "every walker it pushed aside is still in the fight")
	t.check(not crowding, "none of them stands inside the brute")
	t.equal(horde.attackers("gate"), columns - 2 + 1, "the gate is now struck by the brute and the walkers beside it")
	# Its blow is its own.
	var gate_before: float = level.defense.gate_health
	var blows: int = brute.blows
	_until(t, level, 6.0, func() -> bool: return brute.blows > blows)
	t.check(gate_before - level.defense.gate_health >= brute.data.attack_damage, "a brute's blow costs the gate its full weight")
	# When it dies, two from behind step up.
	var waiting: Array[Zombie] = []
	for zombie: Zombie in walkers:
		if zombie.slot != null and zombie.slot.row == 1:
			waiting.append(zombie)
	brute.kill()
	t.simulate(level, 3.0)
	var stepped: int = 0
	for zombie: Zombie in waiting:
		if zombie.slot != null and zombie.slot.row == 0:
			stepped += 1
	t.equal(stepped, mini(2, waiting.size()), "when the brute falls, those behind step up into its two places")
	await t.discard(level)


func _boss(t: TestContext) -> void:
	t.tree.root.get_node("Profile").persist = false
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(3)
	Profile.set_setting("language", "en")
	game.start_match()
	await t.frames(3)
	var hud: Hud = game.hud
	var level: CityLevel = game.level
	var horde: Horde = level.horde
	level.director.stop()
	t.check(not hud.boss_meter.visible and not hud.boss_title.visible, "no boss bar while there is no boss")
	var seen: Array = []
	var fallen: Array = []
	var on_seen := func(zombie: Node3D) -> void: seen.append(zombie)
	var on_fallen := func(zombie: Node3D) -> void: fallen.append(zombie)
	Events.boss_appeared.connect(on_seen)
	Events.boss_fell.connect(on_fallen)
	var started: int = Sound.started
	var boss: Zombie = horde.spawn(&"boss", "ring_right", "gate")
	t.check(seen == [boss] and horde.boss == boss, "the boss is announced when it appears")
	t.check(Sound.started > started, "with its roar")
	t.equal(hud.banner.text, Loc.t("warn_boss"), "the HUD raises the boss warning")
	t.equal(hud.sub_banner.text, Loc.t("zombie_boss"), "and names it")
	await t.frames(2)
	t.check(hud.boss_meter.visible and hud.boss_title.visible, "the boss bar appears")
	t.equal(hud.boss_title.text, Loc.t("zombie_boss"), "under its name")
	t.near(hud.boss_meter.fraction, 1.0, 0.0001, "and starts full")
	var view: Vector2 = hud.get_viewport().get_visible_rect().size
	t.check(absf(hud.boss_meter.position.x + hud.boss_meter.size.x * 0.5 - view.x * 0.5) < 1.0 and hud.boss_meter.position.y < view.y * 0.2,
		"centred under the wave counter")
	t.check(hud.boss_meter.position.y + hud.boss_meter.size.y < hud.banner.position.y, "clear of the banner line")
	boss.take_hit(boss.full_health * 0.25, false, boss.position, Vector3.FORWARD)
	await t.frames(2)
	t.near(hud.boss_meter.fraction, 0.75, 0.001, "the bar follows the boss's health")
	# It shoulders its way to the gate and its blows are heavy.
	for index: int in horde.lines.lines.gate.columns:
		horde.spawn(&"walker", "ring_right", "gate")
	var elapsed: float = 0.0
	while elapsed < 240.0 and boss.state != Zombie.State.ATTACK:
		t.simulate(level, 0.25)
		elapsed += 0.25
	t.equal(boss.state, Zombie.State.ATTACK, "the boss reaches the gate (%.0f s)" % elapsed)
	t.check(boss.slot != null and boss.slot.members.size() == 3, "and takes three places at it")
	var gate_before: float = level.defense.gate_health
	var blows: int = boss.blows
	level.gate_shake = 0.0
	while elapsed < 260.0 and boss.blows == blows:
		t.simulate(level, 0.05)
		elapsed += 0.05
	t.check(gate_before - level.defense.gate_health >= boss.data.attack_damage, "one blow of the boss costs the gate %.0f" % boss.data.attack_damage)
	t.check(level.gate_shake > 1.0, "and shakes it hard")
	# The fall.
	hud.banner_left = 0.0
	boss.kill()
	t.check(fallen == [boss] and horde.boss == null, "its fall is announced")
	t.equal(hud.banner.text, Loc.t("boss_down"), "on the HUD too")
	await t.frames(2)
	t.check(not hud.boss_meter.visible and not hud.boss_title.visible, "and the bar goes away")
	t.equal(level.stats.bosses, 1, "the match counts the boss")

	# A boss that gets inside the city.
	horde.clear()
	level.defense.reset()
	level.defense.apply_damage("gate", level.defense.data.gate_max_health)
	t.check(level.defense.gate_destroyed, "with the gate down")
	var intruder: Zombie = horde.spawn(&"boss", "ring_right", "gate")
	t.equal(intruder.state, Zombie.State.BREACH, "a boss heads straight for the gap")
	var wall_before: float = level.defense.wall_health
	elapsed = 0.0
	while elapsed < 240.0 and intruder.alive:
		t.simulate(level, 0.25)
		elapsed += 0.25
	t.check(horde.entered_total >= 1 and horde.boss == null, "it walks into the city")
	t.near(wall_before - level.defense.wall_health, intruder.data.breach_damage, 0.5, "and takes its toll on the wall")
	await t.frames(2)
	t.check(not hud.boss_meter.visible, "its bar leaves with it")

	# What a wave brings is written under its number.
	var hinted: int = -1
	for index: int in level.wave_set.waves.size():
		if level.wave_set.waves[index].hint_key != "":
			hinted = index
			break
	t.check(hinted >= 0, "the shipped siege has a wave with a hint")
	if hinted >= 0:
		Events.wave_started.emit(hinted, level.wave_set.waves.size())
		t.equal(hud.sub_banner.text, Loc.t(level.wave_set.waves[hinted].hint_key), "the wave banner carries the wave's hint")
	Events.wave_started.emit(0, level.wave_set.waves.size())
	t.equal(hud.sub_banner.text, "", "a wave without a hint shows none")
	Profile.set_setting("language", "fa")
	Events.boss_appeared.disconnect(on_seen)
	Events.boss_fell.disconnect(on_fallen)
	await t.discard(game)
