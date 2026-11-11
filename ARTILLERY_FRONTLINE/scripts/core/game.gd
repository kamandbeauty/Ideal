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
	Events.match_finished.connect(_on_match_finished)
	Sound.start_loop("wind", "Music", -15.0)
	Sound.start_loop("music_theme", "Music", -13.0)
	_load_level()
	menus.show_main()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("--autostart"):
		start_match.call_deferred()
	# Development builds can drive themselves and save screenshots; the driver is not exported.
	if arguments.has("--smoke") and ResourceLoader.exists("res://tools/game_smoke.gd"):
		var driver: Node = (load("res://tools/game_smoke.gd") as Script).new()
		driver.name = "SmokeDriver"
		add_child(driver)


func _load_level() -> void:
	if level != null and is_instance_valid(level):
		hud.bind(null)
		level.queue_free()
	level = (load(LEVEL_SCENE) as PackedScene).instantiate()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	move_child(level, 0)
	hud.bind(level)


func start_match() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_load_level()
	menus.hide_all()
	hud.set_active(true)
	level.begin_match()
	mode = Mode.PLAYING


func pause() -> void:
	if mode != Mode.PLAYING or (level and level.over):
		return
	mode = Mode.PAUSED
	hud.set_active(false)
	get_tree().paused = true
	menus.show_pause()


func resume() -> void:
	if mode != Mode.PAUSED:
		return
	mode = Mode.PLAYING
	get_tree().paused = false
	menus.hide_all()
	hud.set_active(true)


func to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	mode = Mode.MENU
	hud.set_active(false)
	_load_level()
	menus.show_main()


func _on_match_finished(victory: bool, stats: Dictionary) -> void:
	if mode != Mode.PLAYING and mode != Mode.PAUSED:
		return
	last_stats = stats
	mode = Mode.RESULT
	get_tree().paused = false
	hud.set_active(false)
	Profile.record_match(stats)
	menus.show_result(victory, stats)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if mode == Mode.PLAYING:
				pause()
			elif mode == Mode.PAUSED:
				if menus.screen == "settings":
					menus.show_pause()
				else:
					resume()
			elif menus.screen == "settings":
				menus.show_main()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if mode == Mode.PLAYING:
				pause()
