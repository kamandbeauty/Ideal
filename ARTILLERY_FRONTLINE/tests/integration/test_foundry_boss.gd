extends RefCounted
## Placement, HUD, armor timing, damage, interruption and pool lifecycle.

func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.set_setting("language", "en")
	for stage: int in Campaign.count():
		var waves: WaveSet = Campaign.waves(stage)
		t.equal(waves.waves.size(), 3, "stage %d still has three waves" % (stage + 1))
		for index: int in waves.waves.size():
			t.equal(waves.waves[index].count_of(&"foundry_brute"), 1 if stage == 11 and index == 2 else 0,
				"foundry boss appears only in stage 12 wave 3")

	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(3)
	game.select_stage(11)
	game.start_match()
	await t.frames(5)
	var level: CityLevel = game.level
	level.director.stop()
	level.horde.health_scale = Campaign.zombie_health_scale(11)
	var boss: FoundryBrute = level.horde.spawn(&"foundry_brute", "avenue_right", "gate") as FoundryBrute
	t.check(boss != null and boss.data.is_boss and level.horde.boss == boss, "foundry boss uses existing boss tracking")
	t.near(boss.full_health, 1900.0 * 1.06, 0.001, "industrial health uses the agreed 1.06 scaling")
	t.equal(game.hud.banner.text, Loc.t("foundry_brute_incoming"), "arrival is localized")
	t.equal(game.hud.sub_banner.text, Loc.t("foundry_brute_advice"), "advice explains the armor counter")
	await t.frames(2)
	t.check(game.hud.boss_meter.visible and game.hud.boss_title.text == Loc.t("zombie_foundry_brute"), "HUD shows the foundry boss")
	var body_before: float = boss.health
	boss.take_hit(100.0, false, boss.position, Vector3.FORWARD)
	t.near(body_before - boss.health, 100.0, 0.001, "ordinary body shots do full damage outside the brace")
	boss.guard_left = 0.01
	boss.tick(0.02)
	t.check(boss.guard == FoundryBrute.Guard.WARNING and boss.warning_ring.visible, "amber warning precedes the guard")
	t.equal(game.hud.banner.text, Loc.t("foundry_brute_brace"), "the HUD warns before the armor takes effect")
	body_before = boss.health
	boss.take_hit(100.0, false, boss.position, Vector3.FORWARD)
	t.near(body_before - boss.health, 100.0, 0.001, "the warning does not reduce damage")
	boss.tick(FoundryBrute.WARNING_TIME + 0.01)
	t.check(boss.guard == FoundryBrute.Guard.BRACED and boss.warning_ring.visible, "guard begins after its warning")
	t.check(boss.ring_material.albedo_color.b > boss.ring_material.albedo_color.r, "the active guard indicator is blue")
	body_before = boss.health
	boss.take_hit(100.0, false, boss.position, Vector3.FORWARD)
	t.near(body_before - boss.health, 75.0, 0.001, "guard reduces body hits by exactly 25 percent")
	body_before = boss.health
	boss.take_hit(100.0, true, boss.position, Vector3.FORWARD)
	t.near(body_before - boss.health, 100.0 * boss.data.head_damage_scale, 0.001, "guard does not reduce head hits")
	var blast: ExplosionData = (level.defender.weapons[1] as Weapon).data.explosion
	body_before = boss.health
	boss.take_blast(100.0, boss.position + Vector3.RIGHT, 1.0, blast)
	t.near(body_before - boss.health, 100.0 * boss.data.blast_damage_scale, 0.001, "blast damage is not reduced")
	t.check(boss.guard == FoundryBrute.Guard.RECOVER and boss.reel_left > 0.0 and not boss.warning_ring.visible, "a blast cancels the guard")
	body_before = boss.health
	boss.take_hit(100.0, false, boss.position, Vector3.FORWARD)
	t.near(body_before - boss.health, 100.0, 0.001, "body shots resume full damage after interruption")
	while boss.reel_left > 0.0:
		boss.tick(0.1)
	boss.guard = FoundryBrute.Guard.WARNING
	boss.guard_left = 1.0
	boss.take_blast(1.0, boss.position + Vector3.RIGHT, 1.0, blast)
	t.check(boss.guard == FoundryBrute.Guard.RECOVER and not boss.warning_ring.visible, "a blast also cancels the warning")
	while boss.reel_left > 0.0:
		boss.tick(0.1)
	boss.guard = FoundryBrute.Guard.BRACED
	boss.guard_left = 0.01
	boss.tick(0.02)
	t.check(boss.guard == FoundryBrute.Guard.RECOVER and not boss.warning_ring.visible, "guard expires after its bounded duration")
	boss.guard = FoundryBrute.Guard.BRACED
	boss.state = Zombie.State.BREACH
	body_before = boss.health
	boss.take_hit(100.0, false, boss.position, Vector3.FORWARD)
	t.near(body_before - boss.health, 100.0, 0.001, "the guard cannot protect a breaching boss")
	boss.kill()
	t.check(not boss.warning_ring.visible and game.hud.banner.text == Loc.t("foundry_brute_down"), "death clears the indicator and announces the fall")
	level.horde.clear()
	var reused: FoundryBrute = level.horde.spawn(&"foundry_brute", "avenue_right", "gate") as FoundryBrute
	t.check(reused == boss and reused.guard == FoundryBrute.Guard.RECOVER and not reused.warning_ring.visible,
		"pool reuse resets guard and visual state")
	t.near(reused.guard_left, FoundryBrute.FIRST_GUARD, 0.001, "pool reuse resets the initial delay")
	game.queue_free()
	await t.frames(3)
	Profile.reset()
