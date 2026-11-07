class_name DistrictContentLoader
extends RefCounted

static func load_chapter(chapter: String = "ch01") -> Dictionary:
	var path := "res://content/meta/%s-districts.json" % chapter
	if not FileAccess.file_exists(path):
		return {"chapter": chapter, "districts": [], "errors": ["district metadata not found: " + path]}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {"chapter": chapter, "districts": [], "errors": ["invalid district metadata JSON"]}
	return parse_chapter(parsed)

static func parse_chapter(source: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var chapter := str(source.get("chapter", "ch01"))
	var districts: Array[Dictionary] = []
	var district_values: Array = source.get("districts", [])
	if district_values.is_empty():
		errors.append("chapter meta has no districts")
	for district_value in district_values:
		if not district_value is Dictionary:
			continue
		var tasks: Array[Dictionary] = []
		var task_values: Array = district_value.get("tasks", [])
		for task_value in task_values:
			if not task_value is Dictionary:
				continue
			tasks.append({
				"key": str(task_value.get("key", "")),
				"title": str(task_value.get("title", "")),
				"title_en": str(task_value.get("title_en", task_value.get("key", ""))),
				"build_asset": str(task_value.get("build_asset", "")),
				"potion_cost": int(task_value.get("potion_cost", 0))
			})
		var chest_value: Dictionary = district_value.get("chest", {})
		var chest := RewardBundle.new(int(chest_value.get("coins", 0)), int(chest_value.get("potions", 0)))
		districts.append({
			"id": str(district_value.get("id", "")),
			"title": str(district_value.get("title", "")),
			"title_en": str(district_value.get("title_en", district_value.get("id", ""))),
			"tasks": tasks,
			"chest": chest
		})
	errors.append_array(validate_districts(districts))
	return {"chapter": chapter, "districts": districts, "errors": errors}

static func validate_districts(districts: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = []
	if districts.is_empty():
		errors.append("chapter has no districts")
		return errors
	var district_ids: Dictionary = {}
	var task_keys: Dictionary = {}
	for district in districts:
		var district_id := str(district.get("id", ""))
		if district_id.is_empty():
			errors.append("district has no id")
		elif district_ids.has(district_id):
			errors.append("duplicate district id " + district_id)
		district_ids[district_id] = true
		var tasks: Array = district.get("tasks", [])
		if tasks.is_empty():
			errors.append(district_id + ": no tasks")
		for task in tasks:
			var key := str(task.get("key", ""))
			if key.is_empty():
				errors.append(district_id + ": task has no key")
			elif task_keys.has(key):
				errors.append("duplicate task key " + key)
			task_keys[key] = true
			var cost := int(task.get("potion_cost", 0))
			if cost <= 0:
				errors.append(district_id + ": task " + key + " must cost more than 0 potions")
			if cost > 500:
				errors.append(district_id + ": task " + key + " costs more than a district should")
			if str(task.get("build_asset", "")).is_empty():
				errors.append(district_id + ": task " + key + " has no build asset")
		var chest: RewardBundle = district.get("chest", RewardBundle.none())
		if chest.coins < 0 or chest.potions < 0:
			errors.append(district_id + ": negative chest reward")
		if chest.is_empty:
			errors.append(district_id + ": empty chest")
	return errors
