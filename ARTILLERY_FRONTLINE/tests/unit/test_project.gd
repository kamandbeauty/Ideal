extends RefCounted
## Project configuration, and proof that nothing of the coastal game is left.

const BANNED: Array[String] = ["coastal", "beach", "landing_craft", "landing craft", "patrol_boat", "bazooka", "soldier", "artillery", "cannon",
	"ocean", "mounted_rocket", "autocannon", "helicopter", "hangar"]
const ALLOWED_PATHS: Array[String] = ["res://tests/unit/test_project.gd"]


func _files(folder: String, found: Array[String]) -> void:
	for name: String in DirAccess.get_directories_at(folder):
		if name.begins_with(".") or name == "android":
			continue
		_files(folder.path_join(name), found)
	for name: String in DirAccess.get_files_at(folder):
		found.append(folder.path_join(name))


func run(t: TestContext) -> void:
	t.equal(ProjectSettings.get_setting("application/config/name"), "LAST WALL: Zombie Siege", "the project carries the new name")
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	t.check(ResourceLoader.exists(main_scene), "the main scene exists")
	for autoload: String in ["Events", "Profile", "Sound", "Graphics"]:
		t.check(t.tree.root.has_node(autoload), "autoload %s is running" % autoload)
	t.equal(int(ProjectSettings.get_setting("display/window/handheld/orientation")), 4, "the game is locked to sensor landscape")
	t.equal(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 1440, "reference canvas is 1440 wide")
	t.equal(String(ProjectSettings.get_setting("display/window/stretch/mode")), "canvas_items", "the interface scales with the screen")
	t.equal(String(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")), "mobile", "phones use the mobile renderer")
	t.check(bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc")), "Android texture formats are imported")
	t.check(bool(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse")), "the mouse drives the touch controls on desktop")
	t.equal(String(ProjectSettings.get_setting("layer_names/3d_physics/layer_2")), "Zombie body", "physics layer 2 is named")
	t.equal(Layers.BULLET_MASK, 15, "bullets collide with world, zombies and defences")

	var presets := ConfigFile.new()
	t.equal(presets.load("res://export_presets.cfg"), OK, "export presets parse")
	t.equal(String(presets.get_value("preset.0", "platform")), "Android", "the first preset targets Android")
	t.equal(String(presets.get_value("preset.0.options", "package/unique_name")), "com.studiojavid.zombiesiege", "the Android package id is the shipped one")
	t.equal(String(presets.get_value("preset.1.options", "package/unique_name")), "com.studiojavid.zombiesiege.compatibility",
		"the compatibility package can sit beside it")
	t.check(bool(presets.get_value("preset.0.options", "architectures/arm64-v8a")), "the APK is built for ARM64")
	t.check(not bool(presets.get_value("preset.0.options", "permissions/internet")), "the game asks for no network permission")
	t.check(String(presets.get_value("preset.0", "exclude_filter")).contains("tools/*"), "development tools are not exported")
	var zombie_source: String = FileAccess.get_file_as_string("res://scripts/zombies/zombie.gd")
	t.check(not zombie_source.contains("Graphics."), "zombie.gd does not name the Graphics autoload (the headless runner may compile it before autoloads exist)")
	var runner_source: String = FileAccess.get_file_as_string("res://tests/run_tests.gd")
	t.check(not runner_source.contains("Zombie.mix_extras"), "the test runner does not name class_name Zombie at parse time")

	# No file, script, scene or resource of the old game remains.
	var files: Array[String] = []
	_files("res://", files)
	var bad_names: Array[String] = []
	var bad_text: Array[String] = []
	var scanned: int = 0
	for path: String in files:
		var lower: String = path.to_lower()
		for word: String in BANNED:
			if lower.get_file().contains(word):
				bad_names.append(path)
		var extension: String = path.get_extension()
		if not ["gd", "tscn", "tres", "godot", "cfg", "gdshader"].has(extension) or ALLOWED_PATHS.has(path):
			continue
		scanned += 1
		var text: String = FileAccess.get_file_as_string(path).to_lower()
		for word: String in BANNED:
			if text.contains(word):
				bad_text.append("%s (%s)" % [path, word])
	t.check(bad_names.is_empty(), "no file is named after the old game (%s)" % str(bad_names))
	t.check(bad_text.is_empty(), "no script, scene or resource mentions the old game (%s)" % str(bad_text))
	t.check(scanned >= 40, "the scan covered the project's text files (%d)" % scanned)

	# Every scene and resource the project ships loads.
	var broken: Array[String] = []
	var loaded: int = 0
	for path: String in files:
		if path.begins_with("res://tests") or path.begins_with("res://tools") or path.begins_with("res://documentation"):
			continue
		if ["tscn", "tres"].has(path.get_extension()):
			loaded += 1
			if load(path) == null:
				broken.append(path)
	t.check(broken.is_empty(), "every scene and resource loads (%s)" % str(broken))
	t.check(loaded >= 10, "scenes and resources were found (%d)" % loaded)

	# Every sound the game asks for exists.
	var silent: Array[String] = []
	for clip: String in Sound.CLIPS:
		if not Sound.has_clip(clip):
			silent.append(clip)
	t.check(silent.is_empty(), "every listed sound clip is present (%s)" % str(silent))
