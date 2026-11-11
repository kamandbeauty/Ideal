class_name MoveResolver
extends RefCounted

const MAX_CASCADES := 64
const MAX_TRIGGER_CHAIN := 64

var _level: LevelDefinition
var _board: BoardModel
var _rng: DeterministicRandom
var _goals: GoalTracker

func _init(level: LevelDefinition, board: BoardModel, rng: DeterministicRandom, goals: GoalTracker) -> void:
	_level = level
	_board = board
	_rng = rng
	_goals = goals

func swap(from_pos: Vector2i, to_pos: Vector2i) -> Dictionary:
	if not _board.in_bounds(from_pos.x, from_pos.y) or not _board.in_bounds(to_pos.x, to_pos.y):
		return _rejected(GameTypes.MoveKind.SWAP, "out of bounds")
	if absi(from_pos.x - to_pos.x) + absi(from_pos.y - to_pos.y) != 1:
		return _rejected(GameTypes.MoveKind.SWAP, "not adjacent")

	var a = _board.at_pos(from_pos)
	var b = _board.at_pos(to_pos)
	if a == null or b == null or not a.has_piece or not b.has_piece:
		return _rejected(GameTypes.MoveKind.SWAP, "empty cell")

	var power_a: int = a.power_up
	var power_b: int = b.power_up
	var kind_a: int = a.piece
	var kind_b: int = b.piece
	var both_power_ups := power_a != GameTypes.PowerUpKind.NONE and power_b != GameTypes.PowerUpKind.NONE
	# A fan is moved into a piece, not matched: the swap itself is the move, and the colour it takes is
	# the colour of the piece it traded places with. That is the whole promise of the piece.
	var fan_swap := (power_a == GameTypes.PowerUpKind.FAN) != (power_b == GameTypes.PowerUpKind.FAN)
	_swap_cells(a, b)

	if not both_power_ups and not fan_swap:
		# Only a line of three clears. A 2 x 2 block used to count here as well, and because the board
		# is dealt without lines but with squares, the first move of most levels took four unrelated
		# pieces with it. The rule was inherited from the Unity prototype and it was a bug.
		if not MatchFinder.has_match(_board):
			_swap_cells(a, b)
			return _rejected(GameTypes.MoveKind.SWAP, "no match")

	if fan_swap and not both_power_ups:
		var fan_result := _new_result(GameTypes.MoveKind.SWAP)
		var fan_pos := to_pos if power_a == GameTypes.PowerUpKind.FAN else from_pos
		var wanted: int = kind_b if power_a == GameTypes.PowerUpKind.FAN else kind_a
		var fan_cell = _board.at_pos(fan_pos)
		if fan_cell != null:
			fan_cell.power_up = GameTypes.PowerUpKind.NONE
		_add_event(fan_result, {"type": "power_up_triggered", "position": fan_pos,
			"kind": GameTypes.PowerUpKind.FAN})
		var fan_targets: Array[Vector2i] = []
		PowerUps.add_kind(_board, wanted, fan_targets)
		_add_unique(fan_targets, fan_pos)
		_add_unique(fan_targets, from_pos)
		_add_unique(fan_targets, to_pos)
		_expand_triggers(fan_targets, fan_result)
		_apply_clears(fan_targets, fan_result)
		_fall_and_refill()
		_resolve_cascades(fan_result, to_pos, true)
		_settle(fan_result)
		return fan_result

	var result := _new_result(GameTypes.MoveKind.SWAP)
	if both_power_ups:
		var targets: Array[Vector2i] = []
		PowerUps.collect_combo_targets(_board, to_pos, power_a, power_b, _rng, targets)
		_add_event(result, {"type": "power_up_triggered", "position": to_pos, "kind": power_a})
		_add_event(result, {"type": "power_up_triggered", "position": to_pos, "kind": power_b})
		var destination = _board.at_pos(to_pos)
		if destination != null:
			destination.power_up = GameTypes.PowerUpKind.NONE
		_add_unique(targets, to_pos)
		_expand_triggers(targets, result)
		_apply_clears(targets, result)
		_fall_and_refill()

	_resolve_cascades(result, to_pos, true)
	_settle(result)
	return result

func use_booster(kind: int, target: Vector2i) -> Dictionary:
	if not _board.in_bounds(target.x, target.y):
		return _rejected(GameTypes.MoveKind.BOOSTER, "out of bounds")
	var result := _new_result(GameTypes.MoveKind.BOOSTER)
	var cells: Array[Vector2i] = []
	match kind:
		GameTypes.BoosterKind.MALLET:
			_add_unique(cells, target)
		GameTypes.BoosterKind.RAM:
			PowerUps.add_row(_board, target.y, cells)
		GameTypes.BoosterKind.AUGER:
			PowerUps.add_column(_board, target.x, cells)
		GameTypes.BoosterKind.WHIRLWIND:
			BoardFactory.reshuffle(_board, _level.pieces, _rng)
			_add_event(result, {"type": "board_reshuffled"})
			_settle(result)
			return result
		GameTypes.BoosterKind.FALCON:
			for _index in range(3):
				var splash := PowerUps.pick_spinner_target(_board, _rng)
				PowerUps.add_square(_board, splash, 1, cells)

	_expand_triggers(cells, result)
	_apply_clears(cells, result)
	_fall_and_refill()
	_resolve_cascades(result, target, false)
	_settle(result)
	return result

func _resolve_cascades(result: Dictionary, preferred: Vector2i, has_preferred: bool) -> void:
	var cascade := 0
	while cascade < MAX_CASCADES:
		var runs := MatchFinder.find_runs(_board)
		if runs.is_empty():
			break

		cascade += 1
		result.cascades = cascade
		_add_event(result, {"type": "cascade", "index": cascade})
		var clear_set: Array[Vector2i] = []
		var spawns: Array[Dictionary] = []
		var clusters := MatchFinder.build_clusters(runs)

		for cluster in clusters:
			for pos in cluster.cells:
				_add_unique(clear_set, pos)
			var power_kind := MatchFinder.power_up_for(cluster)
			if power_kind == GameTypes.PowerUpKind.NONE:
				continue
			var spawn_pos: Vector2i = MatchFinder.choose_spawn_cell(cluster, preferred, has_preferred and cascade == 1)
			var spawn_cell = _board.at_pos(spawn_pos)
			var spawn_piece: int = spawn_cell.piece if spawn_cell != null else int(cluster.runs[0].piece)
			spawns.append({"position": spawn_pos, "kind": power_kind, "piece": spawn_piece})

		_expand_triggers(clear_set, result)
		for spawn in spawns:
			clear_set.erase(spawn.position)
		_apply_clears(clear_set, result)
		_spawn_power_ups(spawns, result)
		_fall_and_refill()
		has_preferred = false

func _spawn_power_ups(spawns: Array[Dictionary], result: Dictionary) -> void:
	for spawn in spawns:
		var cell = _board.at_pos(spawn.position)
		if cell == null or cell.blocked:
			continue
		if not cell.has_piece:
			cell.piece = int(spawn.piece)
		cell.power_up = int(spawn.kind)
		result.power_ups_created += 1
		_add_event(result, {"type": "power_up_created", "position": spawn.position, "kind": cell.power_up, "piece": cell.piece})

func _expand_triggers(clear_set: Array[Vector2i], result: Dictionary) -> void:
	var queue: Array[Vector2i] = []
	for pos in clear_set:
		var cell = _board.at_pos(pos)
		if cell != null and cell.power_up != GameTypes.PowerUpKind.NONE and cell.has_piece:
			queue.append(pos)
	var guard := 0
	while not queue.is_empty() and guard < MAX_TRIGGER_CHAIN:
		guard += 1
		var pos: Vector2i = queue.pop_front()
		var cell = _board.at_pos(pos)
		if cell == null or cell.power_up == GameTypes.PowerUpKind.NONE:
			continue
		var power_kind: int = cell.power_up
		cell.power_up = GameTypes.PowerUpKind.NONE
		_add_event(result, {"type": "power_up_triggered", "position": pos, "kind": power_kind})
		var targets: Array[Vector2i] = []
		PowerUps.collect_targets(_board, pos, power_kind, _rng, targets,
			GameTypes.PieceKind.NONE, _goals)
		for target_pos in targets:
			if clear_set.has(target_pos):
				continue
			_add_unique(clear_set, target_pos)
			var other = _board.at_pos(target_pos)
			if other != null and other.power_up != GameTypes.PowerUpKind.NONE:
				queue.append(target_pos)

func _apply_clears(cells: Array[Vector2i], result: Dictionary) -> void:
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	for pos in cells:
		var cell = _board.at_pos(pos)
		if cell == null or cell.blocked:
			continue
		if cell.has_piece:
			var piece: int = cell.piece
			_add_event(result, {"type": "piece_cleared", "position": pos, "piece": piece, "power_up": cell.power_up})
			result.pieces_cleared += 1
			_emit_goal_progress(_goals.record_piece_cleared(piece), result)
			cell.clear_piece()
			if cell.has_obstacle:
				_damage_obstacle(pos, cell, result)
		elif cell.has_obstacle:
			_damage_obstacle(pos, cell, result)

func _damage_obstacle(pos: Vector2i, cell, result: Dictionary) -> void:
	var obstacle_kind: int = cell.obstacle
	cell.obstacle_layers -= 1
	var destroyed: bool = cell.obstacle_layers <= 0
	_add_event(result, {"type": "obstacle_hit", "position": pos, "kind": obstacle_kind, "layers_left": cell.obstacle_layers, "destroyed": destroyed})
	_emit_goal_progress(_goals.record_obstacle_layer(obstacle_kind), result)
	if destroyed:
		cell.set_obstacle(GameTypes.ObstacleKind.NONE, 0)
		result.obstacles_destroyed += 1

func _emit_goal_progress(changed: Array[int], result: Dictionary) -> void:
	for index in changed:
		var current := _goals.progress(index)
		var target := _goals.target(index)
		_add_event(result, {"type": "goal_progress", "index": index, "progress": current, "target": target, "complete": current >= target})

func _apply_gravity() -> void:
	var down := _level.gravity == GameTypes.GravityDirection.DOWN
	for x in range(_board.width):
		var write := 0 if down else _board.height - 1
		var step := 1 if down else -1
		for i in range(_board.height):
			var y := i if down else _board.height - 1 - i
			var cell = _board.at(x, y)
			if cell == null or not cell.has_piece or cell.blocked:
				continue
			while write >= 0 and write < _board.height:
				var probe = _board.at(x, write)
				if probe != null and not probe.blocked:
					break
				write += step
			if write < 0 or write >= _board.height:
				break
			if write != y:
				var target = _board.at(x, write)
				target.piece = cell.piece
				target.power_up = cell.power_up
				cell.clear_piece()
			write += step

func _refill() -> void:
	if _level.pieces.is_empty():
		return
	for pos in _board.all_positions():
		var cell = _board.at_pos(pos)
		if cell == null or cell.blocked or cell.has_piece:
			continue
		cell.piece = _level.pieces[_rng.next(_level.pieces.size())]
		cell.power_up = GameTypes.PowerUpKind.NONE

func _fall_and_refill() -> void:
	_apply_gravity()
	_refill()

func _settle(result: Dictionary) -> void:
	if MatchFinder.has_possible_move(_board):
		return
	BoardFactory.reshuffle(_board, _level.pieces, _rng)
	_add_event(result, {"type": "board_reshuffled"})

func _new_result(kind: int) -> Dictionary:
	return {"kind": kind, "accepted": true, "reject_reason": "", "events": [], "pieces_cleared": 0, "power_ups_created": 0, "cascades": 0, "obstacles_destroyed": 0}

func _rejected(kind: int, reason: String) -> Dictionary:
	var result := _new_result(kind)
	result.accepted = false
	result.reject_reason = reason
	_add_event(result, {"type": "move_rejected", "reason": reason})
	return result

func _add_event(result: Dictionary, event: Dictionary) -> void:
	result.events.append(event)

func _add_unique(list: Array[Vector2i], pos: Vector2i) -> void:
	if list.size() >= PowerUps.MAX_TARGETS or list.has(pos):
		return
	list.append(pos)

func _swap_cells(a, b) -> void:
	var piece: int = a.piece
	var power_up: int = a.power_up
	a.piece = b.piece
	a.power_up = b.power_up
	b.piece = piece
	b.power_up = power_up
