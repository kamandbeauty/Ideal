class_name LevelContentLoader
extends RefCounted

static func load_level(number: int, chapter: String = "ch01") -> Dictionary:
	var file_name := "level-%03d.json" % number
	var path := "res://content/levels/%s/%s" % [chapter, file_name]
	if not FileAccess.file_exists(path):
		return {"level": null, "errors": ["level file not found: " + path]}
	var json_text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		return {"level": null, "errors": ["invalid level JSON: " + path]}
	return parse_level(parsed)

static func parse_level(source: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var level := LevelDefinition.new()
	level.id = str(source.get("id", ""))
	level.chapter = str(source.get("chapter", "ch01"))
	level.number = int(source.get("number", 0))
	level.type = str(source.get("type", "normal"))
	level.width = int(source.get("width", 9))
	level.height = int(source.get("height", 9))
	level.gravity = GameTypes.GravityDirection.UP if str(source.get("gravity", "down")).to_lower() == "up" else GameTypes.GravityDirection.DOWN
	level.move_limit = int(source.get("move_limit", 20))
	level.stage_count = maxi(1, int(source.get("stages", 1)))
	level.reward_potions = int(source.get("reward_potions", 0))
	level.reward_coins = int(source.get("reward_coins", 0))

	var piece_names: Array = source.get("pieces", [])
	for piece_name in piece_names:
		var piece := _piece_from_name(str(piece_name))
		if piece == GameTypes.PieceKind.NONE:
			errors.append("level %d: unknown piece '%s'" % [level.number, str(piece_name)])
		else:
			level.pieces.append(piece)

	var goal_values: Array = source.get("goals", [])
	for goal_value in goal_values:
		if not goal_value is Dictionary:
			continue
		var goal_kind_name := str(goal_value.get("kind", ""))
		if goal_kind_name == "clear_pieces":
			var piece_kind := _piece_from_name(str(goal_value.get("piece", "")))
			if piece_kind == GameTypes.PieceKind.NONE:
				errors.append("level %d: unknown goal piece '%s'" % [level.number, str(goal_value.get("piece", ""))])
				continue
			level.goals.append({"kind": GameTypes.GoalKind.CLEAR_PIECES, "piece": piece_kind, "target": int(goal_value.get("target", 0))})
		elif goal_kind_name == "clear_obstacle":
			var obstacle_kind := _obstacle_from_name(str(goal_value.get("obstacle", "")))
			if obstacle_kind == GameTypes.ObstacleKind.NONE:
				errors.append("level %d: unknown goal obstacle '%s'" % [level.number, str(goal_value.get("obstacle", ""))])
				continue
			level.goals.append({"kind": GameTypes.GoalKind.CLEAR_OBSTACLE, "obstacle": obstacle_kind, "target": int(goal_value.get("target", 0))})
		else:
			errors.append("level %d: unknown goal kind '%s'" % [level.number, goal_kind_name])

	var obstacle_values: Array = source.get("obstacles", [])
	for obstacle_value in obstacle_values:
		if not obstacle_value is Dictionary:
			continue
		var obstacle_kind := _obstacle_from_name(str(obstacle_value.get("kind", "")))
		if obstacle_kind == GameTypes.ObstacleKind.NONE:
			errors.append("level %d: unknown obstacle '%s'" % [level.number, str(obstacle_value.get("kind", ""))])
			continue
		level.obstacles.append({
			"x": int(obstacle_value.get("x", -1)),
			"y": int(obstacle_value.get("y", -1)),
			"kind": obstacle_kind,
			"layers": maxi(1, int(obstacle_value.get("layers", 1)))
		})

	var blocked_values: Array = source.get("blocked", [])
	for blocked_value in blocked_values:
		var parts := str(blocked_value).split(",")
		if parts.size() != 2 or not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int():
			errors.append("level %d: bad blocked cell '%s'" % [level.number, str(blocked_value)])
			continue
		level.blocked.append(Vector2i(int(parts[0]), int(parts[1])))

	errors.append_array(LevelValidator.validate(level))
	return {"level": level, "errors": errors}

static func load_chapter(chapter: String = "ch01", count: int = 10) -> Dictionary:
	var levels: Array[LevelDefinition] = []
	var errors: Array[String] = []
	for number in range(1, count + 1):
		var result := load_level(number, chapter)
		for message in result.errors:
			errors.append(message)
		if result.level != null:
			levels.append(result.level)
	errors.append_array(LevelValidator.validate_catalog(levels))
	return {"levels": levels, "errors": errors}

static func _piece_from_name(value: String) -> int:
	match value.strip_edges().to_lower():
		"firouzeh": return GameTypes.PieceKind.FIROUZEH
		"lajvard": return GameTypes.PieceKind.LAJVARD
		"aqiq": return GameTypes.PieceKind.AQIQ
		"zomorrod": return GameTypes.PieceKind.ZOMORROD
		"morvarid": return GameTypes.PieceKind.MORVARID
		"ananas": return GameTypes.PieceKind.ANANAS
		"porteqal": return GameTypes.PieceKind.PORTEQAL
		"moz": return GameTypes.PieceKind.MOZ
		_: return GameTypes.PieceKind.NONE

static func _obstacle_from_name(value: String) -> int:
	match value.strip_edges().to_lower():
		"crate": return GameTypes.ObstacleKind.CRATE
		"frost": return GameTypes.ObstacleKind.FROST
		"ivy": return GameTypes.ObstacleKind.IVY
		"vial": return GameTypes.ObstacleKind.VIAL
		"samovar": return GameTypes.ObstacleKind.SAMOVAR
		"flower_pot": return GameTypes.ObstacleKind.FLOWER_POT
		"chain": return GameTypes.ObstacleKind.CHAIN
		"seal": return GameTypes.ObstacleKind.SEAL
		_: return GameTypes.ObstacleKind.NONE
