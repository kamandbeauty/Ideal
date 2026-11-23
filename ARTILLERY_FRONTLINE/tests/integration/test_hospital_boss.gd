extends RefCounted
## Hospital boss placement, real director progression, combat, HUD and pooling.

func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.set_setting("language", "en")
	for stage: int in range(3, 6):
		var level: CityLevel = t.make_level(stage)
		await t.frames(2)
		t.equal(level.director.wave_count(), 3, "hospital stage %d has three waves" % (stage + 1))
		for index: int in 3:
			var wave: WaveData = level.wave_set.waves[index]
			t.equal(wave.count_of(&"quarantine_brute"), 1 if stage == 5 and index == 2 else 0,
				"hospital boss appears only in stage 6 wave 3")
			for group: SpawnGroup in wave.groups:
				t.check(level.horde.has_type(group.zombie), "hospital can spawn every planned type")
				for route: String in group.routes:
					t.check(level.layout.has_route(route), "hospital wave route exists: " + route)
		level.horde.rng.seed = 100 + stage
		level.director.rng.seed = 200 + stage
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
		t.check(level.over and not level.defense.breached, "hospital stage %d reaches victory" % (stage + 1))
		t.equal(started, [0, 1, 2], "the real director starts the three waves in order")
		t.equal(level.horde.spawned_total, level.wave_set.total_zombies(), "the director spawns every planned enemy")
		t.equal(level.stats.bosses, 1 if stage == 5 else 0, "only the last stage counts a hospital boss")
		Events.wave_started.disconnect(on_wave)
		await t.discard(level)

	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(3)
	game.select_stage(5)
	game.start_match()
	await t.frames(5)
	var level: CityLevel = game.level
	level.director.stop()
	var horde: Horde = level.horde
	var boss: QuarantineBrute = horde.spawn(&"quarantine_brute", "avenue_right", "gate") as QuarantineBrute
	t.check(boss != null and boss.data.is_boss and horde.boss == boss, "the hospital boss is tracked")
	t.equal(game.hud.banner.text, Loc.t("quarantine_brute_incoming"), "the arrival names the hospital boss")
	t.equal(game.hud.sub_banner.text, Loc.t("quarantine_brute_advice"), "the advice explains its heavy strike")
	await t.frames(2)
	t.check(game.hud.boss_meter.visible and game.hud.boss_title.text == Loc.t("zombie_quarantine_brute"), "the HUD names the boss")
	var gun: WeaponData = load("res://resources/weapons/twin_hmg.tres")
	for i: int in 49:
		boss.take_hit(gun.damage, false, boss.position, Vector3.FORWARD)
	t.check(boss.alive, "hospital boss survives 49 direct body rounds of the unupgraded twin gun")
	boss.take_hit(gun.damage, false, boss.position, Vector3.FORWARD)
	t.check(not boss.alive and game.hud.banner.text == Loc.t("quarantine_brute_down"), "round 50 kills it and announces the fall")
	horde.clear()
	var reused: QuarantineBrute = horde.spawn(&"quarantine_brute", "avenue_right", "gate") as QuarantineBrute
	t.check(reused == boss and not reused.strike_warned and not reused.strike_interrupted and not reused.warning_ring.visible,
		"the pooled boss resets its warning and interruption state")
	horde.find_place(reused)
	t.check(reused.slot != null and reused.slot.target == "gate", "the boss can claim a gate slot")
	if reused.slot != null:
		reused.position = reused.slot.position
		reused._arrive()
		reused.blows = 2
		reused.attack_clock = 0.0
		reused.attack_landed = false
		var gate_before: float = level.defense.gate_health
		reused._swing(0.1)
		t.check(reused.strike_warned and reused.warning_ring.visible, "third strike is telegraphed before damage")
		t.equal(game.hud.banner.text, Loc.t("quarantine_brute_strike"), "the HUD warns of the strike")
		t.near(level.defense.gate_health, gate_before, 0.001, "the warning itself does not damage the gate")
		reused._swing(1.8)
		t.near(gate_before - level.defense.gate_health, reused.data.attack_damage + QuarantineBrute.EXTRA_STRIKE_DAMAGE,
			0.001, "the warned strike deals its bounded extra damage once")
		t.check(not reused.warning_ring.visible and not reused.strike_warned, "the warning clears at impact")
		reused.blows = 2
		reused.attack_clock = 0.0
		reused.attack_landed = false
		reused._swing(0.1)
		var blast: ExplosionData = (level.defender.weapons[1] as Weapon).data.explosion
		reused.take_blast(1.0, reused.position + Vector3(1.0, 0.0, 0.0), 1.0, blast)
		t.check(reused.strike_interrupted and reused.reel_left > 0.0 and not reused.warning_ring.visible,
			"a blast interrupts the heavy strike")
		gate_before = level.defense.gate_health
		reused.tick(0.1)
		t.near(level.defense.gate_health, gate_before, 0.001, "the boss cannot hit during the blast reel")
		while reused.reel_left > 0.0:
			reused.tick(0.1)
		reused._swing(1.8)
		t.near(gate_before - level.defense.gate_health, reused.data.attack_damage, 0.001, "an interrupted strike loses its bonus")
	game.queue_free()
	await t.frames(3)
	Profile.reset()
