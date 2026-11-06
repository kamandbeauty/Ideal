extends Node3D
## Application flow and screen composition; no ballistic or damage rules here.
var world: Node3D
var interface: CanvasLayer
var surface: Control
var aim_input: AimInput
var menus: MenuScreens
var hud: GameplayHUD
var battle: BattleController
var coastal: CoastalController
var splash_remaining: float = 1.4
var last_mission_id: String = "sr01"
var smoke_mode: bool = false
var pending_smoke_result: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	interface = CanvasLayer.new()
	interface.layer = 10
	add_child(interface)
	surface = Control.new()
	surface.name = "Interface"
	surface.theme = UITheme.theme()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.process_mode = Node.PROCESS_MODE_ALWAYS
	interface.add_child(surface)
	aim_input = AimInput.new()
	surface.add_child(aim_input)
	hud = GameplayHUD.new()
	surface.add_child(hud)
	menus = MenuScreens.new()
	surface.add_child(menus)
	hud.visible = false
	_connect_ui()
	_replace_battle(load("res://resources/missions/sr01.tres"), false)
	Events.mission_finished.connect(_on_mission_finished)
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	smoke_mode = "--smoke-test" in OS.get_cmdline_user_args() or "--coastal-smoke" in OS.get_cmdline_user_args()
	if "--smoke-test" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://tools/game_smoke.gd"):
		var smoke: Node = load("res://tools/game_smoke.gd").new()
		smoke.set("game", self)
		add_child(smoke)
	if "--coastal-smoke" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://tools/coastal_smoke.gd"):
		var coastal_smoke: Node = load("res://tools/coastal_smoke.gd").new()
		coastal_smoke.set("game", self)
		add_child(coastal_smoke)

func _connect_ui() -> void:
	menus.deploy_requested.connect(start_mission)
	menus.coastal_requested.connect(start_coastal_milestone)
	menus.navigation_requested.connect(navigate)
	menus.resume_requested.connect(resume_game)
	menus.restart_requested.connect(func(): start_mission(last_mission_id))
	menus.abort_requested.connect(return_to_command)
	menus.next_requested.connect(_next_mission)
	menus.upgrade_requested.connect(func(id): menus.toast(Profile.purchase(load("res://resources/upgrades/%s.tres" % id))))
	menus.weapon_selected.connect(func(id): Profile.data.selected_weapon = id; Profile.persist(); menus.toast("KESTREL M-42 EQUIPPED"))
	hud.fire_requested.connect(func(): battle.fire())
	hud.reload_requested.connect(func(): battle.reload())
	hud.zoom_requested.connect(func(): battle.cameras.toggle_zoom())
	hud.camera_requested.connect(func(): battle.cameras.cycle())
	hud.pause_requested.connect(pause_game)
	hud.target_requested.connect(func(): battle.cycle_target())
	hud.solution_requested.connect(func(): battle.compute_solution())
	hud.ammunition_requested.connect(func(id): battle.select_ammunition(id))

func _replace_battle(mission: MissionData, active: bool) -> void:
	if is_instance_valid(battle):
		world.remove_child(battle)
		battle.queue_free()
	battle = load("res://scenes/battlefield/battle.tscn").instantiate()
	battle.mission = mission
	battle.active_on_ready = active
	world.add_child(battle)
	aim_input.dragged.connect(battle.aim_drag)
	if active:
		hud.bind(battle)

func start_coastal_milestone() -> void:
	get_tree().paused = false
	if is_instance_valid(coastal):
		coastal.queue_free()
	if is_instance_valid(battle):
		world.remove_child(battle)
		battle.queue_free()
		battle = null
	coastal = load("res://scenes/coastal/coastal_milestone.tscn").instantiate()
	world.add_child(coastal)
	coastal.exit_requested.connect(return_to_command)
	surface.visible = false
	menus.visible = false
	hud.visible = false
	Sound.play_ui()

func start_mission(id: String) -> void:
	if not id in Profile.data.unlocked:
		menus.toast("COMPLETE THE PREVIOUS OPERATION TO UNLOCK")
		return
	last_mission_id = id
	get_tree().paused = false
	_replace_battle(load("res://resources/missions/%s.tres" % id), true)
	menus.visible = false
	hud.visible = true
	Sound.play_ui()

func return_to_command() -> void:
	get_tree().paused = false
	if is_instance_valid(coastal):
		coastal.queue_free()
		coastal = null
	surface.visible = true
	if is_instance_valid(battle):
		battle.missions.active = false
	_replace_battle(load("res://resources/missions/sr01.tres"), false)
	hud.visible = false
	menus.show_screen("main")

func navigate(screen: String) -> void:
	if screen == "main":
		return_to_command()
		return
	menus.show_screen(screen)

func pause_game() -> void:
	if not is_instance_valid(battle) or not battle.active:
		return
	get_tree().paused = true
	hud.visible = false
	menus.show_screen("pause")

func resume_game() -> void:
	get_tree().paused = false
	menus.visible = false
	hud.visible = true

func _on_mission_finished(result: Dictionary) -> void:
	var first_clear: bool = not last_mission_id in Profile.data.completed
	var previous_stars: int = int(Profile.data.records.get(last_mission_id, {}).get("stars", 0))
	Profile.complete_mission(battle.mission, result)
	if not first_clear:
		result["points"] = 0
	result["star_gain"] = maxi(0, int(result.stars) - previous_stars)
	if smoke_mode:
		# Let the smoke driver photograph the final explosion before the UI hides it.
		pending_smoke_result = result.duplicate(true)
		return
	_present_results(result)

func present_smoke_results() -> void:
	if not pending_smoke_result.is_empty():
		_present_results(pending_smoke_result)
		pending_smoke_result.clear()

func _present_results(result: Dictionary) -> void:
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	hud.visible = false
	menus.show_results(result)
	if not Profile.storage_available:
		menus.toast("STORAGE UNAVAILABLE — progress could not be saved")

func _next_mission() -> void:
	var order: Array[String] = ["sr01", "sr02", "sr03", "sr04", "sr05"]
	var index: int = order.find(last_mission_id)
	if index >= 0 and index + 1 < order.size():
		start_mission(order[index + 1])

func _process(delta: float) -> void:
	if splash_remaining > 0.0:
		splash_remaining -= delta
		if splash_remaining <= 0.0 and not smoke_mode:
			menus.show_screen("main")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_back()
		get_viewport().set_input_as_handled()

func _back() -> void:
	if is_instance_valid(coastal) and coastal.active:
		coastal.set_paused(not coastal.paused)
		return
	if menus.visible:
		match menus.current:
			"pause": resume_game()
			"settings": menus.show_screen(menus.settings_return)
			"briefing": menus.show_screen("campaign")
			"upgrades": menus.show_screen("arsenal")
			"main": pass
			_: menus.show_screen("main")
	elif is_instance_valid(battle) and battle.active:
		pause_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("android") and not get_tree().paused:
		if is_instance_valid(coastal) and coastal.active:
			coastal.set_paused(true)
		elif is_instance_valid(battle) and battle.active:
			pause_game()

func _update_safe_area() -> void:
	if not OS.has_feature("android"):
		return
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window_size.x <= 0 or safe.size.x <= 0:
		return
	var scale: Vector2 = surface.size / window_size
	surface.offset_left = maxf(12, safe.position.x * scale.x)
	surface.offset_top = maxf(8, safe.position.y * scale.y)
	surface.offset_right = -maxf(12, (window_size.x - safe.end.x) * scale.x)
	surface.offset_bottom = -maxf(8, (window_size.y - safe.end.y) * scale.y)
