extends Node
## Drives the real AppRoot through every screen and saves a PNG of each, so the port's layout can be
## reviewed without a device. Runs under Xvfb on CI: `godot --path godot-port res://tests/capture.tscn`.
##
## This exists because "it looks fine in the tests" is not evidence. Geometry assertions catch
## overlaps; only a picture catches "the palace art never drew".

const SHOTS := "res://.shots"
const REPORT := "res://.shots/layout.txt"
const SETTLE_FRAMES := 12

var _report_lines: Array[String] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	# Both calls, because DisplayServer alone leaves the window at the shape the project started with
	# and the first shots then come out portrait while the stage underneath is landscape.
	DisplayServer.window_set_size(Vector2i(738, 415))
	get_window().size = Vector2i(738, 415)
	await _frames(2)

	var app: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _frames(20)

	_report(app, "boot")
	await _shot("01-home")
	app._show_settings()
	await _frames(SETTLE_FRAMES)
	_report(app, "settings")
	var settings_screen = app.get("settings")
	for entry in settings_screen.get("_switches"):
		var toggle := entry["toggle"] as Button
		var knob := entry["knob"] as Control
		_log("SWITCH %s pressed=%s saved=%s knob=%s toggle_rect=%s rtl=%s" % [
			str(entry["key"]), str(toggle.button_pressed),
			str(bool(app.session.save.get(str(entry["key"])))),
			str(knob.position) + " " + str(knob.size),
			str(toggle.get_global_rect()), str(toggle.is_layout_rtl())])
	await _shot("02-settings")
	app._show_shop()
	await _frames(SETTLE_FRAMES)
	_report(app, "shop")
	_dump(app.get("shop"), "row_1", 12)
	await _shot("03-shop")
	app._show_districts()
	await _frames(SETTLE_FRAMES)
	_report(app, "districts")
	_dump(app.get("districts"), "district_0", 40)
	await _shot("04-districts")
	app._show_home()
	await _frames(4)
	app._play(1)
	await _frames(30)
	_report(app, "board")
	await _shot("05-board")

	# The special pieces, on the real board. A picture of a rocket on cream says nothing about how it
	# reads at 44 dp next to a pear, so the three of them are dropped into cells and photographed in
	# place — the only shot that answers "does a player recognise this as a rocket mid-game".
	var live_board = app.get("board")
	var model = live_board.run.board
	var marks = [
		[Vector2i(2, 2), GameTypes.PowerUpKind.ROCKET_HORIZONTAL],
		[Vector2i(4, 2), GameTypes.PowerUpKind.FAN],
		[Vector2i(6, 2), GameTypes.PowerUpKind.KITE],
		[Vector2i(4, 3), GameTypes.PowerUpKind.ROCKET_VERTICAL],
	]
	for mark in marks:
		model.at_pos(mark[0]).power_up = mark[1]
	live_board.get("_board").rebuild()
	await _frames(3)
	await _shot("12-power-ups")
	for mark in marks:
		model.at_pos(mark[0]).power_up = GameTypes.PowerUpKind.NONE
	live_board.get("_board").rebuild()
	await _frames(2)

	# The juice and the whirlwind, photographed inside themselves. Both effects are half a second long
	# and a still of either would otherwise catch the board after they have finished, so the clock is
	# slowed and the shot is taken a third of the way in — the only evidence that the burst has drips
	# and the fan has a tornado, rather than the art existing in a folder.
	var fx_view = live_board.get("_board")
	Engine.time_scale = 0.45
	Fx.splash(fx_view, fx_view.cell_center(Vector2i(3, 4)),
		Fx.piece_tint(GameTypes.PieceKind.AQIQ), fx_view.cell_size)
	Fx.splash(fx_view, fx_view.cell_center(Vector2i(5, 4)),
		Fx.piece_tint(GameTypes.PieceKind.LAJVARD), fx_view.cell_size)
	await _frames(11)
	await _shot("13-burst")
	Engine.time_scale = 1.0
	await _frames(20)

	Engine.time_scale = 0.45
	Fx.whirlwind(fx_view, fx_view.cell_center(Vector2i(4, 4)), fx_view.cell_size * 3.0)
	await _frames(12)
	await _shot("14-whirlwind")
	Engine.time_scale = 1.0
	await _frames(30)
	await _burst_strip(live_board)

	# Motion cannot be judged from a still. The swap is played in slow motion and photographed as it
	# runs, and the crops are laid out in a strip: this is the only evidence that the stones travel,
	# lift and land rather than teleporting, and the animation work has to show itself.
	await _swap_strip(app.get("board"))
	await _match_strip(app.get("board"))

	# The combo bubble lives for nine tenths of a second inside a chain, so a camera that waits for one
	# would photograph an empty board. Ask the real screen to show a real bonus, pin the tween to its
	# legible frame, and shoot the element a player would actually see.
	var board_screen = app.get("board")
	board_screen.run.score = 4820
	board_screen.refresh()
	board_screen._show_combo(3, 300)
	await _frames(2)
	# Freeze the entrance: the tween writes modulate every frame, so setting the values alone only holds
	# them until the next tick and the shot catches the plate half faded in.
	await _frames(1)
	for running in get_tree().get_processed_tweens():
		running.kill()
	var combo_toast := board_screen.get_node_or_null("combo_toast") as Control
	if combo_toast != null:
		combo_toast.modulate = Color(1, 1, 1, 1)
		combo_toast.scale = Vector2.ONE
	await _frames(2)
	await _shot("08-combo")
	if combo_toast != null:
		combo_toast.queue_free()

	# The result card, with a score and a record on it: the one screen a player sees at the end of every
	# level, and the only place the best score is ever printed.
	board_screen.run.status = GameTypes.LevelStatus.WON
	board_screen.run.score = 4820
	board_screen._show_result(true, RewardBundle.none())
	await _frames(3)
	await _shot("09-result")
	board_screen.run.status = GameTypes.LevelStatus.PLAYING
	board_screen._overlay.visible = false

	board_screen._on_pause()
	await _frames(3)
	await _shot("10-pause")
	board_screen._on_resume()
	await _frames(2)

	# A 20:9 phone is where the old layout letterboxed the art and cropped the content.
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	get_window().size = Vector2i(2400, 1080)
	await _frames(6)
	await _shot("06-board-phone-landscape")
	app._show_home()
	await _frames(6)
	await _shot("07-home-phone-landscape")

	_make_contact_sheet(["01-home", "02-settings", "03-shop", "04-districts", "05-board",
		"12-power-ups"])
	_save_report()
	print("[capture] wrote the whole set to %s" % SHOTS)
	get_tree().quit()

## Takes the board through one real move in slow motion and writes the flight of the two stones as a
## strip of crops. Engine.time_scale is what makes it possible: at a fifth of real time the 0.18 s swap
## is long enough to sample ten times, and every offset below is a time in the game's own clock, so the
## strip is the same strip whatever the renderer's frame rate on the day is.
func _swap_strip(board_screen) -> void:
	# Every step of this is written to the report, because the report is committed with the pictures: a
	# strip that does not appear has to say why on the next run rather than be guessed at.
	_log("STRIP start :: screen=%s" % str(board_screen))
	if board_screen == null:
		_log("STRIP skipped :: no board screen")
		return
	var move: Array = board_screen._find_hint_move()
	_log("STRIP move :: %s" % str(move))
	if move.size() != 2:
		_log("STRIP skipped :: no legal move on the board")
		return
	board_screen._hide_hand()
	await _frames(2)
	var board = board_screen.get_node_or_null("board")
	_log("STRIP board :: %s" % str(board))
	if board == null:
		_log("STRIP skipped :: the screen has no board view")
		return
	var a: Vector2 = board.position + board.cell_center(move[0])
	var b: Vector2 = board.position + board.cell_center(move[1])
	# Three cells of neighbourhood around the pair and nothing else: the strip is about two stones
	# trading places, and a crop of half the board hides them among seventy others.
	var span := int(maxf(float(board.cell_size) * 3.4, 96.0))
	var centre := (a + b) * 0.5
	var window := Rect2i(Vector2i(int(centre.x) - span / 2, int(centre.y) - span / 2),
		Vector2i(span, span))
	board_screen._hide_hand()
	# The resting board first, so the strip opens on what the player saw before the move.
	var frames: Array = []
	var before: Image = await _grab_rect(window)
	if before != null:
		frames.append(before)
	Engine.time_scale = 0.2
	board_screen._attempt_swap(move[0], move[1])
	var offsets := [0.02, 0.03, 0.04, 0.06, 0.08, 0.11, 0.16, 0.22, 0.30]
	for index in range(offsets.size()):
		await get_tree().create_timer(float(offsets[index])).timeout
		var grabbed: Image = await _grab_rect(window)
		_log("STRIP frame %d :: %s" % [index, "null" if grabbed == null else str(grabbed.get_size())])
		if grabbed != null:
			frames.append(grabbed)
	Engine.time_scale = 1.0
	await _frames(4)
	_save_strip(frames, "11-swap-strip", 5, 3)

## A whole real move, the whole grid in every frame — the evidence for the clearing rule.
##
## The player's report was that matching three burst fruit that had nothing to do with the match. That
## is a rule about which cells a move takes, and a rule is not visible in a still: the strip opens on
## the resting board, plays a real accepted swap in slow motion, and shows the burst and the settle, so
## the three pieces that go and the dozens that stay are both in the picture.
func _match_strip(board_screen) -> void:
	_log("MATCH STRIP start :: screen=%s" % str(board_screen))
	if board_screen == null:
		_log("MATCH STRIP skipped :: no board screen")
		return
	var move: Array = board_screen._find_hint_move()
	_log("MATCH STRIP move :: %s" % str(move))
	if move.size() != 2:
		_log("MATCH STRIP skipped :: no legal move on the board")
		return
	var view = board_screen.get_node_or_null("board")
	if view == null:
		_log("MATCH STRIP skipped :: the screen has no board view")
		return
	board_screen._hide_hand()
	# The strip before this one plays a move of its own, and a cascade in it leaves the combo bubble over
	# the middle of the board. The strip is about which cells a move takes, so the screen is cleared
	# first; any bubble this move earns still appears, because it would appear for a player too.
	var stale_toast := board_screen.get_node_or_null("combo_toast")
	if stale_toast != null:
		stale_toast.queue_free()
	await _frames(3)
	var origin: Vector2 = view.position + view.grid_origin
	var side := int(view.cell_size * float(view.run.board.width)) + 8
	var window := Rect2i(Vector2i(int(origin.x) - 4, int(origin.y) - 4), Vector2i(side, side))
	var frames: Array = []
	var before: Image = await _grab_rect(window)
	if before != null:
		frames.append(before)
	Engine.time_scale = 0.2
	board_screen._attempt_swap(move[0], move[1])
	var offsets := [0.02, 0.05, 0.09, 0.14, 0.22, 0.34, 0.50, 0.70]
	for index in range(offsets.size()):
		await get_tree().create_timer(float(offsets[index])).timeout
		var grabbed: Image = await _grab_rect(window)
		_log("MATCH STRIP frame %d :: %s" % [index, "null" if grabbed == null else str(grabbed.get_size())])
		if grabbed != null:
			frames.append(grabbed)
	Engine.time_scale = 1.0
	await _frames(30)
	_save_strip(frames, "16-match-strip", 3, 2)

## One cell's worth of board, photographed through a whole burst: the spray is a quarter of a second
## long, so a single still can never show both the droplets in the air and the splat they leave. This
## is the evidence that they go left and right, and that they stay inside the cell.
func _burst_strip(board_screen) -> void:
	var view = board_screen.get("_board")
	if view == null:
		_log("BURST skipped :: no board view")
		return
	var cell := Vector2i(3, 4)
	var centre: Vector2 = view.position + view.cell_center(cell)
	var span := int(maxf(float(view.cell_size) * 2.2, 64.0))
	var window := Rect2i(Vector2i(int(centre.x) - span / 2, int(centre.y) - span / 2),
		Vector2i(span, span))
	var frames: Array = []
	var before: Image = await _grab_rect(window)
	if before != null:
		frames.append(before)
	Engine.time_scale = 0.18
	Fx.splash(view, view.cell_center(cell), Fx.piece_tint(GameTypes.PieceKind.AQIQ),
		view.cell_size)
	for index in range(9):
		await get_tree().create_timer(0.02 + 0.02 * float(index)).timeout
		var grabbed: Image = await _grab_rect(window)
		if grabbed != null:
			frames.append(grabbed)
	Engine.time_scale = 1.0
	await _frames(20)
	_save_strip(frames, "15-burst-strip", 5, 4)

## A horizontal filmstrip of already-cropped frames, doubled so the stones are big enough to judge.
## A grid of already-cropped frames, enlarged, laid out left to right and top to bottom. A strip in one
## long row is unreadable on screen — five frames and it is wider than the window it is judged in.
func _save_strip(frames: Array, strip_name: String, columns: int = 5, scale: int = 3) -> void:
	if frames.is_empty():
		_log("STRIP %s skipped :: no frames" % strip_name)
		return
	var cell: Image = frames[0]
	var pad := 10
	var cell_w := cell.get_width() * scale
	var cell_h := cell.get_height() * scale
	var cols := clampi(columns, 1, frames.size())
	var rows := int(ceil(float(frames.size()) / float(cols)))
	var strip := Image.create(pad + (cell_w + pad) * cols, pad + (cell_h + pad) * rows, false,
		Image.FORMAT_RGB8)
	strip.fill(Color(UiTokens.BG.r, UiTokens.BG.g, UiTokens.BG.b))
	for index in range(frames.size()):
		var frame: Image = frames[index]
		frame.convert(Image.FORMAT_RGB8)
		frame.resize(cell_w, cell_h, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()),
			Vector2i(pad + (index % cols) * (cell_w + pad), pad + (index / cols) * (cell_h + pad)))
	strip.save_png("%s/%s.png" % [SHOTS, strip_name])
	_log("STRIP %s %dx%d frames=%d" % [strip_name, strip.get_width(), strip.get_height(),
		frames.size()])
	print("[capture] %s written" % strip_name)

## A crop of what the camera sees right now. Everything is drawn before the crop is taken, or the strip
## shows the frame before the one it claims to.
func _grab_rect(rect: Rect2i) -> Image:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var safe := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(safe)

## One image with every screen side by side, so a reviewer can see the whole game without opening five
## files. Built here rather than in the workflow so it needs nothing but Godot.
func _make_contact_sheet(names: Array) -> void:
	var pad := 16
	var cell := Vector2i(738, 415)
	var sheet := Image.create(pad + (cell.x + pad) * names.size(), cell.y + pad * 2, false,
		Image.FORMAT_RGB8)
	sheet.fill(Color(UiTokens.BG.r, UiTokens.BG.g, UiTokens.BG.b))
	for index in range(names.size()):
		var path := "%s/%s.png" % [SHOTS, names[index]]
		if not FileAccess.file_exists(path):
			continue
		var shot := Image.load_from_file(ProjectSettings.globalize_path(path))
		if shot == null:
			continue
		shot.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, cell), Vector2i(pad + index * (cell.x + pad), pad))
	sheet.save_png("%s/00-contact-sheet.png" % SHOTS)
	_log("CONTACT %dx%d" % [sheet.get_width(), sheet.get_height()])

## Everything printed above, plus the rect dumps, as a text file next to the pictures.
func _save_report() -> void:
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_report_lines))
	file.close()
	print("[capture] report: %s (%d lines)" % [REPORT, _report_lines.size()])

## One greppable line per shot: which views claim to be visible, and how big the root really is.
## A screen that should be hidden but is not is a composition bug that only a picture would show,
## so the numbers go into the log where CI can turn them into an annotation.
func _report(app: Node, tag: String) -> void:
	var parts: Array[String] = []
	for key in ["home", "board", "districts", "shop", "settings"]:
		var view = app.get(key)
		if view == null:
			parts.append("%s=null" % key)
		else:
			parts.append("%s=%d" % [key, 1 if view.visible else 0])
	_log("STATE %s :: %s :: root=%s" % [tag, " ".join(parts), str(app.size)])
	var art = app.get("_bg")
	var stage = app.get("_stage")
	var tex = art.texture if art != null else null
	var scrim = app.get("_scrim_top")
	print("[capture] ART %s :: tex=%s :: drawn=%s :: stage=%s :: viewport=%s :: scrim_top=%.2f" % [
		tag, "null" if tex == null else str(tex.get_size()),
		str(art.get_global_rect()) if art != null else "-",
		str(stage.position) + " " + str(stage.size) if stage != null else "-",
		str(app.get_viewport_rect().size),
		scrim.modulate.a if scrim != null else 0.0])
	var escapes: Array[String] = []
	_audit(app, escapes)
	_log("LAYOUT %s :: %d control(s) escape their parent" % [tag, escapes.size()])
	for line in escapes.slice(0, 8):
		_log("LAYOUT %s :: %s" % [tag, line])

## Print the real screen rect of every visible control under one node, with its text. Pixels say
## "something is wrong"; these numbers say what and where.
func _dump(node: Node, start_name: String, limit: int) -> void:
	var start := _find_by_name(node, start_name) if node != null else null
	if start == null:
		_log("DUMP %s missing" % start_name)
		return
	var lines: Array[String] = []
	_collect_rects(start, lines, 0)
	for line in lines.slice(0, limit):
		_log("DUMP " + line)

func _find_by_name(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_by_name(child, wanted)
		if found != null:
			return found
	return null

func _collect_rects(node: Node, out: Array[String], depth: int) -> void:
	if out.size() > 80:
		return
	if node is Control and node.visible:
		var control := node as Control
		var extra := ""
		if control is Button:
			extra = " text=%s disabled=%s" % [(control as Button).text, str((control as Button).disabled)]
		elif control is Label:
			extra = " text=%s" % (control as Label).text
		out.append("%s%s %s%s" % ["  ".repeat(depth), control.name, str(control.get_global_rect()), extra])
		depth += 1
	for child in node.get_children():
		_collect_rects(child, out, depth)

func _audit(node: Node, out: Array[String]) -> void:
	if node is Control and not (node as Control).visible:
		return
	for child in node.get_children():
		if child is Control and child.visible and child.get_parent() is Control:
			var control := child as Control
			var parent := control.get_parent() as Control
			if (child is Label or child is Panel) and not parent.get_global_rect().grow(1.0).encloses(control.get_global_rect()):
				out.append("%s %s in %s %s" % [control.name, str(control.get_global_rect()),
					parent.name, str(parent.get_global_rect())])
		_audit(child, out)

func _log(line: String) -> void:
	_report_lines.append(line)
	print("[capture] " + line)

func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [SHOTS, shot_name]
	image.save_png(path)
	print("[capture] %s %dx%d" % [path, image.get_width(), image.get_height()])
