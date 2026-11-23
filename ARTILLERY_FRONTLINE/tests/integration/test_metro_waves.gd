extends RefCounted
## The metro district uses three real director-driven waves per stage.
## Only the third metro stage fields its own boss, in the final wave.

func run(t: TestContext) -> void:
	for stage: int in range(6, 9):
		var level: CityLevel = t.make_level(stage)
		await t.frames(2)
		level.horde.rng.seed = 101 + stage
		level.director.rng.seed = 201 + stage
		var waves: WaveSet = level.wave_set
		t.equal(waves.waves.size(), 3, "metro stage %d has three waves" % (stage + 1))
		t.check(waves.total_zombies() >= 110 and waves.total_zombies() <= 180,
			"stage %d is not made eight times larger" % (stage + 1))
		for index: int in waves.waves.size():
			var wave: WaveData = waves.waves[index]
			t.check(wave.total() >= 20 and wave.total() <= 70 and wave.max_alive <= 56,
				"wave %d is a manageable encounter" % (index + 1))
			t.equal(wave.schedule().size(), wave.total(), "every planned attacker is scheduled")
			t.equal(wave.count_of(&"tunnel_brute"), 1 if stage == 8 and index == 2 else 0,
				"the tunnel boss appears only in stage 9 wave 3")
			t.equal(wave.count_of(&"boss"), 0, "metro never substitutes the city boss")
			for group: SpawnGroup in wave.groups:
				t.check(level.horde.has_type(group.zombie), "every metro enemy type can spawn")
				for route: String in group.routes:
					t.check(level.layout.has_route(route), "metro route exists: " + route)
		var started: Array[int] = []
		var on_wave := func(index: int, _total: int) -> void: started.append(index)
		Events.wave_started.connect(on_wave)
		level.begin_match()
		var elapsed: float = 0.0
		while not level.over and elapsed < 900.0:
			t.simulate(level, 1.0)
			elapsed += 1.0
			for zombie: Zombie in level.horde.active.duplicate():
				if zombie.alive:
					zombie.kill()
		t.check(level.over and not level.defense.breached, "stage %d can reach a real victory" % (stage + 1))
		t.equal(started, [0, 1, 2], "all waves start in order")
		t.equal(level.horde.spawned_total, waves.total_zombies(), "the director spawned every scheduled enemy")
		t.equal(level.stats.waves_cleared, 3, "the match records all three cleared waves")
		t.equal(level.stats.bosses, 1 if stage == 8 else 0, "the boss is counted in the right stage")
		Events.wave_started.disconnect(on_wave)
		await t.discard(level)
