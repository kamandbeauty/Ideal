class_name TestCase
extends RefCounted
## Minimal assertion helper for the headless suites.

var suite_name := ""
var checks := 0
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [suite_name, message])


func equal(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if actual != expected:
		failures.append(
			"%s: %s (expected %s, got %s)" % [suite_name, message, str(expected), str(actual)]
		)


func not_equal(actual: Variant, unexpected: Variant, message: String) -> void:
	checks += 1
	if actual == unexpected:
		failures.append("%s: %s (unexpected %s)" % [suite_name, message, str(unexpected)])


func almost(actual: float, expected: float, message: String, epsilon: float = 0.0001) -> void:
	checks += 1
	if absf(actual - expected) > epsilon:
		failures.append(
			"%s: %s (expected %.4f, got %.4f)" % [suite_name, message, expected, actual]
		)


func fail(message: String) -> void:
	checks += 1
	failures.append("%s: %s" % [suite_name, message])
