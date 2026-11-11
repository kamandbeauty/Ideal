extends SceneTree

# Test using an isolated user data directory to avoid changing real settings.
func _initialize() -> void:
	var settings = load("res://scripts/preferences.gd").new()
	settings.sound_enabled = false
	settings.low_power = true
	assert(settings.save_settings() == OK)
	settings.sound_enabled = true
	settings.low_power = false
	settings.load_settings()
	assert(not settings.sound_enabled)
	assert(settings.low_power)
	print("Preferences round-trip passed")
	settings.free()
	quit()
