class_name SaveData
extends RefCounted

const CURRENT_VERSION := 2

var version := CURRENT_VERSION
var player_id := ""
var created_at_unix: int = 0
var updated_at_unix: int = 0
var coins: int = 0
var potions: int = 0
var lives := 5
var max_lives := 5
var lives_updated_at_unix: int = 0
var level_number := 1
var boosters: Array[int] = []
var levels: Array[Dictionary] = []
var completed_tasks: Array[String] = []
var claimed_chests: Array[String] = []
var music_on := true
var sfx_on := true
var haptics_on := true
var push_on := true

func find_level(number: int) -> Dictionary:
	for record in levels:
		if int(record.get("number", 0)) == number:
			return record
	return {}

func get_or_create_level(number: int) -> Dictionary:
	var existing := find_level(number)
	if not existing.is_empty():
		return existing
	var record := {
		"number": number,
		"plays": 0,
		"best_moves_left": 0,
		"best_score": 0,
		"cleared": false,
		"first_cleared_at_unix": 0,
		"last_replay_hash": ""
	}
	levels.append(record)
	return record

func is_task_complete(key: String) -> bool:
	return completed_tasks.has(key)

func is_chest_claimed(key: String) -> bool:
	return claimed_chests.has(key)
