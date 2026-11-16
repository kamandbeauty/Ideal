extends TestCase
## The mission board: the roster, the fee, the clock, the loot and the purchase.
##
## These run without a scene tree because the desk and the adventurers are plain
## objects on purpose - the money and the timers are the part that must never be
## wrong, and they can be proven without a renderer. The board's painted rigs are
## checked by the play-through captures.

const SEED := 31


func _desk(cash: float = 200.0, capacity: int = 40) -> Array:
	var treasury := GuildTreasury.new()
	treasury.deposit(cash)
	var stock := GuildStock.new(capacity)
	var desk := GuildMissionDesk.new()
	desk.setup(treasury, stock, SEED)
	desk.hire_default_roster()
	return [desk, treasury, stock]


func _advance(desk: GuildMissionDesk, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(0.25, left)
		desk.tick(step)
		left -= step


func test_every_mission_is_well_formed() -> void:
	var ids := GuildMissions.ids()
	check(ids.size() >= 4, "the board offers several missions")
	for id in ids:
		var data := GuildMissions.mission(id)
		check(GuildLocale.has_key(GuildMissions.name_key(id)), "the mission has a name: " + id)
		not_equal(
			GuildLocale.text(GuildMissions.name_key(id), "fa"),
			GuildLocale.text(GuildMissions.name_key(id), "en"),
			"and it is translated: " + id
		)
		check(float(data["duration"]) > 0.0, "the mission takes time: " + id)
		check(float(data["fee"]) > 0.0, "the mission costs a fee: " + id)
		check(GuildMissions.RANKS.has(str(data["rank"])), "the mission has a rank: " + id)
		var loot: Array = data["loot"]
		check(not loot.is_empty(), "the mission can return something: " + id)
		for entry in loot:
			var row := entry as Dictionary
			check(GuildItems.exists(str(row["item"])), "loot names a real item in " + id)
			check(int(row["min"]) >= 1 and int(row["max"]) >= int(row["min"]), "loot counts make sense in " + id)
			check(float(row["chance"]) > 0.0 and float(row["chance"]) <= 1.0, "loot chance is a probability in " + id)


func test_rank_gates_the_hard_missions() -> void:
	check(not GuildMissions.fits_rank("F", "relic_dig"), "a green recruit cannot take a dig")
	check(GuildMissions.fits_rank("D", "relic_dig"), "a rogue can")
	check(GuildMissions.fits_rank("S", "gather_herbs"), "anyone can gather herbs")
	check(not GuildMissions.fits_rank("F", "no_such_mission"), "an unknown mission fits nobody")
	var parts := _desk()
	var desk: GuildMissionDesk = parts[0]
	var warrior := desk.adventurers[0]
	check(warrior.can_take("gather_herbs"), "the F-rank warrior takes the small job")
	check(not warrior.can_take("relic_dig"), "and not the big one")


func test_a_dispatch_pays_the_fee_and_starts_the_clock() -> void:
	var parts := _desk(100.0)
	var desk: GuildMissionDesk = parts[0]
	var treasury: GuildTreasury = parts[1]
	var result := desk.dispatch()
	equal(str(result["reason"]), "", "the dispatch succeeds")
	equal(str(result["mission_id"]), "gather_herbs", "the cheapest job goes first")
	almost(treasury.cash, 100.0 - 8.0, "the fee left the vault", 0.001)
	equal(desk.active_count(), 1, "one adventurer is out")
	equal(desk.idle_count(), 4, "the rest are still by the board")
	for adventurer in desk.adventurers:
		if adventurer.is_away():
			check(adventurer.time_left > 0.0, "the clock is running")
			equal(adventurer.mission_id, "gather_herbs", "and the mission is the one that was paid for")


func test_without_gold_nobody_leaves() -> void:
	var parts := _desk(3.0)
	var desk: GuildMissionDesk = parts[0]
	var treasury: GuildTreasury = parts[1]
	var result := desk.dispatch()
	equal(str(result["reason"]), "no gold", "the dispatch is refused")
	equal(desk.active_count(), 0, "nobody left")
	almost(treasury.cash, 3.0, "and nothing was taken", 0.001)


func test_a_returning_adventurer_brings_real_loot() -> void:
	var parts := _desk(100.0)
	var desk: GuildMissionDesk = parts[0]
	var treasury: GuildTreasury = parts[1]
	desk.dispatch()
	var reputation_before := treasury.reputation
	_advance(desk, 30.0)
	equal(desk.waiting_count(), 1, "one adventurer is back with a pack")
	equal(desk.active_count(), 0, "and nobody is still out")
	var carrier := desk.carrier()
	check(carrier != null, "the pack has an owner")
	if carrier == null:
		return
	check(not carrier.loot.is_empty(), "the pack is not empty")
	for id in carrier.loot:
		check(GuildItems.exists(str(id)), "the loot is a real item: " + str(id))
		check(int(carrier.loot[id]) >= 1, "in a positive amount: " + str(id))
	check(treasury.reputation > reputation_before, "coming home earns reputation")


func test_buying_the_pack_pays_once_and_fills_the_warehouse() -> void:
	var parts := _desk(100.0)
	var desk: GuildMissionDesk = parts[0]
	var treasury: GuildTreasury = parts[1]
	var stock: GuildStock = parts[2]
	desk.dispatch()
	_advance(desk, 30.0)
	var carrier := desk.carrier()
	if carrier == null:
		fail("no adventurer came back, so the purchase cannot be tested")
		return
	var pack := carrier.loot.duplicate()
	var price := GuildMissions.value_of(pack)
	var count := GuildMissions.item_count(pack)
	var cash_before := treasury.cash
	var stock_before := stock.total()
	var result := desk.buy()
	equal(str(result["reason"]), "", "the purchase succeeds")
	almost(treasury.cash, cash_before - price, "the vault paid the buy price", 0.001)
	equal(stock.total(), stock_before + count, "the warehouse gained exactly the pack")
	equal(desk.carrier(), null, "the pack is now the guild's")
	var again := desk.buy()
	equal(str(again["reason"]), "nothing to buy", "and it cannot be bought twice")
	almost(treasury.cash, cash_before - price, "so no gold moves again", 0.001)


func test_a_full_warehouse_refuses_the_purchase() -> void:
	var parts := _desk(100.0, 1)
	var desk: GuildMissionDesk = parts[0]
	var treasury: GuildTreasury = parts[1]
	var stock: GuildStock = parts[2]
	stock.add("slime_gel", 1)
	desk.dispatch()
	_advance(desk, 30.0)
	var cash_before := treasury.cash
	var result := desk.buy()
	equal(str(result["reason"]), "warehouse full", "the purchase is refused")
	almost(treasury.cash, cash_before, "and no gold was spent", 0.001)
	check(desk.carrier() != null, "the pack is still waiting")


func test_the_roll_is_repeatable_and_reported() -> void:
	var first_parts := _desk(100.0)
	var second_parts := _desk(100.0)
	var first: GuildMissionDesk = first_parts[0]
	var second: GuildMissionDesk = second_parts[0]
	first.dispatch()
	second.dispatch()
	_advance(first, 30.0)
	_advance(second, 30.0)
	var first_pack: Dictionary = first.carrier().loot if first.carrier() != null else {}
	var second_pack: Dictionary = second.carrier().loot if second.carrier() != null else {}
	equal(first_pack, second_pack, "the same seed returns the same loot")
	var line := first.report()
	check(line.contains("roster=5"), "the report counts the roster")
	check(line.contains("out=0"), "and who is out")
	check(line.contains("back=1"), "and who came back")
