extends Node
## Central generated-audio facade. Production WAV/OGG assets can replace it without scene changes.

const MIX_RATE := 22050.0
var music_enabled := true
var sound_enabled := true
var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _music_playback: AudioStreamGeneratorPlayback
var _sfx_playback: AudioStreamGeneratorPlayback
var _music_phase := 0.0
var _sfx_phase := 0.0
var _sfx_frequency := 0.0
var _sfx_frames_left := 0


func _ready() -> void:
	_music_player = _make_generator_player(-28.0)
	_sfx_player = _make_generator_player(-12.0)
	_music_playback = _music_player.get_stream_playback()
	_sfx_playback = _sfx_player.get_stream_playback()
	apply_settings()


func _make_generator_player(volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.25
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	return player


func _process(_delta: float) -> void:
	if music_enabled and _music_playback:
		for i in _music_playback.get_frames_available():
			# Gentle two-note forest placeholder ambience.
			var wave := sin(_music_phase) * 0.16 + sin(_music_phase * 1.5) * 0.07
			_music_playback.push_frame(Vector2(wave, wave))
			_music_phase = fmod(_music_phase + TAU * 110.0 / MIX_RATE, TAU)
	if sound_enabled and _sfx_playback:
		for i in _sfx_playback.get_frames_available():
			var wave := 0.0
			if _sfx_frames_left > 0:
				wave = sin(_sfx_phase) * 0.35 * minf(1.0, _sfx_frames_left / 500.0)
				_sfx_phase += TAU * _sfx_frequency / MIX_RATE
				_sfx_frames_left -= 1
			_sfx_playback.push_frame(Vector2(wave, wave))


func apply_settings() -> void:
	if not SaveManager.data.is_empty():
		music_enabled = bool(SaveManager.data.settings.music)
		sound_enabled = bool(SaveManager.data.settings.sound)
	if _music_player:
		_music_player.stream_paused = not music_enabled
	if _sfx_player:
		_sfx_player.stream_paused = not sound_enabled


func play_sfx(event: String) -> void:
	if not sound_enabled:
		return
	var frequencies := {
		"jump": 540.0,
		"coin": 880.0,
		"hit": 120.0,
		"button": 420.0,
		"game_over": 160.0,
		"reward": 760.0,
	}
	_sfx_frequency = float(frequencies.get(event, 360.0))
	_sfx_frames_left = int(MIX_RATE * (0.24 if event in ["hit", "game_over"] else 0.10))
	_sfx_phase = 0.0


func vibrate(duration_ms := 35) -> void:
	if bool(SaveManager.data.settings.vibration):
		Input.vibrate_handheld(duration_ms)


func set_music(enabled: bool) -> void:
	music_enabled = enabled
	SaveManager.data.settings.music = enabled
	SaveManager.save()
	apply_settings()


func set_sound(enabled: bool) -> void:
	sound_enabled = enabled
	SaveManager.data.settings.sound = enabled
	SaveManager.save()
	apply_settings()
