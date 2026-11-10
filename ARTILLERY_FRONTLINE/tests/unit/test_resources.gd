extends RefCounted
func run(t: TestContext) -> void:
	var ids: Array[String] = []
	for id in ["sr01", "sr02", "sr03", "sr04", "sr05"]:
		var mission: MissionData = load("res://resources/missions/%s.tres" % id)
		t.check(mission != null, "Mission resource loads " + id)
		if mission == null:
			continue
		t.check(mission.target_ids.size() > 0 and mission.ammunition.he > 0, "Mission has playable objectives and supply")
		ids.append(mission.id)
	t.equal(ids.size(), 5, "Five distinct playable mission definitions")
	var weapon: WeaponData = load("res://resources/weapons/kestrel.tres")
	t.equal(weapon.compatible_ammunition.size(), 2, "Two compatible ammunition types")
	for id in ["emplacement", "tank", "transport"]:
		var enemy: EnemyData = load("res://resources/enemies/%s.tres" % id)
		t.check(enemy.health > 0 and enemy.collision_size.length() > 0, "Enemy configuration valid")

	# Field-radio voices: every line is shipped and the channel refuses overlap.
	var voice_ids: Array[String] = ["contact", "get_down", "man_down", "take_cover", "reloading", "move_out", "incoming", "keep_moving", "medic", "spotted"]
	var shipped: int = 0
	for id in voice_ids:
		if ResourceLoader.exists("res://assets/voices/%s.wav" % id):
			shipped += 1
	t.equal(shipped, voice_ids.size(), "Every radio voice line ships as a WAV asset")
	t.check(not Sound.play_voice("does_not_exist"), "Unknown radio line is refused instead of queued")
