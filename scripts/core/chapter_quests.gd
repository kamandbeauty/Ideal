class_name ChapterQuests
extends RefCounted
## Builds and evaluates the 3 side-by-side Roadside Empire quest cards below
## the Chapter Progress Bar (Chapter X, 0..9 tasks, 3 milestone chests).

const TASKS_PER_CHAPTER := 9
const SLOT_COUNT := 3
const MILESTONE_STEPS: Array[int] = [3, 6, 9]


static func make_slot(slot_index: int, state, serial: int) -> Dictionary:
	var income_min := maxf(80.0, float(state.net_per_minute()))
	var scale := maxf(1.0, pow(1.22, float(serial)))
	match slot_index % 3:
		0:
			return _make_build_quest(state, income_min, scale, serial)
		1:
			return _make_earn_quest(state, income_min, scale, serial)
	return _make_ops_quest(state, income_min, scale, serial)


static func _make_build_quest(state, income_min: float, _scale: float, serial: int) -> Dictionary:
	for id in BusinessData.ORDER:
		var b = state.business(id)
		if b != null and not b.unlocked and int(state.star_level()) >= BusinessData.star_required(id):
			var unlock_price: float = float(state.unlock_cost(id))
			if unlock_price <= maxf(600.0, float(state.cash) * 2.5 + income_min * 3.0):
				return {
					"kind": "unlock_facility",
					"target": id,
					"start": 0.0,
					"goal": 1.0,
					"cash": round(maxf(220.0, unlock_price * 0.55)),
					"bourbon": 12 + (serial % 4) * 4,
					"gems": 2,
				}
	var pick_id := "gas_station"
	var lowest_lvl := 999
	for id in state.unlocked_ids():
		var b = state.business(id)
		if b.level < BusinessData.MAX_LEVEL and b.level < lowest_lvl:
			lowest_lvl = b.level
			pick_id = id
	var cur_lvl: int = int(state.business(pick_id).level)
	var goal_lvl := mini(BusinessData.MAX_LEVEL, cur_lvl + (4 if cur_lvl < 15 else 5))
	if goal_lvl <= cur_lvl:
		return _make_earn_quest(state, income_min, 1.0, serial)
	return {
		"kind": "facility_level",
		"target": pick_id,
		"start": float(cur_lvl),
		"goal": float(goal_lvl),
		"cash": round(maxf(180.0, income_min * 1.4)),
		"bourbon": 10 + (serial % 3) * 5,
		"gems": 0,
	}


static func _make_earn_quest(state, income_min: float, _scale: float, serial: int) -> Dictionary:
	var target_earn := roundf(maxf(250.0, income_min * 1.6))
	return {
		"kind": "earn_cash",
		"target": "",
		"start": float(state.lifetime_cash_earned),
		"goal": target_earn,
		"cash": roundf(target_earn * 0.45),
		"bourbon": 10 + (serial % 4) * 3,
		"gems": 2 if serial % 3 == 2 else 0,
	}


static func _make_ops_quest(state, income_min: float, _scale: float, serial: int) -> Dictionary:
	if state.managers_hired == 0 and serial >= 1:
		return {
			"kind": "hire_any_manager",
			"target": "",
			"start": 0.0,
			"goal": 1.0,
			"cash": round(maxf(300.0, income_min * 1.5)),
			"bourbon": 18,
			"gems": 3,
		}
	if serial % 3 == 1:
		return {
			"kind": "upgrade_equipment",
			"target": "",
			"start": float(state.branches_total),
			"goal": 1.0,
			"cash": round(maxf(260.0, income_min * 1.3)),
			"bourbon": 14,
			"gems": 0,
		}
	var count := float(8 + mini(22, serial * 2))
	return {
		"kind": "serve_vehicles",
		"target": "",
		"start": float(state.customers),
		"goal": count,
		"cash": round(maxf(220.0, income_min * 1.2)),
		"bourbon": 12,
		"gems": 2 if serial % 4 == 0 else 0,
	}


static func current_value(quest: Dictionary, state) -> float:
	var kind := str(quest.get("kind", ""))
	var target := str(quest.get("target", ""))
	var start := float(quest.get("start", 0.0))
	var goal := maxf(1.0, float(quest.get("goal", 1.0)))
	match kind:
		"unlock_facility":
			var b = state.business(target)
			return 1.0 if (b != null and b.unlocked) else 0.0
		"facility_level":
			var b2 = state.business(target)
			return clampf(float(b2.level) if b2 != null else 0.0, 0.0, goal)
		"earn_cash":
			return clampf(float(state.lifetime_cash_earned) - start, 0.0, goal)
		"hire_any_manager":
			return 1.0 if state.managers_hired >= 1 else 0.0
		"upgrade_equipment":
			return clampf(float(state.branches_total) - start, 0.0, goal)
		"serve_vehicles":
			return clampf(float(state.customers) - start, 0.0, goal)
	return 0.0


static func is_complete(quest: Dictionary, state) -> bool:
	if quest.is_empty():
		return false
	return current_value(quest, state) + 0.001 >= float(quest.get("goal", 1.0))


static func icon_for(quest: Dictionary) -> String:
	var kind := str(quest.get("kind", ""))
	var target := str(quest.get("target", ""))
	if not target.is_empty():
		return BusinessData.icon(target)
	match kind:
		"earn_cash":
			return "💵"
		"hire_any_manager":
			return "🧑‍🔧"
		"upgrade_equipment":
			return "🔧"
		"serve_vehicles":
			return "🚗"
	return "📋"


static func progress_label(quest: Dictionary, state) -> String:
	var cur := floorf(current_value(quest, state))
	var goal := maxf(1.0, float(quest.get("goal", 1.0)))
	return "%s/%s" % [_fmt_short(cur), _fmt_short(goal)]


static func title_text(quest: Dictionary) -> String:
	var kind := str(quest.get("kind", ""))
	var target := str(quest.get("target", ""))
	var goal := float(quest.get("goal", 1.0))
	match kind:
		"unlock_facility":
			return _tr("quest.unlock", [_tr("business.%s.name" % target)])
		"facility_level":
			return _tr("quest.level", [
				_tr("business.%s.name" % target),
				_fmt_num(goal),
			])
		"earn_cash":
			return _tr("quest.earn", [_fmt_short(goal)])
		"hire_any_manager":
			return _tr("quest.manager")
		"upgrade_equipment":
			return _tr("quest.equip")
		"serve_vehicles":
			return _tr("quest.serve", [_fmt_num(goal)])
	return _tr("quest.earn", [_fmt_short(goal)])


static func _tr(key: String, args: Array = []) -> String:
	if App != null:
		return App.t(key, args)
	return L10n.translate("en", key, args)


static func _fmt_short(val: float) -> String:
	if App != null:
		return App.format_short(val)
	if val >= 1000.0:
		return "%.1fK" % (val / 1000.0)
	return "%d" % int(round(val))


static func _fmt_num(val: float) -> String:
	if App != null:
		return App.format_number(val)
	return "%d" % int(round(val))
