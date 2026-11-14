extends TestCase
## Save format: round trip, validation, clamping, and the backup fallback.


func _rich_town() -> TownState:
	var town := TownState.new("desert")
	town.cash = 50000.0
	town.unlock_business("restaurant")
	town.upgrade_business("gas_station")
	town.upgrade_branch("gas_station", "quality")
	town.hire_manager("gas_station")
	town.cash = 1234.5
	town.reputation = 321.0
	town.gems = 10
	town.gems_claimed = 2
	return town


func test_round_trip_keeps_progress() -> void:
	var town := _rich_town()
	var data := town.serialize()
	equal(int(data["version"]), TownState.SAVE_VERSION, "saves carry their version")

	var loaded := TownState.new("desert")
	check(loaded.apply_save(data), "a valid save should load")
	almost(loaded.cash, 1234.5, "cash survives")
	almost(loaded.reputation, 321.0, "reputation survives")
	equal(loaded.gems, 10, "gems survive")
	equal(loaded.business("gas_station").level, 2, "levels survive")
	equal(loaded.business("gas_station").quality_level, 1, "branches survive")
	equal(loaded.business("gas_station").manager_rank, 1, "managers survive")
	check(loaded.business("restaurant").unlocked, "unlocked businesses survive")
	check(loaded.unlocked_ids().size() == 2, "no extra businesses appear")


func test_bad_saves_are_rejected() -> void:
	var town := TownState.new("desert")
	check(not town.apply_save({}), "an empty save is refused")
	check(not town.apply_save({"version": 99, "town": "desert"}), "a wrong version is refused")
	check(not town.apply_save({"version": 1, "town": "atlantis"}), "an unknown town is refused")
	check(not town.apply_save({"version": 1}), "a missing town is refused")


func test_unknown_businesses_are_dropped() -> void:
	var town := TownState.new("desert")
	var data := {
		"version": 1,
		"town": "desert",
		"cash": 10.0,
		"businesses": [
			{"id": "gas_station", "unlocked": true, "level": 99, "capacity": 99},
			{"id": "casino", "unlocked": true, "level": 3},
			{"id": 7},
		],
	}
	check(town.apply_save(data), "the save should still load")
	check(town.business("casino") == null, "unknown businesses are dropped")
	equal(town.business("gas_station").level, BusinessData.MAX_LEVEL, "levels are clamped")
	equal(
		town.business("gas_station").capacity_level,
		BusinessData.MAX_BRANCH_LEVEL,
		"branches are clamped"
	)
	check(town.business("gas_station").unlocked, "the first business stays open")


func test_missing_first_business_is_reopened() -> void:
	var town := TownState.new("desert")
	var data := {
		"version": 1,
		"town": "desert",
		"businesses": [{"id": "restaurant", "unlocked": true, "level": 2}],
	}
	check(town.apply_save(data), "the save should load")
	check(town.business("gas_station").unlocked, "the gas station is restored")
	check(town.business("restaurant").unlocked, "the saved business stays open")


func test_save_file_round_trip() -> void:
	SaveManager.delete()
	var town := TownState.new("desert")
	town.cash = 900.0
	town.reputation = 42.0
	check(SaveManager.save(town), "the save should be written")
	check(SaveManager.has_save(), "the save should be detected")
	var loaded := SaveManager.load_town()
	check(loaded != null, "the save should load")
	almost(loaded.cash, 900.0, "cash survives the file")
	almost(loaded.reputation, 42.0, "reputation survives the file")
	check(loaded.pending_offline_seconds >= 0.0, "offline time is not negative")
	SaveManager.delete()


func test_corrupt_save_falls_back_to_backup() -> void:
	SaveManager.delete()
	var town := TownState.new("desert")
	town.cash = 777.0
	SaveManager.save(town)
	town.cash = 888.0
	SaveManager.save(town)

	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	check(file != null, "the save file should be writable")
	if file != null:
		file.store_string("{not json")
		file.close()

	var loaded := SaveManager.load_town()
	check(loaded != null, "the backup should be used")
	if loaded != null:
		almost(loaded.cash, 777.0, "the backup keeps the previous value")
	SaveManager.delete()
	check(not SaveManager.has_save(), "delete removes the save")
