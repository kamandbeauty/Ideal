class_name SaveManager
extends RefCounted
## JSON persistence: write to a temp file, keep one backup generation, and
## fall back to the backup when the main file is missing or damaged.


static func load_dict(path: String) -> Dictionary:
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		# The instance parser reports failure by return code instead of logging an engine error.
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(candidate)) == OK and json.data is Dictionary:
			return json.data
	return {}


static func save_dict(path: String, data: Dictionary) -> bool:
	var temp: String = path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	var name: String = path.get_file()
	if dir.file_exists(name):
		if dir.file_exists(name + ".bak"):
			dir.remove(name + ".bak")
		dir.rename(name, name + ".bak")
	return dir.rename(temp.get_file(), name) == OK


static func remove(path: String) -> void:
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return
	for suffix: String in ["", ".bak", ".tmp"]:
		if dir.file_exists(path.get_file() + suffix):
			dir.remove(path.get_file() + suffix)


## Keeps only keys the defaults know about and coerces every value to the
## default's type, so an old or hand-edited save can never break the game.
static func merge_defaults(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in defaults:
		var base: Variant = defaults[key]
		var value: Variant = loaded.get(key, base)
		if base is Dictionary:
			result[key] = merge_defaults(base, value if value is Dictionary else {})
		elif base is bool:
			result[key] = bool(value) if (value is bool or value is float or value is int) else base
		elif base is int:
			result[key] = int(value) if (value is float or value is int) else base
		elif base is float:
			result[key] = float(value) if (value is float or value is int) else base
		elif base is String:
			result[key] = value if value is String else base
		else:
			result[key] = value
	return result
