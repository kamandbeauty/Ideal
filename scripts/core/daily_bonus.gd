class_name DailyBonus
extends RefCounted
## The daily chest: a comeback hook that pays more the longer the streak runs.
##
## Pure functions only, so the tests can drive every streak length without a
## clock or a save file.

const MAX_STREAK := 7
const BASE_SECONDS := 150.0     ## the chest is worth ~2.5 minutes of income
const STREAK_STEP := 0.35       ## +35 % per consecutive day, capped
const GEM_EVERY := 3            ## every third day also pays a gem


## The streak after opening (or missing) today's chest.
static func next_streak(last_day: int, streak: int, today: int) -> int:
	if today <= last_day:
		return clampi(streak, 0, MAX_STREAK)
	if today == last_day + 1:
		return clampi(streak + 1, 1, MAX_STREAK)
	return 1


static func multiplier(streak: int) -> float:
	var capped := clampi(streak, 1, MAX_STREAK)
	return 1.0 + STREAK_STEP * float(capped - 1)


## Cash for a chest opened on this streak. Never below a floor so a brand-new
## town still feels rewarded.
static func cash(net_per_minute: float, streak: int) -> float:
	var per_minute := maxf(net_per_minute, 40.0)
	return round(per_minute * BASE_SECONDS / 60.0 * multiplier(streak))


static func gems(streak: int) -> int:
	return 1 if clampi(streak, 1, MAX_STREAK) % GEM_EVERY == 0 else 0


## Human label for the chest: the streak and the multiplier it pays.
static func describe(streak: int) -> Dictionary:
	var capped := clampi(maxi(streak, 1), 1, MAX_STREAK)
	return {"streak": capped, "multiplier": multiplier(capped), "gems": gems(capped)}
