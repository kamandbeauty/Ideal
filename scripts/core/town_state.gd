class_name TownState
extends RefCounted
## A town and its economy: cash, gems, reputation, the businesses and the idle
## simulation. Everything here runs headless, so the tests drive real numbers.

signal changed
signal cash_changed(cash: float)
signal reputation_changed(reputation: float)
signal business_changed(id: String)
signal unlocked(id: String)
signal gems_awarded(amount: int)
signal town_completed
signal mission_claimed(index: int)
signal event_started(id: String)
signal event_ended(id: String)
signal tip_collected(id: String, amount: float)

const STARTING_CASH := 1500.0
const FIRST_BUSINESS := "gas_station"
const OFFLINE_CAP_SECONDS := 8.0 * 3600.0
const OFFLINE_RATE := 0.6
const SAVE_VERSION := 1
const CUSTOMER_REPUTATION := 0.5
const GEM_MILESTONES: Array[float] = [100.0, 300.0, 700.0, 1500.0]
const GEM_REWARD := 5
const COMPLETION_GEMS := 25
const TIP_COOLDOWN := 6.0
const TIP_SECONDS := 2.0
const BOOST_GEMS := 5
const BOOST_EVENT := "holiday"

var town_id := "desert"
var cash := STARTING_CASH
var gems := 0
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
var pending_offline_seconds := 0.0
var businesses: Dictionary = {}

var _tip_clock: Dictionary = {}


func _init(id: String = "desert") -> void:
	town_id = id if TownData.has_town(id) else "desert"
	var opener := opening_business(town_id)
	for business_id in TownData.businesses(town_id):
		var state := BusinessState.new(str(business_id), str(business_id) == opener)
		businesses[str(business_id)] = state


## The business a town opens with: the cheapest one it has. Not every town has a
## gas station - the forest has no pumps - so "the first one is free" must follow
## the prices, otherwise a new town arrives with nothing open and no income.
static func opening_business(town_id: String) -> String:
	var best := ""
	var best_cost := INF
	for id in TownData.businesses(town_id):
		var cost := BusinessData.unlock_cost(str(id))
		if cost < best_cost:
			best_cost = cost
			best = str(id)
	return best


# --- Queries ---------------------------------------------------------------

func traffic() -> float:
	return TownData.traffic(town_id) * event_traffic()


func income_multiplier() -> float:
	return TownData.income_multiplier(town_id)


func cost_scale() -> float:
	return TownData.cost_multiplier(town_id)


func business(id: String) -> BusinessState:
	return businesses.get(id)


func business_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in businesses:
		ids.append(str(id))
	ids.sort()
	return ids


func unlocked_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in business_ids():
		if businesses[id].unlocked:
			ids.append(id)
	return ids


func net_per_minute() -> float:
	var total := 0.0
	for id in business_ids():
		var state: BusinessState = businesses[id]
		if state.unlocked:
			total += state.net_per_minute(traffic())
	return total * income_multiplier() * event_income()


func net_per_second() -> float:
	return net_per_minute() / 60.0


func customers_per_minute() -> float:
	var total := 0.0
	for id in business_ids():
		var state: BusinessState = businesses[id]
		if state.unlocked:
			total += state.served_per_minute(traffic())
	return total


func upkeep_per_minute() -> float:
	var total := 0.0
	for id in business_ids():
		var state: BusinessState = businesses[id]
		if state.unlocked:
			total += state.upkeep_per_minute()
	return total


## How finished this town is, 0..1. Half of each business is simply opening it;
## the rest is its level and the three upgrade branches.
func completion() -> float:
	if businesses.is_empty():
		return 0.0
	var total := 0.0
	for id in business_ids():
		var state: BusinessState = businesses[id]
		var opened := 0.5 if state.unlocked else 0.0
		var level_part := 0.25 * float(state.level - 1) / float(BusinessData.MAX_LEVEL - 1)
		var branches := state.capacity_level + state.speed_level + state.quality_level
		var branch_part := 0.25 * float(branches) / float(3 * BusinessData.MAX_BRANCH_LEVEL)
		total += opened + level_part + branch_part
	return clampf(total / float(businesses.size()), 0.0, 1.0)


func is_complete() -> bool:
	return completion() >= 0.999


func town_level() -> int:
	return 1 + int(floor(reputation / 250.0))


func can_afford(amount: float) -> bool:
	return cash >= amount


# --- Simulation ------------------------------------------------------------

func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed += delta
	var traffic_now := traffic()
	var served: float = customers_per_minute() / 60.0
	cash += net_per_second() * delta
	customers += served * delta
	reputation += served * delta * CUSTOMER_REPUTATION

	for id in business_ids():
		var state: BusinessState = businesses[id]
		if not state.unlocked:
			continue
		var minutes := delta / 60.0
		state.customers_total += state.served_per_minute(traffic_now) * minutes
		state.revenue_total += state.revenue_per_minute(traffic_now) * minutes

	for id in _tip_clock:
		_tip_clock[id] = float(_tip_clock[id]) + delta
	_tick_event(delta)
	_check_gems()
	_check_completion()
	reputation_changed.emit(reputation)


# --- Player interaction ----------------------------------------------------

## A tap on a business that is already running pays a small tip. It is the only
## income the player creates by hand - capped by a per-building cooldown, so
## tapping is a habit worth forming, never a substitute for upgrading.
func collect_tip(id: String) -> float:
	var state := business(id)
	if state == null or not state.unlocked:
		return 0.0
	if float(_tip_clock.get(id, TIP_COOLDOWN)) < TIP_COOLDOWN:
		return 0.0
	_tip_clock[id] = 0.0
	var amount := maxf(5.0, state.net_per_second(traffic()) * TIP_SECONDS)
	cash += amount
	cash_changed.emit(cash)
	tip_collected.emit(id, amount)
	return amount


func tip_ready(id: String) -> bool:
	return float(_tip_clock.get(id, TIP_COOLDOWN)) >= TIP_COOLDOWN


func tip_ratio(id: String) -> float:
	return clampf(float(_tip_clock.get(id, TIP_COOLDOWN)) / TIP_COOLDOWN, 0.0, 1.0)


## The cheapest business that is still closed - the always-visible "next goal".
func next_locked() -> Dictionary:
	var best: Dictionary = {}
	for id in business_ids():
		var state: BusinessState = businesses[id]
		if state.unlocked:
			continue
		var price := BusinessData.unlock_cost(id) * cost_scale()
		if best.is_empty() or price < float(best["price"]):
			best = {"id": id, "price": price}
	return best


## Every town that has already been finished, for the world map's trophy line.
func is_town_complete() -> bool:
	return completed


# --- Missions --------------------------------------------------------------

func _is_open(id: String) -> bool:
	var state := business(id)
	return state != null and state.unlocked


func _max_level() -> int:
	var best := 1
	for id in business_ids():
		best = maxi(best, businesses[id].level)
	return best


## The mission the player is on, with its measured progress.
func mission_progress() -> Dictionary:
	var mission := MissionData.at(mission_step)
	if mission.is_empty():
		return {}
	var id := str(mission["id"])
	var current := 0.0
	var goal := 1.0
	match id:
		"first_upgrade":
			current = float(upgrades_total)
			goal = 1.0
		"open_store":
			current = 1.0 if _is_open("store") else 0.0
			goal = 1.0
		"open_restaurant":
			current = 1.0 if _is_open("restaurant") else 0.0
			goal = 1.0
		"reach_level_three":
			current = float(_max_level())
			goal = 3.0
		"hire_manager":
			current = float(managers_hired)
			goal = 1.0
		"buy_branch":
			current = float(branches_total)
			goal = 1.0
		"serve_customers":
			current = customers
			goal = 500.0
		"open_all":
			current = float(unlocked_ids().size())
			goal = float(businesses.size())
		"complete_town":
			current = 1.0 if completed else 0.0
			goal = 1.0
	return {
		"id": id,
		"index": mission_step,
		"current": current,
		"goal": goal,
		"ready": current >= goal,
		"reward": float(mission.get("reward", 0.0)),
		"gems": int(mission.get("gems", 0)),
	}


func claim_mission() -> Dictionary:
	var progress := mission_progress()
	if progress.is_empty() or not bool(progress["ready"]):
		return {}
	cash += float(progress["reward"])
	gems += int(progress["gems"])
	var index := mission_step
	mission_step += 1
	cash_changed.emit(cash)
	mission_claimed.emit(index)
	changed.emit()
	return progress


# --- Events ----------------------------------------------------------------

func event_traffic() -> float:
	return TownEvents.traffic(active_event)


func event_income() -> float:
	return TownEvents.income(active_event)


## Gems had no sink, so they were a score with no decision behind it. Five gems
## now buy a guaranteed rush hour: the shortest possible "spend or save" choice.
func can_boost() -> bool:
	return gems >= BOOST_GEMS and active_event.is_empty() and not is_complete()


func buy_boost() -> bool:
	if not can_boost() or not start_event(BOOST_EVENT):
		return false
	gems -= BOOST_GEMS
	changed.emit()
	return true


func start_event(id: String) -> bool:
	if not TownEvents.has(id) or not active_event.is_empty():
		return false
	active_event = id
	event_time_left = TownEvents.duration(id)
	event_started.emit(id)
	return true


func _tick_event(delta: float) -> void:
	if active_event.is_empty():
		return
	event_time_left -= delta
	if event_time_left > 0.0:
		return
	var ended := active_event
	active_event = ""
	event_time_left = 0.0
	event_ended.emit(ended)


func _check_completion() -> void:
	if completed or not is_complete():
		return
	completed = true
	gems += COMPLETION_GEMS
	town_completed.emit()
	gems_awarded.emit(COMPLETION_GEMS)


func _check_gems() -> void:
	while gems_claimed < GEM_MILESTONES.size() and reputation >= GEM_MILESTONES[gems_claimed]:
		gems += GEM_REWARD
		gems_claimed += 1
		gems_awarded.emit(GEM_REWARD)


func offline_seconds_capped(seconds: float) -> float:
	return clampf(seconds, 0.0, OFFLINE_CAP_SECONDS)


## Only managed businesses keep working while the player is away.
func offline_net_per_minute() -> float:
	var total := 0.0
	for id in business_ids():
		var state: BusinessState = businesses[id]
		if state.unlocked and state.manager_rank > 0:
			total += state.net_per_minute(traffic())
	return total * income_multiplier()


func offline_earnings(seconds: float) -> float:
	return offline_net_per_minute() * (offline_seconds_capped(seconds) / 60.0) * OFFLINE_RATE


## Credits the time the player was away and returns a small report.
func apply_offline(seconds: float) -> Dictionary:
	var capped := offline_seconds_capped(seconds)
	var earnings := offline_earnings(seconds)
	cash += earnings
	cash_changed.emit(cash)
	return {"seconds": capped, "earnings": earnings}


# --- Purchases -------------------------------------------------------------

func unlock_business(id: String) -> bool:
	var state := business(id)
	if state == null or state.unlocked:
		return false
	var price := BusinessData.unlock_cost(id) * cost_scale()
	if cash < price:
		return false
	cash -= price
	state.unlocked = true
	upgrades_total += 1
	_check_completion()
	business_changed.emit(id)
	unlocked.emit(id)
	cash_changed.emit(cash)
	return true


func upgrade_business(id: String) -> bool:
	var state := business(id)
	if state == null or not state.unlocked or not state.can_upgrade_level():
		return false
	var price := state.upgrade_cost() * cost_scale()
	if cash < price:
		return false
	cash -= price
	state.upgrade_level()
	upgrades_total += 1
	_check_completion()
	business_changed.emit(id)
	cash_changed.emit(cash)
	return true


func upgrade_branch(id: String, branch: String) -> bool:
	var state := business(id)
	if state == null or not state.unlocked or not state.can_upgrade_branch(branch):
		return false
	var price := state.branch_cost(branch) * cost_scale()
	if cash < price:
		return false
	cash -= price
	state.upgrade_branch(branch)
	branches_total += 1
	_check_completion()
	business_changed.emit(id)
	cash_changed.emit(cash)
	return true


func hire_manager(id: String) -> bool:
	var state := business(id)
	if state == null or not state.unlocked or not state.can_hire_manager():
		return false
	var price := state.manager_cost() * cost_scale()
	if cash < price:
		return false
	cash -= price
	state.hire_manager()
	managers_hired += 1
	_check_completion()
	business_changed.emit(id)
	cash_changed.emit(cash)
	return true


# --- Saving ----------------------------------------------------------------

func serialize() -> Dictionary:
	var entries: Array = []
	for id in business_ids():
		entries.append(businesses[id].serialize())
	return {
		"version": SAVE_VERSION,
		"town": town_id,
		"cash": cash,
		"gems": gems,
		"reputation": reputation,
		"customers": customers,
		"elapsed": elapsed,
		"gems_claimed": gems_claimed,
		"completed": completed,
		"mission_step": mission_step,
		"upgrades_total": upgrades_total,
		"branches_total": branches_total,
		"managers_hired": managers_hired,
		"businesses": entries,
	}


func apply_save(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != SAVE_VERSION:
		return false
	if not data.has("town"):
		return false
	var saved_town := str(data.get("town", ""))
	if not TownData.has_town(saved_town):
		return false
	town_id = saved_town

	businesses.clear()
	for business_id in TownData.businesses(town_id):
		businesses[str(business_id)] = BusinessState.new(str(business_id), false)

	var raw: Variant = data.get("businesses", [])
	if typeof(raw) == TYPE_ARRAY:
		for entry in raw:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var id := str(entry.get("id", ""))
			if businesses.has(id):
				businesses[id].apply_save(entry)

	var opener := opening_business(town_id)
	if businesses.has(opener):
		(businesses[opener] as BusinessState).unlocked = true
	elif not businesses.is_empty():
		var fallback: BusinessState = businesses.values()[0]
		fallback.unlocked = true

	cash = maxf(0.0, float(data.get("cash", STARTING_CASH)))
	gems = maxi(0, int(data.get("gems", 0)))
	reputation = maxf(0.0, float(data.get("reputation", 0.0)))
	customers = maxf(0.0, float(data.get("customers", 0.0)))
	elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	gems_claimed = clampi(int(data.get("gems_claimed", 0)), 0, GEM_MILESTONES.size())
	completed = bool(data.get("completed", false))
	mission_step = clampi(int(data.get("mission_step", 0)), 0, MissionData.count())
	upgrades_total = maxi(0, int(data.get("upgrades_total", 0)))
	branches_total = maxi(0, int(data.get("branches_total", 0)))
	managers_hired = maxi(0, int(data.get("managers_hired", 0)))
	active_event = ""
	event_time_left = 0.0
	pending_offline_seconds = 0.0
	_tip_clock.clear()
	changed.emit()
	return true
