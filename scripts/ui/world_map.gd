extends Control
## The world map: five roadside towns strung along one desert highway.
##
## Every town shows what it pays, how busy it is and what it costs in reputation
## to open. Travelling saves the town you leave and opens the one you pick, so the
## empire keeps earning in both.

signal travel_requested(town_id: String)
signal closed

const ROAD := Color(0.42, 0.36, 0.3, 0.85)
const SPOTS := {
	"desert": Vector2(0.14, 0.74),
	"forest": Vector2(0.35, 0.6),
	"mountain": Vector2(0.54, 0.72),
	"coast": Vector2(0.73, 0.52),
	"highway": Vector2(0.88, 0.3),
}

var _map: Control
var _road: Line2D
var _nodes: Dictionary = {}
var _title: Label
var _subtitle: Label
var _summary: Label
var _close: Button


func _ready() -> void:
	theme = App.ui_theme
	layout_direction = App.layout_direction()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	refresh()
	_layout.call_deferred()


func open() -> void:
	visible = true
	refresh()
	Sound.play("click", -12.0)


func close() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	if _nodes.is_empty():
		return
	var profile := Game.profile
	if profile == null:
		return
	_title.text = App.t("map.title")
	_subtitle.text = App.t("map.subtitle", [App.format_number(profile.reputation())])
	var towns := 0
	for id in _nodes:
		towns += 1 if profile.visited(str(id)) else 0
	_summary.text = App.t("map.summary", [
		App.format_number(float(towns)),
		App.format_number(profile.total_income_per_minute()),
	])
	_close.text = App.t("hud.close")
	for id in _nodes:
		_refresh_node(str(id), profile)


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.9)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)

	_title = _label(30, UiTheme.TEXT, true)
	titles.add_child(_title)
	_subtitle = _label(16, UiTheme.MUTED, false)
	titles.add_child(_subtitle)

	_close = Button.new()
	_close.theme_type_variation = "GhostButton"
	_close.custom_minimum_size = Vector2(110, 44)
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(close)
	header.add_child(_close)

	_map = Control.new()
	_map.name = "MapArea"
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.resized.connect(_layout)
	column.add_child(_map)

	_road = Line2D.new()
	_road.width = 10.0
	_road.default_color = ROAD
	_road.joint_mode = Line2D.LINE_JOINT_ROUND
	_map.add_child(_road)

	for id in TownData.ORDER:
		_nodes[id] = _build_node(id)

	_summary = _label(16, UiTheme.GOLD, true)
	column.add_child(_summary)


func _build_node(id: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "Node_" + id
	panel.custom_minimum_size = Vector2(214, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UiTheme.panel_style()
	style.border_color = TownData.ground_color(id).lightened(0.25)
	style.border_width_top = 5
	panel.add_theme_stylebox_override("panel", style)
	_map.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	var name_label := _label(20, UiTheme.TEXT, true)
	name_label.text = App.t("town.%s" % id)
	column.add_child(name_label)

	var numbers := _label(14, UiTheme.MUTED, false)
	numbers.text = App.t("map.rates", [
		App.format_number(TownData.income_multiplier(id) * 100.0),
		App.format_number(TownData.traffic(id) * 100.0),
	])
	column.add_child(numbers)

	var progress := _label(14, UiTheme.ACCENT, false)
	column.add_child(progress)

	var action := Button.new()
	action.theme_type_variation = "PrimaryButton"
	action.custom_minimum_size = Vector2(0, 40)
	action.focus_mode = Control.FOCUS_NONE
	action.pressed.connect(func() -> void: _on_action(id))
	column.add_child(action)

	return {"panel": panel, "action": action, "progress": progress}


func _refresh_node(id: String, profile: Profile) -> void:
	var entry: Dictionary = _nodes[id]
	var action: Button = entry["action"]
	var progress: Label = entry["progress"]
	var state: TownState = profile.towns.get(id, null)

	if state != null:
		progress.text = App.t("map.progress", [
			App.format_number(state.completion() * 100.0),
			App.format_number(float(state.town_level())),
		])
	else:
		progress.text = App.t("map.unvisited")

	if id == profile.active_town:
		action.text = App.t("map.here")
		action.disabled = true
		return
	if not profile.unlocked(id):
		action.text = App.t("map.locked", [
			App.format_number(TownData.reputation_required(id)),
			App.format_number(profile.reputation()),
		])
		action.disabled = true
		return
	action.disabled = false
	action.text = App.t("map.travel")


func _on_action(id: String) -> void:
	if Game.profile == null or not Game.profile.unlocked(id):
		Sound.play("deny", -10.0)
		return
	Sound.play("travel", -6.0)
	App.tap(40)
	travel_requested.emit(id)


## Places the five nodes along the road. Called on every resize, so the map works
## in portrait, landscape and on a tablet.
func _layout() -> void:
	if _map == null or _nodes.is_empty():
		return
	var area := _map.size
	var points: Array[Vector2] = []
	for id in TownData.ORDER:
		var entry: Dictionary = _nodes[id]
		var panel: PanelContainer = entry["panel"]
		var spot: Vector2 = SPOTS.get(id, Vector2(0.5, 0.5))
		var size := panel.get_combined_minimum_size()
		if size.x < 2.0:
			size = Vector2(214.0, 132.0)
		panel.size = size
		var target := Vector2(area.x * spot.x, area.y * spot.y)
		panel.position = target - size * 0.5
		points.append(target)
	if _road != null:
		_road.points = PackedVector2Array(points)


func _label(font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		label.add_theme_font_override("font", load(UiTheme.FONT_BOLD))
	return label
