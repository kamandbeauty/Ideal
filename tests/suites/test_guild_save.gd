extends TestCase
## The guild save: what is kept, what is refused, and what time away does.
##
## The save is a plain dictionary with a version, so the whole thing can be tested
## without touching a disk - and the one test that does touch a disk writes, reads
## back and deletes its own file.

const SEED := 31


## A small but complete guild: some gold, some goods, something in the hands, and a
## roster with one member out in the field.
func _guild() -> Dictionary:
	var treasury := GuildTreasury.new()
	treasury.deposit(120.0)
	treasury.add_reputation(2.5)
	var stock := GuildStock.new(20)
	stock.add("slime_gel", 3)
	stock.add("healing_herb", 1)
	var state := GuildPlayerState.new()
	state.hold_items("iron_ore", 2)
	state.load_money(40.0)
	var desk := GuildMissionDesk.new()
	desk.setup(treasury, stock, SEED)
	desk.hire_default_roster()
	desk.adventurers[0].send_out("ore_run")
	desk.adventurers[0].time_left = 12.0
	return {"treasury": treasury, "stock": stock, "state": state, "desk": desk}


func _fresh() -> Dictionary:
	var treasury := GuildTreasury.new()
	var stock := GuildStock.new(40)
	var state := GuildPlayerState.new()
	var desk := GuildMissionDesk.new()
	desk.setup(treasury, stock, SEED)
	return {"treasury": treasury, "stock": stock, "state": state, "desk": desk}


func _snapshot_of(guild: Dictionary) -> Dictionary:
	return GuildSave.snapshot(
			guild["treasury"], guild["stock"], guild["state"], guild["desk"]
	)


func _apply_to(payload: Dictionary, guild: Dictionary) -> bool:
	return GuildSave.apply(
			payload, guild["treasury"], guild["stock"], guild["state"], guild["desk"]
	)


func test_a_snapshot_round_trips() -> void:
	var source := _guild()
	var payload := _snapshot_of(source)
	equal(int(payload["version"]), 1, "the payload is versioned")
	var target := _fresh()
	check(_apply_to(payload, target), "the payload applies")
	var treasury: GuildTreasury = target["treasury"]
	almost(treasury.cash, 120.0, "the vault came back", 0.001)
	almost(treasury.reputation, 2.5, "and the reputation", 0.001)
	var stock: GuildStock = target["stock"]
	equal(stock.count("slime_gel"), 3, "the warehouse came back")
	equal(stock.count("healing_herb"), 1, "with every item")
	equal(stock.capacity, 20, "and its capacity")
	var state: GuildPlayerState = target["state"]
	equal(state.held_of("iron_ore"), 2, "the hands came back")
	almost(state.money, 40.0, "and the coins in them", 0.001)
	equal(target["desk"].adventurers.size(), 5, "the roster came back whole")


func test_the_hands_never_hold_more_than_they_can() -> void:
	var payload := {
		"version": 1,
		"cash": 10.0,
		"reputation": 0.0,
		"capacity": 10,
		"stock": {"slime_gel": 2},
		"hands": {"slime_gel": 99},
		"money": 99999.0,
		"roster": [],
	}
	var target := _fresh()
	check(_apply_to(payload, target), "a greedy payload still applies")
	var state: GuildPlayerState = target["state"]
	check(state.carry <= state.carry_capacity, "but the hands are capped")
	check(state.money <= state.money_capacity, "and so is the pouch")


func test_a_wrong_version_is_refused() -> void:
	var target := _fresh()
	var before := (target["treasury"] as GuildTreasury).cash
	var payload := _snapshot_of(_guild())
	payload["version"] = 2
	check(not _apply_to(payload, target), "version 2 is not read as version 1")
	almost((target["treasury"] as GuildTreasury).cash, before, "and nothing was applied", 0.001)
	check(not _apply_to({}, target), "an empty payload is refused too")


func test_a_mission_in_flight_keeps_its_clock() -> void:
	var payload := _snapshot_of(_guild())
	var target := _fresh()
	check(_apply_to(payload, target), "the payload applies")
	var desk: GuildMissionDesk = target["desk"]
	equal(desk.active_count(), 1, "one member is still out")
	var away_member: GuildAdventurer = null
	for adventurer in desk.adventurers:
		if adventurer.is_away():
			away_member = adventurer
	check(away_member != null, "and it is the same member")
	if away_member == null:
		return
	equal(away_member.mission_id, "ore_run", "on the same mission")
	almost(away_member.time_left, 12.0, "with the clock it had left", 0.001)
	desk.tick(13.0)
	equal(desk.waiting_count(), 1, "and it comes home when that clock runs out")


func test_time_away_finishes_the_expedition() -> void:
	var source := _guild()
	var payload := _snapshot_of(source)
	payload["last_seen"] = int(Time.get_unix_time_from_system()) - 120
	almost(GuildSave.away_seconds(payload), 120.0, "the payload knows how long it was away", 2.0)
	var target := _fresh()
	check(_apply_to(payload, target), "the payload applies")
	var desk: GuildMissionDesk = target["desk"]
	equal(desk.active_count(), 1, "the member is out when the file was written")
	var finished := GuildSave.catch_up(desk, GuildSave.away_seconds(payload))
	equal(finished, 1, "the expedition finished while the game was closed")
	check(desk.carrier() != null, "and the pack is waiting on the board")


func test_a_month_away_is_not_a_month_of_loot() -> void:
	var payload := {"version": 1, "last_seen": int(Time.get_unix_time_from_system()) - 4000000}
	almost(GuildSave.away_seconds(payload), GuildSave.MAX_AWAY, "time away is capped", 0.5)


func test_the_file_round_trips_on_disk() -> void:
	var source := _guild()
	var payload := _snapshot_of(source)
	check(GuildSave.write(payload), "the save is written")
	check(GuildSave.has_save(), "and found again")
	var read_back := GuildSave.read()
	equal(int(read_back.get("version", 0)), 1, "the file has a version")
	var target := _fresh()
	check(_apply_to(read_back, target), "and it applies after a round trip through JSON")
	almost((target["treasury"] as GuildTreasury).cash, 120.0, "with the vault intact", 0.001)
	equal((target["stock"] as GuildStock).count("slime_gel"), 3, "and the warehouse intact")
	GuildSave.delete()
	check(not GuildSave.has_save(), "and the file can be deleted cleanly")


func test_the_roster_keeps_its_order_and_its_states() -> void:
	var source := _guild()
	var desk_source: GuildMissionDesk = source["desk"]
	desk_source.tick(13.0)
	var payload := _snapshot_of(source)
	var target := _fresh()
	check(_apply_to(payload, target), "the payload applies")
	var desk: GuildMissionDesk = target["desk"]
	var classes: Array[String] = []
	for adventurer in desk.adventurers:
		classes.append(adventurer.class_id)
	equal(classes, Array(["warrior", "archer", "mage", "rogue", "knight"]), "the roster keeps its order")
	var back := desk.carrier()
	check(back != null, "whoever came home still has a pack")
	if back != null:
		check(not back.loot.is_empty(), "with the loot that was rolled")
		check(desk.report().contains("back=1"), "and the desk reports it")
