class_name RubyPlayer
extends Node2D

signal hit

const GRAVITY := 2400.0
const JUMP_VELOCITY := -900.0
const GROUND_Y := 980.0
var velocity_y := 0.0
var jumps_used := 0
var active := false
var skin_color := Color("#E85D3F")
var run_time := 0.0


func reset_player() -> void:
	position = Vector2(145, GROUND_Y)
	velocity_y = 0.0
	jumps_used = 0
	active = true
	visible = true
	skin_color = Color(
		SkinManager.get_skin(str(SaveManager.data.selected_skin)).get("color", "#E85D3F")
	)
	queue_redraw()


func jump() -> bool:
	if not active or jumps_used >= 2:
		return false
	velocity_y = JUMP_VELOCITY if jumps_used == 0 else JUMP_VELOCITY * 0.88
	jumps_used += 1
	AudioManager.play_sfx("jump")
	queue_redraw()
	return true


func _physics_process(delta: float) -> void:
	if not active:
		return
	run_time += delta
	velocity_y += GRAVITY * delta
	position.y += velocity_y * delta
	if position.y >= GROUND_Y:
		position.y = GROUND_Y
		velocity_y = 0.0
		jumps_used = 0
	queue_redraw()


func collision_rect() -> Rect2:
	return Rect2(position + Vector2(-32, -82), Vector2(64, 82))


func take_hit() -> void:
	if not active:
		return
	active = false
	AudioManager.vibrate(45)
	queue_redraw()
	hit.emit()


func _draw() -> void:
	# Replaceable vector placeholder: fox body, head, ears, tail and animation cues.
	var bob := sin(run_time * 15.0) * 4.0 if active and position.y >= GROUND_Y - 1 else 0.0
	draw_circle(Vector2(-31, -34 + bob), 30, skin_color.darkened(0.12))
	draw_circle(Vector2(0, -48 + bob), 37, skin_color)
	var head_y := -84.0 + bob
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(-29, head_y - 17), Vector2(-20, head_y - 57), Vector2(-4, head_y - 27)]
		),
		skin_color
	)
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(29, head_y - 17), Vector2(20, head_y - 57), Vector2(4, head_y - 27)]
		),
		skin_color
	)
	draw_circle(Vector2(0, head_y), 34, skin_color)
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(-25, head_y + 4), Vector2(0, head_y + 31), Vector2(25, head_y + 4)]
		),
		Color("#FFF0CF")
	)
	draw_circle(Vector2(-12, head_y - 5), 4, Color("#252238"))
	draw_circle(Vector2(12, head_y - 5), 4, Color("#252238"))
	draw_circle(Vector2(0, head_y + 13), 5, Color("#252238"))
	var leg := 8.0 if int(run_time * 10.0) % 2 == 0 else -8.0
	draw_line(Vector2(-15, -17 + bob), Vector2(-15 + leg, 0), skin_color.darkened(0.2), 12)
	draw_line(Vector2(15, -17 + bob), Vector2(15 - leg, 0), skin_color.darkened(0.2), 12)
	if jumps_used == 2:
		draw_arc(Vector2.ZERO, 55, 0, TAU, 24, Color(1, 1, 1, 0.45), 5)
