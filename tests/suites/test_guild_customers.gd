extends TestCase
## Customers who walk: the route, the queue, the order and the exit.
##
## Nothing here needs a window or a physics frame. The suite builds a hall and a
## counter but no navigation world, so the routes are straight lines (`routed`
## stays false and the suite says so); the real navigation server is exercised by
## the play-through, whose report prints each route. What is proven here is the
## part CI can prove honestly: a customer moves, stops, queues, orders, is served,
## steps out, and gives up if nobody serves them.

var _hall: GuildHall
var _counter: GuildStation
var _flow: GuildCustomerFlow


func _make_flow() -> GuildCustomerFlow:
	_hall = GuildHall.new()
	_hall.build()
	_counter = GuildStation.new(GuildStation.COUNTER)
	_flow = GuildCustomerFlow.new()
	_flow.setup(_hall, _counter, 11)
	return _flow


func _dispose() -> void:
	if _flow != null:
		for customer in _flow.customers.duplicate():
			customer.free()
		_flow.free()
		_flow = null
	if _counter != null:
		_counter.free()
		_counter = null
	if _hall != null:
		_hall.free()
		_hall = null


func test_a_walk_is_a_route_of_real_waypoints() -> void:
	_make_flow()
	var customer := _flow.spawn("warrior")
	check(customer != null, "a customer can walk in")
	check(not customer.route.is_empty(), "with a route planned")
	check(not customer.routed, "and the suite admits the route is a straight line here")
	var start := customer.position
	_flow.advance(2.0)
	check(customer.position.distance_to(start) > 1.5, "after two seconds they have moved")
	almost(customer.travelled, start.distance_to(customer.position), "and travel is measured", 0.05)
	_dispose()


func test_a_customer_reaches_its_place_in_the_queue() -> void:
	_make_flow()
	var customer := _flow.spawn("mage")
	_flow.advance(20.0)
	var slot := GuildHallZones.queue_slot(0)
	almost(customer.position.x, slot.x, "they stand at the counter", 0.2)
	almost(customer.position.z, slot.z, "on the customer side of it", 0.2)
	equal(customer.state, "ordering", "and they are ordering")
	equal(_flow.waiting_count(), 1, "the HUD has one customer to serve")
	_dispose()


func test_the_front_of_the_line_places_a_real_order() -> void:
	_make_flow()
	_flow.spawn("archer")
	_flow.advance(20.0)
	var order := _counter.order
	check(order != null, "the counter has an order on it")
	if order == null:
		_dispose()
		return
	check(GuildItems.exists(order.item_id), "for an item that exists")
	check(order.amount >= 1 and order.amount <= 3, "in a believable amount")
	almost(order.payment, GuildItems.sell_price(order.item_id) * float(order.amount), "paid at the shelf price")
	check(order.is_ready(), "and waiting to be delivered")
	_dispose()


func test_a_served_customer_leaves_and_the_line_moves_up() -> void:
	_make_flow()
	var first := _flow.spawn("rogue")
	var second := _flow.spawn("knight")
	_flow.advance(24.0)
	equal(first.slot, 0, "the first customer is at the counter")
	equal(second.slot, 1, "the second waits behind")
	check(_counter.order != null, "an order is waiting")
	_counter.order.settle()
	_flow.advance(30.0)
	equal(_flow.served, 1, "one customer was served")
	equal(_flow.queue_length(), 1, "and walked out of the hall")
	equal(second.slot, 0, "the next one stepped up")
	equal(second.state, "ordering", "and is asking for something now")
	check(_counter.order != null and _counter.order.is_ready(), "with a fresh order on the counter")
	_dispose()


func test_an_ignored_customer_gives_up() -> void:
	_make_flow()
	_flow.spawn("warrior")
	_flow.advance(20.0)
	equal(_flow.waiting_count(), 1, "someone is waiting")
	_flow.advance(GuildCustomerFlow.PATIENCE + 10.0)
	equal(_flow.abandoned, 1, "they give up after their patience runs out")
	equal(_flow.waiting_count(), 0, "and the counter is free again")
	_flow.advance(30.0)
	equal(_flow.queue_length(), 0, "and they are gone from the hall")
	_dispose()


func test_the_queue_never_overbooks() -> void:
	_make_flow()
	var spawned := 0
	for index in GuildHallZones.queue_length() + 2:
		if _flow.spawn() != null:
			spawned += 1
	equal(spawned, GuildHallZones.queue_length(), "the hall takes exactly as many customers as it has places")
	equal(_flow.queue_length(), spawned, "and the flow agrees")
	_dispose()


func test_every_class_queues_with_its_own_plate() -> void:
	_make_flow()
	var styles: Array[String] = []
	var places := GuildHallZones.queue_length()
	for index in places:
		var customer := _flow.spawn()
		check(customer != null, "customer %d walks in" % index)
		if customer == null:
			continue
		styles.append(customer.class_id)
		equal(customer.plate.text, GuildLocale.text("customer." + customer.class_id, "en"), "the plate names the class")
	check(styles == GuildCustomerFlow.CLASSES.slice(0, places), "the five classes take turns down the line")
	_flow.set_language("fa")
	for customer in _flow.customers:
		not_equal(customer.plate.text, GuildLocale.text("customer." + customer.class_id, "en"), "Persian renames them")
	_dispose()


func test_the_flow_reports_what_it_did() -> void:
	_make_flow()
	_flow.spawn("warrior")
	_flow.advance(20.0)
	var line := _flow.report()
	check(line.contains("spawned=1"), "the report counts who walked in")
	check(line.contains("waiting=1"), "and who is waiting")
	check(line.contains("order="), "and what is on the counter")
	var customer_line := _flow.customers[0].report()
	check(customer_line.contains("state=ordering"), "each customer reports their own state")
	_dispose()
