class_name SaveManager
extends RefCounted
## JSON-only schema validation, atomic replacement and last-good backup.
const VERSION: int = 1

static func defaults() -> Dictionary:
	return {
		"version": VERSION, "coins": 300, "stars": 0, "upgrade_points": 0,
		"selected_weapon": "kestrel", "weapons": ["kestrel"],
		"upgrades": {"damage": 0, "accuracy": 0, "reload": 0, "range": 0, "capacity": 0},
		"completed": [], "unlocked": ["sr01"], "records": {},
		"settings": {"quality": "auto", "fps_target": 60, "sensitivity": 1.0,
			"master_volume": 0.8, "sfx_volume": 0.9, "ambient_volume": 0.35,
			"camera_shake": true, "advanced_drag": false, "show_performance": false, "auto_reload": true}
	}

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var source: Dictionary = raw
	if int(source.get("version", -1)) != VERSION:
		return {}
	var clean: Dictionary = defaults()
	for key in ["coins", "stars", "upgrade_points"]:
		var value: Variant = source.get(key, clean[key])
		if not (value is int or value is float) or not is_finite(float(value)):
			return {}
		clean[key] = clampi(int(value), 0, 9999999)
	var known_missions: Array = ["sr01", "sr02", "sr03", "sr04", "sr05"]
	for key in ["completed", "unlocked"]:
		if not source.get(key, []) is Array:
			return {}
		for entry in source[key]:
			if entry is String and entry in known_missions and not entry in clean[key]:
				clean[key].append(entry)
	if not "sr01" in clean.unlocked:
		clean.unlocked.append("sr01")
	if source.get("weapons", []) is Array:
		for entry in source.weapons:
			if entry == "kestrel" and not entry in clean.weapons:
				clean.weapons.append(entry)
	if source.get("upgrades", {}) is Dictionary:
		for key in clean.upgrades:
			var level: Variant = source.upgrades.get(key, 0)
			if (level is int or level is float) and is_finite(float(level)):
				clean.upgrades[key] = clampi(int(level), 0, 4)
	if source.get("settings", {}) is Dictionary:
		for key in clean.settings:
			var value: Variant = source.settings.get(key)
			var expected: int = typeof(clean.settings[key])
			if typeof(value) == expected or (expected == TYPE_FLOAT and value is int):
				clean.settings[key] = value
		var settings: Dictionary = clean.settings
		if not settings.quality in ["auto", "low", "medium", "high"]:
			settings.quality = "auto"
		settings.fps_target = 30 if int(settings.fps_target) == 30 else 60
		settings.sensitivity = clampf(float(settings.sensitivity), 0.3, 2.5)
		for key in ["master_volume", "sfx_volume", "ambient_volume"]:
			settings[key] = clampf(float(settings[key]), 0.0, 1.0)
	if source.get("records", {}) is Dictionary:
		for mission_id in source.records:
			var record: Variant = source.records[mission_id]
			if not mission_id in known_missions or not record is Dictionary:
				continue
			if record.get("stars", 0) is int or record.get("stars", 0) is float:
				clean.records[mission_id] = {
					"stars": clampi(int(record.get("stars", 0)), 0, 3),
					"accuracy": clampf(float(record.get("accuracy", 0)), 0, 100),
					"time": clampf(float(record.get("time", 0)), 0, 9999),
					"shots": clampi(int(record.get("shots", 0)), 0, 9999)
				}
	return clean

static func write_atomic(path: String, data: Dictionary) -> bool:
	var directory: String = path.get_base_dir()
	var mkdir_error: int = DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return false
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		var backup_error: int = DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			return false
	var error: int = DirAccess.rename_absolute(temporary, path)
	return error == OK

static func read_with_recovery(path: String) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file: FileAccess = FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var parser := JSON.new()
		var parse_error: int = parser.parse(file.get_as_text())
		file.close()
		var valid: Dictionary = validate(parser.data) if parse_error == OK else {}
		if not valid.is_empty():
			if candidate != path:
				write_atomic(path, valid)
				return {"data": valid, "recovered": true}
			return {"data": valid, "recovered": false}
	return {"data": defaults(), "recovered": FileAccess.file_exists(path)}
