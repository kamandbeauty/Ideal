class_name BusinessState
extends RefCounted
## One Roadside Empire facility: level (1..100), renovation milestones,
## active service bays (1..max_bays), speed/tech upgrades, vault cash & manager.

var id := ""
var unlocked := false
var level := 1
var capacity_level := 0
var speed_level := 0
var quality_level := 0
var manager_rank := 0
var vault_cash := 0.0
var customers_total := 0.0
var revenue_total := 0.0


func _init(business_id: String = "", start_unlocked: bool = false) -> void:
	id = business_id
	unlocked = start_unlocked


func data() -> Dictionary:
	return BusinessData.data(id)


## Active physical bays/pumps on the forecourt (1 .. max_bays).
func active_bays() -> int:
	if not unlocked:
		return 0
	var max_b := BusinessData.max_bays(id)
	var from_milestone := 1 + int(level >= 25) + int(level >= 60)
	return clampi(maxi(1 + capacity_level, from_milestone), 1, max_b)


func capacity() -> float:
	var base := float(data().get("base_capacity", 3.0))
	return base * float(maxi(1, active_bays())) * (1.0 + 0.04 * float(level - 1))


func service_seconds() -> float:
	var base := float(data().get("service_seconds", 3.2))
	var mgr_id := BusinessData.manager_id(id)
	var mgr_speed := ManagerData.speed_multiplier(mgr_id, manager_rank)
	var speed_mult := (1.0 + 0.14 * float(speed_level) + 0.008 * float(level - 1)) * mgr_speed
	return clampf(base / maxf(1.0, speed_mult), 0.55, 8.0)


func throughput() -> float:
	return 60.0 / maxf(0.55, service_seconds())


## Milestone multiplier: x2 at Lv 10, 25, 50, 75, 100 (up to x32!).
func milestone_multiplier() -> float:
	return pow(2.0, float(BusinessData.milestones_reached(level)))


func quality() -> float:
	return (1.0 + 0.14 * float(level - 1)) * (1.0 + 0.30 * float(quality_level)) * milestone_multiplier()


func price() -> float:
	return float(data().get("base_price", 20.0)) * quality()


func upkeep_per_minute() -> float:
	return 0.0


func demand_per_minute(traffic: float) -> float:
	var base := float(data().get("base_demand", 10.0))
	return base * traffic * (1.0 + 0.06 * float(level - 1) + 0.25 * float(capacity_level))


func served_per_minute(traffic: float) -> float:
	if not unlocked:
		return 0.0
	var bay_rate := float(active_bays()) * (60.0 / service_seconds())
	return minf(demand_per_minute(traffic), bay_rate)


func revenue_per_minute(traffic: float) -> float:
	return served_per_minute(traffic) * price()


func profit_per_minute(traffic: float) -> float:
	return maxf(0.0, revenue_per_minute(traffic) - upkeep_per_minute())


## Required manager level for full hands-free automation at current renovation stage.
func required_manager_level() -> int:
	return BusinessData.automation_manager_level(level)


func is_automated() -> bool:
	return unlocked and manager_rank >= required_manager_level()


## Manager income multiplier; unautomated facilities still operate at 75 % pace
## into their local Safe/Vault until collected or automated.
func efficiency() -> float:
	var mgr_id := BusinessData.manager_id(id)
	if manager_rank <= 0:
		return 0.75
	var mult := ManagerData.income_multiplier(mgr_id, manager_rank)
	if not is_automated():
		return maxf(1.0, mult * 0.65)
	return mult


func net_per_minute(traffic: float) -> float:
	if not unlocked:
		return 0.0
	return profit_per_minute(traffic) * efficiency()


func net_per_second(traffic: float) -> float:
	return net_per_minute(traffic) / 60.0


func vault_capacity(traffic: float = 1.0) -> float:
	return maxf(120.0, net_per_minute(maxf(0.5, traffic)) * (1.2 + 0.4 * float(quality_level)))


func vault_fill_ratio(traffic: float = 1.0) -> float:
	return clampf(vault_cash / maxf(1.0, vault_capacity(traffic)), 0.0, 1.0)


func branch_level(branch: String) -> int:
	match branch:
		"capacity":
			return capacity_level
		"speed":
			return speed_level
		"quality":
			return quality_level
	return 0


func max_branch_for(branch: String) -> int:
	if branch == "capacity":
		return maxi(0, BusinessData.max_bays(id) - 1)
	return BusinessData.MAX_BRANCH_LEVEL


func upgrade_cost() -> float:
	if level >= BusinessData.MAX_LEVEL:
		return 0.0
	return round(float(data().get("upgrade_cost", 35.0)) * pow(1.135, float(level - 1)))


func multi_upgrade_cost(steps: int) -> float:
	var total := 0.0
	var count := clampi(steps, 1, BusinessData.MAX_LEVEL - level)
	var base := float(data().get("upgrade_cost", 35.0))
	for i in count:
		total += round(base * pow(1.135, float(level - 1 + i)))
	return total


func branch_cost(branch: String) -> float:
	if branch_level(branch) >= max_branch_for(branch):
		return 0.0
	return round(float(data().get("branch_cost", 200.0)) * pow(2.15, float(branch_level(branch))))


func manager_cost() -> float:
	if manager_rank >= BusinessData.MAX_MANAGER:
		return 0.0
	return round(float(data().get("manager_cost", 250.0)) * pow(1.85, float(manager_rank)))


func can_upgrade_level() -> bool:
	return level < BusinessData.MAX_LEVEL


func can_upgrade_branch(branch: String) -> bool:
	var cap := max_branch_for(branch)
	if branch_level(branch) >= cap:
		return false
	if branch == "capacity":
		return unlocked
	return branch_level(branch) < mini(level, cap)


func can_hire_manager() -> bool:
	return manager_rank < BusinessData.MAX_MANAGER


func upgrade_level() -> void:
	if can_upgrade_level():
		level += 1


func upgrade_branch(branch: String) -> void:
	if not can_upgrade_branch(branch):
		return
	match branch:
		"capacity":
			capacity_level += 1
		"speed":
			speed_level += 1
		"quality":
			quality_level += 1


func hire_manager() -> void:
	if can_hire_manager():
		manager_rank += 1


func serialize() -> Dictionary:
	return {
		"id": id,
		"unlocked": unlocked,
		"level": level,
		"capacity": capacity_level,
		"speed": speed_level,
		"quality": quality_level,
		"manager": manager_rank,
		"vault": vault_cash,
		"customers": customers_total,
		"revenue": revenue_total,
	}


func apply_save(saved: Dictionary) -> void:
	unlocked = bool(saved.get("unlocked", unlocked))
	level = clampi(int(saved.get("level", level)), 1, BusinessData.MAX_LEVEL)
	capacity_level = clampi(int(saved.get("capacity", 0)), 0, max_branch_for("capacity"))
	speed_level = clampi(int(saved.get("speed", 0)), 0, BusinessData.MAX_BRANCH_LEVEL)
	quality_level = clampi(int(saved.get("quality", 0)), 0, BusinessData.MAX_BRANCH_LEVEL)
	manager_rank = clampi(int(saved.get("manager", 0)), 0, BusinessData.MAX_MANAGER)
	vault_cash = maxf(0.0, float(saved.get("vault", 0.0)))
	customers_total = maxf(0.0, float(saved.get("customers", 0.0)))
	revenue_total = maxf(0.0, float(saved.get("revenue", 0.0)))
