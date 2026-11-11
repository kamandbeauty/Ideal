class_name Menus
extends CanvasLayer
## Title, settings, pause and result screens. Ordinary Controls: these are the
## only places where taps go through Godot's GUI instead of the touch router.

signal play_requested
signal resume_requested
signal restart_requested
signal menu_requested

var screen: String = ""
var came_from: String = "main"
var dim: ColorRect
var holder: CenterContainer
var result_victory: bool = false
var result_stats: Dictionary = {}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.025, 0.55)
	add_child(dim)
	holder = CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.theme = UITheme.theme()
	add_child(holder)
	Events.language_changed.connect(_on_language_changed)
	hide_all()


func _on_language_changed() -> void:
	UITheme.refresh_fonts()
	if screen != "":
		_show(screen)


func hide_all() -> void:
	screen = ""
	dim.visible = false
	holder.visible = false
	_clear()


func is_open() -> bool:
	return screen != ""


func _clear() -> void:
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()


func _show(name: String) -> void:
	screen = name
	_clear()
	dim.visible = true
	holder.visible = true
	match name:
		"main":
			dim.color = Color(0.02, 0.02, 0.025, 0.42)
			_build_main()
		"settings":
			dim.color = Color(0.02, 0.02, 0.025, 0.7)
			_build_settings()
		"pause":
			dim.color = Color(0.02, 0.02, 0.025, 0.62)
			_build_pause()
		"result":
			dim.color = Color(0.03, 0.01, 0.01, 0.68) if not result_victory else Color(0.01, 0.03, 0.02, 0.6)
			_build_result()


func show_main() -> void:
	_show("main")


func show_pause() -> void:
	_show("pause")


func show_settings(from: String) -> void:
	came_from = from
	_show("settings")


func show_result(victory: bool, stats: Dictionary) -> void:
	result_victory = victory
	result_stats = stats
	_show("result")


func _panel(width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	holder.add_child(panel)
	return column


func _heading(text: String, size: int, color: Color) -> Label:
	var label: Label = UITheme.label(text, size, color, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _text(text: String, size: int = 22, color: Color = UITheme.MUTED) -> Label:
	var label: Label = UITheme.label(text, size, color, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _build_main() -> void:
	var column: VBoxContainer = _panel(560.0)
	column.add_child(_heading(Loc.t("title"), 76, UITheme.AMBER))
	column.add_child(_heading(Loc.t("subtitle"), 30, UITheme.TEXT))
	column.add_child(_text(Loc.t("tagline")))
	column.add_child(_spacer(8))
	column.add_child(UITheme.button(Loc.t("play"), func() -> void: play_requested.emit(), true))
	column.add_child(UITheme.button(Loc.t("settings"), func() -> void: show_settings("main")))
	column.add_child(UITheme.button("English" if Loc.language == "fa" else "فارسی", _toggle_language))
	var best: int = Profile.data.stats.best_wave
	if best > 0:
		column.add_child(_text(Loc.t("best_wave", [best]), 20))


func _build_pause() -> void:
	var column: VBoxContainer = _panel(480.0)
	column.add_child(_heading(Loc.t("paused"), 50, UITheme.TEXT))
	column.add_child(_spacer(4))
	column.add_child(UITheme.button(Loc.t("resume"), func() -> void: resume_requested.emit(), true))
	column.add_child(UITheme.button(Loc.t("restart"), func() -> void: restart_requested.emit()))
	column.add_child(UITheme.button(Loc.t("settings"), func() -> void: show_settings("pause")))
	column.add_child(UITheme.button(Loc.t("main_menu"), func() -> void: menu_requested.emit()))


func _build_result() -> void:
	var column: VBoxContainer = _panel(640.0)
	var color: Color = UITheme.GREEN if result_victory else UITheme.RED
	column.add_child(_heading(Loc.t("victory_title" if result_victory else "defeat_title"), 54, color))
	column.add_child(_text(Loc.t("victory_text" if result_victory else "defeat_text"), 22, UITheme.TEXT))
	column.add_child(_spacer(6))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	var rows: Array = [
		["waves_held", "%s / %s" % [Loc.number(int(result_stats.get("waves_cleared", 0))), Loc.number(int(result_stats.get("waves_total", 0)))]],
		["kills", Loc.number(int(result_stats.get("kills", 0)))],
		["headshots", Loc.number(int(result_stats.get("headshots", 0)))],
		["accuracy", Loc.percent(float(result_stats.get("accuracy", 0.0)))],
		["time", Loc.clock(float(result_stats.get("time", 0.0)))],
		["wall_left", Loc.percent(float(result_stats.get("wall_left", 0.0)))],
	]
	for row: Array in rows:
		var name_label: Label = UITheme.label(Loc.t(row[0]), 22, UITheme.MUTED, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_label: Label = UITheme.label(row[1], 26, UITheme.TEXT, true)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		grid.add_child(value_label)
	column.add_child(grid)
	column.add_child(_spacer(6))
	column.add_child(UITheme.button(Loc.t("restart"), func() -> void: restart_requested.emit(), true))
	column.add_child(UITheme.button(Loc.t("main_menu"), func() -> void: menu_requested.emit()))


func _build_settings() -> void:
	var column: VBoxContainer = _panel(700.0)
	column.add_child(_heading(Loc.t("settings"), 44, UITheme.TEXT))
	column.add_child(_choice_row("language", Loc.t("language_name"), _toggle_language))
	column.add_child(_slider_row("sensitivity", 0.3, 2.5, 0.05))
	column.add_child(_check_row("invert_y"))
	column.add_child(_check_row("left_handed"))
	column.add_child(_slider_row("master_volume", 0.0, 1.0, 0.05))
	column.add_child(_slider_row("sfx_volume", 0.0, 1.0, 0.05))
	column.add_child(_slider_row("music_volume", 0.0, 1.0, 0.05))
	column.add_child(_choice_row("quality", Loc.t("quality_" + String(Profile.setting("quality"))), _cycle_quality))
	column.add_child(_check_row("show_fps"))
	column.add_child(_spacer(4))
	column.add_child(UITheme.button(Loc.t("back"), func() -> void: _show(came_from), true))


func _spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	return node


func _row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var label: Label = UITheme.label(Loc.t(key), 22, UITheme.TEXT, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _slider_row(key: String, low: float, high: float, step: float) -> HBoxContainer:
	var row: HBoxContainer = _row(key)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = Profile.setting(key)
	slider.custom_minimum_size = Vector2(280, 40)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(value: float) -> void: Profile.set_setting(key, value))
	row.add_child(slider)
	return row


func _check_row(key: String) -> HBoxContainer:
	var row: HBoxContainer = _row(key)
	var toggle := CheckButton.new()
	toggle.button_pressed = Profile.setting(key)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(func(pressed: bool) -> void: Profile.set_setting(key, pressed))
	row.add_child(toggle)
	return row


func _choice_row(key: String, value: String, action: Callable) -> HBoxContainer:
	var row: HBoxContainer = _row(key)
	var button: Button = UITheme.button(value, action)
	button.custom_minimum_size = Vector2(280, 52)
	row.add_child(button)
	return row


func _toggle_language() -> void:
	Profile.set_setting("language", "en" if Loc.language == "fa" else "fa")


func _cycle_quality() -> void:
	var choices: Array[String] = Profile.QUALITY_CHOICES
	var index: int = choices.find(String(Profile.setting("quality")))
	Profile.set_setting("quality", choices[(index + 1) % choices.size()])
	_show("settings")
