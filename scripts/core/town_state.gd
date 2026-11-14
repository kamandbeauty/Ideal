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

const STARTING_CASH := 1500.0
const FIRST_BUSINESS := "gas_station"
const OFFLINE_CAP_SECONDS := 8.0 * 3600.0
const OFFLINE_RATE := 0.6
const SAVE_VERSION := 1
const CUSTOMER_REPUTATION := 0.5
const GEM_MILESTONES: Array[float] = [100.0, 300.0, 700.0, 1500.0]
const GEM_REWARD := 5

var town_id := "desert"
var cash := STARTING_CASH
var gems := 0
var reputation := 0.0
var customers := 0.0
var elapsed := 0.0
var gems_claimed := 0
var pending_offline_seconds := 0.0
var businesses: Dictionary = {}


func _init(id: String = "desert") -> void:
	town_id = id if TownData.has_town(id) else "desert"
	for business_id in TownData.businesses(town_id):
		var state := BusinessState.new(str(business_id), str(business_id) == FIRST_BUSINESS)
		businesses[str(business_id)] = state


# --- Queries ---------------------------------------------------------------

func traffic() -> float:
	return TownData.traffic(town_id)


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
	return total * income_multiplier()


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

	_check_gems()
	reputation_changed.emit(reputation)


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

	if businesses.has(FIRST_BUSINESS):
		businesses[FIRST_BUSINESS].unlocked = true
	elif not businesses.is_empty():
		var fallback: BusinessState = businesses.values()[0]
		fallback.unlocked = true

	cash = maxf(0.0, float(data.get("cash", STARTING_CASH)))
	gems = maxi(0, int(data.get("gems", 0)))
	reputation = maxf(0.0, float(data.get("reputation", 0.0)))
	customers = maxf(0.0, float(data.get("customers", 0.0)))
	elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	gems_claimed = clampi(int(data.get("gems_claimed", 0)), 0, GEM_MILESTONES.size())
	pending_offline_seconds = 0.0
	changed.emit()
	return true
