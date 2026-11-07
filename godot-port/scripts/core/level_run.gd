class_name LevelRun
extends RefCounted

var level: LevelDefinition
var board: BoardModel
var goals: GoalTracker
var seed_high: int
var seed_low: int
var random: DeterministicRandom
var moves_left: int
var moves_used := 0
var potions_earned := 0
var coins_earned := 0
var status: int = GameTypes.LevelStatus.PLAYING
var boosters_used: Array[int] = []
var _resolver: MoveResolver

func _init(level_definition: LevelDefinition, high_word: int, low_word: int) -> void:
	level = level_definition
	seed_high = high_word & 0xffffffff
	seed_low = low_word & 0xffffffff
	moves_left = level.move_limit
	status = GameTypes.LevelStatus.PLAYING
	board = BoardFactory.create(level, seed_high, seed_low)
	# Keep board generation and in-level effects on separate deterministic streams.
	random = DeterministicRandom.new(seed_high, seed_low ^ 0x51ed270b)
	goals = GoalTracker.new(level.goals)
	_resolver = MoveResolver.new(level, board, random, goals)
	if not MatchFinder.has_possible_move(board):
		BoardFactory.reshuffle(board, level.pieces, random)

func try_swap(from_x: int, from_y: int, to_x: int, to_y: int) -> Dictionary:
	if status != GameTypes.LevelStatus.PLAYING:
		return _rejected(GameTypes.MoveKind.SWAP, "level already finished")
	if moves_left <= 0:
		return _rejected(GameTypes.MoveKind.SWAP, "no moves left")
	var result := _resolver.swap(Vector2i(from_x, from_y), Vector2i(to_x, to_y))
	if not result.accepted:
		return result
	moves_left -= 1
	moves_used += 1
	_evaluate()
	return result

func use_booster(kind: int, x: int, y: int) -> Dictionary:
	if status != GameTypes.LevelStatus.PLAYING:
		return _rejected(GameTypes.MoveKind.BOOSTER, "level already finished")
	var result := _resolver.use_booster(kind, Vector2i(x, y))
	if not result.accepted:
		return result
	boosters_used.append(kind)
	_evaluate()
	return result

func revert_last_booster(kind: int) -> void:
	for index in range(boosters_used.size() - 1, -1, -1):
		if boosters_used[index] != kind:
			continue
		boosters_used.remove_at(index)
		return

func _evaluate() -> void:
	if status != GameTypes.LevelStatus.PLAYING:
		return
	if goals.all_complete():
		status = GameTypes.LevelStatus.WON
		potions_earned = level.reward_potions
		coins_earned = level.reward_coins
		return
	if moves_left <= 0:
		status = GameTypes.LevelStatus.LOST
		potions_earned = 0
		coins_earned = 0

func state_hash_hex() -> String:
	return StateHash.compute_run(self)

func goal_summary() -> String:
	var parts: PackedStringArray = []
	for index in range(goals.count()):
		parts.append("%d/%d" % [goals.progress(index), goals.target(index)])
	return " ".join(parts)

func _rejected(kind: int, reason: String) -> Dictionary:
	return {"kind": kind, "accepted": false, "reject_reason": reason, "events": [{"type": "move_rejected", "reason": reason}], "pieces_cleared": 0, "power_ups_created": 0, "cascades": 0, "obstacles_destroyed": 0}
