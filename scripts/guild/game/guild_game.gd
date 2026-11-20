class_name GuildGame
extends Node3D
## The playable guild: the hall, the guild master, the customers, the board and the
## save file, all in one scene.
##
## This is the scene the game boots into. The probe under `scripts/guild/probe` is the
## same world with a camera on a rail for CI screenshots; everything that makes the
## game work - movement, the queue, the missions, the money, saving - lives here and
## in the systems it wires together, so a capture can never show a hall that plays
## differently from this one.

signal exit_requested()
signal save_written(bytes: int)

const AUTOSAVE_SECONDS := 30.0
const CUSTOMER_EVERY := 18.0
const STARTING_GOLD := 60.0
const STARTING_STOCK := {"slime_gel": 4, "healing_herb": 2}
const STARTING_HERO := Vector3(0.0, 0.05, 8.0)

var hall: GuildHall
var hero: GuildPlayer
var camera_rig: GuildPlayerCamera
var treasury: GuildTreasury
var stock: GuildStock
var desk: GuildMissionDesk
var flow: GuildCustomerFlow
var interaction: GuildInteraction
var hud: GuildHud
var panel: GuildBoardPanel
var stations: Array = []

var booted_from_save := false
var caught_up := 0
var away := 0.0

var _environment: Environment
var _autosave_left := AUTOSAVE_SECONDS
var _customer_left := 4.0


func _ready() -> void:
	_build_environment()
	build_world()
	_activate_camera()
	boot()
	_wire_input()
	print("GUILD: ready " + describe())


func _exit_tree() -> void:
	save_game()


# --- construction ----------------------------------------------------------

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.05, 0.06, 0.14)
	sky_material.sky_horizon_color = Color(0.2, 0.17, 0.33)
	sky_material.ground_bottom_color = Color(0.04, 0.04, 0.08)
	sky_material.ground_horizon_color = Color(0.15, 0.13, 0.26)
	var sky := Sky.new()
	sky.sky_material = sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_energy = 0.66
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.18, 0.16, 0.3)
	_environment.fog_density = 0.005


## Builds the world without booting a save, so a suite can inspect it.
func build_world() -> void:
	if hall != null:
		return
	printerr("GAME: hall")
	hall = GuildHall.new()
	hall.name = "GuildHall"
	add_child(hall)

	printerr("GAME: wallet")
	treasury = GuildTreasury.new()
	stock = GuildStock.new(40)

	printerr("GAME: shelf")
	var shelf := GuildStation.new(GuildStation.SHELF)
	shelf.name = "Shelf"
	shelf.position = Vector3(9.0, 0.0, 9.0)
	add_child(shelf)
	shelf.bind_stock(stock)

	printerr("GAME: counter")
	var counter := GuildStation.new(GuildStation.COUNTER)
	counter.name = "Counter"
	counter.position = Vector3(-9.6, 0.0, 7.4)
	add_child(counter)

	printerr("GAME: vault")
	var vault := GuildStation.new(GuildStation.VAULT)
	vault.name = "Vault"
	vault.position = Vector3(9.6, 0.0, 2.6)
	add_child(vault)
	vault.bind_treasury(treasury)

	printerr("GAME: desk")
	desk = GuildMissionDesk.new()
	desk.setup(treasury, stock, 31)
	desk.hire_default_roster()

	printerr("GAME: board")
	var board := GuildStation.new(GuildStation.BOARD)
	board.name = "Board"
	board.position = Vector3(-10.0, 0.0, 3.4)
	add_child(board)
	board.bind_desk(desk)

	stations = [shelf, counter, vault, board]

	printerr("GAME: hero")
	hero = GuildPlayer.new()
	hero.name = "GuildMaster"
	hero.position = STARTING_HERO
	hero.rotation.y = PI
	add_child(hero)

	printerr("GAME: flow")
	flow = GuildCustomerFlow.new()
	flow.name = "CustomerFlow"
	add_child(flow)
	flow.setup(hall, counter, 11)

	printerr("GAME: interaction")
	interaction = GuildInteraction.new()
	interaction.name = "Interaction"
	add_child(interaction)
	interaction.setup(hero, stations, treasury, stock)
	interaction.traded.connect(_on_traded)

	printerr("GAME: hud")
	hud = GuildHud.new()
	add_child(hud)
	hud.bind(interaction, treasury, stock)
	hud.language_changed.connect(_on_language_changed)

	printerr("GAME: panel")
	panel = GuildBoardPanel.new()
	add_child(panel)
	panel.bind(desk)
	hud.board_pressed.connect(panel.open)
	panel.dispatched.connect(_on_traded)

	printerr("GAME: camera")
	camera_rig = GuildPlayerCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.focus_on(hero.position + Vector3(0.0, 1.25, 0.0))


## Makes the rig's camera the one the player looks through; only meaningful inside
## the tree, which is why `build_world()` leaves it alone.
func _activate_camera() -> void:
	if camera_rig == null or camera_rig.camera == null:
		return
	camera_rig.camera.environment = _environment
	camera_rig.camera.current = true


# --- booting ---------------------------------------------------------------

## Loads the guild, or starts a new one. Returns true when a save was picked up.
func boot() -> bool:
	var data := GuildSave.read()
	if data.is_empty():
		start_fresh()
		return false
	booted_from_save = GuildSave.apply(data, treasury, stock, hero.state, desk)
	if not booted_from_save:
		start_fresh()
		return false
	away = GuildSave.away_seconds(data)
	caught_up = GuildSave.catch_up(desk, away)
	_refresh_stations()
	var line := "Guild opened"
	if caught_up > 0:
		line = "%d expedition(s) came home while you were away" % caught_up
	hud.say(line)
	return true


func start_fresh() -> void:
	booted_from_save = false
	treasury.cash = STARTING_GOLD
	for id in STARTING_STOCK:
		stock.add(str(id), int(STARTING_STOCK[id]))
	hero.position = STARTING_HERO
	hud.say(GuildLocale.t("guild.ready", [], hud.language))


## Writes the guild to its save file; used by the autosave and on exit.
func save_game() -> bool:
	if treasury == null or stock == null:
		return false
	var payload := GuildSave.snapshot(treasury, stock, hero.state, desk)
	var wrote := GuildSave.write(payload)
	if wrote:
		save_written.emit(JSON.stringify(payload).length())
	return wrote


func _refresh_stations() -> void:
	for station in stations:
		var node := station as GuildStation
		if node != null:
			node.refresh()


# --- the running game ------------------------------------------------------

## The HUD owns the stick and the action button and the player owns its own movement;
## the scene only keeps "forward" pointing away from the camera. The HUD's stick is
## already a game direction (x right, y forward), the same convention the player uses.
func _wire_input() -> void:
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if hero == null or hud == null or camera_rig == null:
		return
	hero.set_input(hud.stick_input())
	hero.set_camera_yaw(forward_yaw(camera_rig.yaw))


func _process(delta: float) -> void:
	if hall == null:
		return
	_tick_world(delta)
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = AUTOSAVE_SECONDS
		save_game()


## The queue and the missions run on the same clock the save file advances.
func _tick_world(delta: float) -> void:
	flow.tick(delta)
	desk.tick(delta)
	_customer_left -= delta
	if _customer_left <= 0.0:
		_customer_left = CUSTOMER_EVERY
		flow.spawn()
	if camera_rig != null:
		camera_rig.follow_feet(hero.position, delta)


## The camera sits behind the master at `camera_yaw` looking at its back, so the way
## a pushed stick should walk is the camera's yaw turned around. Pinned by a suite.
static func forward_yaw(camera_yaw: float) -> float:
	return camera_yaw + 180.0


func _on_language_changed(language: String) -> void:
	if hall != null:
		hall.set_language(language)
	if flow != null:
		flow.set_language(language)
	if panel != null:
		panel.set_language(language)


func _on_traded(result: Dictionary) -> void:
	if hud == null or interaction == null:
		return
	interaction.last_result = result
	var line := interaction.result_message(hud.language)
	if not line.is_empty():
		hud.say(line)


func _unhandled_input(event: InputEvent) -> void:
	if camera_rig == null:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			camera_rig.zoom_by(GuildPlayerCamera.ZOOM_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			camera_rig.zoom_by(1.0 / GuildPlayerCamera.ZOOM_STEP)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			camera_rig.orbit(-motion.relative.x * 0.18, -motion.relative.y * 0.12)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_Q:
				camera_rig.turn_quarter(-1)
			KEY_E:
				camera_rig.turn_quarter(1)
			KEY_R:
				camera_rig.reset_view()
			KEY_ESCAPE:
				save_game()
				exit_requested.emit()


func describe() -> String:
	return "guild gold=%.0f stock=%d roster=%d out=%d queue=%d saved=%s caught_up=%d" % [
		treasury.cash if treasury != null else -1.0,
		stock.total() if stock != null else -1,
		desk.adventurers.size() if desk != null else -1,
		desk.active_count() if desk != null else -1,
		flow.queue_length() if flow != null else -1,
		str(booted_from_save),
		caught_up,
	]
