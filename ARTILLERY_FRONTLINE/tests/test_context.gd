class_name TestContext
extends RefCounted
## Assertions and scene helpers shared by every suite.

var checks: int = 0
var failures: Array[String] = []
var suite: String = ""
var per_suite: Dictionary = {}
var tree: SceneTree


func check(condition: bool, message: String) -> void:
	checks += 1
	per_suite[suite] = int(per_suite.get(suite, 0)) + 1
	if not condition:
		failures.append(suite + ": " + message)
		push_error("FAIL " + suite + ": " + message)


func near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (got %.5f, expected %.5f ± %.5f)" % [message, actual, expected, tolerance])


func equal(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (got %s, expected %s)" % [message, str(actual), str(expected)])


func frames(count: int = 1) -> void:
	for index: int in count:
		await tree.process_frame


func physics_frames(count: int = 1) -> void:
	for index: int in count:
		await tree.physics_frame


## A fresh siege level under the scene root, carrying the waves of `stage`
## (counted from 0; the scene itself carries the first). Free it with `discard`.
## (No game class is named in this file: the runner compiles it before the
## autoloads exist, and the game scripts need those to compile.)
func make_level(stage: int = 0) -> Node:
	tree.root.get_node("Profile").persist = false
	var level: Node = (load("res://scenes/levels/city_siege.tscn") as PackedScene).instantiate()
	if stage > 0:
		level.set("stage", stage)
		level.set("wave_set", load("res://resources/waves/stage_%d_waves.tres" % (stage + 1)))
	tree.root.add_child(level)
	return level


func discard(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	Engine.time_scale = 1.0
	await tree.process_frame
	await tree.process_frame


## Advances the gameplay systems of a level by `seconds` without waiting for
## real frames, so a whole siege can be simulated in a moment.
func simulate(level: Node, seconds: float, step: float = 1.0 / 30.0) -> void:
	var left: float = seconds
	while left > 0.0:
		var delta: float = minf(step, left)
		level.director._physics_process(delta)
		level.horde._physics_process(delta)
		level.defense._physics_process(delta)
		level._process(delta)
		left -= delta
