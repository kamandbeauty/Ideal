class_name TestContext
extends RefCounted
var checks: int = 0
var failures: Array[String] = []
var suite: String = ""
var tree: SceneTree

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(suite + ": " + message)
		push_error("FAIL " + suite + ": " + message)

func near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (got %.8f, expected %.8f ± %.8f)" % [message, actual, expected, tolerance])

func equal(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (got %s, expected %s)" % [message, str(actual), str(expected)])
