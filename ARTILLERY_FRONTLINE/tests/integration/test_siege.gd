extends RefCounted
## Whole-match simulations: the systems wired together as in the real game.
## The siege is played a stage at a time, each on a sound wall with full pouches.


func run(t: TestContext) -> void:
	await _undefended_wall_falls(t)
	await _sieges(t)


## Nobody shoots: the horde of the first stage must reach the gate, break it and breach the wall.
func _undefended_wall_falls(t: TestContext) -> void:
	var level: CityLevel = t.make_level()
	await t.frames(2)
	var finished: Array = []
	var on_finished := func(victory: bool, stats: Dictionary) -> void: finished.append([victory, stats])
	Events.match_finished.connect(on_finished)
	level.begin_match()
	t.check(level.running, "match is running after begin_match")
	var gate_fell_at: float = -1.0
	var first_blow_at: float = -1.0
	var elapsed: float = 0.0
	while elapsed < 900.0 and not level.over:
		t.simulate(level, 1.0)
		elapsed += 1.0
		if first_blow_at < 0.0 and (level.defense.gate_fraction() < 1.0 or level.defense.wall_fraction() < 1.0):
			first_blow_at = elapsed
		if gate_fell_at < 0.0 and level.defense.gate_destroyed:
			gate_fell_at = elapsed
	print("    undefended: first blow %.0fs, gate fell %.0fs, wall breached %.0fs, spawned %d, entered %d" % [
		first_blow_at, gate_fell_at, elapsed, level.horde.spawned_total, level.horde.entered_total])
	t.check(first_blow_at > 10.0 and first_blow_at < 70.0, "first blow lands between 10 and 70 s (got %.0f)" % first_blow_at)
	t.check(gate_fell_at > 0.0, "the gate falls when nobody defends it")
	t.check(level.defense.breached, "the wall is breached when nobody defends it")
	t.check(level.over, "the level marks the match over")
	t.check(elapsed > 60.0 and elapsed < 600.0, "an undefended wall lasts 1 to 10 minutes (got %.0f s)" % elapsed)
	t.check(level.horde.entered_total > 0, "zombies ran through the fallen gate")
	# The defeat sequence runs in slow motion on real frames.
	var waited: int = 0
	while finished.is_empty() and waited < 900:
		await t.frames(1)
		waited += 1
	t.check(not finished.is_empty(), "match_finished is emitted after the breach sequence")
	if not finished.is_empty():
		t.equal(finished[0][0], false, "the result is a defeat")
		t.check(finished[0][1].wall_left <= 0.0, "defeat stats report an empty wall")
	t.near(Engine.time_scale, 1.0, 0.001, "time scale is restored after the defeat sequence")
	Events.match_finished.disconnect(on_finished)
	await t.discard(level)


## A stand-in for the player, with the game's real numbers. It pours `dps` of
## machine-gun damage into whatever threatens the wall most (those already
## striking first, then the nearest), and with `explosives` it spends rockets
## on the big ones and on crowds, and grenades on crowds, as they come to hand.
## The level, the waves, the resupply and the blasts are the real ones.
func _play(t: TestContext, stage: int, dps: float, explosives: bool, label: String) -> Dictionary:
	var level: CityLevel = t.make_level(stage)
	await t.frames(2)
	var finished: Array = []
	var on_finished := func(victory: bool, stats: Dictionary) -> void: finished.append([victory, stats])
	Events.match_finished.connect(on_finished)
	var waves_seen: Array = []
	var wave_times: Array = []
	var clock: Array = [0.0]
	var on_wave := func(index: int, _total: int) -> void:
		waves_seen.append(index)
		wave_times.append(int(clock[0]))
	Events.wave_started.connect(on_wave)
	level.begin_match()
	var defender: Defender = level.defender
	var launcher: Weapon = defender.weapon_of(&"rpg_launcher")
	var rocket_blast: ExplosionData = launcher.data.explosion
	var grenade_blast: ExplosionData = defender.grenade_data.explosion
	var eye: Vector3 = level.layout.eye_position
	var step: float = 0.25
	var rocket_wait: float = 0.0
	var grenade_wait: float = 0.0
	var look_wait: float = 0.0
	var rockets_used: int = 0
	var grenades_used: int = 0
	var peak_alive: int = 0
	var boss_seen_at: float = -1.0
	var boss_down_at: float = -1.0
	var gate_fell_at: float = -1.0
	while clock[0] < 2400.0 and not level.over:
		t.simulate(level, step)
		clock[0] += step
		launcher.state.step(step)
		rocket_wait -= step
		grenade_wait -= step
		look_wait -= step
		peak_alive = maxi(peak_alive, level.horde.alive_count())
		if boss_seen_at < 0.0 and level.horde.boss != null:
			boss_seen_at = clock[0]
		if boss_seen_at >= 0.0 and boss_down_at < 0.0 and level.horde.boss == null:
			boss_down_at = clock[0]
		if gate_fell_at < 0.0 and level.defense.gate_destroyed:
			gate_fell_at = clock[0]
		# Who can be shot at: everything past the cross street, in order of threat.
		var striking: Array[Zombie] = []
		var coming: Array[Zombie] = []
		for zombie: Zombie in level.horde.active:
			if not zombie.alive or zombie.position.z < -76.0:
				continue
			if zombie.state == Zombie.State.ATTACK or zombie.state == Zombie.State.BREACH:
				striking.append(zombie)
			else:
				coming.append(zombie)
		striking.sort_custom(func(left: Zombie, right: Zombie) -> bool: return left.data.attack_damage > right.data.attack_damage)
		coming.sort_custom(func(left: Zombie, right: Zombie) -> bool: return left.position.z > right.position.z)
		var targets: Array[Zombie] = striking + coming
		if explosives and look_wait <= 0.0 and not targets.is_empty():
			look_wait = 1.0
			if launcher.state.ammo > 0 and rocket_wait <= 0.0:
				var mark: Zombie = _rocket_target(targets, rocket_blast)
				if mark != null and launcher.state.try_fire():
					rocket_wait = 4.0
					rockets_used += 1
					level.explosions.detonate(mark.position + Vector3(0.0, 0.9, 0.0), rocket_blast, mark, launcher.data.damage)
			if defender.grenade_count > 0 and grenade_wait <= 0.0:
				var heart: Zombie = _crowd(targets, grenade_blast.radius * 0.7, 4)
				if heart != null and Vector2(heart.position.x - eye.x, heart.position.z - eye.z).length() <= defender.grenade_data.max_range:
					grenade_wait = 6.0
					grenades_used += 1
					defender.grenade_count -= 1
					level.explosions.detonate(heart.position + Vector3(0.0, 0.2, 0.0), grenade_blast)
		var budget: float = dps * step
		for zombie: Zombie in targets:
			if budget <= 0.0:
				break
			if not zombie.alive:
				continue
			var dealt: float = minf(budget, zombie.health)
			budget -= dealt
			zombie.take_hit(dealt, false, zombie.position, Vector3.FORWARD)
	var result: Dictionary = {
		"label": label, "time": clock[0], "over": level.over, "breached": level.defense.breached, "waves": waves_seen, "wave_times": wave_times,
		"killed": level.horde.killed_total, "entered": level.horde.entered_total, "peak_alive": peak_alive,
		"wall": level.defense.wall_fraction(), "gate": level.defense.gate_fraction(), "gate_fell_at": gate_fell_at,
		"rockets": rockets_used, "grenades": grenades_used, "boss_seen_at": boss_seen_at, "boss_down_at": boss_down_at,
		"created": level.horde.created, "reused": level.horde.reused, "by_type": level.horde.kills_by_type.duplicate(),
		"total": level.wave_set.total_zombies(), "wave_count": level.wave_set.waves.size(), "prewarmed": 0,
	}
	for data: ZombieData in level.zombie_types:
		result.prewarmed += data.prewarm
	var waited: int = 0
	while finished.is_empty() and waited < 900:
		await t.frames(1)
		waited += 1
	result["finished"] = finished.duplicate()
	print("    %s: %s after %.0f s, waves at %s, killed %d of %d (%s), entered %d, peak alive %d, wall %.0f%%, gate %.0f%%%s, %d rockets, %d grenades%s" % [
		label, "defeat" if result.breached else "victory", result.time, str(wave_times), result.killed, result.total, str(result.by_type),
		result.entered, peak_alive, result.wall * 100.0, result.gate * 100.0,
		(" (fell at %.0f s)" % gate_fell_at) if gate_fell_at >= 0.0 else "", rockets_used, grenades_used,
		(", boss up %.0f s to %.0f s" % [boss_seen_at, boss_down_at]) if boss_seen_at >= 0.0 else ""])
	Events.match_finished.disconnect(on_finished)
	Events.wave_started.disconnect(on_wave)
	await t.discard(level)
	return result


## What a rocket is worth spending on: the boss, then a brute, then the heart of a crowd.
func _rocket_target(targets: Array[Zombie], blast: ExplosionData) -> Zombie:
	for zombie: Zombie in targets:
		if zombie.data.is_boss:
			return zombie
	for zombie: Zombie in targets:
		if zombie.data.footprint > 1 and zombie.health > 150.0:
			return zombie
	return _crowd(targets, blast.radius * 0.7, 5)


## The zombie with the most others standing within `reach` of it, if that is at least `least`.
func _crowd(targets: Array[Zombie], reach: float, least: int) -> Zombie:
	var best: Zombie = null
	var best_count: int = least - 1
	for zombie: Zombie in targets:
		var count: int = 0
		for other: Zombie in targets:
			if other.alive and zombie.position.distance_squared_to(other.position) <= reach * reach:
				count += 1
		if count > best_count:
			best_count = count
			best = zombie
	return best


## One stage after another for a gunner of the given skill, stopping at the first stage that is lost.
func _campaign(t: TestContext, dps: float, explosives: bool, label: String) -> Array:
	var runs: Array = []
	for stage: int in Campaign.count():
		var result: Dictionary = await _play(t, stage, dps, explosives, "stage %d, %s" % [stage + 1, label])
		runs.append(result)
		if result.breached or not result.over:
			break
	return runs


## The whole siege at five levels of skill. Damage per second is what lands on
## bodies after every miss, reload and change of target: the machine gun's
## ceiling is 400.
func _sieges(t: TestContext) -> void:
	var stages: int = Campaign.count()
	var strong: Array = await _campaign(t, 240.0, true, "strong gunner (240 dps, explosives)")
	t.equal(strong.size(), stages, "a strong gunner plays every stage")
	var waves: int = 0
	var killed: int = 0
	var entered: int = 0
	var total: int = 0
	var rockets: int = 0
	var time: float = 0.0
	var by_type: Dictionary = {}
	for stage: int in strong.size():
		var result: Dictionary = strong[stage]
		var count: int = result.wave_count
		t.equal(result.waves, range(count), "stage %d: every wave starts, in order" % (stage + 1))
		t.check(result.over and not result.breached, "stage %d: a strong gunner holds the wall to the end" % (stage + 1))
		t.equal(result.killed + result.entered, result.total, "stage %d: every zombie was spawned and accounted for" % (stage + 1))
		t.check(result.wall > 0.5, "stage %d: with most of the wall left (%.0f%%)" % [stage + 1, result.wall * 100.0])
		t.check(result.reused > 0 or stage == 0, "stage %d: zombie nodes are reused from the pools" % (stage + 1))
		t.check(result.created <= result.prewarmed + 40, "stage %d: the pools stay bounded (created %d, prewarmed %d)" % [
			stage + 1, result.created, result.prewarmed])
		t.check(not result.finished.is_empty(), "stage %d: match_finished is emitted after its last wave" % (stage + 1))
		if not result.finished.is_empty():
			var stats: Dictionary = result.finished[0][1]
			t.equal(result.finished[0][0], true, "stage %d: the result is a victory" % (stage + 1))
			t.equal(int(stats.waves_cleared), count, "stage %d: victory stats count every cleared wave" % (stage + 1))
			t.equal(int(stats.kills), result.killed, "stage %d: and every kill" % (stage + 1))
			t.equal(int(stats.stage), stage, "stage %d: and say which stage it was" % (stage + 1))
			t.equal(int(stats.wave_overall), waves + count, "stage %d: its last wave is wave %d of the siege" % [stage + 1, waves + count])
			t.equal(int(stats.special_kills), result.killed - int(result.by_type.get(&"walker", 0)), "stage %d: and everything tougher than a walker" % (stage + 1))
			if stage == stages - 1:
				t.equal(int(stats.bosses), 1, "the boss is among the kills of the last stage")
		waves += count
		killed += result.killed
		entered += result.entered
		total += result.total
		rockets += result.rockets
		time += result.time
		for id: StringName in result.by_type:
			by_type[id] = int(by_type.get(id, 0)) + int(result.by_type[id])
	t.check(waves >= 8, "the shipped siege has at least eight waves (%d)" % waves)
	t.equal(killed + entered, total, "every zombie of the siege was accounted for")
	if strong.size() == stages:
		var first: Dictionary = strong[0]
		var last: Dictionary = strong[stages - 1]
		t.equal(first.wave_count, 3, "the first stage is three waves")
		t.check(first.time > 60.0 and first.time < 240.0, "and lasts one to four minutes (%.0f s)" % first.time)
		t.check(int(first.by_type.get(&"brute", 0)) == 0 and first.boss_seen_at < 0.0, "with no brute and no boss in it")
		t.check(last.boss_seen_at > 0.0 and last.boss_down_at > last.boss_seen_at, "the boss walks on in the last wave and is brought down")
		t.check(last.boss_seen_at >= last.wave_times[last.wave_count - 1], "not before the last wave")
	t.check(rockets >= 4, "rockets are used and resupplied (%d)" % rockets)
	t.check(time > 300.0 and time < 900.0, "the siege lasts 5 to 15 minutes in all (%.0f s)" % time)
	for id: StringName in [&"walker", &"runner", &"brute", &"boss"]:
		t.check(int(by_type.get(id, 0)) > 0, "the siege fields the %s" % id)

	var average: Array = await _campaign(t, 150.0, true, "average gunner (150 dps, explosives)")
	t.check(average.size() == stages and not average[average.size() - 1].breached, "an average gunner who uses the explosives wins every stage")
	# Printed for the balance record; a gunner this weak may win or lose a stage by a hair.
	await _campaign(t, 110.0, true, "modest gunner (110 dps, explosives)")
	await _campaign(t, 90.0, true, "weak gunner (90 dps, explosives)")
	var poor: Array = await _campaign(t, 60.0, false, "poor gunner (60 dps, guns only)")
	var fell: Dictionary = poor[poor.size() - 1]
	t.check(fell.breached, "the siege is not a walkover: a poor gunner loses the wall")
	t.check(poor.size() >= 2, "but not in the first stage (lost stage %d)" % poor.size())
	if not fell.finished.is_empty():
		t.equal(fell.finished[0][0], false, "that result is a defeat")
	t.near(Engine.time_scale, 1.0, 0.001, "time scale is back to normal after the sieges")
