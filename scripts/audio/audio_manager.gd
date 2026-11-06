class_name BattlefieldAudio
extends Node
## Original synthesized sound effects; no external samples or network access.

var enabled: bool = true
var _players: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _next_player: int = 0


func _ready() -> void:
	for i in range(4):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_sounds["fire"] = _synthesize(0.55, 68.0, 0.85, 11)
	_sounds["impact"] = _synthesize(0.85, 47.0, 0.75, 23)
	_sounds["reload"] = _synthesize(0.22, 330.0, 0.32, 43)


func play_sound(sound_name: String) -> void:
	if not enabled or not _sounds.has(sound_name):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _sounds[sound_name]
	player.volume_db = -5.0 if sound_name != "reload" else -12.0
	player.play()


func _synthesize(
	seconds: float, frequency: float, noise_mix: float, seed_value: int
) -> AudioStreamWAV:
	const RATE: int = 22050
	var sample_count := int(seconds * RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(sample_count):
		var t := float(i) / RATE
		var envelope := exp(-t * (5.0 if seconds > 0.4 else 15.0))
		var tone := sin(TAU * frequency * t * (1.0 - 0.35 * t))
		var noise := rng.randf_range(-1.0, 1.0)
		var sample := clampf(
			(tone * (1.0 - noise_mix) + noise * noise_mix) * envelope * 0.72, -1.0, 1.0
		)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream
