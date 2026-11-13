extends RefCounted
## Touch controls, HUD read-outs, menus and the game flow around them.


## Sends a real touch event through the viewport, the way the platform does.
## (Input.parse_input_event is not dispatched by the headless display server.)
func _touch(tree: SceneTree, index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	tree.root.push_input(event, true)


func _drag(tree: SceneTree, index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	tree.root.push_input(event, true)


func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.reset()
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(3)
	var hud: Hud = game.hud
	var menus: Menus = game.menus

	# Menus.
	t.equal(menus.screen, "main", "the title screen is shown")
	menus.show_settings("main")
	t.equal(menus.screen, "settings", "settings open from the title")
	Profile.set_setting("language", "en")
	await t.frames(1)
	t.equal(menus.screen, "settings", "changing language keeps the settings screen open")
	t.equal(Loc.language, "en", "the language switch takes effect")
	menus._show(menus.came_from)
	t.equal(menus.screen, "main", "BACK returns to where settings were opened")

	# Starting a match.
	game.start_match()
	await t.frames(4)
	var level: CityLevel = game.level
	var defender: Defender = level.defender
	t.equal(game.mode, 1, "DEFEND starts play")
	t.check(level.running and defender.input_enabled, "the level runs and takes input")
	t.check(hud.active and hud.root.visible and not menus.is_open(), "the HUD replaces the menu")
	t.equal(hud.wave_label.text, Loc.t("get_ready"), "the HUD announces the opening calm")
	t.equal(hud.ammo_label.text, str(defender.weapon.data.magazine_size), "the HUD shows a full magazine")

	# Layout and finger roles.
	var view: Vector2 = hud.get_viewport().get_visible_rect().size
	var fire: Vector2 = hud.fire_button.center()
	var reload: Vector2 = hud.reload_button.center()
	var pause: Vector2 = hud.pause_button.center()
	t.check(fire.x > view.x * 0.6 and fire.y > view.y * 0.6, "FIRE sits under the right thumb")
	t.check(hud.fire_button.radius >= 80.0 and hud.reload_button.radius >= 40.0, "the buttons are thumb-sized")
	t.check(fire.distance_to(reload) > hud.fire_button.radius + hud.reload_button.radius, "FIRE and RELOAD do not overlap")
	t.equal(hud.role_at(fire), "fire", "a touch on FIRE fires")
	t.equal(hud.role_at(reload), "reload", "a touch on RELOAD reloads")
	t.equal(hud.role_at(pause), "pause", "a touch on PAUSE pauses")
	t.equal(hud.role_at(view * 0.5), "aim", "a touch anywhere else aims")
	t.equal(hud.role_at(Vector2(view.x * 0.2, view.y * 0.7)), "aim", "the left half of the screen aims")

	# Two fingers at once: one holds FIRE, the other drags to aim.
	defender.aim.set_aim(0.0, 0.0)
	hud.touch_down(0, fire)
	t.check(defender.touch_fire and hud.fire_button.held, "finger 0 on FIRE pulls the trigger")
	hud.touch_down(1, view * 0.4)
	hud.touch_drag(1, Vector2(100.0, 0.0))
	var per_pixel: float = defender.aim_settings.degrees_per_pixel * float(Profile.setting("sensitivity"))
	t.near(defender.aim.target_yaw, 100.0 * per_pixel, 0.0001, "finger 1 dragging right turns the gun right")
	t.check(defender.touch_fire, "aiming with a second finger keeps the trigger held")
	hud.touch_drag(0, Vector2(0.0, -50.0))
	t.check(defender.aim.target_pitch > 0.0, "the firing finger can also drag to aim")
	hud.touch_up(1)
	t.check(defender.touch_fire, "lifting the aiming finger keeps firing")
	hud.touch_up(0)
	t.check(not defender.touch_fire and not hud.fire_button.held, "lifting the firing finger releases the trigger")
	hud.touch_drag(1, Vector2(500.0, 0.0))
	t.near(defender.aim.target_yaw, 100.0 * per_pixel, 0.0001, "a lifted finger no longer aims")
	Profile.set_setting("sensitivity", 2.0)
	defender.aim.set_aim(0.0, 0.0)
	hud.touch_down(4, view * 0.3)
	hud.touch_drag(4, Vector2(10.0, 0.0))
	hud.touch_up(4)
	t.near(defender.aim.target_yaw, 10.0 * defender.aim_settings.degrees_per_pixel * 2.0, 0.0001, "the sensitivity setting scales the drag")
	Profile.set_setting("sensitivity", 1.0)

	# The same through real input events.
	_touch(t.tree, 7, fire, true)
	await t.frames(2)
	t.check(defender.touch_fire, "a real touch event on FIRE reaches the gun")
	defender.aim.set_aim(0.0, 0.0)
	_touch(t.tree, 8, view * 0.35, true)
	_drag(t.tree, 8, view * 0.35 + Vector2(-60.0, 0.0), Vector2(-60.0, 0.0))
	t.near(defender.aim.target_yaw, -60.0 * per_pixel, 0.0001, "a real drag event from a second finger aims while firing")
	_touch(t.tree, 8, view * 0.35, false)
	await t.physics_frames(12)
	t.check(defender.weapon.state.shots > 0, "holding the touch fires rounds")
	_touch(t.tree, 7, fire, false)
	await t.frames(2)
	t.check(not defender.touch_fire, "releasing the touch stops firing")
	t.check(int(hud.ammo_label.text) < defender.weapon.data.magazine_size, "the ammo read-out follows the shots")
	hud.touch_down(2, reload)
	hud.touch_up(2)
	t.check(defender.weapon.state.reloading, "RELOAD starts a reload")
	await t.frames(2)
	t.check(hud.reload_label.visible, "the HUD shows that the gun is reloading")

	# Read-outs driven by events.
	Events.wall_damaged.emit(100.0, 500.0, 1000.0)
	t.near(hud.wall_meter.fraction, 0.5, 0.0001, "the wall meter follows wall health")
	t.equal(hud.wall_value.text, "50%", "the wall percentage is shown")
	Events.gate_damaged.emit(50.0, 175.0, 700.0)
	t.near(hud.gate_meter.fraction, 0.25, 0.0001, "the gate meter follows gate health")
	Events.defense_warning.emit("gate_critical")
	t.equal(hud.banner.text, Loc.t("warn_gate_critical"), "a critical warning is announced")
	t.check(hud.banner.modulate.a > 0.9, "the warning banner is visible")
	Events.defense_warning.emit("wall_attack")
	t.equal(hud.banner.text, Loc.t("warn_gate_critical"), "an attack notice does not talk over a critical warning")
	Events.wave_started.emit(1, 5)
	t.equal(hud.wave_label.text, "WAVE 2 / 5", "the wave counter is shown")
	Events.zombie_killed.emit(null, true)
	t.check(hud.kills_label.text.ends_with("1"), "kills are counted on the HUD")
	Events.gate_destroyed.emit()
	t.check(hud.gate_meter.broken and hud.banner.text == Loc.t("warn_gate_destroyed"), "the HUD marks the fallen gate")
	Profile.set_setting("language", "fa")
	t.equal(hud.wall_title.text, "دیوار", "HUD labels switch to Persian")
	t.equal(hud.wall_value.text, "۵۰٪", "HUD numbers switch to Persian digits")
	Profile.set_setting("language", "en")
	Profile.set_setting("left_handed", true)
	t.check(hud.fire_button.center().x < view.x * 0.4, "the left-handed layout moves FIRE to the left")
	Profile.set_setting("left_handed", false)
	t.check(hud.fire_button.center().x > view.x * 0.6, "and back again")

	# Pause and resume.
	hud.touch_down(3, hud.pause_button.center())
	hud.touch_up(3)
	t.equal(game.mode, 2, "PAUSE pauses the game")
	t.check(t.tree.paused and menus.screen == "pause" and not hud.active, "the tree stops and the pause menu shows")
	_touch(t.tree, 5, fire, true)
	t.check(not defender.touch_fire, "controls are dead while paused")
	_touch(t.tree, 5, fire, false)
	game.resume()
	t.check(not t.tree.paused and game.mode == 1 and hud.active, "RESUME continues the match")

	# Result screens and return to title.
	var matches: int = Profile.data.stats.matches
	Events.match_finished.emit(false, {"victory": false, "wave": 3, "kills": 21, "headshots": 4, "waves_cleared": 2, "waves_total": 5,
		"accuracy": 0.4, "time": 95.0, "wall_left": 0.0})
	t.equal(game.mode, 3, "the end of a match shows the result")
	t.check(menus.screen == "result" and not menus.result_victory, "the defeat screen is shown")
	t.equal(Profile.data.stats.matches, matches + 1, "the match is recorded in the profile")
	t.equal(Profile.data.stats.best_wave, 3, "the best wave is recorded")
	game.start_match()
	await t.frames(4)
	t.check(game.mode == 1 and game.level != level and game.level.running, "RESTART builds a fresh level")
	t.near(game.level.defense.wall_fraction(), 1.0, 0.0001, "the new match starts with an intact wall")
	game.to_menu()
	await t.frames(2)
	t.check(game.mode == 0 and menus.screen == "main" and not hud.active, "MAIN MENU returns to the title")
	t.tree.paused = false
	Profile.reset()
	await t.discard(game)
