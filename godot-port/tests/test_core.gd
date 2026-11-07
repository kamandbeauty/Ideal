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
	create_timer(45.0).timeout.connect(_on_timeout)
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
	var rng_a = Rng.new(0, 1)
	var rng_b = Rng.new(0, 1)
	var rng_sequence_matches := true
	for _i in range(20):
		if rng_a.next(97) != rng_b.next(97):
			rng_sequence_matches = false
			break
	failures += _check(rng_sequence_matches, "seeded RNG sequence is repeatable")

	print("TEST STAGE 3: power-up targets")
	var blast_board = Board.new(5, 5)
	var targets: Array[Vector2i] = []
	Powers.add_square(blast_board, Vector2i(2, 2), 1, targets)
	failures += _check(targets.size() == 9, "dynamite 3x3 target area")

	print("TEST STAGE 4: board generation")
	var level = Level.new()
	level.width = 7
	level.height = 7
	level.pieces = [1, 2, 3, 4, 5]
	level.goals = [{"kind": 0, "piece": 1, "target": 10}]
	var generated = Factory.create(level, 0, 12345)
	failures += _check(not Finder.has_match(generated), "opening board has no automatic match")
	failures += _check(Finder.has_possible_move(generated), "opening board has a legal move")

	print("TEST STAGE 5: move resolver")
	var move_level = Level.new()
	move_level.width = 5
	move_level.height = 5
	move_level.pieces = [1, 2, 3, 4, 5]
	move_level.goals = [{"kind": 0, "piece": 1, "target": 10}]
	var move_board = Board.from_ascii(PackedStringArray(["FLAFZ", "ZAFML", "MLFZA", "AFZML", "LZAMF"]))
	var tracker = Goals.new(move_level.goals)
	var resolver = Resolver.new(move_level, move_board, Rng.new(0, 99), tracker)
	var rejected = resolver.swap(Vector2i(-1, 0), Vector2i(0, 0))
	failures += _check(not rejected.accepted and rejected.reject_reason == "out of bounds", "reject out-of-bounds swap")

	var swap_board = Board.from_ascii(PackedStringArray(["ALMZA", "ZFMAL", "FAFZA", "MLZAF", "AFZML"]))
	var swap_tracker = Goals.new([{"kind": 0, "piece": 1, "target": 10}])
	var swap_resolver = Resolver.new(move_level, swap_board, Rng.new(0, 7), swap_tracker)
	var accepted = swap_resolver.swap(Vector2i(1, 3), Vector2i(1, 2))
	failures += _check(accepted.accepted, "accept a swap that creates a three-piece match")
	failures += _check(accepted.pieces_cleared >= 3, "clear matched pieces during move resolution")
	failures += _check(swap_tracker.progress(0) >= 3, "record cleared-piece goal progress")

	print("Godot core tests: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> int:
	if condition:
		print("PASS: " + label)
		return 0
	push_error("FAIL: " + label)
	return 1

func _on_timeout() -> void:
	push_error("Core test timed out before completing")
	quit(2)
