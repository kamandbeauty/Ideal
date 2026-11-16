class_name GuildTrade
extends RefCounted
## The three transactions the carrying loop is made of, as plain functions.
##
## They are deliberately boring and testable: a shelf hands items to the hands, a
## customer takes items from the hands and pays into the hands, and the vault takes
## the coins out of the hands. Every result is a dictionary so the HUD and the
## tests read the same facts, and every failure says why in one word.


## Takes goods off a shelf. `wanted` is what the interact button asked for; the
## shelf and the hands each cap it.
static func pick(state: GuildPlayerState, stock: GuildStock, wanted: int = 3) -> Dictionary:
	if state == null or stock == null:
		return _result(0, "", "no station")
	if stock.is_empty():
		return _result(0, "", "empty shelf")
	if state.is_hands_full():
		return _result(0, "", "hands full")
	var item_id := stock.first_item()
	var taken := stock.take(item_id, mini(wanted, state.space_for_items()))
	taken = state.hold_items(item_id, taken)
	if taken == 0:
		return _result(0, item_id, "nothing taken")
	return _result(taken, item_id, "")


## Hands an order's goods over and takes the payment. The payment is only credited
## when the goods really leave the hands and the pouch has room for the coins.
static func deliver(state: GuildPlayerState, order: GuildOrder) -> Dictionary:
	if state == null or order == null:
		return _money_result(0.0, "no order")
	if not order.is_ready():
		return _money_result(0.0, "already paid")
	if not order.fits(state.held):
		return _money_result(0.0, "not enough goods")
	if state.money_space() < order.payment:
		return _money_result(0.0, "pouch full")
	state.release_items(order.item_id, order.amount)
	var paid := order.settle()
	if paid <= 0.0:
		return _money_result(0.0, "already paid")
	var carried := state.load_money(paid)
	return _money_result(carried, "" if carried > 0.0 else "pouch full")


## Empties the hands into the vault.
static func deposit(state: GuildPlayerState, treasury: GuildTreasury) -> Dictionary:
	if state == null or treasury == null:
		return _money_result(0.0, "no vault")
	if state.money <= 0.0:
		return _money_result(0.0, "no coins")
	var carried := state.unload_money()
	var deposited := treasury.deposit(carried)
	treasury.add_reputation(GuildTreasury.reputation_for(deposited))
	return _money_result(deposited, "")


static func _result(taken: int, item_id: String, reason: String) -> Dictionary:
	return {"taken": taken, "item": item_id, "reason": reason}


static func _money_result(amount: float, reason: String) -> Dictionary:
	return {"amount": amount, "reason": reason}
