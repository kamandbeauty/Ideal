extends Node
## Scripted portrait play-through for CI (`720x1280`):
## captures menus, early desert forecourt with derelict junkyard lots & vault
## badges, expanded Roadside Empire hub, Station Sheet, Managers & Bourbon,
## Supply Cases, Territory Map & Expeditions, Monster Hills rally and Night mode!

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const TOWN_SCENE := preload("res://scenes/town/town.tscn")
const CAPTURE_DIR := "res://documentation/qa"
const PREVIEW_DIR := "res://documentation/qa/preview"

var _town: Node


func _ready() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW_DIR))

	var menu = MENU_SCENE.instantiate()
	add_child(menu)
	await _settle(12)
	await _capture("00-menu-fa")
	App.set_language("en")
	await _settle(6)
	await _capture("01-menu-en")
	menu.queue_free()
	await _settle(3)

	# 1) Early Forecourt in English (like Google Play Screenshot 1 & 2!):
	# Gas Station open + Vault cash + 1 Green Quest ready + Derelict Car Wash $300!
	Game.start_new_game()
	_town = TOWN_SCENE.instantiate()
	add_child(_town)
	await _settle(90)
	_town.state.cash = 420.0
	_town.state.advance(18.0)
	var q1: Dictionary = _town.state.quest_slots[1]
	_town.state.earn(float(q1.get("goal", 400.0)) + 50.0)
	_town.hud.refresh()
	await _settle(90)
	await _capture("02-early-forecourt-en")

	# 2) Expanded Roadside Empire Hub in Persian & English!
	App.set_language("fa")
	_boost_town(_town)
	await _settle(120)
	await _capture("03-town-fa")

	App.set_language("en")
	await _settle(18)
	await _capture("04-town-en")

	# 3) Station Renovation & Manager Bottom Sheet on Gas Station!
	_town.select_business("gas_station")
	await _settle(12)
	await _capture("05-station-sheet")
	_town.deselect()
	await _settle(6)

	# 4) Close-up on Gas Station Forecourt, Pump Canopies & Servicing Vehicles!
	var gas_plot := BusinessData.plot("gas_station")
	_town.camera_rig.focus_on(Vector3(gas_plot.x - 1.2, 0.0, gas_plot.y + 1.5))
	_town.camera_rig.zoom_by(0.72)
	await _settle(180)
	await _capture("06-forecourt-closeup")
	_town.camera_rig.reset_view()
	await _settle(12)

	# 5) Managers & Bourbon Card Collection Modal!
	var mgr_node: Node = _town.hud.get_node("ManagersModal")
	mgr_node.call("open")
	await _settle(10)
	await _capture("07-managers-cards")
	mgr_node.call("close")
	await _settle(4)

	# 6) Supply Cases & Bourbon Shop Modal!
	var cases_node: Node = _town.hud.get_node("CasesModal")
	cases_node.call("open", "cases")
	await _settle(10)
	await _capture("08-supply-cases")
	cases_node.call("close")
	await _settle(4)

	# 7) Territory Map & Monster Hills Expeditions!
	var map_node: Node = _town.hud.get_node("WorldMap")
	map_node.call("open", "story")
	await _settle(10)
	await _capture("09-world-map")
	map_node.call("open", "exp")
	await _settle(10)
	await _capture("10-expeditions")
	map_node.call("close")
	await _settle(4)

	# 8) Monster Hills Rally + x2 Income Booster active!
	EmpireActions.activate_x2_boost(_town.state)
	_town.state.start_event("monster_hills")
	await _settle(90)
	await _capture("11-monster-hills")

	# 9) Desert Highway Night Mode with glowing signs & headlights!
	App.set_language("fa")
	_town.day_cycle.set_time(0.78)
	await _settle(30)
	await _capture("12-town-night-fa")

	# 10) Settings Sheet
	var settings_node: Node = _town.hud.get_node("Settings")
	settings_node.call("open")
	await _settle(10)
	await _capture("13-settings")
	settings_node.call("close")
	await _settle(4)

	print("SMOKE OK")
	get_tree().quit(0)


func _boost_town(town) -> void:
	var state: TownState = town.state
	state.cash = 250000.0
	state.bourbon = 85
	state.gems = 65
	state.manager_cards["buck_novak"] = 4
	state.manager_cards["rico_suds"] = 3
	state.manager_cards["daisy_torque"] = 2

	# Unlock & upgrade initial facilities so Star Level rises to 3, leaving
	# later facilities as visible derelict junkyard lots with Star/Price badges!
	state.upgrade_business("gas_station", 14)
	state.upgrade_branch("gas_station", "capacity")
	state.upgrade_branch("gas_station", "capacity")
	state.upgrade_branch("gas_station", "quality")
	state.hire_manager("gas_station")
	state.hire_manager("gas_station")

	for id in ["car_wash", "auto_service", "toilets", "diner"]:
		state.unlock_business(id)
		if state.business(id).unlocked:
			state.upgrade_business(id, 10)
			state.upgrade_branch(id, "capacity")
			state.hire_manager(id)
			state.hire_manager(id)

	state.chapter_tasks_done = 3
	state.cash = 14800.0
	state.advance(2.5)
	town.view.refresh_all()
	town.hud.refresh()


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _capture(shot_name: String) -> void:
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null:
		printerr("SMOKE: no image for " + shot_name)
		return
	var path := "%s/%s.png" % [CAPTURE_DIR, shot_name]
	var error := image.save_png(path)
	print("SMOKE: captured %s (%s)" % [path, error_string(error)])

	var preview := image.duplicate() as Image
	preview.resize(540, 960, Image.INTERPOLATE_BILINEAR)
	var preview_error := preview.save_jpg("%s/%s.jpg" % [PREVIEW_DIR, shot_name], 0.78)
	print("SMOKE: preview %s (%s)" % [shot_name, error_string(preview_error)])
