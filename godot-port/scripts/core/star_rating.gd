class_name StarRating
extends RefCounted

const MAX_STARS := 3
const MIN_STARS := 1
const SECOND_AT_PERCENT := 25
const THIRD_AT_PERCENT := 50

static func from_run(run) -> int:
	if run == null or run.level == null or run.status != GameTypes.LevelStatus.WON:
		return 0
	return from_moves(run.level.move_limit, run.moves_left)

static func from_moves(move_limit: int, moves_left: int) -> int:
	moves_left = maxi(0, moves_left)
	if move_limit <= 0:
		return MIN_STARS
	var second := maxi(1, int((move_limit * SECOND_AT_PERCENT + 99) / 100))
	var third := maxi(second, int((move_limit * THIRD_AT_PERCENT + 99) / 100))
	var stars := MIN_STARS
	if moves_left >= second:
		stars += 1
	if moves_left >= third:
		stars += 1
	return stars

static func from_record(record: Dictionary, move_limit: int) -> int:
	if record.is_empty() or not bool(record.get("cleared", false)):
		return 0
	return from_moves(move_limit, int(record.get("best_moves_left", 0)))

static func describe(stars: int) -> String:
	var value := clampi(stars, 0, MAX_STARS)
	var persian_digits := "۰۱۲۳۴۵۶۷۸۹"
	var digit := persian_digits.substr(value, 1)
	return digit + " ستاره"
