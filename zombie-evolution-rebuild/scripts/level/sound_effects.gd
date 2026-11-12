extends Node

# Short generated effects are shared by a bounded pool of voices. The existing
# Master-bus preference controls these players as well as all other game audio.
const EFFECTS := {
	"rifle": preload("res://assets/audio/rifle.wav"),
	"impact": preload("res://assets/audio/impact.wav"),
	"gate": preload("res://assets/audio/gate.wav"),
	"reload": preload("res://assets/audio/reload.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
	"defeat": preload("res://assets/audio/defeat.wav"),
}
const AudioProbe = preload("res://ci/audio_probe.gd")
const VOICE_COUNT := 12
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0

func _ready() -> void:
	for i in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = -12.0
		add_child(player)
		voices.append(player)

func play_effect(name: String) -> void:
	if not EFFECTS.has(name) or voices.is_empty():
		return
	var player := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	player.stop()
	player.stream = EFFECTS[name]
	player.play()
	if OS.has_environment("CI_SOUND_DIAGNOSTICS"):
		AudioProbe.record(player.get_stream_playback())

func stop_all() -> void:
	for player in voices:
		player.stop()
		player.stream = null

func _exit_tree() -> void:
	stop_all()
