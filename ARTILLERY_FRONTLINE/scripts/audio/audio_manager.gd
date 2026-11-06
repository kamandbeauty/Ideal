extends Node
## Autoload Sound. Fixed pools; original synthesized PCM, no downloads at runtime.
var clips: Dictionary = {}
var spatial: Array[AudioStreamPlayer3D] = []
var interface: Array[AudioStreamPlayer] = []
var wind: AudioStreamPlayer
var playback_enabled: bool = true
var master_bus: int = -1
var sfx_bus: int = -1
var ambient_bus: int = -1

func _ready() -> void:
	# The headless dummy driver does not mix audio; avoid orphaned playback objects
	# in fast logic tests while keeping bus/resource configuration under test.
	playback_enabled = DisplayServer.get_name() != "headless"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in ["cannon", "explosion", "reload", "click", "impact", "wind", "hmg", "rocket"]:
		var path: String = "res://assets/audio/%s.wav" % id
		if ResourceLoader.exists(path):
			clips[id] = load(path)
	master_bus = _bus("Frontline SFX")
	sfx_bus = master_bus
	ambient_bus = _bus("Frontline Ambience")
	for index in range(12):
		var player := AudioStreamPlayer3D.new()
		player.bus = "Frontline SFX"
		player.max_distance = 950.0
		player.unit_size = 28.0
		add_child(player)
		spatial.append(player)
	for index in range(4):
		var player := AudioStreamPlayer.new()
		player.bus = "Frontline SFX"
		add_child(player)
		interface.append(player)
	if clips.has("wind"):
		wind = AudioStreamPlayer.new()
		var stream: AudioStreamWAV = clips.wind.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
		wind.stream = stream
		wind.bus = "Frontline Ambience"
		add_child(wind)
		if playback_enabled:
			wind.play()
	Profile.changed.connect(apply_settings)
	apply_settings()

func _bus(name: String) -> int:
	var existing: int = AudioServer.get_bus_index(name)
	if existing >= 0:
		return existing
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, name)
	AudioServer.set_bus_send(index, "Master")
	return index

func apply_settings() -> void:
	var settings: Dictionary = Profile.data.settings
	AudioServer.set_bus_mute(0, float(settings.master_volume) <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(settings.master_volume))))
	AudioServer.set_bus_mute(sfx_bus, float(settings.sfx_volume) <= 0.0)
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(maxf(0.0001, float(settings.sfx_volume))))
	AudioServer.set_bus_mute(ambient_bus, float(settings.ambient_volume) <= 0.0)
	AudioServer.set_bus_volume_db(ambient_bus, linear_to_db(maxf(0.0001, float(settings.ambient_volume))))

func play_at(id: String, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not playback_enabled or not clips.has(id):
		return
	var selected: AudioStreamPlayer3D = spatial[0]
	for player in spatial:
		if not player.playing:
			selected = player
			break
	selected.stream = clips[id]
	selected.global_position = position
	selected.volume_db = volume_db
	selected.pitch_scale = pitch
	selected.play()

func play_ui(id: String = "click") -> void:
	if not playback_enabled or not clips.has(id):
		return
	for player in interface:
		if not player.playing:
			player.stream = clips[id]
			player.volume_db = -9.0
			player.play()
			return

func stop_all() -> void:
	for player in spatial:
		player.stop()
		player.stream = null
	for player in interface:
		player.stop()
		player.stream = null
	if wind:
		wind.stop()
		wind.stream = null

func _exit_tree() -> void:
	stop_all()
	clips.clear()
