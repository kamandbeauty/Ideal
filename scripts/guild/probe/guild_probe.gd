class_name GuildProbe
extends Node3D
## A photographed slice of the guild: the hall with its nine zones, the five
## customer classes, the player carrying goods, and the navigation mesh the
## customers will walk on. CI captures it, so the look and the layout are never
## assumed.
##
## This is a probe, not the game: it has no orders, no economy and no mission
## loop yet. It exists to prove the hall, the rig and the pathfinding together.

const DEMO_SPAWNS: Array[String] = ["warrior", "mage", "archer"]
const DEMO_HERO_SPOT := Vector3(1.0, 0.05, 3.2)

var hall: GuildHall
var hero: GuildPlayer
var stations: Array = []
var stock: GuildStock
var treasury: GuildTreasury
var interaction: GuildInteraction
var hud: GuildHud
var last_result: Dictionary = {}
var camera_rig: GuildPlayerCamera
var flow: GuildCustomerFlow
var counter_station: GuildStation
var board: GuildStation
var desk: GuildMissionDesk

var follow_hero := false
## The play-through drives the queue by hand so a capture is repeatable; in the
## real game `_process` ticks it every frame.
var auto_flow := true
## The mission desk runs on wall-clock time in the game; a capture advances it by
## hand so a forty-second expedition does not cost forty seconds of CI.
var auto_desk := true
var _pose := "idle"
var _speed := 0.0
var _environment: Environment
var _save_bytes := 0
var _save_away := 0.0
var _save_caught_up := 0


func _ready() -> void:
	_build_environment()
	_build_hall()
	_build_cast()
	_build_trade()
	_build_flow()
	_build_missions()
	_build_hud()
	_build_camera()
	print("SMOKE: probe ready, " + describe())


## The pose this probe holds; the smoke run calls it before each capture.
func set_demo_pose(pose: String, carry: int = 0) -> void:
	_pose = pose
	_speed = 2.4 if pose in ["walk", "run"] else 0.0
	# The demo hands are real: four goods, not a number typed into the state.
	hero.state.clear_hands()
	if carry > 0:
		hero.state.hold_items("slime_gel", carry)
	_animate_hero(0.5)


## Empties the hands, so a demo loop starts from nothing.
func clear_hands() -> void:
	hero.state.clear_hands()
	hero.state.unload_money()


## Coins in the hands, for the deposit beat.
func set_demo_money(amount: float, pose: String = "deposit") -> void:
	_pose = pose
	_speed = 0.0
	hero.state.money = amount
	hero.carry_stack.show_money(amount)
	_animate_hero(0.5)


## Tight, slightly low shot of the guild master: the carrying loop's money shot.
func focus_hero() -> void:
	if camera_rig == null:
		return
	camera_rig.distance = GuildPlayerCamera.MIN_DISTANCE
	camera_rig.pitch = 27.0
	camera_rig.yaw = 16.0
	if camera_rig.camera != null:
		camera_rig.camera.fov = 38.0
	camera_rig.focus_on(Vector3(hero.position.x, 1.02, hero.position.z))


## The whole room, which is how the player first sees it.
func overview() -> void:
	shot(Vector3(0.0, 1.2, 0.4), 18.0, 54.0, GuildPlayerCamera.MAX_DISTANCE, 66.0)


## A framed shot from above the furniture, so a capture never ends up inside a
## shelf. Used for the loop beats, where the camera in the player's hand would
## collide with the racks.
func shot(focus: Vector3, yaw_degrees: float, pitch_degrees: float, distance: float, lens: float) -> void:
	if camera_rig == null:
		return
	camera_rig.yaw = yaw_degrees
	camera_rig.pitch = clampf(pitch_degrees, GuildPlayerCamera.MIN_PITCH, GuildPlayerCamera.MAX_PITCH)
	camera_rig.distance = distance
	if camera_rig.camera != null:
		camera_rig.camera.fov = lens
	camera_rig.focus_on(focus)


## Puts the camera over a station, high enough to clear the shelves.
func look_at_station(station: GuildStation) -> void:
	if station == null:
		return
	var spot := station.global_position
	shot(Vector3(spot.x, 1.15, spot.z) , 26.0, 44.0, 8.0, 50.0)


## A one-line health check of the rig, mirrored into the CI log.
func describe() -> String:
	var meshes := hero.character.find_children("*", "MeshInstance3D", true, false)
	var shown := 0
	for mesh in meshes:
		if (mesh as MeshInstance3D).is_visible_in_tree():
			shown += 1
	return "hero_parts=%d hero_meshes=%d hero_visible=%d hero_pos=%s queue=%d stack=%d zone=%s" % [
		hero.character.parts.size(),
		meshes.size(),
		shown,
		str(hero.global_position),
		flow.queue_length() if flow != null else 0,
		hero.carry_stack.visible_count(),
		GuildHallZones.zone_at(hero.global_position),
	]


## The navigation mesh and two real route queries, written next to the captures.
func hall_report() -> String:
	if hall == null:
		return "hall: none"
	var lines: Array[String] = []
	lines.append(hall.navmesh_report())
	lines.append(hall.check_path(
			GuildHallZones.spawn("warehouse_pickup"), GuildHallZones.spawn("counter_delivery")
	))
	lines.append(hall.check_path(GuildHallZones.spawn("door"), GuildHallZones.spawn("treasury_deposit")))
	lines.append(hall.check_path(GuildHallZones.spawn("player"), GuildHallZones.spawn("mission_board")))
	return "\n".join(lines)


## A full dump of the player rig, written next to the captures so a missing mesh
## can be diagnosed from the repo instead of guessed at.
func hero_report() -> String:
	var lines: Array[String] = []
	lines.append("hero in_tree=%s visible=%s pos=%s rot_y=%.3f children=%d" % [
		str(hero.is_inside_tree()),
		str(hero.visible),
		str(hero.global_position),
		hero.rotation.y,
		hero.get_child_count(),
	])
	if hero.character == null:
		lines.append("hero.character is NULL")
		return "\n".join(lines)
	lines.append("rig parts=%d body_children=%d" % [
		hero.character.parts.size(),
		hero.character.get_child_count(),
	])
	for part_name in hero.character.parts:
		var node := hero.character.parts[part_name] as Node3D
		if node == null:
			lines.append("  part %s: not a Node3D" % str(part_name))
			continue
		lines.append("  part %s visible=%s meshes=%d global=%s" % [
			str(part_name),
			str(node.visible),
			node.find_children("*", "MeshInstance3D", true, false).size(),
			str(node.global_position),
		])
	lines.append("stack kind=%s total=%d visible=%d global=%s" % [
		hero.carry_stack.kind,
		hero.carry_stack.total,
		hero.carry_stack.visible_count(),
		str(hero.carry_stack.global_position),
	])
	return "\n".join(lines)


## Moves the guild master and turns them, so a capture can stand them anywhere.
func place_hero(point: Vector3, yaw_degrees: float = 0.0) -> void:
	hero.velocity = Vector3.ZERO
	hero.global_position = Vector3(point.x, 0.05, point.z)
	hero.rotation.y = deg_to_rad(yaw_degrees)


## The item a waiting customer is asking for, so the player grabs the right goods.
func waiting_item() -> String:
	for station in stations:
		var counter := station as GuildStation
		if counter == null or counter.kind != GuildStation.COUNTER or counter.order == null:
			continue
		if counter.order.is_ready():
			return counter.order.item_id
	return ""


func station_at_hero() -> GuildStation:
	return GuildStation.nearest(stations, hero.global_position)


## The action button: starts the verb the nearest station offers. The trade itself
## lands when the verb finishes (see GuildInteraction).
func press_action() -> Dictionary:
	if interaction == null:
		return {"reason": "no interaction"}
	var result := interaction.press()
	last_result = interaction.last_result
	return result


## A fresh customer order, so a capture has a customer to serve.
func renew_order(item_id: String = "slime_gel", amount: int = 3) -> void:
	for station in stations:
		var counter := station as GuildStation
		if counter != null and counter.kind == GuildStation.COUNTER:
			counter.bind_order(GuildOrder.new(item_id, amount))


## The HUD's state, written next to the captures.
func hud_report() -> String:
	if hud == null:
		return "hud: none"
	return "hud lang=%s action=%s gold=%s warehouse=%s customers=%d stick=%s" % [
		hud.language,
		hud.action_label.text,
		hud.gold_label.text,
		hud.warehouse_label.text,
		hud.waiting_customers(),
		str(hud.stick_input()),
	]


## The loop's books, written next to the captures.
func trade_report() -> String:
	return "loop stock=%d hands=%d money=%.0f vault=%.0f reputation=%.1f last=%s" % [
		stock.total() if stock != null else -1,
		hero.state.carry,
		hero.state.money,
		treasury.cash if treasury != null else -1.0,
		treasury.reputation if treasury != null else -1.0,
		str(last_result),
	]


func _process(delta: float) -> void:
	_animate_hero(delta)
	if auto_flow and flow != null:
		flow.tick(delta)
	if auto_desk and desk != null:
		desk.tick(delta)
	if follow_hero and camera_rig != null:
		camera_rig.follow_feet(hero.global_position, delta)


func _animate_hero(delta: float) -> void:
	if hero == null:
		return
	hero.character.animate(delta, _speed, _pose)


# --- construction ----------------------------------------------------------

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.05, 0.06, 0.14)
	sky_material.sky_horizon_color = Color(0.2, 0.17, 0.33)
	sky_material.ground_bottom_color = Color(0.04, 0.04, 0.08)
	sky_material.ground_horizon_color = Color(0.15, 0.13, 0.26)
	sky_material.sun_angle_max = 12.0
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
	_environment.tonemap_exposure = 1.0


func _build_hall() -> void:
	hall = GuildHall.new()
	hall.name = "GuildHall"
	add_child(hall)


func _build_cast() -> void:
	hero = GuildPlayer.new()
	hero.position = DEMO_HERO_SPOT
	hero.rotation.y = deg_to_rad(6.0)
	add_child(hero)
	print("SMOKE: hero node children=%d, rig parts=%d" % [hero.get_child_count(), hero.character.parts.size()])


func _build_trade() -> void:
	treasury = GuildTreasury.new()
	stock = GuildStock.new(40)
	stock.add("slime_gel", 9)
	stock.add("healing_herb", 3)

	var shelf := GuildStation.new(GuildStation.SHELF)
	shelf.name = "Shelf"
	shelf.position = Vector3(9.0, 0.0, 9.0)
	add_child(shelf)
	shelf.bind_stock(stock)

	var counter := GuildStation.new(GuildStation.COUNTER)
	counter.name = "Counter"
	counter.position = Vector3(-9.6, 0.0, 7.4)
	add_child(counter)
	counter.bind_order(GuildOrder.new("slime_gel", 3))

	var vault := GuildStation.new(GuildStation.VAULT)
	vault.name = "Vault"
	vault.position = Vector3(9.6, 0.0, 2.6)
	add_child(vault)
	vault.bind_treasury(treasury)

	stations = [shelf, counter, vault]
	counter_station = counter

	interaction = GuildInteraction.new()
	interaction.name = "Interaction"
	add_child(interaction)
	interaction.setup(hero, stations, treasury, stock)
	interaction.traded.connect(_on_traded)


func _on_traded(result: Dictionary) -> void:
	last_result = result
	_refresh_counter_order()


## After a delivery the counter is empty until the next customer steps up, so the
## sign on it never promises an order nobody is waiting for.
func _refresh_counter_order() -> void:
	if counter_station == null or counter_station.order == null:
		return
	if counter_station.order.fulfilled:
		counter_station.bind_order(null)


func _build_missions() -> void:
	desk = GuildMissionDesk.new()
	desk.setup(treasury, stock, 31)
	desk.hire_default_roster()
	board = GuildStation.new(GuildStation.BOARD)
	board.name = "Board"
	board.position = Vector3(-10.0, 0.0, 3.4)
	add_child(board)
	board.bind_desk(desk)
	# Appended in place: the interaction holds this very array, so a board added
	# later is the same board the button sees.
	stations.append(board)


## Lets the roster's clock run for `seconds` without waiting for them.
func advance_desk(seconds: float) -> void:
	if desk == null:
		return
	var left := seconds
	while left > 0.0:
		var step := minf(0.25, left)
		desk.tick(step)
		left -= step


## Writes the guild to its own save file and reports what went in.
func save_state() -> bool:
	var payload := GuildSave.snapshot(treasury, stock, hero.state, desk)
	_save_bytes = JSON.stringify(payload).length()
	return GuildSave.write(payload)


## Reads the file back onto the live objects, which is the whole point of a save.
func load_state() -> bool:
	var data := GuildSave.read()
	if data.is_empty():
		return false
	_save_bytes = JSON.stringify(data).length()
	_save_away = GuildSave.away_seconds(data)
	if not GuildSave.apply(data, treasury, stock, hero.state, desk):
		return false
	_save_caught_up = GuildSave.catch_up(desk, _save_away)
	return true


func save_report() -> String:
	return "save exists=%s bytes=%d away=%.0f caught_up=%d cash=%.0f stock=%d roster=%d" % [
		str(GuildSave.has_save()),
		_save_bytes,
		_save_away,
		_save_caught_up,
		treasury.cash if treasury != null else -1.0,
		stock.total() if stock != null else -1,
		desk.adventurers.size() if desk != null else -1,
	]


func mission_report() -> String:
	if desk == null:
		return "desk: none"
	return desk.report() + " verb=" + board.verb() + " | " + board.summary()


func _build_flow() -> void:
	flow = GuildCustomerFlow.new()
	flow.name = "CustomerFlow"
	add_child(flow)
	flow.setup(hall, counter_station, 11)


## Five customers, sent through the door by the queue itself: the lineup capture is
## the same walk the game runs, not five mannequins placed by hand.
func stage_lineup() -> void:
	reset_customers()
	auto_flow = false
	for index in GuildHallZones.queue_length():
		flow.spawn()
	flow.advance(26.0)
	_freeze_line()


## Three customers caught on their way in, so the capture shows the walk.
func stage_customers() -> void:
	reset_customers()
	auto_flow = false
	for style in DEMO_SPAWNS:
		flow.spawn(style)
	flow.advance(3.2)


## Lets the staged queue keep walking for `seconds`.
func advance_customers(seconds: float) -> void:
	if flow != null:
		flow.advance(seconds)


func reset_customers() -> void:
	if flow == null:
		return
	for customer in flow.customers.duplicate():
		customer.free()
	flow.setup(hall, counter_station, 11)


func _freeze_line() -> void:
	for customer in flow.customers:
		customer.rotation.y = 0.0


func flow_report() -> String:
	if flow == null:
		return "flow: none"
	var lines: Array[String] = [flow.report()]
	for customer in flow.customers:
		lines.append("  " + customer.report())
	return "\n".join(lines)


func _build_hud() -> void:
	hud = GuildHud.new()
	add_child(hud)
	hud.bind(interaction, treasury, stock)
	hud.language_changed.connect(_on_language_changed)


func _on_language_changed(language: String) -> void:
	if hall != null:
		hall.set_language(language)
	if flow != null:
		flow.set_language(language)


func _build_camera() -> void:
	camera_rig = GuildPlayerCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	overview()
	if camera_rig.camera != null and _environment != null:
		camera_rig.camera.environment = _environment
		camera_rig.camera.current = true
