extends Node
## Session state: the town the player is running, saving and offline income.

signal town_loaded

var town: TownState
var offline_seconds := 0.0


func start_new_game() -> void:
	town = TownState.new("desert")
	offline_seconds = 0.0
	SaveManager.save(town)
	town_loaded.emit()


## Returns true when an existing save was picked up.
func continue_game() -> bool:
	var loaded := SaveManager.load_town()
	if loaded == null:
		start_new_game()
		return false
	town = loaded
	offline_seconds = loaded.pending_offline_seconds
	loaded.pending_offline_seconds = 0.0
	town_loaded.emit()
	return true


func ensure_town() -> void:
	if town == null:
		continue_game()


func save_game() -> bool:
	if town == null:
		return false
	return SaveManager.save(town)


func has_save() -> bool:
	return SaveManager.has_save()


## Credits the time away, once, and returns the report for the HUD.
func claim_offline() -> Dictionary:
	if town == null or offline_seconds <= 0.0:
		offline_seconds = 0.0
		return {}
	var report := town.apply_offline(offline_seconds)
	offline_seconds = 0.0
	save_game()
	return report
