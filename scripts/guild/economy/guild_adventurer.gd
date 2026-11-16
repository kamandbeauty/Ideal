class_name GuildAdventurer
extends RefCounted
## One adventurer on the guild's roster: a class, a rank, and wherever they are
## right now - standing by the board, in the field, or back with a full pack.
##
## The adventurer owns no gold and no goods beyond the pack they came back with;
## the desk (GuildMissionDesk) does the paying, so a rank cannot quietly pay itself.

const IDLE := "idle"
const AWAY := "away"
const RETURNED := "returned"

var class_id := "warrior"
var rank := "F"
var state := IDLE
var mission_id := ""
var time_left := 0.0
var duration := 0.0
var loot: Dictionary = {}


func _init(adventurer_class: String = "warrior", adventurer_rank: String = "F") -> void:
	class_id = adventurer_class if GuildCharacter.STYLES.has(adventurer_class) else "warrior"
	rank = adventurer_rank if GuildMissions.RANKS.has(adventurer_rank) else "F"


func is_free() -> bool:
	return state == IDLE


func is_away() -> bool:
	return state == AWAY


func has_loot() -> bool:
	return not loot.is_empty()


func can_take(mission: String) -> bool:
	return is_free() and GuildMissions.exists(mission) and GuildMissions.fits_rank(rank, mission)


## Sends them out. The desk has already taken the fee by the time this is called.
func send_out(mission: String) -> void:
	mission_id = mission if GuildMissions.exists(mission) else ""
	duration = float(GuildMissions.mission(mission_id).get("duration", 30.0))
	time_left = duration
	state = AWAY
	loot.clear()


func mission_name_key() -> String:
	return GuildMissions.name_key(mission_id)


## Advances the clock. Returns true on the step the adventurer comes back.
func tick(delta: float) -> bool:
	if state != AWAY:
		return false
	time_left = maxf(time_left - delta, 0.0)
	return time_left <= 0.0


func report() -> String:
	return "%s %s state=%s mission=%s left=%.1f loot=%s" % [
		class_id,
		rank,
		state,
		mission_id if not mission_id.is_empty() else "-",
		time_left,
		str(loot),
	]
