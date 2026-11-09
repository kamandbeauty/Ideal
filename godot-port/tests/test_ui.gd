extends SceneTree
## Presentation-layer tests: Persian numerals, the screen kit, the session contract, and the parts of
## the board view that decide what the player's finger means.
##
## These run headlessly, without a renderer, which is the point: the port must be able to prove its
## text and its navigation in CI on a machine that has no display.

const Clock = preload("res://scripts/core/manual_clock.gd")
const Codec = preload("res://scripts/core/save_codec.gd")
const Store = preload("res://scripts/core/save_store.gd")

var failures := 0
var tree_root: Window

func _initialize() -> void:
	tree_root = get_root()
	create_timer(30.0).timeout.connect(_on_timeout)
	call_deferred("_run")

func _on_timeout() -> void:
	push_error("test_ui timed out")
	quit(1)

## The five views AppRoot owns, named in the order they are layered, filtered to the visible ones.
func _visible_views(app: Node) -> Array:
	var out := []
	for key in ["home", "board", "districts", "shop", "settings"]:
		var view = app.get(key)
		if view != null and view.visible:
			out.append(key)
	return out

## Labels whose rect escapes the panel they were placed in. This is the bug class that made the HUD
## numbers float outside their pills: a Label reports its text as its minimum size, so a fixed rect is
## only honoured when it clips.
func _escaped_labels(node: Node, slack: float) -> Array:
	var out := []
	for child in node.get_children():
		if child is Label and child.visible and child.get_parent() is Control:
			var label := child as Label
			var parent := label.get_parent() as Control
			if parent is Panel or parent is Button:
				if not parent.get_global_rect().grow(slack).encloses(label.get_global_rect()):
					out.append("%s in %s" % [label.name, parent.name])
		out.append_array(_escaped_labels(child, slack))
	return out

## Visible controls that reach past the design space, ignoring the full-bleed layers that are meant to.
func _outside_canvas(app: Node, slack: float) -> Array:
	# The stage is centred inside whatever window we have, so "inside the design space" is the stage's
	# own rect — not a rect at the origin.
	var stage := app.get("_stage") as Control
	var canvas := (stage.get_global_rect() if stage != null else Rect2(
		Vector2.ZERO, Vector2(UiTokens.CANVAS_WIDTH, UiTokens.CANVAS_HEIGHT))).grow(slack)
	var out := []
	for view in ["home", "board", "districts", "shop", "settings"]:
		var screen = app.get(view)
		if screen == null or not screen.visible:
			continue
		for child in screen.get_children():
			if child is Control and child.visible and not (child is ColorRect) and not (child is TextureRect):
				var control := child as Control
				if not canvas.encloses(control.get_global_rect()):
					out.append("%s %s" % [control.name, str(control.get_global_rect())])
	return out

func _check(condition: bool, label: String) -> int:
	if condition:
		return 0
	push_error("FAILED: " + label)
	print("::error title=test_ui::" + label)
	return 1

func _run() -> void:
	print("UI STAGE 1: Persian numerals and formatting")
	failures += _check(PersianText.number(0) == "۰", "zero")
	failures += _check(PersianText.number(7) == "۷", "single digit")
	failures += _check(PersianText.number(1234) == "۱٬۲۳۴", "four digits are grouped with the Persian thousands separator")
	failures += _check(PersianText.number(1234567) == "۱٬۲۳۴٬۵۶۷", "seven digits are grouped twice")
	failures += _check(PersianText.number(-42) == "-۴۲", "negative numbers keep the sign")
	failures += _check(PersianText.time(0) == "۰:۰۰", "zero seconds")
	failures += _check(PersianText.time(95) == "۱:۳۵", "one minute thirty five")
	failures += _check(PersianText.time(3725) == "۱:۰۲:۰۵", "hours are shown when there are any")
	failures += _check(PersianText.fraction(3, 5) == "۳ از ۵", "the counter shape used by every HUD chip")
	failures += _check(PersianText.localize("مرحله 3") == "مرحله ۳", "authored ASCII digits become Persian")
	failures += _check(PersianText.to_ascii_digits("۱۲۳") == "123", "round trip back to ASCII for tooling")
	failures += _check(PersianText.contains_persian("کاخ"), "detects Persian")

	print("UI STAGE 2: the screen kit")
	failures += _check(UiKit.medium_font() != null, "Vazir Medium loads from Resources")
	failures += _check(UiKit.bold_font() != null, "Vazir Bold loads from Resources")
	failures += _check(UiKit.texture("piece_firouzeh") != null, "art lookup resolves an id to a texture")
	failures += _check(UiKit.texture("no_such_art") == null, "a missing art id degrades to null instead of throwing")
	failures += _check(UiKit.art_box("panel_frame", UiTokens.BORDER_CARD) != null, "nine-slice art builds a stylebox")
	failures += _check(UiKit.art_box("no_such_art",
		UiTokens.BORDER_CARD) == null, "missing nine-slice art falls back to the rounded panel")

	# The pictures themselves, not one sample of them. A build that ships a null texture still boots, still
	# passes every layout assertion and looks like a flat prototype on the phone — so the count is
	# asserted here and every file has to decode to a real texture with a real size.
	print("UI STAGE 2b: every shipped picture loads")
	var art_files := _list_pngs("res://assets/art")
	var ui_files := _list_pngs("res://assets/ui")
	failures += _check(art_files.size() == 85,
		"all 85 game plates are present (%d found)" % art_files.size())
	failures += _check(ui_files.size() == 24,
		"all 24 picture-chrome plates are present (%d found)" % ui_files.size())
	var undecodable: Array[String] = []
	for path in art_files + ui_files:
		var texture := load(path) as Texture2D
		if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
			undecodable.append(path)
	failures += _check(undecodable.is_empty(),
		"every picture decodes to a texture (%d broken: %s)" % [undecodable.size(), ", ".join(undecodable)])
	# And every id the game can ask for has a file behind it, so no piece, obstacle, power-up or booster
	# can silently fall back to a drawn shape.
	var unresolved: Array[String] = []
	for kind in [GameTypes.PieceKind.FIROUZEH, GameTypes.PieceKind.LAJVARD, GameTypes.PieceKind.AQIQ,
			GameTypes.PieceKind.ZOMORROD, GameTypes.PieceKind.MORVARID]:
		if AssetCatalog.piece_texture(kind) == null:
			unresolved.append("piece %d" % kind)
	for kind in [GameTypes.ObstacleKind.CRATE, GameTypes.ObstacleKind.FROST, GameTypes.ObstacleKind.IVY,
			GameTypes.ObstacleKind.VIAL, GameTypes.ObstacleKind.SAMOVAR, GameTypes.ObstacleKind.FLOWER_POT,
			GameTypes.ObstacleKind.CHAIN, GameTypes.ObstacleKind.SEAL]:
		if AssetCatalog.obstacle_texture(kind) == null:
			unresolved.append("obstacle %d" % kind)
	for kind in [GameTypes.PowerUpKind.ROCKET_VERTICAL, GameTypes.PowerUpKind.ROCKET_HORIZONTAL,
			GameTypes.PowerUpKind.SPINNER, GameTypes.PowerUpKind.DYNAMITE,
			GameTypes.PowerUpKind.ELECTRO_BALL, GameTypes.PowerUpKind.SUPER_ELECTRO_BALL]:
		if AssetCatalog.power_up_texture(kind) == null:
			unresolved.append("power-up %d" % kind)
	failures += _check(unresolved.is_empty(),
		"every piece, obstacle and power-up has a picture (%s)" % ", ".join(unresolved))
	var host := Control.new()
	tree_root.add_child(host)
	var panel := UiKit.panel(host, "panel", 10.0, 20.0, 100.0, 50.0, UiTokens.SURFACE, UiTokens.RADIUS_MD)
	failures += _check(panel.position.x == 10.0 and panel.position.y == 20.0 and panel.size.x == 100.0,
		"panels are placed by their top-left corner in design units")
	var label := UiKit.label(host, "label", "مرحله 3", UiTokens.TYPE_BASE, UiTokens.TEXT)
	failures += _check(label.text == "مرحله ۳", "labels localise their numerals")
	failures += _check(label.layout_direction == Control.LAYOUT_DIRECTION_RTL, "labels are laid out right to left")
	var pressed := {"count": 0}
	var button := UiKit.button(host, "button", "بازی", 0.0, 0.0, 120.0, 48.0, UiTokens.GOLD,
		UiTokens.ON_GOLD, func() -> void: pressed.count += 1)
	button.pressed.emit()
	failures += _check(pressed.count == 1, "a button calls back once per press")
	host.queue_free()
	await process_frame

	print("UI STAGE 3: the session contract")
	var directory := "user://godot-ui-tests"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var clock = Clock.new(1700000000)
	var save = Codec.new_save(clock)
	save.level_number = 1
	save.coins = 50
	var store = Store.new(clock, directory)
	store.save(save)
	var errors: Array[String] = []
	var session = GameSession.load_session(clock, store, "ch01", errors)
	failures += _check(errors.is_empty(), "a fresh save boots with no content errors")
	failures += _check(session.districts.size() == 3, "three districts are loaded from the chapter metadata")
	failures += _check(session.current_level == 1, "a new player starts on level one")
	failures += _check(session.blocked_reason(1) == "", "level one may start")
	failures += _check(not session.blocked_reason(2).is_empty(), "a locked level reports why")

	var seed_a := GameSession.stable_seed("player-1", 3, 0)
	var seed_b := GameSession.stable_seed("player-1", 3, 0)
	var seed_c := GameSession.stable_seed("player-1", 4, 0)
	failures += _check(seed_a == seed_b, "the seed is stable for the same player and level")
	failures += _check(seed_a != seed_c, "a different level gives a different board seed")
	failures += _check(seed_a != GameSession.stable_seed("player-2", 3, 0), "a different player gets a different board")

	var attempt := session.start_attempt(1)
	failures += _check(attempt.get("run", null) != null, "level one builds a run")
	var run = attempt["run"]
	failures += _check(run.moves_left == run.level.move_limit, "a run starts with the level's move limit")

	print("UI STAGE 4: the board view's meaning of a touch")
	var view := BoardView.new()
	tree_root.add_child(view)
	view.setup(run, Vector2(383.0, 392.0))
	failures += _check(view.get_child_count() == 81, "the view draws one widget per cell")
	var expected := view.position_for(Vector2i(0, 0)) + Vector2(4.0, 4.0)
	failures += _check(view.cell_at(expected) == Vector2i(0, 0), "a touch inside the first cell maps to it")
	var outside := view.position_for(Vector2i(0, 0)) + Vector2(-20.0, 4.0)
	failures += _check(view.cell_at(outside) == Vector2i(-1, -1), "a touch outside the grid maps to nothing")
	var last := view.position_for(Vector2i(8, 8)) + Vector2(4.0, 4.0)
	failures += _check(view.cell_at(last) == Vector2i(8, 8), "the far corner maps to the last cell")

	print("UI STAGE 5: every level boots and plays through the screen")
	for number in range(1, GameSession.LEVEL_COUNT + 1):
		session.save.level_number = number
		var screen := BoardScreen.new()
		tree_root.add_child(screen)
		screen.init_screen(session)
		var started: bool = screen.start_level(number)
		failures += _check(started, "level %d starts on the board screen" % number)
		var view_node := screen.get_node("board") as BoardView
		failures += _check(view_node != null and view_node.get_child_count() == screen.run.board.width * screen.run.board.height,
			"level %d draws its own board size" % number)
		# The score is a label bound to the run, so the binding can be checked without playing a move:
		# set the number, refresh, and read what a player would see.
		var score_label := screen.find_child("score", true, false) as Label
		failures += _check(score_label != null, "level %d puts a score on the board" % number)
		if score_label != null:
			screen.run.score = 1234
			screen.refresh()
			failures += _check(score_label.text == PersianText.number(1234),
				"level %d shows the score in Persian numerals" % number)
			var score_card := screen.get_node_or_null("score_card") as Panel
			failures += _check(score_card != null and score_card.get_rect().position.y >= 52.0
				and score_card.get_rect().end.y <= 100.0,
				"level %d keeps the score card under the header" % number)
			# Strict picture rule: every surface on this screen is a shipped plate, not a drawn shape.
			var plate_checks := {"score_card": score_card, "moves": screen.get_node_or_null("moves"),
				"status_card": screen.get_node_or_null("status_card"),
				"board_frame": screen.get_node_or_null("board_frame")}
			var drawn: Array[String] = []
			for key in plate_checks:
				var plate := plate_checks[key] as Panel
				if plate == null or not (plate.get_theme_stylebox("panel") is StyleBoxTexture):
					drawn.append(str(key))
			failures += _check(drawn.is_empty(),
				"level %d draws every card and the board frame with picture plates (%s)" % [number, ", ".join(drawn)])
		# A "+" or a "×" between a Persian word and a number is bidi-neutral, and the run it splits can
		# come out reading backwards. The bubble has to say it with words.
		screen._show_combo(3, 300)
		var combo_toast := screen.get_node_or_null("combo_toast") as Control
		var combo_popup: Label = null
		failures += _check(combo_toast != null and combo_toast.get_theme_stylebox("panel") is StyleBoxTexture,
			"level %d shows the combo on a shipped plate, not a drawn rectangle" % number)
		if combo_toast != null:
			combo_popup = combo_toast.get_node_or_null("combo_popup") as Label
		failures += _check(combo_popup != null
			and combo_popup.text.ends_with(PersianText.number(300) + " امتیاز")
			and combo_popup.text.contains(PersianText.number(3))
			and not combo_popup.text.contains("+") and not combo_popup.text.contains("×"),
			"level %d names the combo bonus in words, not bidi-neutral symbols" % number)
		# The result card is a fixed box with a two line body: prove both lines are written and that the
		# font's own line height leaves them inside it, and that the title sits on the banner frame.
		screen.run.status = GameTypes.LevelStatus.WON
		screen.run.score = 4820
		screen._show_result(true, RewardBundle.none())
		await process_frame
		var result_body := screen.get("_result_body") as Label
		var result_title := screen.get("_result_title") as Label
		var overlay_card := screen.get("_overlay_card") as Panel
		var banner := overlay_card.get_node_or_null("banner") as TextureRect
		failures += _check(result_body != null and result_body.text.split("\n").size() == 2
			and result_body.get_line_height() * result_body.get_line_count() <= result_body.size.y,
			"level %d writes a two line result inside its box" % number)
		failures += _check(result_title != null and banner != null and banner.visible
			and banner.get_rect().encloses(result_title.get_rect()),
			"level %d writes the result title on the banner" % number)

		# Pause: the board is frozen, the card is a picture plate, and resuming works.
		screen.run.status = GameTypes.LevelStatus.PLAYING
		screen._on_pause()
		var pause_layer := screen.get_node_or_null("pause") as Control
		failures += _check(pause_layer != null and pause_layer.visible,
			"level %d pauses on demand" % number)
		if pause_layer != null:
			var pause_plate := pause_layer.get_node_or_null("card") as Panel
			failures += _check(pause_plate != null
				and pause_plate.get_theme_stylebox("panel") is StyleBoxTexture,
				"level %d draws the pause card with a picture plate" % number)
			screen._on_resume()
			failures += _check(not pause_layer.visible, "level %d resumes from the pause card" % number)
		failures += _check(combo_popup == null or not combo_popup.text.is_empty(),
			"level %d writes the combo bonus on the toast" % number)
		screen.queue_free()
		await process_frame
	view.queue_free()
	await process_frame

	for file_name in ["shazdeh-save.json", "shazdeh-save.json.bak", "shazdeh-save.json.tmp"]:
		var cleanup := directory.path_join(file_name)
		if FileAccess.file_exists(cleanup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

	print("UI STAGE 6: sound assets and the director")
	for cue in SoundDirector.cue_names():
		var cue_path: String = SoundDirector.CUE_PATHS[cue]
		failures += _check(load(cue_path) is AudioStream, "cue '%s' loads as an AudioStream" % cue)
	var music := load(SoundDirector.MUSIC_PATH)
	failures += _check(music is AudioStreamWAV and music.get_length() > 20.0,
		"the palace music loop is a real audio stream of at least twenty seconds")

	var director := SoundDirector.new()
	tree_root.add_child(director)
	await process_frame
	failures += _check(SoundDirector.instance == director, "the director registers itself for the static API")
	failures += _check(director.has_cue("match") and director.has_cue("win") and director.has_cue("reject"),
		"the director knows its cues")
	director.apply_settings(session.save)
	director.play_cue("match")
	failures += _check(true, "playing a cue is safe under the headless audio driver")
	director.sfx_enabled = false
	director.play_cue("match")
	failures += _check(true, "a muted cue is not an error")
	director.queue_free()
	await process_frame
	failures += _check(SoundDirector.instance == null, "the director clears the static handle when it leaves")

	print("UI STAGE 7: particles and the tutorial hand")
	var fx_host := Control.new()
	fx_host.name = "fx_host"
	tree_root.add_child(fx_host)
	Fx.spark(fx_host, Vector2(40.0, 40.0), UiTokens.ACCENT, 6)
	Fx.coin_burst(fx_host, Vector2(40.0, 40.0), 6)
	Fx.ring(fx_host, Vector2(40.0, 40.0), 60.0)
	await process_frame
	failures += _check(fx_host.get_child_count() >= 3, "sparks, coins and a ring attach to the host")
	await create_timer(1.2).timeout
	failures += _check(fx_host.get_child_count() == 0, "every effect frees itself")
	fx_host.queue_free()
	await process_frame

	var tutorial_directory := "user://godot-tutorial-tests"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(tutorial_directory))
	var tutorial_clock = Clock.new(1700000000)
	var tutorial_save = Codec.new_save(tutorial_clock)
	tutorial_save.level_number = 1
	var tutorial_store = Store.new(tutorial_clock, tutorial_directory)
	tutorial_store.save(tutorial_save)
	var tutorial_errors: Array[String] = []
	var tutorial_session = GameSession.load_session(tutorial_clock, tutorial_store, "ch01", tutorial_errors)
	var tutorial_screen := BoardScreen.new()
	tree_root.add_child(tutorial_screen)
	tutorial_screen.init_screen(tutorial_session)
	failures += _check(tutorial_screen.start_level(1), "the first level starts")
	var hand := tutorial_screen.get_node_or_null("tutorial_hand") as TextureRect
	failures += _check(hand != null and hand.visible, "a first-time player is shown a hand on a real swap")
	failures += _check(hand != null and hand.texture != null, "the hand uses the shipped tutorial art")
	tutorial_screen.queue_free()
	await process_frame
	for cleanup_name in ["shazdeh-save.json", "shazdeh-save.json.bak", "shazdeh-save.json.tmp"]:
		var cleanup_file := tutorial_directory.path_join(cleanup_name)
		if FileAccess.file_exists(cleanup_file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup_file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tutorial_directory))

	print("UI STAGE 9: haptics obey the save and never crash off-device")
	var haptic_save = Codec.new_save(Clock.new(1700000000))
	haptic_save.haptics_on = true
	Haptics.apply_settings(haptic_save)
	failures += _check(Haptics.enabled, "haptics follow the switch being on")
	Haptics.tick()
	Haptics.thump()
	await process_frame
	failures += _check(true, "a vibration call off-device is a no-op, not an error")
	haptic_save.haptics_on = false
	Haptics.apply_settings(haptic_save)
	failures += _check(not Haptics.enabled, "haptics follow the switch being off")
	haptic_save.haptics_on = true
	Haptics.apply_settings(haptic_save)

	print("UI STAGE 8: the real AppRoot composes one screen at a time")
	var app := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree_root.add_child(app)
	for _i in range(4):
		await process_frame
	failures += _check(_visible_views(app) == ["home"],
		"boot shows the title screen and nothing else, got %s" % str(_visible_views(app)))
	# set_anchors_preset() keeps a control's current rect; a 0x0 screen still *looks* right because its
	# children are placed absolutely, and every anchor-based child inside it silently collapses.
	for key in ["home", "board", "districts", "shop", "settings"]:
		var screen_control = app.get(key) as Control
		failures += _check(screen_control.size == Vector2(UiTokens.CANVAS_WIDTH, UiTokens.CANVAS_HEIGHT),
			"the %s screen fills the design space, got %s" % [key, str(screen_control.size)])
	app._show_settings()
	await process_frame
	failures += _check(_visible_views(app) == ["settings"],
		"settings replaces the title screen, got %s" % str(_visible_views(app)))
	app._show_shop()
	await process_frame
	failures += _check(_visible_views(app) == ["shop"],
		"shop replaces settings, got %s" % str(_visible_views(app)))
	app._show_home()
	await process_frame
	app._play(1)
	for _i in range(4):
		await process_frame
	failures += _check(_visible_views(app) == ["board"],
		"playing replaces the title screen, got %s" % str(_visible_views(app)))
	# A settings switch that renders "off" while the save says "on" is a lie the player acts on.
	app._show_settings()
	await process_frame
	var settings_screen = app.get("settings")
	for entry in settings_screen.get("_switches"):
		var toggle: Button = entry["toggle"]
		var want := bool(app.session.save.get(str(entry["key"])))
		failures += _check(toggle.button_pressed == want,
			"the %s switch shows the saved value" % str(entry["key"]))
	app._show_home()
	await process_frame
	app._play(1)
	for _i in range(3):
		await process_frame
	var escaped := _escaped_labels(app, 1.0)
	failures += _check(escaped.is_empty(),
		"every label sits inside the panel it was placed in: %s" % ", ".join(escaped))
	var spilled := _outside_canvas(app, 2.0)
	failures += _check(spilled.is_empty(),
		"nothing draws outside the %dx%d design space: %s" % [int(UiTokens.CANVAS_WIDTH), int(UiTokens.CANVAS_HEIGHT), ", ".join(spilled)])
	app.queue_free()
	await process_frame

	print("test_ui: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## Every PNG directly inside a directory of the project, sorted, so a count in a test means something.
func _list_pngs(directory_path: String) -> Array[String]:
	var out: Array[String] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return out
	for file_name in directory.get_files():
		if file_name.ends_with(".png"):
			out.append(directory_path.path_join(file_name))
	out.sort()
	return out
