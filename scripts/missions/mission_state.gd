class_name MissionState
extends RefCounted

signal progress_changed(destroyed: int, total: int)
signal completed

var total_targets: int = 0
var destroyed_ids: Dictionary = {}
var shots_fired: int = 0
var hits: int = 0
var elapsed: float = 0.0
var is_complete: bool = false


func setup(total: int) -> void:
	total_targets = maxi(total, 1)
	destroyed_ids.clear()
	shots_fired = 0
	hits = 0
	elapsed = 0.0
	is_complete = false


func target_destroyed(target_id: int) -> void:
	if is_complete or destroyed_ids.has(target_id):
		return
	destroyed_ids[target_id] = true
	progress_changed.emit(destroyed_ids.size(), total_targets)
	if destroyed_ids.size() >= total_targets:
		is_complete = true
		completed.emit()


func record_shot() -> void:
	shots_fired += 1


func record_hit() -> void:
	hits += 1


func rating() -> int:
	if not is_complete:
		return 0
	# One useful hit per shot, with a gentle time threshold.
	var accuracy := float(hits) / float(maxi(shots_fired, 1))
	if accuracy >= 0.75 and elapsed <= 180.0:
		return 3
	if accuracy >= 0.45:
		return 2
	return 1
