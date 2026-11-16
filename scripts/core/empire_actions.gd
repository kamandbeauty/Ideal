class_name EmpireActions
extends RefCounted
## High-level Roadside Empire actions on a TownState: manager card + bourbon
## promotions, supply case opening, chapter quest claims, special orders and
## Iron Bones junkyard salvage.


static func star_progress(state: TownState) -> Dictionary:
	var pts := state.star_points_total()
	var lvl := state.star_level()
	var prev_idx := clampi(lvl - 1, 0, TownState.STAR_THRESHOLDS.size() - 1)
	var next_idx := clampi(lvl, 0, TownState.STAR_THRESHOLDS.size() - 1)
	var floor_pts := TownState.STAR_THRESHOLDS[prev_idx]
	var ceil_pts := TownState.STAR_THRESHOLDS[next_idx] if next_idx > prev_idx else floor_pts + 6
	return {
		"level": lvl,
		"current": maxi(0, pts - floor_pts),
		"needed": maxi(1, ceil_pts - floor_pts),
	}


static func activate_x2_boost(state: TownState) -> bool:
	state.x2_boost_seconds = minf(TownState.X2_MAX_SECONDS, state.x2_boost_seconds + TownState.X2_DURATION)
	state.changed.emit()
	return true


static func grant_cash(state: TownState, amount: float) -> void:
	if amount <= 0.0:
		return
	state.cash += amount
	state.lifetime_cash_earned += amount
	state.cash_changed.emit(state.cash)
	state.changed.emit()


static func record_convoy_served(state: TownState, count: float) -> void:
	if count <= 0.0:
		return
	state.customers += count
	if state.special_order_active:
		state.special_order_done += count
		if state.special_order_done >= state.special_order_goal:
			state.special_order_active = false
			state.special_order_timer = 0.0
			var bonus_cash := roundf(maxf(400.0, state.net_per_minute() * 2.5))
			grant_cash(state, bonus_cash)
			state.bourbon += 28
			state.changed.emit()


static func cards_for(state: TownState, mgr_id: String) -> int:
	return int(state.manager_cards.get(mgr_id, 0))


static func can_upgrade_manager_cards(state: TownState, facility_id: String) -> bool:
	var b := state.business(facility_id)
	if b == null or not b.unlocked or not b.can_hire_manager():
		return false
	var mgr_id := BusinessData.manager_id(facility_id)
	var need_cards := ManagerData.cards_needed(b.manager_rank)
	var need_bourbon := ManagerData.bourbon_needed(b.manager_rank)
	return cards_for(state, mgr_id) >= need_cards and state.bourbon >= need_bourbon


static func upgrade_manager_cards(state: TownState, facility_id: String) -> bool:
	var b := state.business(facility_id)
	if not can_upgrade_manager_cards(state, facility_id):
		return false
	var mgr_id := BusinessData.manager_id(facility_id)
	state.manager_cards[mgr_id] = cards_for(state, mgr_id) - ManagerData.cards_needed(b.manager_rank)
	state.bourbon -= ManagerData.bourbon_needed(b.manager_rank)
	b.hire_manager()
	state.managers_hired += 1
	if b.is_automated() and b.vault_cash > 0.0:
		state.collect_vault(facility_id)
	state.business_changed.emit(facility_id)
	state.changed.emit()
	return true


static func open_case(
	state: TownState, case_id: String, rng: RandomNumberGenerator = null
) -> Dictionary:
	if not ManagerData.CASES.has(case_id):
		return {}
	var spec: Dictionary = ManagerData.CASES[case_id]
	var gem_cost := int(spec.get("gem_cost", 0))
	if case_id == "free_crate" and state.free_crate_cooldown > 0.0:
		return {}
	if gem_cost > 0 and state.gems < gem_cost:
		return {}
	var local_rng := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		local_rng.randomize()
	state.gems -= gem_cost
	if case_id == "free_crate":
		state.free_crate_cooldown = float(spec.get("cooldown", 180.0))
	var got_bourbon := local_rng.randi_range(int(spec["bourbon_min"]), int(spec["bourbon_max"]))
	var got_cash := roundf(maxf(120.0, state.net_per_minute() * float(spec["cash_minutes"])))
	var drops := ManagerData.roll_case_cards(local_rng, case_id)
	state.bourbon += got_bourbon
	state.cash += got_cash
	state.lifetime_cash_earned += got_cash
	var total_cards := 0
	for mgr_id in drops:
		var c := int(drops[mgr_id])
		total_cards += c
		state.manager_cards[mgr_id] = cards_for(state, str(mgr_id)) + c
	state.cash_changed.emit(state.cash)
	state.changed.emit()
	return {"bourbon": got_bourbon, "cash": got_cash, "cards": drops, "card_count": total_cards}


static func buy_bourbon_pack(state: TownState, gem_price: int, bourbon_amount: int) -> bool:
	if state.gems < gem_price or gem_price <= 0:
		return false
	state.gems -= gem_price
	state.bourbon += bourbon_amount
	state.changed.emit()
	return true


static func claim_quest_slot(state: TownState, slot_idx: int) -> Dictionary:
	while state.quest_slots.size() < 3:
		var idx := state.quest_slots.size()
		state.quest_slots.append(ChapterQuests.make_slot(idx, state, state.chapter_serial))
		state.chapter_serial += 1
	if slot_idx < 0 or slot_idx >= state.quest_slots.size():
		return {}
	var quest: Dictionary = state.quest_slots[slot_idx]
	if not ChapterQuests.is_complete(quest, state):
		return {}
	var got_cash := float(quest.get("cash", 200.0))
	var got_bourbon := int(quest.get("bourbon", 10))
	var got_gems := int(quest.get("gems", 0))
	state.cash += got_cash
	state.lifetime_cash_earned += got_cash
	state.bourbon += got_bourbon
	state.gems += got_gems
	state.chapter_tasks_done = mini(ChapterQuests.TASKS_PER_CHAPTER, state.chapter_tasks_done + 1)
	state.quest_slots[slot_idx] = ChapterQuests.make_slot(slot_idx, state, state.chapter_serial)
	state.chapter_serial += 1
	state.cash_changed.emit(state.cash)
	state.quest_claimed.emit(slot_idx)
	state.changed.emit()
	return {"cash": got_cash, "bourbon": got_bourbon, "gems": got_gems}


static func can_claim_chapter_milestone(state: TownState, step: int) -> bool:
	return (
		step in ChapterQuests.MILESTONE_STEPS
		and state.chapter_tasks_done >= step
		and not (step in state.chapter_milestones)
	)


static func claim_chapter_milestone(state: TownState, step: int) -> Dictionary:
	if not can_claim_chapter_milestone(state, step):
		return {}
	state.chapter_milestones.append(step)
	var base := maxf(500.0, state.net_per_minute() * 3.0)
	var reward := {"cash": 0.0, "bourbon": 0, "gems": 0}
	if step == 3:
		reward["cash"] = round(base)
		reward["bourbon"] = 20
	elif step == 6:
		reward["cash"] = round(base * 2.0)
		reward["bourbon"] = 35
		reward["gems"] = 5
	else:
		reward["cash"] = round(base * 3.0)
		reward["bourbon"] = 60
		reward["gems"] = 20
		var epic_mgr := ManagerData.ORDER[state.chapter_index % ManagerData.ORDER.size()]
		state.manager_cards[epic_mgr] = cards_for(state, epic_mgr) + 2
	state.cash += float(reward["cash"])
	state.lifetime_cash_earned += float(reward["cash"])
	state.bourbon += int(reward["bourbon"])
	state.gems += int(reward["gems"])
	if state.chapter_milestones.size() >= ChapterQuests.MILESTONE_STEPS.size():
		state.chapter_index += 1
		state.chapter_tasks_done = 0
		state.chapter_milestones.clear()
	state.cash_changed.emit(state.cash)
	state.changed.emit()
	return reward


static func start_special_order(state: TownState) -> bool:
	if state.special_order_active:
		return false
	state.special_order_active = true
	state.special_order_done = 0.0
	state.special_order_goal = float(6 + state.unlocked_ids().size() * 2)
	state.special_order_timer = 65.0
	state.changed.emit()
	return true


static func salvage_iron_bones(
	state: TownState, rng: RandomNumberGenerator = null
) -> Dictionary:
	if state.salvage_charges <= 0:
		if state.gems < 5:
			return {}
		state.gems -= 5
	else:
		state.salvage_charges -= 1
	var local_rng := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		local_rng.randomize()
	var got_bourbon := local_rng.randi_range(12, 30)
	var got_cash := roundf(maxf(180.0, state.net_per_minute() * 1.1))
	var got_gems := 3 if local_rng.randf() < 0.35 else 0
	var mgr := ManagerData.ORDER[local_rng.randi_range(0, ManagerData.ORDER.size() - 1)]
	state.bourbon += got_bourbon
	state.cash += got_cash
	state.lifetime_cash_earned += got_cash
	state.gems += got_gems
	state.manager_cards[mgr] = cards_for(state, mgr) + 1
	state.cash_changed.emit(state.cash)
	state.changed.emit()
	return {"bourbon": got_bourbon, "cash": got_cash, "gems": got_gems, "card": mgr}
