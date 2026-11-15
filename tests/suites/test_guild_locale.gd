extends TestCase
## Guild Tycoon's language contract: English is the source, Persian replaces
## words only. The layout, the alignment, the direction and the number format are
## identical in both languages, and no key may fall back silently.

## Keys whose Persian text is legitimately identical: they are pure formatting.
const IDENTICAL_OK: Array[String] = ["hud.warehouse_value"]


func _placeholders(text: String) -> Array[String]:
	var found: Array[String] = []
	for index in 8:
		var marker := "{%d}" % index
		if text.contains(marker):
			found.append(marker)
	return found


func test_english_is_complete() -> void:
	check(GuildLocale.keys().size() > 50, "the base table should be a real vocabulary")
	for key in GuildLocale.keys():
		var english := GuildLocale.text(key, "en")
		check(not english.is_empty(), "empty English for " + key)
		not_equal(english, key, "missing English for " + key)


func test_every_english_key_has_a_persian_override() -> void:
	var missing := GuildLocale.missing_overrides()
	check(missing.is_empty(), "untranslated keys: " + ", ".join(missing))


func test_persian_is_really_translated() -> void:
	var same: Array[String] = []
	for key in GuildLocale.untranslated_overrides():
		if not IDENTICAL_OK.has(key):
			same.append(key)
	check(same.is_empty(), "Persian still equals English for: " + ", ".join(same))


func test_placeholders_survive_translation() -> void:
	for key in GuildLocale.keys():
		var english := _placeholders(GuildLocale.text(key, "en"))
		var persian := _placeholders(GuildLocale.text(key, "fa"))
		equal(persian, english, "placeholder mismatch in " + key)


func test_layout_never_mirrors() -> void:
	for language in GuildLocale.LANGUAGES:
		check(not GuildLocale.is_rtl(language), "no RTL mirroring in " + language)
	equal(GuildLocale.layout_direction(), Control.LAYOUT_DIRECTION_LTR, "layout stays LTR")
	equal(GuildLocale.alignment(), HORIZONTAL_ALIGNMENT_LEFT, "text stays left aligned")


func test_numbers_are_latin_in_both_languages() -> void:
	var value := GuildLocale.format_number(1234567.0)
	equal(value, "1,234,567", "thousands separators")
	for digit in ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]:
		check(not value.contains(digit), "Persian digits would change the width")
	equal(GuildLocale.format_number(-1500.0), "-1,500", "negatives keep their sign")
	equal(GuildLocale.format_number(1500.5, 1), "1,500.5", "decimals keep the separator")
	equal(GuildLocale.format_number(0.0), "0", "zero is zero")


func test_money_abbreviates_without_changing_the_bar() -> void:
	equal(GuildLocale.format_money(850.0), "850", "small sums stay exact")
	equal(GuildLocale.format_money(12340.0), "12.3K", "tens of thousands use K")
	equal(GuildLocale.format_money(4500000.0), "4.5M", "millions use M")
	equal(GuildLocale.format_money(2100000000.0), "2.1B", "billions use B")


func test_durations_read_like_a_timer() -> void:
	equal(GuildLocale.format_duration(9.0), "9s", "seconds")
	equal(GuildLocale.format_duration(90.0), "1m", "minutes")
	equal(GuildLocale.format_duration(4800.0), "1h 20m", "hours")
	equal(GuildLocale.format_duration(0.0), "0s", "zero does not go negative")


func test_substitution_works_in_both_languages() -> void:
	var english := GuildLocale.t("msg.picked", ["Slime Gel"], "en")
	check(english.contains("Slime Gel"), "English argument missing: " + english)
	check(not english.contains("{0}"), "English placeholder left: " + english)
	var persian := GuildLocale.t("msg.picked", ["Slime Gel"], "fa")
	check(persian.contains("Slime Gel"), "Persian keeps the item name: " + persian)
	check(not persian.contains("{0}"), "Persian placeholder left: " + persian)
	not_equal(persian, english, "Persian uses its own words")


func test_unknown_keys_echo_instead_of_crashing() -> void:
	equal(GuildLocale.text("no.such.key", "fa"), "no.such.key", "unknown keys echo")
	check(not GuildLocale.has_key("no.such.key"), "unknown keys are not known")
	check(not GuildLocale.has_key("hud.gold "), "keys are exact")
