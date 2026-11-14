extends TestCase
## The city rules: money, roads, growth, goals and saving.


func test_a_new_city() -> void:
	var state := CityState.new()
	almost(state.cash, CityState.STARTING_CASH, "starting gold")
	equal(state.structure_at(CityState.HALL_CELL), CityData.HALL_ID, "the town hall is placed")
	almost(state.population, 0.0, "nobody lives here yet")
	almost(state.capacity, 0.0, "there is nowhere to live yet")
	equal(state.connected_buildings, 0, "no connected buildings")
	check(state.cell_in_bounds(Vector2i(0, 0)), "the centre is on the island")
	check(not state.cell_in_bounds(Vector2i(CityData.HALF_GRID, 0)), "the edge is off the island")


func test_placing_costs_money() -> void:
	var state := CityState.new()
	var cash := state.cash
	check(state.place("road", Vector2i(1, 0)), "a road can be placed next to the hall")
	almost(state.cash, cash - float(CityData.cost("road")), "the road is paid for")
	check(not state.place("road", Vector2i(1, 0)), "the same cell cannot be built twice")
	check(not state.place("road", Vector2i(CityData.HALF_GRID + 2, 0)), "cannot build off the island")
	check(not state.place(CityData.HALL_ID, Vector2i(5, 5)), "the town hall cannot be copied")
	check(not state.place("no_such_structure", Vector2i(2, 0)), "unknown structures are refused")


func test_building_needs_gold() -> void:
	var state := CityState.new()
	state.cash = 10.0
	check(not state.place("house_a", Vector2i(1, 0)), "an expensive house is refused")
	almost(state.cash, 10.0, "a refused build changes nothing")
	state.cash = 500.0
	check(state.place("house_a", Vector2i(1, 0)), "gold buys the house")


func test_roads_connect_buildings_to_the_hall() -> void:
	var state := CityState.new()
	state.place_free("road", Vector2i(1, 0))
	state.place_free("house_a", Vector2i(2, 0))
	equal(state.connected_buildings, 1, "the house is connected through the road")
	almost(state.capacity, 4.0, "the house adds capacity")
	check(state.income > 0.0, "the house earns money")
	almost(state.happiness, 45.0, "a connected house costs no happiness")

	var isolated := CityState.new()
	isolated.place_free("house_a", Vector2i(-4, -4))
	equal(isolated.connected_buildings, 0, "without a road there is no connection")
	equal(isolated.unconnected_buildings, 1, "the house is reported as unconnected")
	almost(isolated.capacity, 0.0, "an unconnected house holds nobody")
	check(isolated.happiness < 45.0, "an unconnected house is a problem")


func test_cutting_the_road_disconnects_the_city() -> void:
	var state := CityState.new()
	state.place_free("road", Vector2i(1, 0))
	state.place_free("house_a", Vector2i(2, 0))
	equal(state.connected_buildings, 1, "connected to start with")
	var result := state.remove(Vector2i(1, 0))
	equal(str(result.get("id", "")), "road", "the road is gone")
	equal(state.connected_buildings, 0, "the house lost its connection")
	equal(state.unconnected_buildings, 1, "and is counted as unconnected")


func test_roads_are_connected_through_each_other() -> void:
	var state := CityState.new()
	for x in range(1, 6):
		state.place_free("road", Vector2i(x, 0))
	state.place_free("house_b", Vector2i(5, 1))
	equal(state.connected_buildings, 1, "a long road still connects")
	almost(state.capacity, 7.0, "town house capacity")

	# A road that touches the hall but not the house does not help.
	var lonely := CityState.new()
	lonely.place_free("road", Vector2i(-1, 0))
	lonely.place_free("house_a", Vector2i(-5, 0))
	equal(lonely.connected_buildings, 0, "a disconnected road connects nothing")


func test_removing_refunds_half() -> void:
	var state := CityState.new()
	state.place_free("house_d", Vector2i(-2, 0))
	var before := state.cash
	var result := state.remove(Vector2i(-2, 0))
	equal(int(result["refund"]), CityData.refund("house_d"), "half of the price comes back")
	almost(state.cash, before + float(CityData.refund("house_d")), "the refund is paid")
	check(state.is_empty(Vector2i(-2, 0)), "the cell is free again")

	var hall := state.remove(CityState.HALL_CELL)
	check(hall.is_empty(), "the town hall cannot be removed")
	equal(state.structure_at(CityState.HALL_CELL), CityData.HALL_ID, "the hall stays")


func test_parks_make_people_happier_and_shops_less_happy() -> void:
	var plain := CityState.new()
	var park := CityState.new()
	park.place_free("trees", Vector2i(3, 3))
	park.place_free("fountain", Vector2i(4, 3))
	check(park.happiness > plain.happiness, "greenery raises happiness")

	var shop := CityState.new()
	shop.place_free("road", Vector2i(1, 0))
	shop.place_free("shop", Vector2i(2, 0))
	check(shop.happiness < plain.happiness, "a workshop makes the town less pleasant")


func test_population_grows_towards_capacity() -> void:
	var state := CityState.new()
	state.place_free("road", Vector2i(1, 0))
	state.place_free("house_a", Vector2i(2, 0))
	state.population = 0.0
	state.advance(2.0)
	check(state.population > 0.0, "people start moving in")
	state.advance(200.0)
	almost(state.population, state.capacity, "the house fills up")
	check(state.cash > CityState.STARTING_CASH, "a populated city earns money")

	state.place_free("house_b", Vector2i(1, 1))
	almost(state.capacity, 11.0, "a second house adds capacity")
	state.advance(1.0)
	check(state.population < state.capacity, "new capacity takes time to fill")


func test_income_follows_people_and_happiness() -> void:
	var state := CityState.new()
	state.place_free("road", Vector2i(1, 0))
	state.place_free("house_a", Vector2i(2, 0))
	state.population = 0.0
	var empty_income := state.income_per_second()
	state.population = 4.0
	var full_income := state.income_per_second()
	check(full_income > empty_income, "more people earn more")

	state.happiness = 100.0
	var happy_income := state.income_per_second()
	state.happiness = 45.0
	check(happy_income > state.income_per_second(), "happy people earn more")


func test_goals_pay_a_bonus_once() -> void:
	var state := CityState.new()
	var events: Array = []
	state.milestone_reached.connect(func(index: int, bonus: int) -> void:
		events.append([index, bonus])
	)
	state.capacity = 30.0
	state.population = 0.0
	state.happiness = 100.0
	var before := state.cash
	state.advance(60.0)
	equal(events.size(), 1, "the first goal fires once")
	equal(int(events[0][0]), 0, "goal index")
	equal(int(events[0][1]), CityState.MILESTONE_BONUS[0], "goal bonus")
	check(state.cash >= before + float(CityState.MILESTONE_BONUS[0]), "the bonus is paid")
	state.advance(10.0)
	equal(events.size(), 1, "the goal does not fire again")
	equal(state.next_milestone(), CityState.MILESTONES[1], "the next goal is the second one")


func test_saving_round_trip() -> void:
	var state := CityState.new()
	state.place_free("road", Vector2i(1, 0))
	state.place_free("house_b", Vector2i(2, 0), 2)
	state.cash = 1234.0
	state.population = 3.0
	state.elapsed = 42.0

	var data := state.serialize()
	var copy := CityState.deserialize(data)
	equal(copy.structure_at(Vector2i(2, 0)), "house_b", "the house survives the round trip")
	equal(copy.rotation_at(Vector2i(2, 0)), 2, "the rotation survives")
	almost(copy.cash, 1234.0, "gold survives")
	almost(copy.elapsed, 42.0, "the clock survives")
	equal(copy.connected_buildings, 1, "the city rebuilds its road network")
	equal(copy.structure_at(CityState.HALL_CELL), CityData.HALL_ID, "the hall survives")


func test_bad_saves_are_refused_or_repaired() -> void:
	var state := CityState.new()
	check(not state.apply_save({"version": 99, "cells": []}), "a future save version is refused")
	check(not state.apply_save({"version": CityState.SAVE_VERSION, "cells": "nope"}), "garbage is refused")

	var without_hall := {
		"version": CityState.SAVE_VERSION,
		"cash": 100.0,
		"population": 500.0,
		"cells": [{"x": 1, "z": 0, "id": "road", "rot": 0}],
	}
	check(state.apply_save(without_hall), "a save without a hall is repaired")
	equal(state.structure_at(CityState.HALL_CELL), CityData.HALL_ID, "the hall is restored")
	almost(state.population, state.capacity, "population is clamped to capacity")


func test_saving_to_disk() -> void:
	CityState.delete_save()
	check(not CityState.save_exists(), "no save before saving")
	var state := CityState.new()
	state.place_free("road", Vector2i(1, 0))
	state.cash = 777.0
	check(state.save_to_disk(), "the city is written")
	check(CityState.save_exists(), "the save file exists")
	var loaded := CityState.load_from_disk()
	check(loaded != null, "the city is read back")
	if loaded != null:
		equal(loaded.structure_at(Vector2i(1, 0)), "road", "the road is in the loaded city")
		almost(loaded.cash, 777.0, "the gold is in the loaded city")
	CityState.delete_save()
	check(not CityState.save_exists(), "the save can be deleted")
