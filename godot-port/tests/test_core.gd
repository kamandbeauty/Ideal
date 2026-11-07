extends SceneTree

const Board = preload("res://scripts/core/board_model.gd")
const Finder = preload("res://scripts/core/match_finder.gd")
const Rng = preload("res://scripts/core/deterministic_random.gd")
const Powers = preload("res://scripts/core/power_ups.gd")
const Factory = preload("res://scripts/core/board_factory.gd")
const Level = preload("res://scripts/core/level_definition.gd")
const Goals = preload("res://scripts/core/goal_tracker.gd")
const Resolver = preload("res://scripts/core/move_resolver.gd")

func _initialize() -> void:
	create_timer(20.0).timeout.connect(_on_timeout)
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	print("TEST STAGE 1: board and match detection")
	var board = Board.from_ascii(PackedStringArray([".....", ".....", "FFF..", ".....", "....."]))
	failures += _check(Finder.find_runs(board).size() == 1, "detect horizontal run of three")
	failures += _check(Finder.find_runs(board)[0].length == 3, "horizontal run length")
	failures += _check(not Finder.has_match(Board.from_ascii(PackedStringArray(["F....", ".F...", "..F..", "...F.", "....F"]))), "diagonal is not a match")
	var square_board = Board.from_ascii(PackedStringArray(["....", ".FF.", ".FF.", "...."]))
	failures += _check(Finder.find_squares(square_board).size() == 1, "detect 2x2 square")
	var clone = board.duplicate_board()
	clone.at(0, 2).clear_piece()
	failures += _check(board.at(0, 2).has_piece and not clone.at(0, 2).has_piece, "board clone is independent")

	print("TEST STAGE 2: deterministic RNG")
	var rng_reference = Rng.new(0, 1)
	failures += _check(rng_reference.next(97) == 30, "xorshift64* reference vector for seed 1")
	failures += _check(rng_reference.state_hex() == "0000000002000001", "xorshift64* state reference vector")
	var expected := [29, 42, 2, 14, 92, 33, 12, 87, 27]
	for expected_value in expected:
		failures += _check(rng_reference.next(97) == expected_value, "xorshift64* sequence value %d" % expected_value)

	print("TEST STAGE 3: power-up target geometry")
	var power_board = Board.new(5, 5)
	var blast_targets: Array[Vector2i] = []
	Powers.add_square(power_board, Vector2i(2, 2), 1, blast_targets)
	failures += _check(blast_targets.size() == 9, "dynamite targets exactly a 3x3 area")
	var row_targets: Array[Vector2i] = []
	Powers.add_row(power_board, 2, row_targets)
	failures += _check(row_targets.size() == 5, "rocket row target count")
	var column_targets: Array[Vector2i] = []
	Powers.add_column(power_board, 3, column_targets)
	failures += _check(column_targets.size() == 5, "rocket column target count")

	print("TEST STAGE 3B: power-up target rules")
	var mixed_board = Board.from_ascii(PackedStringArray(["FFFFF", "LLLLL", "FFLFL", "FLLFF", "LLFFF"]))
	var all_targets: Array[Vector2i] = []
	Powers.collect_targets(mixed_board, Vector2i(2, 2), GameTypes.PowerUpKind.SUPER_ELECTRO_BALL, Rng.new(0, 1), all_targets)
	failures += _check(all_targets.size() == 25, "super electro ball targets every occupied cell")
	var electro_targets: Array[Vector2i] = []
	Powers.collect_targets(mixed_board, Vector2i(2, 2), GameTypes.PowerUpKind.ELECTRO_BALL, Rng.new(0, 1), electro_targets)
	failures += _check(Powers.most_common_kind(mixed_board) == GameTypes.PieceKind.FIROUZEH, "electro ball selects most common piece kind")
	failures += _check(electro_targets.size() == 15, "electro ball targets all pieces of the most common kind")
	var combo_targets: Array[Vector2i] = []
	Powers.collect_combo_targets(mixed_board, Vector2i(2, 2), GameTypes.PowerUpKind.ROCKET_VERTICAL, GameTypes.PowerUpKind.ROCKET_HORIZONTAL, Rng.new(0, 1), combo_targets)
	failures += _check(combo_targets.size() == 9, "rocket pair combo clears one row and one column without duplicates")

	print("TEST STAGE 4: deterministic opening board")
	var level = Level.new()
	level.width = 7
	level.height = 7
	var level_pieces: Array[int] = [1, 2, 3, 4, 5]
	level.pieces = level_pieces
	var level_goals: Array[Dictionary] = [{"kind": 0, "piece": 1, "target": 10}]
	level.goals = level_goals
	var opening_a = Factory.create(level, 0, 12345)
	var opening_b = Factory.create(level, 0, 12345)
	failures += _check(not Finder.has_match(opening_a), "opening board contains no automatic match")
	failures += _check(opening_a.to_ascii() == opening_b.to_ascii(), "opening board is reproducible from the same seed")
	failures += _check(level.is_structurally_valid(), "valid level model passes structural validation")
	failures += _check(Finder.has_possible_move(opening_a), "generated board has at least one legal move")

	print("TEST STAGE 5: goal tracking and rejected moves")
	var tracker = Goals.new(level.goals)
	var changed = tracker.record_piece_cleared(1)
	failures += _check(changed.size() == 1 and tracker.progress(0) == 1, "record matching piece goal progress")
	var move_level = Level.new()
	move_level.width = 5
	move_level.height = 5
	var move_pieces: Array[int] = [1, 2, 3, 4, 5]
	move_level.pieces = move_pieces
	var move_goals: Array[Dictionary] = [{"kind": 0, "piece": 1, "target": 10}]
	move_level.goals = move_goals
	var move_board = Board.from_ascii(PackedStringArray(["FLAFZ", "ZAFML", "MLFZA", "AFZML", "LZAMF"]))
	var move_tracker = Goals.new(move_level.goals)
	var resolver = Resolver.new(move_level, move_board, Rng.new(0, 99), move_tracker)
	var rejected_bounds = resolver.swap(Vector2i(-1, 0), Vector2i(0, 0))
	failures += _check(not rejected_bounds.accepted and rejected_bounds.reject_reason == "out of bounds", "reject out-of-bounds swap")
	var before_rejected := move_board.to_ascii()
	var rejected_match = resolver.swap(Vector2i(0, 4), Vector2i(1, 4))
	failures += _check(not rejected_match.accepted and rejected_match.reject_reason == "no match", "reject swap that creates no match")
	failures += _check(move_board.to_ascii() == before_rejected, "restore board after rejected swap")
	var accepted_board = Board.from_ascii(PackedStringArray(["ALMZA", "ZFMAL", "FAFZA", "MLZAF", "AFZML"]))
	accepted_board.at(0, 2).set_obstacle(GameTypes.ObstacleKind.CRATE, 1)
	var accepted_level = Level.new()
	accepted_level.width = 5
	accepted_level.height = 5
	accepted_level.pieces = move_pieces
	var accepted_goals: Array[Dictionary] = [
		{"kind": GameTypes.GoalKind.CLEAR_PIECES, "piece": GameTypes.PieceKind.FIROUZEH, "target": 10},
		{"kind": GameTypes.GoalKind.CLEAR_OBSTACLE, "obstacle": GameTypes.ObstacleKind.CRATE, "target": 1}
	]
	accepted_level.goals = accepted_goals
	var accepted_tracker = Goals.new(accepted_level.goals)
	var accepted_resolver = Resolver.new(accepted_level, accepted_board, Rng.new(0, 7), accepted_tracker)
	var accepted_move = accepted_resolver.swap(Vector2i(1, 3), Vector2i(1, 2))
	failures += _check(accepted_move.accepted, "accept swap that creates a three-piece match")
	failures += _check(accepted_move.pieces_cleared >= 3, "clear matched pieces during accepted move")
	failures += _check(accepted_tracker.progress(0) >= 3, "apply piece-goal progress during accepted move")
	failures += _check(accepted_move.obstacles_destroyed == 1 and accepted_tracker.progress(1) == 1, "clear obstacle layer and advance obstacle goal")

	print("Godot core tests: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _on_timeout() -> void:
	push_error("Core test timed out before completing")
	quit(2)

func _check(condition: bool, label: String) -> int:
	if condition:
		print("PASS: " + label)
		return 0
	push_error("FAIL: " + label)
	return 1
