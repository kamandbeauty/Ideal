class_name TacticalOverlay
extends Control
var battle: BattleController

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(battle) or not battle.active or battle.cameras.camera == null:
		return
	var camera: Camera3D = battle.cameras.camera
	var font: Font = UITheme.bold
	for target in battle.battlefield.targets:
		if target.health.is_destroyed or not target.required:
			continue
		var point: Vector3 = target.damage_point() + Vector3.UP * target.data.collision_size.y * 0.6
		if camera.is_position_behind(point):
			continue
		var screen: Vector2 = camera.unproject_position(point)
		if screen.x < 20 or screen.x > size.x - 20 or screen.y < 95 or screen.y > size.y - 160:
			continue
		var distance: float = camera.global_position.distance_to(target.global_position)
		var selected: bool = target == battle.selected_target
		var color: Color = UITheme.ACCENT if selected else Color(0.75, 0.79, 0.64, 0.65)
		var radius: float = clampf(1700.0 / distance, 12.0, 35.0)
		if selected:
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var corner := screen + Vector2(sx, sy) * radius
					draw_line(corner, corner - Vector2(sx * 10, 0), color, 2.0)
					draw_line(corner, corner - Vector2(0, sy * 10), color, 2.0)
			draw_string(font, screen + Vector2(-radius, -radius - 12), target.target_id.to_upper() + " / " + target.data.kind.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
			var bar := Rect2(screen.x - radius, screen.y + radius + 9, radius * 2, 4)
			draw_rect(bar, Color(0.1, 0.13, 0.10, 0.8))
			bar.size.x *= target.health.current / target.health.maximum
			draw_rect(bar, color)
			draw_string(font, screen + Vector2(-radius, radius + 32), "%d m" % roundi(battle.artillery.global_position.distance_to(target.global_position)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		else:
			draw_polyline(PackedVector2Array([screen + Vector2(0, -8), screen + Vector2(8, 0), screen + Vector2(0, 8), screen + Vector2(-8, 0), screen + Vector2(0, -8)]), color, 1.5)
	if battle.targeting.prediction_valid:
		var impact: Vector3 = battle.targeting.predicted_impact + Vector3.UP * 0.3
		if not camera.is_position_behind(impact):
			var center: Vector2 = camera.unproject_position(impact)
			if center.y > 100 and center.y < size.y - 150:
				var color := Color(0.94, 0.80, 0.49, 0.9)
				draw_arc(center, 22, 0, TAU, 40, color, 1.4, true)
				for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					draw_line(center + direction * 12, center + direction * 32, color, 1.5)
				draw_circle(center, 2, color)
				draw_string(font, center + Vector2(34, 5), "IMPACT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
