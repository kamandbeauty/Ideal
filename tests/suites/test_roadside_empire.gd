extends TestCase
## Roadside Empire signature meta-systems:
## Manager Cards + Bourbon promotions, Supply Cases, x2 Income Booster,
## 3-Slot Chapter Quests + Milestone Chests, Special Orders and Iron Bones!


func test_manager_cards_and_bourbon_promote_and_automate() -> void:
	var town := TownState.new("desert")
	town.cash = 0.0
	town.bourbon = 50
	town.manager_cards["buck_novak"] = 4
	check(
		EmpireActions.can_upgrade_manager_cards(town, "gas_station"),
		"Buck Novak has enough cards and bourbon for Lv 1"
	)
	check(EmpireActions.upgrade_manager_cards(town, "gas_station"), "card+bourbon promotion works")
	equal(town.business("gas_station").manager_rank, 1, "Buck Novak reached Lv 1")
	check(town.business("gas_station").is_automated(), "Gas Station is now automated")
	check(town.bourbon < 50, "bourbon was spent")
	check(EmpireActions.cards_for(town, "buck_novak") < 4, "cards were consumed")


func test_supply_cases_award_cards_bourbon_and_cash() -> void:
	var town := TownState.new("desert")
	town.gems = 100
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var free_loot := EmpireActions.open_case(town, "free_crate", rng)
	check(not free_loot.is_empty(), "free supply crate opens immediately")
	check(int(free_loot["card_count"]) >= 1, "free crate drops manager cards")
	check(EmpireActions.open_case(town, "free_crate", rng).is_empty(), "free crate enters cooldown")

	var epic_loot := EmpireActions.open_case(town, "epic_case", rng)
	check(not epic_loot.is_empty(), "epic case opens with gems")
	equal(town.gems, 45, "epic case spends 55 gems")
	check(int(epic_loot["card_count"]) >= 7, "epic case drops abundant cards")


func test_x2_booster_doubles_income_and_ticks_down() -> void:
	var town := TownState.new("desert")
	town.cash = 50000.0
	town.hire_manager("gas_station")
	var base_mult := town.income_multiplier()
	EmpireActions.activate_x2_boost(town)
	almost(town.income_multiplier(), base_mult * 2.0, "x2 booster doubles income multiplier", 0.001)
	check(town.x2_boost_seconds >= 299.0, "x2 booster grants 5 minutes")
	town.advance(310.0)
	equal(town.x2_boost_seconds, 0.0, "x2 booster expires cleanly")


func test_chapter_quests_and_milestones_advance_chapter() -> void:
	var town := TownState.new("desert")
	equal(town.quest_slots.size(), 3, "three side-by-side quest cards exist at start")
	for step_i in range(9):
		# Complete slot 1 (earn_cash) reliably by crediting earnings.
		var q: Dictionary = town.quest_slots[1]
		town.earn(float(q.get("goal", 1000.0)) + 500.0)
		check(ChapterQuests.is_complete(q, town), "earn quest becomes ready")
		var reward := EmpireActions.claim_quest_slot(town, 1)
		check(not reward.is_empty(), "claiming quest pays reward")
	equal(town.chapter_tasks_done, 9, "all 9 chapter tasks completed")
	for m_step in ChapterQuests.MILESTONE_STEPS:
		check(EmpireActions.can_claim_chapter_milestone(town, m_step), "milestone %d ready" % m_step)
		var m_reward := EmpireActions.claim_chapter_milestone(town, m_step)
		check(not m_reward.is_empty(), "milestone %d pays chest" % m_step)
	equal(town.chapter_index, 2, "claiming 3, 6, 9 advances to Chapter 2!")


func test_special_orders_and_iron_bones_salvage() -> void:
	var town := TownState.new("desert")
	town.cash = 50000.0
	town.hire_manager("gas_station")
	check(EmpireActions.start_special_order(town), "VIP Convoy Special Order starts")
	check(town.special_order_active, "special order active")
	EmpireActions.record_convoy_served(town, town.special_order_goal + 1.0)
	check(not town.special_order_active, "finishing convoy pays bonus and closes order")

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var salvage := EmpireActions.salvage_iron_bones(town, rng)
	check(not salvage.is_empty(), "Iron Bones junkyard salvage yields parts & cards")
	equal(town.salvage_charges, 2, "one free salvage charge used")
