extends RefCounted
## Real metro boss: telegraph, charge, interruption, pooling and HUD.

func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.set_setting("language", "en")
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(3)
	game.select_stage(8)
	game.start_match()
	await t.frames(5)
	var level: CityLevel = game.level
	level.director.stop()
	var horde: Horde = level.horde
	horde.rng.seed = 14
	var warning: Array = []
	var on_warning := func(zombie: Node3D) -> void: warning.append(zombie)
	Events.tunnel_brute_warning.connect(on_warning)
	var boss: TunnelBrute = horde.spawn(&"tunnel_brute", "avenue_left", "gate") as TunnelBrute
	t.check(boss != null and horde.boss == boss and boss.data.is_boss, "the real metro boss is tracked as a boss")
	t.equal(game.hud.banner.text, Loc.t("tunnel_brute_incoming"), "the arrival banner names the metro boss")
	t.equal(game.hud.sub_banner.text, Loc.t("tunnel_brute_advice"), "arrival advice explains the rush and interruption")
	await t.frames(2)
	t.check(game.hud.boss_meter.visible and game.hud.boss_title.text == Loc.t("zombie_tunnel_brute"), "the boss health bar has the right name")
	# A long unobstructed path makes displacement measurements independent of navigation.
	boss.path = PackedVector3Array([boss.position, boss.position + Vector3(0.0, 0.0, 500.0)])
	boss.path_index = 1
	boss.court_index = 1
	var base_speed: float = boss.speed
	for i: int in 61:
		boss.tick(0.1)
	t.equal(boss.rush, TunnelBrute.Rush.WARNING, "rush begins with a warning")
	t.check(boss.warning_ring.visible and warning == [boss], "orange ring and event telegraph the attack")
	t.equal(game.hud.banner.text, Loc.t("tunnel_brute_rush"), "HUD also warns before the charge")
	for i: int in 17:
		boss.tick(0.1)
	t.equal(boss.rush, TunnelBrute.Rush.CHARGE, "it charges after the warning")
	t.check(not boss.warning_ring.visible, "warning ring clears once charge starts")
	var before: Vector3 = boss.position
	boss.tick(0.5)
	t.near(boss.position.distance_to(before), base_speed * TunnelBrute.CHARGE_SPEED * 0.5, 0.02, "charge is faster but follows its path")
	t.near(boss.speed, base_speed, 0.0001, "temporary speed is restored after each tick")
	var blast: ExplosionData = (level.defender.weapons[1] as Weapon).data.explosion
	boss.take_blast(1.0, boss.position + Vector3(1, 0, 0), 1.0, blast)
	t.check(boss.alive and boss.reel_left > 0.0 and boss.rush == TunnelBrute.Rush.RECOVER, "a blast interrupts a live charge")
	t.check(not boss.warning_ring.visible, "interrupted warning is hidden")
	boss.kill()
	t.equal(game.hud.banner.text, Loc.t("tunnel_brute_down"), "the fall banner names the metro boss")
	t.check(not boss.warning_ring.visible and horde.boss == null, "death clears the warning and boss bar source")
	horde.clear()
	var reused: TunnelBrute = horde.spawn(&"tunnel_brute", "avenue_left", "gate") as TunnelBrute
	t.check(reused == boss and reused.rush == TunnelBrute.Rush.RECOVER and is_equal_approx(reused.rush_left, TunnelBrute.FIRST_WARNING),
		"pool reuse resets the rush timer")
	t.check(not reused.warning_ring.visible and reused.reel_left == 0.0, "pool reuse clears visual and blast state")
	Events.tunnel_brute_warning.disconnect(on_warning)
	game.queue_free()
	await t.frames(3)
	Profile.reset()
