class_name SaveStore
extends RefCounted
## Versioned, local-only JSON. A valid previous generation is retained as backup.

const VERSION: int = 1
var path: String = "user://frontline-save.json"
var last_status: String = "new"


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"settings": {"graphics": "AUTO", "target_fps": 60, "sensitivity": 1.0, "sound": true},
		"records": {},
	}


func load_data() -> Dictionary:
	var data := _read_valid(path)
	if not data.is_empty():
		last_status = "primary"
		return _normalize(data)
	data = _read_valid(path + ".bak")
	if not data.is_empty():
		last_status = "backup"
		return _normalize(data)
	last_status = "new" if not FileAccess.file_exists(path) else "corrupt"
	return defaults()


func save_data(data: Dictionary) -> bool:
	var normalized := _normalize(data)
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(normalized, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false

	var absolute := ProjectSettings.globalize_path(path)
	var backup := ProjectSettings.globalize_path(path + ".bak")
	var temporary := ProjectSettings.globalize_path(temp)
	if not _rotate_primary(absolute, backup):
		return false
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		# If promotion fails, retain/restore the last known-good save.
		if FileAccess.file_exists(path + ".bak") and not FileAccess.file_exists(path):
			DirAccess.copy_absolute(backup, absolute)
		return false
	last_status = "saved"
	return true


func _rotate_primary(absolute: String, backup: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	# Never replace a good backup with a damaged primary.
	if _read_valid(path).is_empty():
		return DirAccess.remove_absolute(absolute) == OK
	if FileAccess.file_exists(path + ".bak") and DirAccess.remove_absolute(backup) != OK:
		return false
	return DirAccess.rename_absolute(absolute, backup) == OK


func _read_valid(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var decoded: Variant = JSON.parse_string(file.get_as_text())
	if not decoded is Dictionary:
		return {}
	var result: Dictionary = decoded
	var version: Variant = result.get("version", null)
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or float(version) != float(VERSION):
		return {}
	if not result.get("settings") is Dictionary or not result.get("records") is Dictionary:
		return {}
	return result


func _normalize(data: Dictionary) -> Dictionary:
	var out := defaults()
	var settings: Dictionary = (
		data.get("settings", {}) if data.get("settings", {}) is Dictionary else {}
	)
	var mode: Variant = settings.get("graphics", "AUTO")
	if not mode is String or mode.to_upper() not in ["AUTO", "LOW", "MEDIUM", "HIGH"]:
		mode = "AUTO"
	out.settings.graphics = mode.to_upper()
	var fps: Variant = settings.get("target_fps", 60)
	out.settings.target_fps = 30 if typeof(fps) in [TYPE_INT, TYPE_FLOAT] and fps == 30 else 60
	var sensitivity: Variant = settings.get("sensitivity", 1.0)
	if typeof(sensitivity) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(sensitivity)):
		sensitivity = 1.0
	out.settings.sensitivity = clampf(float(sensitivity), 0.4, 2.0)
	var sound: Variant = settings.get("sound", true)
	out.settings.sound = sound if typeof(sound) == TYPE_BOOL else true
	if data.get("records", {}) is Dictionary:
		out.records = data.get("records", {}).duplicate(true)
	return out
