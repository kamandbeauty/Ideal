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
const ContentLoader = preload("res://scripts/core/level_content_loader.gd")
const Catalog = preload("res://scripts/core/asset_catalog.gd")
const DistrictLoader = preload("res://scripts/core/district_content_loader.gd")

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


	var rng_42 = Rng.new(0, 42)
	var golden_high := [0x56ce4ab7, 0xc841eb53, 0xca466be0, 0xf1acc733, 0xc3af4dd7, 0xd5f30c22]
	var golden_low := [0x719ba3a0, 0xebbb2dda, 0xc9980276, 0x4a7b70df, 0xfb900a06, 0x06dfcea3]
	for index in range(6):
		var draw: Array[int] = rng_42.next_words()
		failures += _check(draw[0] == golden_high[index] and draw[1] == golden_low[index], "C# seed-42 RNG golden draw %d" % index)
	failures += _check(rng_42.state_hex() == "c0d2f1a263e84ebf", "C# seed-42 RNG state after six draws")
	var zero_seed_a = Rng.new(0, 0)
	var zero_seed_b = Rng.new(Rng.FALLBACK_HIGH, Rng.FALLBACK_LOW)
	failures += _check(zero_seed_a.next(97) == zero_seed_b.next(97), "zero seed uses the documented fallback state")

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


	var hash_board = Board.from_ascii(PackedStringArray(["F..", "..."]))
	failures += _check(StateHash.compute_board(hash_board) == "556036242e410b66", "C# FNV board-hash golden vector")
	var hash_level = Level.new()
	hash_level.width = 9
	hash_level.height = 9
	hash_level.move_limit = 20
	var hash_pieces: Array[int] = [1, 2, 3, 4, 5]
	hash_level.pieces = hash_pieces
	var hash_goals: Array[Dictionary] = [{"kind": 0, "piece": 3, "target": 20}]
	hash_level.goals = hash_goals
	var hash_run = Run.new(hash_level, 0, 42)
	failures += _check(hash_run.state_hash_hex() == "396f06d4828178f0", "C# LevelRun FNV state-hash golden vector for seed 42")

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

	print("TEST STAGE 8B: opening-board seed corpus")
	for seed in range(1, 21):
		var seed_run = Run.new(hash_level, 0, seed)
		failures += _check(not Finder.has_match(seed_run.board), "seed %d opens without an automatic match" % seed)
		failures += _check(Finder.has_possible_move(seed_run.board), "seed %d has at least one legal move" % seed)
		failures += _check(seed_run.board.count_pieces() == 81, "seed %d fills all 81 cells" % seed)
		failures += _check(seed_run.moves_left == 20 and seed_run.status == GameTypes.LevelStatus.PLAYING, "seed %d starts with the configured move budget" % seed)


	var move_accounting_run = Run.new(hash_level, 0, 2026)
	var legal_swap := _find_legal_swap(move_accounting_run.board)
	failures += _check(legal_swap.size() == 4, "find a legal opening swap in the deterministic board")
	if legal_swap.size() == 4:
		var accepted_run_move = move_accounting_run.try_swap(legal_swap[0], legal_swap[1], legal_swap[2], legal_swap[3])
		failures += _check(accepted_run_move.accepted and move_accounting_run.moves_left == 19 and move_accounting_run.moves_used == 1, "accepted LevelRun swap consumes exactly one move")
		var rejected_run_move = move_accounting_run.try_swap(0, 0, 0, 0)
		failures += _check(not rejected_run_move.accepted and move_accounting_run.moves_left == 19 and move_accounting_run.moves_used == 1, "rejected LevelRun swap consumes no move")
		var moves_before_booster: int = move_accounting_run.moves_left
		var run_booster = move_accounting_run.use_booster(GameTypes.BoosterKind.MALLET, 4, 4)
		failures += _check(run_booster.accepted and move_accounting_run.moves_left == moves_before_booster and move_accounting_run.boosters_used.size() == 1, "LevelRun booster does not consume a move")

	var run_a = Run.new(progression_level, 0, 12345)
	var run_b = Run.new(progression_level, 0, 12345)
	failures += _check(run_a.state_hash_hex() == run_b.state_hash_hex(), "same seed produces same initial replay hash")
	failures += _check(Stars.from_moves(20, 4) == 1 and Stars.from_moves(20, 5) == 2 and Stars.from_moves(20, 10) == 3, "star thresholds use exact integer percentages")
	run_a.status = GameTypes.LevelStatus.WON
	run_a.moves_left = 10
	var progression = ProgressionScript.new(save_data, clock)
	var first_result = progression.record_level_result(run_a, wallet)
	failures += _check(first_result.first_clear and wallet.coins == WalletScript.MAX_BALANCE - 110 and wallet.potions == 23, "first clear grants reward and records progression")
	var repeat_result = progression.record_level_result(run_a, wallet)
	failures += _check(not repeat_result.first_clear and wallet.potions == 23, "replay does not pay first-clear reward twice")
	failures += _check(progression.highest_unlocked_level == 2 and Stars.from_run(run_a) == 3, "first clear unlocks next level and computes stars")
	var no_effect_run = Run.new(progression_level, 0, 77)
	no_effect_run.board.at(0, 0).blocked = true
	var no_effect_booster = no_effect_run.use_booster(GameTypes.BoosterKind.MALLET, 0, 0)
	failures += _check(no_effect_booster.accepted, "blocked-target booster request is accepted by the resolver")
	failures += _check(no_effect_run.boosters_used.size() == 1, "accepted booster is recorded before refund")
	no_effect_run.revert_last_booster(GameTypes.BoosterKind.MALLET)
	failures += _check(no_effect_run.boosters_used.is_empty(), "no-effect booster refund removes it from replay history")
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


	print("TEST STAGE 10: imported chapter content and art")
	var loaded_level = ContentLoader.load_level(1)
	failures += _check(loaded_level.level != null and loaded_level.errors.is_empty(), "load first shipped chapter level")
	failures += _check(loaded_level.level.id == "ch01-001" and loaded_level.level.width == 9 and loaded_level.level.pieces.size() == 5, "map level metadata and piece names")
	var chapter = ContentLoader.load_chapter("ch01", 10)
	failures += _check(chapter.levels.size() == 10 and chapter.errors.is_empty(), "load all ten chapter-one levels")

	failures += _check(LevelValidator.validate(loaded_level.level).is_empty(), "first level passes full content validation")
	failures += _check(LevelValidator.validate_catalog(chapter.levels).is_empty(), "chapter level catalog has unique ids and sequential numbers")
	var district_content = DistrictLoader.load_chapter("ch01")
	failures += _check(district_content.errors.is_empty() and district_content.districts.size() == 3, "load and validate all chapter-one districts")
	var district_task_count := 0
	for district in district_content.districts:
		district_task_count += district.tasks.size()
	failures += _check(district_task_count == 12, "map all twelve district build tasks")
	failures += _check(district_content.districts[0].title == "میدانِ فیروزه", "preserve Persian district title")

	failures += _check(Catalog.piece_texture(GameTypes.PieceKind.FIROUZEH) != null, "original piece art is available to Godot")
	failures += _check(Catalog.power_up_texture(GameTypes.PowerUpKind.ROCKET_VERTICAL) != null, "original power-up art is available to Godot")
	failures += _check(Catalog.obstacle_texture(GameTypes.ObstacleKind.CRATE) != null, "original obstacle art is available to Godot")

	var gameplay_scene = ResourceLoader.load("res://scenes/gameplay_screen.tscn")
	failures += _check(gameplay_scene is PackedScene, "load native gameplay screen scene")

	print("TEST STAGE 11: gameplay scene runtime smoke test")
	var smoke_directory := "user://godot-screen-smoke"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(smoke_directory))
	var screen_scene = ResourceLoader.load("res://scenes/gameplay_screen.tscn")
	var screen = screen_scene.instantiate()
	screen.set_meta("save_directory", smoke_directory)
	root.add_child(screen)
	await process_frame
	failures += _check(screen.debug_cell_count() == 81, "gameplay screen builds a 9x9 interactive board")
	failures += _check(screen.debug_run_status() == GameTypes.LevelStatus.PLAYING, "gameplay screen starts level one in playing state")
	screen.queue_free()
	await process_frame
	for file_name in ["shazdeh-save.json", "shazdeh-save.json.bak", "shazdeh-save.json.tmp"]:
		var cleanup_path := smoke_directory.path_join(file_name)
		if FileAccess.file_exists(cleanup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(smoke_directory))


	print("TEST STAGE 12: real chapter levels under repeated legal moves")
	for content_level in chapter.levels:
		for seed in range(1, 6):
			var content_run = Run.new(content_level, 0, seed)
			failures += _check(not Finder.has_match(content_run.board), "%s seed %d opens settled" % [content_level.id, seed])
			failures += _check(Finder.has_possible_move(content_run.board), "%s seed %d opens playable" % [content_level.id, seed])
			for move_index in range(10):
				if content_run.status != GameTypes.LevelStatus.PLAYING:
					break
				var candidate := _find_legal_swap(content_run.board)
				if candidate.size() != 4:
					break
				var move_result = content_run.try_swap(candidate[0], candidate[1], candidate[2], candidate[3])
				failures += _check(move_result.accepted and move_result.pieces_cleared > 0, "%s seed %d move %d resolves" % [content_level.id, seed, move_index])
				failures += _check(not Finder.has_match(content_run.board), "%s seed %d move %d leaves no match" % [content_level.id, seed, move_index])
				failures += _check(_is_board_full(content_run.board), "%s seed %d move %d leaves no empty cells" % [content_level.id, seed, move_index])


	print("TEST STAGE 13: matcher shapes, clusters and spawn rules")
	var vertical_board = Board.from_ascii(PackedStringArray(["F", "F", "F"]))
	failures += _check(Finder.find_runs(vertical_board).size() == 1 and not Finder.find_runs(vertical_board)[0].horizontal, "detect a vertical run")
	var long_run = Finder.find_runs(Board.from_ascii(PackedStringArray(["FFFFF"])))
	failures += _check(long_run.size() == 1 and long_run[0].length == 5, "five pieces form one maximal run")
	var stale_board = Board.from_ascii(PackedStringArray(["FLA", "LAF", "AFM"]))
	failures += _check(not Finder.has_possible_move(stale_board), "detect a stale board with no legal swap")
	var cross_runs: Array[Dictionary] = [
		{"start": Vector2i(0, 1), "length": 3, "horizontal": true, "piece": GameTypes.PieceKind.AQIQ},
		{"start": Vector2i(1, 0), "length": 3, "horizontal": false, "piece": GameTypes.PieceKind.AQIQ}
	]
	var cross_clusters = Finder.build_clusters(cross_runs)
	failures += _check(cross_clusters.size() == 1 and cross_clusters[0].cells.size() == 5, "merge crossing runs into one five-cell cluster")
	failures += _check(Finder.power_up_for(cross_clusters[0]) == GameTypes.PowerUpKind.DYNAMITE, "crossing cluster earns dynamite")
	var four_runs: Array[Dictionary] = [{"start": Vector2i(0, 0), "length": 4, "horizontal": true, "piece": 3}]
	var four_cluster = Finder.build_clusters(four_runs)[0]
	failures += _check(Finder.power_up_for(four_cluster) == GameTypes.PowerUpKind.ROCKET_VERTICAL, "horizontal four earns vertical rocket")
	failures += _check(Finder.choose_spawn_cell(four_cluster, Vector2i(3, 0), true) == Vector2i(3, 0), "power-up spawn prefers the player destination")
	var five_runs: Array[Dictionary] = [{"start": Vector2i(0, 0), "length": 5, "horizontal": true, "piece": 4}]
	failures += _check(Finder.power_up_for(Finder.build_clusters(five_runs)[0]) == GameTypes.PowerUpKind.ELECTRO_BALL, "five in a line earns electro ball")

	print("TEST STAGE 14: edge-clipped power-up targets and obstacle layers")
	var edge_targets: Array[Vector2i] = []
	Powers.add_square(power_board, Vector2i(0, 0), 1, edge_targets)
	failures += _check(edge_targets.size() == 4, "dynamite blast clips correctly at board corner")
	var obstacle_board = Board.from_ascii(PackedStringArray(["AZMFL", "ZMFLA", "MFLAZ", "FLAZM", "LAZMF"]))
	obstacle_board.at(1, 1).set_obstacle(GameTypes.ObstacleKind.FROST, 2)
	var obstacle_level = Level.new()
	obstacle_level.width = 5
	obstacle_level.height = 5
	obstacle_level.pieces = move_pieces
	var obstacle_goals: Array[Dictionary] = [{"kind": GameTypes.GoalKind.CLEAR_OBSTACLE, "obstacle": GameTypes.ObstacleKind.FROST, "target": 2}]
	obstacle_level.goals = obstacle_goals
	var obstacle_tracker = Goals.new(obstacle_level.goals)
	var obstacle_resolver = Resolver.new(obstacle_level, obstacle_board, Rng.new(0, 5), obstacle_tracker)
	var first_frost_hit = obstacle_resolver.use_booster(GameTypes.BoosterKind.MALLET, Vector2i(1, 1))
	failures += _check(first_frost_hit.accepted and obstacle_board.at(1, 1).obstacle_layers == 1, "first mallet hit removes one frost layer")
	var second_frost_hit = obstacle_resolver.use_booster(GameTypes.BoosterKind.MALLET, Vector2i(1, 1))
	failures += _check(second_frost_hit.accepted and not obstacle_board.at(1, 1).has_obstacle, "second mallet hit destroys two-layer frost")
	failures += _check(obstacle_tracker.progress(0) == 2, "each obstacle layer advances the goal")

	var whirlwind_board = Board.from_ascii(PackedStringArray(["AZMFL", "ZMFLA", "MFLAZ", "FLAZM", "LAZMF"]))
	var whirlwind_resolver = Resolver.new(obstacle_level, whirlwind_board, Rng.new(0, 3), Goals.new(obstacle_level.goals))
	var whirlwind_result = whirlwind_resolver.use_booster(GameTypes.BoosterKind.WHIRLWIND, Vector2i(2, 2))
	failures += _check(whirlwind_result.accepted and whirlwind_result.pieces_cleared == 0, "whirlwind reshuffles without clearing pieces")
	failures += _check(not Finder.has_match(whirlwind_board) and _is_board_full(whirlwind_board), "whirlwind leaves a full settled board")


	print("TEST STAGE 15: home, district, shop and settings screen smoke tests")
	failures += _check(await _smoke_ui_scene("res://scenes/home_screen.tscn", "user://home-screen-smoke"), "home screen instantiates")
	failures += _check(await _smoke_ui_scene("res://scenes/district_screen.tscn", "user://district-screen-smoke"), "district screen instantiates")
	failures += _check(await _smoke_ui_scene("res://scenes/shop_screen.tscn", "user://shop-screen-smoke"), "shop screen instantiates")
	failures += _check(await _smoke_ui_scene("res://scenes/settings_screen.tscn", "user://settings-screen-smoke"), "settings screen instantiates")

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

func _find_legal_swap(board) -> Array[int]:
	for y in range(board.height):
		for x in range(board.width):
			for direction in [Vector2i.RIGHT, Vector2i.UP]:
				var other: Vector2i = Vector2i(x, y) + direction
				if not board.in_bounds(other.x, other.y):
					continue
				var a = board.at(x, y)
				var b = board.at_pos(other)
				if a == null or b == null or not a.has_piece or not b.has_piece:
					continue
				var piece: int = a.piece
				var power_up: int = a.power_up
				a.piece = b.piece
				a.power_up = b.power_up
				b.piece = piece
				b.power_up = power_up
				var creates_match := Finder.has_match(board) or not Finder.find_squares(board).is_empty()
				piece = a.piece
				power_up = a.power_up
				a.piece = b.piece
				a.power_up = b.power_up
				b.piece = piece
				b.power_up = power_up
				if creates_match:
					return [x, y, other.x, other.y]
	return []

func _is_board_full(board) -> bool:
	for pos in board.all_positions():
		var cell = board.at_pos(pos)
		if not cell.blocked and not cell.has_piece:
			return false
	return true

func _smoke_ui_scene(scene_path: String, save_directory: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_directory))
	var packed = ResourceLoader.load(scene_path)
	if not packed is PackedScene:
		return false
	var screen = packed.instantiate()
	screen.set_meta("save_directory", save_directory)
	root.add_child(screen)
	await process_frame
	var loaded_ok: bool = screen.get_child_count() > 0
	screen.queue_free()
	await process_frame
	for file_name in ["shazdeh-save.json", "shazdeh-save.json.bak", "shazdeh-save.json.tmp"]:
		var cleanup_path := save_directory.path_join(file_name)
		if FileAccess.file_exists(cleanup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_directory))
	return loaded_ok
