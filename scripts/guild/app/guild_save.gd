class_name GuildSave
extends RefCounted
## The guild's own save file: the vault, the warehouse, the guild master's hands and
## the roster - including the adventurers who are still out in the field.
##
## It is deliberately a separate file from the Roadstop profile: the guild is a new
## game, and a half-migrated profile is how saves get corrupted. The format is a
## plain dictionary with a version; anything else is refused instead of half-read.
##
## Offline time is not idle income here. Missions are timers, so time away advances
## the same clock the hall uses: an expedition that would have finished while the
## phone was in a pocket is finished, and the loot is waiting on the board when the
## player comes back - capped, so a month away is not a month of loot.

const VERSION := 1
const SAVE_DIR := "user://saves"
const SAVE_PATH := "user://saves/guild_01.json"
const BACKUP_PATH := "user://saves/guild_backup_01.json"
## The longest stretch of real time that can pass a mission along: eight hours.
const MAX_AWAY := 8.0 * 3600.0


# --- the payload -----------------------------------------------------------

## Everything worth keeping, read off the live objects. The customer queue is not
## in here on purpose: who is standing in line this second is not progress.
static func snapshot(
		treasury: GuildTreasury,
		stock: GuildStock,
		player_state: GuildPlayerState,
		desk: GuildMissionDesk
) -> Dictionary:
	var payload := {
		"version": VERSION,
		"last_seen": int(Time.get_unix_time_from_system()),
		"cash": treasury.cash if treasury != null else 0.0,
		"reputation": treasury.reputation if treasury != null else 0.0,
		"capacity": stock.capacity if stock != null else GuildStock.DEFAULT_CAPACITY,
		"stock": stock.snapshot() if stock != null else {},
		"hands": player_state.held.duplicate() if player_state != null else {},
		"money": player_state.money if player_state != null else 0.0,
		"roster": [],
	}
	if desk != null:
		for adventurer in desk.adventurers:
			payload["roster"].append({
				"class_id": adventurer.class_id,
				"rank": adventurer.rank,
				"state": adventurer.state,
				"mission_id": adventurer.mission_id,
				"time_left": adventurer.time_left,
				"duration": adventurer.duration,
				"loot": adventurer.loot.duplicate(),
			})
	return payload


## Puts a payload back onto live objects. Returns true only when the whole thing
## applied; a version or shape mismatch leaves the objects untouched.
static func apply(
		data: Dictionary,
		treasury: GuildTreasury,
		stock: GuildStock,
		player_state: GuildPlayerState,
		desk: GuildMissionDesk
) -> bool:
	if int(data.get("version", 0)) != VERSION:
		return false
	if treasury == null or stock == null:
		return false
	treasury.cash = maxf(float(data.get("cash", 0.0)), 0.0)
	treasury.reputation = maxf(float(data.get("reputation", 0.0)), 0.0)
	treasury.changed.emit()
	stock.capacity = maxi(int(data.get("capacity", GuildStock.DEFAULT_CAPACITY)), 1)
	stock.clear()
	var goods: Variant = data.get("stock", {})
	if typeof(goods) == TYPE_DICTIONARY:
		for id in goods:
			stock.add(str(id), int(goods[id]))
	if player_state != null:
		player_state.clear_hands()
		player_state.money = 0.0
		var hands: Variant = data.get("hands", {})
		if typeof(hands) == TYPE_DICTIONARY:
			for id in hands:
				player_state.hold_items(str(id), int(hands[id]))
		player_state.load_money(float(data.get("money", 0.0)))
	if desk != null:
		_apply_roster(desk, data.get("roster", []))
	return true


static func _apply_roster(desk: GuildMissionDesk, raw: Variant) -> void:
	desk.adventurers.clear()
	if typeof(raw) != TYPE_ARRAY:
		return
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row := entry as Dictionary
		var adventurer := desk.hire(str(row.get("class_id", "warrior")), str(row.get("rank", "F")))
		adventurer.state = str(row.get("state", GuildAdventurer.IDLE))
		adventurer.mission_id = str(row.get("mission_id", ""))
		adventurer.duration = float(row.get("duration", 0.0))
		adventurer.time_left = clampf(float(row.get("time_left", 0.0)), 0.0, adventurer.duration)
		var loot: Variant = row.get("loot", {})
		adventurer.loot = {}
		if typeof(loot) == TYPE_DICTIONARY:
			for id in loot:
				adventurer.loot[str(id)] = int(loot[id])
	desk.changed.emit()


# --- the file --------------------------------------------------------------

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


## Writes the payload and keeps the previous file as a backup.
static func write(payload: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var body := payload.duplicate()
	body["version"] = VERSION
	body["last_seen"] = int(Time.get_unix_time_from_system())
	if FileAccess.file_exists(SAVE_PATH):
		var previous := FileAccess.get_file_as_string(SAVE_PATH)
		if not previous.is_empty():
			_store(BACKUP_PATH, previous)
	return _store(SAVE_PATH, JSON.stringify(body))


## Reads the newest readable payload: the live file first, the backup second.
static func read() -> Dictionary:
	var data := _parse(SAVE_PATH)
	if data.is_empty():
		data = _parse(BACKUP_PATH)
	if data.is_empty():
		return {}
	if int(data.get("version", 0)) != VERSION:
		return {}
	return data


static func delete() -> void:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Real seconds between a payload being written and now, capped.
static func away_seconds(data: Dictionary) -> float:
	var last := int(data.get("last_seen", 0))
	if last <= 0:
		return 0.0
	var away := float(Time.get_unix_time_from_system()) - float(last)
	return clampf(away, 0.0, MAX_AWAY)


## Lifts the adventurers' clock by the time the player was away. Returns how many
## missions finished while the phone was in a pocket.
static func catch_up(desk: GuildMissionDesk, seconds: float) -> int:
	if desk == null or seconds <= 0.0:
		return 0
	var before := desk.waiting_count()
	var left := seconds
	while left > 0.0:
		var step := minf(1.0, left)
		desk.tick(step)
		left -= step
	return desk.waiting_count() - before


static func _store(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


static func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
