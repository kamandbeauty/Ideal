class_name RunnerEntity
extends Node2D

enum Kind { ROCK, LOG, COIN }
var kind := Kind.ROCK
var active := false
var collected := false
var speed := 420.0


func activate(entity_kind: Kind, at: Vector2, move_speed: float) -> void:
	kind = entity_kind
	position = at
	speed = move_speed
	active = true
	collected = false
	visible = true
	set_process(true)
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not active:
		return
	position.x -= speed * delta
	if position.x < -100:
		deactivate()


func collision_rect() -> Rect2:
	match kind:
		Kind.COIN:
			return Rect2(position - Vector2(22, 22), Vector2(44, 44))
		Kind.LOG:
			return Rect2(position + Vector2(-48, -48), Vector2(96, 48))
		_:
			return Rect2(position + Vector2(-37, -64), Vector2(74, 64))


func collect() -> void:
	if kind == Kind.COIN and not collected:
		collected = true
		deactivate()


func _draw() -> void:
	match kind:
		Kind.COIN:
			draw_circle(Vector2.ZERO, 23, Color("#F9C74F"))
			draw_circle(Vector2.ZERO, 15, Color("#F6A832"))
			draw_string(
				ThemeDB.fallback_font,
				Vector2(-7, 8),
				"R",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				21,
				Color.WHITE
			)
		Kind.LOG:
			draw_rect(Rect2(-48, -42, 96, 42), Color("#70452D"), true)
			draw_circle(Vector2(44, -21), 21, Color("#B97845"))
			draw_circle(Vector2(44, -21), 11, Color("#70452D"), false, 4)
		Kind.ROCK:
			draw_colored_polygon(
				PackedVector2Array(
					[
						Vector2(-37, 0),
						Vector2(-29, -44),
						Vector2(-5, -65),
						Vector2(28, -51),
						Vector2(38, 0)
					]
				),
				Color("#66706F")
			)
			draw_line(Vector2(-20, -35), Vector2(18, -45), Color("#8D9997"), 5)
