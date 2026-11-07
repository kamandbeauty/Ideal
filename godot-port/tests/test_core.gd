extends SceneTree

const Board = preload("res://scripts/core/board_model.gd")
const Finder = preload("res://scripts/core/match_finder.gd")
const Rng = preload("res://scripts/core/deterministic_random.gd")
const Powers = preload("res://scripts/core/power_ups.gd")
const Factory = preload("res://scripts/core/board_factory.gd")
const Level = preload("res://scripts/core/level_definition.gd")
const Goals = preload("res://scripts/core/goal_tracker.gd")
const Resolver = preload("res://scripts/core/move_resolver.gd")
const Save = preload("res://scripts/core/save_data.gd")
const WalletScript = preload("res://scripts/core/wallet.gd")
const Bag = preload("res://scripts/core/booster_bag.gd")
const Clock = preload("res://scripts/core/manual_clock.gd")
const LivesScript = preload("res://scripts/core/lives.gd")
const Run = preload("res://scripts/core/level_run.gd")
const ProgressionScript = preload("res://scripts/core/progression.gd")
const Stars = preload("res://scripts/core/star_rating.gd")
const Codec = preload("res://scripts/core/save_codec.gd")
const Store = preload("res://scripts/core/save_store.gd")

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
	failures += _check(electro_targets.size() == 14, "electro ball targets all pieces of the most common kind")
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


	print("TEST STAGE 6: power-up creation and chained activation")
	var four_match_board = Board.from_ascii(PackedStringArray(["ALMZA", "ZFMAL", "FAFFZ", "MLZAF", "AFZML"]))
	var four_match_resolver = Resolver.new(move_level, four_match_board, Rng.new(0, 17), Goals.new(move_level.goals))
	var four_match_result = four_match_resolver.swap(Vector2i(1, 3), Vector2i(1, 2))
	failures += _check(four_match_result.accepted and four_match_result.power_ups_created >= 1, "four-piece match creates a rocket power-up")

	var booster_board = move_board.duplicate_board()
	booster_board.at(2, 2).power_up = GameTypes.PowerUpKind.ROCKET_VERTICAL
	var booster_resolver = Resolver.new(move_level, booster_board, Rng.new(0, 23), Goals.new(move_level.goals))
	var booster_result = booster_resolver.use_booster(GameTypes.BoosterKind.MALLET, Vector2i(2, 2))
	var saw_trigger_event := false
	for event in booster_result.events:
		if event.get("type", "") == "power_up_triggered":
			saw_trigger_event = true
	failures += _check(booster_result.accepted and saw_trigger_event, "mallet triggers a power-up on its target")
	failures += _check(booster_result.pieces_cleared >= 5, "triggered vertical rocket clears its column")


	print("TEST STAGE 7: wallet, booster inventory and lives")
	var save_data = Save.new()
	save_data.coins = 200
	save_data.potions = 20
	var wallet = WalletScript.new(save_data)
	failures += _check(wallet.try_spend_coins(40) and wallet.coins == 160, "wallet spends affordable coins")
	failures += _check(not wallet.try_spend_coins(1000) and wallet.coins == 160, "wallet refuses overspending")
	wallet.grant(999999999, 1)
	failures += _check(wallet.coins == WalletScript.MAX_BALANCE, "wallet clamps balance to configured maximum")
	var bag = Bag.new(save_data)
	bag.grant(GameTypes.BoosterKind.MALLET, 2)
	failures += _check(bag.count(GameTypes.BoosterKind.MALLET) == 2, "booster bag grants inventory")
	failures += _check(bag.buy(GameTypes.BoosterKind.RAM, wallet, 2) and bag.count(GameTypes.BoosterKind.RAM) == 2, "booster bag buys a requested quantity")
	failures += _check(bag.try_consume(GameTypes.BoosterKind.RAM) and bag.count(GameTypes.BoosterKind.RAM) == 1, "booster bag consumes one item")

	var clock = Clock.new(1700000000)
	save_data.lives = 5
	save_data.max_lives = 5
	save_data.lives_updated_at_unix = clock.now_unix()
	var lives = LivesScript.new(save_data, clock)
	failures += _check(lives.try_spend() and lives.current == 4, "spend one life")
	clock.advance(LivesScript.REFILL_SECONDS)
	failures += _check(lives.refresh() == 1 and lives.current == 5, "refill one life after thirty minutes")
	failures += _check(lives.is_full and lives.next_refill_in_seconds == 0, "full lives pool has no refill countdown")

	print("TEST STAGE 8: level run, state hash, stars and progression")
	var progression_level = Level.new()
	progression_level.id = "test-01"
	progression_level.number = 1
	progression_level.width = 7
	progression_level.height = 7
	progression_level.move_limit = 20
	progression_level.reward_coins = 10
	progression_level.reward_potions = 2
	var progression_pieces: Array[int] = [1, 2, 3, 4, 5]
	progression_level.pieces = progression_pieces
	var progression_goals: Array[Dictionary] = [{"kind": 0, "piece": 1, "target": 1}]
	progression_level.goals = progression_goals
	var run_a = Run.new(progression_level, 0, 12345)
	var run_b = Run.new(progression_level, 0, 12345)
	failures += _check(run_a.state_hash_hex() == run_b.state_hash_hex(), "same seed produces same initial replay hash")
	failures += _check(Stars.from_moves(20, 4) == 1 and Stars.from_moves(20, 5) == 2 and Stars.from_moves(20, 10) == 3, "star thresholds use exact integer percentages")
	run_a.status = GameTypes.LevelStatus.WON
	run_a.moves_left = 10
	var progression = ProgressionScript.new(save_data, clock)
	var first_result = progression.record_level_result(run_a, wallet)
	failures += _check(first_result.first_clear and wallet.coins == WalletScript.MAX_BALANCE and wallet.potions == 23, "first clear grants reward and records progression")
	var repeat_result = progression.record_level_result(run_a, wallet)
	failures += _check(not repeat_result.first_clear and wallet.potions == 23, "replay does not pay first-clear reward twice")
	failures += _check(progression.highest_unlocked_level == 2 and Stars.from_run(run_a) == 3, "first clear unlocks next level and computes stars")
	failures += _check(progression.try_complete_task("d1-t1", 3, wallet), "complete a task and spend its potion cost")
	var potions_after_task: int = wallet.potions
	failures += _check(not progression.try_complete_task("d1-t1", 3, wallet) and wallet.potions == potions_after_task, "completed task cannot be charged twice")
	var district_tasks: Array[Dictionary] = [
		{"key": "d1-t2", "potion_cost": 2},
		{"key": "d1-t3", "potion_cost": 3}
	]
	var bulk_result = progression.try_complete_tasks(district_tasks, wallet)
	failures += _check(bulk_result.success and bulk_result.completed == 2 and bulk_result.spent == 5, "complete a district batch all at once")
	var chest_reward = preload("res://scripts/core/reward_bundle.gd").new(20, 5)
	failures += _check(progression.try_claim_chest("d1", chest_reward, district_tasks, wallet), "claim chest after district tasks are complete")
	failures += _check(not progression.try_claim_chest("d1", chest_reward, district_tasks, wallet), "district chest cannot be claimed twice")


	print("TEST STAGE 9: save codec migration and backup persistence")
	var save_clock = Clock.new(1700000000)
	var fresh_save = Codec.new_save(save_clock)
	failures += _check(fresh_save.version == Save.CURRENT_VERSION and fresh_save.boosters.size() == Bag.SLOTS, "new save uses current version and starter booster slots")
	var fresh_bag = Bag.new(fresh_save)
	failures += _check(fresh_bag.count(GameTypes.BoosterKind.MALLET) == Bag.START_OWNED, "new save grants one of each booster")
	fresh_save.coins = 1234
	fresh_save.potions = 56
	fresh_save.level_number = 7
	var level_record = fresh_save.get_or_create_level(3)
	level_record.plays = 4
	level_record.cleared = true
	level_record.best_moves_left = 9
	level_record.last_replay_hash = "c0d2f1a263e84ebf"
	var encoded_save := Codec.encode(fresh_save)
	var decoded_save = Codec.decode(encoded_save, save_clock)
	failures += _check(decoded_save.errors.is_empty(), "save JSON round-trip has no errors")
	failures += _check(decoded_save.data.coins == 1234 and decoded_save.data.potions == 56 and decoded_save.data.level_number == 7, "save JSON round-trip preserves balances and level")
	failures += _check(decoded_save.data.find_level(3).get("last_replay_hash", "") == "c0d2f1a263e84ebf", "save JSON round-trip preserves level records")
	var migrated = Codec.decode("{\"version\":1,\"coins\":40,\"potions\":90}", save_clock)
	failures += _check(migrated.data.version == Save.CURRENT_VERSION and migrated.data.boosters.size() == Bag.SLOTS, "v1 save migrates to v2 with starter boosters")
	var corrupt = Codec.decode("{ broken", save_clock)
	failures += _check(corrupt.data != null and not corrupt.errors.is_empty(), "corrupt save returns a fresh playable save")

	var test_directory := "user://godot-save-tests"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_directory))
	var store = Store.new(save_clock, test_directory)
	var stored_save = Codec.new_save(save_clock)
	stored_save.potions = 10
	failures += _check(store.save(stored_save), "write first save file")
	stored_save.potions = 20
	failures += _check(store.save(stored_save), "write second save and retain backup")
	var loaded_store = store.load_save()
	failures += _check(loaded_store.data.potions == 20, "load current save from disk")
	var broken_file = FileAccess.open(store.location, FileAccess.WRITE)
	broken_file.store_string("broken json")
	broken_file.close()
	var recovered_store = store.load_save()
	failures += _check(recovered_store.data.potions == 10 and recovered_store.errors.has("recovered from backup save"), "recover last known good backup after corruption")
	for path in [store.location, store.location + ".bak", store.location + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_directory))

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
