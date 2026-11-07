class_name Wallet
extends RefCounted

const MAX_BALANCE := 999999999

var _data: SaveData

func _init(data: SaveData) -> void:
	_data = data

var coins: int:
	get:
		return _data.coins

var potions: int:
	get:
		return _data.potions

func can_afford_potions(amount: int) -> bool:
	return amount >= 0 and _data.potions >= amount

func can_afford_coins(amount: int) -> bool:
	return amount >= 0 and _data.coins >= amount

func try_spend_potions(amount: int) -> bool:
	if amount < 0 or _data.potions < amount:
		return false
	_data.potions -= amount
	return true

func try_spend_coins(amount: int) -> bool:
	if amount < 0 or _data.coins < amount:
		return false
	_data.coins -= amount
	return true

func grant(coins_amount: int, potions_amount: int) -> void:
	if coins_amount > 0:
		_data.coins = _clamp_balance(_data.coins, coins_amount)
	if potions_amount > 0:
		_data.potions = _clamp_balance(_data.potions, potions_amount)

func grant_bundle(reward: RewardBundle) -> void:
	if reward != null:
		grant(reward.coins, reward.potions)

func _clamp_balance(balance: int, delta: int) -> int:
	if delta >= MAX_BALANCE - balance:
		return MAX_BALANCE
	return balance + delta
