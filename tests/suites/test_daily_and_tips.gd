extends TestCase
## The two "come back" systems: the daily chest curve and the tap-to-serve tip.
## Both must be generous, bounded and impossible to farm.


func test_the_streak_multiplier_is_capped() -> void:
	almost(DailyBonus.multiplier(1), 1.0, "day one pays the base")
	almost(DailyBonus.multiplier(3), 1.7, "day three pays 70 % more")
	almost(DailyBonus.multiplier(7), 3.1, "day seven pays 3.1x")
	almost(DailyBonus.multiplier(30), 3.1, "the multiplier stops at the cap")


func test_the_chest_scales_with_the_town() -> void:
	var small := DailyBonus.cash(60.0, 1)
	var large := DailyBonus.cash(600.0, 1)
	check(large > small * 5.0, "a richer town opens a richer chest")
	check(DailyBonus.cash(0.0, 1) > 0.0, "a brand-new town still gets a chest")


func test_gems_arrive_on_the_third_day() -> void:
	equal(DailyBonus.gems(1), 0, "no gem on day one")
	equal(DailyBonus.gems(3), 1, "a gem on day three")
	equal(DailyBonus.gems(6), 1, "a gem on day six")


func test_the_streak_only_grows_one_day_at_a_time() -> void:
	equal(DailyBonus.next_streak(-1, 0, 30), 1, "the first day starts at one")
	equal(DailyBonus.next_streak(30, 4, 31), 5, "yesterday's streak continues")
	equal(DailyBonus.next_streak(30, 4, 33), 1, "a missed day resets it")
	equal(DailyBonus.next_streak(30, 9, 31), DailyBonus.MAX_STREAK, "it never exceeds the cap")
	equal(DailyBonus.next_streak(31, 4, 31), 4, "opening twice changes nothing")


func test_a_tip_pays_once_per_cooldown() -> void:
	var town := TownState.new("desert")
	town.cash = 1000.0
	var first := town.collect_tip("gas_station")
	check(first > 0.0, "an open business pays a tip")
	almost(town.cash, 1000.0 + first, "the tip lands in the cash")
	almost(town.collect_tip("gas_station"), 0.0, "a second tap inside the cooldown pays nothing")
	check(not town.tip_ready("gas_station"), "the cooldown is reported")

	town.advance(TownState.TIP_COOLDOWN * 0.5)
	almost(town.collect_tip("gas_station"), 0.0, "half a cooldown is not enough")
	town.advance(TownState.TIP_COOLDOWN)
	check(town.collect_tip("gas_station") > 0.0, "the tip comes back after the cooldown")


func test_locked_businesses_pay_no_tips() -> void:
	var town := TownState.new("desert")
	town.cash = 5000.0
	almost(town.collect_tip("motel"), 0.0, "a closed business pays nothing")
	almost(town.collect_tip("no_such_business"), 0.0, "an unknown id pays nothing")


func test_a_tip_is_worth_a_few_seconds_not_a_fortune() -> void:
	var town := TownState.new("desert")
	town.business("gas_station").manager_rank = 4
	var per_second: float = town.business("gas_station").net_per_second(town.traffic())
	var tip := town.collect_tip("gas_station")
	check(tip <= per_second * TownState.TIP_SECONDS + 0.001, "a tip never beats three seconds")
	check(tip < town.net_per_minute() * 0.25, "tapping cannot replace the economy")


func test_the_next_goal_is_the_cheapest_closed_business() -> void:
	var town := TownState.new("desert")
	town.cash = 100000.0
	var first := town.next_locked()
	check(not first.is_empty(), "there is always a next goal")
	equal(str(first["id"]), "store", "the store is the cheapest gap")
	town.unlock_business("store")
	var next := town.next_locked()
	equal(str(next["id"]), "restaurant", "the next gap is the restaurant")
	check(float(next["price"]) > float(first["price"]), "the goals get more expensive")
