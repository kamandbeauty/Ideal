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

	await _shot("01-home")
	app._show_settings()
	await _frames(SETTLE_FRAMES)
	await _shot("02-settings")
	app._show_shop()
	await _frames(SETTLE_FRAMES)
	await _shot("03-shop")
	app._show_districts()
	await _frames(SETTLE_FRAMES)
	await _shot("04-districts")
	app._show_home()
	await _frames(4)
	app._play(1)
	await _frames(30)
	await _shot("05-board")
	print("[capture] wrote %d shots to %s" % [5, SHOTS])
	get_tree().quit()

func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [SHOTS, shot_name]
	image.save_png(path)
	print("[capture] %s %dx%d" % [path, image.get_width(), image.get_height()])
