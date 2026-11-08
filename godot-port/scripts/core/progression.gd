class_name Progression
extends RefCounted

var _data: SaveData
var _clock: RefCounted

func _init(data: SaveData, clock: RefCounted) -> void:
	_data = data
	_clock = clock
	if _data.level_number < 1:
		_data.level_number = 1

var highest_unlocked_level: int:
	get:
		return _data.level_number

func is_unlocked(level_number: int) -> bool:
	return level_number >= 1 and level_number <= _data.level_number

func record_level_result(run: LevelRun, wallet: Wallet) -> Dictionary:
	var reward := RewardBundle.none()
	if run == null or run.level == null:
		return {"first_clear": false, "reward": reward}
	var record := _data.get_or_create_level(run.level.number)
	record.plays = int(record.get("plays", 0)) + 1
	record.last_replay_hash = run.state_hash_hex()
	if run.score > int(record.get("best_score", 0)):
		record.best_score = run.score
	if run.status != GameTypes.LevelStatus.WON:
		_data.updated_at_unix = _clock.now_unix()
		return {"first_clear": false, "reward": reward}
	if run.moves_left > int(record.get("best_moves_left", 0)):
		record.best_moves_left = run.moves_left
	var first_clear := not bool(record.get("cleared", false))
	if first_clear:
		record.cleared = true
		record.first_cleared_at_unix = _clock.now_unix()
		reward = RewardBundle.new(run.level.reward_coins, run.level.reward_potions)
		if wallet != null:
			wallet.grant_bundle(reward)
		if run.level.number >= _data.level_number:
			_data.level_number = run.level.number + 1
	_data.updated_at_unix = _clock.now_unix()
	return {"first_clear": first_clear, "reward": reward}

func is_task_complete(key: String) -> bool:
	return _data.is_task_complete(key)

func try_complete_task(key: String, potion_cost: int, wallet: Wallet) -> bool:
	if key.is_empty() or _data.is_task_complete(key) or wallet == null:
		return false
	if not wallet.try_spend_potions(potion_cost):
		return false
	_data.completed_tasks.append(key)
	_data.updated_at_unix = _clock.now_unix()
	return true

func try_complete_tasks(tasks: Array[Dictionary], wallet: Wallet) -> Dictionary:
	if wallet == null:
		return {"success": false, "completed": 0, "spent": 0}
	var total := 0
	for task in tasks:
		var key := str(task.get("key", ""))
		if key.is_empty() or _data.is_task_complete(key):
			continue
		total += int(task.get("potion_cost", 0))
	if total <= 0 or not wallet.try_spend_potions(total):
		return {"success": false, "completed": 0, "spent": 0}
	var completed := 0
	for task in tasks:
		var key := str(task.get("key", ""))
		if key.is_empty() or _data.is_task_complete(key):
			continue
		_data.completed_tasks.append(key)
		completed += 1
	_data.updated_at_unix = _clock.now_unix()
	return {"success": completed > 0, "completed": completed, "spent": total}

func is_chest_claimed(district_id: String) -> bool:
	return _data.is_chest_claimed(district_id)

func try_claim_chest(district_id: String, reward: RewardBundle, tasks: Array[Dictionary], wallet: Wallet) -> bool:
	if district_id.is_empty() or _data.is_chest_claimed(district_id):
		return false
	if not is_district_complete(tasks) or reward == null or reward.is_empty or wallet == null:
		return false
	_data.claimed_chests.append(district_id)
	wallet.grant_bundle(reward)
	_data.updated_at_unix = _clock.now_unix()
	return true

func is_district_complete(tasks: Array[Dictionary]) -> bool:
	if tasks.is_empty():
		return false
	for task in tasks:
		var key := str(task.get("key", ""))
		if not key.is_empty() and not _data.is_task_complete(key):
			return false
	return true
