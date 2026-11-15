extends Node
## Music and sound effects. Every file is synthesised by `tools/build_audio.py`,
## so the game ships no licensed audio and the palette is one coherent 1950s
## roadside band: electric piano, upright bass, brushes, vibraphone.
##
## `play("coin")` takes a short name from `NAMES`; a full `res://` path still
## works, which is what the older UI code passes.

const POOL_SIZE := 14
const FADE_SECONDS := 1.1
const MUSIC_DB := -9.0
const AMBIENCE_DB := -26.0
const AMBIENCE := "res://assets/audio/ambience.ogg"

## Short name -> file. Keep this table in sync with `tools/build_audio.py`.
const NAMES := {
	"coin": "res://assets/audio/sfx/coin.ogg",
	"cash": "res://assets/audio/sfx/cash.ogg",
	"build": "res://assets/audio/sfx/build.ogg",
	"upgrade": "res://assets/audio/sfx/upgrade.ogg",
	"levelup": "res://assets/audio/sfx/levelup.ogg",
	"mission": "res://assets/audio/sfx/mission.ogg",
	"gem": "res://assets/audio/sfx/gem.ogg",
	"hire": "res://assets/audio/sfx/hire.ogg",
	"event": "res://assets/audio/sfx/event.ogg",
	"click": "res://assets/audio/sfx/click.ogg",
	"deny": "res://assets/audio/sfx/deny.ogg",
	"complete": "res://assets/audio/sfx/complete.ogg",
	"whoosh": "res://assets/audio/sfx/whoosh.ogg",
	"pop": "res://assets/audio/sfx/pop.ogg",
	"travel": "res://assets/audio/sfx/travel.ogg",
}

const MUSIC := {
	"menu": "res://assets/audio/music/menu.ogg",
	"day": "res://assets/audio/music/day.ogg",
	"night": "res://assets/audio/music/night.ogg",
}

var _players: Array[AudioStreamPlayer] = []
var _free: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _track := ""
var _fade: Tween
var _last_played: Dictionary = {}

var _music_volume := 0.7
var _sfx_volume := 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		player.finished.connect(_release.bind(player))
		_players.append(player)
		_free.append(player)

	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	add_child(_music)

	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Master"
	add_child(_ambience)

	if App != null:
		set_music_volume(App.music_volume)
		set_sfx_volume(App.sfx_volume)


func play(name_or_path: String, volume_db: float = -6.0) -> void:
	if _sfx_volume <= 0.001 or _free.is_empty():
		return
	var path := str(NAMES.get(name_or_path, name_or_path))
	if not ResourceLoader.exists(path):
		return
	# One-shots fired in the same frame would otherwise phase into mush.
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(path, -1000)) < 45:
		return
	_last_played[path] = now

	var player: AudioStreamPlayer = _free.pop_back()
	player.stream = _stream(path)
	player.volume_db = volume_db + linear_to_db(_sfx_volume)
	player.play()


# --- Music -----------------------------------------------------------------

## Crossfades to a looping track: "menu", "day" or "night".
func play_music(track: String) -> void:
	var path := str(MUSIC.get(track, ""))
	if path.is_empty() or _track == track or _music == null:
		return
	_track = track
	if not ResourceLoader.exists(path):
		return
	var stream := _stream(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_fade_out()
	var tween := create_tween()
	tween.tween_callback(func() -> void:
		if _music == null:
			return
		_music.stream = stream
		_music.volume_db = -60.0
		_music.play()
	).set_delay(FADE_SECONDS * 0.5)
	tween.tween_property(_music, "volume_db", _music_db(), FADE_SECONDS)
	_fade = tween


func stop_music() -> void:
	_track = ""
	if _music != null:
		_music.stop()


func current_track() -> String:
	return _track


func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	if _music != null:
		_music.volume_db = _music_db()


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)


# --- Ambience --------------------------------------------------------------

func start_ambience() -> void:
	if _ambience == null or _ambience.playing:
		return
	if not ResourceLoader.exists(AMBIENCE):
		return
	var stream := _stream(AMBIENCE)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_ambience.stream = stream
	_ambience.volume_db = AMBIENCE_DB
	_ambience.play()


func stop_ambience() -> void:
	if _ambience != null:
		_ambience.stop()


# --- Internals -------------------------------------------------------------

func _music_db() -> float:
	if _music_volume <= 0.001:
		return -80.0
	return MUSIC_DB + linear_to_db(_music_volume)


func _fade_out() -> void:
	if _music == null or not _music.playing:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", -60.0, FADE_SECONDS * 0.5)
	_fade.tween_callback(_music.stop)


func _stream(path: String) -> AudioStream:
	var stream: AudioStream = load(path)
	return stream if stream == null else stream.duplicate()


func _release(player: AudioStreamPlayer) -> void:
	if not _free.has(player):
		_free.append(player)
