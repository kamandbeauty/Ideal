extends Node
## Drives the real AppRoot through every screen and saves a PNG of each, so the port's layout can be
## reviewed without a device. Runs under Xvfb on CI: `godot --path godot-port res://tests/capture.tscn`.
##
## This exists because "it looks fine in the tests" is not evidence. Geometry assertions catch
## overlaps; only a picture catches "the palace art never drew".

const SHOTS := "res://.shots"
const SETTLE_FRAMES := 12

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	DisplayServer.window_set_size(Vector2i(415, 738))
	await _frames(2)

	var app: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _frames(20)

	_report(app, "boot")
	await _shot("01-home")
	app._show_settings()
	await _frames(SETTLE_FRAMES)
	_report(app, "settings")
	await _shot("02-settings")
	app._show_shop()
	await _frames(SETTLE_FRAMES)
	_report(app, "shop")
	await _shot("03-shop")
	app._show_districts()
	await _frames(SETTLE_FRAMES)
	await _shot("04-districts")
	app._show_home()
	await _frames(4)
	app._play(1)
	await _frames(30)
	_report(app, "board")
	await _shot("05-board")
	# A 20:9 phone is where the old layout letterboxed the art and cropped the content.
	DisplayServer.window_set_size(Vector2i(1080, 2400))
	get_window().size = Vector2i(1080, 2400)
	await _frames(6)
	await _shot("06-board-phone-20x9")
	app._show_home()
	await _frames(6)
	await _shot("07-home-phone-20x9")

	print("[capture] wrote the whole set to %s" % SHOTS)
	get_tree().quit()

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
	print("[capture] STATE %s :: %s :: root=%s" % [tag, " ".join(parts), str(app.size)])
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
	print("[capture] LAYOUT %s :: %d control(s) escape their parent" % [tag, escapes.size()])
	for line in escapes.slice(0, 8):
		print("[capture] LAYOUT %s :: %s" % [tag, line])

func _audit(node: Node, out: Array[String]) -> void:
	for child in node.get_children():
		if child is Control and child.visible and child.get_parent() is Control:
			var control := child as Control
			var parent := control.get_parent() as Control
			if (child is Label or child is Panel) and not parent.get_global_rect().grow(1.0).encloses(control.get_global_rect()):
				out.append("%s in %s" % [control.name, parent.name])
		_audit(child, out)

func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [SHOTS, shot_name]
	image.save_png(path)
	print("[capture] %s %dx%d" % [path, image.get_width(), image.get_height()])
