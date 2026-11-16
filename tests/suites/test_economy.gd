extends TestCase
## Roadside Empire idle economy: station vaults, manager automation, renovation
## milestones, star levels, branches and offline earnings.


func test_new_town_starts_with_gas_station() -> void:
	var town := TownState.new("desert")
	equal(town.cash, TownState.STARTING_CASH, "starting cash")
	equal(town.unlocked_ids().size(), 1, "one facility at the start")
	check(town.business("gas_station").unlocked, "gas station is open")
	check(town.net_per_minute() > 0.0, "the gas station earns")
	equal(town.star_level(), 1, "starts at Star Level 1")


func test_unautomated_station_stores_cash_in_vault_until_collected() -> void:
	var town := TownState.new("desert")
	var b := town.business("gas_station")
	check(not b.is_automated(), "no manager means manual vault mode")
	var start_cash := town.cash
	town.advance(20.0)
	equal(town.cash, start_cash, "unautomated cash waits in the station safe")
	check(b.vault_cash > 0.0, "station vault accumulates cash")
	var swept := town.collect_vault("gas_station")
	check(swept > 0.0, "tapping collects the vault")
	almost(town.cash, start_cash + swept, "collected cash enters wallet", 0.01)
	equal(b.vault_cash, 0.0, "vault is emptied")


func test_automated_station_credits_wallet_and_earns_offline() -> void:
	var town := TownState.new("desert")
	equal(town.offline_earnings(3600.0), 0.0, "manual station earns nothing offline")
	town.cash = 100000.0
	check(town.hire_manager("gas_station"), "hiring Buck Novak succeeds")
	check(town.business("gas_station").is_automated(), "Lv 1 manager automates Lv 1..9")
	var rate := town.net_per_minute()
	var before := town.cash
	town.advance(60.0)
	almost(town.cash, before + rate, "60 s automated pays directly to wallet", 0.05)
	check(town.offline_earnings(3600.0) > 0.0, "automated station earns offline")


func test_renovation_milestone_raises_manager_requirement_and_awards_star() -> void:
	var town := TownState.new("desert")
	town.cash = 500000.0
	town.hire_manager("gas_station")
	check(town.business("gas_station").is_automated(), "automated at Lv 1")
	var stars_before := town.star_points_total()
	town.upgrade_business("gas_station", 9)
	equal(town.business("gas_station").level, 10, "reached Lv 10 renovation milestone")
	check(town.star_points_total() > stars_before, "Lv 10 awards a Star point")
	check(not town.business("gas_station").is_automated(), "Lv 10 requires Manager Lv 2")
	town.hire_manager("gas_station")
	check(town.business("gas_station").is_automated(), "Manager Lv 2 restores automation")


func test_offline_is_capped_at_eight_hours() -> void:
	var town := TownState.new("desert")
	town.cash = 100000.0
	town.hire_manager("gas_station")
	var eight_hours := TownState.OFFLINE_CAP_SECONDS
	almost(
		town.offline_earnings(eight_hours * 3.0),
		town.offline_earnings(eight_hours),
		"offline earnings are capped at eight hours"
	)
	var report := town.apply_offline(eight_hours * 2.0)
	almost(float(report["seconds"]), eight_hours, "report seconds capped")
	check(town.cash > 100000.0, "offline income is credited")


func test_upgrades_and_branches_boost_station() -> void:
	var town := TownState.new("desert")
	town.cash = 500000.0
	var b := town.business("gas_station")
	var before := town.net_per_minute()
	check(town.upgrade_business("gas_station", 5), "multi-step upgrade works")
	check(town.net_per_minute() > before, "higher level earns more")
	var bays_before := b.active_bays()
	check(town.upgrade_branch("gas_station", "capacity"), "bays upgrade works")
	check(b.active_bays() > bays_before, "extra pump island opens")
	var price_before := b.price()
	check(town.upgrade_branch("gas_station", "quality"), "value tech works")
	check(b.price() > price_before, "value tech raises price per vehicle")


func test_star_level_gates_advanced_facilities() -> void:
	var town := TownState.new("desert")
	town.cash = 1000000.0
	check(town.unlock_business("car_wash"), "Car Wash unlocks at Star Level 1")
	check(not town.unlock_business("motel"), "Motel is gated by Star Level 5")
	for id in ["gas_station", "car_wash"]:
		town.upgrade_business(id, 50)
	check(town.star_level() >= 2, "milestones and unlocks raise Star Level")
	check(town.unlock_business("auto_service"), "Auto Service unlocks once Star Level >= 2")


func test_completion_tracks_progress() -> void:
	var town := TownState.new("desert")
	check(not town.is_complete(), "a fresh hub is not complete")
	town.cash = 1.0e15
	for pass_idx in range(6):
		for id in town.business_ids():
			town.unlock_business(id)
			if town.business(id).unlocked:
				town.upgrade_business(id, BusinessData.MAX_LEVEL)
				for branch in BusinessData.BRANCHES:
					while town.business(id).can_upgrade_branch(branch):
						town.upgrade_branch(id, branch)
	almost(town.completion(), 1.0, "a maxed hub reaches 100% completion", 0.001)
	check(town.is_complete(), "is_complete agrees")
	check(town.completed, "completion flag set")
