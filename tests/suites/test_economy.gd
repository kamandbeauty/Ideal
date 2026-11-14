extends TestCase
## The idle economy: income, upgrades, managers, reputation and offline pay.


func test_new_town_starts_with_one_business() -> void:
	var town := TownState.new("desert")
	equal(town.cash, TownState.STARTING_CASH, "starting cash")
	equal(town.unlocked_ids().size(), 1, "one business at the start")
	check(town.business("gas_station").unlocked, "gas station is open")
	check(town.net_per_minute() > 0.0, "the gas station earns")
	equal(town.reputation, 0.0, "no reputation yet")


func test_advance_credits_the_profit() -> void:
	var town := TownState.new("desert")
	var rate := town.net_per_minute()
	var cash := town.cash
	town.advance(60.0)
	almost(town.cash, cash + rate, "60 s should pay one minute of profit", 0.01)
	check(town.customers > 0.0, "customers should be counted")
	check(town.reputation > 0.0, "reputation should grow")
	town.advance(0.0)
	almost(town.cash, cash + rate, "zero time must not pay", 0.01)


func test_offline_is_capped_at_eight_hours() -> void:
	var town := TownState.new("desert")
	var eight_hours := TownState.OFFLINE_CAP_SECONDS
	almost(
		town.offline_earnings(eight_hours * 3.0),
		town.offline_earnings(eight_hours),
		"offline earnings are capped at eight hours"
	)
	almost(town.offline_earnings(60.0), town.net_per_minute() * TownState.OFFLINE_RATE, "rate")
	equal(town.offline_earnings(0.0), 0.0, "no time away, no money")
	var report := town.apply_offline(eight_hours * 2.0)
	almost(float(report["seconds"]), eight_hours, "the report should be capped")
	check(town.cash > TownState.STARTING_CASH, "offline income should be credited")


func test_upgrades_raise_profit_and_price() -> void:
	var town := TownState.new("desert")
	town.cash = 100000.0
	var before := town.net_per_minute()
	var first := town.business("gas_station").upgrade_cost()
	check(town.upgrade_business("gas_station"), "the upgrade should be affordable")
	check(town.net_per_minute() > before, "level 2 should earn more")
	check(town.upgrade_business("gas_station"), "level 3 should be affordable")
	check(town.business("gas_station").upgrade_cost() > first, "upgrades get more expensive")


func test_capacity_branch_raises_served() -> void:
	var town := TownState.new("desert")
	town.cash = 100000.0
	var business := town.business("gas_station")
	business.level = 3
	var served := business.served_per_minute(town.traffic())
	var before := town.net_per_minute()
	check(town.upgrade_branch("gas_station", "capacity"), "capacity branch should buy")
	check(business.served_per_minute(town.traffic()) > served, "capacity should serve more")
	check(town.net_per_minute() > before, "capacity should earn more")


func test_quality_branch_raises_price() -> void:
	var town := TownState.new("desert")
	town.cash = 100000.0
	town.business("gas_station").level = 2
	var price := town.business("gas_station").price()
	check(town.upgrade_branch("gas_station", "quality"), "quality branch should buy")
	check(town.business("gas_station").price() > price, "quality should raise the price")


func test_manager_raises_efficiency() -> void:
	var town := TownState.new("desert")
	town.cash = 100000.0
	var business := town.business("gas_station")
	equal(business.manager_rank, 0, "no manager to start")
	var before := town.net_per_minute()
	check(town.hire_manager("gas_station"), "the manager should be affordable")
	almost(business.efficiency(), 0.7, "one rank is 70 %", 0.001)
	check(town.net_per_minute() > before, "a manager should earn more")


func test_manager_rank_is_capped() -> void:
	var town := TownState.new("desert")
	town.cash = 100000000.0
	for i in 10:
		town.hire_manager("gas_station")
	equal(town.business("gas_station").manager_rank, BusinessData.MAX_MANAGER, "manager cap")


func test_level_is_capped() -> void:
	var town := TownState.new("desert")
	town.cash = 100000000.0
	for i in 10:
		town.upgrade_business("gas_station")
	equal(town.business("gas_station").level, BusinessData.MAX_LEVEL, "level cap")
	check(not town.business("gas_station").can_upgrade_level(), "cannot upgrade past the cap")


func test_branch_is_capped_by_level() -> void:
	var town := TownState.new("desert")
	town.cash = 100000000.0
	check(town.upgrade_branch("gas_station", "speed"), "level 1 allows one branch step")
	check(not town.upgrade_branch("gas_station", "speed"), "the branch may not pass the level")
	check(town.upgrade_business("gas_station"), "level up")
	check(town.upgrade_branch("gas_station", "speed"), "level 2 allows a second step")


func test_purchases_need_cash() -> void:
	var town := TownState.new("desert")
	town.cash = 10.0
	check(not town.unlock_business("restaurant"), "cannot unlock without cash")
	check(not town.upgrade_business("gas_station"), "cannot upgrade without cash")
	check(not town.hire_manager("gas_station"), "cannot hire without cash")
	equal(town.cash, 10.0, "a failed purchase must not spend")


func test_unlocking_opens_a_business() -> void:
	var town := TownState.new("desert")
	town.cash = 5000.0
	var cash := town.cash
	check(town.unlock_business("store"), "the store should unlock")
	check(town.unlocked_ids().has("store"), "the store should be listed")
	almost(town.cash, cash - BusinessData.unlock_cost("store"), "unlock should be paid", 0.01)
	check(town.net_per_minute() > 0.0, "two businesses earn more")


func test_reputation_pays_gems_once() -> void:
	var town := TownState.new("desert")
	town.reputation = 100.0
	town.advance(1.0)
	equal(town.gems, TownState.GEM_REWARD, "the first milestone pays gems")
	town.advance(1.0)
	equal(town.gems, TownState.GEM_REWARD, "gems are not paid twice")
	equal(town.town_level(), 1, "level from reputation")
	town.reputation = 600.0
	equal(town.town_level(), 3, "600 reputation is level 3")


func test_town_modifiers_apply() -> void:
	var desert := TownState.new("desert")
	var highway := TownState.new("highway")
	check(highway.net_per_minute() > 0.0, "the highway town earns too")
	check(TownData.cost_multiplier("highway") > 1.0, "later towns cost more")
	almost(desert.traffic(), 1.0, "the desert is the baseline")
