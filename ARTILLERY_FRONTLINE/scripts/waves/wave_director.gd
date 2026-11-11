class_name WaveDirector
extends Node
## Plays a WaveSet: spawns each wave's groups on schedule, waits for the
## street to clear, pauses, and reports victory after the last wave.

signal finished

enum Phase { IDLE, OPENING, SPAWNING, CLEARING, INTERMISSION, COMPLETE }

@export var wave_set: WaveSet

var horde: Horde
var phase: Phase = Phase.IDLE
var index: int = -1
var clock: float = 0.0
var queue: Array = []
var rng := RandomNumberGenerator.new()
var spawned_in_wave: int = 0


func _ready() -> void:
	rng.randomize()


func wave_count() -> int:
	return wave_set.waves.size() if wave_set else 0


func begin() -> void:
	if wave_set == null or wave_set.waves.is_empty() or horde == null:
		return
	index = -1
	phase = Phase.OPENING
	clock = wave_set.opening_delay
	Events.intermission_started.emit(clock, 0)


func stop() -> void:
	phase = Phase.IDLE
	queue.clear()


## Zombies still to come in the current wave plus those alive.
func remaining() -> int:
	return queue.size() + (horde.alive_count() if horde else 0)


func _physics_process(delta: float) -> void:
	match phase:
		Phase.OPENING, Phase.INTERMISSION:
			clock -= delta
			if clock <= 0.0:
				_start_wave(index + 1)
		Phase.SPAWNING:
			clock += delta
			var wave: WaveData = wave_set.waves[index]
			while not queue.is_empty() and queue[0][0] <= clock and horde.alive_count() < wave.max_alive:
				_spawn(queue.pop_front())
			if queue.is_empty():
				phase = Phase.CLEARING
		Phase.CLEARING:
			if horde.alive_count() <= 0:
				_wave_cleared()


func _start_wave(wave_index: int) -> void:
	index = wave_index
	var wave: WaveData = wave_set.waves[index]
	queue = wave.schedule()
	clock = 0.0
	spawned_in_wave = 0
	horde.health_scale = wave_set.health_scale(index)
	horde.speed_scale = wave_set.speed_scale(index)
	phase = Phase.SPAWNING
	Events.wave_started.emit(index, wave_set.waves.size())


func _spawn(entry: Array) -> void:
	var routes: PackedStringArray = entry[2]
	var route: String
	if routes.is_empty():
		var names: Array[String] = horde.layout.route_names()
		route = names[rng.randi() % names.size()]
	else:
		route = routes[rng.randi() % routes.size()]
	if horde.spawn(entry[1], route, entry[3]) != null:
		spawned_in_wave += 1


func _wave_cleared() -> void:
	Events.wave_cleared.emit(index, wave_set.waves.size())
	if index + 1 >= wave_set.waves.size():
		phase = Phase.COMPLETE
		finished.emit()
		return
	phase = Phase.INTERMISSION
	clock = wave_set.waves[index].intermission
	Events.intermission_started.emit(clock, index + 1)
