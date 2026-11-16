class_name GuildProbe
extends Node3D
## A photographed slice of the guild: the hall with its nine zones, the five
## customer classes, the player carrying goods, and the navigation mesh the
## customers will walk on. CI captures it, so the look and the layout are never
## assumed.
##
## This is a probe, not the game: it has no orders, no economy and no mission
## loop yet. It exists to prove the hall, the rig and the pathfinding together.

const CAST: Array[String] = ["warrior", "mage", "archer", "rogue", "knight"]
const DEMO_HERO_SPOT := Vector3(1.0, 0.05, 3.2)

var hall: GuildHall
var hero: GuildPlayer
var stations: Array = []
var stock: GuildStock
var treasury: GuildTreasury
var last_result: Dictionary = {}
var camera_rig: GuildPlayerCamera
var cast: Array[GuildCharacter] = []

var follow_hero := false
var _pending: Dictionary = {}
var _pose := "idle"
var _speed := 0.0
var _environment: Environment


func _ready() -> void:
	_build_environment()
	_build_hall()
	_build_cast()
	_build_trade()
	_build_camera()
	hero.state.verb_finished.connect(_on_verb_finished)
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
	if camera_rig == null:
		return
	camera_rig.distance = GuildPlayerCamera.MAX_DISTANCE
	camera_rig.pitch = 46.0
	camera_rig.yaw = 18.0
	if camera_rig.camera != null:
		camera_rig.camera.fov = 52.0
	camera_rig.focus_on(Vector3(0.0, 1.4, 0.4))


## A one-line health check of the rig, mirrored into the CI log.
func describe() -> String:
	var meshes := hero.character.find_children("*", "MeshInstance3D", true, false)
	var shown := 0
	for mesh in meshes:
		if (mesh as MeshInstance3D).is_visible_in_tree():
			shown += 1
	return "hero_parts=%d hero_meshes=%d hero_visible=%d hero_pos=%s cast=%d stack=%d zone=%s" % [
		hero.character.parts.size(),
		meshes.size(),
		shown,
		str(hero.global_position),
		cast.size(),
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
## lands when the verb finishes, so a pickup cannot happen mid-air.
func press_action() -> Dictionary:
	var station := station_at_hero()
	if station == null:
		last_result = {"reason": "nothing near"}
		return last_result
	var verb := station.verb()
	if not hero.interact(verb):
		last_result = {"reason": "busy"}
		return last_result
	_pending = {"verb": verb, "station": station}
	last_result = {"verb": verb, "station": station.kind, "started": true}
	return last_result


func _on_verb_finished(verb: String) -> void:
	if _pending.is_empty() or str(_pending["verb"]) != verb:
		return
	var station: GuildStation = _pending["station"]
	_pending = {}
	match verb:
		"pickup":
			last_result = GuildTrade.pick(hero.state, station.stock, 3, waiting_item())
		"deliver":
			last_result = GuildTrade.deliver(hero.state, station.order)
		"deposit":
			last_result = GuildTrade.deposit(hero.state, station.treasury)
		_:
			last_result = {"reason": "unknown verb"}


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
	_environment.ambient_light_energy = 0.5
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.18, 0.16, 0.3)
	_environment.fog_density = 0.008


func _build_hall() -> void:
	hall = GuildHall.new()
	hall.name = "GuildHall"
	add_child(hall)


func _build_cast() -> void:
	hero = GuildPlayer.new()
	hero.position = DEMO_HERO_SPOT
	hero.rotation.y = deg_to_rad(6.0)
	add_child(hero)

	var queue_spot := GuildHallZones.spawn("customer_queue")
	for index in CAST.size():
		var style := CAST[index]
		var member := GuildCharacter.new(style, true)
		member.name = "Cast_" + style
		member.position = Vector3(queue_spot.x - 2.6 + index * 1.4, 0.0, queue_spot.z + 1.4)
		member.rotation.y = deg_to_rad(-8.0 + index * 4.0)
		add_child(member)
		cast.append(member)
		member.animate(0.016, 0.0, "idle")
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
	counter.set_customer(GuildCharacter.new("mage", true))

	var vault := GuildStation.new(GuildStation.VAULT)
	vault.name = "Vault"
	vault.position = Vector3(9.6, 0.0, 2.6)
	add_child(vault)
	vault.bind_treasury(treasury)

	stations = [shelf, counter, vault]


func _build_camera() -> void:
	camera_rig = GuildPlayerCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	overview()
	if camera_rig.camera != null and _environment != null:
		camera_rig.camera.environment = _environment
		camera_rig.camera.current = true
