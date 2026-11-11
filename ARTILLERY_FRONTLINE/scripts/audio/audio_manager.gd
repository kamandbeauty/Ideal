extends Node
## Autoload Sound: pooled one-shot players, two looping beds and per-clip
## throttling so a full horde cannot flood the mixer. Every clip is original,
## synthesized by tools/build_audio.py.

const CLIP_DIR: String = "res://assets/audio/"
const CLIPS: Array[String] = [
	"hmg_shot", "dry_fire", "reload", "click", "critical", "impact", "impact_flesh", "impact_metal", "explosion", "rocket",
	"headshot", "zombie_groan_1", "zombie_groan_2", "zombie_groan_3", "zombie_death_1", "zombie_death_2", "zombie_attack_1",
	"zombie_attack_2", "gate_hit_1", "gate_hit_2", "wall_hit_1", "wall_hit_2", "gate_break", "wall_break", "alarm", "wave_horn",
	"wave_clear", "wind", "music_theme",
]
## Shortest gap between two starts of the same clip, in milliseconds.
const MIN_GAP_MS: Dictionary = {
	"impact_flesh": 45, "impact": 60, "impact_metal": 60, "headshot": 70, "zombie_groan_1": 500, "zombie_groan_2": 500,
	"zombie_groan_3": 500, "zombie_death_1": 120, "zombie_death_2": 120, "zombie_attack_1": 180, "zombie_attack_2": 180,
	"gate_hit_1": 110, "gate_hit_2": 110, "wall_hit_1": 110, "wall_hit_2": 110,
}
const SPATIAL_VOICES: int = 14
const FLAT_VOICES: int = 10

var clips: Dictionary = {}
var spatial: Array[AudioStreamPlayer3D] = []
var flat: Array[AudioStreamPlayer] = []
var loops: Dictionary = {}
var last_start: Dictionary = {}
var playback_enabled: bool = true
var sfx_bus: int = -1
var music_bus: int = -1
var spatial_cursor: int = 0
var flat_cursor: int = 0
## Counts requests that reached a voice; tests read it instead of listening.
var started: int = 0


func _ready() -> void:
	# The headless driver mixes nothing; skipping playback keeps logic tests free of orphaned streams.
	playback_enabled = DisplayServer.get_name() != "headless"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id: String in CLIPS:
		var path: String = CLIP_DIR + id + ".wav"
		if ResourceLoader.exists(path):
			clips[id] = load(path)
	sfx_bus = _bus("Effects")
	music_bus = _bus("Music")
	for index: int in SPATIAL_VOICES:
		var player := AudioStreamPlayer3D.new()
		player.bus = "Effects"
		player.max_distance = 400.0
		player.unit_size = 22.0
		player.attenuation_filter_cutoff_hz = 9000.0
		add_child(player)
		spatial.append(player)
	for index: int in FLAT_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		add_child(player)
		flat.append(player)
	Profile.changed.connect(apply_settings)
	apply_settings()


func _bus(bus_name: String) -> int:
	var existing: int = AudioServer.get_bus_index(bus_name)
	if existing >= 0:
		return existing
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
	return index


func apply_settings() -> void:
	var settings: Dictionary = Profile.data.settings
	_set_bus(0, settings.master_volume)
	_set_bus(sfx_bus, settings.sfx_volume)
	_set_bus(music_bus, settings.music_volume)


func _set_bus(index: int, volume: float) -> void:
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.001, volume)))


func has_clip(id: String) -> bool:
	return clips.has(id)


func _allowed(id: String) -> bool:
	if not clips.has(id):
		return false
	var gap: int = MIN_GAP_MS.get(id, 0)
	if gap > 0:
		var now: int = Time.get_ticks_msec()
		if now - int(last_start.get(id, -100000)) < gap:
			return false
		last_start[id] = now
	return true


## Non-positional one-shot: the player's own weapon, interface and alarms.
func play(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if not _allowed(id):
		return false
	started += 1
	if not playback_enabled:
		return true
	var player: AudioStreamPlayer = flat[flat_cursor]
	flat_cursor = (flat_cursor + 1) % flat.size()
	player.stream = clips[id]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	return true


func play_at(id: String, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if not _allowed(id):
		return false
	started += 1
	if not playback_enabled:
		return true
	var player: AudioStreamPlayer3D = spatial[spatial_cursor]
	spatial_cursor = (spatial_cursor + 1) % spatial.size()
	player.stream = clips[id]
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	return true


## Picks one of `<prefix>_1 .. <prefix>_<count>`.
func play_variant_at(prefix: String, count: int, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	return play_at("%s_%d" % [prefix, 1 + randi() % count], position, volume_db, pitch)


func start_loop(id: String, bus: String = "Music", volume_db: float = 0.0) -> void:
	if loops.has(id) or not clips.has(id):
		return
	var stream: AudioStreamWAV = clips[id].duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	var frame_bytes: int = (2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if stream.stereo else 1)
	stream.loop_end = stream.data.size() / frame_bytes
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	loops[id] = player
	if playback_enabled:
		player.play()


func stop_loop(id: String) -> void:
	if not loops.has(id):
		return
	var player: AudioStreamPlayer = loops[id]
	player.stop()
	player.stream = null
	player.queue_free()
	loops.erase(id)


func is_looping(id: String) -> bool:
	return loops.has(id)


func stop_all() -> void:
	for player: AudioStreamPlayer3D in spatial:
		player.stop()
		player.stream = null
	for player: AudioStreamPlayer in flat:
		player.stop()
		player.stream = null
	for id: String in loops.keys():
		stop_loop(id)


func _exit_tree() -> void:
	stop_all()
	clips.clear()
