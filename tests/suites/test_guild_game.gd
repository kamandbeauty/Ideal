extends TestCase
## The playable guild scene: what it builds, what it boots, and how it saves.

const GuildGameScript := preload("res://scripts/guild/game/guild_game.gd")


func suite_name() -> String:
	return "guild_game"


func _clear_save() -> void:
	GuildSave.delete()


func _game() -> Node3D:
	var game := GuildGameScript.new()
	game.build_world()
	return game


func test_the_world_has_every_station() -> void:
	print("GAME: test_the_world_has_every_station")
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
	print("GAME: test_a_new_guild_starts_with_gold_and_goods")
	_clear_save()
	var game := _game()
	check(not game.boot(), "with no save the guild starts new")
	equal(int(game.treasury.cash), 60, "it starts with 60 gold")
	equal(game.stock.total(), 6, "it starts with six goods")
	equal(game.stock.count("slime_gel"), 4, "four slime gels")
	equal(game.hero.position, GuildGameScript.STARTING_HERO, "the master stands in the hall")
	check(not game.booted_from_save, "and it says it is a new guild")
	game.free()


func test_a_saved_guild_is_picked_up() -> void:
	print("GAME: test_a_saved_guild_is_picked_up")
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
	print("GAME: test_saving_writes_the_live_values")
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
	print("GAME: test_a_pushed_stick_walks_away_from_the_camera")
	var ahead := Vector3.BACK.rotated(Vector3.UP, deg_to_rad(GuildGameScript.forward_yaw(0.0)))
	almost(ahead.z, -1.0, "with the camera behind at yaw 0, forward is -Z")
	ahead = Vector3.BACK.rotated(Vector3.UP, deg_to_rad(GuildGameScript.forward_yaw(90.0)))
	almost(ahead.x, -1.0, "with the camera turned a quarter, forward turns with it")


func test_the_stick_drives_the_master() -> void:
	print("GAME: test_the_stick_drives_the_master")
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
	print("GAME: test_the_clock_feeds_the_queue_and_the_missions")
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
	print("GAME: test_describe_reads_the_live_guild")
	_clear_save()
	var game := _game()
	game.boot()
	var line: String = game.describe()
	check(line.contains("guild gold=60"), "it reports the gold: " + line)
	check(line.contains("roster=5"), "it reports the roster: " + line)
	check(line.contains("saved=false"), "it reports a new guild: " + line)
	game.free()
