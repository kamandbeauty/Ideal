class_name Profile
extends RefCounted
## Everything one player owns across their Roadside Empire: every territory
## station they have opened, the active one, and the daily login streak.

signal changed
signal travelled(town_id: String)

const VERSION := 3
const FIRST_TOWN := "desert"
const SECONDS_PER_DAY := 86400.0

var active_town := FIRST_TOWN
var towns: Dictionary = {}
var streak := 0
var bonus_day := -1
var best_reputation := 0


func _init() -> void:
	town(FIRST_TOWN)


func town(id: String) -> TownState:
	if not TownData.has_town(id):
		return null
	if not towns.has(id):
		towns[id] = TownState.new(id)
		(towns[id] as TownState).changed.connect(_on_town_changed)
	return towns[id]


func active() -> TownState:
	return town(active_town)


func town_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in TownData.ORDER:
		if towns.has(id):
			ids.append(id)
	return ids


func reputation() -> float:
	var best := 0.0
	for id in towns:
		best = maxf(best, (towns[id] as TownState).reputation)
	return best


func best_star_level() -> int:
	var best := 1
	for id in towns:
		best = maxi(best, (towns[id] as TownState).star_level())
	return best


func total_income_per_minute() -> float:
	var total := 0.0
	for id in towns:
		total += (towns[id] as TownState).net_per_minute()
	return total


func unlocked(id: String) -> bool:
	if not TownData.has_town(id):
		return false
	if id == FIRST_TOWN:
		return true
	return best_star_level() >= TownData.star_required(id) or reputation() >= TownData.reputation_required(id)


func can_travel(id: String) -> bool:
	return unlocked(id) and id != active_town


func travel(id: String) -> bool:
	if not unlocked(id):
		return false
	var prev_gems := active().gems
	var prev_bourbon := active().bourbon
	var prev_cards := active().manager_cards.duplicate(true)
	var dest := town(id)
	# Gems, Bourbon and Manager Cards are empire-wide currencies!
	dest.gems = maxi(dest.gems, prev_gems)
	dest.bourbon = maxi(dest.bourbon, prev_bourbon)
	for mgr_id in prev_cards:
		dest.manager_cards[mgr_id] = maxi(int(dest.manager_cards.get(mgr_id, 0)), int(prev_cards[mgr_id]))
	active_town = id
	changed.emit()
	travelled.emit(id)
	return true


func visited(id: String) -> bool:
	return towns.has(id)


func _on_town_changed() -> void:
	changed.emit()


static func today_index() -> int:
	return int(floor(Time.get_unix_time_from_system() / SECONDS_PER_DAY))


func bonus_ready(today: int = -1) -> bool:
	var day := today if today >= 0 else today_index()
	return day > bonus_day


func claim_daily(today: int = -1) -> Dictionary:
	var day := today if today >= 0 else today_index()
	if day <= bonus_day:
		return {}
	var previous := bonus_day
	bonus_day = day
	streak = DailyBonus.next_streak(previous, streak, day)
	var town_state := active()
	var earned := DailyBonus.cash(town_state.net_per_minute(), streak)
	var gems := DailyBonus.gems(streak)
	var bourbon_bonus := 15 + streak * 5
	town_state.cash += earned
	town_state.lifetime_cash_earned += earned
	town_state.gems += gems
	town_state.bourbon += bourbon_bonus
	town_state.cash_changed.emit(town_state.cash)
	changed.emit()
	return {
		"day": day,
		"streak": streak,
		"cash": earned,
		"gems": gems,
		"bourbon": bourbon_bonus,
		"multiplier": DailyBonus.multiplier(streak),
	}


func claim_offline(seconds: float) -> Dictionary:
	var total := 0.0
	var breakdown: Array = []
	for id in TownData.ORDER:
		if not towns.has(id):
			continue
		var state: TownState = towns[id]
		if state.offline_net_per_minute() <= 0.0:
			continue
		var report := state.apply_offline(seconds)
		var earned := float(report.get("earnings", 0.0))
		if earned > 0.0:
			breakdown.append({"town": id, "earnings": earned})
			total += earned
	return {
		"seconds": clampf(seconds, 0.0, TownState.OFFLINE_CAP_SECONDS),
		"earnings": total,
		"breakdown": breakdown,
	}


func serialize() -> Dictionary:
	var stored: Dictionary = {}
	for id in towns:
		stored[id] = (towns[id] as TownState).serialize()
	return {
		"version": VERSION,
		"active": active_town,
		"towns": stored,
		"streak": streak,
		"bonus_day": bonus_day,
		"best_reputation": best_reputation,
	}


func apply_save(data: Dictionary) -> bool:
	if not data.has("towns"):
		return _apply_legacy(data)
	var ver := int(data.get("version", 0))
	if ver < 2 or ver > VERSION:
		return false
	var stored: Variant = data.get("towns", {})
	if typeof(stored) != TYPE_DICTIONARY or (stored as Dictionary).is_empty():
		return false
	towns.clear()
	for id in stored:
		var town_key := str(id)
		if not TownData.has_town(town_key):
			continue
		var entry: Variant = stored[id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var town_state := TownState.new(town_key)
		if not town_state.apply_save(entry as Dictionary):
			continue
		towns[town_key] = town_state
		town_state.changed.connect(_on_town_changed)
	if towns.is_empty():
		return false
	active_town = str(data.get("active", FIRST_TOWN))
	if not towns.has(active_town):
		active_town = FIRST_TOWN if towns.has(FIRST_TOWN) else str(towns.keys()[0])
	town(active_town)
	streak = clampi(int(data.get("streak", 0)), 0, DailyBonus.MAX_STREAK)
	bonus_day = int(data.get("bonus_day", -1))
	best_reputation = maxi(0, int(data.get("best_reputation", 0)))
	changed.emit()
	return true


func _apply_legacy(data: Dictionary) -> bool:
	var id := str(data.get("town_id", FIRST_TOWN))
	if not TownData.has_town(id):
		id = FIRST_TOWN
	var state := TownState.new(id)
	if not state.apply_save(data):
		return false
	towns = {id: state}
	state.changed.connect(_on_town_changed)
	active_town = id
	streak = 0
	bonus_day = -1
	changed.emit()
	return true
