extends TestCase
## Managers spending the takings on their own business, without eating the cash
## reserve the player is saving for something big.


func _managed_town(cash: float) -> TownState:
	var town := TownState.new("desert")
	town.cash = 50000.0
	town.upgrade_business("gas_station")
	town.hire_manager("gas_station")
	town.cash = cash
	return town


func test_a_business_without_a_manager_never_upgrades_itself() -> void:
	var town := TownState.new("desert")
	town.cash = 50000.0
	check(AutoUpgrade.candidates(town).is_empty(), "nothing to consider without a manager")
	check(AutoUpgrade.apply(town).is_empty(), "and nothing gets bought")
	equal(town.business("gas_station").level, 1, "the level is untouched")


func test_the_cheapest_upgrade_goes_first() -> void:
	var town := _managed_town(50000.0)
	var options := AutoUpgrade.candidates(town)
	check(options.size() >= 2, "a managed business has several options")
	var cheapest := float(options[0]["cost"])
	for option in options:
		check(float(option["cost"]) >= cheapest, "the list is sorted by price")
	var step := AutoUpgrade.apply(town)
	check(not step.is_empty(), "the manager buys something")
	check(float(step["cost"]) <= cheapest, "and it is the cheapest option")
	check(town.cash < 50000.0, "the cash went down")


func test_the_reserve_is_never_spent() -> void:
	var town := _managed_town(0.0)
	var options := AutoUpgrade.candidates(town)
	var cheapest := float(options[0]["cost"])
	var reserve := AutoUpgrade.reserve(town)
	town.cash = reserve + cheapest - 1.0
	check(AutoUpgrade.next_step(town).is_empty(), "spending it would break the reserve")
	check(AutoUpgrade.apply(town).is_empty(), "so nothing is bought")
	town.cash = reserve + cheapest + 1.0
	check(not AutoUpgrade.next_step(town).is_empty(), "one coin more and it is affordable")


func test_the_reserve_grows_with_income() -> void:
	var poor := TownState.new("desert")
	poor.cash = 0.0
	var rich := TownState.new("desert")
	rich.cash = 500000.0
	for id in rich.business_ids():
		rich.unlock_business(id)
		for i in 4:
			rich.upgrade_business(id)
	rich.cash = 0.0
	check(
		AutoUpgrade.reserve(rich) > AutoUpgrade.reserve(poor),
		"a busier town keeps a bigger cushion"
	)
	check(AutoUpgrade.reserve(poor) >= AutoUpgrade.RESERVE_FLOOR, "with a floor underneath")


func test_a_finished_business_is_left_alone() -> void:
	var town := _managed_town(1.0e15)
	var business := town.business("gas_station")
	while business.can_upgrade_level() and town.upgrade_business("gas_station", 10):
		pass
	for branch in BusinessData.BRANCHES:
		while business.can_upgrade_branch(branch) and town.upgrade_branch("gas_station", branch):
			pass
	while business.can_hire_manager() and town.hire_manager("gas_station"):
		pass
	for option in AutoUpgrade.candidates(town):
		check(String(option["id"]) != "gas_station", "a maxed business has nothing to buy")
	check(AutoUpgrade.apply(town).is_empty(), "so the manager stops spending")
