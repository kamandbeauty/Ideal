extends Control
## Title screen: new town, continue, language.

signal play_requested
signal continue_requested

var _title: Label
var _subtitle: Label
var _hint: Label
var _controls: Label
var _best: Label
var _play: Button
var _continue: Button
var _language: Button
var _quit: Button
var _settings_button: Button
var _settings
var _icon: TextureRect
var _built := false


func _ready() -> void:
	theme = App.ui_theme
	layout_direction = App.layout_direction()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not _built:
		_build()
	_apply_language()
	App.language_changed.connect(_on_language_changed)
	Sound.play_music("menu")


func _build() -> void:
	_built = true

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.13, 0.18, 0.24))
	gradient.set_color(1, Color(0.02, 0.03, 0.05))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.35, 1.0)
	var background := TextureRect.new()
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -40
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size = Vector2(560, 0)
	center.add_child(column)

	_icon = TextureRect.new()
	_icon.texture = load("res://assets/icons/launcher_192.png")
	_icon.custom_minimum_size = Vector2(132, 132)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_icon)

	_title = _make_label(72, UiTheme.TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_subtitle = _make_label(26, UiTheme.ACCENT)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap)

	_hint = _make_label(19, UiTheme.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 22)
	column.add_child(gap2)

	_play = _make_button(360, 76, "PrimaryButton")
	_play.add_theme_font_size_override("font_size", 24)
	_play.pressed.connect(func() -> void: play_requested.emit())
	column.add_child(_play)

	_continue = _make_button(360, 62, "GhostButton")
	_continue.pressed.connect(func() -> void: continue_requested.emit())
	column.add_child(_continue)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)

	_language = _make_button(200, 56, "GhostButton")
	_language.pressed.connect(func() -> void: App.toggle_language())
	buttons.add_child(_language)

	_settings_button = _make_button(160, 56, "GhostButton")
	_settings_button.pressed.connect(_on_settings)
	buttons.add_child(_settings_button)

	_settings = load("res://scripts/ui/settings_panel.gd").new()
	_settings.name = "Settings"
	_settings.visible = false
	add_child(_settings)

	_best = _make_label(18, UiTheme.GOLD)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_best)

	_controls = _make_label(16, UiTheme.MUTED)
	_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_controls.offset_left = 20
	_controls.offset_top = -52
	_controls.offset_right = -20
	_controls.offset_bottom = -18
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_controls)

	_quit = _make_button(140, 50, "GhostButton")
	_quit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_quit.offset_left = -156
	_quit.offset_top = -74
	_quit.offset_right = -16
	_quit.offset_bottom = -24
	_quit.pressed.connect(func() -> void: get_tree().quit())
	add_child(_quit)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(min_width: int, height: int, variation: String) -> Button:
	var button := Button.new()
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(min_width, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	return button


func _on_settings() -> void:
	Sound.play("click", -12.0)
	_settings.open()


func _on_language_changed(_language: String) -> void:
	layout_direction = App.layout_direction()
	_apply_language()


func _apply_language() -> void:
	_title.text = App.t("app.title")
	_subtitle.text = App.t("app.subtitle")
	_hint.text = App.t("menu.hint")
	_controls.text = App.t("menu.controls")
	_play.text = App.t("menu.new_game")
	_continue.text = App.t("menu.continue")
	_language.text = App.t("menu.language_target")
	_settings_button.text = App.t("hud.settings")
	_quit.text = App.t("menu.quit")
	_best.text = App.t("menu.record", [App.format_number(float(App.best_reputation))])
	_continue.visible = Game.has_save()
	_quit.visible = not OS.has_feature("mobile")
