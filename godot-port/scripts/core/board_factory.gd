class_name BoardFactory
extends RefCounted

static func create(level: LevelDefinition, seed_high: int, seed_low: int) -> BoardModel:
	var rng := DeterministicRandom.new(seed_high, seed_low)
	var board := BoardModel.new(level.width, level.height)
	for pos in level.blocked:
		var blocked_cell = board.at_pos(pos)
		if blocked_cell != null:
			blocked_cell.blocked = true

	for y in range(board.height):
		for x in range(board.width):
			var cell = board.at(x, y)
			if cell == null or cell.blocked:
				continue
			cell.piece = _pick_without_match(board, x, y, level.pieces, rng)

	for spec in level.obstacles:
		var obstacle_cell = board.at(int(spec.get("x", -1)), int(spec.get("y", -1)))
		if obstacle_cell == null or obstacle_cell.blocked:
			continue
		obstacle_cell.set_obstacle(int(spec.get("kind", 0)), int(spec.get("layers", 1)))
	return board

static func _pick_without_match(board: BoardModel, x: int, y: int, kinds: Array[int], rng: DeterministicRandom) -> int:
	if kinds.is_empty():
		return GameTypes.PieceKind.FIROUZEH
	var start := rng.next(kinds.size())
	for attempt in range(kinds.size()):
		var candidate := kinds[(start + attempt) % kinds.size()]
		if not _would_match(board, x, y, candidate):
			return candidate
	return kinds[start]

static func _would_match(board: BoardModel, x: int, y: int, candidate: int) -> bool:
	var left_one = board.at(x - 1, y)
	var left_two = board.at(x - 2, y)
	if left_one != null and left_two != null and left_one.has_piece and left_two.has_piece and left_one.piece == candidate and left_two.piece == candidate:
		return true
	var down_one = board.at(x, y - 1)
	var down_two = board.at(x, y - 2)
	if down_one != null and down_two != null and down_one.has_piece and down_two.has_piece and down_one.piece == candidate and down_two.piece == candidate:
		return true
	return false

static func reshuffle(board: BoardModel, kinds: Array[int], rng: DeterministicRandom) -> void:
	var pieces: Array[int] = []
	for pos in board.all_positions():
		var cell = board.at_pos(pos)
		if cell != null and cell.has_piece:
			pieces.append(cell.piece)
	for attempt in range(24):
		rng.shuffle(pieces)
		var index := 0
		for pos in board.all_positions():
			var cell = board.at_pos(pos)
			if cell == null or not cell.has_piece:
				continue
			cell.piece = pieces[index]
			index += 1
		if MatchFinder.find_runs(board).is_empty() and MatchFinder.has_possible_move(board):
			return
	for pos in board.all_positions():
		var cell = board.at_pos(pos)
		if cell == null or not cell.has_piece:
			continue
		cell.piece = kinds[rng.next(kinds.size())] if not kinds.is_empty() else GameTypes.PieceKind.FIROUZEH
