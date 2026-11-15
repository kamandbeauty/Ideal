class_name Profile
extends RefCounted
## Everything one player owns: every town they have opened, the one they are
## standing in, and the daily streak.
##
## One profile is one save file. Towns are created lazily, so a fresh profile
## only ever holds the desert and gains a town the first time the player travels
## to it. Reputation is *shared*: it is the best reputation of any town, which is
## what unlocks the next town on the world map.

signal changed
signal travelled(town_id: String)

const VERSION := 2
const FIRST_TOWN := "desert"
const SECONDS_PER_DAY := 86400.0

var active_town := FIRST_TOWN
var towns: Dictionary = {}
var streak := 0
var bonus_day := -1          ## Unix day index the last chest was opened on
var best_reputation := 0


func _init() -> void:
	town(FIRST_TOWN)


# --- Towns -----------------------------------------------------------------

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


## Reputation is the profile's standing, not a town's: the highest of them all.
func reputation() -> float:
	var best := 0.0
	for id in towns:
		best = maxf(best, (towns[id] as TownState).reputation)
	return best


func total_income_per_minute() -> float:
	var total := 0.0
	for id in towns:
		total += (towns[id] as TownState).net_per_minute()
	return total


func unlocked(id: String) -> bool:
	if not TownData.has_town(id):
		return false
	return reputation() >= TownData.reputation_required(id)


func can_travel(id: String) -> bool:
	return unlocked(id) and id != active_town


func travel(id: String) -> bool:
	if not unlocked(id):
		return false
	town(id)
	active_town = id
	changed.emit()
	travelled.emit(id)
	return true


## Towns the player has actually been to (the lazy ones do not count).
func visited(id: String) -> bool:
	return towns.has(id)


func _on_town_changed() -> void:
	changed.emit()


# --- Daily chest ------------------------------------------------------------

static func today_index() -> int:
	return int(floor(Time.get_unix_time_from_system() / SECONDS_PER_DAY))


func bonus_ready(today: int = -1) -> bool:
	var day := today if today >= 0 else today_index()
	return day > bonus_day


## Opens the chest for today. Returns {} when it is not ready yet.
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
	town_state.cash += earned
	town_state.gems += gems
	town_state.cash_changed.emit(town_state.cash)
	changed.emit()
	return {
		"day": day,
		"streak": streak,
		"cash": earned,
		"gems": gems,
		"multiplier": DailyBonus.multiplier(streak),
	}


# --- Offline ----------------------------------------------------------------

## Credits every town that has managers, once, and reports the breakdown.
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


# --- Saving ----------------------------------------------------------------

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
	# Version 1 was a single town in the same file; wrap it instead of dropping
	# the player's progress.
	if not data.has("towns"):
		return _apply_legacy(data)
	if int(data.get("version", 0)) != VERSION:
		return false
	var stored: Variant = data.get("towns", {})
	if typeof(stored) != TYPE_DICTIONARY or (stored as Dictionary).is_empty():
		return false
	towns.clear()
	for id in stored:
		var entry: Variant = stored[id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var town_state := TownState.new(str(id))
		if not town_state.apply_save(entry as Dictionary):
			continue
		towns[str(id)] = town_state
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
	var town_state := TownState.new(str(data.get("town", FIRST_TOWN)))
	if not town_state.apply_save(data):
		return false
	towns.clear()
	towns[town_state.town_id] = town_state
	town_state.changed.connect(_on_town_changed)
	active_town = town_state.town_id
	streak = 0
	bonus_day = -1
	best_reputation = int(town_state.reputation)
	changed.emit()
	return true
