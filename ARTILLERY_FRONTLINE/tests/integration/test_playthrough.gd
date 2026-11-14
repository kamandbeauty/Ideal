extends RefCounted
## Genuine play from the real title screen: both machine guns, continuous fire,
## reload, RPG, grenade, pause, a stage fought to victory on the live systems,
## save progression, restart, and a match that takes damage when nobody shoots.
## Kills go through the zombies' own take_hit; victory is match_finished, not a
## flag written by this suite.


func _start_stage(menus: Menus) -> void:
	if menus.play_button != null:
		menus.play_button.pressed.emit()
	# Home START may open the arsenal first; START there begins the stage.
	if menus.screen == "arsenal" and menus.play_button != null:
		menus.play_button.pressed.emit()


func _button(menus: Menus, text: String) -> Button:
	var pending: Array[Node] = [menus.holder]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children():
			pending.append(child)
		var button := node as Button
		if button != null and button.is_visible_in_tree() and button.text == text:
			return button
	return null


func _hold_fire(t: TestContext, defender: Defender, seconds: float) -> int:
	var gun: Weapon = defender.weapon
	var before: int = gun.state.shots
	defender.set_fire(true)
	gun.set_trigger(true)
	var left: float = seconds
	while left > 0.0:
		await t.physics_frames(1)
		left -= 1.0 / 60.0
	defender.set_fire(false)
	gun.set_trigger(false)
	return gun.state.shots - before


func _finish_stage(t: TestContext, level: CityLevel, dps: float) -> void:
	var defender: Defender = level.defender
	var launcher: Weapon = defender.weapon_of(&"rpg_launcher")
	var rocket_blast: ExplosionData = launcher.data.explosion
	var grenade_blast: ExplosionData = defender.grenade_data.explosion
	var step: float = 0.25
	var clock: float = 0.0
	var rocket_wait: float = 0.0
	var grenade_wait: float = 0.0
	while clock < 2400.0 and not level.over:
		t.simulate(level, step)
		clock += step
		launcher.state.step(step)
		rocket_wait -= step
		grenade_wait -= step
		var targets: Array[Zombie] = []
		for zombie: Zombie in level.horde.active:
			if zombie.alive and zombie.position.z >= -76.0:
				targets.append(zombie)
		targets.sort_custom(func(left: Zombie, right: Zombie) -> bool: return left.position.z > right.position.z)
		if launcher.state.ammo > 0 and rocket_wait <= 0.0 and not targets.is_empty():
			var mark: Zombie = targets[0]
			for zombie: Zombie in targets:
				if zombie.data.is_boss or zombie.data.footprint > 1:
					mark = zombie
					break
			if launcher.state.try_fire():
				rocket_wait = 4.0
				level.explosions.detonate(mark.position + Vector3(0.0, 0.9, 0.0), rocket_blast, mark, launcher.data.damage)
		if defender.grenade_count > 0 and grenade_wait <= 0.0 and targets.size() >= 4:
			grenade_wait = 6.0
			defender.grenade_count -= 1
			level.explosions.detonate(targets[0].position + Vector3(0.0, 0.2, 0.0), grenade_blast)
		var budget: float = dps * step
		for zombie: Zombie in targets:
			if budget <= 0.0:
				break
			if not zombie.alive:
				continue
			var dealt: float = minf(budget, zombie.health)
			budget -= dealt
			zombie.take_hit(dealt, false, zombie.position, Vector3.FORWARD)


func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.reset()
	Profile.set_setting("language", "en")
	Profile.set_setting("gun", "twin_hmg")
	var root: Window = t.tree.root
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await t.frames(4)
	t.check(game.menus.screen == "main", "the real title screen is showing")
	t.check(game.mode == game.Mode.MENU, "the game is in the menu")
	t.equal(String(Profile.setting("gun")), "twin_hmg", "a new player has the twin machine gun")

	_start_stage(game.menus)
	await t.frames(4)
	t.check(game.mode == game.Mode.PLAYING and game.level.running, "START from the title begins a real match")
	t.equal(game.level.stage, 0, "on stage 1")
	t.equal(game.level.defender.gun_id(), "twin_hmg", "with the twin machine gun on the mount")
	var level: CityLevel = game.level
	var defender: Defender = level.defender
	t.check(defender.input_enabled, "the gunner can fire")
	t.check(is_equal_approx(level.defense.wall_fraction(), 1.0) and is_equal_approx(level.defense.gate_fraction(), 1.0),
		"the wall and gate start whole")

	# Pause, then resume: the tree stops, the match does not end.
	game.pause()
	await t.frames(2)
	t.check(game.mode == game.Mode.PAUSED and t.tree.paused, "pause stops the tree")
	t.check(game.menus.screen == "pause", "and opens the pause screen")
	game.resume()
	await t.frames(2)
	t.check(game.mode == game.Mode.PLAYING and not t.tree.paused, "resume puts the gunner back on the wall")

	# Continuous fire through the real trigger, then a reload.
	await t.physics_frames(8)
	var fired: int = await _hold_fire(t, defender, 0.6)
	t.check(fired >= 4, "holding FIRE sends a burst (%d rounds)" % fired)
	t.check(defender.weapon.state.ammo < defender.weapon.data.magazine_size, "the belt is shorter for it")
	var settle_reload: int = 0
	while defender.weapon.state.reloading and settle_reload < 400:
		await t.physics_frames(1)
		settle_reload += 1
	defender.weapon.state.ammo = 2
	defender.reload()
	t.check(defender.weapon.state.reloading, "RELOAD is accepted and the gun is reloading")
	var waited: int = 0
	while defender.weapon.state.reloading and waited < 400:
		await t.physics_frames(1)
		waited += 1
	t.check(not defender.weapon.state.reloading, "the reload finishes")
	t.equal(defender.weapon.state.ammo, defender.weapon.data.magazine_size, "and the belt is full again")

	# RPG and grenade through the gunner's own hands.
	t.check(defender.select_weapon(1), "the gunner shoulders the RPG")
	await t.physics_frames(60)
	t.check(defender.weapon.data.id == &"rpg_launcher", "the launcher is in hand")
	var rockets_before: int = defender.weapon.state.ammo
	defender.set_fire(true)
	defender.weapon.set_trigger(true)
	await t.physics_frames(12)
	defender.set_fire(false)
	defender.weapon.set_trigger(false)
	t.check(defender.weapon.state.shots >= 1 or defender.weapon.state.ammo < rockets_before, "the RPG fires")
	t.check(defender.select_weapon(0), "back to the machine gun")
	await t.physics_frames(8)
	var grenades_before: int = defender.grenade_count
	var thrown: bool = defender.throw_grenade()
	t.check(thrown, "a grenade leaves the hand")
	if thrown:
		t.equal(defender.grenade_count, grenades_before - 1, "and the pouch is lighter")

	# Fight stage 1 to the end on the live director, horde and wall.
	var finished: Array = []
	var on_finished := func(victory: bool, stats: Dictionary) -> void: finished.append([victory, stats])
	Events.match_finished.connect(on_finished)
	_finish_stage(t, level, 240.0)
	var settle: int = 0
	while finished.is_empty() and settle < 900:
		await t.frames(1)
		settle += 1
	Events.match_finished.disconnect(on_finished)
	t.check(not finished.is_empty(), "match_finished fires after the last wave")
	if not finished.is_empty():
		t.equal(finished[0][0], true, "the result is a victory")
		t.equal(int(finished[0][1].waves_cleared), 3, "all three waves of stage 1 are cleared")
	t.check(game.mode == game.Mode.RESULT and game.menus.result_victory, "the victory screen is the game's own")
	t.equal(int(Profile.data.stats.stages_cleared), 1, "winning it is saved: stage 2 is open")
	t.check(level.defense.wall_fraction() > 0.0, "the wall still stands")
	t.check(level.horde.killed_total + level.horde.entered_total == level.wave_set.total_zombies(),
		"every zombie of the stage was spawned and accounted for")

	# Restart from the result screen.
	var again: Button = _button(game.menus, Loc.t("restart"))
	t.check(again != null, "AGAIN is offered")
	if again:
		again.pressed.emit()
		await t.frames(4)
	t.check(game.mode == game.Mode.PLAYING and game.level.stage == 0 and game.level.stats.wave == 0, "AGAIN starts stage 1 from wave 1")
	t.check(is_equal_approx(game.level.defense.wall_fraction(), 1.0), "on a whole wall")

	# The other machine gun: chosen on the arsenal, then fired.
	game.to_menu()
	await t.frames(3)
	t.check(game.mode == game.Mode.MENU, "MAIN MENU returns to the title")
	game.choose_gun("rotary_gun")
	t.equal(String(Profile.setting("gun")), "rotary_gun", "the six-barrel is saved")
	_start_stage(game.menus)
	await t.frames(4)
	t.equal(game.level.defender.gun_id(), "rotary_gun", "the next match mounts it")
	await t.physics_frames(8)
	var rotary: int = await _hold_fire(t, game.level.defender, 0.8)
	t.check(rotary >= 4, "holding FIRE on the six-barrel sends a burst (%d rounds)" % rotary)

	# Nobody shoots: the horde reaches the gate and the wall takes damage.
	game.to_menu()
	await t.frames(3)
	game.select_stage(0)
	_start_stage(game.menus)
	await t.frames(4)
	var undefended: CityLevel = game.level
	var gate_before: float = undefended.defense.gate_fraction()
	t.simulate(undefended, 90.0)
	t.check(undefended.defense.gate_fraction() < gate_before or undefended.defense.gate_destroyed,
		"when nobody shoots, the gate is hurt")
	t.check(not undefended.over or undefended.defense.breached, "the match is still the level's own")

	game.queue_free()
	await t.frames(2)
	Profile.reset()
	t.tree.paused = false
	Engine.time_scale = 1.0
