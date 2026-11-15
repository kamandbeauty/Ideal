extends Node
## Root of the game: owns the level, the HUD and the menus, and moves between
## title, play, pause and result.

enum Mode { MENU, PLAYING, PAUSED, RESULT }

const LEVEL_SCENE: String = "res://scenes/levels/city_siege.tscn"

var mode: Mode = Mode.MENU
var level: CityLevel
var hud: Hud
var menus: Menus
var last_stats: Dictionary = {}
## The stage that PLAY starts, counted from 0: the newest one open unless the player picks an earlier one.
var stage: int = 0
## The match just finished was won and there is a stage after it.
var won_onward: bool = false


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
	stage = Campaign.open_stages(int(Profile.data.stats.stages_cleared)) - 1
	menus.stage = stage
	Events.match_finished.connect(_on_match_finished)
	_start_menu_music()
	menus.show_loading(true)
	_startup()


## Paint the loading screen before touching the heavy level. Resource loading
## happens on a worker; instantiation and prewarming still happen on the main
## thread, after the player has already seen what the game is doing.
func _startup() -> void:
	if DisplayServer.get_name() == "headless":
		# Logic suites need no presentation delay or renderer.
		_load_level()
		_finish_startup()
		return
	var began: int = Time.get_ticks_msec()
	await get_tree().process_frame
	await get_tree().process_frame
	var packed: PackedScene = null
	var error: Error = ResourceLoader.load_threaded_request(LEVEL_SCENE, "PackedScene")
	if error == OK:
		while true:
			var progress: Array = []
			var state: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(LEVEL_SCENE, progress)
			if not progress.is_empty():
				menus.set_loading_progress(float(progress[0]) * 0.8)
			if state == ResourceLoader.THREAD_LOAD_LOADED:
				packed = ResourceLoader.load_threaded_get(LEVEL_SCENE) as PackedScene
				break
			if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				break
			await get_tree().process_frame
	# Fall back to the normal loader if the worker could not start or failed.
	menus.set_loading_progress(0.85, "loading_prepare")
	await get_tree().process_frame
	_load_level(packed)
	menus.set_loading_progress(1.0)
	await get_tree().process_frame
	var left: float = 0.9 - float(Time.get_ticks_msec() - began) / 1000.0
	if left > 0.0:
		await get_tree().create_timer(left).timeout
	_finish_startup()


func _finish_startup() -> void:
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
	if packed == null:
		packed = load(LEVEL_SCENE) as PackedScene
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


## Picks the stage PLAY will start. A stage that is still locked is refused.
func select_stage(index: int) -> bool:
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
	_stop_menu_music()
	Sound.stop_loop("wind")
	won_onward = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	hud.set_active(false)
	menus.show_loading()
	# Let the loading screen paint before the hitch of instantiating the street.
	await get_tree().process_frame
	await get_tree().process_frame
	menus.set_loading_progress(0.65, "loading_prepare")
	await get_tree().process_frame
	_load_level()
	menus.set_loading_progress(1.0)
	menus.hide_all()
	hud.set_active(true)
	level.begin_match()
	mode = Mode.PLAYING
	# Wind is gameplay ambience, not part of the menu music.
	Sound.start_loop("wind", "Effects", -28.0)


func pause() -> void:
	if mode != Mode.PLAYING or (level and level.over):
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
	# Back from a stage that was won, the title screen offers the next one.
	if won_onward:
		select_stage(stage + 1)
	won_onward = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	mode = Mode.MENU
	Sound.stop_loop("wind")
	hud.set_active(false)
	Sound.silence_combat()
	_start_menu_music()
	_load_level()
	menus.show_main()


func _on_match_finished(victory: bool, stats: Dictionary) -> void:
	if mode != Mode.PLAYING and mode != Mode.PAUSED:
		return
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
	elif menus.screen == "arsenal":
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
