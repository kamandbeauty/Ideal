extends Node
## Small sound pool for UI clicks, building sounds and the ambience.

const POOL_SIZE := 10
const AMBIENCE := "res://assets/audio/ambience.ogg"

var _players: Array[AudioStreamPlayer] = []
var _free: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = -14.0
		add_child(player)
		player.finished.connect(_release.bind(player))
		_players.append(player)
		_free.append(player)
	_start_ambience()


## Plays one sound. A path may contain a wildcard, e.g.
## "res://assets/audio/placement-*.ogg", and a random match is used.
func play(path: String, volume_db: float = -14.0) -> void:
	var chosen := _resolve(path)
	if chosen.is_empty():
		return
	if _free.is_empty():
		return
	var player: AudioStreamPlayer = _free.pop_back()
	player.stream = load(chosen)
	player.volume_db = volume_db
	player.play()


func stop_ambience() -> void:
	if _ambience != null:
		_ambience.stop()


func _start_ambience() -> void:
	if not ResourceLoader.exists(AMBIENCE):
		return
	var stream: AudioStream = load(AMBIENCE)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = stream
	_ambience.volume_db = -24.0
	_ambience.autoplay = true
	add_child(_ambience)
	_ambience.play()


func _resolve(path: String) -> String:
	if not path.contains("*"):
		return path if ResourceLoader.exists(path) else ""
	var directory := path.get_base_dir()
	var pattern := path.get_file()
	var matches: Array[String] = []
	for file in DirAccess.get_files_at(directory):
		if file.match(pattern):
			matches.append(directory.path_join(file))
	if matches.is_empty():
		return ""
	return matches[randi() % matches.size()]


func _release(player: AudioStreamPlayer) -> void:
	if not _free.has(player):
		_free.append(player)
