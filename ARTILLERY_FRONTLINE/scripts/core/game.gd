extends Node
## Root of the game: owns the level, the HUD and the menus, and moves between
## title, play, pause and result.

enum Mode { MENU, PLAYING, PAUSED, RESULT }

var mode: Mode = Mode.MENU
var level: CityLevel
var hud: Hud
var menus: Menus
var last_stats: Dictionary = {}
## The stage that PLAY starts, counted from 0: the newest one open unless the player picks an earlier one.
var stage: int = 0
## The match just finished was won and there is a stage after it.
var won_onward: bool = false
## Prevent duplicate deploys or menu returns from racing during a transition.
var transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud = Hud.new()
	hud.name = "Hud"
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	menus = Menus.new()
	menus.name = "Menus"
	add_child(menus)
	hud.pause_pressed.connect(pause)
	menus.play_requested.connect(start_match)
	menus.resume_requested.connect(resume)
	menus.restart_requested.connect(start_match)
	menus.menu_requested.connect(to_menu)
	menus.stage_chosen.connect(select_stage)
	menus.next_requested.connect(next_stage)
	menus.gun_chosen.connect(choose_gun)
	stage = mini(int(Profile.data.stats.stages_cleared), Campaign.count() - 1)
	menus.stage = stage
	Events.match_finished.connect(_on_match_finished)
	# Stop any ambience left by a previous scene before the title is displayed.
	Sound.stop_loop("wind")
	Sound.silence_combat()
	_start_menu_music()
	menus.show_loading(true)
	_startup()


## Load the actual selected district, not the city regardless of saved stage.
## Loading and scene setup happen behind an already painted screen. The
## progress bar tracks the threaded resource phase; preparation is a separate
## step because instantiating nodes must happen on the main thread.
func _startup() -> void:
	transitioning = true
	if DisplayServer.get_name() == "headless":
		_load_level()
		transitioning = false
		_finish_startup()
		return
	var ok: bool = await _prepare_level()
	transitioning = false
	if ok:
		_finish_startup()
	else:
		menus.show_main()


func _prepare_level() -> bool:
	# Two frames ensure the loading screen is rendered before setup can block.
	await get_tree().process_frame
	await get_tree().process_frame
	var path: String = Campaign.scene(stage)
	var packed: PackedScene = null
	if DisplayServer.get_name() == "headless":
		packed = load(path) as PackedScene
	else:
		var error: Error = ResourceLoader.load_threaded_request(path, "PackedScene", true)
		if error == OK:
			while true:
				var progress: Array = []
				var state: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path, progress)
				if not progress.is_empty():
					menus.set_loading_progress(float(progress[0]) * 0.8)
				if state == ResourceLoader.THREAD_LOAD_LOADED:
					packed = ResourceLoader.load_threaded_get(path) as PackedScene
					break
				if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					break
				await get_tree().process_frame
		if packed == null:
			packed = load(path) as PackedScene
	if packed == null:
		push_error("Could not load level: " + path)
		return false
	menus.set_loading_progress(0.85, "loading_prepare")
	# Free the old scene before constructing a new one to avoid keeping two
	# zombie pools and worlds alive together on memory-constrained devices.
	if level != null and is_instance_valid(level):
		hud.bind(null)
		level.queue_free()
		level = null
		await get_tree().process_frame
	_load_level(packed)
	menus.set_loading_progress(1.0)
	return true


func _finish_startup() -> void:
	_set_menu_world_idle()
	menus.show_main()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("--autostart"):
		start_match.call_deferred()
	# Development builds can drive themselves and save screenshots; the driver is not exported.
	if arguments.has("--smoke") and ResourceLoader.exists("res://tools/game_smoke.gd"):
		var driver: Node = (load("res://tools/game_smoke.gd") as Script).new()
		driver.name = "SmokeDriver"
		add_child(driver)


func _load_level(packed: PackedScene = null) -> void:
	if level != null and is_instance_valid(level):
		hud.bind(null)
		level.queue_free()
	# Whatever happened to the profile meanwhile, a stage that is not open is never laid.
	stage = clampi(stage, 0, Campaign.open_stages(int(Profile.data.stats.stages_cleared)) - 1)
	menus.stage = stage
	var scene_path: String = Campaign.scene(stage)
	if packed == null:
		packed = load(scene_path) as PackedScene
	level = packed.instantiate()
	level.stage = stage
	level.wave_set = Campaign.waves(stage)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	move_child(level, 0)
	hud.bind(level)
	var chosen: String = str(Profile.setting("gun"))
	if level.defender != null and level.defender.gun_id() != chosen:
		level.defender.mount_gun(chosen)


## Picks the stage PLAY will start; invalid stage numbers are refused.
func select_stage(index: int) -> bool:
	if transitioning:
		return false
	if index < 0 or index >= Campaign.open_stages(int(Profile.data.stats.stages_cleared)):
		return false
	stage = index
	menus.stage = stage
	return true


## From the result screen of a stage that was won: straight on to the next one.
func next_stage() -> void:
	if select_stage(stage + 1):
		start_match()


## Puts another gun on the mount. It is the player's for every match from now on, and the armory,
## which looks out over the gun, shows it at once.
func choose_gun(id: String) -> void:
	if not Profile.GUNS.has(id):
		return
	Profile.set_setting("gun", id)
	if mode == Mode.MENU and level != null and is_instance_valid(level):
		level.defender.mount_gun(id)


## Prefer the licensed recording when supplied; keep the existing theme as a
## fallback so the menu is not silent in builds without that asset.
func _start_menu_music() -> void:
	var track: String = "teeth_in_the_wire" if Sound.has_clip("teeth_in_the_wire") else "music_theme"
	Sound.start_loop(track, "Music", -13.0)


func _stop_menu_music() -> void:
	Sound.stop_loop("teeth_in_the_wire")
	Sound.stop_loop("music_theme")


func start_match() -> void:
	if transitioning:
		return
	transitioning = true
	mode = Mode.MENU
	_stop_menu_music()
	Sound.stop_loop("wind")
	won_onward = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	hud.set_active(false)
	menus.show_loading()
	var ok: bool = await _prepare_level()
	transitioning = false
	if not ok:
		mode = Mode.MENU
		_start_menu_music()
		menus.show_main()
		return
	menus.hide_all()
	hud.set_active(true)
	level.begin_match()
	mode = Mode.PLAYING
	Sound.start_loop("wind", "Effects", -28.0)


func pause() -> void:
	if transitioning or mode != Mode.PLAYING or (level and level.over):
		return
	mode = Mode.PAUSED
	Sound.stop_loop("wind")
	hud.set_active(false)
	get_tree().paused = true
	menus.show_pause(match_status())


## Where the match stands, for the pause screen.
func match_status() -> Dictionary:
	if level == null or not is_instance_valid(level):
		return {}
	return {"wave": level.stats.wave, "waves": level.stats.waves_total, "wall": level.defense.wall_fraction(),
		"gate": level.defense.gate_fraction(), "stage": stage + 1}


func resume() -> void:
	if mode != Mode.PAUSED:
		return
	mode = Mode.PLAYING
	get_tree().paused = false
	Sound.start_loop("wind", "Effects", -28.0)
	menus.hide_all()
	hud.set_active(true)


func to_menu() -> void:
	if transitioning:
		return
	if won_onward:
		select_stage(stage + 1)
	transitioning = true
	won_onward = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	mode = Mode.MENU
	Sound.stop_loop("wind")
	hud.set_active(false)
	Sound.silence_combat()
	_start_menu_music()
	menus.show_loading()
	var ok: bool = await _prepare_level()
	transitioning = false
	if ok:
		_set_menu_world_idle()
	menus.show_main()


## The approved menus have opaque backgrounds and a separate weapon preview.
## Keeping the hidden 3D world alive behind them wastes GPU and CPU on phones.
func _set_menu_world_idle() -> void:
	if level != null and is_instance_valid(level):
		level.visible = false
		level.process_mode = Node.PROCESS_MODE_DISABLED


func _on_match_finished(victory: bool, stats: Dictionary) -> void:
	if mode != Mode.PLAYING and mode != Mode.PAUSED:
		return
	stats = stats.duplicate(true)
	stats["coins_earned"] = Profile.reward_for(stats)
	last_stats = stats
	mode = Mode.RESULT
	Sound.stop_loop("wind")
	get_tree().paused = false
	hud.set_active(false)
	# A first match always beats "nothing"; only a later one can be called a record.
	var record: bool = int(Profile.data.stats.matches) > 0 and int(stats.get("wave_overall", 0)) > int(Profile.data.stats.best_wave)
	Profile.record_match(stats)
	won_onward = victory and stage + 1 < Campaign.count()
	Sound.silence_combat()
	_set_menu_world_idle()
	menus.show_result(victory, stats, record, won_onward)
	Sound.play("victory" if victory else "defeat", -5.0)


## Android's back button (and Escape in the menus): one step back from
## wherever the player is. False when there is nowhere left to go back to.
func go_back() -> bool:
	if mode == Mode.PLAYING:
		pause()
	elif mode == Mode.PAUSED:
		if menus.screen == "settings":
			menus.show_pause()
		else:
			resume()
	elif menus.screen == "settings":
		menus.show_main()
	elif menus.screen == "upgrade":
		menus._show("equipment")
	elif menus.screen == "equipment":
		if menus.equipment_return == "arsenal":
			menus.show_arsenal()
		else:
			menus.show_main()
	elif menus.screen == "arsenal":
		menus.show_campaign()
	elif menus.screen == "campaign":
		menus.show_main()
	elif menus.screen == "loading":
		return true
	elif mode == Mode.RESULT:
		to_menu()
	else:
		return false
	return true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Back on the title screen leaves the game, as Android users expect.
			if not go_back():
				get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if mode == Mode.PLAYING:
				pause()
