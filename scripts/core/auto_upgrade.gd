class_name AutoUpgrade
extends RefCounted
## Managers do their own shopping. Every town tick a managed business may spend
## part of the takings on itself - the cheapest sensible upgrade it can afford,
## as long as a cash reserve stays in the till for the player.
##
## The rule lives here (not in the UI) so it can be tested headlessly and so the
## player-facing upgrades and the automatic ones share one code path.

## How much cash is always left alone: a couple of minutes of income, never
## less than a small floor, so an idle night cannot drain the till.
const RESERVE_SECONDS := 90.0
const RESERVE_FLOOR := 150.0

const KIND_LEVEL := "level"
const KIND_BRANCH := "branch"
const KIND_MANAGER := "manager"


static func reserve(state) -> float:
	if state == null:
		return RESERVE_FLOOR
	return maxf(RESERVE_FLOOR, state.net_per_minute() * RESERVE_SECONDS / 60.0)


## Every upgrade a manager could buy, cheapest first.
static func candidates(state) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state == null:
		return result
	for id in state.business_ids():
		var business = state.business(id)
		if business == null or not business.unlocked or business.manager_rank <= 0:
			continue
		if business.can_upgrade_level():
			result.append({
				"id": id, "kind": KIND_LEVEL, "branch": "",
				"cost": business.upgrade_cost() * state.cost_scale(),
			})
		for branch in BusinessData.BRANCHES:
			if business.can_upgrade_branch(branch):
				result.append({
					"id": id, "kind": KIND_BRANCH, "branch": branch,
					"cost": business.branch_cost(branch) * state.cost_scale(),
				})
		if business.can_hire_manager():
			result.append({
				"id": id, "kind": KIND_MANAGER, "branch": "",
				"cost": business.manager_cost() * state.cost_scale(),
			})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["cost"]) < float(b["cost"])
	)
	return result


## The step a manager would take right now, or `{}` when nothing is affordable
## without eating into the reserve.
static func next_step(state) -> Dictionary:
	if state == null:
		return {}
	var budget: float = float(state.cash) - reserve(state)
	if budget <= 0.0:
		return {}
	for candidate in candidates(state):
		if float(candidate["cost"]) <= budget:
			return candidate
	return {}


## Buys the step and reports what happened: `{}` when there was nothing to do,
## otherwise the candidate plus the level/branch it reached.
static func apply(state) -> Dictionary:
	var step := next_step(state)
	if step.is_empty():
		return {}
	var id := String(step["id"])
	var kind := String(step["kind"])
	var business = state.business(id)
	var bought := false
	match kind:
		KIND_LEVEL:
			bought = state.upgrade_business(id)
		KIND_BRANCH:
			bought = state.upgrade_branch(id, String(step["branch"]))
		KIND_MANAGER:
			bought = state.hire_manager(id)
	if not bought:
		return {}
	step["level"] = business.level
	step["branch_level"] = business.branch_level(String(step["branch"])) if kind == KIND_BRANCH else 0
	step["manager_rank"] = business.manager_rank
	return step
