class_name BusinessState
extends RefCounted
## One business and its progress: level, the three upgrade branches and the
## manager. All of the economy for a single building lives here.

var id := ""
var unlocked := false
var level := 1
var capacity_level := 0
var speed_level := 0
var quality_level := 0
var manager_rank := 0
var customers_total := 0.0
var revenue_total := 0.0


func _init(business_id: String = "", start_unlocked: bool = false) -> void:
	id = business_id
	unlocked = start_unlocked


func data() -> Dictionary:
	return BusinessData.data(id)


func capacity() -> float:
	var base := float(data().get("base_capacity", 1.0))
	return base * (1.0 + 0.3 * (level - 1)) * (1.0 + 0.2 * capacity_level)


func throughput() -> float:
	return 1.0 + 0.08 * (level - 1) + 0.12 * speed_level


func quality() -> float:
	return 1.0 + 0.1 * (level - 1) + 0.15 * quality_level


func price() -> float:
	return float(data().get("base_price", 1.0)) * quality()


func upkeep_per_minute() -> float:
	var base := float(data().get("base_upkeep", 0.0))
	return base * (1.0 + 0.12 * (level - 1))


func demand_per_minute(traffic: float) -> float:
	return float(data().get("base_demand", 0.0)) * traffic


func served_per_minute(traffic: float) -> float:
	return minf(demand_per_minute(traffic), capacity() * throughput())


func revenue_per_minute(traffic: float) -> float:
	return served_per_minute(traffic) * price()


func profit_per_minute(traffic: float) -> float:
	return maxf(0.0, revenue_per_minute(traffic) - upkeep_per_minute())


## A business without a manager only runs at 60 %; each manager rank adds 10 %.
func efficiency() -> float:
	return 0.6 + 0.1 * float(manager_rank)


func net_per_minute(traffic: float) -> float:
	return profit_per_minute(traffic) * efficiency()


func net_per_second(traffic: float) -> float:
	return net_per_minute(traffic) / 60.0


func branch_level(branch: String) -> int:
	match branch:
		"capacity":
			return capacity_level
		"speed":
			return speed_level
		"quality":
			return quality_level
	return 0


func upgrade_cost() -> float:
	if level >= BusinessData.MAX_LEVEL:
		return 0.0
	return float(data().get("upgrade_cost", 0.0)) * pow(1.75, level - 1)


func branch_cost(branch: String) -> float:
	if branch_level(branch) >= BusinessData.MAX_BRANCH_LEVEL:
		return 0.0
	return float(data().get("branch_cost", 0.0)) * pow(1.6, branch_level(branch))


func manager_cost() -> float:
	if manager_rank >= BusinessData.MAX_MANAGER:
		return 0.0
	return float(data().get("manager_cost", 0.0)) * pow(2.0, manager_rank)


func can_upgrade_level() -> bool:
	return level < BusinessData.MAX_LEVEL


## A branch may never be ahead of the building itself.
func can_upgrade_branch(branch: String) -> bool:
	return branch_level(branch) < mini(level, BusinessData.MAX_BRANCH_LEVEL)


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
		"customers": customers_total,
		"revenue": revenue_total,
	}


func apply_save(data: Dictionary) -> void:
	unlocked = bool(data.get("unlocked", unlocked))
	level = clampi(int(data.get("level", level)), 1, BusinessData.MAX_LEVEL)
	capacity_level = clampi(int(data.get("capacity", 0)), 0, BusinessData.MAX_BRANCH_LEVEL)
	speed_level = clampi(int(data.get("speed", 0)), 0, BusinessData.MAX_BRANCH_LEVEL)
	quality_level = clampi(int(data.get("quality", 0)), 0, BusinessData.MAX_BRANCH_LEVEL)
	manager_rank = clampi(int(data.get("manager", 0)), 0, BusinessData.MAX_MANAGER)
	customers_total = maxf(0.0, float(data.get("customers", 0.0)))
	revenue_total = maxf(0.0, float(data.get("revenue", 0.0)))
