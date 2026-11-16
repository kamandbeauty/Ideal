class_name GuildStock
extends RefCounted
## What sits on a shelf or in the warehouse, counted per item.
##
## The stock is the single source of truth: the shelf's visible parcels are drawn
## from these counts, so "the shelf looks full" and "the shelf is full" can never
## disagree.

signal changed()

const DEFAULT_CAPACITY := 40

var capacity := DEFAULT_CAPACITY
var counts: Dictionary = {}


func _init(stock_capacity: int = DEFAULT_CAPACITY) -> void:
	capacity = stock_capacity


func total() -> int:
	var sum := 0
	for id in counts:
		sum += int(counts[id])
	return sum


func count(item_id: String) -> int:
	return int(counts.get(item_id, 0))


func space() -> int:
	return maxi(capacity - total(), 0)


func is_empty() -> bool:
	return total() == 0


## How many of `amount` fit right now.
func fits(amount: int) -> int:
	return clampi(amount, 0, space())


func add(item_id: String, amount: int) -> int:
	if not GuildItems.exists(item_id) or amount <= 0:
		return 0
	var accepted := fits(amount)
	if accepted == 0:
		return 0
	counts[item_id] = count(item_id) + accepted
	changed.emit()
	return accepted


func take(item_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var taken := mini(amount, count(item_id))
	if taken == 0:
		return 0
	counts[item_id] = count(item_id) - taken
	changed.emit()
	return taken


## Which item is on top of the pile, the one a "pick up" button should grab first.
func first_item() -> String:
	for id in GuildItems.ids():
		if count(id) > 0:
			return id
	return ""


## Sale value of everything on the shelf, at today's prices.
func value() -> float:
	var sum := 0.0
	for id in counts:
		sum += float(counts[id]) * GuildItems.sell_price(str(id))
	return sum


func clear() -> void:
	counts.clear()
	changed.emit()


func snapshot() -> Dictionary:
	return counts.duplicate()
