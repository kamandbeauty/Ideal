class_name RewardBundle
extends RefCounted

var coins: int = 0
var potions: int = 0

func _init(coins_amount: int = 0, potions_amount: int = 0) -> void:
	coins = coins_amount
	potions = potions_amount

var is_empty: bool:
	get:
		return coins == 0 and potions == 0

static func none() -> RewardBundle:
	return RewardBundle.new()
