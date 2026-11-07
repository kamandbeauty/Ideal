class_name GameSession
extends RefCounted
## The one object the screens talk to, ported from client/Assets/Game/GameSession.cs.
##
## It owns the save, the wallet, the lives clock, progression, the booster bag and the district
## metadata, and it is the only place that knows the rules that span more than one of them:
## when an attempt may start, what a finished attempt pays, and that a rejected booster must not be
## charged. Screens call this; nothing here knows that screens exist.

signal changed

const CHAPTER := "ch01"
const LEVEL_COUNT := 10

var clock: RefCounted
var store: SaveStore
var save: SaveData
var wallet: Wallet
var lives: Lives
var progression: Progression
var boosters: BoosterBag
var districts: Array[Dictionary] = []
var boot_errors: Array[String] = []
var chapter := CHAPTER

## Loads the save and every piece of content once. Anything that went wrong is collected instead of
## thrown, so a broken level file cannot stop the game from booting to a screen that explains it.
static func load_session(save_clock: RefCounted, save_store: SaveStore, chapter_id: String,
		errors: Array[String]) -> GameSession:
	var session := GameSession.new()
	session.clock = save_clock
	session.store = save_store
	session.chapter = chapter_id

	var loaded := save_store.load_save()
	session.save = loaded["data"] as SaveData
	var load_errors: Array = loaded.get("errors", [])
	for message in load_errors:
		errors.append(str(message))

	session.wallet = Wallet.new(session.save)
	session.lives = Lives.new(session.save, save_clock)
	session.progression = Progression.new(session.save, save_clock)
	session.boosters = BoosterBag.new(session.save)

	var meta := DistrictContentLoader.load_chapter(chapter_id)
	var meta_errors: Array = meta.get("errors", [])
	for message in meta_errors:
		errors.append(str(message))
	var district_values: Array = meta.get("districts", [])
	for value in district_values:
		if value is Dictionary:
			session.districts.append(value)

	session.boot_errors = errors
	return session

# ---- counters -----------------------------------------------------------------------------------

var current_level: int:
	get:
		var unlocked := progression.highest_unlocked_level
		if unlocked < 1:
			unlocked = 1
		if unlocked > LEVEL_COUNT:
			unlocked = LEVEL_COUNT
		return unlocked

func is_unlocked(level_number: int) -> bool:
	return progression.is_unlocked(level_number) and level_number >= 1 and level_number <= LEVEL_COUNT

var is_last_level: bool:
	get:
		return current_level >= LEVEL_COUNT

var cleared_count: int:
	get:
		var cleared := 0
		for record in save.levels:
			if record is Dictionary and bool(record.get("cleared", false)):
				cleared += 1
		return cleared

func stars_for(level_number: int) -> int:
	var record := save.find_level(level_number)
	if record.is_empty():
		return 0
	if not bool(record.get("cleared", false)):
		return 0
	var content := LevelContentLoader.load_level(level_number, chapter)
	var level: LevelDefinition = content.get("level", null)
	var limit := level.move_limit if level != null else 20
	return StarRating.from_record(record, limit)

# ---- playing ------------------------------------------------------------------------------------

## Why the play button would be disabled, or "" when the attempt may start.
func blocked_reason(level_number: int) -> String:
	if not is_unlocked(level_number):
		return "مرحله هنوز باز نشده است"
	if lives.current <= 0:
		return "جان ندارید — جان بعدی تا " + PersianText.time(lives.next_refill_in_seconds)
	return ""

## Builds the run for a level. Returns {run, level, error}; run is null when the attempt may not start.
func start_attempt(level_number: int) -> Dictionary:
	var reason := blocked_reason(level_number)
	if not reason.is_empty():
		return {"run": null, "level": null, "error": reason}

	var content := LevelContentLoader.load_level(level_number, chapter)
	var level: LevelDefinition = content.get("level", null)
	var level_errors: Array = content.get("errors", [])
	if level == null or not level_errors.is_empty():
		for message in level_errors:
			push_error("[level] " + str(message))
		return {"run": null, "level": null, "error": "بارگذاری مرحله ناموفق بود"}

	var record := save.find_level(level_number)
	var plays := int(record.get("plays", 0)) if record is Dictionary else 0
	var seed_value := stable_seed(save.player_id, level_number, plays)
	var run := LevelRun.new(level, (seed_value >> 32) & 0xffffffff, seed_value & 0xffffffff)
	return {"run": run, "level": level, "error": ""}

## Same player, same level, same attempt count → same board. FNV-1a over the player id, then the
## level, then the play count; identical to GameSession.StableSeed in C#.
static func stable_seed(player_id: String, level_number: int, plays: int) -> int:
	var hash_value := 1469598103934665603
	for index in range(player_id.length()):
		hash_value ^= player_id.unicode_at(index)
		hash_value = hash_value * 1099511628211
	hash_value ^= (level_number * 2654435761) & 0xffffffff
	hash_value = hash_value * 1099511628211
	hash_value ^= (plays * 40503) & 0xffffffff
	return hash_value

## Writes a finished attempt: a win pays its first-clear reward and unlocks the next level, a loss
## costs one life. Returns {ok, first_clear, reward}.
func finish_attempt(run: LevelRun) -> Dictionary:
	if run == null:
		return {"ok": false, "first_clear": false, "reward": RewardBundle.none()}

	var outcome := {"ok": false, "first_clear": false, "reward": RewardBundle.none()}
	if run.status == GameTypes.LevelStatus.WON:
		var recorded := progression.record_level_result(run, wallet)
		outcome["first_clear"] = bool(recorded.get("first_clear", false))
		outcome["reward"] = recorded.get("reward", RewardBundle.none())
	elif run.status == GameTypes.LevelStatus.LOST:
		lives.try_spend()
		progression.record_level_result(run, wallet)
	else:
		return outcome

	outcome["ok"] = true
	save_now()
	return outcome

# ---- boosters -----------------------------------------------------------------------------------

## Fires a booster on the board, charging for it only if the board accepts the move.
func try_use_booster(run: LevelRun, kind: int, x: int, y: int) -> Dictionary:
	if run == null or run.status != GameTypes.LevelStatus.PLAYING:
		return {"ok": false, "result": null}
	if not boosters.try_consume(kind):
		return {"ok": false, "result": null}

	var result: Dictionary = run.use_booster(kind, x, y)
	if not bool(result.get("accepted", false)):
		boosters.grant(kind, 1)
		return {"ok": false, "result": null}

	# A booster that cleared nothing did nothing; the whirlwind is the exception, since changing the
	# board without clearing is exactly its job.
	if kind != GameTypes.BoosterKind.WHIRLWIND and not cleared_anything(result):
		boosters.grant(kind, 1)
		run.revert_last_booster(kind)
		return {"ok": false, "result": null}

	save_now()
	return {"ok": true, "result": result}

static func cleared_anything(result: Dictionary) -> bool:
	var events: Array = result.get("events", [])
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == "piece_cleared":
			return true
	return false

func buy_booster(kind: int, quantity: int = 1) -> bool:
	if not boosters.buy(kind, wallet, quantity):
		return false
	save_now()
	return true

# ---- the meta layer -----------------------------------------------------------------------------

func remaining_potions(district: Dictionary) -> int:
	var total := 0
	var tasks: Array = district.get("tasks", [])
	for task in tasks:
		var key := str(task.get("key", ""))
		if not key.is_empty() and not progression.is_task_complete(key):
			total += int(task.get("potion_cost", 0))
	return total

func is_district_built(district: Dictionary) -> bool:
	if district.is_empty():
		return false
	return progression.is_district_complete(district.get("tasks", []))

func built_districts() -> int:
	var count := 0
	for district in districts:
		if is_district_built(district):
			count += 1
	return count

func can_afford(district: Dictionary) -> bool:
	return wallet.can_afford_potions(remaining_potions(district))

func build_task(district: Dictionary, task: Dictionary) -> bool:
	if district.is_empty() or task.is_empty():
		return false
	if not progression.try_complete_task(str(task.get("key", "")), int(task.get("potion_cost", 0)), wallet):
		return false
	save_now()
	return true

func build_district(district: Dictionary) -> bool:
	if district.is_empty():
		return false
	if not progression.try_complete_tasks(district.get("tasks", []), wallet).get("success", false):
		return false
	save_now()
	return true

func open_chest(district: Dictionary) -> bool:
	if district.is_empty():
		return false
	var chest: RewardBundle = district.get("chest", RewardBundle.none())
	if not progression.try_claim_chest(str(district.get("id", "")), chest, district.get("tasks", []), wallet):
		return false
	save_now()
	return true

func is_chest_open(district: Dictionary) -> bool:
	return progression.is_chest_claimed(str(district.get("id", "")))

var is_chapter_built: bool:
	get:
		if districts.is_empty():
			return false
		for district in districts:
			if not is_district_built(district):
				return false
		return true

# ---- housekeeping -------------------------------------------------------------------------------

## Materialises any life that came back and writes it. Cheap enough to call every second.
func refresh_lives() -> bool:
	var restored := lives.refresh()
	if restored <= 0:
		return false
	save_now()
	changed.emit()
	return true

func save_now() -> void:
	if store == null or save == null:
		return
	save.updated_at_unix = clock.now_unix()
	store.save(save)

func notify_changed() -> void:
	changed.emit()
