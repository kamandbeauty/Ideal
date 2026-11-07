class_name Lives
extends RefCounted

const REFILL_SECONDS := 30 * 60
const DEFAULT_MAX := 5

var _data: SaveData
var _clock: RefCounted

func _init(data: SaveData, clock: RefCounted) -> void:
	_data = data
	_clock = clock
	if _data.max_lives < 1:
		_data.max_lives = DEFAULT_MAX
	_data.lives = clampi(_data.lives, 0, _data.max_lives)

var max_lives: int:
	get:
		return _data.max_lives

var current: int:
	get:
		refresh()
		return _data.lives

var is_full: bool:
	get:
		return current >= max_lives

var next_refill_in_seconds: int:
	get:
		refresh()
		if _data.lives >= _data.max_lives:
			return 0
		var elapsed := _clock.now_unix() - _data.lives_updated_at_unix
		var remaining := REFILL_SECONDS - posmod(elapsed, REFILL_SECONDS)
		if remaining <= 0:
			remaining = REFILL_SECONDS
		return remaining

func refresh() -> int:
	if _data.lives >= _data.max_lives:
		_data.lives_updated_at_unix = _clock.now_unix()
		return 0
	var elapsed := _clock.now_unix() - _data.lives_updated_at_unix
	if elapsed <= 0:
		return 0
	var gained := int(elapsed / REFILL_SECONDS)
	if gained <= 0:
		return 0
	var before := _data.lives
	var restored := mini(gained, _data.max_lives - _data.lives)
	_data.lives += restored
	_data.lives_updated_at_unix += restored * REFILL_SECONDS
	if _data.lives >= _data.max_lives:
		_data.lives_updated_at_unix = _clock.now_unix()
	return _data.lives - before

func try_spend() -> bool:
	refresh()
	if _data.lives <= 0:
		return false
	if _data.lives == _data.max_lives:
		_data.lives_updated_at_unix = _clock.now_unix()
	_data.lives -= 1
	return true

func grant(amount: int) -> void:
	if amount <= 0:
		return
	_data.lives = mini(_data.max_lives, _data.lives + amount)

func buy_refill(amount: int, pay_coins: bool, wallet: Wallet, coin_price: int) -> bool:
	if amount <= 0:
		return false
	if pay_coins and wallet != null and coin_price > 0:
		if not wallet.try_spend_coins(coin_price):
			return false
	grant(amount)
	return true
