class_name GuildCustomerFlow
extends Node3D
## The queue: customers arrive through the door, wait their turn, order at the
## counter, and leave once the guild master serves them.
##
## Nothing here is a timer pretending to be a person. A customer is a node that
## walks the real navigation mesh; the order on the counter belongs to the customer
## standing at the front of the line; when that order is paid the same node walks
## back out. `tick(delta)` drives everything, so the play-through can advance a
## minute in one call and a suite can do the same without a physics frame.

signal customer_arrived(customer: GuildCustomer)
signal customer_left(customer: GuildCustomer)
signal order_placed(order: GuildOrder)

const CLASSES: Array[String] = ["warrior", "mage", "archer", "rogue", "knight"]
const PATIENCE := 60.0
const TICK_STEP := 0.05

var hall: GuildHall
var counter: GuildStation
var customers: Array[GuildCustomer] = []
var spawned := 0
var served := 0
var abandoned := 0
var language := "en"

var _rng := RandomNumberGenerator.new()
var _next_class := 0


func setup(hall_node: GuildHall, counter_station: GuildStation, seed_value: int = 7) -> void:
	hall = hall_node
	counter = counter_station
	_rng.seed = seed_value
	customers.clear()
	spawned = 0
	served = 0
	abandoned = 0
	_next_class = 0


## Sends one customer in through the door. Returns null when the line is full, so a
## caller can never quietly overbook the counter.
func spawn(class_id: String = "") -> GuildCustomer:
	if hall == null or counter == null:
		return null
	if customers.size() >= GuildHallZones.queue_length():
		return null
	var chosen := class_id
	if chosen.is_empty():
		chosen = CLASSES[_next_class % CLASSES.size()]
	_next_class += 1
	var customer := GuildCustomer.new(chosen)
	customer.name = "Customer_%s_%d" % [chosen, spawned]
	customer.position = GuildHallZones.spawn("door")
	customer.rotation.y = PI
	customer.set_language(language)
	customer.state = "walking"
	add_child(customer)
	customers.append(customer)
	customer.slot = customers.size() - 1
	customer.plan_route(GuildHallZones.queue_slot(customer.slot), _map())
	spawned += 1
	customer_arrived.emit(customer)
	return customer


func set_language(new_language: String) -> void:
	language = "fa" if new_language == "fa" else "en"
	for customer in customers:
		customer.set_language(language)


## One simulation step: walk everybody, hand out the front place, fulfil or expire.
func tick(delta: float) -> void:
	for customer in customers.duplicate():
		if not is_instance_valid(customer):
			continue
		if customer.walk(delta):
			_reach_slot(customer)
		_watch(customer, delta)


## Runs `seconds` of simulation in fixed steps, which is how a capture and a suite
## advance the hall by whole minutes.
func advance(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(TICK_STEP, left)
		tick(step)
		left -= step


func waiting_count() -> int:
	var waiting := 0
	for customer in customers:
		if customer.state == "ordering":
			waiting += 1
	return waiting


func queue_length() -> int:
	return customers.size()


func report() -> String:
	var order_text := "none"
	if counter != null and counter.order != null:
		order_text = "%s x%d" % [counter.order.item_id, counter.order.amount]
	return "flow spawned=%d served=%d waiting=%d abandoned=%d order=%s" % [
		spawned,
		served,
		waiting_count(),
		abandoned,
		order_text,
	]


# --- internals -------------------------------------------------------------

## A customer that reached the end of its route takes its place in the line, and
## the one at the front places the order.
func _reach_slot(customer: GuildCustomer) -> void:
	if customer.state == "leaving":
		_leave(customer)
		return
	if customer.slot == 0:
		customer.state = "ordering"
		customer.waited = 0.0
		_place_order(customer)
	else:
		customer.state = "queued"


## The front of the line asks for something the guild can actually have in stock.
func _place_order(customer: GuildCustomer) -> void:
	if counter == null:
		return
	if counter.order != null and counter.order.is_ready():
		customer.order = counter.order
		return
	var item_id := GuildItems.ids()[_rng.randi_range(0, GuildItems.ids().size() - 1)]
	var amount := _rng.randi_range(1, 3)
	var order := GuildOrder.new(item_id, amount)
	customer.order = order
	counter.bind_order(order)
	order_placed.emit(order)


## A paid order ends the visit; an ignored one ends it too, which is what keeps a
## queue from standing there forever pretending to be gameplay.
func _watch(customer: GuildCustomer, delta: float) -> void:
	if customer.state == "leaving":
		return
	if customer.state == "ordering":
		customer.waited += delta
		if customer.order != null and customer.order.fulfilled:
			_begin_leaving(customer, true)
			return
		if customer.waited > PATIENCE:
			_begin_leaving(customer, false)
		return
	if customer.state == "queued" and customer.order != null and customer.order.fulfilled:
		_begin_leaving(customer, true)


func _begin_leaving(customer: GuildCustomer, happy: bool) -> void:
	customer.state = "leaving"
	customer.slot = -1
	if happy:
		served += 1
	else:
		abandoned += 1
	if counter != null and counter.order != null and counter.order.fulfilled:
		counter.bind_order(null)
	customer.plan_route(GuildHallZones.spawn("door"), _map())
	_advance_line()


## Everyone behind the front of the line steps up one place.
func _advance_line() -> void:
	var place := 0
	for customer in customers:
		if customer.state == "leaving":
			continue
		if customer.slot != place:
			customer.slot = place
			customer.plan_route(GuildHallZones.queue_slot(place), _map())
			customer.state = "walking"
		place += 1


## The customer walked out of the door: the node has done its job.
func _leave(customer: GuildCustomer) -> void:
	customers.erase(customer)
	customer_left.emit(customer)
	customer.queue_free()


func _map() -> RID:
	if hall != null and hall.is_inside_tree():
		return hall.get_world_3d().navigation_map
	return RID()
