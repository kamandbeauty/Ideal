extends Node
## Scripted portrait play-through for CI (`720x1280`):
## captures menus, the bright cartoon forecourt, construction lots & vault
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
	EmpireActions.grant_cash(_town.state, float(q1.get("goal", 400.0)) + 50.0)
	_town.hud.refresh()
	await _settle(720)
	await _capture("02-early-forecourt-en")

	# 2) Expanded Roadside Empire Hub in Persian & English!
	App.set_language("fa")
	_boost_town(_town)
	await _settle(600)
	await _capture("03-town-fa")

	App.set_language("en")
	await _settle(18)
	await _capture("04-town-en")

	# 3) Station Renovation & Manager Bottom Sheet on Gas Station!
	_town.select_business("gas_station")
	await _settle(12)
	await _capture("05-station-sheet")
	App.set_language("fa")
	await _settle(6)
	await _capture("17-station-sheet-fa")
	App.set_language("en")
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
	App.set_language("fa")
	await _settle(6)
	await _capture("18-managers-fa")
	App.set_language("en")
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
	_town.state.active_event = ""
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

	# 11) New one-way circulation and surface detail in daylight.
	App.set_language("en")
	_town.day_cycle.set_time(0.24)
	_town.camera_rig.focus_on(Vector3(0, 0, 4.5))
	_town.camera_rig.zoom = 35.0
	_town.camera_rig.apply()
	await _settle(120)
	await _capture("14-one-way-forecourt")

	# 12) Fully built hub: every reserved bay must remain reachable.
	for id in _town.state.business_ids():
		var business: BusinessState = _town.state.business(id)
		business.unlocked = true
		business.capacity_level = business.max_branch_for("capacity")
	_town.view.refresh_all()
	_town.camera_rig.yaw = 12.0
	_town.camera_rig.focus_on(Vector3(0, 0, 11.0))
	_town.camera_rig.zoom = 56.0
	_town.camera_rig.apply()
	await _settle(90)
	await _capture("15-full-hub-circulation")

	# Match the tall Android aspect ratio in the device feedback (9:20).
	App.set_language("fa")
	_town.camera_rig.reset_view()
	get_window().size = Vector2i(720, 1600)
	await _settle(24)
	await _capture("16-tall-device-fa")

	await _capture_live_car_wash()
	print("SMOKE OK")
	get_tree().quit(0)


## A fresh, single-business fixture makes the close-up deterministic. This is
## still a REAL highway arrival and ServiceQueue timer, never a posed/teleported
## car. The ordinary eight-business hub is covered above and by traffic_check.
func _capture_live_car_wash() -> void:
	_town.queue_free()
	await _settle(3)
	Game.start_new_game()
	for id in Game.town.business_ids():
		Game.town.business(id).unlocked = id == "car_wash"
	get_window().size = Vector2i(720, 1280)
	_town = TOWN_SCENE.instantiate()
	add_child(_town)
	_town.view.customers.max_agents = 1
	_town.day_cycle.set_time(0.24)
	await _settle(66)
	var plot := BusinessData.plot("car_wash")
	_town.camera_rig.focus_on(Vector3(plot.x - 0.8, 0.0, plot.y + 1.8))
	_town.camera_rig.zoom = 26.0
	_town.camera_rig.apply()
	var flow: CustomerFlow = _town.view.customers
	for frame in 2400:
		await get_tree().physics_frame
		for entry in flow.agents:
			if String(entry["phase"]) != "service":
				continue
			var queue: ServiceQueue = flow.get("_queues")["car_wash"]
			if queue.progress_of(int(entry["cid"])) < 0.25:
				continue
			var effects: ServiceEffects = entry["service_fx"]
			assert(effects.visible and effects.servicing, "rendered wash needs actual service")
			assert(effects.particle_count() == 10, "high preset needs its bounded foam pool")
			await _capture("19-live-car-wash-fa")
			App.set_quality("low")
			await _settle(2)
			assert(effects.servicing and effects.particle_count() == 0, "low removes foam, not service")
			await _capture("20-car-wash-low-fa")
			App.set_quality("high")
			return
	assert(false, "car-wash customer did not park in the allotted 40 simulated seconds")


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
		await get_tree().physics_frame


func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	if is_instance_valid(_town):
		_validate_portrait_layout()
	var image := get_viewport().get_texture().get_image()
	if image == null:
		printerr("SMOKE: no image for " + shot_name)
		return
	if shot_name == "14-one-way-forecourt":
		_validate_reference_daylight(image)
	if shot_name == "16-tall-device-fa":
		var gas := BusinessData.plot("gas_station")
		var corner: Vector2 = _town.camera_rig.camera.unproject_position(Vector3(gas.x + 1.61, 2.0, gas.y - 1.30))
		assert(corner.x < get_viewport().get_visible_rect().size.x - 2.0, "tall-device camera crops the gas office")
	var path := "%s/%s.png" % [CAPTURE_DIR, shot_name]
	var error := image.save_png(path)
	print("SMOKE: captured %s (%s)" % [path, error_string(error)])

	var preview := image.duplicate() as Image
	preview.resize(
		540, roundi(540.0 * float(image.get_height()) / float(image.get_width())), Image.INTERPOLATE_BILINEAR
	)
	var preview_error := preview.save_jpg("%s/%s.jpg" % [PREVIEW_DIR, shot_name], 0.78)
	print("SMOKE: preview %s (%s)" % [shot_name, error_string(preview_error)])


func _validate_portrait_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var rectangles: Array[Rect2] = []
	for key in ["_map_btn", "_cases_btn", "_boost_btn", "_managers_btn", "_build_btn"]:
		var button: Button = _town.hud.get(key)
		var rect := button.get_global_rect()
		assert(rect.position.x >= -1.0 and rect.end.x <= viewport_size.x + 1.0, key + " clipped horizontally")
		assert(rect.end.y <= viewport_size.y + 1.0, key + " clipped vertically")
		assert(rect.size.x >= 44.0 and rect.size.y >= 60.0, key + " touch target is too small")
		for other in rectangles:
			assert(not rect.intersects(other), "navigation touch targets overlap")
		rectangles.append(rect)

	var badges: WorldBadges = _town.hud.get("_badges")
	if badges.is_visible_in_tree():
		for entry in badges.get("_entries").values():
			var button: Button = entry["btn"]
			if not button.is_visible_in_tree():
				continue
			var rect := button.get_global_rect()
			assert(rect.position.x >= 0.0 and rect.end.x <= viewport_size.x, "translated world badge is clipped")
			assert(rect.size.y >= 44.0, "world badges need a finger-sized touch target")
			var arrow: Label = entry["arrow"]
			if arrow.visible:
				assert(arrow.get_global_rect().end.x <= viewport_size.x, "world upgrade arrow is clipped")
			if App.language == "fa":
				assert(not button.text.contains("Lv"), "Persian world levels must not use English Lv")

	for root in _town.view.customers.get("_bay_roots").values():
		for child in root.get_children():
			if child is Label3D and child.has_meta("bay_number"):
				assert(child.text == App.to_digits("%02d" % int(child.get_meta("bay_number"))), "bay language is stale")

	if App.language == "fa":
		var sheet: StationSheet = _town.hud.get("_sheet")
		if sheet.visible:
			assert(not (sheet.get("_mgr_title") as Label).text.contains("Lv"), "Persian sheet manager level")
			assert(not (sheet.get("_stats_label") as Label).text.contains("customer"), "Persian customer price")
		var managers: ManagersModal = _town.hud.get("_managers")
		if managers.visible:
			for row in managers.get("_rows").values():
				assert(not (row["name"] as Label).text.contains("Lv"), "Persian manager modal level")
				assert(not (row["fac"] as Label).text.contains("Profit"), "Persian manager profit")


func _validate_reference_daylight(image: Image) -> void:
	var camera: Camera3D = _town.camera_rig.camera
	var road_pt := Vector2i(camera.unproject_position(Vector3(0, 0.078, 2.9)))
	# Use the camera-facing lawn edge; the rear corner is occluded by the new gable.
	var lawn_pt := Vector2i(camera.unproject_position(Vector3(-1.6, 0.076, -0.9)))
	var road := image.get_pixelv(road_pt)
	var lawn := image.get_pixelv(lawn_pt)
	print("SMOKE PALETTE: road=#%s lawn=#%s" % [road.to_html(false), lawn.to_html(false)])
	assert(
		road.r > 0.40 and road.r < 0.68 and road.b < 0.78,
		"road must remain grey, not washed-out cyan: " + road.to_html(false)
	)
	assert(
		lawn.g > 0.73 and lawn.b < 0.47 and lawn.r < 0.96,
		"lawn must remain lime, not clipped yellow: " + lawn.to_html(false)
	)
