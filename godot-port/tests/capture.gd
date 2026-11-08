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

	# The combo bubble lives for nine tenths of a second inside a chain, so a camera that waits for one
	# would photograph an empty board. Ask the real screen to show a real bonus, pin the tween to its
	# legible frame, and shoot the element a player would actually see.
	var board_screen = app.get("board")
	board_screen.run.score = 4820
	board_screen.refresh()
	board_screen._show_combo(3, 300)
	await _frames(2)
	var combo_toast := board_screen.get_node_or_null("combo_toast") as Control
	if combo_toast != null:
		combo_toast.modulate = Color(1, 1, 1, 1)
		combo_toast.scale = Vector2.ONE
	await _frames(2)
	await _shot("08-combo")
	if combo_toast != null:
		combo_toast.queue_free()

	# A 20:9 phone is where the old layout letterboxed the art and cropped the content.
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	get_window().size = Vector2i(2400, 1080)
	await _frames(6)
	await _shot("06-board-phone-landscape")
	app._show_home()
	await _frames(6)
	await _shot("07-home-phone-landscape")

	_make_contact_sheet(["01-home", "02-settings", "03-shop", "04-districts", "05-board"])
	_save_report()
	print("[capture] wrote the whole set to %s" % SHOTS)
	get_tree().quit()

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
