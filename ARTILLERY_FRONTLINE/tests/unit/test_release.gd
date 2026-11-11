extends RefCounted
## What must hold for a build that goes to a phone: the approved rules of play
## are the ones in the data, the Android package is set up as agreed, a chosen
## quality survives a restart, and the three volume sliders reach three buses.

const ZOMBIES: Dictionary = {
	&"walker": {"health": 80.0, "breach": 25.0, "places": 1, "boss": false, "fielded": 184},
	&"runner": {"health": 45.0, "breach": 15.0, "places": 1, "boss": false, "fielded": 118},
	&"brute": {"health": 520.0, "breach": 90.0, "places": 2, "boss": false, "fielded": 22},
	&"boss": {"health": 7000.0, "breach": 600.0, "places": 3, "boss": true, "fielded": 1},
}


func run(t: TestContext) -> void:
	_approved_play(t)
	_android(t)
	await _boss_entrance(t)
	_settings(t)


## The numbers of the approved design. A change here is a change of balance and has to be meant.
func _approved_play(t: TestContext) -> void:
	var aim: AimSettings = load("res://resources/aim/default_aim.tres")
	t.near(aim.pitch_min_degrees, -15.0, 0.0001, "the gun depresses 15 degrees")
	t.near(aim.pitch_max_degrees, 45.0, 0.0001, "and elevates 45")
	t.check(is_equal_approx(aim.yaw_min_degrees, -70.0) and is_equal_approx(aim.yaw_max_degrees, 70.0), "it traverses 70 degrees to either side")
	var gun: WeaponData = load("res://resources/weapons/twin_hmg.tres")
	t.check(is_equal_approx(gun.damage, 34.0) and is_equal_approx(gun.headshot_multiplier, 2.5) and is_equal_approx(gun.fire_interval, 0.085)
		and gun.magazine_size == 160 and is_equal_approx(gun.reload_time, 2.6) and gun.reserve < 0,
		"the machine gun: 34 a round, 2.5 times to the head, a round every 0.085 s, 160 to a belt, 2.6 s to reload, belts without end")
	var launcher: WeaponData = load("res://resources/weapons/rpg_launcher.tres")
	t.check(is_equal_approx(launcher.damage, 260.0) and launcher.magazine_size == 1 and launcher.reserve == 3 and launcher.reserve_max == 6,
		"the launcher: 260 on a direct hit, one in the tube, three spare, six at most")
	var rocket_blast: ExplosionData = load("res://resources/explosions/rocket_blast.tres")
	var grenade_blast: ExplosionData = load("res://resources/explosions/grenade_blast.tres")
	t.check(is_equal_approx(rocket_blast.damage, 220.0) and is_equal_approx(rocket_blast.radius, 5.5), "a rocket's blast: 220 over 5.5 m")
	t.check(is_equal_approx(grenade_blast.damage, 200.0) and is_equal_approx(grenade_blast.radius, 5.0), "a grenade's blast: 200 over 5 m")
	t.check(rocket_blast.structure_damage <= 0.0 and grenade_blast.structure_damage <= 0.0, "neither harms the wall or the gate")
	var grenade: GrenadeData = load("res://resources/weapons/frag_grenade.tres")
	t.check(grenade.carried == 3 and grenade.capacity == 5 and is_equal_approx(grenade.max_range, 46.0), "grenades: three carried, five at most, 46 m of reach")
	var wall: DefenseData = load("res://resources/defense/city_wall.tres")
	t.check(is_equal_approx(wall.wall_max_health, 1000.0) and is_equal_approx(wall.gate_max_health, 700.0), "the wall holds 1000 and the gate 700")
	# The second gun the player may choose, and the sight both guns and the launcher share.
	var rotary: WeaponData = load("res://resources/weapons/rotary_gun.tres")
	t.check(is_equal_approx(rotary.damage, 17.0) and is_equal_approx(rotary.headshot_multiplier, 2.0) and is_equal_approx(rotary.fire_interval, 0.04)
		and rotary.magazine_size == 500 and is_equal_approx(rotary.reload_time, 3.6) and rotary.reserve < 0 and rotary.penetration == 0
		and is_equal_approx(rotary.spin_up_time, 0.3),
		"the six-barrel gun: 17 a round, twice to the head, a round every 0.04 s, 500 to a belt, 3.6 s to reload, 0.3 s to spin up, no round passes through")
	t.check(rotary.damage / rotary.fire_interval < gun.damage / gun.fire_interval * 1.1 and rotary.damage / rotary.fire_interval > gun.damage / gun.fire_interval * 0.9,
		"held on a body the two guns do the same work to within a tenth (%.0f against %.0f a second)" % [
			rotary.damage / rotary.fire_interval, gun.damage / gun.fire_interval])
	t.check(Profile.GUNS == ["twin_hmg", "rotary_gun"] and Profile.DEFAULTS.settings.gun == "twin_hmg", "the twin gun is the one a new player starts with")
	t.check(is_equal_approx(aim.fov_degrees, 43.0) and is_equal_approx(aim.zoom_factor, 2.5), "the eye sees 43 degrees; the drawn-in sight brings the street 2.5 times closer")
	var waves: WaveSet = Campaign.whole()
	t.equal(waves.waves.size(), 8, "the siege is eight waves")
	t.equal(waves.total_zombies(), 325, "of 325 zombies")
	var sizes: Array = []
	for stage: int in Campaign.count():
		sizes.append(Campaign.waves(stage).waves.size())
	t.equal(sizes, [3, 3, 2], "played in three stages: the first of three waves, then three, then the last two")
	t.equal(Campaign.waves(0).total_zombies(), 74, "the first stage fields 74 zombies")
	for id: StringName in ZOMBIES:
		var wanted: Dictionary = ZOMBIES[id]
		var data: ZombieData = load("res://resources/zombies/%s.tres" % String(id))
		t.check(data.id == id and is_equal_approx(data.max_health, wanted.health) and is_equal_approx(data.breach_damage, wanted.breach)
			and data.footprint == int(wanted.places) and data.is_boss == bool(wanted.boss),
			"the %s: %d health, %d off the wall when it gets in, %d place(s) at the wall" % [id, wanted.health, wanted.breach, wanted.places])
		var fielded: int = 0
		for wave: WaveData in waves.waves:
			fielded += wave.count_of(id)
		t.equal(fielded, int(wanted.fielded), "%d of them over the siege" % wanted.fielded)
	var last: WaveData = waves.waves[waves.waves.size() - 1]
	t.equal(last.count_of(&"boss"), 1, "the one boss comes in the last wave")
	t.check(float(ZOMBIES[&"boss"].breach) < wall.wall_max_health, "and its way in costs less than a whole wall")


func _android(t: TestContext) -> void:
	var presets := ConfigFile.new()
	t.equal(presets.load("res://export_presets.cfg"), OK, "the export presets parse")
	var version: String = ProjectSettings.get_setting("application/config/version")
	for index: int in 2:
		var head: String = "preset.%d" % index
		var options: String = head + ".options"
		var label: String = String(presets.get_value(head, "name", ""))
		t.equal(String(presets.get_value(head, "platform", "")), "Android", "%s is an Android preset" % label)
		t.check(bool(presets.get_value(options, "architectures/arm64-v8a", false)) and not bool(presets.get_value(options, "architectures/armeabi-v7a", true))
			and not bool(presets.get_value(options, "architectures/x86", true)) and not bool(presets.get_value(options, "architectures/x86_64", true)),
			"%s builds for ARM64 and nothing else" % label)
		var asked: Array[String] = []
		for key: String in presets.get_section_keys(options):
			if not key.begins_with("permissions/"):
				continue
			var value: Variant = presets.get_value(options, key)
			if (value is bool and value) or (value is PackedStringArray and not (value as PackedStringArray).is_empty()):
				asked.append(key)
		t.check(asked.is_empty(), "%s asks for no Android permission (%s)" % [label, str(asked)])
		t.equal(int(presets.get_value(options, "package/app_category", -1)), 2, "%s is declared as a game, not as some other kind of app" % label)
		t.check(bool(presets.get_value(options, "screen/immersive_mode", false)), "%s hides the system bars" % label)
		t.check(not bool(presets.get_value(options, "user_data_backup/allow", true)), "%s keeps the save out of cloud backups" % label)
		t.check(not bool(presets.get_value(options, "gradle_build/use_gradle_build", true)), "%s uses the stock template, whose floor is Android 7.0" % label)
		t.check(bool(presets.get_value(options, "package/signed", false)), "%s is signed" % label)
		t.equal(String(presets.get_value(options, "version/name", "")), version, "%s carries the project's version" % label)
		t.check(int(presets.get_value(options, "version/code", 0)) >= 5, "%s has a version code above every earlier build" % label)
		var left_out: String = String(presets.get_value(head, "exclude_filter", ""))
		t.check(left_out.contains("tests/*") and left_out.contains("tools/*") and left_out.contains("documentation/*"), "%s ships no tests, tools or reports" % label)
	t.check(String(presets.get_value("preset.0.options", "package/unique_name", "")) != String(presets.get_value("preset.1.options", "package/unique_name", "")),
		"the two packages can be installed side by side")
	t.check(bool(ProjectSettings.get_setting("display/window/energy_saving/keep_screen_on")), "the screen stays on during a siege")
	t.equal(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")), 60, "the simulation runs 60 ticks a second")
	t.check(not bool(ProjectSettings.get_setting("audio/driver/enable_input")), "the microphone is never opened")
	t.check(not ProjectSettings.has_setting("application/run/max_fps") or int(ProjectSettings.get_setting("application/run/max_fps")) == 0,
		"the frame rate is left to the display")


## The approved rule: the boss getting in costs 600 of the wall's 1000, and that alone does not end the match.
func _boss_entrance(t: TestContext) -> void:
	var level: CityLevel = t.make_level()
	await t.frames(2)
	level.begin_match()
	level.director.stop()
	level.defense.apply_damage("gate", level.defense.gate_health + 1.0)
	t.check(level.defense.gate_destroyed and not level.defense.breached, "the gate is down, the wall whole")
	var boss: Zombie = level.horde.spawn(&"boss", "avenue_left", "gate")
	level.horde.entered_city(boss)
	t.near(level.defense.wall_health, 400.0, 0.001, "the boss getting into the city takes 600 of the wall's 1000")
	t.check(not level.defense.breached and not level.over, "and that alone does not lose the match")
	t.check(level.horde.boss == null and level.horde.alive_count() == 0, "the boss is gone from the field")
	var second: Zombie = level.horde.spawn(&"boss", "avenue_left", "gate")
	level.horde.entered_city(second)
	t.check(level.defense.breached and level.over, "what is left of the wall would not survive a second such blow")
	await t.discard(level)


func _settings(t: TestContext) -> void:
	# A chosen quality survives a restart of the game.
	var path: String = "user://release_test_profile.json"
	var original_path: String = Profile.save_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Profile.save_path = path
	Profile.persist = true
	Profile.reset()
	Profile.set_setting("quality", "low")
	Profile.set_setting("left_handed", true)
	t.check(FileAccess.file_exists(path), "a changed setting is written to the save")
	Profile.data = {}
	Profile.load_profile()
	Graphics.apply_preference()
	t.equal(String(Profile.setting("quality")), "low", "a chosen quality is still chosen after a restart")
	t.equal(Graphics.tier, "low", "and it is the tier in force")
	t.check(not Graphics.governing(), "with the governor standing aside")
	t.check(bool(Profile.setting("left_handed")), "the other settings come back with it")
	Profile.set_setting("quality", "auto")
	Profile.data = {}
	Profile.load_profile()
	Graphics.apply_preference()
	t.equal(String(Profile.setting("quality")), "auto", "and so does a return to automatic")
	Profile.persist = false
	Profile.save_path = original_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Profile.reset()
	Graphics.apply_preference()

	# Three sliders, three buses.
	t.equal(Sound.clips.size(), Sound.CLIPS.size(), "every clip in the mixer's list was loaded (%d)" % Sound.clips.size())
	t.check(AudioServer.get_bus_name(Sound.sfx_bus) == "Effects" and AudioServer.get_bus_name(Sound.music_bus) == "Music", "effects and music each have their bus")
	Profile.set_setting("master_volume", 0.5)
	t.near(AudioServer.get_bus_volume_db(0), linear_to_db(0.5), 0.01, "the master slider sets the master bus")
	Profile.set_setting("sfx_volume", 0.25)
	t.near(AudioServer.get_bus_volume_db(Sound.sfx_bus), linear_to_db(0.25), 0.01, "the effects slider sets the effects bus")
	t.near(AudioServer.get_bus_volume_db(Sound.music_bus), linear_to_db(float(Profile.DEFAULTS.settings.music_volume)), 0.01, "and leaves the music where it was")
	Profile.set_setting("music_volume", 0.0)
	t.check(AudioServer.is_bus_mute(Sound.music_bus), "music at nought mutes the music bus")
	t.check(not AudioServer.is_bus_mute(0) and not AudioServer.is_bus_mute(Sound.sfx_bus), "and nothing else")
	Profile.set_setting("music_volume", 0.6)
	t.check(not AudioServer.is_bus_mute(Sound.music_bus), "raising it again brings the music back")
	Profile.set_setting("master_volume", 0.0)
	t.check(AudioServer.is_bus_mute(0), "the master at nought silences everything")
	Profile.reset()
	t.check(not AudioServer.is_bus_mute(0) and not AudioServer.is_bus_mute(Sound.sfx_bus) and not AudioServer.is_bus_mute(Sound.music_bus),
		"the settings a new player starts with leave nothing silent")
	t.near(AudioServer.get_bus_volume_db(0), 0.0, 0.01, "and the master at full")
