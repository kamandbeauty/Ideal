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
var _stage: Control
var _bg: TextureRect
var _wash: TextureRect
var _scrim_top: TextureRect
var _scrim_bottom: TextureRect
var _fade: TextureRect
var _tick := 0.0
var _current: UiScreen

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	# The picture fills whatever the device is; the content stays in the 415x738 design space and is
	# centred inside it. Before this, a 20:9 phone letterboxed the art into a flat-colour band and a
	# shorter window cropped it.
	_bg = TextureRect.new()
	_bg.name = "window_art"
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# The rect is computed by _paint_window_art(), which crops rather than letterboxes: the plate is
	# landscape and the phone is not, so the art has to be larger than the window and pinned.
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_scrim_top = _make_scrim("scrim_top", true)
	_scrim_bottom = _make_scrim("scrim_bottom", false)

	_wash = UiKit.color_rect(self, "window_wash", Color(0, 0, 0, 0))
	_wash.texture = UiKit.ui_texture("ui_veil")
	UiKit.stretch(_wash)
	move_child(_wash, _scrim_top.get_index())

	_stage = Control.new()
	_stage.name = "stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.position = Vector2.ZERO
	_stage.size = Vector2(UiTokens.CANVAS_WIDTH, UiTokens.CANVAS_HEIGHT)
	_center_stage()

	home = HomeScreen.new()
	home.name = "HomeScreen"
	_stage.add_child(home)
	home.init_screen(session)
	home.play_requested.connect(_on_play_requested)
	home.districts_requested.connect(_show_districts)
	home.shop_requested.connect(_show_shop)
	home.settings_requested.connect(_show_settings)

	board = BoardScreen.new()
	board.name = "BoardScreen"
	_stage.add_child(board)
	board.init_screen(session)
	board.home_requested.connect(_show_home)
	board.next_level_requested.connect(_play)
	board.retry_requested.connect(_play)

	districts = DistrictScreen.new()
	districts.name = "DistrictScreen"
	_stage.add_child(districts)
	districts.init_screen(session)
	districts.back_requested.connect(_show_home)

	shop = ShopScreen.new()
	shop.name = "ShopScreen"
	_stage.add_child(shop)
	shop.init_screen(session)
	shop.back_requested.connect(_show_home)

	settings = SettingsScreen.new()
	settings.name = "SettingsScreen"
	_stage.add_child(settings)
	settings.init_screen(session)
	settings.back_requested.connect(_show_home)

	sound = SoundDirector.new()
	sound.name = "Sound"
	add_child(sound)
	sound.apply_settings(session.save)
	Haptics.apply_settings(session.save)

	# Added last so the strip draws above every screen.
	top_bar = TopBar.new()
	top_bar.name = "TopBar"
	_stage.add_child(top_bar)
	top_bar.build(session)

	_fade = UiKit.color_rect(self, "fade", Color(UiTokens.BG.r, UiTokens.BG.g, UiTokens.BG.b, 0.0))
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
	_bg.texture = UiKit.backdrop_texture(target.backdrop_art)
	_wash.modulate = target.wash_color
	_paint_window_art(target)
	_center_stage()
	target.refresh()
	top_bar.visible = target.shows_top_bar
	top_bar.refresh()
	_fade_in()

## A short dip to the background colour on every screen change: cheap, and it hides the pop of a
## screen whose widgets are built the first time it is shown.
func _fade_in() -> void:
	if _fade == null:
		return
	_fade.modulate = Color(UiTokens.BG.r, UiTokens.BG.g, UiTokens.BG.b, 0.85)
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, UiTokens.MOTION_SCREEN)

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

## Size and pin the window art so it covers the window without being squashed, and set the two edge
## scrims that keep HUD text readable over a bright plate.
func _paint_window_art(target: UiScreen) -> void:
	var viewport := get_viewport_rect().size
	var tex := _bg.texture
	if tex == null:
		_bg.position = Vector2.ZERO
		_bg.size = viewport
	else:
		var tex_size := tex.get_size()
		var scale_factor := maxf(viewport.x / tex_size.x, viewport.y / tex_size.y)
		var drawn := tex_size * scale_factor
		_bg.size = drawn
		_bg.position = Vector2(
			(viewport.x - drawn.x) * target.backdrop_anchor.x,
			(viewport.y - drawn.y) * target.backdrop_anchor.y)
	for pair in [[_scrim_top, target.scrim.x, true], [_scrim_bottom, target.scrim.y, false]]:
		var scrim_node: TextureRect = pair[0]
		var alpha: float = pair[1]
		scrim_node.visible = alpha > 0.001
		if not scrim_node.visible:
			continue
		scrim_node.modulate.a = alpha
		var height := viewport.y * (0.42 if bool(pair[2]) else 0.34)
		scrim_node.size = Vector2(viewport.x, height)
		scrim_node.position = Vector2(0.0, 0.0) if bool(pair[2]) else Vector2(0.0, viewport.y - height)

## The edge scrim: a shipped picture of the background colour fading out, tinted by `modulate.a`.
## It used to be a `GradientTexture2D` built here, which is a picture the engine painted at run time —
## the one thing the picture rule forbids, and the sweep test now fails on a gradient that sneaks back.
func _make_scrim(node_name: String, from_top: bool) -> TextureRect:
	var node := TextureRect.new()
	node.name = node_name
	node.texture = UiKit.ui_texture("ui_scrim_top" if from_top else "ui_scrim_bottom")
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

## Centre the design space in the real window. With the stretch aspect set to `expand`, the root
## control is the device's shape, so a tall phone gets extra picture above and below the game instead
## of the game being cropped to it.
func _center_stage() -> void:
	if _stage == null:
		return
	var visible_size := get_viewport_rect().size
	_stage.position = Vector2(
		maxf(0.0, (visible_size.x - UiTokens.CANVAS_WIDTH) * 0.5),
		maxf(0.0, (visible_size.y - UiTokens.CANVAS_HEIGHT) * 0.5))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center_stage()
		if _current != null:
			_paint_window_art(_current)

## Android's back gesture returns to the title screen instead of quitting the game.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _current != null and _current != home:
			_show_home()
			get_viewport().set_input_as_handled()
