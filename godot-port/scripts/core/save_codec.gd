class_name SaveCodec
extends RefCounted

static func new_save(clock: RefCounted = null) -> SaveData:
	var now := _now(clock)
	var data := SaveData.new()
	data.version = SaveData.CURRENT_VERSION
	data.player_id = Crypto.new().generate_random_bytes(16).hex_encode()
	data.created_at_unix = now
	data.updated_at_unix = now
	data.lives = Lives.DEFAULT_MAX
	data.max_lives = Lives.DEFAULT_MAX
	data.lives_updated_at_unix = now
	data.level_number = 1
	data.boosters = _starter_boosters()
	return data

static func encode(data: SaveData, pretty: bool = true) -> String:
	if data == null:
		push_error("cannot encode a null save")
		return ""
	return JSON.stringify(_to_dictionary(data), "\t" if pretty else "")

static func decode(json_text: String, clock: RefCounted = null) -> Dictionary:
	var errors: Array[String] = []
	if json_text.is_empty():
		errors.append("save is empty")
		return {"data": new_save(clock), "errors": errors}
	var parser := JSON.new()
	var parse_error := parser.parse(json_text)
	if parse_error != OK:
		errors.append("corrupt save: " + parser.get_error_message())
		return {"data": new_save(clock), "errors": errors}
	if not parser.data is Dictionary:
		errors.append("save deserialized to null")
		return {"data": new_save(clock), "errors": errors}
	var data := _from_dictionary(parser.data)
	_migrate(data, errors)
	_sanitize(data, clock)
	return {"data": data, "errors": errors}

static func _starter_boosters() -> Array[int]:
	var result: Array[int] = []
	for _index in range(BoosterBag.SLOTS):
		result.append(BoosterBag.START_OWNED)
	return result

static func _from_dictionary(source: Dictionary) -> SaveData:
	var data := SaveData.new()
	data.version = int(source.get("version", 0))
	data.player_id = str(source.get("playerId", source.get("player_id", "")))
	data.created_at_unix = int(source.get("createdAtUnix", source.get("created_at_unix", 0)))
	data.updated_at_unix = int(source.get("updatedAtUnix", source.get("updated_at_unix", 0)))
	data.coins = int(source.get("coins", 0))
	data.potions = int(source.get("potions", 0))
	data.lives = int(source.get("lives", 5))
	data.max_lives = int(source.get("maxLives", source.get("max_lives", 5)))
	data.lives_updated_at_unix = int(source.get("livesUpdatedAtUnix", source.get("lives_updated_at_unix", 0)))
	data.level_number = int(source.get("levelNumber", source.get("level_number", 1)))
	data.music_on = bool(source.get("musicOn", source.get("music_on", true)))
	data.sfx_on = bool(source.get("sfxOn", source.get("sfx_on", true)))
	data.haptics_on = bool(source.get("hapticsOn", source.get("haptics_on", true)))
	data.push_on = bool(source.get("pushOn", source.get("push_on", true)))

	var booster_values = source.get("boosters", [])
	if booster_values is Array:
		for value in booster_values:
			data.boosters.append(int(value))

	var task_values = source.get("completedTasks", source.get("completed_tasks", []))
	if task_values is Array:
		for value in task_values:
			data.completed_tasks.append(str(value))
	var chest_values = source.get("claimedChests", source.get("claimed_chests", []))
	if chest_values is Array:
		for value in chest_values:
			data.claimed_chests.append(str(value))

	var level_values = source.get("levels", [])
	if level_values is Array:
		for value in level_values:
			if not value is Dictionary:
				continue
			data.levels.append({
				"number": int(value.get("number", 0)),
				"plays": int(value.get("plays", 0)),
				"best_moves_left": int(value.get("bestMovesLeft", value.get("best_moves_left", 0))),
				"best_score": int(value.get("bestScore", value.get("best_score", 0))),
				"cleared": bool(value.get("cleared", false)),
				"first_cleared_at_unix": int(value.get("firstClearedAtUnix", value.get("first_cleared_at_unix", 0))),
				"last_replay_hash": str(value.get("lastReplayHash", value.get("last_replay_hash", "")))
			})
	return data

static func _to_dictionary(data: SaveData) -> Dictionary:
	var level_values: Array[Dictionary] = []
	for record in data.levels:
		level_values.append({
			"number": int(record.get("number", 0)),
			"plays": int(record.get("plays", 0)),
			"bestMovesLeft": int(record.get("best_moves_left", 0)),
			"bestScore": int(record.get("best_score", 0)),
			"cleared": bool(record.get("cleared", false)),
			"firstClearedAtUnix": int(record.get("first_cleared_at_unix", 0)),
			"lastReplayHash": str(record.get("last_replay_hash", ""))
		})
	return {
		"version": data.version,
		"playerId": data.player_id,
		"createdAtUnix": data.created_at_unix,
		"updatedAtUnix": data.updated_at_unix,
		"coins": data.coins,
		"potions": data.potions,
		"lives": data.lives,
		"maxLives": data.max_lives,
		"livesUpdatedAtUnix": data.lives_updated_at_unix,
		"levelNumber": data.level_number,
		"boosters": data.boosters,
		"levels": level_values,
		"completedTasks": data.completed_tasks,
		"claimedChests": data.claimed_chests,
		"musicOn": data.music_on,
		"sfxOn": data.sfx_on,
		"hapticsOn": data.haptics_on,
		"pushOn": data.push_on
	}

static func _migrate(data: SaveData, errors: Array[String]) -> void:
	if data.version > SaveData.CURRENT_VERSION:
		errors.append("save comes from a newer build (v%d), reading it as best we can" % data.version)
		return
	if data.version < 1:
		data.version = 1
		errors.append("migrated save from v0 to v1")
	if data.version < 2:
		data.version = 2
		data.boosters = _starter_boosters()
		errors.append("migrated save from v1 to v2: boosters added")
	data.version = SaveData.CURRENT_VERSION

static func _sanitize(data: SaveData, clock: RefCounted) -> void:
	var now := _now(clock)
	if data.player_id.is_empty():
		data.player_id = Crypto.new().generate_random_bytes(16).hex_encode()
	if data.coins < 0:
		data.coins = 0
	if data.potions < 0:
		data.potions = 0
	data.coins = mini(data.coins, Wallet.MAX_BALANCE)
	data.potions = mini(data.potions, Wallet.MAX_BALANCE)
	if data.max_lives < 1:
		data.max_lives = Lives.DEFAULT_MAX
	data.lives = clampi(data.lives, 0, data.max_lives)
	if data.lives_updated_at_unix <= 0:
		data.lives_updated_at_unix = now
	if data.level_number < 1:
		data.level_number = 1
	if data.created_at_unix <= 0:
		data.created_at_unix = now
	if data.updated_at_unix <= 0:
		data.updated_at_unix = now
	if data.boosters.is_empty():
		data.boosters = _starter_boosters()
	while data.boosters.size() < BoosterBag.SLOTS:
		data.boosters.append(BoosterBag.START_OWNED)
	for index in range(data.boosters.size()):
		data.boosters[index] = clampi(data.boosters[index], 0, BoosterBag.MAX_OWNED)

static func _now(clock: RefCounted) -> int:
	return clock.now_unix() if clock != null else 0
