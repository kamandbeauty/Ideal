extends TestCase
## The profile: several towns, shared reputation, travel gates and the daily
## streak. This is the layer the world map and the offline report sit on.


func _rich_town(town_id: String, reputation: float, cash: float) -> TownState:
	var town := TownState.new(town_id)
	town.cash = cash
	town.unlock_business("restaurant")
	town.cash = cash
	town.reputation = reputation
	return town


func test_a_new_profile_starts_in_the_desert_only() -> void:
	var profile := Profile.new()
	equal(profile.active_town, "desert", "a new profile starts in the desert")
	check(profile.active() != null, "the desert town exists")
	equal(profile.town_ids().size(), 1, "only the desert is visited")
	check(profile.unlocked("desert"), "the desert needs no reputation")
	check(not profile.unlocked("forest"), "the forest starts locked")
	almost(profile.reputation(), 0.0, "no reputation yet")


func test_reputation_is_the_best_of_every_town() -> void:
	var profile := Profile.new()
	profile.towns["forest"] = _rich_town("forest", 700.0, 5000.0)
	profile.active_town = "forest"
	almost(profile.reputation(), 700.0, "the highest town reputation counts")
	check(profile.unlocked("forest"), "700 opens the forest (needs 600)")
	check(not profile.unlocked("mountain"), "700 does not open the mountain")


func test_every_town_unlocks_at_its_gate() -> void:
	for id in TownData.ORDER:
		var profile := Profile.new()
		var need := TownData.reputation_required(id)
		profile.towns["desert"] = _rich_town("desert", need, 0.0)
		check(profile.unlocked(id), "gate for %s should open at %.0f" % [id, need])
		if need > 0.0:
			profile.towns["desert"].reputation = need - 1.0
			check(not profile.unlocked(id), "gate for %s must stay shut below" % id)


func test_travel_creates_and_switches_towns() -> void:
	var profile := Profile.new()
	profile.towns["desert"].reputation = 1500.0
	check(profile.travel("forest"), "an unlocked town accepts travel")
	equal(profile.active_town, "forest", "the active town moved")
	check(profile.visited("forest"), "the forest now exists")
	check(not profile.travel("highway"), "a locked town refuses travel")
	equal(profile.active_town, "forest", "a refused travel keeps the town")
	check(profile.travel("desert"), "the player can come back")
	equal(profile.town_ids().size(), 2, "coming back does not add a town")


func test_profile_round_trip_keeps_every_town() -> void:
	var profile := Profile.new()
	profile.towns["desert"].cash = 1234.0
	profile.towns["desert"].reputation = 900.0
	profile.travel("forest")
	profile.towns["forest"].cash = 5000.0
	profile.towns["forest"].upgrade_business("gas_station")
	profile.towns["forest"].cash = 555.0
	profile.streak = 3
	profile.bonus_day = 400

	var data := profile.serialize()
	equal(int(data["version"]), Profile.VERSION, "the payload carries its version")
	var loaded := Profile.new()
	check(loaded.apply_save(data), "a profile save should load")
	equal(loaded.active_town, "forest", "the active town survives")
	equal(loaded.town_ids().size(), 2, "both towns survive")
	almost(loaded.towns["desert"].cash, 1234.0, "the desert cash survives")
	equal(loaded.towns["forest"].business("gas_station").level, 2, "levels survive")
	almost(loaded.towns["forest"].cash, 555.0, "the forest cash survives")
	equal(loaded.streak, 3, "the streak survives")
	almost(loaded.reputation(), 900.0, "reputation is restored")


func test_a_version_one_save_is_wrapped() -> void:
	# A version 1 file was a single town written at the top level.
	var town := TownState.new("desert")
	town.cash = 5000.0
	town.reputation = 250.0
	town.upgrade_business("gas_station")
	town.cash = 777.0
	var legacy := town.serialize()
	legacy["last_seen"] = 1234

	var profile := Profile.new()
	check(profile.apply_save(legacy), "an old single-town save still loads")
	equal(profile.active_town, "desert", "the old town becomes the active one")
	almost(profile.towns["desert"].cash, 777.0, "the old cash is kept")
	equal(profile.towns["desert"].business("gas_station").level, 2, "old levels are kept")


func test_bad_profile_saves_are_refused() -> void:
	var profile := Profile.new()
	check(not profile.apply_save({}), "an empty save is refused")
	check(not profile.apply_save({"version": 99, "towns": {}}), "a wrong version is refused")
	check(
		not profile.apply_save({"version": Profile.VERSION, "towns": {"atlantis": {}}}),
		"a profile of unknown towns is refused"
	)


func test_offline_pays_every_managed_town_once() -> void:
	var profile := Profile.new()
	profile.towns["desert"].hire_manager("gas_station")
	profile.towns["forest"] = _rich_town("forest", 700.0, 5000.0)
	profile.towns["forest"].hire_manager("gas_station")

	var report := profile.claim_offline(3600.0)
	check(float(report["earnings"]) > 0.0, "managed towns pay offline")
	equal((report["breakdown"] as Array).size(), 2, "both towns are in the report")

	var second := profile.claim_offline(0.0)
	almost(float(second["earnings"]), 0.0, "claiming twice pays nothing extra")


func test_the_daily_chest_pays_once_a_day() -> void:
	var profile := Profile.new()
	profile.towns["desert"].cash = 0.0
	profile.towns["desert"].upgrade_business("gas_station")
	check(profile.bonus_ready(100), "day 100 should be ready")
	var chest := profile.claim_daily(100)
	check(not chest.is_empty(), "the chest opens")
	check(float(chest["cash"]) > 0.0, "the chest pays cash")
	equal(int(chest["streak"]), 1, "the first day is streak 1")
	check(not profile.bonus_ready(100), "the same day cannot be claimed twice")
	check(profile.claim_daily(100).is_empty(), "a second claim returns nothing")

	var next := profile.claim_daily(101)
	equal(int(next["streak"]), 2, "the next day extends the streak")
	var gap := profile.claim_daily(105)
	equal(int(gap["streak"]), 1, "missing a day resets the streak")
