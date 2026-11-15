class_name SaveManager
extends RefCounted
## Versioned JSON saves with a backup copy, written to `user://saves/`.
##
## The file holds a whole profile (every town, the active one, the daily streak).
## A version 1 file - a single town - is still read and wrapped, so nobody loses
## progress when the world map arrives.

const SAVE_DIR := "user://saves"
const SAVE_PATH := "user://saves/profile_01.json"
const BACKUP_PATH := "user://saves/backup_01.json"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


## Accepts a `Profile` (the normal case) or a bare `TownState`, which the tests
## and the older call sites still use.
static func save(value) -> bool:
	var profile: Profile = null
	if value is Profile:
		profile = value as Profile
	elif value is TownState:
		profile = Profile.new()
		profile.towns = {value.town_id: value}
		profile.active_town = value.town_id
	if profile == null:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var payload := profile.serialize()
	payload["last_seen"] = int(Time.get_unix_time_from_system())
	var text := JSON.stringify(payload)

	if FileAccess.file_exists(SAVE_PATH):
		var previous := FileAccess.get_file_as_string(SAVE_PATH)
		if not previous.is_empty():
			_write(BACKUP_PATH, previous)
	return _write(SAVE_PATH, text)


static func load_profile() -> Profile:
	var data := _read(SAVE_PATH)
	if data.is_empty():
		data = _read(BACKUP_PATH)
	if data.is_empty():
		return null

	var profile := Profile.new()
	if not profile.apply_save(data):
		return null

	var last_seen := int(data.get("last_seen", 0))
	if last_seen > 0:
		var away := float(Time.get_unix_time_from_system()) - float(last_seen)
		for id in profile.towns:
			(profile.towns[id] as TownState).pending_offline_seconds = \
				(profile.towns[id] as TownState).offline_seconds_capped(away)
	return profile


## Kept for the tests and for anything that only cares about the open town.
static func load_town() -> TownState:
	var profile := load_profile()
	if profile == null:
		return null
	return profile.active()


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
