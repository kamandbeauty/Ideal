extends RefCounted
## Whole-match simulations: the systems wired together as in the real game.


func run(t: TestContext) -> void:
	await _undefended_wall_falls(t)
	await _defended_wall_holds(t)


## Nobody shoots: the horde must reach the gate, break it and breach the wall.
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


## A gunner who kills everything that enters the court wins all five waves.
func _defended_wall_holds(t: TestContext) -> void:
	var level: CityLevel = t.make_level()
	await t.frames(2)
	var finished: Array = []
	var on_finished := func(victory: bool, stats: Dictionary) -> void: finished.append([victory, stats])
	Events.match_finished.connect(on_finished)
	var waves_seen: Array = []
	var on_wave := func(index: int, _total: int) -> void: waves_seen.append(index)
	Events.wave_started.connect(on_wave)
	level.begin_match()
	var elapsed: float = 0.0
	var peak_alive: int = 0
	while elapsed < 1200.0 and not level.over:
		t.simulate(level, 0.5)
		elapsed += 0.5
		peak_alive = maxi(peak_alive, level.horde.alive_count())
		# Stand-in for the player: two kills per half second among those inside the court.
		var budget: int = 2
		for zombie: Zombie in level.horde.active:
			if budget <= 0:
				break
			if zombie.alive and zombie.position.z > -46.0:
				zombie.take_hit(1000.0, true, zombie.position, Vector3.FORWARD)
				budget -= 1
	print("    defended: %.0fs, waves %s, killed %d, peak alive %d, wall %.0f%%, gate %.0f%%, created %d, reused %d" % [
		elapsed, str(waves_seen), level.horde.killed_total, peak_alive, level.defense.wall_fraction() * 100.0,
		level.defense.gate_fraction() * 100.0, level.horde.created, level.horde.reused])
	t.equal(waves_seen, [0, 1, 2, 3, 4], "all five waves start in order")
	t.equal(level.horde.killed_total, level.wave_set.total_zombies(), "every zombie of the siege was spawned and killed")
	t.check(not level.defense.breached, "the wall holds against a competent gunner")
	t.check(level.over, "the level marks the match over after the last wave")
	t.check(level.horde.reused > 0, "zombie nodes are reused from the pool")
	t.check(level.horde.created <= level.prewarm_count + 60, "the pool stays bounded (created %d)" % level.horde.created)
	var waited: int = 0
	while finished.is_empty() and waited < 600:
		await t.frames(1)
		waited += 1
	t.check(not finished.is_empty(), "match_finished is emitted after the last wave")
	if not finished.is_empty():
		t.equal(finished[0][0], true, "the result is a victory")
		t.equal(int(finished[0][1].waves_cleared), 5, "victory stats count five cleared waves")
		t.equal(int(finished[0][1].kills), level.wave_set.total_zombies(), "victory stats count every kill")
	Events.match_finished.disconnect(on_finished)
	Events.wave_started.disconnect(on_wave)
	await t.discard(level)
