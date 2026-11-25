extends RefCounted
## Placement, localized warnings, aura movement, interruption and pool reuse.

func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.set_setting("language", "en")
	for stage: int in Campaign.count():
		var waves: WaveSet = Campaign.waves(stage)
		for index: int in waves.waves.size():
			t.equal(waves.waves[index].count_of(&"terminal_brute"), 1 if stage == 17 and index == 2 else 0, "terminal boss appears only in stage 18 wave 3")
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(3)
	game.select_stage(17)
	game.start_match()
	await t.frames(5)
	var level: CityLevel = game.level
	level.director.stop()
	var horde: Horde = level.horde
	var boss: TerminalBrute = horde.spawn(&"terminal_brute", "avenue_right", "gate") as TerminalBrute
	t.check(boss != null and boss.data.is_boss and horde.boss == boss, "boss uses existing tracking")
	t.near(boss.full_health, 1900.0 * 1.12, 0.001, "boss uses terminal district scaling")
	t.equal(game.hud.banner.text, Loc.t("terminal_brute_incoming"), "arrival is localized")
	t.equal(game.hud.sub_banner.text, Loc.t("terminal_brute_advice"), "advice explains the signal")
	await t.frames(2)
	t.check(game.hud.boss_meter.visible and game.hud.boss_title.text == Loc.t("zombie_terminal_brute"), "boss health meter is visible")
	var health_before: float = boss.health
	boss.take_hit(100.0, false, boss.position, Vector3.FORWARD)
	t.near(health_before - boss.health, 100.0, 0.001, "body damage is unchanged")
	health_before = boss.health
	boss.take_hit(100.0, true, boss.position, Vector3.FORWARD)
	t.near(health_before - boss.health, 100.0 * boss.data.head_damage_scale, 0.001, "head damage is unchanged")
	boss.position = Vector3(0, 0, -80)
	boss.path = PackedVector3Array([boss.position, Vector3(0, 0, -20)])
	boss.path_index = 1
	var walker: Zombie = horde.spawn(&"walker", "avenue_right", "gate")
	var runner: Zombie = horde.spawn(&"runner", "avenue_right", "gate")
	var brute: Zombie = horde.spawn(&"brute", "avenue_right", "gate")
	var far: Zombie = horde.spawn(&"walker", "avenue_right", "gate")
	for entry: Array in [[walker, 2.0], [runner, 3.0], [brute, 4.0], [far, 20.0]]:
		var zombie: Zombie = entry[0]
		zombie.position = boss.position + Vector3(float(entry[1]), 0, 0)
		zombie.path = PackedVector3Array([zombie.position, zombie.position + Vector3(0, 0, 50)])
		zombie.path_index = 1
		zombie.state = Zombie.State.ADVANCE
	boss.signal_left = 0.01
	boss.tick(0.02)
	t.check(boss.signal_state == TerminalBrute.Rally.WARNING and boss.warning_ring.visible and not boss.aura_ring.visible, "warning precedes the aura")
	t.equal(game.hud.banner.text, Loc.t("terminal_brute_signal"), "HUD warns before the rally")
	t.near(boss.escort_speed_multiplier(walker), 1.0, 0.001, "warning does not boost movement")
	var start: Vector3 = walker.position
	var base_speed: float = walker.speed
	walker._walk(0.1, 1.0)
	t.near(start.distance_to(walker.position), base_speed * 0.1, 0.001, "ordinary movement while warning")
	boss.tick(TerminalBrute.WARNING_TIME + 0.01)
	t.check(boss.signal_state == TerminalBrute.Rally.ACTIVE and boss.warning_ring.visible and boss.aura_ring.visible, "active signal displays both rings")
	t.check(boss.warning_material.albedo_color.b > boss.warning_material.albedo_color.r, "active marker is blue")
	t.near(boss.scale.x * boss.aura_ring.scale.x * TerminalBrute.RALLY_RADIUS, 12.0, 0.001, "ring radius matches the range despite model scale")
	t.near(boss.scale.z * boss.aura_ring.scale.z * TerminalBrute.RALLY_RADIUS, 12.0, 0.001, "ring range matches along both axes")
	t.near(boss.escort_speed_multiplier(walker), 1.3, 0.001, "nearby walker is rallied")
	t.near(boss.escort_speed_multiplier(runner), 1.3, 0.001, "nearby runner is rallied")
	t.near(boss.escort_speed_multiplier(brute), 1.0, 0.001, "brutes cannot be rallied")
	t.near(boss.escort_speed_multiplier(far), 1.0, 0.001, "outside the radius is unaffected")
	t.near(boss.escort_speed_multiplier(boss), 1.0, 0.001, "boss never speeds itself up")
	start = walker.position
	walker._walk(0.2, 1.0)
	t.near(start.distance_to(walker.position), base_speed * 0.2 * 1.3, 0.001, "walk displacement is boosted 30 percent")
	t.near(walker.speed, base_speed, 0.001, "base speed is never mutated")
	t.check(walker.rally_animation_boosted, "walk animation follows the movement boost")
	runner.state = Zombie.State.BREACH
	t.near(boss.escort_speed_multiplier(runner), 1.0, 0.001, "no speed buff while breaching")
	runner.state = Zombie.State.ADVANCE
	var blast: ExplosionData = (level.defender.weapons[1] as Weapon).data.explosion
	health_before = boss.health
	boss.take_blast(100.0, boss.position + Vector3.RIGHT, 1.0, blast)
	t.near(health_before - boss.health, 100.0 * boss.data.blast_damage_scale, 0.001, "blast damage is ordinary")
	t.check(boss.signal_state == TerminalBrute.Rally.RECOVER and boss.reel_left > 0.0 and not boss.warning_ring.visible and not boss.aura_ring.visible, "blast cancels the aura")
	start = walker.position
	walker._walk(0.1, 1.0)
	t.near(start.distance_to(walker.position), base_speed * 0.1, 0.001, "nearby walker immediately returns to base speed")
	t.check(not walker.rally_animation_boosted, "walk animation returns to baseline")
	while boss.reel_left > 0.0:
		boss.tick(0.1)
	boss.signal_state = TerminalBrute.Rally.WARNING
	boss.signal_left = 1.0
	boss.take_blast(1.0, boss.position + Vector3.RIGHT, 1.0, blast)
	t.check(boss.signal_state == TerminalBrute.Rally.RECOVER and not boss.warning_ring.visible, "blast also cancels warning")
	while boss.reel_left > 0.0:
		boss.tick(0.1)
	boss.signal_state = TerminalBrute.Rally.ACTIVE
	boss.signal_left = 0.01
	boss.tick(0.02)
	t.check(boss.signal_state == TerminalBrute.Rally.RECOVER and not boss.aura_ring.visible, "aura expires after its bounded duration")
	boss.signal_state = TerminalBrute.Rally.ACTIVE
	boss.state = Zombie.State.BREACH
	boss.tick(0.01)
	t.check(boss.signal_state == TerminalBrute.Rally.RECOVER and not boss.aura_ring.visible, "breaching cancels the aura")
	boss.kill()
	t.check(not boss.aura_ring.visible and game.hud.banner.text == Loc.t("terminal_brute_down"), "death clears the aura and is announced")
	horde.clear()
	var reused: TerminalBrute = horde.spawn(&"terminal_brute", "avenue_right", "gate") as TerminalBrute
	t.check(reused == boss and reused.signal_state == TerminalBrute.Rally.RECOVER and not reused.warning_ring.visible and not reused.aura_ring.visible, "pool reuse resets signal state")
	t.near(reused.signal_left, TerminalBrute.FIRST_SIGNAL, 0.001, "pool reuse resets the initial delay")
	game.queue_free()
	await t.frames(3)
	Profile.reset()
