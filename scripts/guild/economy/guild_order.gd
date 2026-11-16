class_name GuildOrder
extends RefCounted
## One customer's order: an item, a count, and what they will pay for it.
##
## The payment is fixed when the order is created, so walking away and coming back
## cannot change the price, and a delivery can never be paid twice.

signal changed()

var item_id := ""
var amount := 0
var payment := 0.0
var fulfilled := false


func _init(wanted_item: String = "slime_gel", wanted_amount: int = 1) -> void:
	item_id = wanted_item if GuildItems.exists(wanted_item) else GuildItems.ids()[0]
	amount = maxi(wanted_amount, 1)
	payment = GuildItems.sell_price(item_id) * float(amount)


func is_ready() -> bool:
	return not fulfilled and amount > 0


## Can `hands` (an item-id → count dictionary) fill this order?
func fits(hands: Dictionary) -> bool:
	return is_ready() and int(hands.get(item_id, 0)) >= amount


func unit_price() -> float:
	return GuildItems.sell_price(item_id)


## Marks the order paid and returns the money owed. Returns 0 if it was already
## delivered, which is what stops double payment.
func settle() -> float:
	if not is_ready():
		return 0.0
	fulfilled = true
	changed.emit()
	return payment


func label_keys() -> Dictionary:
	return {
		"name_key": GuildItems.name_key(item_id),
		"category_key": str(GuildItems.item(item_id).get("category_key", "")),
	}
