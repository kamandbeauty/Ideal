extends RefCounted
func run(t: TestContext) -> void:
	var dir: String = "user://artillery_tests_%d" % Time.get_ticks_usec()
	var path: String = dir + "/save.json"
	var data: Dictionary = SaveManager.defaults()
	data.coins = 875
	data.completed = ["sr01"]
	data.unlocked.append("sr02")
	data.upgrades.reload = 2
	t.check(SaveManager.write_atomic(path, data), "Atomic save succeeds")
	var loaded: Dictionary = SaveManager.read_with_recovery(path)
	t.equal(loaded.data.coins, 875, "Round-trip currency")
	t.equal(loaded.data.upgrades.reload, 2, "Round-trip upgrades")
	t.check(not loaded.recovered, "Healthy primary load")
	data.coins = 999
	t.check(SaveManager.write_atomic(path, data), "Second save creates backup")
	var primary: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	primary.store_string("{broken json")
	primary.close()
	var recovered: Dictionary = SaveManager.read_with_recovery(path)
	t.check(recovered.recovered, "Corrupt primary triggers backup")
	t.equal(recovered.data.coins, 875, "Last-good backup restored")
	t.equal(SaveManager.read_with_recovery(path).data.coins, 875, "Recovered primary persisted")
	t.check(SaveManager.validate({"version": 999}).is_empty(), "Unknown schema rejected")
	t.check(SaveManager.validate([]).is_empty(), "Nontable save rejected")
	var unsafe: Dictionary = SaveManager.defaults()
	unsafe.coins = -500
	unsafe.upgrades.damage = 500
	unsafe.settings.quality = "invalid"
	var safe: Dictionary = SaveManager.validate(unsafe)
	t.equal(safe.coins, 0, "Currency sanitized")
	t.equal(safe.upgrades.damage, 4, "Upgrade level clamped")
	t.equal(safe.settings.quality, "auto", "Graphics preference sanitized")
	var bad: FileAccess = FileAccess.open(path + ".bak", FileAccess.WRITE)
	bad.store_string("bad backup")
	bad.close()
	var broken: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("bad primary")
	broken.close()
	t.check(SaveManager.read_with_recovery(path).recovered, "Both files corrupt safely defaults")
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)
	DirAccess.remove_absolute(dir)
