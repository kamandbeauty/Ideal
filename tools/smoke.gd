extends Node
## Scripted play-through for CI: opens the menu, runs the desert town, buys
## upgrades and a manager, turns and zooms the camera, opens the business panel
## and the offline report, and saves screenshots of each step.
##
##     xvfb-run godot --path . res://tools/smoke.tscn
##
## It is a scene (not a --script main loop) so the autoloads exist exactly as
## they do for a player.

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const TOWN_SCENE := preload("res://scenes/town/town.tscn")
const CAPTURE_DIR := "res://documentation/qa"

var _town: Node


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
	await _settle(3)

	Game.start_new_game()
	_town = TOWN_SCENE.instantiate()
	add_child(_town)
	await _settle(8)

	_boost_town(_town)
	await _settle(12)
	await _capture("02-town-fa")

	_town.select_business("restaurant")
	await _settle(6)
	await _capture("03-business-panel-fa")

	_town.deselect()
	_town.camera_rig.turn_quarter(1)
	await _settle(20)
	await _capture("04-town-turned")

	_town.camera_rig.zoom_by(0.6)
	await _settle(14)
	await _capture("05-town-close")

	var away := 3.5 * 3600.0
	_town.hud.show_offline(away, _town.state.offline_earnings(away))
	await _settle(8)
	await _capture("06-offline-fa")
	_town.hud.collect_offline()
	await _settle(4)

	App.set_language("en")
	_town.camera_rig.reset_view()
	_town.select_business("gas_station")
	await _settle(10)
	await _capture("07-town-en")

	print("SMOKE OK")
	get_tree().quit(0)


## Gives the demo town enough progress to show every part of the interface.
func _boost_town(town) -> void:
	var state: TownState = town.state
	state.cash = 60000.0
	for id in ["restaurant", "store", "workshop", "motel", "car_wash"]:
		state.unlock_business(id)
	for id in state.business_ids():
		state.upgrade_business(id)
		state.upgrade_business(id)
		state.upgrade_branch(id, "capacity")
		state.upgrade_branch(id, "quality")
		state.hire_manager(id)
	state.reputation = 310.0
	state.advance(0.05)
	town.view.refresh_all()
	town.hud.refresh()


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
