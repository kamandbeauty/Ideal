class_name AimReticle
extends Control

var aim_position: Vector2 = Vector2(-1000, -1000)
var has_target: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func update_position(point: Vector2, target: bool) -> void:
	aim_position = point
	has_target = target
	queue_redraw()


func _draw() -> void:
	if (
		aim_position.x < 0
		or aim_position.y < 0
		or aim_position.x > size.x
		or aim_position.y > size.y
	):
		return
	var color := Color("efbd60") if not has_target else Color("ff7957")
	var center := aim_position
	draw_arc(center, 25.0, 0.0, TAU, 48, Color(color, 0.62), 1.5, true)
	draw_arc(center, 17.0, deg_to_rad(35), deg_to_rad(145), 24, color, 2.0, true)
	draw_arc(center, 17.0, deg_to_rad(215), deg_to_rad(325), 24, color, 2.0, true)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + direction * 27.0, center + direction * 37.0, color, 2.0, true)
	draw_circle(center, 2.5, color)
