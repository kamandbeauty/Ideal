class_name GuildTreasury
extends RefCounted
## The guild's vault: the only place gold is allowed to accumulate.
##
## Coins reach it in two steps on purpose - a customer pays into the player's
## hands, and the player walks that money to the vault. Nothing is credited while
## the coins are still being carried.

signal changed()

var cash := 0.0
var reputation := 0.0


## Takes coins out of the player's hands and into the vault; returns the amount.
func deposit(amount: float) -> float:
	var accepted := maxf(amount, 0.0)
	if accepted <= 0.0:
		return 0.0
	cash += accepted
	changed.emit()
	return accepted


func can_afford(amount: float) -> bool:
	return cash >= amount


func spend(amount: float) -> bool:
	if amount <= 0.0 or cash < amount:
		return false
	cash -= amount
	changed.emit()
	return true


func add_reputation(amount: float) -> void:
	if amount <= 0.0:
		return
	reputation += amount
	changed.emit()


## Reputation is a slow drip off real trade, never a counter of button presses.
static func reputation_for(payment: float) -> float:
	return maxf(payment, 0.0) / 20.0
