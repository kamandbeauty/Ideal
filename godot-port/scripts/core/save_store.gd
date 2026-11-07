class_name SaveStore
extends RefCounted

const FILE_NAME := "shazdeh-save.json"

var _clock: RefCounted
var _path: String
var _backup_path: String
var _temp_path: String

func _init(clock: RefCounted = null, directory: String = "") -> void:
	_clock = clock if clock != null else GameClock.new()
	var root := directory if not directory.is_empty() else "user://"
	_path = root.path_join(FILE_NAME)
	_backup_path = _path + ".bak"
	_temp_path = _path + ".tmp"

var location: String:
	get:
		return _path

func load_save() -> Dictionary:
	var errors: Array[String] = []
	var primary := _try_read(_path, errors)
	if primary != null:
		return {"data": primary, "errors": errors}
	var backup := _try_read(_backup_path, errors)
	if backup != null:
		errors.append("recovered from backup save")
		return {"data": backup, "errors": errors}
	var fresh := SaveCodec.new_save(_clock)
	errors.append("no save found, starting a new one")
	return {"data": fresh, "errors": errors}

func save(data: SaveData) -> bool:
	if data == null:
		return false
	data.version = SaveData.CURRENT_VERSION
	data.updated_at_unix = _clock.now_unix()
	var json_text := SaveCodec.encode(data)
	if json_text.is_empty():
		return false
	var file := FileAccess.open(_temp_path, FileAccess.WRITE)
	if file == null:
		push_error("save failed: cannot open temporary save file (%s)" % _temp_path)
		return false
	file.store_string(json_text)
	file.close()

	var path_absolute := ProjectSettings.globalize_path(_path)
	var backup_absolute := ProjectSettings.globalize_path(_backup_path)
	var temp_absolute := ProjectSettings.globalize_path(_temp_path)
	if FileAccess.file_exists(_path):
		if FileAccess.file_exists(_backup_path):
			DirAccess.remove_absolute(backup_absolute)
		var copy_error := DirAccess.copy_absolute(path_absolute, backup_absolute)
		if copy_error != OK:
			push_error("save failed: could not create backup (%s)" % error_string(copy_error))
			return false
		var remove_error := DirAccess.remove_absolute(path_absolute)
		if remove_error != OK:
			push_error("save failed: could not replace previous file (%s)" % error_string(remove_error))
			return false
	var rename_error := DirAccess.rename_absolute(temp_absolute, path_absolute)
	if rename_error != OK:
		push_error("save failed: could not move temporary file into place (%s)" % error_string(rename_error))
		return false
	return true

func _try_read(path: String, errors: Array[String]) -> SaveData:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("could not read %s: %s" % [path.get_file(), error_string(FileAccess.get_open_error())])
		return null
	var json_text := file.get_as_text()
	file.close()
	var decoded := SaveCodec.decode(json_text, _clock)
	var local_errors: Array[String] = decoded.errors
	for message in local_errors:
		errors.append(message)
	return decoded.data if local_errors.is_empty() else null
