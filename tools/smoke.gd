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
const PREVIEW_DIR := "res://documentation/qa/preview"

var _town: Node


func _ready() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW_DIR))

	var menu = MENU_SCENE.instantiate()
	add_child(menu)
	await _settle(10)
	await _capture("00-menu-fa")
	App.set_language("en")
	await _settle(6)
	await _capture("01-menu-en")
	App.set_language("fa")
	menu.queue_free()
	await _settle(3)

	Game.start_new_game()
	_town = TOWN_SCENE.instantiate()
	add_child(_town)
	await _settle(80)

	_boost_town(_town)
	await _settle(12)
	await _capture("02-town-fa")

	_town.select_business("restaurant")
	await _settle(6)
	await _capture("03-business-panel-fa")

	_town.deselect()
	_town.camera_rig.turn_quarter(1)
	_town.state.start_event("holiday")
	_town.day_cycle.set_time(0.47)
	await _settle(24)
	await _capture("04-town-dusk")

	_town.day_cycle.set_time(0.78)
	await _settle(24)
	await _capture("05-town-night")

	_town.day_cycle.set_time(0.22)
	var away := 3.5 * 3600.0
	_town.hud.show_offline(away, _town.state.offline_earnings(away))
	await _settle(10)
	await _capture("06-offline-fa")
	_town.hud.collect_offline()
	await _settle(6)

	_max_town(_town)
	await _settle(120)
	await _capture("07-town-complete")
	_town.hud.dismiss_completion()
	await _settle(20)

	App.set_language("en")
	_town.camera_rig.reset_view()
	_town.select_business("gas_station")
	await _settle(18)
	await _capture("08-town-en")

	# Close on the busiest plot so the queue itself is on the record.
	App.set_language("fa")
	_town.day_cycle.set_time(0.3)
	_town.deselect()
	var gas_plot := BusinessData.plot("gas_station")
	_town.camera_rig.focus_on(Vector3(gas_plot.x, 0, gas_plot.y))
	_town.camera_rig.zoom_by(0.72)
	await _settle(360)
	await _capture("09-customers")

	# The world map, with one town behind the player and the route ahead locked.
	Game.profile.travel("forest")
	Game.profile.travel("desert")
	var map_node: Node = _town.hud.get_node("WorldMap")
	map_node.call("open")
	await _settle(12)
	await _capture("10-world-map")
	map_node.call("close")
	await _settle(4)

	# The crew: staff at the door and a manager patrolling the restaurant plot.
	_town.deselect()
	_town.day_cycle.set_time(0.5)
	var restaurant := BusinessData.plot("restaurant")
	_town.camera_rig.focus_on(Vector3(restaurant.x, 0, restaurant.y))
	_town.camera_rig.zoom_by(0.55)
	await _settle(150)
	await _capture("11-staff")

	# The settings sheet, so the sliders and the presets are on the record too.
	var settings_node: Node = _town.hud.get_node("Settings")
	settings_node.call("open")
	await _settle(10)
	await _capture("12-settings")
	settings_node.call("close")
	await _settle(4)

	# The guild slice: the procedural rig, the follow camera and a carry stack
	# that is literally the number of items in the hands.
	_town.queue_free()
	await _settle(6)
	var probe := GuildProbe.new()
	add_child(probe)
	await _settle(30)
	await _capture("13-guild-lineup")
	print("SMOKE: " + probe.describe())
	print("SMOKE: " + probe.hall_report())
	probe.focus_hero()
	probe.set_demo_pose("carry", 4)
	await _settle(20)
	await _capture("14-guild-carry")
	print("SMOKE: " + probe.describe())
	probe.set_demo_money(240.0, "deposit")
	await _settle(20)
	await _capture("15-guild-deposit")
	probe.overview()
	await _settle(20)
	await _capture("16-guild-hall-top")
	probe.set_demo_money(0.0, "idle")

	# The first real loop: shelf -> hands -> counter -> coins -> vault.
	probe.place_hero(Vector3(9.0, 0.0, 8.0), 180.0)
	probe.press_action()
	await _settle(45)
	print("SMOKE: loop pickup " + str(probe.last_result))
	probe.focus_hero()
	await _settle(20)
	await _capture("17-guild-pickup")

	probe.place_hero(Vector3(-9.6, 0.0, 7.0), 0.0)
	probe.press_action()
	await _settle(45)
	print("SMOKE: loop deliver " + str(probe.last_result))
	await _capture("18-guild-deliver")

	probe.place_hero(Vector3(9.6, 0.0, 2.6), 180.0)
	probe.press_action()
	await _settle(45)
	print("SMOKE: loop deposit " + str(probe.last_result))
	await _capture("19-guild-vault")

	print("SMOKE: " + probe.describe())
	print("SMOKE: " + probe.trade_report())
	_write_probe_report(
			probe.describe()
			+ "\n" + probe.hero_report()
			+ "\n" + probe.hall_report()
			+ "\n" + probe.trade_report()
	)
	probe.queue_free()
	await _settle(4)

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
	state.reputation = 1500.0
	state.advance(0.05)
	var mission := state.mission_progress()
	if not mission.is_empty() and bool(mission["ready"]):
		state.claim_mission()
	town.view.refresh_all()
	town.hud.refresh()


## Levels every business to the top so the completion banner can be captured.
func _max_town(town) -> void:
	var state: TownState = town.state
	state.cash = 500000000.0
	for id in state.business_ids():
		while state.business(id).level < BusinessData.MAX_LEVEL:
			state.upgrade_business(id)
		for branch in BusinessData.BRANCHES:
			while state.business(id).can_upgrade_branch(branch):
				state.upgrade_branch(id, branch)
	state.advance(0.2)


## Diagnostics with the screenshots: a missing mesh is then readable from the
## repository, not only from the CI log.
func _write_probe_report(text: String) -> void:
	var file := FileAccess.open("res://documentation/qa/guild-probe.txt", FileAccess.WRITE)
	if file == null:
		printerr("SMOKE: could not write the probe report")
		return
	file.store_string(text + "\n")
	file.close()
	print("SMOKE: wrote the probe report")


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

	# Small, committed stills so the play-through can be reviewed without
	# downloading the (much larger) full-resolution artifact.
	var preview := image.duplicate() as Image
	preview.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	var preview_error := preview.save_jpg("%s/%s.jpg" % [PREVIEW_DIR, name], 0.72)
	print("SMOKE: preview %s (%s)" % [name, error_string(preview_error)])
