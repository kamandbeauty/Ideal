class_name LevelValidator
extends RefCounted

const MIN_GOAL_TARGET := 1
const MAX_GOAL_TARGET := 200
const MIN_MOVE_LIMIT := 5
const MAX_MOVE_LIMIT := 100
const MAX_GOALS := 3
const MAX_OBSTACLE_LAYERS := 4

static func validate(level: LevelDefinition) -> Array[String]:
	var errors: Array[String] = []
	if level == null:
		errors.append("level is null")
		return errors
	var tag := level.id if not level.id.is_empty() else "level %d" % level.number
	if level.id.is_empty():
		errors.append(tag + ": id is required")
	if level.number < 1:
		errors.append(tag + ": number must be >= 1")
	if level.width < LevelDefinition.MIN_BOARD_SIDE or level.width > LevelDefinition.MAX_BOARD_SIDE:
		errors.append(tag + ": width must be 7..10")
	if level.height < LevelDefinition.MIN_BOARD_SIDE or level.height > LevelDefinition.MAX_BOARD_SIDE:
		errors.append(tag + ": height must be 7..10")
	if level.move_limit < MIN_MOVE_LIMIT or level.move_limit > MAX_MOVE_LIMIT:
		errors.append(tag + ": move_limit must be 5..100")
	if level.pieces.size() < 4 or level.pieces.size() > 6:
		errors.append(tag + ": needs 4..6 piece kinds")
	var seen_pieces: Dictionary = {}
	for piece in level.pieces:
		if seen_pieces.has(piece):
			errors.append(tag + ": duplicate piece kind %d" % piece)
		seen_pieces[piece] = true
	if level.goals.is_empty():
		errors.append(tag + ": at least one goal is required")
	if level.goals.size() > MAX_GOALS:
		errors.append(tag + ": at most %d goals" % MAX_GOALS)
	var total_piece_goal := 0
	for index in range(level.goals.size()):
		var goal: Dictionary = level.goals[index]
		var target := int(goal.get("target", 0))
		if target < MIN_GOAL_TARGET or target > MAX_GOAL_TARGET:
			errors.append(tag + ": goal %d target must be 1..200" % index)
		var kind := int(goal.get("kind", GameTypes.GoalKind.CLEAR_PIECES))
		if kind == GameTypes.GoalKind.CLEAR_PIECES:
			var piece := int(goal.get("piece", 0))
			if not level.pieces.has(piece):
				errors.append(tag + ": goal %d asks for a piece the level does not use (%d)" % [index, piece])
			total_piece_goal += target
		elif kind == GameTypes.GoalKind.CLEAR_OBSTACLE:
			var obstacle := int(goal.get("obstacle", 0))
			if _count_obstacle_layers(level, obstacle) == 0:
				errors.append(tag + ": goal %d asks for an obstacle that is not on the board (%d)" % [index, obstacle])
		else:
			errors.append(tag + ": goal %d has unknown kind %d" % [index, kind])

	var occupied: Dictionary = {}
	for index in range(level.obstacles.size()):
		var obstacle: Dictionary = level.obstacles[index]
		var x := int(obstacle.get("x", -1))
		var y := int(obstacle.get("y", -1))
		if x < 0 or y < 0 or x >= level.width or y >= level.height:
			errors.append(tag + ": obstacle %d is out of bounds (%d,%d)" % [index, x, y])
		else:
			var pos := Vector2i(x, y)
			if occupied.has(pos):
				errors.append(tag + ": two obstacles on the same cell (%d,%d)" % [x, y])
			occupied[pos] = true
		var layers := int(obstacle.get("layers", 1))
		if layers < 1 or layers > MAX_OBSTACLE_LAYERS:
			errors.append(tag + ": obstacle %d layers must be 1..%d" % [index, MAX_OBSTACLE_LAYERS])

	var blocked: Dictionary = {}
	for pos in level.blocked:
		if pos.x < 0 or pos.y < 0 or pos.x >= level.width or pos.y >= level.height:
			errors.append(tag + ": blocked cell out of bounds %s" % str(pos))
		elif blocked.has(pos):
			errors.append(tag + ": duplicate blocked cell %s" % str(pos))
		elif occupied.has(pos):
			errors.append(tag + ": blocked cell also holds an obstacle %s" % str(pos))
		blocked[pos] = true

	if level.reward_potions < 0 or level.reward_potions > 500:
		errors.append(tag + ": reward_potions must be 0..500")
	if level.reward_coins < 0 or level.reward_coins > 1000:
		errors.append(tag + ": reward_coins must be 0..1000")
	if total_piece_goal > level.move_limit * 15:
		errors.append(tag + ": piece goals exceed the rough move capacity")
	return errors

static func validate_catalog(levels: Array[LevelDefinition]) -> Array[String]:
	var errors: Array[String] = []
	if levels.is_empty():
		errors.append("catalog is empty")
		return errors
	var ids: Dictionary = {}
	var numbers: Dictionary = {}
	for level in levels:
		if level == null:
			continue
		if ids.has(level.id):
			errors.append("duplicate level id '%s'" % level.id)
		ids[level.id] = true
		if numbers.has(level.number):
			errors.append("duplicate level number %d" % level.number)
		numbers[level.number] = true
	for number in range(1, levels.size() + 1):
		if not numbers.has(number):
			errors.append("missing level number %d" % number)
	return errors

static func _count_obstacle_layers(level: LevelDefinition, kind: int) -> int:
	var total := 0
	for obstacle in level.obstacles:
		if int(obstacle.get("kind", 0)) == kind:
			total += int(obstacle.get("layers", 1))
	return total
