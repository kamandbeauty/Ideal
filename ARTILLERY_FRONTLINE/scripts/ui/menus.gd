class_name Menus
extends CanvasLayer
## Title, settings, pause and result screens. Ordinary Controls: these are the
## only places where taps go through Godot's GUI instead of the touch router.
## Every screen is laid out for the reading direction of the language in use.
## Buttons and the rows of the settings screen are 88 canvas units high and
## its choice buttons 84 (7.4 and 7.0 mm on a 6.5-inch phone).

signal play_requested
signal resume_requested
signal restart_requested
signal menu_requested

const FADE_TIME: float = 0.16
## A button that asks to be pressed twice stays armed this long.
const CONFIRM_TIME: float = 3.0

var screen: String = ""
var came_from: String = "main"
var dim: ColorRect
var holder: Control
var result_victory: bool = false
var result_stats: Dictionary = {}
## The match just finished went further than any before it.
var result_record: bool = false
## What the pause screen says about the match in progress: wave, waves, wall, gate.
var pause_status: Dictionary = {}
var fade: Tween
var armed: Button = null
var armed_left: float = 0.0
var armed_text: String = ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.025, 0.55)
	add_child(dim)
	holder = Control.new()
	holder.name = "Screen"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.theme = UITheme.theme()
	add_child(holder)
	Events.language_changed.connect(_on_language_changed)
	hide_all()


func _process(delta: float) -> void:
	if armed != null:
		armed_left -= delta
		if armed_left <= 0.0:
			_disarm()


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
	armed = null
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()


func _show(name: String) -> void:
	screen = name
	_clear()
	dim.visible = true
	holder.visible = true
	holder.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	match name:
		"main":
			# The title screen leaves the street in view: only the side the column stands on is darkened.
			dim.color = Color(0.02, 0.02, 0.025, 0.18)
			_build_main()
		"settings":
			dim.color = Color(0.02, 0.02, 0.025, 0.74)
			_build_settings()
		"pause":
			dim.color = Color(0.02, 0.02, 0.025, 0.66)
			_build_pause()
		"result":
			dim.color = Color(0.05, 0.01, 0.01, 0.72) if not result_victory else Color(0.01, 0.035, 0.02, 0.66)
			_build_result()
	if fade != null and fade.is_valid():
		fade.kill()
	holder.modulate.a = 0.0
	fade = create_tween()
	fade.tween_property(holder, "modulate:a", 1.0, FADE_TIME)


func show_main() -> void:
	_show("main")


func show_pause(status: Dictionary = {}) -> void:
	if not status.is_empty():
		pause_status = status
	_show("pause")


func show_settings(from: String) -> void:
	came_from = from
	_show("settings")


func show_result(victory: bool, stats: Dictionary, record: bool = false) -> void:
	result_victory = victory
	result_stats = stats
	result_record = record
	_show("result")


# -- Building blocks -----------------------------------------------------------------
## Clear space at the (left, right) of the screen: the HUD's margins, so menus clear the same cut-outs.
func _side_margins() -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var window := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	return Hud.margins_for(view, Hud.insets_for(view, window, DisplayServer.get_display_safe_area()))


func _frame(extra: float = 0.0) -> MarginContainer:
	var margins: Vector2 = _side_margins()
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("margin_left", int(margins.x + extra))
	frame.add_theme_constant_override("margin_right", int(margins.y + extra))
	frame.add_theme_constant_override("margin_top", 16)
	frame.add_theme_constant_override("margin_bottom", 16)
	holder.add_child(frame)
	return frame


## A panel in the middle of the screen with a column inside it.
func _panel(width: float) -> VBoxContainer:
	var frame: MarginContainer = _frame()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	frame.add_child(panel)
	return column


func _heading(text: String, size: int, color: Color, centered: bool = true) -> Label:
	var label: Label = UITheme.label(text, size, color, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	return label


func _text(text: String, size: int = UITheme.BODY, color: Color = UITheme.MUTED, centered: bool = true) -> Label:
	var label: Label = UITheme.label(text, size, color, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## A button that must be pressed twice: the first press arms it and says so.
func _confirm_button(text: String, action: Callable) -> Button:
	var button: Button = UITheme.button(text, func() -> void: pass)
	button.pressed.connect(func() -> void:
		if armed == button:
			_disarm()
			action.call()
		else:
			_disarm()
			armed = button
			armed_text = text
			armed_left = CONFIRM_TIME
			button.text = Loc.t("confirm")
			UITheme.paint_button(button, "danger"))
	return button


func _disarm() -> void:
	if armed != null and is_instance_valid(armed):
		armed.text = armed_text
		UITheme.paint_button(armed, "plain")
	armed = null


# -- Title -----------------------------------------------------------------------------
func _build_main() -> void:
	var shade := MenuWidgets.Shade.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(shade)
	var frame: MarginContainer = _frame(26.0)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(560.0, 0.0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 10)
	frame.add_child(column)
	column.add_child(MenuWidgets.Stripes.new())
	column.add_child(_heading(Loc.t("title"), 84, UITheme.AMBER, false))
	column.add_child(_heading(Loc.t("subtitle"), 32, UITheme.TEXT, false))
	column.add_child(_text(Loc.t("tagline"), 24, UITheme.MUTED, false))
	column.add_child(_spacer(10))
	column.add_child(UITheme.button(Loc.t("play"), func() -> void: play_requested.emit(), "accent", "ui_start"))
	column.add_child(UITheme.button(Loc.t("settings"), func() -> void: show_settings("main")))
	column.add_child(UITheme.button("English" if Loc.language == "fa" else "فارسی", _toggle_language))
	column.add_child(_spacer(4))
	var totals: Dictionary = Profile.data.stats
	if int(totals.matches) > 0:
		var record: String = Loc.t("best_wave", [int(totals.best_wave)]) if int(totals.best_wave) > 0 else ""
		var career: String = Loc.t("career", [int(totals.matches), int(totals.victories), int(totals.kills)])
		column.add_child(_text(record + ("\n" if record != "" else "") + career, 22, UITheme.TEXT, false))
	column.add_child(_text(Loc.t("version", [Loc.number(String(ProjectSettings.get_setting("application/config/version", "")))]), 20, UITheme.MUTED, false))


# -- Pause -----------------------------------------------------------------------------
func _build_pause() -> void:
	var column: VBoxContainer = _panel(580.0)
	column.add_child(MenuWidgets.Stripes.new())
	column.add_child(_heading(Loc.t("paused"), 54, UITheme.TEXT))
	if not pause_status.is_empty():
		# Where the match stands, so RESTART and MAIN MENU are weighed against what would be lost.
		var parts: PackedStringArray = []
		if int(pause_status.get("wave", 0)) > 0:
			parts.append(Loc.t("wave", [int(pause_status.wave), int(pause_status.get("waves", 0))]))
		parts.append("%s %s" % [Loc.t("wall"), Loc.percent(float(pause_status.get("wall", 1.0)))])
		parts.append("%s %s" % [Loc.t("gate"), Loc.percent(float(pause_status.get("gate", 1.0)))])
		column.add_child(_text("   ·   ".join(parts), 24, UITheme.MUTED))
	column.add_child(_spacer(2))
	column.add_child(UITheme.button(Loc.t("resume"), func() -> void: resume_requested.emit(), "accent"))
	column.add_child(_confirm_button(Loc.t("restart"), func() -> void: restart_requested.emit()))
	column.add_child(UITheme.button(Loc.t("settings"), func() -> void: show_settings("pause")))
	column.add_child(_confirm_button(Loc.t("main_menu"), func() -> void: menu_requested.emit()))


# -- Result ----------------------------------------------------------------------------
func _build_result() -> void:
	var column: VBoxContainer = _panel(1080.0)
	var color: Color = UITheme.GREEN if result_victory else UITheme.RED
	column.add_child(MenuWidgets.Stripes.new())
	column.add_child(_heading(Loc.t("victory_title" if result_victory else "defeat_title"), 60, color))
	var story: String = Loc.t("victory_text" if result_victory else "defeat_text")
	if not result_victory and int(result_stats.get("wave", 0)) > 0:
		story += "  " + Loc.t("fell_in_wave", [int(result_stats.wave)])
	column.add_child(_text(story, 24, UITheme.TEXT))
	if result_record:
		column.add_child(_heading(Loc.t("new_record"), 24, UITheme.AMBER))
	column.add_child(MenuWidgets.Rule.new(8.0))
	var first: Array = [
		["waves_held", "%s / %s" % [Loc.number(int(result_stats.get("waves_cleared", 0))), Loc.number(int(result_stats.get("waves_total", 0)))]],
		["time", Loc.clock(float(result_stats.get("time", 0.0)))],
		["wall_left", Loc.percent(float(result_stats.get("wall_left", 0.0)))],
		["gate_left", Loc.percent(float(result_stats.get("gate_left", 0.0)))],
		["accuracy", Loc.percent(float(result_stats.get("accuracy", 0.0)))],
	]
	var second: Array = [
		["kills", Loc.number(int(result_stats.get("kills", 0)))],
		["headshots", Loc.number(int(result_stats.get("headshots", 0)))],
		["special_kills", Loc.number(int(result_stats.get("special_kills", 0)))],
		["blast_kills", Loc.number(int(result_stats.get("blast_kills", 0)))],
		["explosives_used", "%s + %s" % [Loc.number(int(result_stats.get("rockets", 0))), Loc.number(int(result_stats.get("grenades", 0)))]],
	]
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 56)
	columns.add_child(_stat_column(first))
	columns.add_child(_stat_column(second))
	column.add_child(columns)
	column.add_child(MenuWidgets.Rule.new(8.0))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	var again: Button = UITheme.button(Loc.t("restart"), func() -> void: restart_requested.emit(), "accent", "ui_start")
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var leave: Button = UITheme.button(Loc.t("main_menu"), func() -> void: menu_requested.emit())
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(again)
	buttons.add_child(leave)
	column.add_child(buttons)


func _stat_column(rows: Array) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	for row: Array in rows:
		var line := HBoxContainer.new()
		var name_label: Label = UITheme.label(Loc.t(row[0]), 24, UITheme.MUTED, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var value_label: Label = UITheme.label(row[1], 30, UITheme.TEXT, true)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(name_label)
		line.add_child(value_label)
		column.add_child(line)
	return column


# -- Settings --------------------------------------------------------------------------
func _build_settings() -> void:
	var column: VBoxContainer = _panel(1200.0)
	column.add_child(_heading(Loc.t("settings"), 36, UITheme.TEXT))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 52)
	var controls: VBoxContainer = _group("group_controls")
	controls.add_child(_slider_row("sensitivity", 0.3, 2.5, 0.05))
	controls.add_child(_check_row("invert_y"))
	controls.add_child(_check_row("left_handed"))
	controls.add_child(_check_row("screen_shake"))
	controls.add_child(_choice_row("language", ["فارسی", "English"], Profile.LANGUAGES.find(Loc.language),
		func(index: int) -> void: Profile.set_setting("language", Profile.LANGUAGES[index]), 300.0))
	var sound: VBoxContainer = _group("group_sound")
	sound.add_child(_slider_row("master_volume", 0.0, 1.0, 0.05))
	sound.add_child(_slider_row("sfx_volume", 0.0, 1.0, 0.05))
	sound.add_child(_slider_row("music_volume", 0.0, 1.0, 0.05))
	# Four words do not fit beside a label on a phone, so the quality choices sit under their own heading.
	sound.add_child(_group_title("group_display"))
	var qualities: Array = []
	for choice: String in Profile.QUALITY_CHOICES:
		qualities.append(Loc.t("quality_" + choice))
	var quality := MenuWidgets.Choices.new(qualities, Profile.QUALITY_CHOICES.find(String(Profile.setting("quality"))))
	quality.chosen.connect(func(index: int) -> void: Profile.set_setting("quality", Profile.QUALITY_CHOICES[index]))
	sound.add_child(quality)
	sound.add_child(_check_row("show_fps"))
	columns.add_child(controls)
	columns.add_child(sound)
	column.add_child(columns)
	column.add_child(UITheme.button(Loc.t("back"), func() -> void: _show(came_from), "accent", "ui_back"))


func _group_title(key: String) -> Label:
	var title: Label = UITheme.label(Loc.t(key), 22, UITheme.AMBER, true)
	title.custom_minimum_size = Vector2(0.0, 34.0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return title


func _group(key: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation", 4)
	group.add_child(_group_title(key))
	return group


func _row(key: String) -> MenuWidgets.Row:
	var row := MenuWidgets.Row.new()
	var label: Label = UITheme.label(Loc.t(key), UITheme.BODY, UITheme.TEXT, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


func _readout(key: String, value: float) -> String:
	if key == "sensitivity":
		return Loc.number("%.2f" % value) + "×"
	return Loc.percent(value)


func _slider_row(key: String, low: float, high: float, step: float) -> MenuWidgets.Row:
	var row: MenuWidgets.Row = _row(key)
	var slider := MenuWidgets.SlideBar.new(low, high, step, Profile.setting(key))
	slider.custom_minimum_size = Vector2(250.0, 72.0)
	var readout: Label = UITheme.label(_readout(key, slider.value), 24, UITheme.AMBER, true)
	readout.custom_minimum_size = Vector2(76.0, 0.0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# While the thumb is moving the value is applied but not written to storage; it is saved once on release.
	slider.value_changed.connect(func(value: float) -> void:
		Profile.set_setting(key, value, false)
		readout.text = _readout(key, value))
	slider.released.connect(func() -> void:
		Profile.save()
		if key != "sensitivity":
			Sound.play("click", -6.0))
	row.add_child(slider)
	row.add_child(readout)
	return row


func _check_row(key: String) -> MenuWidgets.Row:
	var row: MenuWidgets.Row = _row(key)
	var toggle := MenuWidgets.Switch.new(bool(Profile.setting(key)))
	toggle.toggled.connect(func(pressed: bool) -> void: Profile.set_setting(key, pressed))
	row.toggle = toggle
	row.add_child(toggle)
	return row


## A setting with a few named choices, beside its name.
func _choice_row(key: String, labels: Array, selected: int, action: Callable, width: float) -> MenuWidgets.Row:
	var row: MenuWidgets.Row = _row(key)
	var choices := MenuWidgets.Choices.new(labels, selected)
	choices.custom_minimum_size = Vector2(width, 0.0)
	choices.chosen.connect(action)
	row.add_child(choices)
	return row


func _toggle_language() -> void:
	Profile.set_setting("language", "en" if Loc.language == "fa" else "fa")
