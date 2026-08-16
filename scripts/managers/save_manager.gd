extends Node
## Versioned, defensive and atomic local save storage. No personal data leaves the device.

signal data_changed
signal data_reset

const SAVE_PATH := "user://ruby_run_save.json"
const BACKUP_PATH := "user://ruby_run_save.backup.json"
const SAVE_VERSION := 1

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": 0,
		"best_score": 0,
		"unlocked_skins": ["classic"],
		"selected_skin": "classic",
		"daily": {"day": 0, "last_claim_epoch": 0, "last_seen_epoch": 0},
		"settings": {"music": true, "sound": true, "vibration": true},
		"stats": {"runs": 0, "coins_collected": 0}
	}


func load_data() -> void:
	data = _read_valid(SAVE_PATH)
	if data.is_empty():
		data = _read_valid(BACKUP_PATH)
	if data.is_empty():
		data = defaults()
	_sanitize()
	data_changed.emit()


func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _sanitize() -> void:
	var clean := defaults()
	clean["coins"] = maxi(0, int(data.get("coins", 0)))
	clean["best_score"] = maxi(0, int(data.get("best_score", 0)))
	var unlocked: Array = data.get("unlocked_skins", ["classic"])
	clean["unlocked_skins"] = unlocked.filter(func(id): return id is String)
	if not clean["unlocked_skins"].has("classic"):
		clean["unlocked_skins"].append("classic")
	clean["selected_skin"] = str(data.get("selected_skin", "classic"))
	if not clean["unlocked_skins"].has(clean["selected_skin"]):
		clean["selected_skin"] = "classic"
	var settings: Dictionary = data.get("settings", {})
	for key in clean["settings"]:
		clean["settings"][key] = bool(settings.get(key, true))
	var daily: Dictionary = data.get("daily", {})
	clean["daily"] = {
		"day": clampi(int(daily.get("day", 0)), 0, 6),
		"last_claim_epoch": maxi(0, int(daily.get("last_claim_epoch", 0))),
		"last_seen_epoch": maxi(0, int(daily.get("last_seen_epoch", 0)))
	}
	var stats: Dictionary = data.get("stats", {})
	clean["stats"] = {
		"runs": maxi(0, int(stats.get("runs", 0))),
		"coins_collected": maxi(0, int(stats.get("coins_collected", 0)))
	}
	data = clean


func save() -> bool:
	var json := JSON.stringify(data, "  ")
	var temp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to open local save temp file")
		return false
	file.store_string(json)
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	DirAccess.remove_absolute(SAVE_PATH)
	var error := DirAccess.rename_absolute(temp_path, SAVE_PATH)
	if error != OK:
		push_error("Unable to commit local save: %s" % error)
		return false
	data_changed.emit()
	return true


func add_coins(amount: int) -> void:
	data.coins = maxi(0, int(data.coins) + amount)
	save()


func submit_score(score: int) -> bool:
	if score <= int(data.best_score):
		return false
	data.best_score = score
	save()
	return true


func reset_all() -> void:
	data = defaults()
	for path in [SAVE_PATH, BACKUP_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	save()
	data_reset.emit()
