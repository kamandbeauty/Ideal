extends RefCounted
## Text tables: both languages complete, placeholders aligned, digits localised.


func run(t: TestContext) -> void:
	var english: Dictionary = Loc.TEXT.en
	var persian: Dictionary = Loc.TEXT.fa
	var missing: Array[String] = []
	var empty: Array[String] = []
	var mismatched: Array[String] = []
	for key: String in english:
		if not persian.has(key):
			missing.append(key)
			continue
		if String(english[key]).strip_edges() == "" or String(persian[key]).strip_edges() == "":
			empty.append(key)
		if String(english[key]).count("%s") != String(persian[key]).count("%s"):
			mismatched.append(key)
	for key: String in persian:
		if not english.has(key):
			missing.append(key)
	t.check(missing.is_empty(), "both languages have the same keys (missing: %s)" % str(missing))
	t.check(empty.is_empty(), "no text is empty (%s)" % str(empty))
	t.check(mismatched.is_empty(), "placeholders match between languages (%s)" % str(mismatched))
	t.check(english.size() >= 50, "the table covers the interface (%d keys)" % english.size())

	var before: String = Loc.language
	Loc.language = "en"
	t.equal(Loc.t("wave", [2, 5]), "WAVE 2 / 5", "English formats numbers with Latin digits")
	t.equal(Loc.number(1234), "1234", "English keeps Latin digits")
	t.equal(Loc.percent(0.426), "43%", "English percent")
	t.equal(Loc.clock(125.0), "2:05", "clock formatting")
	t.check(not Loc.is_rtl(), "English is left-to-right")
	t.equal(Loc.t("no_such_key"), "no_such_key", "an unknown key is returned as-is")
	Loc.language = "fa"
	t.equal(Loc.number(1234), "۱۲۳۴", "Persian uses Persian digits")
	t.check(Loc.t("wave", [2, 5]).contains("۲") and Loc.t("wave", [2, 5]).contains("۵"), "Persian text carries Persian digits")
	t.equal(Loc.percent(0.5), "۵۰٪", "Persian percent")
	t.equal(Loc.clock(125.0), "۲:۰۵", "Persian clock")
	t.check(Loc.is_rtl(), "Persian is right-to-left")
	t.check(Loc.t("title") != english.title, "Persian has its own title")

	# Every message the game can raise has text.
	for kind: String in ["gate_attack", "wall_attack", "gate_half", "gate_critical", "wall_half", "wall_critical", "gate_destroyed", "wall_breached"]:
		t.check(english.has("warn_" + kind) and persian.has("warn_" + kind), "warning text exists for %s" % kind)
	for quality: String in Profile.QUALITY_CHOICES:
		t.check(english.has("quality_" + quality), "quality choice %s has a label" % quality)
	var weapon: WeaponData = load("res://resources/weapons/twin_hmg.tres")
	t.check(english.has(weapon.name_key), "the weapon's name key has text")

	# The fonts can draw both scripts.
	for heavy: bool in [false, true]:
		Loc.language = "fa"
		var persian_font: Font = UITheme.font(heavy)
		t.check(persian_font.has_char("د".unicode_at(0)) and persian_font.has_char("۵".unicode_at(0)), "the Persian font has Persian letters and digits")
		t.check(persian_font.has_char("A".unicode_at(0)), "the Persian font stack can draw Latin")
		Loc.language = "en"
		var latin_font: Font = UITheme.font(heavy)
		t.check(latin_font.has_char("W".unicode_at(0)), "the Latin font has Latin letters")
		t.check(latin_font.has_char("گ".unicode_at(0)), "the Latin font stack falls back for Persian")
	Loc.language = before
