class_name ForestBackground
extends Node2D
var scroll := 0.0
var playing := false
var speed := 200.0


func _process(delta: float) -> void:
	if playing:
		scroll = fmod(scroll + speed * delta, 360.0)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 720, 1280), Color("#8FD8E8"))
	draw_circle(Vector2(590, 170), 65, Color("#FFE08A"))
	# distant hills
	for i in range(-1, 5):
		var x: float = i * 240.0 - fmod(scroll * 0.18, 240.0)
		draw_circle(Vector2(x, 820), 220, Color("#72B78B"))
	# tree layers
	for i in range(-1, 6):
		var x2: float = i * 170.0 - fmod(scroll * 0.42, 170.0)
		draw_rect(Rect2(x2 + 63, 600, 27, 400), Color("#6D4932"))
		draw_circle(Vector2(x2 + 75, 600), 105, Color("#3D8E62"))
		draw_circle(Vector2(x2 + 30, 660), 80, Color("#4EA66D"))
	# shrubs and ground
	for i in range(-1, 9):
		var bx: float = i * 100.0 - fmod(scroll * 0.75, 100.0)
		draw_circle(Vector2(bx, 970), 50, Color("#276A4A"))
	draw_rect(Rect2(0, 980, 720, 300), Color("#795238"))
	draw_rect(Rect2(0, 980, 720, 28), Color("#5FB04C"))
	for i in range(-1, 14):
		var gx: float = i * 64.0 - fmod(scroll, 64.0)
		draw_line(Vector2(gx, 1035), Vector2(gx + 28, 1058), Color("#5F402D"), 7)
