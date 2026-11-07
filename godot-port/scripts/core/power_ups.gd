class_name PowerUps
extends RefCounted

const DYNAMITE_RADIUS := 1
const SPINNER_RADIUS := 1
const MAX_TARGETS := 400

static func collect_targets(board: BoardModel, origin: Vector2i, kind: int, rng: DeterministicRandom, into: Array[Vector2i]) -> void:
	if into == null:
		return
	match kind:
		GameTypes.PowerUpKind.ROCKET_VERTICAL:
			add_column(board, origin.x, into)
		GameTypes.PowerUpKind.ROCKET_HORIZONTAL:
			add_row(board, origin.y, into)
		GameTypes.PowerUpKind.DYNAMITE:
			add_square(board, origin, DYNAMITE_RADIUS, into)
		GameTypes.PowerUpKind.SPINNER:
			var target := pick_spinner_target(board, rng)
			add_square(board, target, SPINNER_RADIUS, into)
		GameTypes.PowerUpKind.ELECTRO_BALL:
			add_kind(board, most_common_kind(board), into)
		GameTypes.PowerUpKind.SUPER_ELECTRO_BALL:
			add_all_pieces(board, into)

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
	var dynamite_a := kind_a == GameTypes.PowerUpKind.DYNAMITE
	var dynamite_b := kind_b == GameTypes.PowerUpKind.DYNAMITE
	var spinner_a := kind_a == GameTypes.PowerUpKind.SPINNER
	var spinner_b := kind_b == GameTypes.PowerUpKind.SPINNER

	if rocket_a and rocket_b:
		add_row(board, origin.y, into)
		add_column(board, origin.x, into)
		return
	if dynamite_a and dynamite_b:
		add_square(board, origin, 2, into)
		return
	if (rocket_a and dynamite_b) or (dynamite_a and rocket_b):
		for offset in range(-1, 2):
			add_row(board, origin.y + offset, into)
			add_column(board, origin.x + offset, into)
		return
	if spinner_a or spinner_b:
		var target := pick_spinner_target(board, rng)
		add_row(board, target.y, into)
		add_column(board, target.x, into)
		return
	collect_targets(board, origin, kind_a, rng, into)
	collect_targets(board, origin, kind_b, rng, into)

static func most_common_kind(board: BoardModel) -> int:
	var counts := [0, 0, 0, 0, 0, 0]
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
