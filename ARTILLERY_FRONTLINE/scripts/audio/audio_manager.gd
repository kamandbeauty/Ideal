extends Node
## Autoload Sound: pooled one-shot voices, looping beds, per-clip throttling
## and a rank for every clip, so a full horde or a long burst can neither flood
## the mixer nor cut off the sounds that matter. A limiter on the master bus
## keeps a rocket landing in the middle of a burst from clipping. Every clip is
## original, synthesized by tools/build_audio.py.

const CLIP_DIR: String = "res://assets/audio/"
const CLIPS: Array[String] = [
	"hmg_shot", "hmg_tail", "dry_fire", "reload", "click", "critical", "impact", "impact_flesh", "impact_metal", "explosion", "rocket",
	"headshot", "zombie_groan_1", "zombie_groan_2", "zombie_groan_3", "zombie_death_1", "zombie_death_2", "zombie_attack_1",
	"zombie_attack_2", "gate_hit_1", "gate_hit_2", "wall_hit_1", "wall_hit_2", "gate_break", "wall_break", "alarm", "wave_horn",
	"wave_clear", "wind", "music_theme", "explosion_small", "grenade_throw", "grenade_bounce", "weapon_switch", "resupply", "boss_roar",
	"boss_death", "body_fall", "ui_toggle", "ui_start", "ui_back", "victory", "defeat", "rotary_shot", "rotary_spin", "rotary_tail",
]
## Shortest gap between two starts of the same clip, in milliseconds.
const MIN_GAP_MS: Dictionary = {
	"impact_flesh": 45, "impact": 60, "impact_metal": 60, "headshot": 70, "zombie_groan_1": 500, "zombie_groan_2": 500,
	"zombie_groan_3": 500, "zombie_death_1": 120, "zombie_death_2": 120, "zombie_attack_1": 180, "zombie_attack_2": 180,
	"gate_hit_1": 160, "gate_hit_2": 160, "wall_hit_1": 160, "wall_hit_2": 160, "explosion": 70, "explosion_small": 70,
	"grenade_bounce": 50, "body_fall": 150, "hmg_tail": 250, "ui_toggle": 40, "rotary_tail": 250, "rotary_spin": 200,
}
## How much a clip matters when every voice is busy. A new sound may take the
## voice of one that matters no more than itself, never of one that matters
## more: bullet strikes give way to everything, and nothing cuts off an alarm,
## a blast or the giant. Clips not listed rank 1.
const RANK: Dictionary = {
	"impact": 0, "impact_flesh": 0, "impact_metal": 0, "grenade_bounce": 0, "zombie_groan_1": 0, "zombie_groan_2": 0,
	"zombie_groan_3": 0, "body_fall": 0, "hmg_tail": 0, "rotary_tail": 0, "rotary_spin": 0,
	"explosion": 2, "explosion_small": 2, "rocket": 2, "critical": 2, "resupply": 2, "ui_start": 2,
	"gate_break": 3, "wall_break": 3, "boss_roar": 3, "boss_death": 3, "alarm": 3, "wave_horn": 3, "wave_clear": 3,
	"victory": 3, "defeat": 3,
}
const SPATIAL_VOICES: int = 14
const FLAT_VOICES: int = 10
## The master bus never passes this level, however much is sounding at once.
const CEILING_DB: float = -0.8
## Seconds a bed takes to come up. A loop is cut from the middle of a sound, so it starts on a
## step, and a bed at full level the instant the game opens is heard as a fault, not as weather.
const LOOP_FADE: float = 1.6
const SILENT_DB: float = -60.0

var clips: Dictionary = {}
var spatial: Array[AudioStreamPlayer3D] = []
var flat: Array[AudioStreamPlayer] = []
## What each voice is carrying: is it sounding, how much its clip matters, and when it began.
var spatial_busy := PackedByteArray()
var spatial_rank := PackedInt32Array()
var spatial_since := PackedInt64Array()
var flat_busy := PackedByteArray()
var flat_rank := PackedInt32Array()
var flat_since := PackedInt64Array()
var loops: Dictionary = {}
var last_start: Dictionary = {}
var playback_enabled: bool = true
var sfx_bus: int = -1
var music_bus: int = -1
## Counts requests that reached a voice; tests read it instead of listening.
var started: int = 0
## Requests turned away because every voice carried something that mattered more.
var refused: int = 0


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
	_protect_master()
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
	spatial_busy.resize(SPATIAL_VOICES)
	spatial_rank.resize(SPATIAL_VOICES)
	spatial_since.resize(SPATIAL_VOICES)
	flat_busy.resize(FLAT_VOICES)
	flat_rank.resize(FLAT_VOICES)
	flat_since.resize(FLAT_VOICES)
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


## A burst, a blast and an alarm at once add up to more than full scale.
## Without a limiter the output simply clips, which a phone speaker turns into a rasp.
func _protect_master() -> void:
	for index: int in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, index) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = CEILING_DB
	limiter.pre_gain_db = 0.0
	limiter.release = 0.12
	AudioServer.add_bus_effect(0, limiter)


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


func rank_of(id: String) -> int:
	return int(RANK.get(id, 1))


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


## Which voice a sound of `rank` gets: a silent one if there is one; otherwise
## the one carrying the least important sound, and among equals the one that
## has sounded longest. -1 when every voice carries something that matters more.
static func choose_voice(busy: PackedByteArray, ranks: PackedInt32Array, since: PackedInt64Array, rank: int) -> int:
	var best: int = -1
	for index: int in busy.size():
		if busy[index] == 0:
			return index
		if ranks[index] > rank:
			continue
		if best < 0 or ranks[index] < ranks[best] or (ranks[index] == ranks[best] and since[index] < since[best]):
			best = index
	return best


## Non-positional one-shot: the player's own weapon, interface and alarms.
func play(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if not _allowed(id):
		return false
	if not playback_enabled:
		started += 1
		return true
	for index: int in FLAT_VOICES:
		flat_busy[index] = 1 if flat[index].playing else 0
	var rank: int = rank_of(id)
	var voice: int = choose_voice(flat_busy, flat_rank, flat_since, rank)
	if voice < 0:
		refused += 1
		return false
	started += 1
	flat_rank[voice] = rank
	flat_since[voice] = Time.get_ticks_msec()
	var player: AudioStreamPlayer = flat[voice]
	player.stream = clips[id]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	return true


func play_at(id: String, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if not _allowed(id):
		return false
	if not playback_enabled:
		started += 1
		return true
	for index: int in SPATIAL_VOICES:
		spatial_busy[index] = 1 if spatial[index].playing else 0
	var rank: int = rank_of(id)
	var voice: int = choose_voice(spatial_busy, spatial_rank, spatial_since, rank)
	if voice < 0:
		refused += 1
		return false
	started += 1
	spatial_rank[voice] = rank
	spatial_since[voice] = Time.get_ticks_msec()
	var player: AudioStreamPlayer3D = spatial[voice]
	player.stream = clips[id]
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	return true


## Picks one of `<prefix>_1 .. <prefix>_<count>`.
func play_variant_at(prefix: String, count: int, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	return play_at("%s_%d" % [prefix, 1 + randi() % count], position, volume_db, pitch)


## Frames in a clip, whatever it is stored as. Counting the bytes is wrong for
## the compressed formats the importer writes: it put the loop point of the
## theme two fifths of the way through it.
static func frames_of(stream: AudioStreamWAV) -> int:
	return int(round(stream.get_length() * float(stream.mix_rate)))


func start_loop(id: String, bus: String = "Music", volume_db: float = 0.0, fade: float = LOOP_FADE) -> void:
	if loops.has(id) or not clips.has(id):
		return
	var stream: AudioStreamWAV = clips[id].duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames_of(stream)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	loops[id] = player
	if not playback_enabled:
		return
	if fade > 0.0:
		player.volume_db = SILENT_DB
		# Bound to the player, so stopping the bed stops its fade; it keeps rising while the game is paused.
		var rise: Tween = player.create_tween()
		rise.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		rise.tween_method(func(level: float) -> void: player.volume_db = linear_to_db(level),
			db_to_linear(SILENT_DB), db_to_linear(volume_db), fade)
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
