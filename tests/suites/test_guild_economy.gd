extends TestCase
## The carrying loop's arithmetic: goods on a shelf, an order on a counter, coins
## in the hands and a vault. If gold can appear from anywhere else, this suite is
## where it shows up.


func test_the_catalogue_is_honest() -> void:
	var ids := GuildItems.ids()
	equal(ids.size(), 5, "five goods in the catalogue")
	for id in ids:
		check(GuildItems.has_positive_margin(id), "selling beats buying for " + id)
		check(GuildItems.sell_price(id) > 0.0, "a price for " + id)
		var key := GuildItems.name_key(id)
		check(GuildLocale.has_key(key), "English name for " + key)
		check(not GuildLocale.missing_overrides().has(key), "Persian name for " + key)
	equal(GuildItems.buy_price("slime_gel"), 10.0, "slime gel buys at 10")
	equal(GuildItems.sell_price("slime_gel"), 18.0, "and sells at 18")
	equal(GuildItems.margin("slime_gel"), 8.0, "margin is the difference")
	check(not GuildItems.has_positive_margin("no_such_item"), "unknown items earn nothing")


func test_loot_rolls_cover_the_table() -> void:
	var seen := {}
	for step in 20:
		var id := GuildItems.roll_loot(step / 20.0)
		check(GuildItems.exists(id), "rolls land on a real item")
		seen[id] = true
	equal(seen.size(), 5, "a full sweep reaches every item")
	equal(GuildItems.roll_loot(0.0), "slime_gel", "the cheapest loot is the most common")
	equal(GuildItems.roll_loot(0.999), "ancient_coin", "the rarest is at the end of the table")


func test_stock_counts_and_capacity() -> void:
	var stock := GuildStock.new(10)
	check(stock.is_empty(), "a new shelf is empty")
	equal(stock.add("slime_gel", 4), 4, "four parcels go on the shelf")
	equal(stock.count("slime_gel"), 4, "and are counted")
	equal(stock.add("slime_gel", 9), 6, "the shelf stops at its capacity")
	equal(stock.total(), 10, "ten parcels in total")
	equal(stock.space(), 0, "no room left")
	equal(stock.add("no_such_item", 1), 0, "unknown goods are refused")
	equal(stock.take("slime_gel", 3), 3, "three come off")
	equal(stock.total(), 7, "seven left")
	equal(stock.take("slime_gel", 99), 7, "talking more than there is takes what is left")
	check(stock.is_empty(), "an emptied shelf is empty")
	equal(stock.take("slime_gel", 1), 0, "and gives nothing more")


func test_stock_value_and_first_item() -> void:
	var stock := GuildStock.new(10)
	stock.add("iron_ore", 2)
	stock.add("moon_shard", 1)
	equal(stock.first_item(), "iron_ore", "the player grabs the first item in the catalogue")
	equal(stock.value(), 2.0 * 9.0 + 95.0, "the shelf is worth what it sells for")
	stock.take("iron_ore", 2)
	equal(stock.first_item(), "moon_shard", "and moves on when that pile is gone")


func test_an_order_pays_once() -> void:
	var order := GuildOrder.new("slime_gel", 2)
	equal(order.payment, 36.0, "two gels at 18")
	check(order.is_ready(), "a new order waits for goods")
	check(order.fits({"slime_gel": 2}), "two in hand fill it")
	check(not order.fits({"slime_gel": 1}), "one does not")
	check(not order.fits({"iron_ore": 5}), "the wrong goods do not")
	equal(order.settle(), 36.0, "settling pays the order")
	check(not order.is_ready(), "and closes it")
	equal(order.settle(), 0.0, "a closed order never pays again")


func test_picking_up_never_exceeds_the_hands() -> void:
	var state := GuildPlayerState.new()
	state.carry_capacity = 5
	var stock := GuildStock.new(20)
	stock.add("healing_herb", 8)
	var first := GuildTrade.pick(state, stock, 3)
	equal(int(first["taken"]), 3, "three herbs picked up")
	equal(first["item"], "healing_herb", "the right item")
	equal(state.carry, 3, "the hands hold three")
	equal(state.held_of("healing_herb"), 3, "as herbs, not as anonymous cargo")
	var second := GuildTrade.pick(state, stock, 4)
	equal(int(second["taken"]), 2, "only two more fit")
	equal(state.carry, 5, "the hands are full")
	var third := GuildTrade.pick(state, stock, 1)
	equal(int(third["taken"]), 0, "a full pair of hands takes nothing")
	equal(third["reason"], "hands full", "and says why")
	equal(stock.total(), 3, "the shelf lost exactly what was carried")


func test_an_empty_shelf_gives_nothing() -> void:
	var state := GuildPlayerState.new()
	var stock := GuildStock.new(10)
	var result := GuildTrade.pick(state, stock, 2)
	equal(int(result["taken"]), 0, "nothing to pick")
	equal(result["reason"], "empty shelf", "and it says so")
	equal(state.carry, 0, "the hands stay empty")


func test_the_full_loop_pays_the_margin() -> void:
	var state := GuildPlayerState.new()
	state.carry_capacity = 6
	state.money_capacity = 500.0
	var treasury := GuildTreasury.new()
	var stock := GuildStock.new(30)
	var shelf_cost := 4.0 * GuildItems.buy_price("slime_gel")
	stock.add("slime_gel", 4)
	var order := GuildOrder.new("slime_gel", 3)

	equal(treasury.cash, 0.0, "the vault starts empty")
	equal(int(GuildTrade.pick(state, stock, 4)["taken"]), 4, "carry four gels")
	var paid := GuildTrade.deliver(state, order)
	equal(float(paid["amount"]), 54.0, "three sold at 18 = 54 coins in the hands")
	equal(state.carry, 1, "one gel is still in the hands")
	equal(state.money, 54.0, "the coins are carried, not banked")
	equal(treasury.cash, 0.0, "the vault is still empty until the walk")

	var repeat := GuildTrade.deliver(state, order)
	equal(float(repeat["amount"]), 0.0, "the same order cannot pay twice")
	equal(state.money, 54.0, "and the pouch did not grow")

	var deposited := GuildTrade.deposit(state, treasury)
	equal(float(deposited["amount"]), 54.0, "all the coins go into the vault")
	equal(treasury.cash, 54.0, "the vault holds them")
	equal(state.money, 0.0, "and the hands are empty")
	almost(treasury.cash - shelf_cost, 14.0, "the guild kept the margin on what it bought")
	almost(treasury.reputation, 2.7, "reputation follows real trade")


func test_deliveries_need_the_goods_and_a_pouch_with_room() -> void:
	var state := GuildPlayerState.new()
	state.money_capacity = 20.0
	var order := GuildOrder.new("moon_shard", 1)
	equal(float(GuildTrade.deliver(state, order)["amount"]), 0.0, "empty hands cannot deliver")
	equal(GuildTrade.deliver(state, order)["reason"], "not enough goods", "and it says why")
	state.hold_items("moon_shard", 1)
	var pouch := GuildTrade.deliver(state, order)
	equal(float(pouch["amount"]), 0.0, "a 95 coin order needs a pouch that holds 95")
	equal(pouch["reason"], "pouch full", "and it says why")
	equal(state.held_of("moon_shard"), 1, "the goods stay in the hands")
	state.money_capacity = 200.0
	equal(float(GuildTrade.deliver(state, order)["amount"]), 95.0, "with room, the sale goes through")


func test_depositing_nothing_does_nothing() -> void:
	var state := GuildPlayerState.new()
	var treasury := GuildTreasury.new()
	var result := GuildTrade.deposit(state, treasury)
	equal(float(result["amount"]), 0.0, "no coins, no deposit")
	equal(result["reason"], "no coins", "and it says why")
	check(treasury.spend(10.0) == false, "an empty vault cannot buy anything")
	treasury.deposit(25.0)
	check(treasury.spend(10.0), "a funded vault can")
	equal(treasury.cash, 15.0, "and keeps the rest")


func test_stations_say_what_they_are() -> void:
	var shelf := GuildStation.new(GuildStation.SHELF)
	shelf.bind_stock(GuildStock.new(20))
	shelf.stock.add("slime_gel", 5)
	equal(shelf.verb(), "pickup", "a shelf is picked up from")
	equal(shelf.prompt(), "Pick up", "with an English prompt")
	equal(shelf.summary(), "stock 5", "and its real stock")
	equal(int(shelf.get_meta("drawn_parcels", 0)), 5, "five parcels are drawn for five items")

	var counter := GuildStation.new(GuildStation.COUNTER)
	counter.bind_order(GuildOrder.new("slime_gel", 2))
	equal(counter.verb(), "deliver", "a counter is delivered to")
	check(counter.summary().contains("2 x Slime Gel"), "the order is readable: " + counter.summary())

	var vault := GuildStation.new(GuildStation.VAULT)
	var treasury := GuildTreasury.new()
	treasury.deposit(240.0)
	vault.bind_treasury(treasury)
	equal(vault.verb(), "deposit", "a vault is deposited into")
	equal(int(vault.get_meta("drawn_coins", 0)), 4, "240 gold draws four coin stacks")
	check(vault.summary().contains("240"), "the vault reports its gold")

	equal(GuildStation.nearest([shelf, counter, vault], Vector3.ZERO, 2.4), shelf, "the nearest station wins")
	equal(GuildStation.nearest([shelf, counter, vault], Vector3(400.0, 0.0, 0.0), 2.4), null, "out of range is nothing")
	shelf.free()
	counter.free()
	vault.free()
