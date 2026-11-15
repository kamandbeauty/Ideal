extends Control
## The settings sheet: music, effects, haptics and the graphics preset.
##
## It is a plain overlay built in code, the same way the rest of the UI is, so it
## works with the Persian font and the RTL layout without any editor work.

signal closed

var _music: HSlider
var _sfx: HSlider
var _haptics: Button
var _quality: Button
var _close: Button
var _rows: Dictionary = {}
var _title: Label


func _ready() -> void:
	theme = App.ui_theme
	layout_direction = App.layout_direction()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_apply_language()


func open() -> void:
	visible = true
	_refresh()
	Sound.play("click", -12.0)


func close() -> void:
	visible = false
	closed.emit()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.01, 0.015, 0.03, 0.72)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	_title = _label(28, UiTheme.TEXT, true)
	column.add_child(_title)

	column.add_child(_separator())

	_music = _slider_row(column, "settings.music")
	_music.value_changed.connect(func(value: float) -> void: App.set_music_volume(value))

	_sfx = _slider_row(column, "settings.sfx")
	_sfx.value_changed.connect(func(value: float) -> void:
		App.set_sfx_volume(value)
		Sound.play("pop", -8.0))

	_haptics = _button_row(column, "settings.haptics")
	_haptics.pressed.connect(_on_haptics)

	_quality = _button_row(column, "settings.quality")
	_quality.pressed.connect(_on_quality)

	column.add_child(_separator())

	_close = Button.new()
	_close.theme_type_variation = "PrimaryButton"
	_close.custom_minimum_size = Vector2(0, 56)
	_close.pressed.connect(close)
	column.add_child(_close)

	_refresh()


func _slider_row(column: VBoxContainer, key: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var label := _label(18, UiTheme.MUTED, false)
	label.custom_minimum_size = Vector2(150, 0)
	_row_label(key, label)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(0, 36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	return slider


func _button_row(column: VBoxContainer, key: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 52)
	button.focus_mode = Control.FOCUS_NONE
	column.add_child(button)
	_rows[key] = button
	return button


func _row_label(key: String, label: Label) -> void:
	_rows[key] = label
	label.text = App.t(key)


func _separator() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	return gap


func _refresh() -> void:
	_music.set_value_no_signal(App.music_volume)
	_sfx.set_value_no_signal(App.sfx_volume)
	_haptics.text = "%s: %s" % [
		App.t("settings.haptics"), App.t("settings.on" if App.haptics else "settings.off")
	]
	_quality.text = "%s: %s" % [
		App.t("settings.quality"), App.t(Quality.label_key(App.quality))
	]


func _on_haptics() -> void:
	App.haptics = not App.haptics
	App.tap(24)
	_refresh()
	App.settings_changed.emit()


func _on_quality() -> void:
	App.cycle_quality()
	_refresh()
	Sound.play("click", -12.0)


func _apply_language() -> void:
	_title.text = App.t("settings.title")
	_close.text = App.t("hud.close")
	for key in _rows:
		var node: Node = _rows[key]
		if node is Label:
			(node as Label).text = App.t(str(key))
	_refresh()


func _label(font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if bold else HORIZONTAL_ALIGNMENT_LEFT
	return label
