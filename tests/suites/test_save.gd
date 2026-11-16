extends TestCase
## Save format: round trip, Roadside Empire fields, validation, clamping and backup.


func _rich_town() -> TownState:
	var town := TownState.new("desert")
	town.cash = 50000.0
	town.unlock_business("car_wash")
	town.upgrade_business("gas_station", 3)
	town.upgrade_branch("gas_station", "quality")
	town.hire_manager("gas_station")
	town.cash = 1234.5
	town.bourbon = 88
	town.manager_cards["buck_novak"] = 5
	town.reputation = 321.0
	town.gems = 25
	town.chapter_index = 2
	town.chapter_tasks_done = 4
	town.completed = true
	town.mission_step = 3
	return town


func test_round_trip_keeps_progress() -> void:
	var town := _rich_town()
	var data := town.serialize()
	equal(int(data["version"]), TownState.SAVE_VERSION, "saves carry their version")

	var loaded := TownState.new("desert")
	check(loaded.apply_save(data), "a valid save should load")
	almost(loaded.cash, 1234.5, "cash survives")
	equal(loaded.bourbon, 88, "bourbon survives")
	equal(EmpireActions.cards_for(loaded, "buck_novak"), 5, "manager cards survive")
	equal(loaded.gems, 25, "gems survive")
	equal(loaded.chapter_index, 2, "chapter index survives")
	equal(loaded.chapter_tasks_done, 4, "chapter tasks survive")
	equal(loaded.business("gas_station").level, 4, "levels survive")
	equal(loaded.business("gas_station").quality_level, 1, "branches survive")
	equal(loaded.business("gas_station").manager_rank, 1, "managers survive")
	check(loaded.business("car_wash").unlocked, "unlocked businesses survive")
	check(loaded.completed, "completion flag survives")


func test_bad_saves_are_rejected() -> void:
	var town := TownState.new("desert")
	check(not town.apply_save({}), "an empty save is refused")
	check(not town.apply_save({"version": 99, "town": "desert"}), "a wrong version is refused")
	check(not town.apply_save({"version": 1, "town": "atlantis"}), "an unknown town is refused")
	check(not town.apply_save({"version": 1}), "a missing town is refused")


func test_unknown_businesses_are_dropped_and_levels_clamped() -> void:
	var town := TownState.new("desert")
	var data := {
		"version": TownState.SAVE_VERSION,
		"town": "desert",
		"cash": 10.0,
		"businesses": [
			{"id": "gas_station", "unlocked": true, "level": 999, "capacity": 99},
			{"id": "casino", "unlocked": true, "level": 3},
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


func test_missing_first_business_is_reopened() -> void:
	var town := TownState.new("desert")
	var data := {
		"version": TownState.SAVE_VERSION,
		"town": "desert",
		"businesses": [{"id": "car_wash", "unlocked": true, "level": 2}],
	}
	check(town.apply_save(data), "the save should load")
	check(town.business("gas_station").unlocked, "the gas station is restored")
	check(town.business("car_wash").unlocked, "the saved business stays open")


func test_save_file_and_backup_fallback() -> void:
	SaveManager.delete()
	var town := TownState.new("desert")
	town.cash = 777.0
	check(SaveManager.save(town), "first save written")
	town.cash = 888.0
	SaveManager.save(town)

	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("{not json")
		file.close()

	var loaded := SaveManager.load_town()
	check(loaded != null, "the backup should be used")
	if loaded != null:
		almost(loaded.cash, 777.0, "the backup keeps the previous value")
	SaveManager.delete()
	check(not SaveManager.has_save(), "delete removes the save")
