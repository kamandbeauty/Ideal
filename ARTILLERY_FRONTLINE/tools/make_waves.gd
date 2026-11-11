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


func wave(max_alive: int, intermission: float, groups: Array, rockets: int = 1, grenades: int = 1, hint: String = "") -> WaveData:
	var data := WaveData.new()
	data.max_alive = max_alive
	data.intermission = intermission
	data.resupply_rockets = rockets
	data.resupply_grenades = grenades
	data.hint_key = hint
	var typed: Array[SpawnGroup] = []
	for entry: SpawnGroup in groups:
		typed.append(entry)
	data.groups = typed
	return data


func _init() -> void:
	var siege := WaveSet.new()
	siege.opening_delay = 4.0
	siege.health_growth = 0.06
	siege.speed_growth = 0.02
	var waves: Array[WaveData] = [
		# 1. The first probe: walkers at the gate, then at the patched wall.
		wave(30, 7.0, [
			group(&"walker", 8, 0.0, 1.6, NEAR_RIGHT, "gate"),
			group(&"walker", 8, 9.0, 1.8, NEAR_LEFT, "wall"),
		]),
		# 2. Runners appear behind the walkers.
		wave(36, 7.0, [
			group(&"walker", 10, 0.0, 1.3, NEAR_RIGHT + ["cross_right"], "gate"),
			group(&"walker", 8, 4.0, 1.6, NEAR_LEFT, "wall"),
			group(&"runner", 6, 16.0, 0.8, AVENUE, "any"),
		], 1, 1, "wave_hint_runners"),
		# 3. Both kinds, on both sides.
		wave(40, 8.0, [
			group(&"walker", 12, 0.0, 1.1, CROSS, "gate"),
			group(&"walker", 10, 2.0, 1.4, NEAR_LEFT, "wall"),
			group(&"runner", 6, 10.0, 0.5, NEAR_RIGHT, "gate", 2),
			group(&"runner", 6, 24.0, 0.5, NEAR_LEFT, "wall", 2),
		]),
		# 4. The first brutes go for the gate.
		wave(40, 8.0, [
			group(&"brute", 2, 0.0, 9.0, NEAR_RIGHT, "gate"),
			group(&"walker", 14, 3.0, 1.0, AVENUE + CROSS, "gate"),
			group(&"walker", 8, 6.0, 1.3, NEAR_LEFT, "wall"),
			group(&"runner", 8, 20.0, 0.6, AVENUE, "any", 2),
		], 2, 1, "wave_hint_brutes"),
		# 5. Everything together.
		wave(46, 8.0, [
			group(&"walker", 16, 0.0, 0.9, AVENUE + CROSS, "gate"),
			group(&"walker", 12, 3.0, 1.1, NEAR_LEFT, "wall"),
			group(&"brute", 2, 8.0, 10.0, NEAR_LEFT, "wall"),
			group(&"brute", 2, 14.0, 10.0, NEAR_RIGHT, "gate"),
			group(&"runner", 16, 18.0, 0.5, [], "any", 2),
		], 1, 2),
		# 6. A swarm of runners.
		wave(50, 8.0, [
			group(&"runner", 12, 0.0, 0.45, AVENUE, "gate", 3),
			group(&"walker", 14, 2.0, 1.0, NEAR_LEFT + NEAR_RIGHT, "any"),
			group(&"runner", 10, 14.0, 0.45, CROSS, "wall", 2),
			group(&"brute", 4, 16.0, 6.0, NEAR_RIGHT, "gate"),
			group(&"runner", 16, 28.0, 0.4, [], "any", 2),
		], 2, 2, "wave_hint_swarm"),
		# 7. A heavy push.
		wave(54, 9.0, [
			group(&"brute", 4, 0.0, 6.0, NEAR_RIGHT + ["cross_right"], "gate"),
			group(&"walker", 22, 1.0, 0.8, AVENUE + CROSS, "gate"),
			group(&"walker", 12, 4.0, 1.0, NEAR_LEFT, "wall"),
			group(&"brute", 4, 12.0, 7.0, NEAR_LEFT, "wall"),
			group(&"runner", 14, 22.0, 0.5, [], "any", 2),
		], 2, 2, "wave_hint_heavy"),
		# 8. The Behemoth and its escort.
		wave(56, 9.0, [
			group(&"walker", 18, 0.0, 0.9, AVENUE + CROSS, "gate"),
			group(&"boss", 1, 6.0, 1.0, ["cross_right"], "gate"),
			group(&"walker", 12, 6.0, 1.1, NEAR_LEFT, "wall"),
			group(&"runner", 14, 18.0, 0.5, [], "any", 2),
			group(&"brute", 4, 26.0, 8.0, NEAR_RIGHT + NEAR_LEFT, "any"),
			group(&"runner", 10, 44.0, 0.5, AVENUE, "gate", 2),
		], 1, 1, "wave_hint_boss"),
	]
	siege.waves = waves
	var error: int = ResourceSaver.save(siege, "res://resources/waves/city_siege_waves.tres")
	print("city_siege_waves.tres: ", error_string(error), ", ", siege.total_zombies(), " zombies in ", siege.waves.size(), " waves")
	quit(0 if error == OK else 1)
