extends RefCounted
## Save files and the player profile.


func run(t: TestContext) -> void:
	var path: String = "user://test_lastwall_save.json"
	SaveManager.remove(path)
	t.equal(SaveManager.load_dict(path), {}, "a missing save loads as empty")
	var data: Dictionary = {"version": 1, "settings": {"language": "en", "sensitivity": 1.4}, "stats": {"kills": 12}}
	t.check(SaveManager.save_dict(path, data), "saving succeeds")
	var loaded: Dictionary = SaveManager.load_dict(path)
	t.equal(String(loaded.settings.language), "en", "strings survive the round trip")
	t.near(float(loaded.settings.sensitivity), 1.4, 0.0001, "numbers survive the round trip")
	# A second save keeps the first as backup; a damaged main file falls back to it.
	data.stats.kills = 99
	t.check(SaveManager.save_dict(path, data), "saving again succeeds")
	t.check(FileAccess.file_exists(path + ".bak"), "the previous save is kept as a backup")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	var recovered: Dictionary = SaveManager.load_dict(path)
	t.equal(int(recovered.stats.kills), 12, "a damaged save falls back to the backup")
	SaveManager.remove(path)
	t.check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"), "remove deletes the save and its backup")

	# Defaults are merged and types coerced.
	var defaults: Dictionary = Profile.DEFAULTS
	var merged: Dictionary = SaveManager.merge_defaults(defaults, {"settings": {"language": 5, "sensitivity": "fast", "invert_y": 1.0, "hack": true},
		"stats": {"kills": 7.0}, "junk": 1})
	t.equal(merged.settings.language, "fa", "a wrong-typed string falls back to the default")
	t.near(merged.settings.sensitivity, 1.0, 0.0001, "a wrong-typed number falls back to the default")
	t.equal(merged.settings.invert_y, true, "numbers coerce to booleans")
	t.check(not merged.settings.has("hack") and not merged.has("junk"), "unknown keys are dropped")
	t.equal(typeof(merged.stats.kills), TYPE_INT, "JSON floats coerce back to integers")
	t.equal(merged.stats.kills, 7, "the loaded value is kept")
	t.check(merged.settings.has("quality") and merged.stats.has("best_wave"), "missing keys get defaults")

	# Profile behaviour (persistence is off in tests).
	Profile.persist = false
	Profile.reset()
	t.equal(Profile.setting("language"), "fa", "Persian is the default language")
	var changes: Array = []
	var on_changed := func() -> void: changes.append(1)
	Profile.changed.connect(on_changed)
	Profile.set_setting("sensitivity", 9.0)
	t.near(Profile.setting("sensitivity"), 2.5, 0.0001, "sensitivity is clamped to its range")
	Profile.set_setting("quality", "ultra-mega")
	t.equal(Profile.setting("quality"), "auto", "an unknown quality falls back to auto")
	Profile.set_setting("no_such_setting", 3)
	t.check(not Profile.data.settings.has("no_such_setting"), "unknown settings are not created")
	t.equal(changes.size(), 2, "changed is emitted for each real change")
	Profile.set_setting("language", "en")
	t.equal(Loc.language, "en", "changing the language switches the text table")
	Profile.set_setting("language", "xx")
	t.equal(Profile.setting("language"), "fa", "an unknown language falls back to Persian")
	Profile.record_match({"victory": true, "wave": 4, "kills": 30, "headshots": 9})
	Profile.record_match({"victory": false, "wave": 2, "kills": 5, "headshots": 1})
	t.equal(Profile.data.stats.matches, 2, "matches are counted")
	t.equal(Profile.data.stats.victories, 1, "victories are counted")
	t.equal(Profile.data.stats.best_wave, 4, "the best wave is kept")
	t.equal(Profile.data.stats.kills, 35, "kills accumulate")
	Profile.changed.disconnect(on_changed)

	# Real persistence through the profile, on a scratch file.
	var profile_path: String = "user://test_lastwall_profile.json"
	SaveManager.remove(profile_path)
	var original_path: String = Profile.save_path
	Profile.save_path = profile_path
	Profile.persist = true
	Profile.reset()
	Profile.set_setting("left_handed", true)
	Profile.set_setting("music_volume", 0.25)
	Profile.data = {}
	Profile.load_profile()
	t.equal(Profile.setting("left_handed"), true, "a saved setting is restored")
	t.near(Profile.setting("music_volume"), 0.25, 0.0001, "a saved volume is restored")
	Profile.persist = false
	Profile.save_path = original_path
	SaveManager.remove(profile_path)
	Profile.reset()
