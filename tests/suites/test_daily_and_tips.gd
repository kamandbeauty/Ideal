extends TestCase
## Daily streak chest, tap-to-serve bonus tips and next-goal helper.


func test_the_streak_multiplier_is_capped() -> void:
	almost(DailyBonus.multiplier(1), 1.0, "day one pays base")
	almost(DailyBonus.multiplier(3), 1.7, "day three pays +70%")
	almost(DailyBonus.multiplier(7), 3.1, "day seven pays 3.1x")
	almost(DailyBonus.multiplier(30), 3.1, "multiplier caps at 7 days")


func test_a_tip_pays_once_per_cooldown() -> void:
	var town := TownState.new("desert")
	town.cash = 1000.0
	var first := town.collect_tip("gas_station")
	check(first > 0.0, "open station pays a tip")
	almost(town.cash, 1000.0 + first, "tip lands in wallet")
	almost(town.collect_tip("gas_station"), 0.0, "second tap inside cooldown pays nothing")
	town.advance(TownState.TIP_COOLDOWN)
	check(town.collect_tip("gas_station") > 0.0, "tip comes back after cooldown")


func test_locked_businesses_pay_no_tips() -> void:
	var town := TownState.new("desert")
	almost(town.collect_tip("motel"), 0.0, "closed facility pays nothing")
	almost(town.collect_tip("no_such_business"), 0.0, "unknown id pays nothing")


func test_the_next_goal_is_car_wash_then_auto_service() -> void:
	var town := TownState.new("desert")
	town.cash = 100000.0
	var first := town.next_locked()
	check(not first.is_empty(), "next goal exists")
	equal(str(first["id"]), "car_wash", "Car Wash ($300) is the first derelict lot to restore")
	town.unlock_business("car_wash")
	var second := town.next_locked()
	equal(str(second["id"]), "auto_service", "Auto Service ($1,200) is next")
	check(float(second["price"]) > float(first["price"]), "goals rise in price")
