class_name TestCase
extends RefCounted
## Minimal assertion helper for the headless suites.

const TRACE_PATH := "res://documentation/qa/run-trace.txt"

var suite_name := ""
var checks := 0
var failures: Array[String] = []


## Leaves one flushed line on disk. stdout is buffered when CI pipes it, so a suite
## that hangs takes its prints with it - but not this file.
static func mark(text: String) -> void:
	var file := FileAccess.open(TRACE_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(TRACE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(text)
	file.flush()


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
