class_name ServiceQueue
extends RefCounted
## The capacity rule behind the visible customer flow: only as many customers
## are served at once as the business has service slots, the rest wait in line,
## and a line that grows past its limit turns travellers away.
##
## The economy stays statistical; this only decides who gets a parking spot and
## when a payment happens on screen.

var capacity := 1
var limit := 3
var _entries: Array[Dictionary] = []


func configure(slots: int, max_total: int) -> void:
	capacity = maxi(1, slots)
	limit = maxi(capacity, max_total)
	while _entries.size() > limit:
		_entries.pop_back()


## Returns "served" when a slot is free, "queued" when there is still room in
## the line and "rejected" when the traveller gives up and drives on.
func request(id: int, duration: float) -> String:
	if _entries.size() >= limit:
		return "rejected"
	var span := maxf(0.2, duration)
	_entries.append({"id": id, "remaining": span, "total": span})
	return "served" if _entries.size() - 1 < capacity else "queued"


## Advances every customer that currently holds a service slot and returns the
## ids that just paid and left.
func tick(delta: float) -> Array[int]:
	# Only the customers who already held a slot this frame are advanced: anyone
	# promoted by a completed service starts their timer on the next tick.
	var done: Array[int] = []
	var serving := mini(capacity, _entries.size())
	for i in range(serving - 1, -1, -1):
		var entry: Dictionary = _entries[i]
		if not bool(entry.get("arrived", true)):
			continue
		entry["remaining"] = float(entry["remaining"]) - maxf(0.0, delta)
		if float(entry["remaining"]) <= 0.0:
			done.append(int(entry["id"]))
			_entries.remove_at(i)
	return done


func index_of(id: int) -> int:
	for i in _entries.size():
		if int(_entries[i]["id"]) == id:
			return i
	return -1


func is_serving(id: int) -> bool:
	var index := index_of(id)
	return index >= 0 and index < capacity


func progress_of(id: int) -> float:
	var index := index_of(id)
	if index < 0:
		return 0.0
	var entry: Dictionary = _entries[index]
	return clampf(1.0 - float(entry["remaining"]) / float(entry["total"]), 0.0, 1.0)


func size() -> int:
	return _entries.size()


func serving_count() -> int:
	return mini(capacity, _entries.size())


func waiting_count() -> int:
	return maxi(0, _entries.size() - capacity)


func clear() -> void:
	_entries.clear()
