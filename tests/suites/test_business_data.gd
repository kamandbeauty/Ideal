extends TestCase
## The business catalogue: every entry is complete, unique and points at a model
## that really ships with the game.


func test_catalogue_is_complete() -> void:
	equal(BusinessData.ids().size(), 6, "six businesses should ship")
	equal(BusinessData.ORDER.size(), BusinessData.BUSINESSES.size(), "order covers the catalogue")
	for id in BusinessData.ids():
		var data := BusinessData.data(id)
		check(not data.is_empty(), "missing data for " + id)
		for key in [
			"model", "accent", "plot", "unlock_cost", "base_price", "base_capacity",
			"base_demand", "base_upkeep", "upgrade_cost", "branch_cost", "manager_cost",
		]:
			check(data.has(key), "%s is missing '%s'" % [id, key])
		check(float(data["base_capacity"]) > 0.0, id + " has no capacity")
		check(float(data["base_demand"]) > 0.0, id + " has no demand")
		check(float(data["base_price"]) > 0.0, id + " has no price")
		check(float(data["upgrade_cost"]) > 0.0, id + " cannot be upgraded")
		check(float(data["branch_cost"]) > 0.0, id + " has free branches")
		check(float(data["manager_cost"]) > 0.0, id + " has a free manager")


func test_models_exist_on_disk() -> void:
	for id in BusinessData.ids():
		var path := BusinessData.model_path(id)
		check(not path.is_empty(), "no model path for " + id)
		check(FileAccess.file_exists(path), "missing model file: " + path)
	for key in ["road-straight", "road-straight-lightposts", "pavement", "grass-trees-tall"]:
		check(
			FileAccess.file_exists(str(BusinessData.MODELS[key])),
			"missing scenery model: " + key
		)


func test_plots_do_not_overlap() -> void:
	var seen: Array[Vector2] = []
	for id in BusinessData.ids():
		var plot := BusinessData.plot(id)
		check(plot != Vector2.ZERO, id + " sits on the origin")
		check(not seen.has(plot), "two businesses share a plot at " + str(plot))
		seen.append(plot)


func test_first_business_is_free() -> void:
	equal(BusinessData.unlock_cost(TownState.FIRST_BUSINESS), 0.0, "the first business is free")
	for id in BusinessData.ids():
		if id == TownState.FIRST_BUSINESS:
			continue
		check(BusinessData.unlock_cost(id) > 0.0, id + " should cost something")


func test_branch_labels_have_keys() -> void:
	for branch in BusinessData.BRANCHES:
		var key := BusinessData.branch_label_key(branch)
		check(not L10n.translate("en", key).begins_with("branch."), "missing label for " + branch)


func test_towns_are_valid() -> void:
	equal(TownData.ORDER.size(), 5, "five towns are planned")
	for id in TownData.ORDER:
		check(TownData.has_town(id), "missing town data for " + id)
		check(TownData.traffic(id) > 0.0, id + " has no traffic")
		var businesses := TownData.businesses(id)
		check(businesses.size() >= 4, id + " has too few businesses")
		for business_id in businesses:
			check(BusinessData.has_business(str(business_id)), "unknown business in " + id)
	check(TownData.has_town("desert"), "the slice needs the desert town")
	equal(TownData.reputation_required("desert"), 0.0, "the desert town is the entry point")
	check(
		TownData.reputation_required("highway") > TownData.reputation_required("forest"),
		"the highway should unlock later than the forest"
	)
	var unlocked := TownData.unlocked_towns(0.0)
	check(unlocked.has("desert"), "the desert town must be available from the start")
