class_name WaveData
extends RefCounted
## Ten waves, generated from one formula so balance is changed in one place.
##
## A wave is a list of groups. Each group spawns `count` enemies of one type,
## `delay` seconds into the wave, every `interval` seconds.

const TOTAL := 10
const PREPARE_TIME_FIRST := 15.0
const PREPARE_TIME := 9.0
const EARLY_BONUS_PER_SECOND := 2


static func get_wave(index: int) -> Dictionary:
	var i := clampi(index, 1, TOTAL)
	var groups: Array = []

	groups.append({
		"type": "grunt",
		"count": 3 + i,
		"interval": maxf(0.4, 0.95 - 0.05 * i),
		"delay": 0.0,
	})
	if i >= 2:
		groups.append({
			"type": "runner",
			"count": 1 + int(i * 0.8),
			"interval": 0.75,
			"delay": 3.5,
		})
	if i >= 4:
		groups.append({
			"type": "tank",
			"count": 1 + int((i - 4) / 2.0),
			"interval": 2.2,
			"delay": 6.0,
		})
	if i % 5 == 0:
		groups.append({"type": "boss", "count": 1, "interval": 1.0, "delay": 9.0})

	return {
		"index": i,
		"groups": groups,
		"reward": 30 + 10 * i,
		"total_enemies": count_enemies(groups),
	}


static func count_enemies(groups: Array) -> int:
	var total := 0
	for group in groups:
		total += int(group["count"])
	return total


## Flat spawn schedule: [{ "time": seconds, "type": "grunt" }, ...]
static func schedule(index: int) -> Array:
	var entries: Array = []
	for group in get_wave(index)["groups"]:
		for n in int(group["count"]):
			entries.append({
				"time": float(group["delay"]) + float(group["interval"]) * n,
				"type": str(group["type"]),
			})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["time"]) < float(b["time"])
	)
	return entries


static func reward(index: int) -> int:
	return int(get_wave(index)["reward"])


static func is_boss_wave(index: int) -> bool:
	return index % 5 == 0 and index > 0


static func prepare_time(index: int) -> float:
	return PREPARE_TIME_FIRST if index <= 1 else PREPARE_TIME
