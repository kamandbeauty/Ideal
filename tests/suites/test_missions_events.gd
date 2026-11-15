extends TestCase
## The guided mission chain and the roadside events.


func _focus(town: TownState, id: String) -> void:
	match id:
		"first_upgrade":
			if town.upgrades_total == 0:
				town.upgrade_business("gas_station")
		"open_restaurant":
			town.unlock_business("restaurant")
		"reach_level_three":
			while town.business("gas_station").level < 3:
				town.upgrade_business("gas_station")
		"hire_manager":
			town.hire_manager("gas_station")
		"buy_branch":
			if town.business("gas_station").level < 2:
				town.upgrade_business("gas_station")
			town.upgrade_branch("gas_station", "capacity")
		"serve_customers":
			town.customers = 500.0
		"open_all":
			for business_id in town.business_ids():
				town.unlock_business(business_id)
		"complete_town":
			for business_id in town.business_ids():
				while town.business(business_id).level < BusinessData.MAX_LEVEL:
					town.upgrade_business(business_id)
				for branch in BusinessData.BRANCHES:
					while town.business(business_id).can_upgrade_branch(branch):
						town.upgrade_branch(business_id, branch)


func test_mission_chain_starts_with_an_upgrade() -> void:
	var town := TownState.new("desert")
	var progress := town.mission_progress()
	equal(str(progress["id"]), "first_upgrade", "the chain starts with the first upgrade")
	check(not bool(progress["ready"]), "it is not ready on a fresh town")
	check(town.claim_mission().is_empty(), "an unfinished mission pays nothing")

	town.cash = 100000.0
	var cash_before := town.cash
	check(town.upgrade_business("gas_station"), "the upgrade should be affordable")
	check(bool(town.mission_progress()["ready"]), "the first mission is ready")
	var reward := town.claim_mission()
	check(not reward.is_empty(), "the reward should pay")
	almost(town.cash, cash_before - 850.0 + 250.0, "the reward is credited", 0.01)
	equal(int(town.mission_progress()["index"]), 1, "the chain moves on")
	check(town.claim_mission().is_empty(), "a mission cannot be claimed twice")


func test_mission_chain_can_be_finished() -> void:
	var town := TownState.new("desert")
	town.cash = 100000000.0
	for i in MissionData.count():
		var progress := town.mission_progress()
		check(not progress.is_empty(), "a mission is always offered")
		_focus(town, str(progress["id"]))
		check(bool(town.mission_progress()["ready"]), "%s should be ready" % progress["id"])
		town.claim_mission()
	check(town.mission_progress().is_empty(), "the chain ends after the last mission")
	check(town.completed, "the last mission needs a finished town")


func test_every_mission_has_copy() -> void:
	for id in MissionData.ids():
		for language in L10n.LANGUAGES:
			var title := L10n.translate(language, "mission.%s.title" % id)
			var description := L10n.translate(language, "mission.%s.desc" % id)
			check(title != "mission.%s.title" % id, "missing mission title for " + id)
			check(description != "mission.%s.desc" % id, "missing mission text for " + id)


func test_events_change_traffic_and_income() -> void:
	var town := TownState.new("desert")
	var base_traffic := town.traffic()
	check(town.start_event("rush"), "rush hour should start")
	almost(
		town.traffic(),
		base_traffic * TownEvents.traffic("rush"),
		"rush multiplies traffic",
		0.001
	)
	check(not town.start_event("rain"), "only one event runs at a time")
	town.advance(TownEvents.duration("rush") + 1.0)
	check(town.active_event.is_empty(), "the event should end on time")
	almost(town.traffic(), base_traffic, "traffic returns to normal", 0.001)


func test_bad_weather_slows_the_stop() -> void:
	var town := TownState.new("desert")
	check(town.start_event("rain"), "rain starts")
	check(town.traffic() < 1.0, "rain reduces traffic")
	town.advance(TownEvents.duration("rain") + 1.0)
	check(town.start_event("breakdown"), "breakdown starts")
	check(town.event_income() < 1.0, "a breakdown reduces income")
	town.advance(TownEvents.duration("breakdown") + 1.0)
	almost(town.event_income(), 1.0, "income returns to normal", 0.001)


func test_event_catalogue_is_complete() -> void:
	equal(TownEvents.ids().size(), 6, "six events ship")
	for id in TownEvents.ids():
		check(TownEvents.duration(id) > 0.0, id + " needs a duration")
		check(TownEvents.traffic(id) > 0.0, id + " needs a traffic factor")
		check(TownEvents.income(id) > 0.0, id + " needs an income factor")
		for language in L10n.LANGUAGES:
			var label := L10n.translate(language, TownEvents.name_key(id))
			check(label != TownEvents.name_key(id), "missing event name for " + id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	check(TownEvents.pick(rng, "rush") != "rush", "pick avoids the previous event")
