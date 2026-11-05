class_name CampaignMap
extends Control
signal mission_selected(id: String)
var buttons: Dictionary = {}
var missions: Array[MissionData] = []

func _ready() -> void:
	custom_minimum_size = Vector2(650, 470)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for id in ["sr01", "sr02", "sr03", "sr04", "sr05"]:
		missions.append(load("res://resources/missions/%s.tres" % id))
	resized.connect(_layout)
	refresh()

func refresh() -> void:
	for child in get_children():
		child.queue_free()
	buttons.clear()
	for index in range(missions.size()):
		var mission: MissionData = missions[index]
		var unlocked: bool = mission.id in Profile.data.unlocked
		var complete: bool = mission.id in Profile.data.completed
		var caption: String = "%02d  %s" % [index + 1, mission.title] if unlocked else "%02d  LOCKED" % (index + 1)
		if complete:
			caption += "\n%d / 3 STARS" % int(Profile.data.records.get(mission.id, {}).get("stars", 0))
		var button: Button = UITheme.button(caption, func(): mission_selected.emit(mission.id), unlocked and not complete)
		button.disabled = not unlocked
		button.custom_minimum_size = Vector2(174, 66)
		button.add_theme_font_size_override("font_size", 17)
		add_child(button)
		buttons[mission.id] = button
	_layout()
	queue_redraw()

func _layout() -> void:
	for mission in missions:
		if buttons.has(mission.id):
			var button: Button = buttons[mission.id]
			button.position = Vector2(mission.map_position.x * maxf(1.0, size.x - 180), mission.map_position.y * maxf(1.0, size.y - 90))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.14, 0.115))
	for x in range(0, int(size.x), 48):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.24, 0.29, 0.22, 0.32), 1)
	for y in range(0, int(size.y), 48):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.24, 0.29, 0.22, 0.32), 1)
	for contour in range(13):
		var points := PackedVector2Array()
		for step in range(80):
			var x: float = float(step) / 79.0 * size.x
			var y: float = size.y * (0.08 + contour * 0.075) + sin(x * 0.008 + contour * 0.31) * 30 + cos(x * 0.019 + contour) * 8
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.36, 0.40, 0.28, 0.35), 1.0, true)
	var road := PackedVector2Array()
	for mission in missions:
		road.append(Vector2(mission.map_position.x * maxf(1.0, size.x - 180) + 87, mission.map_position.y * maxf(1.0, size.y - 90) + 33))
	draw_polyline(road, Color(0.62, 0.54, 0.36, 0.45), 3.0, true)
	draw_string(UITheme.bold, Vector2(24, 34), "SABLE RIDGE / TACTICAL SECTOR 07", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UITheme.MUTED)
	draw_string(UITheme.regular, Vector2(24, size.y - 22), "34° 18′ N   41° 07′ E     •     OFFLINE CAMPAIGN", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.MUTED)
	draw_line(Vector2(size.x - 42, 36), Vector2(size.x - 42, 80), UITheme.ACCENT, 2)
	draw_string(UITheme.bold, Vector2(size.x - 48, 29), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITheme.ACCENT)
