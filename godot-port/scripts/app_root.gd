class_name AppRoot
extends Control
## The one node a scene needs, ported from client/Assets/Game/AppRoot.cs.
##
## It loads the save, builds the five screens and the top bar, and is the only place that knows how
## they connect: screens emit, AppRoot navigates. Nothing is authored in the scene file, so there is
## no node tree to break and CI can boot the game headlessly.

const TICK_SECONDS := 1.0

var clock: GameClock
var store: SaveStore
var session: GameSession
var top_bar: TopBar
var home: HomeScreen
var board: BoardScreen
var districts: DistrictScreen
var shop: ShopScreen
var settings: SettingsScreen

var sound: SoundDirector
var _fade: ColorRect
var _tick := 0.0
var _current: UiScreen

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot()

func _boot() -> void:
	clock = GameClock.new()
	store = SaveStore.new(clock)

	var errors: Array[String] = []
	session = GameSession.load_session(clock, store, GameSession.CHAPTER, errors)
	for message in errors:
		push_warning("[boot] " + message)
	print("[boot] save at %s — level %d, %d potions, %d lives" % [
		store.location, session.current_level, session.wallet.potions, session.lives.current])

	home = HomeScreen.new()
	home.name = "HomeScreen"
	add_child(home)
	home.init_screen(session)
	home.play_requested.connect(_on_play_requested)
	home.districts_requested.connect(_show_districts)
	home.shop_requested.connect(_show_shop)
	home.settings_requested.connect(_show_settings)

	board = BoardScreen.new()
	board.name = "BoardScreen"
	add_child(board)
	board.init_screen(session)
	board.home_requested.connect(_show_home)
	board.next_level_requested.connect(_play)
	board.retry_requested.connect(_play)

	districts = DistrictScreen.new()
	districts.name = "DistrictScreen"
	add_child(districts)
	districts.init_screen(session)
	districts.back_requested.connect(_show_home)

	shop = ShopScreen.new()
	shop.name = "ShopScreen"
	add_child(shop)
	shop.init_screen(session)
	shop.back_requested.connect(_show_home)

	settings = SettingsScreen.new()
	settings.name = "SettingsScreen"
	add_child(settings)
	settings.init_screen(session)
	settings.back_requested.connect(_show_home)

	sound = SoundDirector.new()
	sound.name = "Sound"
	add_child(sound)
	sound.apply_settings(session.save)

	# Added last so the strip draws above every screen.
	top_bar = TopBar.new()
	top_bar.name = "TopBar"
	add_child(top_bar)
	top_bar.build(session)

	_fade = ColorRect.new()
	_fade.name = "fade"
	_fade.color = Color(UiTokens.BG.r, UiTokens.BG.g, UiTokens.BG.b, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	UiKit.stretch(_fade, 0.0, 0.0)
	_fade.move_to_front()

	session.changed.connect(_refresh_all)
	session.refresh_lives()

	_show_home()

# ---- navigation ---------------------------------------------------------------------------------

func _show_screen(target: UiScreen) -> void:
	for screen in [home, board, districts, shop, settings]:
		screen.set_visible_screen(screen == target)
	_current = target
	target.refresh()
	top_bar.refresh()
	_fade_in()

## A short dip to the background colour on every screen change: cheap, and it hides the pop of a
## screen whose widgets are built the first time it is shown.
func _fade_in() -> void:
	if _fade == null:
		return
	_fade.color = Color(UiTokens.BG.r, UiTokens.BG.g, UiTokens.BG.b, 0.85)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, UiTokens.MOTION_SCREEN)

func _show_home() -> void:
	board.clear()
	_show_screen(home)

func _show_districts() -> void:
	_show_screen(districts)

func _show_shop() -> void:
	_show_screen(shop)

func _show_settings() -> void:
	_show_screen(settings)

func _on_play_requested() -> void:
	_play(session.current_level)

## Starts a level if it may be started; otherwise stays on the home screen, which explains why.
func _play(level_number: int) -> void:
	if not session.blocked_reason(level_number).is_empty():
		_show_home()
		return
	if not board.start_level(level_number):
		_show_home()
		return
	_show_screen(board)

# ---- ticks --------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if session == null:
		return
	_tick += delta
	if _tick < TICK_SECONDS:
		return
	_tick = 0.0
	# Lives refill from a timestamp, so nothing has to wake up: this only notices the clock moved.
	session.refresh_lives()
	top_bar.refresh()
	if _current == home:
		home.refresh()

func _refresh_all() -> void:
	if top_bar == null:
		return
	top_bar.refresh()
	if _current != null:
		_current.refresh()

## Android's back gesture returns to the title screen instead of quitting the game.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _current != null and _current != home:
			_show_home()
			get_viewport().set_input_as_handled()
