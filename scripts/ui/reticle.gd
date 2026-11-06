class_name AimReticle
extends Control

var aim_position: Vector2 = Vector2(-1000, -1000)
var has_target: bool = false
var target_markers: Array[Dictionary] = []
var _mono: Font = load("res://assets/fonts/IBMPlexMono-Regular.ttf")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func update_position(point: Vector2, target: bool) -> void:
	aim_position = point
	has_target = target
	queue_redraw()


func update_markers(markers: Array[Dictionary]) -> void:
	target_markers = markers
	queue_redraw()


func _draw() -> void:
	for marker in target_markers:
		var point: Vector2 = marker.position
		if point.x < 20 or point.x > size.x - 140 or point.y < 80 or point.y > size.y - 150:
			continue
		var color := Color("e8b34f")
		draw_line(point + Vector2(0, 5), point + Vector2(0, 20), color, 1.0, true)
		draw_polyline(
			PackedVector2Array(
				[
					point + Vector2(0, -6),
					point + Vector2(6, 0),
					point + Vector2(0, 6),
					point + Vector2(-6, 0),
					point + Vector2(0, -6)
				]
			),
			color,
			1.5,
			true
		)
		draw_rect(Rect2(point + Vector2(10, -16), Vector2(116, 19)), Color(0.05, 0.08, 0.06, 0.82))
		draw_string(
			_mono, point + Vector2(15, -2), marker.name, HORIZONTAL_ALIGNMENT_LEFT, 108, 10, color
		)
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
