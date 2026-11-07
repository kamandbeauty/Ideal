extends SceneTree

const Board = preload("res://scripts/core/board_model.gd")
const Finder = preload("res://scripts/core/match_finder.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	var board = Board.from_ascii(PackedStringArray([".....", ".....", "FFF..", ".....", "....."]))
	failures += _check(Finder.find_runs(board).size() == 1, "detect horizontal run of three")
	failures += _check(Finder.find_runs(board)[0].length == 3, "horizontal run length")
	failures += _check(not Finder.has_match(Board.from_ascii(PackedStringArray(["F....", ".F...", "..F..", "...F.", "....F"]))), "diagonal is not a match")
	var square_board = Board.from_ascii(PackedStringArray(["....", ".FF.", ".FF.", "...."]))
	failures += _check(Finder.find_squares(square_board).size() == 1, "detect 2x2 square")
	var clone = board.duplicate_board()
	clone.at(0, 2).clear_piece()
	failures += _check(board.at(0, 2).has_piece and not clone.at(0, 2).has_piece, "board clone is independent")
	print("Godot core tests: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> int:
	if condition:
		print("PASS: " + label)
		return 0
	push_error("FAIL: " + label)
	return 1
