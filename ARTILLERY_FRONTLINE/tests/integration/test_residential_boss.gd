extends RefCounted
## Stage placement, warning, actual defense damage, blast, breach and pooling.

func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.set_setting("language", "en")
	for stage: int in Campaign.count():
		var waves: WaveSet = Campaign.waves(stage)
		for index: int in waves.waves.size():
			t.equal(waves.waves[index].count_of(&"residential_brute"), 1 if stage == 20 and index == 2 else 0, "block breaker appears only in stage 21 wave 3")
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(3)
	game.select_stage(20)
	game.start_match()
	await t.frames(5)
	var level: CityLevel = game.level
	level.director.stop()
	var horde: Horde = level.horde
	var boss: ResidentialBrute = horde.spawn(&"residential_brute", "avenue_right", "gate") as ResidentialBrute
	t.check(boss != null and boss.data.is_boss and horde.boss == boss, "boss uses existing tracking")
	t.near(boss.full_health, 1900.0 * 1.15, 0.001, "boss uses residential health scale")
	t.equal(game.hud.banner.text, Loc.t("residential_brute_incoming"), "arrival is localized")
	t.equal(game.hud.sub_banner.text, Loc.t("residential_brute_advice"), "arrival explains both targets and the counter")
	await t.frames(2)
	t.check(game.hud.boss_meter.visible and game.hud.boss_title.text == Loc.t("zombie_residential_brute"), "boss health meter is visible")
	var before: float = boss.health
	boss.take_hit(100.0, false, boss.position, Vector3.FORWARD)
	t.near(before - boss.health, 100.0, 0.001, "body damage unchanged")
	before = boss.health
	boss.take_hit(100.0, true, boss.position, Vector3.FORWARD)
	t.near(before - boss.health, 100.0 * boss.data.head_damage_scale, 0.001, "head damage unchanged")
	horde.find_place(boss)
	t.check(boss.slot != null and boss.slot.target == "gate", "boss claims its gate slot")
	if boss.slot != null:
		boss.position = boss.slot.position
		boss._arrive()
		boss.attack_clock = 0.0
		boss.attack_landed = false
		boss.shock_left = 0.01
		var wall_before: float = level.defense.wall_health
		var gate_before: float = level.defense.gate_health
		boss.tick(0.02)
		t.check(boss.shock == ResidentialBrute.Shock.WARNING and boss.warning_ring.visible, "clear warning precedes shockwave")
		t.equal(game.hud.banner.text, Loc.t("residential_brute_slam"), "HUD announces shockwave")
		boss.tick(ResidentialBrute.WARNING_TIME - 0.1)
		t.near(level.defense.wall_health, wall_before, 0.001, "no wall damage before warning completes")
		t.near(level.defense.gate_health, gate_before, 0.001, "no gate damage or hidden normal swing during warning")
		boss.tick(0.11)
		t.near(wall_before - level.defense.wall_health, ResidentialBrute.SHOCK_DAMAGE, 0.001, "shock damages wall once")
		t.near(gate_before - level.defense.gate_health, ResidentialBrute.SHOCK_DAMAGE, 0.001, "shock damages gate once")
		t.check(boss.shock == ResidentialBrute.Shock.RECOVER and not boss.warning_ring.visible, "impact ends the warning")
		t.near(boss.shock_left, ResidentialBrute.RECOVERY, 0.001, "impact starts bounded cooldown")
		var blast: ExplosionData = (level.defender.weapons[1] as Weapon).data.explosion
		boss.shock = ResidentialBrute.Shock.WARNING
		boss.shock_left = 0.01
		boss.warning_ring.visible = true
		before = boss.health
		boss.take_blast(100.0, boss.position + Vector3.RIGHT, 1.0, blast)
		t.near(before - boss.health, 100.0 * boss.data.blast_damage_scale, 0.001, "blast damage is unchanged")
		t.check(boss.shock == ResidentialBrute.Shock.RECOVER and boss.reel_left > 0.0 and not boss.warning_ring.visible, "blast cancels the pending shockwave")
		wall_before = level.defense.wall_health
		gate_before = level.defense.gate_health
		boss.tick(0.1)
		t.near(level.defense.wall_health, wall_before, 0.001, "interrupted shock does not damage wall")
		t.near(level.defense.gate_health, gate_before, 0.001, "interrupted shock does not damage gate")
		while boss.reel_left > 0.0:
			boss.tick(0.1)
		boss.shock = ResidentialBrute.Shock.WARNING
		boss.warning_ring.visible = true
		boss.state = Zombie.State.BREACH
		boss.tick(0.01)
		t.check(boss.shock == ResidentialBrute.Shock.RECOVER and not boss.warning_ring.visible, "breach cancels the warning")
		# With the gate already gone its portion cannot be redirected to the
		# wall by the normal Defense.apply_damage fallback.
		level.defense.gate_destroyed = true
		wall_before = level.defense.wall_health
		boss._release_shock()
		t.near(wall_before - level.defense.wall_health, ResidentialBrute.SHOCK_DAMAGE, 0.001, "destroyed gate does not double-hit the wall")
	boss.kill()
	t.check(not boss.warning_ring.visible and game.hud.banner.text == Loc.t("residential_brute_down"), "death cancels warning and is announced")
	horde.clear()
	var reused: ResidentialBrute = horde.spawn(&"residential_brute", "avenue_right", "gate") as ResidentialBrute
	t.check(reused == boss and reused.shock == ResidentialBrute.Shock.RECOVER and not reused.warning_ring.visible, "pool reuse resets warning")
	t.near(reused.shock_left, ResidentialBrute.FIRST_WARNING, 0.001, "pool reuse resets timer")
	game.queue_free()
	await t.frames(3)
	var actual: CityLevel = t.make_level(20)
	await t.frames(2)
	actual.horde.rng.seed = 2121
	actual.director.rng.seed = 2122
	actual.begin_match()
	actual.director._start_wave(2)
	t.simulate(actual, 4.5)
	t.check(actual.horde.boss is ResidentialBrute, "real director spawns the residential boss")
	var naturally_warned: bool = false
	var naturally_hit: bool = false
	for frame: int in 2400:
		var field_boss: ResidentialBrute = actual.horde.boss as ResidentialBrute
		var prior_shock: bool = field_boss != null and field_boss.shock == ResidentialBrute.Shock.WARNING
		var wall_before: float = actual.defense.wall_health
		var gate_before: float = actual.defense.gate_health
		t.simulate(actual, 0.1, 0.1)
		for enemy: Zombie in actual.horde.active.duplicate():
			if enemy.alive and enemy != field_boss:
				enemy.kill()
		if field_boss != null:
			naturally_warned = naturally_warned or field_boss.shock == ResidentialBrute.Shock.WARNING
			if prior_shock and field_boss.shock == ResidentialBrute.Shock.RECOVER:
				naturally_hit = absf(wall_before - actual.defense.wall_health - ResidentialBrute.SHOCK_DAMAGE) < 0.01 and absf(gate_before - actual.defense.gate_health - ResidentialBrute.SHOCK_DAMAGE) < 0.01
				if naturally_hit:
					break
		if actual.over:
			break
	t.check(naturally_warned, "naturally advancing boss reaches its warned attack at the defenses")
	t.check(naturally_hit, "real director and horde deliver one shock to both intact defenses")
	await t.discard(actual)
	Profile.reset()
