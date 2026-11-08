class_name Haptics
extends RefCounted
## Vibration, honouring the save's switch. Two strengths are all a match-3 needs: a light tick for a
## tap that did something, and a heavier one for a reject or a reward.
##
## Godot only vibrates on a handheld; on desktop and in the headless suites every call here is a no-op,
## which is why nothing has to guard its call sites with a platform check.

const TICK_MS := 12
const THUMP_MS := 32

static var enabled := true

static func apply_settings(save: SaveData) -> void:
	enabled = save == null or save.haptics_on

static func tick() -> void:
	_buzz(TICK_MS)

static func thump() -> void:
	_buzz(THUMP_MS)

static func _buzz(milliseconds: int) -> void:
	if not enabled:
		return
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		return
	Input.vibrate_handheld(milliseconds)
