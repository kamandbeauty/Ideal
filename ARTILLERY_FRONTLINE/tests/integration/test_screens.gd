extends RefCounted
## The HUD and the menus on screens of other shapes, beside camera cut-outs and
## in both reading directions, and the rules that make every control safe under a thumb.

const SHAPES: Array = [[Vector2i(1440, 810), "16:9"], [Vector2i(1800, 810), "20:9"], [Vector2i(1440, 1080), "4:3"]]


func _visible_controls(under: Node) -> Array[Control]:
	var found: Array[Control] = []
	var pending: Array[Node] = [under]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children():
			pending.append(child)
		var control := node as Control
		if control != null and control.is_visible_in_tree() and control.size.x > 0.0 and control.size.y > 0.0:
			found.append(control)
	return found


## What a thumb can press on a menu: buttons, switches and sliders (a row is only the wider target of its own switch).
func _pressables(menus: Menus) -> Array[Control]:
	var found: Array[Control] = []
	for control: Control in _visible_controls(menus.holder):
		if control is BaseButton or control is MenuWidgets.Switch or control is MenuWidgets.SlideBar:
			found.append(control)
	return found


## Texts and pressable controls of the open menu that are not wholly inside `inside`.
func _strays(menus: Menus, inside: Rect2) -> Array[String]:
	var strays: Array[String] = []
	for control: Control in _visible_controls(menus.holder):
		if not (control is BaseButton or control is Label or control is MenuWidgets.Switch or control is MenuWidgets.SlideBar):
			continue
		if not inside.grow(0.5).encloses(control.get_global_rect()):
			strays.append("%s %s" % [control.get_class(), str(control.get_global_rect())])
	return strays


func _overlaps(controls: Array[Control]) -> Array[String]:
	var found: Array[String] = []
	for first: int in controls.size():
		for second: int in range(first + 1, controls.size()):
			if controls[first].get_global_rect().grow(-0.5).intersects(controls[second].get_global_rect().grow(-0.5)):
				found.append("%s / %s" % [str(controls[first].get_global_rect()), str(controls[second].get_global_rect())])
	return found


func _button(menus: Menus, text: String) -> Button:
	for control: Control in _visible_controls(menus.holder):
		if control is Button and (control as Button).text == text:
			return control
	return null


func _has_text(menus: Menus, text: String) -> bool:
	for control: Control in _visible_controls(menus.holder):
		if control is Label and (control as Label).text.contains(text):
			return true
	return false


## The HUD's parts that belong to an edge of the screen: [rectangle, name]. Full-width overlays and the sight are left out.
func _hud_parts(hud: Hud, view: Vector2) -> Array:
	var parts: Array = []
	for child: Node in hud.root.get_children():
		var control := child as Control
		if control == null or not control.is_visible_in_tree() or control.modulate.a <= 0.01 or control == hud.crosshair:
			continue
		var box: Rect2 = control.get_global_rect()
		if box.size.x <= 1.0 or box.size.y <= 1.0 or box.size.x >= view.x - 1.0:
			continue
		parts.append([box, control.get_class()])
	return parts


func _hud_span(hud: Hud, view: Vector2) -> Vector2:
	var from: float = view.x
	var to: float = 0.0
	for part: Array in _hud_parts(hud, view):
		from = minf(from, (part[0] as Rect2).position.x)
		to = maxf(to, (part[0] as Rect2).end.x)
	return Vector2(from, to)


func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.reset()
	var root: Window = t.tree.root
	var old_size: Vector2i = root.size

	# The margin rule itself.
	t.equal(UITheme.TOUCH, 88.0, "a touch target is 88 canvas units, 7.4 mm on a 6.5-inch phone")
	t.equal(Hud.margins_for(Vector2(1440.0, 810.0), Vector2.ZERO), Vector2(Hud.MARGIN, Hud.MARGIN), "on a 16:9 screen the HUD keeps its plain margin")
	var wide: Vector2 = Hud.margins_for(Vector2(1800.0, 810.0), Vector2.ZERO)
	t.check(wide.x > Hud.MARGIN and wide.x <= Hud.MARGIN + Hud.WIDE_BONUS and wide.x == wide.y, "a 20:9 screen gets more, for its rounded corners (%.0f)" % wide.x)
	t.equal(Hud.margins_for(Vector2(1440.0, 1080.0), Vector2.ZERO), Vector2(Hud.MARGIN, Hud.MARGIN), "a 4:3 tablet does not")
	var notched: Vector2 = Hud.margins_for(Vector2(1800.0, 810.0), Vector2(120.0, 0.0))
	t.near(notched.x, 140.0, 0.001, "past a cut-out a gap of 20 units is kept")
	t.near(notched.y, wide.y, 0.001, "and the side without one is left alone")
	t.equal(Hud.margins_for(Vector2(1800.0, 810.0), Vector2(30.0, 0.0)), wide, "a cut-out shallower than the margin changes nothing")

	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await t.frames(3)
	var hud: Hud = game.hud
	var menus: Menus = game.menus
	game.start_match()
	await t.frames(4)
	var level: CityLevel = game.level
	level.director.stop()

	# The HUD on three shapes of screen, in both languages, with both threat arrows up.
	for shape: Array in SHAPES:
		root.size = shape[0]
		await t.frames(2)
		var view: Vector2 = hud.get_viewport().get_visible_rect().size
		t.check(view.is_equal_approx(Vector2(shape[0])), "the canvas of a %s screen is %d x %d" % [shape[1], shape[0].x, shape[0].y])
		var margins: Vector2 = Hud.margins_for(view, Vector2.ZERO)
		for language: String in Profile.LANGUAGES:
			Profile.set_setting("language", language)
			level.defender.aim.set_aim(0.0, -4.0)
			hud.wall_threat = level.layout.patch_center
			hud.wall_struck = 0.0
			hud.gate_struck = 0.0
			await t.frames(2)
			var label: String = "%s, %s" % [shape[1], language]
			t.check(hud.wall_arrow.visible and hud.gate_arrow.visible and hud.wall_arrow_label.visible, "%s: both threat arrows are up" % label)
			var outside: Array[String] = []
			t.check(_hud_parts(hud, view).size() >= 30, "%s: the HUD is up (%d parts)" % [label, _hud_parts(hud, view).size()])
			for part: Array in _hud_parts(hud, view):
				var box: Rect2 = part[0]
				if box.position.x < margins.x - 0.5 or box.end.x > view.x - margins.y + 0.5 or box.position.y < 0.0 or box.end.y > view.y:
					outside.append("%s %s" % [part[1], str(box)])
			t.check(outside.is_empty(), "%s: every part of the HUD is on the screen and inside the margins (%s)" % [label, str(outside)])
			var buttons: Array[HudWidgets.RoundButton] = [hud.fire_button, hud.reload_button, hud.grenade_button, hud.pause_button, hud.zoom_button]
			var apart: bool = true
			for first: int in buttons.size():
				for second: int in range(first + 1, buttons.size()):
					if buttons[first].center().distance_to(buttons[second].center()) < buttons[first].radius + buttons[second].radius + 4.0:
						apart = false
			t.check(apart, "%s: the thumb buttons do not touch each other" % label)
			# The cards of the two weapons and the buttons are found by a touch at their middle.
			var found: bool = hud.role_at(hud.fire_button.center()) == "fire" and hud.role_at(hud.reload_button.center()) == "reload" \
				and hud.role_at(hud.grenade_button.center()) == "grenade" and hud.role_at(hud.pause_button.center()) == "pause" \
				and hud.role_at(hud.zoom_button.center()) == "zoom" \
				and hud.role_at(hud.weapon_slots[0].center()) == "weapon_0" and hud.role_at(hud.weapon_slots[1].center()) == "weapon_1" \
				and hud.role_at(view * 0.5) == "aim"
			t.check(found, "%s: every control is found where it is drawn" % label)
			# The weapon cards are rectangles: clear of each other and of every round button.
			var cards: Array[Control] = [hud.weapon_slots[0], hud.weapon_slots[1]]
			var clear: bool = _overlaps(cards).is_empty()
			for card: Control in cards:
				var box: Rect2 = card.get_global_rect()
				for button: HudWidgets.RoundButton in buttons:
					var at: Vector2 = button.center()
					var nearest := Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.y, box.position.y, box.end.y))
					if nearest.distance_to(at) < button.radius + 4.0:
						clear = false
			t.check(clear, "%s: the weapon cards are clear of each other and of the buttons" % label)
			# A threat arrow may come up at either edge, at either of its two heights: wherever it does, it and its
			# caption stay off the thumb buttons, for a right hand and for a left.
			for left_handed: bool in [false, true]:
				Profile.set_setting("left_handed", left_handed)
				await t.frames(2)
				var covered: Array[String] = []
				for side: float in [-1.0, 1.0]:
					for placing: Array in [[hud.gate_arrow, hud.gate_arrow_label, Hud.GATE_ARROW_HEIGHT], [hud.wall_arrow, hud.wall_arrow_label, Hud.WALL_ARROW_HEIGHT]]:
						hud._place_arrow(placing[0], placing[1], true, side, view, placing[2])
						for box: Rect2 in [(placing[0] as Control).get_global_rect(), (placing[1] as Control).get_global_rect()]:
							for button: HudWidgets.RoundButton in [hud.fire_button, hud.reload_button, hud.grenade_button, hud.pause_button, hud.zoom_button]:
								var at: Vector2 = button.center()
								var nearest := Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.y, box.position.y, box.end.y))
								if nearest.distance_to(at) < button.radius + 2.0:
									covered.append("%s on %s" % [str(box), button.kind])
				t.check(covered.is_empty(), "%s, %s hand: no threat arrow or caption lies on a thumb button (%s)" % [label, "left" if left_handed else "right", str(covered)])
			Profile.set_setting("left_handed", false)
			await t.frames(2)
		t.check(hud.fire_button.radius >= 80.0 and hud.reload_button.radius >= 40.0 and hud.grenade_button.radius >= 44.0 and hud.pause_button.radius >= 30.0
			and hud.zoom_button.radius >= 44.0,
			"%s: the buttons keep their size" % shape[1])
		t.check(hud.weapon_slots[0].size.y >= 76.0 and hud.weapon_slots[0].size.x >= 150.0, "%s: a weapon card is a thumb wide and high" % shape[1])
		t.check(hud.crosshair.get_global_rect().get_center().is_equal_approx(view * 0.5), "%s: the sight is in the middle of the screen" % shape[1])

	# Cut-outs, on the 20:9 phone: left, right, and with the controls changed over for a left hand.
	root.size = Vector2i(1800, 810)
	Profile.set_setting("language", "fa")
	await t.frames(2)
	var canvas: Vector2 = hud.get_viewport().get_visible_rect().size
	hud.inset_override = Vector2(120.0, 0.0)
	hud._layout()
	await t.frames(2)
	var span: Vector2 = _hud_span(hud, canvas)
	t.check(span.x >= 139.5, "beside a cut-out on the left nothing of the HUD comes within 20 units of it (from %.0f)" % span.x)
	t.check(span.y <= canvas.x - wide.y + 0.5 and span.y > canvas.x - wide.y - 30.0, "and the right side keeps its ordinary margin (to %.0f)" % span.y)
	var fire_before: Vector2 = hud.fire_button.center()
	Profile.set_setting("left_handed", true)
	await t.frames(2)
	t.check(hud.fire_button.center().x - hud.fire_button.radius >= 139.5, "left-handed, FIRE moves beside the cut-out and stays clear of it")
	t.near(hud.fire_button.center().y, fire_before.y, 0.001, "at the same height")
	t.check(_hud_span(hud, canvas).x >= 139.5, "and so does everything else")
	Profile.set_setting("left_handed", false)
	hud.inset_override = Vector2(0.0, 120.0)
	hud._layout()
	await t.frames(2)
	span = _hud_span(hud, canvas)
	t.check(span.y <= canvas.x - 139.5 and span.x <= wide.x + 0.5, "a cut-out on the right moves the right-hand controls inward instead (to %.0f)" % span.y)
	hud.inset_override = Vector2(-1.0, -1.0)
	hud._layout()

	# The pause screen says where the match stands, and asks twice before throwing it away.
	game.pause()
	await t.frames(2)
	t.equal(menus.screen, "pause", "PAUSE opens the pause screen")
	t.check(menus.pause_status.has("wave") and menus.pause_status.has("wall") and menus.pause_status.has("gate"), "which is told where the match stands")
	t.check(_has_text(menus, Loc.t("wall")) and _has_text(menus, Loc.percent(level.defense.wall_fraction())), "and says so")
	var restarts: Array = []
	var leaves: Array = []
	var count_restart := func() -> void: restarts.append(1)
	var count_leave := func() -> void: leaves.append(1)
	# (The game listens too; it is cut off here so the match is not actually thrown away.)
	var listeners: Array = menus.restart_requested.get_connections() + menus.menu_requested.get_connections()
	for link: Dictionary in listeners:
		(link.signal as Signal).disconnect(link.callable)
	menus.restart_requested.connect(count_restart)
	menus.menu_requested.connect(count_leave)
	var restart: Button = _button(menus, Loc.t("restart"))
	var leave: Button = _button(menus, Loc.t("main_menu"))
	t.check(restart != null and leave != null, "the pause screen has RESTART and MAIN MENU")
	restart.pressed.emit()
	t.check(restarts.is_empty() and menus.armed == restart and restart.text == Loc.t("confirm"), "one tap on RESTART only asks to be confirmed")
	menus._process(Menus.CONFIRM_TIME + 0.1)
	t.check(menus.armed == null and restart.text == Loc.t("restart"), "left alone for %.0f s it stands down" % Menus.CONFIRM_TIME)
	restart.pressed.emit()
	leave.pressed.emit()
	t.check(menus.armed == leave and restart.text == Loc.t("restart") and leave.text == Loc.t("confirm"), "a tap on the other button moves the question there")
	t.check(restarts.is_empty() and leaves.is_empty(), "and still nothing is thrown away")
	leave.pressed.emit()
	t.equal(leaves.size(), 1, "the second tap on the same button does it")
	restart.pressed.emit()
	restart.pressed.emit()
	t.equal(restarts.size(), 1, "and so do two taps on RESTART")
	menus.restart_requested.disconnect(count_restart)
	menus.menu_requested.disconnect(count_leave)
	for link: Dictionary in listeners:
		(link.signal as Signal).connect(link.callable)

	# Every menu, on every shape, in both languages: on the screen, thumb-sized, nothing overlapping.
	var stats: Dictionary = {"wave": 8, "waves_cleared": 8, "waves_total": 8, "kills": 325, "headshots": 65, "accuracy": 0.47, "time": 486.0,
		"wall_left": 0.82, "gate_left": 0.37, "rockets": 9, "grenades": 7, "blast_kills": 64, "special_kills": 141, "bosses": 1}
	for shape: Array in SHAPES:
		root.size = shape[0]
		await t.frames(2)
		var view: Vector2 = menus.get_viewport().get_visible_rect().size
		for language: String in Profile.LANGUAGES:
			Profile.set_setting("language", language)
			for screen: String in ["main", "settings", "pause", "result"]:
				match screen:
					"main":
						menus.show_main()
					"settings":
						menus.show_settings("pause")
					"pause":
						menus.show_pause({"wave": 3, "waves": 8, "wall": 0.5, "gate": 0.25})
					"result":
						menus.show_result(true, stats, true)
				await t.frames(2)
				var label: String = "%s, %s, %s" % [shape[1], language, screen]
				t.check(menus._is_laid_out(), "%s: the screen is built for this canvas" % label)
				var strays: Array[String] = _strays(menus, Rect2(Vector2.ZERO, view))
				t.check(strays.is_empty(), "%s: every text and control is on the screen (%s)" % [label, str(strays)])
				var small: Array[String] = []
				var pressables: Array[Control] = _pressables(menus)
				for control: Control in pressables:
					var needed: float = 72.0 if (control is MenuWidgets.Switch or control is MenuWidgets.SlideBar) else 84.0
					if control.size.y < needed - 0.5 or control.size.x < 84.0:
						small.append("%s %s" % [control.get_class(), str(control.size)])
				t.check(not pressables.is_empty() and small.is_empty(), "%s: all %d controls are thumb-sized (%s)" % [label, pressables.size(), str(small)])
				t.check(_overlaps(pressables).is_empty(), "%s: no two controls overlap" % label)
				t.equal(menus.holder.layout_direction, Control.LAYOUT_DIRECTION_RTL if language == "fa" else Control.LAYOUT_DIRECTION_LTR,
					"%s: laid out in the reading direction" % label)

	# The title screen in detail: the title at the reading edge, the card of the coming battle at the other,
	# with the gun between them; a player with a career has two more lines under the title.
	for career: bool in [false, true]:
		Profile.data.stats.matches = 12 if career else 0
		Profile.data.stats.victories = 7 if career else 0
		Profile.data.stats.kills = 23456 if career else 0
		Profile.data.stats.best_wave = 8 if career else 0
		Profile.data.stats.stages_cleared = 3 if career else 0
		for shape: Array in SHAPES:
			root.size = shape[0]
			await t.frames(2)
			var view: Vector2 = menus.get_viewport().get_visible_rect().size
			var margins: Vector2 = Hud.margins_for(view, Vector2.ZERO)
			for language: String in Profile.LANGUAGES:
				Profile.set_setting("language", language)
				for gun: String in Profile.GUNS:
					Profile.set_setting("gun", gun)
					menus.show_main()
					await t.frames(2)
					var label: String = "%s, %s, %s%s" % [shape[1], language, gun, ", with a career" if career else ""]
					var title: Control = menus.stage_brief
					var card: Control = menus.stage_brief.get_parent().get_parent()
					var column: Control = null
					for control: Control in _visible_controls(menus.holder):
						if control is Label and (control as Label).text == Loc.t("title"):
							column = control.get_parent()
					t.check(column != null and card is PanelContainer and title != null, "%s: the title screen has its title and its card" % label)
					var title_box: Rect2 = column.get_global_rect()
					var card_box: Rect2 = card.get_global_rect()
					t.check(_strays(menus, Rect2(margins.x, 0.0, view.x - margins.x - margins.y, view.y)).is_empty(), "%s: every text and control is on the screen, inside the margins" % label)
					t.check(Rect2(Vector2.ZERO, view).encloses(card_box) and Rect2(Vector2.ZERO, view).encloses(title_box), "%s: so are the two blocks themselves" % label)
					var gap: float = (title_box.position.x - card_box.end.x) if language == "fa" else (card_box.position.x - title_box.end.x)
					t.check(gap >= 200.0, "%s: the title stands at the reading edge and the card at the other, with the street between (%.0f units)" % [label, gap])
					t.check(card_box.end.y <= view.y * 0.76, "%s: the card ends above the gun (at %.0f of %.0f)" % [label, card_box.end.y, view.y])
					t.check(menus.gun_note.get_line_count() <= 2, "%s: the line about the gun fits the two lines kept for it" % label)
					var cut: Array[String] = []
					for button: Button in menus.stage_choices.buttons + menus.gun_choices.buttons:
						if button.get_minimum_size().x > button.size.x + 0.5:
							cut.append(button.text)
					t.check(cut.is_empty(), "%s: every name on a choice fits its button (%s)" % [label, str(cut)])
	Profile.reset()

	# The settings screen in detail (16:9, Persian).
	root.size = Vector2i(1440, 810)
	Profile.set_setting("language", "fa")
	menus.show_settings("pause")
	await t.frames(2)
	var rows: Array[MenuWidgets.Row] = []
	var switches: Array[MenuWidgets.Switch] = []
	var sliders: Array[MenuWidgets.SlideBar] = []
	for control: Control in _visible_controls(menus.holder):
		if control is MenuWidgets.Row:
			rows.append(control)
		elif control is MenuWidgets.Switch:
			switches.append(control)
		elif control is MenuWidgets.SlideBar:
			sliders.append(control)
	t.equal(rows.size(), 9, "nine settings stand in rows")
	t.equal(switches.size(), 4, "four of them are switches")
	t.equal(sliders.size(), 4, "four are sliders")
	var short_rows: int = 0
	for row: MenuWidgets.Row in rows:
		if row.size.y < UITheme.TOUCH - 0.5:
			short_rows += 1
	t.equal(short_rows, 0, "every row is as tall as a button")
	# A tap anywhere on the row of a switch flips it; the whole row is the target.
	var invert_row: MenuWidgets.Row = null
	for row: MenuWidgets.Row in rows:
		if row.toggle != null and row.get_child(0) is Label and (row.get_child(0) as Label).text == Loc.t("invert_y"):
			invert_row = row
	t.check(invert_row != null, "the invert-aim setting has a row with a switch")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = Vector2(20.0, 20.0)
	invert_row._gui_input(tap)
	t.equal(Profile.setting("invert_y"), true, "a tap on the name of a switch setting flips it")
	t.check(invert_row.toggle.pressed, "and the switch shows it")
	invert_row.toggle.flip()
	t.equal(Profile.setting("invert_y"), false, "a tap on the switch itself flips it back")
	# In Persian a row reads from the right: its name is to the right of its control.
	t.check(invert_row.get_child(0).get_global_rect().position.x > invert_row.toggle.get_global_rect().position.x, "in Persian the name stands to the right of the switch")
	Profile.set_setting("language", "en")
	await t.frames(2)
	for control: Control in _visible_controls(menus.holder):
		if control is MenuWidgets.Row and (control as MenuWidgets.Row).toggle != null:
			t.check(control.get_child(0).get_global_rect().position.x < (control as MenuWidgets.Row).toggle.get_global_rect().position.x,
				"in English it stands to the left")
			break
	Profile.set_setting("language", "fa")
	await t.frames(2)

	# A slider applies its value while the thumb moves and writes it to storage once, when the thumb lifts.
	var path: String = "user://test_screens_profile.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var real_path: String = Profile.save_path
	Profile.save_path = path
	Profile.persist = true
	Profile.set_setting("music_volume", 0.35, false)
	t.near(float(Profile.setting("music_volume")), 0.35, 0.0001, "a value set while dragging takes effect at once")
	t.near(AudioServer.get_bus_volume_db(Sound.music_bus), linear_to_db(0.35), 0.01, "and is heard at once")
	t.check(not FileAccess.file_exists(path), "but nothing is written while the thumb is down")
	Profile.save()
	t.check(FileAccess.file_exists(path), "it is written when the thumb lifts")
	var stored: Dictionary = SaveManager.load_dict(path)
	t.near(float(stored.settings.music_volume), 0.35, 0.0001, "with the value the thumb left it at")
	Profile.persist = false
	Profile.save_path = real_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Profile.reset()

	# The result screen marks a record, and only a record.
	menus.show_result(true, stats, true)
	await t.frames(2)
	t.check(menus.result_record and _has_text(menus, Loc.t("new_record")), "a match that went further than any before is marked as a record")
	t.check(_has_text(menus, Loc.t("victory_title")) and _has_text(menus, Loc.number(325)), "a victory is announced with its kills")
	menus.show_result(false, stats)
	await t.frames(2)
	t.check(not menus.result_record and not _has_text(menus, Loc.t("new_record")), "an ordinary result is not")
	t.check(_has_text(menus, Loc.t("defeat_title")), "a defeat is announced as one")

	# A cut-out that appears while a menu is open (the phone turned over): the menu is built again around it.
	root.size = Vector2i(1800, 810)
	menus.show_main()
	await t.frames(2)
	var view_wide: Vector2 = menus.get_viewport().get_visible_rect().size
	t.check(menus._is_laid_out(), "the title is laid out for the 20:9 canvas")
	menus.inset_override = Vector2(0.0, 150.0)
	t.check(not menus._is_laid_out(), "a cut-out that was not there when the screen was built is noticed")
	menus._process(1.1)
	await t.frames(2)
	t.check(menus._is_laid_out() and menus.screen == "main", "within a second the screen is built again")
	t.near(menus.built_margins.y, 170.0, 0.001, "20 units clear of the cut-out")
	t.check(_strays(menus, Rect2(0.0, 0.0, view_wide.x - 150.0, view_wide.y)).is_empty(), "and nothing of the Persian title, which stands on the right, is under it")
	t.check(menus.holder.modulate.a >= 0.99, "without fading in a second time")
	Profile.set_setting("language", "en")
	menus.inset_override = Vector2(150.0, 0.0)
	menus._process(1.1)
	await t.frames(2)
	t.check(_strays(menus, Rect2(150.0, 0.0, view_wide.x - 150.0, view_wide.y)).is_empty(), "nor of the English title, which stands on the left")
	menus.inset_override = Vector2(-1.0, -1.0)
	# Turning a folding phone or splitting the screen changes the canvas itself.
	root.size = Vector2i(1440, 1080)
	await t.frames(3)
	t.check(menus._is_laid_out() and menus.built_view.is_equal_approx(Vector2(1440.0, 1080.0)), "a change of canvas rebuilds the open screen too")

	Profile.reset()
	game.to_menu()
	await t.frames(2)
	root.size = old_size
	await t.frames(2)
	game.queue_free()
	await t.frames(2)
