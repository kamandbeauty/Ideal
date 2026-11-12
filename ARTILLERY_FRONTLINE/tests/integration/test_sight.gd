extends RefCounted
## The sight that can be drawn in: how much closer it brings the street, what it
## does to the aim, when it lets go by itself, and its button on the HUD.


func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.reset()
	_numbers(t)
	await _on_the_gun(t)
	await _on_the_hud(t)
	Profile.reset()


## The rule itself: magnification is a ratio of tangents, not of angles.
func _numbers(t: TestContext) -> void:
	var aim: AimSettings = load("res://resources/aim/default_aim.tres")
	t.near(aim.fov_at(1.0), aim.fov_degrees, 0.0001, "with the naked eye the field of view is the gunner's own")
	t.near(aim.fov_at(0.2), aim.fov_degrees, 0.0001, "nothing pushes the street further away than that")
	var drawn: float = aim.fov_at(aim.zoom_factor)
	t.near(tan(deg_to_rad(aim.fov_degrees) * 0.5) / tan(deg_to_rad(drawn) * 0.5), aim.zoom_factor, 0.0001,
		"drawn in, everything on the screen is %.1f times as large (a field of %.1f degrees)" % [aim.zoom_factor, drawn])
	t.check(drawn > 12.0 and drawn < 25.0, "that is a gunner's sight, not a telescope (%.1f degrees)" % drawn)
	t.check(aim.zoom_time > 0.0 and aim.zoom_time <= 0.3, "it glides in, in a fraction of a second (%.2f s)" % aim.zoom_time)


func _on_the_gun(t: TestContext) -> void:
	var level: CityLevel = t.make_level()
	await t.frames(2)
	var defender: Defender = level.defender
	var aim: AimSettings = defender.aim_settings
	t.check(not defender.zoomed and is_zero_approx(defender.zoom), "the gunner starts with the naked eye")
	t.near(defender.camera.fov, aim.fov_degrees, 0.001, "and its field of view")
	t.check(not defender.toggle_zoom() and not defender.zoomed, "before the match begins the sight cannot be drawn in")
	level.begin_match()
	level.director.stop()
	t.check(defender.toggle_zoom() and defender.zoomed, "in a match it can")
	t.check(defender.zoom < 1.0, "it does not jump: the picture glides in")
	defender._process(aim.zoom_time * 0.5)
	t.check(defender.zoom > 0.3 and defender.zoom < 0.7, "half-way through the glide it is half-way in (%.2f)" % defender.zoom)
	t.check(defender.camera.fov < aim.fov_degrees and defender.camera.fov > aim.fov_at(aim.zoom_factor), "and so is the picture")
	defender._process(aim.zoom_time)
	t.near(defender.zoom, 1.0, 0.0001, "after the glide it is fully in")
	t.near(defender.magnification(), aim.zoom_factor, 0.0001, "the street is %.1f times closer" % aim.zoom_factor)
	t.near(defender.camera.fov, aim.fov_at(aim.zoom_factor), 0.001, "through a field of view of %.1f degrees" % aim.fov_at(aim.zoom_factor))
	t.near(defender.aim_scale(), 1.0 / aim.zoom_factor, 0.0001, "and a turn of the gun is worth that much more on the screen")

	# The same travel of the finger moves the picture as far as ever: the gun turns less.
	var sensitivity: float = float(Profile.setting("sensitivity"))
	defender.aim.set_aim(0.0, 0.0)
	defender.add_drag(Vector2(100.0, 0.0))
	t.near(defender.aim.target_yaw, 100.0 * aim.degrees_per_pixel * sensitivity / aim.zoom_factor, 0.0001, "drawn in, a drag turns the gun 1/%.1f as far" % aim.zoom_factor)
	defender._apply_aim()
	var direction_in: Vector3 = defender.aim_direction()
	defender.set_zoom(false, true)
	t.check(is_zero_approx(defender.zoom) and is_equal_approx(defender.camera.fov, aim.fov_degrees), "let out at once, the eye is naked again")
	t.check(defender.aim_direction().is_equal_approx(direction_in), "the sight changes the picture, not where the gun points")
	defender.aim.set_aim(0.0, 0.0)
	defender.add_drag(Vector2(100.0, 0.0))
	t.near(defender.aim.target_yaw, 100.0 * aim.degrees_per_pixel * sensitivity, 0.0001, "with the naked eye the same drag turns it the full way")

	# What shakes the picture is scaled with it, so a shot is no rougher through the sight.
	defender.set_zoom(true, true)
	defender.shake = Vector3(1.0, -0.5, 0.25)
	defender.punch = 2.0
	defender._apply_aim()
	t.near(rad_to_deg(defender.camera.rotation.x), 1.0 / aim.zoom_factor, 0.0001, "drawn in, the shake of a shot is scaled down with the field of view")
	t.near(defender.camera.fov, aim.fov_at(aim.zoom_factor) + 2.0 / aim.zoom_factor, 0.001, "and so is the jolt of a blast")
	Profile.set_setting("screen_shake", false)
	defender._apply_aim()
	t.check(defender.camera.rotation.is_zero_approx() and is_equal_approx(defender.camera.fov, aim.fov_at(aim.zoom_factor)),
		"with the shake switched off the drawn-in picture is still")
	Profile.set_setting("screen_shake", true)
	defender.shake = Vector3.ZERO
	defender.punch = 0.0

	# Rounds still go where the sight rests.
	var target: Zombie = level.horde.spawn(&"walker", "avenue_left", "gate")
	target.position = Vector3(2.0, 0.0, -60.0)
	target.speed = 0.0
	await t.physics_frames(3)
	var wanted: Vector2 = defender.aim_for(target.head_area.global_position)
	defender.aim.set_aim(wanted.x, wanted.y)
	defender._apply_aim()
	var gun: Weapon = defender.weapon
	gun.data = gun.data.duplicate()
	gun.data.spread_degrees = 0.0
	gun.state = WeaponState.new(gun.data)
	var health: float = target.health
	gun.set_trigger(true)
	gun._physics_process(1.0 / 60.0)
	gun.set_trigger(false)
	await t.physics_frames(8)
	t.check(target.health < health or not target.alive, "through the sight a round still lands where the cross rests, 60 m out")

	# The threat arrows know the picture is narrower.
	t.near(defender.view_fov(), aim.fov_at(aim.zoom_factor), 0.001, "the HUD is told the narrower view")

	# The sight lets go by itself when the gunner leaves the gun, and at the start of every match.
	defender.set_input_enabled(false)
	t.check(not defender.zoomed, "taken off the gun (a pause, the end of the match) the gunner lets the sight out")
	defender.set_input_enabled(true)
	defender.set_zoom(true, true)
	level.running = false
	level.begin_match()
	level.director.stop()
	t.check(not defender.zoomed and is_zero_approx(defender.zoom), "a new match starts with the naked eye")
	t.near(defender.camera.fov, aim.fov_degrees, 0.001, "at once, without a glide")

	# The launcher looks through the same sight.
	defender.select_weapon(1)
	defender.set_zoom(true, true)
	t.check(defender.weapon.data.kind == "rocket" and defender.zoomed, "the sight can be drawn in with the launcher on the shoulder too")
	t.near(defender.camera.fov, aim.fov_at(aim.zoom_factor), 0.001, "with the same picture")
	await t.discard(level)


func _on_the_hud(t: TestContext) -> void:
	var root: Window = t.tree.root
	var old_size: Vector2i = root.size
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await t.frames(3)
	root.size = Vector2i(1440, 810)
	var hud: Hud = game.hud
	game.start_match()
	await t.frames(3)
	var level: CityLevel = game.level
	level.director.stop()
	var defender: Defender = level.defender
	t.check(hud.zoom_button != null and hud.zoom_button.is_visible_in_tree(), "the HUD has a button for the sight")
	t.check(hud.zoom_button.radius * 2.0 >= UITheme.TOUCH, "a full touch target across (%.0f units)" % (hud.zoom_button.radius * 2.0))
	t.check(HudWidgets.ICONS.has(hud.zoom_button.kind), "with a picture of its own")
	t.check(not hud.zoom_button.lit and not hud.scope.visible, "with the naked eye it is unlit and the picture is clear to its edges")
	# A tap toggles; a finger resting on it does not flicker it, and it never starts an aim drag.
	hud.touch_down(3, hud.zoom_button.center())
	t.check(defender.zoomed, "a tap on it draws the sight in")
	hud.touch_drag(3, Vector2(40.0, 0.0))
	t.near(defender.aim.target_yaw, defender.aim_settings.start_yaw_degrees, 0.0001, "a finger sliding off the button does not turn the gun")
	hud.touch_up(3)
	t.check(defender.zoomed, "lifting the finger leaves it in")
	await _settle(t, defender)
	t.check(hud.zoom_button.lit, "the button stays lit while the sight is in")
	t.check(hud.scope.visible and hud.scope.modulate.a > 0.9, "the edges of the picture darken")
	t.near(hud.crosshair.zoom, 1.0, 0.001, "and the cross grows its long hairs")
	t.near(defender.camera.fov, defender.aim_settings.fov_at(defender.aim_settings.zoom_factor), 0.01, "the picture is the drawn-in one")
	# Firing with one thumb while the other holds the sight button down.
	hud.touch_down(4, hud.zoom_button.center())
	t.check(not defender.zoomed, "a second tap lets it out")
	hud.touch_up(4)
	await _settle(t, defender)
	t.check(not hud.zoom_button.lit and not hud.scope.visible and is_zero_approx(hud.crosshair.zoom), "and the HUD is as before")
	# Keyboard and mouse, for a desktop run.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Z
	key.pressed = true
	hud._input(key)
	t.check(defender.zoomed, "Z draws the sight in")
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_Z
	echo.pressed = true
	echo.echo = true
	hud._input(echo)
	t.check(defender.zoomed, "a key held down does not flicker it")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	hud._input(click)
	t.check(not defender.zoomed, "the right mouse button lets it out")
	# A pause freezes the gunner as he is: the button is dead, and on resuming he is still looking through the sight.
	hud._input(key)
	t.check(defender.zoomed, "(drawn in again)")
	game.pause()
	await t.frames(2)
	hud.touch_down(5, hud.zoom_button.center())
	hud.touch_up(5)
	hud._input(key)
	t.check(defender.zoomed, "while the game is paused neither the button nor the key changes the sight")
	game.resume()
	await t.frames(2)
	t.check(defender.zoomed and defender.input_enabled, "and after the pause the gunner is still looking through it")
	# The end of a match takes the gunner off the gun, and the sight with him.
	level.defense.apply_damage("wall", level.defense.wall_health + 1.0)
	t.check(level.over and not defender.zoomed, "when the wall is lost the sight is let out: the end is seen with the naked eye")
	# The hint line tells a new player about it.
	var told: bool = false
	for hint: Array in Hud.HINTS:
		if hint[0] == "hint_zoom":
			told = true
	t.check(told and Loc.TEXT.en.has("hint_zoom") and Loc.TEXT.fa.has("hint_zoom"), "the hints of the first minute mention the sight, in both languages")
	Engine.time_scale = 1.0
	game.to_menu()
	await t.frames(2)
	root.size = old_size
	game.queue_free()
	await t.frames(2)


## Waits for the glide of the sight to end.
func _settle(t: TestContext, defender: Defender) -> void:
	var goal: float = 1.0 if defender.zoomed else 0.0
	var waited: int = 0
	while not is_equal_approx(defender.zoom, goal) and waited < 600:
		await t.frames(1)
		waited += 1
	await t.frames(2)
