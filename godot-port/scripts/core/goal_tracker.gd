class_name GoalTracker
extends RefCounted

var _goals: Array[Dictionary] = []
var _progress: Array[int] = []

func _init(goals: Array[Dictionary] = []) -> void:
	for goal in goals:
		_goals.append(goal.duplicate(true))
		_progress.append(0)

func count() -> int:
	return _goals.size()

func goal(index: int) -> Dictionary:
	return _goals[index]

func progress(index: int) -> int:
	return _progress[index]

func target(index: int) -> int:
	return int(_goals[index].get("target", 0))

func is_complete(index: int) -> bool:
	return _progress[index] >= target(index)

func all_complete() -> bool:
	if _goals.is_empty():
		return false
	for index in range(_goals.size()):
		if not is_complete(index):
			return false
	return true

func completed_count() -> int:
	var total := 0
	for index in range(_goals.size()):
		if is_complete(index):
			total += 1
	return total

func record_piece_cleared(piece: int) -> Array[int]:
	var changed: Array[int] = []
	for index in range(_goals.size()):
		var goal_data := _goals[index]
		if int(goal_data.get("kind", GameTypes.GoalKind.CLEAR_PIECES)) != GameTypes.GoalKind.CLEAR_PIECES:
			continue
		if int(goal_data.get("piece", 0)) != piece or is_complete(index):
			continue
		_progress[index] += 1
		changed.append(index)
	return changed

func record_obstacle_layer(obstacle: int) -> Array[int]:
	var changed: Array[int] = []
	for index in range(_goals.size()):
		var goal_data := _goals[index]
		if int(goal_data.get("kind", GameTypes.GoalKind.CLEAR_PIECES)) != GameTypes.GoalKind.CLEAR_OBSTACLE:
			continue
		if int(goal_data.get("obstacle", 0)) != obstacle or is_complete(index):
			continue
		_progress[index] += 1
		changed.append(index)
	return changed

func snapshot() -> Array[int]:
	return _progress.duplicate()
