class_name TargetLock
extends Control
## Green lock brackets on the nearest hostile. Drawn in viewport space so the
## brackets line up with the 3D camera, even when the HUD root is inset for a cutout.

const LOCK_COLOR := Color(0.46, 1.0, 0.52, 0.9)

var screen_point: Vector2 = Vector2.ZERO
var range_m: float = 0.0
var locked: bool = false
var pulse: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func bracket_size(distance_m: float) -> float:
	## Brackets shrink with range, but stay between 26 and 84 px so they are always readable.
	return clampf(900.0 / maxf(distance_m, 1.0), 26.0, 84.0)


func set_lock(point: Vector2, distance_m: float, on: bool) -> void:
	screen_point = point
	range_m = distance_m
	locked = on
	queue_redraw()


func _process(delta: float) -> void:
	if not locked:
		return
	pulse += delta
	queue_redraw()


func _draw() -> void:
	if not locked:
		return
	var half: float = bracket_size(range_m) * 0.5 * (1.0 + 0.08 * sin(pulse * 6.0))
	var arm: float = half * 0.45
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip: Vector2 = screen_point + corner * half
		draw_line(tip, tip - Vector2(corner.x * arm, 0.0), LOCK_COLOR, 3.0, true)
		draw_line(tip, tip - Vector2(0.0, corner.y * arm), LOCK_COLOR, 3.0, true)
	draw_circle(screen_point, 2.5, LOCK_COLOR)
