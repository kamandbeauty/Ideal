extends TestCase
## The structure catalogue: prices, categories, models and the build palette.


func test_every_structure_is_complete() -> void:
	for id in CityData.all_ids():
		var data := CityData.structure(id)
		check(CityData.CATEGORIES.has(CityData.category_of(id)), "bad category for " + id)
		check(CityData.cost(id) >= 0, "negative price for " + id)
		check(not CityData.model_of(id).is_empty(), "no model for " + id)
		var path := CityData.model_path(CityData.model_of(id))
		check(not path.is_empty(), "no model path for " + id)
		check(FileAccess.file_exists(path), "missing model file: " + path)


func test_prices_and_refunds() -> void:
	check(CityData.cost("road") > 0, "a road costs something")
	check(CityData.cost("road") <= CityState.STARTING_CASH, "a road is affordable at the start")
	for id in CityData.all_ids():
		var cost := CityData.cost(id)
		var refund := CityData.refund(id)
		if cost == 0:
			equal(refund, 0, "a free structure refunds nothing: " + id)
		else:
			check(refund < cost, "refund below price for " + id)
			equal(refund, int(floor(cost * 0.5)), "refund is half the price for " + id)


func test_palette_excludes_the_town_hall() -> void:
	for category in CityData.CATEGORIES:
		var ids := CityData.ids_in_category(category)
		check(not ids.is_empty(), "category %s has something to build" % category)
		check(not ids.has(CityData.HALL_ID), "the town hall is not for sale")
		var previous := -1
		for id in ids:
			check(CityData.category_of(id) == category, "wrong category in " + category)
			check(CityData.cost(id) >= previous, "the palette is sorted by price in " + category)
			previous = CityData.cost(id)


func test_buildings_need_roads_and_parks_do_not() -> void:
	for id in ["house_a", "house_b", "house_d", "shop"]:
		check(CityData.needs_road(id), id + " needs a road")
		var data := CityData.structure(id)
		var gives := float(data["population"]) > 0.0 or float(data["income"]) > 0.0
		check(gives, id + " gives something")
	for id in ["grass", "trees", "tall_trees", "pavement", "fountain"]:
		check(not CityData.needs_road(id), id + " does not need a road")
		check(float(CityData.structure(id)["happiness"]) > 0.0, id + " adds happiness")


func test_there_is_a_sensible_building_line_up() -> void:
	var homes := CityData.ids_in_category("residential")
	check(homes.size() >= 3, "at least three kinds of home")
	var capacity := 0.0
	for id in homes:
		capacity += float(CityData.structure(id)["population"])
	check(capacity >= 20.0, "the homes can hold the first goal")
	equal(CityData.ids_in_category("road").size(), 1, "one road tool, auto-tiled")


func test_models_are_listed_once() -> void:
	var seen := {}
	for model_id in CityData.MODEL_PATHS:
		var path := CityData.model_path(model_id)
		check(not seen.has(path), "duplicate model path: " + path)
		seen[path] = true
		check(FileAccess.file_exists(path), "missing model: " + path)
