class_name ManualClock
extends RefCounted

var _now: int

func _init(start_unix: int = 1700000000) -> void:
	_now = start_unix

func now_unix() -> int:
	return _now

func advance(seconds: int) -> void:
	_now += seconds
