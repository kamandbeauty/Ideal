class_name DayCycle
extends Node
## A slow, controlled day: sun path, sky colours, fog and the night signs.
## One directional light and one fill light are all it drives, so mobile stays
## inside budget.

const DAY_SECONDS := 720.0
const START_TIME := 0.29

var time := START_TIME
var _view: TownView


func setup(view: TownView) -> void:
	_view = view
	apply()


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	set_time(time + delta / DAY_SECONDS)


func set_time(value: float) -> void:
	time = fposmod(value, 1.0)
	apply()


func apply() -> void:
	if _view != null:
		_view.apply_time(time)


func elevation() -> float:
	return sin(time * TAU)


func phase() -> String:
	if time < 0.12:
		return "morning"
	if time < 0.34:
		return "noon"
	if time < 0.5:
		return "evening"
	return "night"


func is_night() -> bool:
	return elevation() < -0.05
