extends Control
## Portrait Roadside Empire title screen: warm desert canyon backdrop, large
## glossy GAS station icon, Start/Continue, Language switcher & Settings!

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
var _settings_button: Button
var _quit: Button
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
	gradient.set_color(0, Color(0.24, 0.48, 0.80))
	gradient.add_point(0.55, Color(0.86, 0.56, 0.28))
	gradient.set_color(1, Color(0.16, 0.13, 0.22))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var background := TextureRect.new()
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(610, 0)
	center.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	_icon = TextureRect.new()
	_icon.texture = load("res://assets/icons/icon.png")
	_icon.custom_minimum_size = Vector2(188, 188)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_icon)

	_title = _make_label(48, UiTheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_subtitle = _make_label(22, UiTheme.ACCENT)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_subtitle)

	_hint = _make_label(16, UiTheme.TEXT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)

	_continue = _make_button(440, 68, "GreenButton")
	_continue.add_theme_font_size_override("font_size", 23)
	_continue.pressed.connect(func() -> void: continue_requested.emit())
	col.add_child(_continue)

	_play = _make_button(440, 62, "PurpleButton")
	_play.add_theme_font_size_override("font_size", 21)
	_play.pressed.connect(func() -> void: play_requested.emit())
	col.add_child(_play)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)

	_language = _make_button(210, 52, "GhostButton")
	_language.pressed.connect(func() -> void: App.toggle_language())
	row.add_child(_language)

	_settings_button = _make_button(210, 52, "GhostButton")
	_settings_button.pressed.connect(func() -> void: _settings.open())
	row.add_child(_settings_button)

	_best = _make_label(16, UiTheme.GOLD)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_best)

	_controls = _make_label(14, UiTheme.MUTED)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_controls)

	_quit = _make_button(180, 44, "GhostButton")
	_quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(_quit)

	_settings = load("res://scripts/ui/settings_panel.gd").new()
	_settings.name = "Settings"
	_settings.visible = false
	add_child(_settings)


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


func _on_language_changed(_lang: String) -> void:
	layout_direction = App.layout_direction()
	_apply_language()


func _apply_language() -> void:
	_title.text = App.t("app.title")
	_subtitle.text = App.t("app.subtitle")
	_hint.text = App.t("menu.hint")
	_play.text = "⛽ " + App.t("menu.new_game")
	_continue.text = "▶ " + App.t("menu.continue")
	_continue.visible = Game.has_save()
	_language.text = "🌐 " + App.t("menu.language_target")
	_settings_button.text = "⚙️ " + App.t("hud.settings")
	_quit.text = App.t("menu.quit")
	_controls.text = App.t("menu.controls")
	_best.visible = App.best_reputation > 0
	if _best.visible:
		_best.text = "⭐ " + App.t("menu.record", [App.format_number(App.best_reputation)])
