extends Node

const PATH := "user://settings.cfg"
var sound_enabled := true
var low_power := false

func _ready() -> void:
	load_settings()
	apply_settings()

func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	sound_enabled = bool(file.get_value("audio", "enabled", true))
	low_power = bool(file.get_value("graphics", "low_power", false))

func apply_settings() -> void:
	Engine.max_fps = 30 if low_power else 60
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_enabled)

func save_settings() -> Error:
	var file := ConfigFile.new()
	file.set_value("audio", "enabled", sound_enabled)
	file.set_value("graphics", "low_power", low_power)
	return file.save(PATH)
