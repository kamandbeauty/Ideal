extends Node
## Central audio facade. Sounds are generated tones until production artwork/audio is supplied.

var music_enabled := true
var sound_enabled := true
var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	apply_settings()


func apply_settings() -> void:
	if not SaveManager.data.is_empty():
		music_enabled = bool(SaveManager.data.settings.music)
		sound_enabled = bool(SaveManager.data.settings.sound)


func play_sfx(_event: String) -> void:
	# Stable no-op when audio assets are absent; all calls remain centralized.
	if not sound_enabled:
		return


func set_music(enabled: bool) -> void:
	music_enabled = enabled
	SaveManager.data.settings.music = enabled
	SaveManager.save()


func set_sound(enabled: bool) -> void:
	sound_enabled = enabled
	SaveManager.data.settings.sound = enabled
	SaveManager.save()
