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
	var persian := L10n.translate("fa", "hud.level", [3])
	check(persian.contains("3"), "Persian level missing: " + persian)
	var english := L10n.translate("en", "menu.record", [7])
	check(english.contains("7"), "best reputation not substituted: " + english)
	var offline := L10n.translate("en", "hud.offline_body", [2, 5, "1,200"])
	check(offline.contains("2") and offline.contains("5"), "offline numbers missing")
	check(offline.contains("1,200"), "offline earnings missing")


func test_shared_world_and_ui_digits_preserve_punctuation() -> void:
	equal(L10n.to_digits("fa", "01 ×2 · 3.5"), "۰۱ ×۲ · ۳.۵", "Persian numbers keep punctuation and padding")
	equal(L10n.to_digits("en", "01 ×2 · 3.5"), "01 ×2 · 3.5", "English numbers are unchanged")
	equal(L10n.translate("fa", "hud.level", ["۱۲"]), "سطح ۱۲", "no English Lv in a Persian level label")
	for key in ["hud.price_customer", "hud.efficiency", "event.remaining"]:
		var text := L10n.translate("fa", key, ["۲"])
		check(text.contains("۲"), key + " uses the localized argument")
		check(not text.contains("customer") and not text.contains("Profit"), key + " is fully Persian")


func test_unknown_key_is_echoed() -> void:
	equal(L10n.translate("fa", "no.such.key"), "no.such.key", "unknown keys should echo")
	equal(L10n.translate("fa", "hud.cash"), "پول", "cash label")


func test_languages_are_distinct() -> void:
	not_equal(
		L10n.translate("fa", "app.title"),
		L10n.translate("en", "app.title"),
		"the title should differ between languages"
	)
	equal(L10n.LANGUAGES.size(), 2, "two languages are shipped")
	check(L10n.has_language("fa") and L10n.has_language("en"), "fa and en are supported")
	check(not L10n.has_language("de"), "unexpected language accepted")


func test_every_business_has_a_name_and_a_description() -> void:
	for id in BusinessData.ids():
		for language in L10n.LANGUAGES:
			var name := L10n.translate(language, "business.%s.name" % id)
			var description := L10n.translate(language, "business.%s.desc" % id)
			check(name != "business.%s.name" % id, "missing name for " + id)
			check(description != "business.%s.desc" % id, "missing description for " + id)


func test_every_town_branch_and_manager_is_named() -> void:
	for id in TownData.ORDER:
		var label := L10n.translate("en", "town.%s" % id)
		check(label != "town.%s" % id, "missing town name for " + id)
	for branch in BusinessData.BRANCHES:
		var label := L10n.translate("fa", "branch.%s" % branch)
		check(label != "branch.%s" % branch, "missing branch label for " + branch)
	for rank in range(BusinessData.MAX_MANAGER + 1):
		var label := L10n.translate("en", "manager.rank.%d" % rank)
		check(label != "manager.rank.%d" % rank, "missing manager rank %d" % rank)
