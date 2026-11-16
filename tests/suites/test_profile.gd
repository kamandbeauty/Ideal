extends TestCase
## Profile: multi-territory US highway progression, Star Level travel gates,
## offline claims across automated hubs and daily streak rewards.


func _star_town(town_id: String, target_star_lvl: int, cash: float) -> TownState:
	var town := TownState.new(town_id)
	town.cash = 1.0e12
	for pass_idx in range(6):
		if town.star_level() >= target_star_lvl:
			break
		for id in town.business_ids():
			town.unlock_business(id)
			if town.business(id).unlocked and town.star_level() < target_star_lvl:
				town.upgrade_business(id, 25)
	town.cash = cash
	return town


func test_a_new_profile_starts_in_dusty_canyon() -> void:
	var profile := Profile.new()
	equal(profile.active_town, "desert", "starts in Dusty Canyon AZ")
	check(profile.active() != null, "the desert hub exists")
	equal(profile.town_ids().size(), 1, "only Dusty Canyon is visited")
	check(profile.unlocked("desert"), "Dusty Canyon needs Star Level 1")
	check(not profile.unlocked("mojave"), "Red Rock Oasis needs Star Level 2")
	equal(profile.best_star_level(), 1, "starts at Star Level 1")


func test_travel_unlocks_by_star_level() -> void:
	var profile := Profile.new()
	profile.towns["desert"] = _star_town("desert", 3, 5000.0)
	check(profile.unlocked("mojave"), "Star Level 3 unlocks Red Rock Oasis (Ch 2)")
	check(profile.unlocked("forest"), "Star Level 3 unlocks Timberland Pass (Ch 3)")
	check(not profile.unlocked("vegas"), "Star Level 3 does not unlock Vegas (Ch 6)")
	check(profile.travel("forest"), "can travel to Timberland Pass")
	equal(profile.active_town, "forest", "active hub switched")
	check(not profile.travel("vegas"), "locked Vegas refuses travel")


func test_profile_round_trip_keeps_every_hub() -> void:
	var profile := Profile.new()
	profile.towns["desert"] = _star_town("desert", 3, 1234.0)
	profile.travel("mojave")
	profile.towns["mojave"].cash = 5000.0
	profile.towns["mojave"].upgrade_business("gas_station")
	profile.towns["mojave"].cash = 555.0
	profile.streak = 3
	profile.bonus_day = 400

	var data := profile.serialize()
	equal(int(data["version"]), Profile.VERSION, "payload carries version")
	var loaded := Profile.new()
	check(loaded.apply_save(data), "profile save loads")
	equal(loaded.active_town, "mojave", "active hub survives")
	equal(loaded.town_ids().size(), 2, "both hubs survive")
	almost(loaded.towns["desert"].cash, 1234.0, "desert cash survives")
	equal(loaded.towns["mojave"].business("gas_station").level, 2, "levels survive")
	equal(loaded.streak, 3, "streak survives")


func test_offline_pays_every_automated_hub_once() -> void:
	var profile := Profile.new()
	profile.towns["desert"].cash = 50000.0
	profile.towns["desert"].hire_manager("gas_station")
	profile.towns["mojave"] = _star_town("mojave", 2, 50000.0)
	profile.towns["mojave"].hire_manager("gas_station")

	var report := profile.claim_offline(3600.0)
	check(float(report["earnings"]) > 0.0, "automated hubs pay offline")
	equal((report["breakdown"] as Array).size(), 2, "both hubs are in the breakdown")


func test_the_daily_chest_pays_once_a_day() -> void:
	var profile := Profile.new()
	check(profile.bonus_ready(100), "day 100 ready")
	var chest := profile.claim_daily(100)
	check(not chest.is_empty(), "chest opens")
	check(float(chest["cash"]) > 0.0, "chest pays cash")
	check(not profile.bonus_ready(100), "same day cannot be claimed twice")
