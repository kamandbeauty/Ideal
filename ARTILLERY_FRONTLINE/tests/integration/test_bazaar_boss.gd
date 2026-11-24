extends RefCounted
## Wave placement, warning, actual strike timing, blast interruption and reuse.

func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.set_setting("language", "en")
	for stage: int in Campaign.count():
		var waves: WaveSet = Campaign.waves(stage)
		for index: int in waves.waves.size():
			t.equal(waves.waves[index].count_of(&"bazaar_brute"), 1 if stage == 14 and index == 2 else 0, "market boss appears only in stage 15 wave 3")
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(3)
	game.select_stage(14)
	game.start_match()
	await t.frames(5)
	var level: CityLevel = game.level
	level.director.stop()
	var horde: Horde = level.horde
	var boss: BazaarBrute = horde.spawn(&"bazaar_brute", "avenue_right", "gate") as BazaarBrute
	t.check(boss != null and boss.data.is_boss and horde.boss == boss, "boss uses existing tracking")
	t.near(boss.full_health, 1900.0 * 1.09, 0.001, "boss uses bazaar health scale")
	t.equal(game.hud.banner.text, Loc.t("bazaar_brute_incoming"), "localized arrival")
	t.equal(game.hud.sub_banner.text, Loc.t("bazaar_brute_advice"), "advice explains the counter")
	await t.frames(2)
	t.check(game.hud.boss_meter.visible and game.hud.boss_title.text == Loc.t("zombie_bazaar_brute"), "HUD displays the boss")
	var before: float = boss.health
	boss.take_hit(100.0, false, boss.position, Vector3.FORWARD)
	t.near(before - boss.health, 100.0, 0.001, "body damage is not reduced")
	before = boss.health
	boss.take_hit(100.0, true, boss.position, Vector3.FORWARD)
	t.near(before - boss.health, 100.0 * boss.data.head_damage_scale, 0.001, "head damage is unchanged")
	horde.find_place(boss)
	t.check(boss.slot != null and boss.slot.target == "gate", "boss claims a gate slot")
	if boss.slot != null:
		boss.position = boss.slot.position
		boss._arrive()
		boss.attack_clock = 0.0
		boss.attack_landed = false
		boss.fury_left = 0.01
		boss.tick(0.02)
		t.check(boss.fury == BazaarBrute.Fury.WARNING and boss.warning_ring.visible, "warning starts before the frenzy")
		t.equal(game.hud.banner.text, Loc.t("bazaar_brute_fury"), "HUD announces the warning")
		boss.tick(BazaarBrute.WARNING_TIME + 0.01)
		t.check(boss.fury == BazaarBrute.Fury.ACTIVE and boss.warning_ring.visible, "frenzy follows the warning")
		t.check(boss.ring_material.albedo_color.r > 0.8 and boss.ring_material.albedo_color.g < 0.2, "active indicator is red")
		boss.attack_clock = 0.0
		boss.attack_landed = false
		var gate_before: float = level.defense.gate_health
		boss._swing(0.5)
		t.near(boss.attack_clock, 0.75, 0.001, "active fury advances its own strike clock 1.5 times faster")
		t.near(level.defense.gate_health, gate_before, 0.001, "strike does not land before the normal impact point")
		boss._swing(0.8)
		t.near(gate_before - level.defense.gate_health, boss.data.attack_damage, 0.001, "a frenzy strike deals ordinary damage once")
		var blast: ExplosionData = (level.defender.weapons[1] as Weapon).data.explosion
		before = boss.health
		boss.take_blast(100.0, boss.position + Vector3.RIGHT, 1.0, blast)
		t.near(before - boss.health, 100.0 * boss.data.blast_damage_scale, 0.001, "blast damage is unchanged")
		t.check(boss.fury == BazaarBrute.Fury.RECOVER and boss.reel_left > 0.0 and not boss.warning_ring.visible, "blast cancels active fury")
		gate_before = level.defense.gate_health
		boss.tick(0.1)
		t.near(level.defense.gate_health, gate_before, 0.001, "reeling boss cannot strike")
		while boss.reel_left > 0.0:
			boss.tick(0.1)
		boss.fury = BazaarBrute.Fury.WARNING
		boss.fury_left = 1.0
		boss.take_blast(1.0, boss.position + Vector3.RIGHT, 1.0, blast)
		t.check(boss.fury == BazaarBrute.Fury.RECOVER and not boss.warning_ring.visible, "blast also cancels warning")
		boss.fury = BazaarBrute.Fury.ACTIVE
		boss.state = Zombie.State.BREACH
		boss.tick(0.01)
		t.check(boss.fury == BazaarBrute.Fury.RECOVER and not boss.warning_ring.visible, "fury cannot survive a breach")
	boss.kill()
	t.equal(game.hud.banner.text, Loc.t("bazaar_brute_down"), "death is announced")
	horde.clear()
	var reused: BazaarBrute = horde.spawn(&"bazaar_brute", "avenue_right", "gate") as BazaarBrute
	t.check(reused == boss and reused.fury == BazaarBrute.Fury.RECOVER and not reused.warning_ring.visible, "pool reuse resets fury")
	t.near(reused.fury_left, BazaarBrute.FIRST_WARNING, 0.001, "pool reuse resets timer")
	game.queue_free()
	await t.frames(3)
	Profile.reset()
