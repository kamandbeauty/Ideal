extends TestCase
## The playable guild scene: what it builds, what it boots, and how it saves.

## Loaded at run time, not preloaded: the suite must not drag the scene's whole
## class graph into the test runner's own load.
func _script() -> GDScript:
	return load("res://scripts/guild/game/guild_game.gd") as GDScript


func suite_name() -> String:
	return "guild_game"


func _clear_save() -> void:
	GuildSave.delete()


func _game() -> Node3D:
	TestCase.mark("    game: new")
	var game := _script().new()
	TestCase.mark("    game: build")
	game.build_world()
	TestCase.mark("    game: built")
	return game


func test_the_hall_builds_on_its_own() -> void:
	TestCase.mark("    part hall")
	var game := _script().new()
	game.build_hall()
	TestCase.mark("    part hall done")
	check(game.hall != null, "the hall is there")
	game.free()


func test_the_stations_build_on_their_own() -> void:
	TestCase.mark("    part stations")
	var game := _script().new()
	game.build_stations()
	TestCase.mark("    part stations done")
	check(game.stations.size() == 4, "four stations")
	check(game.counter_station != null, "the counter is remembered")
	game.free()


func test_the_master_builds_on_his_own() -> void:
	TestCase.mark("    part master")
	var game := _script().new()
	game.build_stations()
	game.build_master()
	TestCase.mark("    part master done")
	check(game.hero != null and game.interaction != null, "the master can act")
	game.free()


func test_the_ui_builds_on_its_own() -> void:
	TestCase.mark("    part ui")
	var game := _script().new()
	game.build_stations()
	game.build_master()
	game.build_ui()
	TestCase.mark("    part ui done")
	check(game.hud != null and game.panel != null, "the hud and the sheet are built")
	game.free()


func test_the_camera_builds_on_its_own() -> void:
	TestCase.mark("    part camera")
	var game := _script().new()
	game.build_stations()
	game.build_master()
	game.build_camera()
	TestCase.mark("    part camera done")
	check(game.camera_rig != null, "the camera rig is there")
	game.free()


func test_the_customers_build_on_their_own() -> void:
	TestCase.mark("    part customers")
	var game := _script().new()
	game.build_hall()
	game.build_stations()
	game.build_customers()
	TestCase.mark("    part customers done")
	check(game.flow != null, "the queue exists")
	game.free()


func test_the_world_has_every_station() -> void:
	_clear_save()
	var game := _game()
	var kinds: Array = []
	for station in game.stations:
		kinds.append(int(station.kind))
	equal(kinds.size(), 4, "four stations are placed")
	check(kinds.has(GuildStation.SHELF), "the shelf is there")
	check(kinds.has(GuildStation.COUNTER), "the counter is there")
	check(kinds.has(GuildStation.VAULT), "the vault is there")
	check(kinds.has(GuildStation.BOARD), "the reward board is there")
	equal(game.desk.adventurers.size(), 5, "the roster is hired")
	check(game.hud != null and game.panel != null, "hud and board panel exist")
	check(game.flow != null, "customers have a flow")
	check(game.camera_rig != null and game.camera_rig.camera != null, "the camera exists")
	game.free()


func test_a_new_guild_starts_with_gold_and_goods() -> void:
	_clear_save()
	var game := _game()
	check(not game.boot(), "with no save the guild starts new")
	equal(int(game.treasury.cash), 60, "it starts with 60 gold")
	equal(game.stock.total(), 6, "it starts with six goods")
	equal(game.stock.count("slime_gel"), 4, "four slime gels")
	equal(game.hero.position, _script().STARTING_HERO, "the master stands in the hall")
	check(not game.booted_from_save, "and it says it is a new guild")
	game.free()


func test_a_saved_guild_is_picked_up() -> void:
	_clear_save()
	var builder := _game()
	builder.treasury.cash = 99.0
	builder.stock.clear()
	builder.stock.add("iron_ore", 3)
	builder.desk.dispatch_with(builder.desk.adventurers[0], "gather_herbs")
	var payload := GuildSave.snapshot(builder.treasury, builder.stock, builder.hero.state, builder.desk)
	payload["last_seen"] = Time.get_unix_time_from_system() - 40.0
	check(GuildSave.write(payload), "the save is written")
	builder.free()

	var game := _game()
	check(game.boot(), "the guild boots from the save")
	equal(int(game.treasury.cash), 99, "gold came back")
	equal(game.stock.total(), 3, "stock came back")
	equal(game.stock.count("iron_ore"), 3, "and it is iron ore")
	equal(game.caught_up, 1, "the expedition that was out came home")
	game.free()
	_clear_save()


func test_saving_writes_the_live_values() -> void:
	_clear_save()
	var game := _game()
	game.boot()
	game.treasury.cash = 123.0
	game.stock.add("moon_shard", 2)
	check(game.save_game(), "the game saves")
	var data := GuildSave.read()
	equal(int(data["cash"]), 123, "the cash is in the file")
	equal(int(data["stock"]["moon_shard"]), 2, "the goods are in the file")
	game.free()
	_clear_save()


func test_a_pushed_stick_walks_away_from_the_camera() -> void:
	var ahead := Vector3.BACK.rotated(Vector3.UP, deg_to_rad(_script().forward_yaw(0.0)))
	almost(ahead.z, -1.0, "with the camera behind at yaw 0, forward is -Z")
	ahead = Vector3.BACK.rotated(Vector3.UP, deg_to_rad(_script().forward_yaw(90.0)))
	almost(ahead.x, -1.0, "with the camera turned a quarter, forward turns with it")


func test_the_stick_drives_the_master() -> void:
	_clear_save()
	var game := _game()
	game.boot()
	game.hud.set_stick_input(Vector2(0.0, 1.0))
	equal(game.hud.stick_input(), Vector2(0.0, 1.0), "the stick reaches the master")
	game.hud.set_stick_input(Vector2(4.0, 3.0))
	almost(game.hud.stick_input().length(), 1.0, "a hard push is still a walk, not a sprint")
	game.hud.set_stick_input(Vector2.ZERO)
	equal(game.hud.stick_input(), Vector2.ZERO, "a released stick stands still")
	game.free()


func test_the_clock_feeds_the_queue_and_the_missions() -> void:
	_clear_save()
	var game := _game()
	game.boot()
	game.desk.dispatch_with(game.desk.adventurers[0], "gather_herbs")
	game._customer_left = 0.1
	game._tick_world(0.2)
	equal(game.flow.queue_length(), 1, "a customer walked in")
	equal(game.desk.active_count(), 1, "the expedition is still out")
	game.free()
	_clear_save()


func test_describe_reads_the_live_guild() -> void:
	_clear_save()
	var game := _game()
	game.boot()
	var line: String = game.describe()
	check(line.contains("guild gold=60"), "it reports the gold: " + line)
	check(line.contains("roster=5"), "it reports the roster: " + line)
	check(line.contains("saved=false"), "it reports a new guild: " + line)
	game.free()
