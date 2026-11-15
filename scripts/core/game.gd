extends Node
## Session state: the player's profile, the town they are standing in, saving,
## offline income and travel between towns.

signal town_loaded
signal travelled(town_id: String)

var profile: Profile
var town: TownState
var offline_seconds := 0.0


func start_new_game() -> void:
	profile = Profile.new()
	town = profile.active()
	offline_seconds = 0.0
	SaveManager.save(profile)
	town_loaded.emit()


## Returns true when an existing save was picked up.
func continue_game() -> bool:
	profile = SaveManager.load_profile()
	if profile == null:
		start_new_game()
		return false
	town = profile.active()
	offline_seconds = town.pending_offline_seconds
	for id in profile.towns:
		(profile.towns[id] as TownState).pending_offline_seconds = 0.0
	town_loaded.emit()
	return true


func ensure_town() -> void:
	if profile == null or town == null:
		continue_game()


func save_game() -> bool:
	if profile == null:
		if town == null:
			return false
		return SaveManager.save(town)
	return SaveManager.save(profile)


func has_save() -> bool:
	return SaveManager.has_save()


## Moves the player to another town on the world map. False when it is locked.
func travel_to(town_id: String) -> bool:
	ensure_town()
	if profile == null or not profile.unlocked(town_id):
		return false
	save_game()
	profile.travel(town_id)
	town = profile.active()
	offline_seconds = 0.0
	save_game()
	travelled.emit(town_id)
	town_loaded.emit()
	return true


## Credits the time away, once, across every town with a manager, and returns
## the report for the HUD.
func claim_offline() -> Dictionary:
	if profile == null or offline_seconds <= 0.0:
		offline_seconds = 0.0
		return {}
	var report := profile.claim_offline(offline_seconds)
	offline_seconds = 0.0
	save_game()
	return report
