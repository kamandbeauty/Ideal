extends SceneTree
## Writes the default siege (resources/waves/city_siege_waves.tres).
##
##     godot --headless --path . --script res://tools/make_waves.gd
##
## Run it to restore the shipped waves. Day-to-day balance is done by editing
## the .tres in the inspector: every group and number is an exported property.

const NEAR_RIGHT: Array = ["ring_right", "alley_right"]
const NEAR_LEFT: Array = ["ring_left", "alley_left"]
const CROSS: Array = ["cross_left", "cross_right"]
const AVENUE: Array = ["avenue_left", "avenue_right"]


func group(zombie: StringName, count: int, start: float, interval: float, routes: Array, target: String, burst: int = 1) -> SpawnGroup:
	var entry := SpawnGroup.new()
	entry.zombie = zombie
	entry.count = count
	entry.start_time = start
	entry.interval = interval
	entry.routes = PackedStringArray(routes)
	entry.target = target
	entry.burst = burst
	return entry


func wave(max_alive: int, intermission: float, groups: Array, rockets: int = 1, grenades: int = 1) -> WaveData:
	var data := WaveData.new()
	data.max_alive = max_alive
	data.intermission = intermission
	data.resupply_rockets = rockets
	data.resupply_grenades = grenades
	var typed: Array[SpawnGroup] = []
	for entry: SpawnGroup in groups:
		typed.append(entry)
	data.groups = typed
	return data


func _init() -> void:
	var siege := WaveSet.new()
	siege.opening_delay = 4.0
	siege.health_growth = 0.08
	siege.speed_growth = 0.03
	var waves: Array[WaveData] = [
		wave(30, 7.0, [
			group(&"walker", 8, 0.0, 1.6, NEAR_RIGHT, "gate"),
			group(&"walker", 8, 9.0, 1.8, NEAR_LEFT, "wall"),
		]),
		wave(36, 7.0, [
			group(&"walker", 10, 0.0, 1.3, NEAR_RIGHT + ["cross_right"], "gate"),
			group(&"walker", 8, 4.0, 1.6, NEAR_LEFT, "wall"),
			group(&"walker", 8, 14.0, 1.2, AVENUE, "gate"),
		]),
		wave(42, 8.0, [
			group(&"walker", 12, 0.0, 1.0, CROSS, "gate"),
			group(&"walker", 10, 2.0, 1.4, NEAR_LEFT, "wall"),
			group(&"walker", 8, 12.0, 0.9, NEAR_RIGHT, "gate", 2),
			group(&"walker", 8, 20.0, 1.2, AVENUE, "any"),
		]),
		wave(48, 8.0, [
			group(&"walker", 16, 0.0, 0.8, AVENUE + CROSS, "gate"),
			group(&"walker", 12, 3.0, 1.1, NEAR_LEFT, "wall"),
			group(&"walker", 12, 10.0, 0.9, NEAR_RIGHT, "gate", 2),
			group(&"walker", 12, 22.0, 0.8, [], "any"),
		], 2, 2),
		wave(54, 8.0, [
			group(&"walker", 20, 0.0, 0.7, AVENUE, "gate", 2),
			group(&"walker", 16, 2.0, 0.9, NEAR_LEFT + ["cross_left"], "wall"),
			group(&"walker", 16, 8.0, 0.8, NEAR_RIGHT + ["cross_right"], "gate", 2),
			group(&"walker", 18, 24.0, 0.6, [], "any", 3),
		]),
	]
	siege.waves = waves
	var error: int = ResourceSaver.save(siege, "res://resources/waves/city_siege_waves.tres")
	print("city_siege_waves.tres: ", error_string(error), ", ", siege.total_zombies(), " zombies in ", siege.waves.size(), " waves")
	quit(0 if error == OK else 1)
