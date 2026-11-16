extends TestCase
## Guided mission chain and Roadside Empire rush/weather events.


func _focus(town: TownState, id: String) -> void:
	match id:
		"first_upgrade":
			if town.upgrades_total == 0:
				town.upgrade_business("gas_station")
		"open_car_wash":
			town.unlock_business("car_wash")
		"open_auto_service":
			town.upgrade_business("gas_station", 25)
			town.unlock_business("auto_service")
		"reach_level_ten":
			while town.business("gas_station").level < 10:
				town.upgrade_business("gas_station")
		"hire_manager":
			town.hire_manager("gas_station")
		"buy_branch":
			if town.business("gas_station").level < 2:
				town.upgrade_business("gas_station")
			town.upgrade_branch("gas_station", "capacity")
		"serve_customers":
			town.customers = 150.0
		"open_all":
			for pass_idx in range(6):
				for bid in town.business_ids():
					town.unlock_business(bid)
					if town.business(bid).unlocked and town.business(bid).level < 25:
						town.upgrade_business(bid, 25)
		"complete_town":
			for pass_idx in range(6):
				for bid in town.business_ids():
					town.unlock_business(bid)
					if town.business(bid).unlocked:
						town.upgrade_business(bid, BusinessData.MAX_LEVEL)
						for branch in BusinessData.BRANCHES:
							while town.business(bid).can_upgrade_branch(branch):
								town.upgrade_branch(bid, branch)


func test_mission_chain_can_be_finished() -> void:
	var town := TownState.new("desert")
	town.cash = 1.0e15
	for i in MissionData.count():
		var progress := town.mission_progress()
		check(not progress.is_empty(), "a mission is always offered")
		_focus(town, str(progress["id"]))
		check(bool(town.mission_progress()["ready"]), "%s should be ready" % progress["id"])
		town.claim_mission()
	check(town.mission_progress().is_empty(), "the chain ends after the last mission")
	check(town.completed, "the last mission finishes the hub")


func test_every_mission_has_copy() -> void:
	for id in MissionData.ids():
		for language in L10n.LANGUAGES:
			var title := L10n.translate(language, "mission.%s.title" % id)
			var description := L10n.translate(language, "mission.%s.desc" % id)
			check(title != "mission.%s.title" % id, "missing mission title for " + id)
			check(description != "mission.%s.desc" % id, "missing mission text for " + id)


func test_events_change_traffic_and_monster_hills_spawns_monsters() -> void:
	var town := TownState.new("desert")
	var base_traffic := town.traffic()
	check(town.start_event("monster_hills"), "Monster Hills rally starts")
	check(TownEvents.spawns_monsters("monster_hills"), "Monster Hills spawns monster trucks")
	almost(
		town.traffic(),
		base_traffic * TownEvents.traffic("monster_hills"),
		"Monster Hills boosts traffic",
		0.001
	)
	check(not town.start_event("sandstorm"), "only one event runs at a time")
	town.advance(TownEvents.duration("monster_hills") + 1.0)
	check(town.active_event.is_empty(), "event ends on time")


func test_event_catalogue_is_complete() -> void:
	equal(TownEvents.ids().size(), 6, "six events ship")
	for id in TownEvents.ids():
		check(TownEvents.duration(id) > 0.0, id + " needs a duration")
		check(TownEvents.traffic(id) > 0.0, id + " needs a traffic factor")
		check(TownEvents.income(id) > 0.0, id + " needs an income factor")
		for language in L10n.LANGUAGES:
			var label := L10n.translate(language, TownEvents.name_key(id))
			check(label != TownEvents.name_key(id), "missing event name for " + id)
