class_name CampaignMap
extends Control
## Painted ridge map with a tactical overlay; mission captions are Persian/RTL.
signal mission_selected(id: String)
var buttons: Dictionary = {}
var missions: Array[MissionData] = []


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
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
		var number: String = Loc.digits("%02d" % (index + 1))
		var caption: String = number + "  " + (mission.title if unlocked else Loc.t("locked"))
		if complete:
			caption += "\n" + Loc.t("campaign_star_count") % Loc.number(int(Profile.data.records.get(mission.id, {}).get("stars", 0)))
		var button: Button = UITheme.button(caption, func(): mission_selected.emit(mission.id), unlocked and not complete)
		button.disabled = not unlocked
		button.custom_minimum_size = Vector2(190, 72)
		button.add_theme_font_size_override("font_size", 17)
		add_child(button)
		buttons[mission.id] = button
	_layout()
	queue_redraw()


func _layout() -> void:
	for mission in missions:
		if buttons.has(mission.id):
			var button: Button = buttons[mission.id]
			button.position = Vector2(mission.map_position.x * maxf(1.0, size.x - 200), mission.map_position.y * maxf(1.0, size.y - 100))


func _draw() -> void:
	draw_texture_rect(UITheme.texture("hero_ridge.jpg"), Rect2(Vector2.ZERO, size), false, Color(0.62, 0.62, 0.62, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.04, 0.48))
	for x in range(0, int(size.x), 48):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.30, 0.36, 0.27, 0.28), 1)
	for y in range(0, int(size.y), 48):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.30, 0.36, 0.27, 0.28), 1)
	for contour in range(13):
		var points := PackedVector2Array()
		for step in range(80):
			var x: float = float(step) / 79.0 * size.x
			var y: float = size.y * (0.08 + contour * 0.075) + sin(x * 0.008 + contour * 0.31) * 30 + cos(x * 0.019 + contour) * 8
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.46, 0.50, 0.34, 0.30), 1.0, true)
	var road := PackedVector2Array()
	for mission in missions:
		road.append(Vector2(mission.map_position.x * maxf(1.0, size.x - 200) + 95, mission.map_position.y * maxf(1.0, size.y - 100) + 36))
	draw_polyline(road, Color(0.78, 0.64, 0.40, 0.55), 3.0, true)
	draw_string(UITheme.bold, Vector2(24, 38), Loc.t("campaign_sector"), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 48, 19, UITheme.TEXT, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_RTL)
	draw_string(UITheme.regular, Vector2(24, size.y - 22), Loc.t("campaign_coords"), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 48, 15, UITheme.MUTED, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_RTL)
	draw_line(Vector2(42, 40), Vector2(42, 84), UITheme.ACCENT, 2)
	draw_string(UITheme.bold, Vector2(18, 32), Loc.t("north"), HORIZONTAL_ALIGNMENT_CENTER, 48, 15, UITheme.ACCENT, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_RTL)
