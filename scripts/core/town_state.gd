class_name TownState
extends RefCounted
## One Roadside Empire territory station: cash, gems, bourbon, star level,
## 8 facilities with vaults, managers & cards, 3 chapter quests, and expeditions.

signal changed
signal cash_changed(cash: float)
signal reputation_changed(reputation: float)
signal business_changed(id: String)
signal unlocked(id: String)
signal gems_awarded(amount: int)
signal town_completed
signal mission_claimed(index: int)
signal quest_claimed(slot: int)
signal event_started(id: String)
signal event_ended(id: String)
signal tip_collected(id: String, amount: float)
signal vault_collected(id: String, amount: float)

const STARTING_CASH := 450.0
const STARTING_GEMS := 25
const STARTING_BOURBON := 25
const FIRST_BUSINESS := "gas_station"
const OFFLINE_CAP_SECONDS := 8.0 * 3600.0
const OFFLINE_RATE := 0.7
const SAVE_VERSION := 3
const CUSTOMER_REPUTATION := 0.65
const GEM_MILESTONES: Array[float] = [100.0, 300.0, 700.0, 1500.0, 3000.0]
const GEM_REWARD := 8
const COMPLETION_GEMS := 35
const TIP_COOLDOWN := 5.0
const TIP_SECONDS := 2.5
const BOOST_GEMS := 5
const BOOST_EVENT := "holiday"
const X2_DURATION := 300.0
const X2_MAX_SECONDS := 900.0
const STAR_THRESHOLDS: Array[int] = [0, 2, 5, 9, 14, 20, 27, 35, 44]

var town_id := "desert"
var cash := STARTING_CASH
var lifetime_cash_earned := 0.0
var gems := STARTING_GEMS
var bourbon := STARTING_BOURBON
var reputation := 0.0
var customers := 0.0
var elapsed := 0.0
var gems_claimed := 0
var completed := false
var mission_step := 0
var upgrades_total := 0
var branches_total := 0
var managers_hired := 0
var active_event := ""
var event_time_left := 0.0
var x2_boost_seconds := 0.0
var free_crate_cooldown := 0.0
var salvage_charges := 3
var salvage_cooldown := 0.0
var special_order_active := false
var special_order_done := 0.0
var special_order_goal := 6.0
var special_order_timer := 0.0
var chapter_index := 1
var chapter_tasks_done := 0
var chapter_serial := 0
var chapter_milestones: Array[int] = []
var quest_slots: Array = []
var manager_cards: Dictionary = {}
var pending_offline_seconds := 0.0
var businesses: Dictionary = {}

var _tip_clock: Dictionary = {}


func _init(id: String = "desert") -> void:
	town_id = id if TownData.has_town(id) else "desert"
	var opener := opening_business(town_id)
	for business_id in TownData.businesses(town_id):
		var b_state := BusinessState.new(str(business_id), str(business_id) == opener)
		businesses[str(business_id)] = b_state
	for mgr_id in ManagerData.ORDER:
		manager_cards[mgr_id] = 2 if mgr_id == "buck_novak" else 0
	_ensure_quests()


static func opening_business(target_town: String) -> String:
	var best := ""
	var best_cost := INF
	for id in TownData.businesses(target_town):
		var cost := BusinessData.unlock_cost(str(id))
		if cost < best_cost:
			best_cost = cost
			best = str(id)
	return best


func _ensure_quests() -> void:
	while quest_slots.size() < 3:
		var idx := quest_slots.size()
		quest_slots.append(ChapterQuests.make_slot(idx, self, chapter_serial))
		chapter_serial += 1


func traffic() -> float:
	return TownData.traffic(town_id) * TownEvents.traffic_multiplier(active_event)


func event_income() -> float:
	return TownEvents.income_multiplier(active_event)


func income_multiplier() -> float:
	return TownData.income_multiplier(town_id) * _boost_multiplier() * _global_manager_multiplier()


func _boost_multiplier() -> float:
	return 2.0 if x2_boost_seconds > 0.0 else 1.0


func _global_manager_multiplier() -> float:
	var bonus := 0.0
	for id in business_ids():
		var b: BusinessState = businesses[id]
		bonus += ManagerData.global_bonus(BusinessData.manager_id(id), b.manager_rank)
	return 1.0 + bonus


func cost_scale() -> float:
	return TownData.cost_multiplier(town_id)


func business(id: String) -> BusinessState:
	return businesses.get(id)


func business_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in BusinessData.ORDER:
		if businesses.has(id):
			ids.append(id)
	return ids


func unlocked_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in business_ids():
		if businesses[id].unlocked:
			ids.append(id)
	return ids


func star_level() -> int:
	var pts := star_points_total()
	var lvl := 1
	for i in range(1, STAR_THRESHOLDS.size()):
		if pts >= STAR_THRESHOLDS[i]:
			lvl = i + 1
	return lvl


func star_points_total() -> int:
	var pts := maxi(0, unlocked_ids().size() - 1)
	for id in unlocked_ids():
		pts += BusinessData.milestones_reached(businesses[id].level)
	return pts


func net_per_minute() -> float:
	var total := 0.0
	var tr := traffic()
	for id in business_ids():
		var b: BusinessState = businesses[id]
		if b.unlocked:
			total += b.net_per_minute(tr)
	return total * income_multiplier() * event_income()


func net_per_second() -> float:
	return net_per_minute() / 60.0


func completion() -> float:
	if businesses.is_empty():
		return 0.0
	var total := 0.0
	for id in business_ids():
		var b: BusinessState = businesses[id]
		var opened := 0.45 if b.unlocked else 0.0
		var level_part := 0.35 * float(b.level - 1) / float(BusinessData.MAX_LEVEL - 1)
		var max_br := float(b.max_branch_for("capacity") + 2 * BusinessData.MAX_BRANCH_LEVEL)
		var branches := float(b.capacity_level + b.speed_level + b.quality_level)
		total += opened + level_part + 0.20 * (branches / maxf(1.0, max_br))
	return clampf(total / float(businesses.size()), 0.0, 1.0)


func is_complete() -> bool:
	return completion() >= 0.999


func town_level() -> int:
	return star_level()


func _can_afford(amount: float) -> bool:
	return cash + 0.001 >= amount


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed += delta
	_tick_timers(delta)
	var tr := traffic()
	var global_mult := income_multiplier() * TownEvents.income_multiplier(active_event)
	var served_total := 0.0
	for id in business_ids():
		var b: BusinessState = businesses[id]
		if not b.unlocked:
			continue
		var served_now := (b.served_per_minute(tr) / 60.0) * delta
		served_total += served_now
		b.customers_total += served_now
		var earned := b.net_per_second(tr) * global_mult * delta
		b.revenue_total += earned
		if b.is_automated():
			var sweep := earned + b.vault_cash
			b.vault_cash = 0.0
			cash += sweep
			lifetime_cash_earned += sweep
		else:
			cash += earned * 0.45
			lifetime_cash_earned += earned * 0.45
			b.vault_cash = minf(b.vault_capacity(tr), b.vault_cash + earned * 0.55)
	customers += served_total
	reputation += served_total * CUSTOMER_REPUTATION
	_tick_special_order(served_total, delta)
	_tick_event(delta)
	_check_gems()
	_check_completion()
	reputation_changed.emit(reputation)


func _tick_timers(delta: float) -> void:
	if x2_boost_seconds > 0.0:
		x2_boost_seconds = maxf(0.0, x2_boost_seconds - delta)
	if free_crate_cooldown > 0.0:
		free_crate_cooldown = maxf(0.0, free_crate_cooldown - delta)
	if salvage_charges < 3:
		salvage_cooldown += delta
		if salvage_cooldown >= 90.0:
			salvage_cooldown = 0.0
			salvage_charges = mini(3, salvage_charges + 1)
	for id in _tip_clock:
		_tip_clock[id] = float(_tip_clock[id]) + delta


func _tick_special_order(served_total: float, delta: float) -> void:
	if not special_order_active:
		return
	special_order_done += served_total
	special_order_timer -= delta
	if special_order_done >= special_order_goal:
		_finish_special_order(true)
	elif special_order_timer <= 0.0:
		_finish_special_order(false)


func _finish_special_order(won: bool) -> void:
	special_order_active = false
	special_order_timer = 0.0
	if won:
		var bonus_cash := roundf(maxf(400.0, net_per_minute() * 2.5))
		cash += bonus_cash
		lifetime_cash_earned += bonus_cash
		bourbon += 28
		var mgr_id := ManagerData.ORDER[int(customers) % ManagerData.ORDER.size()]
		manager_cards[mgr_id] = int(manager_cards.get(mgr_id, 0)) + 1
		cash_changed.emit(cash)
	changed.emit()


func collect_vault(id: String) -> float:
	var b := business(id)
	if b == null or not b.unlocked or b.vault_cash < 1.0:
		return 0.0
	var amount := b.vault_cash
	b.vault_cash = 0.0
	cash += amount
	lifetime_cash_earned += amount
	cash_changed.emit(cash)
	vault_collected.emit(id, amount)
	changed.emit()
	return amount


func collect_tip(id: String) -> float:
	var b := business(id)
	if b == null or not b.unlocked:
		return 0.0
	var vaulted := collect_vault(id)
	if float(_tip_clock.get(id, TIP_COOLDOWN)) < TIP_COOLDOWN:
		return vaulted
	_tip_clock[id] = 0.0
	var amount := maxf(8.0, b.net_per_second(traffic()) * income_multiplier() * TIP_SECONDS)
	cash += amount
	lifetime_cash_earned += amount
	cash_changed.emit(cash)
	tip_collected.emit(id, amount + vaulted)
	return amount + vaulted


func tip_ready(id: String) -> bool:
	return float(_tip_clock.get(id, TIP_COOLDOWN)) >= TIP_COOLDOWN


func unlock_cost(id: String) -> float:
	return round(BusinessData.unlock_cost(id) * cost_scale())


func unlock_business(id: String) -> bool:
	var b := business(id)
	if b == null or b.unlocked or star_level() < BusinessData.star_required(id):
		return false
	var cost := unlock_cost(id)
	if not _can_afford(cost):
		return false
	cash -= cost
	b.unlocked = true
	cash_changed.emit(cash)
	unlocked.emit(id)
	business_changed.emit(id)
	changed.emit()
	return true


func upgrade_cost(id: String, steps: int = 1) -> float:
	var b := business(id)
	if b == null:
		return 0.0
	var raw := b.upgrade_cost() if steps <= 1 else b.multi_upgrade_cost(steps)
	return round(raw * cost_scale())


func upgrade_business(id: String, steps: int = 1) -> bool:
	var b := business(id)
	if b == null or not b.unlocked or not b.can_upgrade_level():
		return false
	var count := clampi(steps, 1, BusinessData.MAX_LEVEL - b.level)
	var cost := upgrade_cost(id, count)
	if not _can_afford(cost):
		return false
	cash -= cost
	for _i in count:
		b.upgrade_level()
	upgrades_total += count
	cash_changed.emit(cash)
	business_changed.emit(id)
	changed.emit()
	return true


func branch_cost(id: String, branch: String) -> float:
	var b := business(id)
	return round(b.branch_cost(branch) * cost_scale()) if b != null else 0.0


func upgrade_branch(id: String, branch: String) -> bool:
	var b := business(id)
	if b == null or not b.unlocked or not b.can_upgrade_branch(branch):
		return false
	var cost := branch_cost(id, branch)
	if not _can_afford(cost):
		return false
	cash -= cost
	b.upgrade_branch(branch)
	branches_total += 1
	cash_changed.emit(cash)
	business_changed.emit(id)
	changed.emit()
	return true


func manager_cost(id: String) -> float:
	var b := business(id)
	return round(b.manager_cost() * cost_scale()) if b != null else 0.0


func hire_manager(id: String) -> bool:
	if EmpireActions.can_upgrade_manager_cards(self, id):
		return EmpireActions.upgrade_manager_cards(self, id)
	var b := business(id)
	if b == null or not b.unlocked or not b.can_hire_manager():
		return false
	var cost := manager_cost(id)
	if not _can_afford(cost):
		return false
	cash -= cost
	b.hire_manager()
	managers_hired += 1
	if b.is_automated() and b.vault_cash > 0.0:
		collect_vault(id)
	cash_changed.emit(cash)
	business_changed.emit(id)
	changed.emit()
	return true


func next_locked() -> Dictionary:
	var best_id := ""
	var best_cost := INF
	for id in business_ids():
		var b: BusinessState = businesses[id]
		if not b.unlocked and unlock_cost(id) < best_cost:
			best_cost = unlock_cost(id)
			best_id = id
	return {"id": best_id, "cost": best_cost} if not best_id.is_empty() else {}


func can_buy_boost() -> bool:
	return gems >= BOOST_GEMS and active_event.is_empty()


func buy_boost() -> bool:
	if not can_buy_boost():
		return false
	gems -= BOOST_GEMS
	start_event(BOOST_EVENT)
	changed.emit()
	return true


func current_mission() -> Dictionary:
	return MissionData.mission(mission_step)


func mission_progress() -> Dictionary:
	var m := current_mission()
	if m.is_empty():
		return {}
	var goal := float(m["goal"])
	var current := _measure_mission(m)
	return {"current": minf(current, goal), "goal": goal, "complete": current + 0.001 >= goal}


func claim_mission() -> bool:
	var progress := mission_progress()
	if progress.is_empty() or not bool(progress["complete"]):
		return false
	var m := current_mission()
	var claimed := mission_step
	mission_step += 1
	cash += float(m.get("cash", 0.0))
	lifetime_cash_earned += float(m.get("cash", 0.0))
	gems += int(m.get("gems", 0))
	bourbon += int(m.get("bourbon", 0))
	cash_changed.emit(cash)
	mission_claimed.emit(claimed)
	changed.emit()
	return true


func _measure_mission(m: Dictionary) -> float:
	var val := 0.0
	var kind := str(m.get("kind", ""))
	if kind == "upgrades":
		val = float(upgrades_total)
	elif kind == "branches":
		val = float(branches_total)
	elif kind == "managers":
		val = float(managers_hired)
	elif kind == "customers":
		val = floor(customers)
	elif kind == "unlocked_count":
		val = float(unlocked_ids().size())
	elif kind == "business":
		var target := business(str(m.get("target", "")))
		val = 1.0 if (target != null and target.unlocked) else 0.0
	elif kind == "max_level":
		var best := 0
		for id in unlocked_ids():
			best = maxi(best, businesses[id].level)
		val = float(best)
	elif kind == "completion":
		val = round(completion() * 100.0)
	return val


func start_event(id: String) -> bool:
	if not TownEvents.has_event(id):
		return false
	active_event = id
	event_time_left = TownEvents.duration(id)
	event_started.emit(id)
	changed.emit()
	return true


func _tick_event(delta: float) -> void:
	if active_event.is_empty():
		return
	event_time_left -= delta
	if event_time_left <= 0.0:
		var ended := active_event
		active_event = ""
		event_time_left = 0.0
		event_ended.emit(ended)
		changed.emit()


func offline_net_per_minute() -> float:
	var total := 0.0
	var tr := TownData.traffic(town_id)
	for id in business_ids():
		var b: BusinessState = businesses[id]
		if b.unlocked and b.manager_rank > 0:
			total += b.net_per_minute(tr)
	return total * TownData.income_multiplier(town_id) * _global_manager_multiplier()


func offline_seconds_capped(away_seconds: float) -> float:
	return clampf(away_seconds, 0.0, OFFLINE_CAP_SECONDS)


func offline_earnings(away_seconds: float) -> float:
	return (offline_net_per_minute() / 60.0) * offline_seconds_capped(away_seconds) * OFFLINE_RATE


func apply_offline(away_seconds: float) -> Dictionary:
	var seconds := offline_seconds_capped(away_seconds)
	var earned := offline_earnings(seconds)
	cash += earned
	lifetime_cash_earned += earned
	cash_changed.emit(cash)
	changed.emit()
	return {"seconds": seconds, "earnings": earned}


func _check_gems() -> void:
	while gems_claimed < GEM_MILESTONES.size() and reputation >= GEM_MILESTONES[gems_claimed]:
		gems_claimed += 1
		gems += GEM_REWARD
		gems_awarded.emit(GEM_REWARD)
		changed.emit()


func _check_completion() -> void:
	if completed or not is_complete():
		return
	completed = true
	gems += COMPLETION_GEMS
	gems_awarded.emit(COMPLETION_GEMS)
	town_completed.emit()
	changed.emit()


func serialize() -> Dictionary:
	var stored_businesses := {}
	for id in business_ids():
		stored_businesses[id] = businesses[id].serialize()
	return {
		"version": SAVE_VERSION,
		"town_id": town_id,
		"cash": cash,
		"lifetime_cash": lifetime_cash_earned,
		"gems": gems,
		"bourbon": bourbon,
		"reputation": reputation,
		"customers": customers,
		"elapsed": elapsed,
		"gems_claimed": gems_claimed,
		"completed": completed,
		"mission_step": mission_step,
		"upgrades_total": upgrades_total,
		"branches_total": branches_total,
		"managers_hired": managers_hired,
		"active_event": active_event,
		"event_time_left": event_time_left,
		"x2_boost": x2_boost_seconds,
		"free_crate_cd": free_crate_cooldown,
		"salvage_charges": salvage_charges,
		"chapter_index": chapter_index,
		"chapter_tasks": chapter_tasks_done,
		"chapter_serial": chapter_serial,
		"chapter_milestones": chapter_milestones,
		"quest_slots": quest_slots,
		"manager_cards": manager_cards,
		"businesses": stored_businesses,
	}


func apply_save(saved: Dictionary) -> bool:
	if saved.is_empty():
		return false
	var ver := int(saved.get("version", 0))
	if ver < 1 or ver > SAVE_VERSION:
		return false
	var saved_town := str(saved.get("town_id", town_id))
	if TownData.has_town(saved_town) and saved_town != town_id:
		_init(saved_town)
	cash = maxf(0.0, float(saved.get("cash", STARTING_CASH)))
	lifetime_cash_earned = maxf(cash, float(saved.get("lifetime_cash", cash)))
	gems = maxi(0, int(saved.get("gems", STARTING_GEMS)))
	bourbon = maxi(0, int(saved.get("bourbon", STARTING_BOURBON)))
	reputation = maxf(0.0, float(saved.get("reputation", 0.0)))
	customers = maxf(0.0, float(saved.get("customers", 0.0)))
	elapsed = maxf(0.0, float(saved.get("elapsed", 0.0)))
	gems_claimed = clampi(int(saved.get("gems_claimed", 0)), 0, GEM_MILESTONES.size())
	completed = bool(saved.get("completed", false))
	mission_step = clampi(int(saved.get("mission_step", 0)), 0, MissionData.count())
	upgrades_total = maxi(0, int(saved.get("upgrades_total", 0)))
	branches_total = maxi(0, int(saved.get("branches_total", 0)))
	managers_hired = maxi(0, int(saved.get("managers_hired", 0)))
	var ev := str(saved.get("active_event", ""))
	active_event = ev if TownEvents.has_event(ev) else ""
	event_time_left = maxf(0.0, float(saved.get("event_time_left", 0.0))) if not active_event.is_empty() else 0.0
	x2_boost_seconds = clampf(float(saved.get("x2_boost", 0.0)), 0.0, X2_MAX_SECONDS)
	free_crate_cooldown = maxf(0.0, float(saved.get("free_crate_cd", 0.0)))
	salvage_charges = clampi(int(saved.get("salvage_charges", 3)), 0, 3)
	chapter_index = maxi(1, int(saved.get("chapter_index", 1)))
	chapter_tasks_done = clampi(int(saved.get("chapter_tasks", 0)), 0, ChapterQuests.TASKS_PER_CHAPTER)
	chapter_serial = maxi(0, int(saved.get("chapter_serial", 0)))
	chapter_milestones.clear()
	for m in saved.get("chapter_milestones", []):
		chapter_milestones.append(int(m))
	_load_cards_and_businesses(saved)
	return true


func _load_cards_and_businesses(saved: Dictionary) -> void:
	var saved_cards: Variant = saved.get("manager_cards", {})
	if typeof(saved_cards) == TYPE_DICTIONARY:
		for mgr_id in saved_cards:
			if ManagerData.has_manager(str(mgr_id)):
				manager_cards[str(mgr_id)] = maxi(0, int(saved_cards[mgr_id]))
	var stored: Variant = saved.get("businesses", {})
	if typeof(stored) == TYPE_DICTIONARY:
		for id in stored:
			if businesses.has(id) and typeof(stored[id]) == TYPE_DICTIONARY:
				businesses[id].apply_save(stored[id])
	var saved_quests: Variant = saved.get("quest_slots", [])
	if typeof(saved_quests) == TYPE_ARRAY and (saved_quests as Array).size() == 3:
		quest_slots = (saved_quests as Array).duplicate(true)
	else:
		quest_slots.clear()
		_ensure_quests()
