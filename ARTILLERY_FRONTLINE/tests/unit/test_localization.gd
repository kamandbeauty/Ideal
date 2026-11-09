extends RefCounted
## Guards the Persian-first UI contract: copy, numerals, fonts and resources.
func run(t: TestContext) -> void:
	var latin := RegEx.new()
	latin.compile("[A-Za-z]")
	for key in Loc.STRINGS:
		t.check(Loc.is_persian(Loc.t(key)), "Persian display copy: " + key)
		t.check(latin.search(Loc.t(key).replace("%s", "")) == null, "No Latin letters in display copy: " + key)
	t.equal(Loc.digits("0123456789"), "۰۱۲۳۴۵۶۷۸۹", "Persian digits")
	t.equal(Loc.number(140), "۱۴۰", "Persian integer display")
	t.equal(Loc.clock(210), "۰۳:۳۰", "Persian mission clock")
	t.equal(Loc.state("READY"), Loc.t("ready"), "Internal READY code maps to Persian")
	t.equal(Loc.state("RELOADING"), Loc.t("reloading"), "Internal RELOADING code maps to Persian")
	t.check(Loc.is_persian(Loc.wave("FIRST LANDING")), "Coastal wave label localised")
	t.check(Loc.is_persian(Loc.target_name("t01")), "Target caption localised")
	t.check(Loc.is_persian(Loc.camera("OPTIC")), "Camera caption localised")
	t.check(Loc.is_persian(Loc.support("airstrike")), "Support caption localised")
	for key in ["reason_time", "reason_ammo", "reason_abandoned", "upgrade_installed", "upgrade_insufficient", "notice_intro", "toast_locked", "toast_storage"]:
		t.check(Loc.is_persian(Loc.t(key)), "Runtime message localised: " + key)
	for id in ["sr01", "sr02", "sr03", "sr04", "sr05"]:
		var mission: MissionData = load("res://resources/missions/%s.tres" % id)
		t.check(Loc.is_persian(mission.title), "Mission title Persian: " + id)
		t.check(Loc.is_persian(mission.subtitle), "Mission subtitle Persian: " + id)
		t.check(Loc.is_persian(mission.briefing), "Mission briefing Persian: " + id)
	for id in ["damage", "accuracy", "reload", "range", "capacity"]:
		var upgrade: UpgradeData = load("res://resources/upgrades/%s.tres" % id)
		t.check(Loc.is_persian(upgrade.display_name), "Upgrade name Persian: " + id)
		t.check(Loc.is_persian(upgrade.description), "Upgrade description Persian: " + id)
	for path in ["res://resources/enemies/emplacement.tres", "res://resources/enemies/tank.tres", "res://resources/enemies/transport.tres", "res://resources/ammunition/he.tres", "res://resources/ammunition/ap.tres", "res://resources/weapons/kestrel.tres"]:
		var resource: Variant = load(path)
		t.check(Loc.is_persian(resource.display_name), "Resource display name Persian: " + path.get_file())
	t.check(UITheme.regular.has_char(0x06CC), "Vazirmatn regular has Persian yeh")
	t.check(UITheme.bold.has_char(0x06AF), "Vazirmatn bold has Persian gaf")
	t.check(UITheme.regular.get_string_size("سلام", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x > 10.0, "Persian string measures with the shipped font")
	var hero: Texture2D = UITheme.texture("hero_beach.jpg")
	t.check(hero != null and hero.get_width() >= 1000, "Painted home-screen key art ships")
	t.check(UITheme.texture("emblem.png") != null, "Command emblem ships")
	var normal: StyleBox = UITheme.theme().get_stylebox("normal", "Button")
	var plate := normal as StyleBoxTexture
	t.check(plate != null and plate.texture != null, "Buttons use textured nine-patch plates")
