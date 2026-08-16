extends Node
## Offline daily rewards with clock rollback detection.
## Server authority is intentionally not claimed.

signal reward_claimed(amount: int, special: bool)
const REWARDS := [100, 150, 200, 250, 300, 400, 600]
const DAY_SECONDS := 86400


func status() -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var daily: Dictionary = SaveManager.data.daily
	if now + 300 < int(daily.last_seen_epoch):
		return {"available": false, "reason": "Device clock moved backwards", "day": int(daily.day)}
	daily.last_seen_epoch = maxi(now, int(daily.last_seen_epoch))
	var elapsed := now - int(daily.last_claim_epoch)
	return {
		"available": int(daily.last_claim_epoch) == 0 or elapsed >= DAY_SECONDS,
		"reason": "",
		"day": int(daily.day),
		"seconds_remaining": maxi(0, DAY_SECONDS - elapsed)
	}


func claim() -> int:
	var state := status()
	if not state.available:
		return 0
	var day := int(SaveManager.data.daily.day)
	var amount: int = REWARDS[day]
	SaveManager.data.daily.day = (day + 1) % 7
	SaveManager.data.daily.last_claim_epoch = int(Time.get_unix_time_from_system())
	SaveManager.add_coins(amount)
	AnalyticsManager.track(&"daily_reward_claimed", {"amount": amount})
	reward_claimed.emit(amount, day == 6)
	return amount
