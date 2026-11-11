class_name PowerUps
extends RefCounted

const SQUARE_RADIUS := 1
const MAX_TARGETS := 400

## Everything a special piece takes with it when it fires.
##
## `colour` is the piece kind the fan was swapped with, and only the fan uses it: the whole point of a
## fan is that *you* choose the colour, by choosing what to swap it with. `goals` lets the kite fly at
## the kind the level actually needs instead of at the most common colour on the board.
static func collect_targets(board: BoardModel, origin: Vector2i, kind: int, rng: DeterministicRandom,
		into: Array[Vector2i], colour: int = GameTypes.PieceKind.NONE,
		goals: GoalTracker = null) -> void:
	if into == null:
		return
	match kind:
		GameTypes.PowerUpKind.ROCKET_VERTICAL:
			add_column(board, origin.x, into)
		GameTypes.PowerUpKind.ROCKET_HORIZONTAL:
			add_row(board, origin.y, into)
		GameTypes.PowerUpKind.KITE:
			add_kind(board, most_suitable_kind(board, goals), into)
		GameTypes.PowerUpKind.FAN:
			add_kind(board, colour if colour != GameTypes.PieceKind.NONE else most_common_kind(board), into)
		GameTypes.PowerUpKind.ELECTRO_BALL:
			add_kind(board, most_common_kind(board), into)
		GameTypes.PowerUpKind.SUPER_ELECTRO_BALL:
			add_all_pieces(board, into)

## The kind a kite should fly at: the one an unfinished goal is asking for, or — when no goal names a
## colour — the one there is most of, because that is the clear that pays.
static func most_suitable_kind(board: BoardModel, goals: GoalTracker) -> int:
	if goals != null:
		for index in range(goals.count()):
			if goals.is_complete(index):
				continue
			var goal: Dictionary = goals.goal(index)
			if int(goal.get("kind", -1)) != GameTypes.GoalKind.CLEAR_PIECES:
				continue
			var wanted := int(goal.get("piece", GameTypes.PieceKind.NONE))
			if wanted != GameTypes.PieceKind.NONE and count_kind(board, wanted) > 0:
				return wanted
	return most_common_kind(board)

static func count_kind(board: BoardModel, kind: int) -> int:
	var total := 0
	for pos in board.all_positions():
		var cell = board.at_pos(pos)
		if cell != null and cell.has_piece and cell.piece == kind:
			total += 1
	return total

static func pick_spinner_target(board: BoardModel, rng: DeterministicRandom) -> Vector2i:
	var occupied: Array[Vector2i] = []
	for pos in board.all_positions():
		var cell = board.at_pos(pos)
		if cell != null and cell.has_piece:
			occupied.append(pos)
	if occupied.is_empty():
		return Vector2i.ZERO
	if rng == null:
		return occupied[0]
	return occupied[rng.next(occupied.size())]

static func collect_combo_targets(board: BoardModel, origin: Vector2i, kind_a: int, kind_b: int, rng: DeterministicRandom, into: Array[Vector2i]) -> void:
	if kind_a == GameTypes.PowerUpKind.SUPER_ELECTRO_BALL or kind_b == GameTypes.PowerUpKind.SUPER_ELECTRO_BALL:
		add_all_pieces(board, into)
		return
	var electro_a := kind_a == GameTypes.PowerUpKind.ELECTRO_BALL
	var electro_b := kind_b == GameTypes.PowerUpKind.ELECTRO_BALL
	if electro_a and electro_b:
		add_all_pieces(board, into)
		return
	if electro_a or electro_b:
		add_kind(board, most_common_kind(board), into)
		return

	var rocket_a := kind_a == GameTypes.PowerUpKind.ROCKET_VERTICAL or kind_a == GameTypes.PowerUpKind.ROCKET_HORIZONTAL
	var rocket_b := kind_b == GameTypes.PowerUpKind.ROCKET_VERTICAL or kind_b == GameTypes.PowerUpKind.ROCKET_HORIZONTAL
	var fan_a := kind_a == GameTypes.PowerUpKind.FAN
	var fan_b := kind_b == GameTypes.PowerUpKind.FAN
	var kite_a := kind_a == GameTypes.PowerUpKind.KITE
	var kite_b := kind_b == GameTypes.PowerUpKind.KITE

	# Two specials swapped together should always beat either one alone, so the table below only ever
	# adds: every entry is "what the pair takes", never "what it replaces".
	if fan_a and fan_b:
		add_all_pieces(board, into)
		return
	if kite_a and kite_b:
		add_all_pieces(board, into)
		return
	if rocket_a and rocket_b:
		add_row(board, origin.y, into)
		add_column(board, origin.x, into)
		return
	if (fan_a and kite_b) or (fan_b and kite_a):
		add_kind(board, most_suitable_kind(board, null), into)
		add_kind(board, most_common_kind(board), into)
		return
	if (fan_a or fan_b) and (rocket_a or rocket_b):
		add_kind(board, most_common_kind(board), into)
		add_row(board, origin.y, into)
		add_column(board, origin.x, into)
		return
	if (kite_a or kite_b) and (rocket_a or rocket_b):
		add_kind(board, most_suitable_kind(board, null), into)
		add_row(board, origin.y, into)
		add_column(board, origin.x, into)
		return
	collect_targets(board, origin, kind_a, rng, into)
	collect_targets(board, origin, kind_b, rng, into)

static func most_common_kind(board: BoardModel) -> int:
	# One slot per piece value, including 0 and the three fruits added later: the old six-slot array
	# stopped indexing at the sixth kind, which is a crash the moment a pineapple is on the board.
	var counts := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	for pos in board.all_positions():
		var cell = board.at_pos(pos)
		if cell == null or not cell.has_piece:
			continue
		counts[cell.piece] += 1
	var best := 0
	for index in range(1, counts.size()):
		if counts[index] > counts[best]:
			best = index
	return best

static func add_row(board: BoardModel, y: int, into: Array[Vector2i]) -> void:
	if y < 0 or y >= board.height:
		return
	for x in range(board.width):
		_add_unique(into, Vector2i(x, y))

static func add_column(board: BoardModel, x: int, into: Array[Vector2i]) -> void:
	if x < 0 or x >= board.width:
		return
	for y in range(board.height):
		_add_unique(into, Vector2i(x, y))

static func add_square(board: BoardModel, origin: Vector2i, radius: int, into: Array[Vector2i]) -> void:
	for y in range(origin.y - radius, origin.y + radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			if board.in_bounds(x, y):
				_add_unique(into, Vector2i(x, y))

static func add_kind(board: BoardModel, kind: int, into: Array[Vector2i]) -> void:
	if kind == GameTypes.PieceKind.NONE:
		return
	for pos in board.all_positions():
		var cell = board.at_pos(pos)
		if cell != null and cell.has_piece and cell.piece == kind:
			_add_unique(into, pos)

static func add_all_pieces(board: BoardModel, into: Array[Vector2i]) -> void:
	for pos in board.all_positions():
		var cell = board.at_pos(pos)
		if cell != null and cell.has_piece:
			_add_unique(into, pos)

static func _add_unique(into: Array[Vector2i], pos: Vector2i) -> void:
	if into.size() >= MAX_TARGETS or into.has(pos):
		return
	into.append(pos)
