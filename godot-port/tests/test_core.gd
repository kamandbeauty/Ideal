extends SceneTree

const Board = preload("res://scripts/core/board_model.gd")
const Finder = preload("res://scripts/core/match_finder.gd")
const Rng = preload("res://scripts/core/deterministic_random.gd")
const Powers = preload("res://scripts/core/power_ups.gd")
const Factory = preload("res://scripts/core/board_factory.gd")
const Level = preload("res://scripts/core/level_definition.gd")

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
