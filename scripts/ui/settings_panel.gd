extends Control
## Portrait Settings & Pause Sheet: language toggle (Persian/English), audio,
## haptics, graphics preset, save and return to main menu.

signal closed
signal menu_requested

var session: Node
var _music: HSlider
var _sfx: HSlider
var _haptics: Button
var _quality: Button
var _lang_btn: Button
var _save_btn: Button
var _menu_btn: Button
var _close: Button
var _rows: Dictionary = {}
var _title: Label


func _ready() -> void:
	theme = App.ui_theme
	layout_direction = App.layout_direction()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	App.language_changed.connect(func(_l: String) -> void:
		layout_direction = App.layout_direction()
		_refresh())


func open() -> void:
	layout_direction = App.layout_direction()
	visible = true
	_refresh()
	Sound.play("click", -12.0)


func close() -> void:
	visible = false
	closed.emit()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.06, 0.78)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	_title = _lbl(26, UiTheme.TEXT)
	col.add_child(_title)

	_music = _slider_row(col, "settings.music")
	_music.value_changed.connect(func(v: float) -> void: App.set_music_volume(v))

	_sfx = _slider_row(col, "settings.sfx")
	_sfx.value_changed.connect(func(v: float) -> void:
		App.set_sfx_volume(v)
		Sound.play("pop", -8.0))

	_haptics = _btn_row(col)
	_haptics.pressed.connect(func() -> void:
		App.haptics = not App.haptics
		App.tap(24)
		_refresh())

	_quality = _btn_row(col)
	_quality.pressed.connect(func() -> void:
		App.cycle_quality()
		Sound.play("click", -10.0)
		_refresh())

	_lang_btn = _btn_row(col)
	_lang_btn.pressed.connect(func() -> void:
		Sound.play("click", -10.0)
		App.toggle_language())

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	col.add_child(action_row)

	_save_btn = Button.new()
	_save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_btn.custom_minimum_size = Vector2(0, 48)
	_save_btn.focus_mode = Control.FOCUS_NONE
	_save_btn.pressed.connect(func() -> void:
		Game.save_game()
		Sound.play("cash", -8.0)
		close())
	action_row.add_child(_save_btn)

	_menu_btn = Button.new()
	_menu_btn.theme_type_variation = "DangerButton"
	_menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_btn.custom_minimum_size = Vector2(0, 48)
	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.pressed.connect(func() -> void:
		close()
		menu_requested.emit())
	action_row.add_child(_menu_btn)

	_close = Button.new()
	_close.theme_type_variation = "GreenButton"
	_close.custom_minimum_size = Vector2(0, 54)
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(close)
	col.add_child(_close)
	_refresh()


func _slider_row(col: VBoxContainer, key: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var l := _lbl(17, UiTheme.MUTED)
	l.custom_minimum_size = Vector2(145, 0)
	row.add_child(l)
	_rows[key] = l

	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(0, 36)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	return s


func _btn_row(col: VBoxContainer) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	col.add_child(b)
	return b


func _refresh() -> void:
	if _title == null:
		return
	_title.text = "⚙️ " + App.t("settings.title")
	for k in _rows:
		(_rows[k] as Label).text = App.t(String(k))
	_music.set_value_no_signal(App.music_volume)
	_sfx.set_value_no_signal(App.sfx_volume)
	_haptics.text = "%s: %s" % [
		App.t("settings.haptics"), App.t("settings.on" if App.haptics else "settings.off")
	]
	_quality.text = "%s: %s" % [
		App.t("settings.quality"), App.t(Quality.label_key(App.quality))
	]
	_lang_btn.text = "🌐 %s -> %s" % [App.t("settings.lang"), App.t("menu.language_target")]
	_save_btn.text = "💾 " + App.t("hud.save")
	_menu_btn.text = "🏠 " + App.t("hud.menu")
	_menu_btn.visible = session != null
	_save_btn.visible = session != null
	_close.text = App.t("hud.close")


func _lbl(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
