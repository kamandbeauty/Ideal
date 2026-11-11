class_name WaveData
extends Resource
## One wave: a list of spawn groups running side by side.

@export var groups: Array[SpawnGroup] = []
## The director holds back spawns while this many are alive.
@export_range(1, 200) var max_alive: int = 40
## Pause after the wave is cleared, before the next one.
@export_range(0.0, 120.0, 0.5) var intermission: float = 7.0
## Handed to the gunner when this wave is cleared (as far as there is room to carry it).
@export_range(0, 20) var resupply_rockets: int = 1
@export_range(0, 20) var resupply_grenades: int = 1


func total() -> int:
	var sum: int = 0
	for group: SpawnGroup in groups:
		if group != null:
			sum += group.count
	return sum


## Expands the groups into [time, zombie id, routes, target] entries sorted by time.
func schedule() -> Array:
	var entries: Array = []
	for group: SpawnGroup in groups:
		if group == null:
			continue
		for index: int in group.count:
			var time: float = group.start_time + float(index / group.burst) * group.interval
			entries.append([time, group.zombie, group.routes, group.target])
	entries.sort_custom(func(left: Array, right: Array) -> bool: return left[0] < right[0])
	return entries
