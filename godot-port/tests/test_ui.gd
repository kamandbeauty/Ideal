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
var _failed_labels: Array[String] = []
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
					# Geometry in the message: "a label escaped" is not a bug report, and the numbers say
					# immediately whether it is the rect, the font or the plate that is wrong.
					out.append("%s in %s [label %s parent %s min %s]" % [label.name, parent.name,
						str(label.get_global_rect().size), str(parent.get_global_rect().size),
						str(label.get_minimum_size())])
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
	# Collected, not printed one annotation at a time: GitHub keeps only ten annotations per step, so a
	# suite with eleven failures used to hide the eleventh — which is how a broken plate and a broken
	# resume both fit under the cap and told us nothing.
	_failed_labels.append(label)
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
	# The set by name, not by count: a count drifts every time the chrome grows, and asserting it only
	# ever taught the suite to be edited. What matters is that no plate a screen asks for is missing.
	var required_plates := ["ui_panel", "ui_panel_sm", "ui_panel_raised", "ui_panel_raised_sm",
		"ui_button", "ui_button_sm", "ui_button_gold", "ui_button_gold_sm", "ui_button_accent",
		"ui_button_accent_sm", "ui_button_danger", "ui_button_danger_sm", "ui_button_royal",
		"ui_button_royal_sm", "ui_button_green", "ui_button_green_sm", "ui_header_tab", "ui_pill", "ui_chip", "ui_slot", "ui_row", "ui_rail", "ui_orb",
		"ui_board_tray", "ui_tile_frame", "ui_booster_disc", "ui_piece_shadow", "ui_card_frame",
		"ui_card_tall", "ui_switch_off", "ui_switch_on", "ui_knob", "ui_veil", "ui_rule",
		"ui_scrollbar", "ui_scrollgrabber", "ui_scrim_top", "ui_scrim_bottom", "ui_shadow"]
	var missing_plates: Array[String] = []
	for plate_name in required_plates:
		if not ui_files.has("res://assets/ui/%s.png" % plate_name):
			missing_plates.append(plate_name)
	failures += _check(missing_plates.is_empty(),
		"every picture-chrome plate a screen asks for ships (%s)" % ", ".join(missing_plates))
	# The backdrops are their own pictures at their own size. A square Unity plate scaled to cover a
	# landscape window is a crop, not a backdrop, and the first device screenshot showed exactly that.
	var backdrop_files := _list_pngs("res://assets/backdrops")
	failures += _check(backdrop_files.size() == 5,
		"all 5 painted backdrops are present (%d found)" % backdrop_files.size())
	var narrow: Array[String] = []
	for path in backdrop_files:
		var backdrop := load(path) as Texture2D
		if backdrop == null or backdrop.get_width() < 1440 or backdrop.get_height() < 800:
			narrow.append(path)
	failures += _check(narrow.is_empty(),
		"every backdrop is painted at landscape size, not upscaled from a square (%s)" % ", ".join(narrow))

	# The identity of the app is a picture too: the launcher icon, the two adaptive layers Android
	# composites, and the splash. A flat `icon_432.png` stood in for all of them until now, which is
	# why the icon on the phone was a placeholder and not the logo.
	var brand_sizes := {
		"icon_512.png": Vector2i(512, 512), "icon_192.png": Vector2i(192, 192),
		"icon_128.png": Vector2i(128, 128), "icon_foreground_432.png": Vector2i(432, 432),
		"icon_background_432.png": Vector2i(432, 432), "title_plate.png": Vector2i(1024, 232),
	}
	var missing_brand: Array[String] = []
	for name in brand_sizes:
		var path: String = "res://assets/branding/" + str(name)
		var picture := load(path) as Texture2D
		var wanted: Vector2i = brand_sizes[name]
		if picture == null or picture.get_width() != wanted.x or picture.get_height() != wanted.y:
			missing_brand.append(name)
	failures += _check(missing_brand.is_empty(),
		"the icon, its two adaptive layers and the logotype ship at their exact sizes (%s)" % ", ".join(missing_brand))
	var foreground := load("res://assets/branding/icon_foreground_432.png") as Texture2D
	if foreground != null:
		var image := foreground.get_image()
		failures += _check(image.get_pixel(0, 0).a < 0.1 and image.get_pixel(216, 216).a > 0.9,
			"the adaptive foreground is transparent at the corner and opaque at the centre, so the mask keeps the crest")

	# The stones are re-cut pictures in their own folder, on top of the Unity ones that still ship, so
	# counting `assets/art` alone would not notice if they went missing.
	var gem_files := _list_pngs("res://assets/gems")
	failures += _check(gem_files.size() == 8,
		"all 8 re-cut fruits are present (%d found)" % gem_files.size())
	var weak_gems: Array[String] = []
	for path in gem_files:
		var gem := load(path) as Texture2D
		if gem == null or gem.get_width() < 128:
			weak_gems.append(path)
	failures += _check(weak_gems.is_empty(),
		"every gem is at least 128 px so a phone never upscales it (%s)" % ", ".join(weak_gems))
	for kind in [GameTypes.PieceKind.FIROUZEH, GameTypes.PieceKind.LAJVARD, GameTypes.PieceKind.AQIQ,
			GameTypes.PieceKind.ZOMORROD, GameTypes.PieceKind.MORVARID, GameTypes.PieceKind.ANANAS,
			GameTypes.PieceKind.PORTEQAL, GameTypes.PieceKind.MOZ]:
		failures += _check(AssetCatalog.piece_path(kind).begins_with(AssetCatalog.GEM_DIR),
			"the board draws the re-cut gem for piece %d" % kind)
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
			GameTypes.PieceKind.ZOMORROD, GameTypes.PieceKind.MORVARID, GameTypes.PieceKind.ANANAS,
			GameTypes.PieceKind.PORTEQAL, GameTypes.PieceKind.MOZ]:
		if AssetCatalog.piece_texture(kind) == null:
			unresolved.append("piece %d" % kind)
	for kind in [GameTypes.ObstacleKind.CRATE, GameTypes.ObstacleKind.FROST, GameTypes.ObstacleKind.IVY,
			GameTypes.ObstacleKind.VIAL, GameTypes.ObstacleKind.SAMOVAR, GameTypes.ObstacleKind.FLOWER_POT,
			GameTypes.ObstacleKind.CHAIN, GameTypes.ObstacleKind.SEAL]:
		if AssetCatalog.obstacle_texture(kind) == null:
			unresolved.append("obstacle %d" % kind)
	for kind in [GameTypes.PowerUpKind.ROCKET_VERTICAL, GameTypes.PowerUpKind.ROCKET_HORIZONTAL,
			GameTypes.PowerUpKind.FAN, GameTypes.PowerUpKind.KITE,
			GameTypes.PowerUpKind.ELECTRO_BALL, GameTypes.PowerUpKind.SUPER_ELECTRO_BALL]:
		if AssetCatalog.power_up_texture(kind) == null:
			unresolved.append("power-up %d" % kind)
	failures += _check(unresolved.is_empty(),
		"every piece, obstacle and power-up has a picture (%s)" % ", ".join(unresolved))
	print("UI STAGE 2b: the fan's gust crosses the board without spinning")
	# The fan's gust: the player asked for a wind that crosses the grid, not a top that spins on it. So the
	# effect must never rotate, must keep to one straight line, and must lie flat — its height a fraction of
	# its width — because a full-height tornado reads as standing on the board instead of blowing over it.
	var gust_host := Control.new()
	tree_root.add_child(gust_host)
	Fx.whirlwind(gust_host, Vector2(100.0, 200.0), Vector2(180.0, 0.0), 96.0)
	await process_frame
	var gust := gust_host.get_node_or_null("whirlwind") as TextureRect
	failures += _check(gust != null, "firing the fan puts its gust on the board")
	if gust != null:
		var gust_start: Vector2 = gust.position
		await create_timer(0.22).timeout
		failures += _check(is_zero_approx(gust.rotation), "the gust never spins (%.4f rad)" % gust.rotation)
		failures += _check(gust.position.x > gust_start.x + 8.0,
			"the gust travels across the grid (%.1f dp)" % (gust.position.x - gust_start.x))
		failures += _check(absf(gust.position.y - gust_start.y) < 1.0,
			"the gust travels in a straight line (%.2f dp off its line)" % (gust.position.y - gust_start.y))
		failures += _check(gust.scale.y / maxf(0.001, gust.scale.x) < 0.55,
			"the gust lies flat on the grid (height is %.2f of its width)"
			% (gust.scale.y / maxf(0.001, gust.scale.x)))
		await create_timer(0.6).timeout
		failures += _check(gust_host.get_node_or_null("whirlwind") == null,
			"the gust clears itself off the board when it is done")
	gust_host.queue_free()
	await process_frame
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

	# A phone delivers a touch and Godot emulates a mouse from it, so the view must answer the real
	# event and drop the copy. A tap that fires twice selects and immediately deselects, which is what
	# "the tiles do not respond" looked like on the device.
	var taps: Array = []
	var swaps: Array = []
	view.cell_tapped.connect(func(pos: Vector2i) -> void: taps.append(pos))
	view.swipe_requested.connect(func(from: Vector2i, to: Vector2i) -> void: swaps.append([from, to]))
	var first := Vector2i(0, 0)
	var neighbour := Vector2i(1, 0)
	_tap(view, view.cell_center(first), 0)
	failures += _check(taps.size() == 1 and taps[0] == first,
		"one tap is exactly one cell, not one per input event (%d)" % taps.size())
	_tap(view, view.cell_center(first), InputEvent.DEVICE_ID_EMULATION)
	failures += _check(taps.size() == 1, "the emulated copy of a tap is ignored (%d)" % taps.size())
	# Two taps on adjacent cells are two taps, not one gesture: the pairing (tap, then tap the neighbour)
	# is the screen's selection state, and a drag is the view's swipe. Both paths have to stay
	# distinguishable or the screen would swap on the first tap of a pair.
	_tap(view, view.cell_center(neighbour), 0)
	failures += _check(taps.size() == 2 and taps[1] == neighbour and swaps.is_empty(),
		"two separate taps stay two taps (%d taps, %d swipes)" % [taps.size(), swaps.size()])
	_drag(view, view.cell_center(first), view.cell_center(neighbour), 0)
	failures += _check(swaps.size() == 1 and swaps[0] == [first, neighbour],
		"a drag onto the neighbour asks for exactly one swap (%d)" % swaps.size())
	_drag(view, view.cell_center(first), view.cell_center(neighbour), InputEvent.DEVICE_ID_EMULATION)
	failures += _check(swaps.size() == 1, "the emulated copy of a drag asks for nothing (%d)" % swaps.size())

	# Precision. A thumb rolls a few dp when it taps, and the old rule — "you lifted over the next
	# cell, so it is a swipe" — swapped two gems for that. A gesture under the threshold is a tap on
	# the cell that was pressed, whatever cell the finger ended over.
	taps.clear()
	swaps.clear()
	# The press starts 4 dp from the boundary, so a 10 dp roll of the thumb ends up over the neighbour
	# while still being a tap: this is the exact gesture that used to swap two gems.
	var edge := view.cell_center(first) + Vector2(view.cell_size * 0.5 - 4.0, 0.0)
	_drag(view, edge, edge + Vector2(10.0, 0.0), 0)
	failures += _check(taps == [first] and swaps.is_empty(),
		"a tap whose thumb rolls into the next cell is still a tap (%d taps, %d swipes)"
		% [taps.size(), swaps.size()])

	# A diagonal drag is a drag along the axis the player leaned towards, not a refusal.
	taps.clear()
	swaps.clear()
	var diagonal := view.cell_center(first) + Vector2(view.cell_size * 0.9, view.cell_size * 0.6)
	_drag(view, view.cell_center(first), diagonal, 0)
	failures += _check(swaps.size() == 1 and swaps[0] == [first, neighbour],
		"a diagonal drag swipes along its dominant axis (%s)" % str(swaps))

	# And a drag that would leave the board does nothing at all.
	taps.clear()
	swaps.clear()
	_drag(view, view.cell_center(first), view.cell_center(first) + Vector2(-view.cell_size, 0.0), 0)
	_drag(view, view.cell_center(first), view.cell_center(first) + Vector2(0.0, -view.cell_size), 0)
	failures += _check(taps.is_empty() and swaps.is_empty(),
		"a swipe off the edge of the board asks for nothing (%d taps, %d swipes)"
		% [taps.size(), swaps.size()])

	# The animations are tweens, so the view is only correct again once they finish. A tween that is
	# killed halfway, or one that forgets to put a node back, leaves a stone a few dp off its cell — and
	# that stone is still there on the next move, because nothing redraws the board between moves.
	print("UI STAGE 4b: the animations end with the board exact")
	await view.animate_swap(Vector2i(0, 0), Vector2i(1, 0))
	var swapped_a := view.get_node_or_null("cell_0_0") as Control
	var swapped_b := view.get_node_or_null("cell_1_0") as Control
	failures += _check(not view.is_busy(), "the swap hands the board back")
	failures += _check(swapped_a != null and swapped_b != null
		and swapped_a.position.is_equal_approx(view.position_for(Vector2i(0, 0)))
		and swapped_b.position.is_equal_approx(view.position_for(Vector2i(1, 0)))
		and swapped_a.scale.is_equal_approx(Vector2.ONE)
		and swapped_b.scale.is_equal_approx(Vector2.ONE),
		"the swap leaves both stones on their cells at full size (%s %s)"
		% [str(swapped_a.position if swapped_a != null else Vector2.ZERO),
			str(swapped_a.scale if swapped_a != null else Vector2.ZERO)])
	# A refused move shakes the pair along the axis the player pushed: a stone left warm-tinted or a
	# few dp off would show on the next screenshot and never be corrected by anything.
	await view.animate_reject(Vector2i(0, 0), Vector2i(0, 1))
	var rejected := view.get_node_or_null("cell_0_0") as Control
	failures += _check(rejected != null and not view.is_busy()
		and rejected.position.is_equal_approx(view.position_for(Vector2i(0, 0)))
		and rejected.modulate.is_equal_approx(Color(1, 1, 1, 1)),
		"a refused move puts the pair back, tint off, and hands the board back")
	# Every tile still answers to its own name, which the screen looks up by name when it is placed.
	failures += _check(view.get_child_count() == 81 and view.get_node_or_null("cell_8_8") != null,
		"the rebuilt board keeps one named tile per cell (%d children)" % view.get_child_count())

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
			# The layout the player asked for: the board centred, a capsule rail down each side.
			# Goals on the left, tools on the right — and the board big enough to hit.
			var goals_rail := screen.get_node_or_null("rail_goals") as Panel
			var tools_rail := screen.get_node_or_null("rail_tools") as Panel
			var board_view := screen.get_node_or_null("board") as BoardView
			var tray := screen.get_node_or_null("board_tray") as Panel
			var drawn: Array[String] = []
			# Over the dictionary's keys, not over the dictionary: iterating a Dictionary yields its keys,
			# and casting a String to Control is a hard error at run time.
			var plate_checks := {"rail_goals": goals_rail, "rail_tools": tools_rail, "board_tray": tray}
			for key in plate_checks:
				var node := plate_checks[key] as Control
				if node == null or not node.visible or not (node.get("theme_override_styles/panel") is StyleBoxTexture):
					drawn.append(str(key))
			failures += _check(drawn.is_empty(),
				"level %d builds both rails and the board out of picture plates (%s)"
				% [number, ", ".join(drawn)])
			# Centred is a measurement, not an opinion: the board's midpoint is the canvas midpoint
			# and the tray plate encloses the grid on every side.
			if board_view != null and tray != null:
				var board_rect := board_view.get_global_rect()
				var tray_rect := tray.get_global_rect()
				# Relative to the screen, not to the window: the stage is centred in whatever window the
				# test happens to run in, and that offset is not what "centred" means here.
				var origin := (screen as Control).get_global_rect().position
				var centre := board_rect.get_center() - origin
				failures += _check(absf(centre.x - 369.0) <= 2.0 and absf(centre.y - 207.5) <= 2.0,
					"level %d centres the board (%s)" % [number, str(centre)])
				failures += _check(tray_rect.encloses(board_rect),
					"level %d lays the grid inside the carpet" % number)
				failures += _check(board_view.cell_size >= 40.0,
					"level %d gives a stone a %.1f dp target" % [number, board_view.cell_size])
				# The rails must not eat the board: the grid is the biggest thing on the screen.
				failures += _check(board_rect.size.x >= 360.0,
					"level %d keeps the playfield at %.0f dp" % [number, board_rect.size.x])
			# Every control on a rail has to stay on its rail: a label that escapes its capsule is the
			# bug class this layout invites, and it is invisible in a green test run.
			var escaped: Array[String] = []
			for rail in [goals_rail, tools_rail]:
				var rail_node := rail as Control
				if rail_node == null:
					continue
				var rail_rect: Rect2 = rail_node.get_global_rect().grow(1.0)
				for child in rail_node.get_children():
					if child is Control and child.visible and not rail_rect.encloses(child.get_global_rect()):
						escaped.append("%s in %s" % [child.name, rail_node.name])
			failures += _check(escaped.is_empty(),
				"level %d keeps every rail control on its rail (%s)" % [number, ", ".join(escaped)])
			# Ink, not light text: the rails are painted cream, and the game's text colour would be
			# invisible on them.
			var moves_label := screen.get("_moves_label") as Label
			failures += _check(moves_label != null
				and moves_label.get_theme_color("font_color") == UiTokens.INK,
				"level %d writes the counter in ink on the cream rail" % number)
			# The five tools are round painted orbs down the right rail, each thumb-sized and stacked
			# without overlapping the next.
			var previous_end := -1.0
			var tidy := true
			for index in range(BoosterBag.SLOTS):
				# The tools live on their rail, not on the screen: look them up by name rather than by path.
				var orb := screen.find_child("booster_%d" % index, true, false) as Control
				if orb == null:
					tidy = false
					break
				tidy = tidy and orb.visible and orb.get_global_rect().size.x >= 48.0
				tidy = tidy and orb.get_global_rect().position.y >= previous_end
				previous_end = orb.get_global_rect().end.y
				if tools_rail != null:
					tidy = tidy and tools_rail.get_global_rect().grow(1.0).encloses(orb.get_global_rect())
			failures += _check(tidy,
				"level %d stacks five thumb-sized tools down the right rail" % number)
			var coin_label := screen.get("_coin_label") as Label
			failures += _check(coin_label != null and coin_label.text == PersianText.number(session.wallet.coins),
				"level %d shows the coin balance on the board" % number)
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
				and pause_plate.get("theme_override_styles/panel") is StyleBoxTexture,
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
	# A picture that the engine painted at run time is still a drawn shape. The last one was the edge
	# scrim, a GradientTexture2D built in `_make_scrim`; both scrims and the window art must be files.
	var runtime_pictures: Array[String] = []
	for key in ["_scrim_top", "_scrim_bottom", "_bg"]:
		var painted := app.get(key) as TextureRect
		if painted == null or painted.texture == null or painted.texture is GradientTexture2D:
			runtime_pictures.append(key)
	failures += _check(runtime_pictures.is_empty(),
		"the scrims and the window art are shipped pictures, not gradients made at run time (%s)"
		% ", ".join(runtime_pictures))
	# The strict rule, applied to the whole app rather than to a list of widgets the test knows about:
	# not one panel, not one button state, not one rectangle in any of the five screens may be a shape
	# the engine rounded at runtime. Everything the player sees is a shipped picture. Focus styles are
	# exempt because every button here is focus_mode NONE, so a focus plate can never be painted.
	var drawn_shapes: Array[String] = []
	_drawn_shapes_in(app, drawn_shapes)
	failures += _check(drawn_shapes.is_empty(),
		"every panel and button in the app is a shipped plate (%d drawn: %s)"
		% [drawn_shapes.size(), ", ".join(drawn_shapes)])
	app.queue_free()
	await process_frame

	print("test_ui: %d failure(s)" % failures)
	if not _failed_labels.is_empty():
		var summary := "%0A".join(_failed_labels)
		print("::error title=test_ui (%d failures)::%s" % [failures, summary.left(6000)])
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

## Presses and releases the view the way the engine would, at a point in view-local coordinates.
## A press on `from` released on `to`: one gesture, which is what a swipe is.
func _drag(view: BoardView, from: Vector2, to: Vector2, device: int) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.device = device
	view._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.device = device
	view._gui_input(release)



## Collects every surface in a tree that is not a shipped picture: a Panel or Button state whose style
## is a StyleBoxFlat, or a ColorRect, which is a rectangle by definition.
func _drawn_shapes_in(node: Node, out: Array[String]) -> void:
	if node is ColorRect:
		out.append(str(node.get_path()))
	if node is Panel:
		var style: StyleBox = (node as Panel).get("theme_override_styles/panel") as StyleBox
		if style != null and not (style is StyleBoxTexture):
			out.append(str(node.get_path()))
	if node is Button:
		var button := node as Button
		for state in ["normal", "hover", "pressed", "disabled"]:
			var state_style: StyleBox = button.get("theme_override_styles/" + state) as StyleBox
			if state_style != null and not (state_style is StyleBoxTexture):
				out.append(str(button.get_path()) + ":" + state)
	for child in node.get_children():
		_drawn_shapes_in(child, out)

func _tap(view: BoardView, point: Vector2, device: int) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	press.device = device
	view._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	release.device = device
	view._gui_input(release)
