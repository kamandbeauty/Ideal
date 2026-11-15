extends TestCase
## Capacity rules behind the visible customer flow, plus the vehicle catalogue
## the flow draws from.


func test_queue_serves_up_to_capacity() -> void:
	var queue := ServiceQueue.new()
	queue.configure(2, 4)
	equal(queue.request(1, 4.0), "served", "the first customer gets a slot")
	equal(queue.request(2, 4.0), "served", "so does the second")
	equal(queue.request(3, 4.0), "queued", "the third has to wait")
	equal(queue.size(), 3, "three customers are in the line")
	equal(queue.serving_count(), 2, "only two are being served")
	equal(queue.waiting_count(), 1, "one is still waiting")


func test_full_line_turns_travellers_away() -> void:
	var queue := ServiceQueue.new()
	queue.configure(1, 2)
	equal(queue.request(1, 3.0), "served", "first in")
	equal(queue.request(2, 3.0), "queued", "second waits")
	equal(queue.request(3, 3.0), "rejected", "the line is full")
	equal(queue.size(), 2, "a rejected customer never joins")


func test_tick_pays_and_promotes_the_line() -> void:
	var queue := ServiceQueue.new()
	queue.configure(1, 3)
	queue.request(1, 1.0)
	queue.request(2, 1.0)
	equal(queue.is_serving(2), false, "the second one waits at first")
	var done: Array[int] = queue.tick(1.2)
	equal(done.size(), 1, "one customer finished")
	equal(done[0], 1, "the one at the front paid")
	equal(queue.is_serving(2), true, "the next customer steps up")
	equal(queue.index_of(2), 0, "and moves to the front of the line")


func test_waiting_customers_do_not_age() -> void:
	var queue := ServiceQueue.new()
	queue.configure(1, 3)
	queue.request(1, 0.5)
	queue.request(2, 0.5)
	queue.tick(0.3)
	equal(queue.progress_of(2), 0.0, "a waiting customer has not started service")
	queue.tick(0.4)
	equal(queue.is_serving(2), true, "now they are at the front")
	check(queue.progress_of(2) >= 0.0, "progress stays sane")


func test_reconfigure_keeps_only_what_fits() -> void:
	var queue := ServiceQueue.new()
	queue.configure(3, 5)
	for i in 5:
		queue.request(i, 5.0)
	equal(queue.size(), 5, "five customers fit")
	queue.configure(1, 2)
	equal(queue.size(), 2, "shrinking the line drops the tail")


func test_vehicle_catalogue_is_unique_and_shaped() -> void:
	equal(VehicleMesh.KINDS.size(), 6, "six silhouettes")
	equal(VehicleMesh.PAINTS.size(), 10, "ten paint variants")
	for kind in VehicleMesh.KINDS:
		var profile := VehicleMesh.spec(kind)
		check(profile.size() >= 5, "%s carries a full profile" % kind)
		check(float(profile["length"]) > float(profile["width"]), "%s is longer than wide" % kind)
	check(VehicleMesh.PAINTS.size() >= VehicleMesh.KINDS.size(), "every kind has colours")
