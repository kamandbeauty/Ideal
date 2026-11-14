class_name SaveManager
extends RefCounted
## Versioned JSON saves with a backup copy, written to `user://saves/`.

const SAVE_DIR := "user://saves"
const SAVE_PATH := "user://saves/profile_01.json"
const BACKUP_PATH := "user://saves/backup_01.json"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


static func save(town: TownState) -> bool:
	if town == null:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var payload := town.serialize()
	payload["last_seen"] = int(Time.get_unix_time_from_system())
	var text := JSON.stringify(payload)

	if FileAccess.file_exists(SAVE_PATH):
		var previous := FileAccess.get_file_as_string(SAVE_PATH)
		if not previous.is_empty():
			_write(BACKUP_PATH, previous)
	return _write(SAVE_PATH, text)


static func load_town() -> TownState:
	var data := _read(SAVE_PATH)
	if data.is_empty():
		data = _read(BACKUP_PATH)
	if data.is_empty():
		return null
	if not TownData.has_town(str(data.get("town", ""))):
		return null

	var town := TownState.new(str(data["town"]))
	if not town.apply_save(data):
		return null

	var last_seen := int(data.get("last_seen", 0))
	if last_seen > 0:
		var away := float(Time.get_unix_time_from_system()) - float(last_seen)
		town.pending_offline_seconds = town.offline_seconds_capped(away)
	return town


static func delete() -> void:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
