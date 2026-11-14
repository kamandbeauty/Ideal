extends TestCase
## The two-language text table must be complete and must substitute values.


func test_every_key_exists_in_every_language() -> void:
	for key in L10n.keys():
		for language in L10n.LANGUAGES:
			var text := L10n.translate(language, key)
			check(not text.is_empty(), "empty string for %s/%s" % [key, language])
			check(text != key, "missing translation for %s/%s" % [key, language])
	check(L10n.is_complete(), "the translation table reports itself incomplete")


func test_arguments_are_substituted() -> void:
	var persian := L10n.translate("fa", "hud.population_value", [3, 10])
	check(persian.contains("3"), "Persian population missing: " + persian)
	check(persian.contains("10"), "Persian capacity missing: " + persian)
	var english := L10n.translate("en", "menu.best", [7])
	check(english.contains("7"), "best population not substituted: " + english)


func test_unknown_key_is_echoed() -> void:
	equal(L10n.translate("fa", "no.such.key"), "no.such.key", "unknown keys should echo")
	equal(L10n.translate("fa", "hud.cash"), "طلا", "gold label")


func test_languages_are_distinct() -> void:
	not_equal(
		L10n.translate("fa", "app.title"),
		L10n.translate("en", "app.title"),
		"the title should differ between languages"
	)
	equal(L10n.LANGUAGES.size(), 2, "two languages are shipped")
	check(L10n.has_language("fa") and L10n.has_language("en"), "fa and en are supported")
	check(not L10n.has_language("de"), "unexpected language accepted")


func test_every_structure_has_a_name_and_a_description() -> void:
	for id in CityData.all_ids():
		for language in L10n.LANGUAGES:
			var name := L10n.translate(language, "structure.%s.name" % id)
			var description := L10n.translate(language, "structure.%s.desc" % id)
			check(name != "structure.%s.name" % id, "missing name for " + id)
			check(
				description != "structure.%s.desc" % id,
				"missing description for " + id
			)
	for category in CityData.CATEGORIES:
		var label := L10n.translate("en", "category." + category)
		check(label != "category." + category, "missing category label for " + category)
