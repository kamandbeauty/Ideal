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
		screen.queue_free()
		await process_frame
	view.queue_free()
	await process_frame

	for file_name in ["shazdeh-save.json", "shazdeh-save.json.bak", "shazdeh-save.json.tmp"]:
		var cleanup := directory.path_join(file_name)
		if FileAccess.file_exists(cleanup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

	print("test_ui: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
