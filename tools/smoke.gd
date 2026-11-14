extends Node
## Scripted play-through for CI: opens the menu, builds a small city, turns and
## zooms the camera, switches language and saves screenshots.
##
##     xvfb-run godot --path . res://tools/smoke.tscn
##
## It is a scene (not a --script main loop) so the autoloads exist exactly as
## they do for a player.

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const CITY_SCENE := preload("res://scenes/city/city.tscn")
const CAPTURE_DIR := "res://documentation/qa"

var _city: Node


func _ready() -> void:
	_run()


func _run() -> void:
	var directory := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(directory)

	var menu = MENU_SCENE.instantiate()
	add_child(menu)
	await _settle(10)
	await _capture("00-menu-fa")
	App.set_language("en")
	await _settle(6)
	await _capture("01-menu-en")
	menu.queue_free()
	await _settle(4)

	_city = CITY_SCENE.instantiate()
	_city.load_from_file = false
	add_child(_city)
	await _settle(6)
	_build_demo_city(_city)
	await _settle(12)
	await _capture("02-city-fa")

	_city.camera_rig.turn_quarter()
	await _settle(45)
	await _capture("03-city-turned")

	_city.camera_rig.zoom_by(0.55)
	await _settle(30)
	await _capture("04-city-close")

	_city.camera_rig.zoom_by(2.4)
	_city.hud.toast(App.t("hud.milestone", [50, 800]))
	await _settle(30)
	await _capture("05-city-toast")

	App.set_language("fa")
	await _settle(10)
	await _capture("06-city-en")

	print("SMOKE OK")
	get_tree().quit(0)


func _build_demo_city(city) -> void:
	var state: CityState = city.state
	state.cash = 120000.0

	# Three streets each way, making four blocks of 4x4 cells.
	for x in [-5, 0, 5]:
		for z in range(-7, 8):
			state.place_free("road", Vector2i(x, z))
	for z in [-5, 5]:
		for x in range(-7, 8):
			if x not in [-5, 0, 5]:
				state.place_free("road", Vector2i(x, z))

	var houses := [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2),
		Vector2i(4, 1), Vector2i(4, 2),
		Vector2i(-1, 1), Vector2i(-2, 1), Vector2i(-4, 2),
		Vector2i(1, -1), Vector2i(1, -2), Vector2i(4, -4),
		Vector2i(-1, -1), Vector2i(-2, -2), Vector2i(-4, -2),
	]
	var kinds := ["house_a", "house_b", "house_d"]
	for i in houses.size():
		state.place_free(kinds[i % kinds.size()], houses[i], i % 4)

	state.place_free("shop", Vector2i(2, -1), 1)
	state.place_free("shop", Vector2i(-4, -1), 2)

	for cell in [Vector2i(3, 2), Vector2i(3, 3), Vector2i(2, 3), Vector2i(2, -2),
			Vector2i(-3, 2), Vector2i(-3, 3), Vector2i(-3, -3)]:
		state.place_free("trees", cell)
	for cell in [Vector2i(4, 3), Vector2i(-4, 3), Vector2i(3, -2), Vector2i(-1, -3)]:
		state.place_free("tall_trees", cell)
	state.place_free("fountain", Vector2i(3, 1))
	state.place_free("fountain", Vector2i(-2, 3))
	for cell in [Vector2i(2, 2), Vector2i(-2, 2), Vector2i(3, -3), Vector2i(-1, -2)]:
		state.place_free("pavement", cell)

	state.recompute()
	state.population = state.capacity

	city.selected_id = "house_a"
	city.view.rebuild()
	city.view.set_selection("house_a", 0)
	city.view.update_cursor(Vector2i(3, -4), true)
	city.hud.set_selection("house_a")
	city.hud.refresh(state)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _capture(name: String) -> void:
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null:
		printerr("SMOKE: no image for " + name)
		return
	var path := "%s/%s.png" % [CAPTURE_DIR, name]
	var error := image.save_png(path)
	print("SMOKE: captured %s (%s)" % [path, error_string(error)])
