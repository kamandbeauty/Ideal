extends RefCounted
## The siege as the player meets it: three short stages, each opened by winning
## the one before, chosen on the title screen and played one at a time.


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


func _has_text(menus: Menus, text: String) -> bool:
	var pending: Array[Node] = [menus.holder]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children():
			pending.append(child)
		var label := node as Label
		if label != null and label.is_visible_in_tree() and label.text.contains(text):
			return true
	return false


## Ends the match in progress as the level itself would, having reached `wave` of its stage.
func _end(game: Node, victory: bool, wave: int) -> void:
	var level: CityLevel = game.level
	level.director.stop()
	level.over = true
	level.stats.wave = wave
	level.stats.waves_cleared = wave if victory else wave - 1
	level.stats.kills = 10 * wave
	level._finish(victory)


func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.reset()
	Profile.set_setting("language", "en")
	var root: Window = t.tree.root
	var old_size: Vector2i = root.size
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await t.frames(3)
	root.size = Vector2i(1440, 810)
	await t.frames(2)
	var menus: Menus = game.menus
	var hud: Hud = game.hud
	var stages: int = Campaign.count()
	t.equal(stages, 3, "the siege is fought in three stages")

	# A new player: one stage open, the others under a padlock.
	t.check(menus.screen == "main" and menus.stage_choices != null, "the title screen shows the stages")
	t.equal(menus.stage_choices.buttons.size(), stages, "one choice for each")
	t.equal(game.stage, 0, "a new player starts at the first")
	t.equal(menus.stage_choices.selected, 0, "which is the one lit")
	t.check(not menus.stage_choices.is_locked(0) and menus.stage_choices.is_locked(1) and menus.stage_choices.is_locked(2), "the second and third are locked")
	t.check(menus.stage_choices.buttons[1].disabled and menus.stage_choices.buttons[2].disabled, "and deaf to the thumb")
	var first: WaveSet = Campaign.waves(0)
	t.equal(first.waves.size(), 3, "the first stage has three waves")
	t.equal(menus.stage_brief.text, Loc.t("stage_brief", [1, first.waves.size(), first.total_zombies()]), "the title screen says what the lit stage holds: its waves and its zombies")
	menus.stage_choices._choose(1)
	t.check(menus.stage_choices.selected == 0 and game.stage == 0, "a tap on a locked stage changes nothing")
	t.check(not game.select_stage(1) and not game.select_stage(-1) and game.stage == 0, "and the game refuses a stage that is not open")

	# The first stage.
	_button(menus, Loc.t("play")).pressed.emit()
	await t.frames(3)
	var level: CityLevel = game.level
	t.check(game.mode == game.Mode.PLAYING and level.running, "PLAY starts the match")
	t.check(level.stage == 0 and level.wave_set == first, "on the waves of the first stage")
	t.equal(level.director.wave_count(), 3, "three of them")
	t.equal(level.stats.waves_total, 3, "the match is counted against those three")
	t.equal(level.stats.waves_before, 0, "with none of the siege behind it")
	t.equal(hud.wave_total, 3, "the HUD counts three waves")
	hud._on_wave_started(0, 3)
	t.equal(hud.banner.text, Loc.t("stage_wave", [1, 1]), "the banner of the first wave names the stage")
	hud._on_wave_started(1, 3)
	t.equal(hud.banner.text, Loc.t("wave_incoming", [2]), "the later ones only their wave")
	t.equal(hud.wave_label.text, Loc.t("wave", [2, 3]), "the wave plate counts within the stage")
	t.equal(int(game.match_status().stage), 1, "the pause screen is told which stage this is")
	game.pause()
	await t.frames(2)
	t.check(_has_text(menus, Loc.t("stage_n", [1])), "and says so")
	game.resume()
	await t.frames(2)

	# Losing it opens nothing.
	_end(game, false, 2)
	await t.frames(2)
	t.check(game.mode == game.Mode.RESULT and menus.screen == "result" and not menus.result_victory, "a lost stage ends on the defeat screen")
	t.check(_has_text(menus, Loc.t("defeat_title")) and _has_text(menus, Loc.t("fell_in_wave", [1, 2])), "which says in which stage and wave the wall fell")
	t.check(_button(menus, Loc.t("next_stage")) == null and not game.won_onward, "and offers no next stage")
	t.equal(int(Profile.data.stats.stages_cleared), 0, "nothing is opened by it")
	t.equal(int(Profile.data.stats.best_wave), 2, "the wave reached is kept")
	_button(menus, Loc.t("restart")).pressed.emit()
	await t.frames(3)
	t.check(game.mode == game.Mode.PLAYING and game.level.stage == 0 and game.level.stats.wave == 0, "AGAIN starts the same stage from its first wave")

	# Winning it opens the second, and the result screen leads straight on.
	_end(game, true, 3)
	await t.frames(2)
	t.check(menus.result_victory and menus.result_onward and game.won_onward, "a stage that is won, with another after it, is not the end of the siege")
	t.check(_has_text(menus, Loc.t("stage_won_title", [1])) and not _has_text(menus, Loc.t("victory_title")), "the result screen says the stage was held, and keeps the last word for the last stage")
	t.check(_has_text(menus, "3 / 3"), "all three of its waves are counted as held")
	t.equal(int(Profile.data.stats.stages_cleared), 1, "the second stage is open from now on")
	var onward: Button = _button(menus, Loc.t("next_stage"))
	t.check(onward != null and onward.size.y >= UITheme.TOUCH - 0.5, "NEXT STAGE is offered, a full touch target high")
	t.check(_button(menus, Loc.t("restart")) != null and _button(menus, Loc.t("main_menu")) != null, "beside AGAIN and MAIN MENU")
	onward.pressed.emit()
	await t.frames(3)
	level = game.level
	t.check(game.mode == game.Mode.PLAYING and game.stage == 1 and level.stage == 1, "it starts the second stage")
	t.check(level.wave_set == Campaign.waves(1) and level.director.wave_count() == Campaign.waves(1).waves.size(), "on its own waves")
	t.equal(level.stats.waves_before, 3, "which come after the three already fought")
	t.check(is_equal_approx(level.defense.wall_fraction(), 1.0) and is_equal_approx(level.defense.gate_fraction(), 1.0), "every stage begins on a whole wall and gate")
	var launcher: Weapon = level.defender.weapons[1]
	t.check(launcher.state.ammo == launcher.data.magazine_size and launcher.state.reserve == launcher.data.reserve, "with the rockets a match starts with")
	t.equal(level.defender.grenade_count, mini(level.defender.grenade_data.carried, level.defender.grenade_data.capacity), "and its grenades")
	hud._on_wave_started(0, level.director.wave_count())
	t.equal(hud.banner.text, Loc.t("stage_wave", [2, 1]), "its first banner names the second stage")
	# The zombies of a later stage carry the hardening of the waves before it.
	var later: WaveSet = Campaign.waves(1)
	t.equal(later.waves_before, 3, "the second stage knows three waves lie behind it")
	t.check(later.health_scale(0) > first.health_scale(0), "so its first wave is tougher than the first wave of the siege (%.2f against %.2f)" % [later.health_scale(0), first.health_scale(0)])

	# Falling in the second stage: the record counts waves of the whole siege.
	_end(game, false, 2)
	await t.frames(2)
	t.check(_has_text(menus, Loc.t("fell_in_wave", [2, 2])), "the defeat screen names stage 2, wave 2")
	t.equal(int(Profile.data.stats.best_wave), 5, "that is the fifth wave of the siege, and the record says so")
	t.check(menus.result_record, "it is further than this player had been, and is marked as a record")
	t.equal(int(Profile.data.stats.stages_cleared), 1, "the third stage stays shut")
	_button(menus, Loc.t("main_menu")).pressed.emit()
	await t.frames(3)
	t.check(game.mode == game.Mode.MENU and menus.screen == "main", "MAIN MENU goes back to the title")
	t.equal(menus.stage_choices.selected, 1, "where the stage just fought is still the one lit")
	t.check(not menus.stage_choices.is_locked(0) and not menus.stage_choices.is_locked(1) and menus.stage_choices.is_locked(2), "the first two are open, the third locked")
	t.check(_has_text(menus, Loc.t("best_run", [2, 2])), "the record is written as a stage and a wave")
	t.equal(game.level.stage, 1, "the street behind the menu is laid for that stage")

	# An earlier stage can be played again.
	menus.stage_choices.buttons[0].pressed.emit()
	await t.frames(2)
	t.check(game.stage == 0 and menus.stage == 0 and menus.stage_choices.selected == 0, "a tap on an open stage picks it")
	t.equal(menus.stage_brief.text, Loc.t("stage_brief", [1, first.waves.size(), first.total_zombies()]), "and the line above the choices describes it")
	menus.show_settings("main")
	await t.frames(2)
	menus.show_main()
	await t.frames(2)
	t.equal(menus.stage_choices.selected, 0, "the choice survives a visit to the settings")
	Profile.set_setting("language", "fa")
	await t.frames(2)
	t.check(menus.stage_choices.selected == 0 and menus.stage_brief.text == Loc.t("stage_brief", [1, first.waves.size(), first.total_zombies()]), "and a change of language")
	Profile.set_setting("language", "en")
	await t.frames(2)
	_button(menus, Loc.t("play")).pressed.emit()
	await t.frames(3)
	t.check(game.level.stage == 0 and game.level.director.wave_count() == 3, "PLAY starts the stage that was picked")
	_end(game, true, 3)
	await t.frames(2)
	t.equal(int(Profile.data.stats.stages_cleared), 1, "winning an old stage again opens nothing new")
	t.equal(int(Profile.data.stats.best_wave), 5, "and does not lower the record")
	t.check(not menus.result_record, "nor is it one")
	t.check(menus.result_onward and _button(menus, Loc.t("next_stage")) != null, "but it still leads on to the stage after it")

	# Leaving a won stage by MAIN MENU: the title offers the next one.
	_button(menus, Loc.t("main_menu")).pressed.emit()
	await t.frames(3)
	t.check(game.stage == 1 and menus.stage_choices.selected == 1, "back on the title after a won stage, the next one is lit")

	# The second stage won, then the third: the siege is over.
	_button(menus, Loc.t("play")).pressed.emit()
	await t.frames(3)
	_end(game, true, Campaign.waves(1).waves.size())
	await t.frames(2)
	t.equal(int(Profile.data.stats.stages_cleared), 2, "winning the second stage opens the third")
	_button(menus, Loc.t("next_stage")).pressed.emit()
	await t.frames(3)
	level = game.level
	var last: WaveSet = Campaign.waves(2)
	t.check(level.stage == 2 and level.wave_set == last, "the third stage is the last")
	t.equal(level.stats.waves_before, Campaign.total_waves() - last.waves.size(), "everything before it counted")
	var bosses: int = 0
	for wave: WaveData in last.waves:
		bosses += wave.count_of(&"boss")
	t.equal(bosses, 1, "the boss waits in it")
	_end(game, true, last.waves.size())
	await t.frames(2)
	t.check(menus.result_victory and not menus.result_onward and not game.won_onward, "winning it ends the siege")
	t.check(_has_text(menus, Loc.t("victory_title")) and _button(menus, Loc.t("next_stage")) == null, "with the victory screen, and no next stage to go to")
	t.equal(int(Profile.data.stats.stages_cleared), stages, "every stage is won")
	t.equal(int(Profile.data.stats.best_wave), Campaign.total_waves(), "and the record is the last wave of the siege")
	_button(menus, Loc.t("main_menu")).pressed.emit()
	await t.frames(3)
	var locked: int = 0
	for index: int in stages:
		if menus.stage_choices.is_locked(index):
			locked += 1
	t.check(locked == 0 and menus.stage_choices.selected == 2, "the title shows all three open, the last one lit")
	t.check(_has_text(menus, Loc.t("best_run", [3, last.waves.size()])), "and the record as the last wave of the last stage")
	# A profile that loses its progress under a running game (a save wiped from outside) cannot leave a locked stage playable.
	Profile.reset()
	Profile.set_setting("language", "en")
	_button(menus, Loc.t("play")).pressed.emit()
	await t.frames(3)
	t.check(game.stage == 0 and game.level.stage == 0 and game.level.wave_set == first, "with the progress gone, PLAY starts the first stage whatever was lit")
	game.to_menu()
	await t.frames(3)
	t.check(menus.stage_choices.selected == 0 and menus.stage_choices.is_locked(1), "and the title shows the stages locked again")
	game.queue_free()
	await t.frames(2)

	# The game opened again later: it offers the newest stage that is open.
	Profile.reset()
	Profile.data.stats.stages_cleared = 1
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await t.frames(3)
	t.equal(game.stage, 1, "a player who has won the first stage is offered the second on opening the game")
	t.equal(game.menus.stage_choices.selected, 1, "lit on the title screen")
	t.equal(game.level.stage, 1, "with the street laid for it")
	game.queue_free()
	await t.frames(2)
	Profile.reset()
	Profile.data.stats.stages_cleared = stages
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await t.frames(3)
	t.equal(game.stage, stages - 1, "one who has won them all, the last")
	game.queue_free()
	await t.frames(2)
	root.size = old_size
	Profile.reset()
