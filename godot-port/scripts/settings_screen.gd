extends Control

const GOLD := Color(1.0, 0.82, 0.43)
const CREAM := Color(1.0, 0.94, 0.78)

var _save: SaveData
var _store: SaveStore
var _status: Label

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	ui_theme.default_font_size = 17
	theme = ui_theme
	var directory := str(get_meta("save_directory", ""))
	_store = SaveStore.new(null, directory)
	_save = _store.load_save().data
	_build_ui()

func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = AssetCatalog.texture("res://assets/art/map_backdrop.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.025, 0.03, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	center.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var back := Button.new()
	back.text = "⌂ خانه"
	back.custom_minimum_size = Vector2(88, 46)
	_style_button(back, Color(0.035, 0.14, 0.15), GOLD)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	header.add_child(back)
	var title := Label.new()
	title.text = "تنظیمات باغ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)
	var crown := TextureRect.new()
	crown.texture = AssetCatalog.texture("res://assets/art/icon_settings.png")
	crown.custom_minimum_size = Vector2(40, 40)
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(crown)

	var intro := PanelContainer.new()
	intro.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.10, 0.10, 0.95), Color(0.83, 0.66, 0.36, 0.9), 19, 13))
	layout.add_child(intro)
	var intro_text := Label.new()
	intro_text.text = "باغ را مطابق سلیقه‌ات تنظیم کن"
	intro_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_text.add_theme_color_override("font_color", CREAM)
	intro.add_child(intro_text)

	var sections_row := HBoxContainer.new()
	sections_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sections_row.add_theme_constant_override("separation", 14)
	layout.add_child(sections_row)
	var sound_section := _section("صدا و بازخورد")
	sound_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections_row.add_child(sound_section)
	_add_setting(sound_section, "صداهای بازی", "افکت‌های جابه‌جایی، کمبو و قدرت‌ها", "res://assets/art/icon_sound.png", _save.sfx_on, "sfx", true)
	_add_setting(sound_section, "لرزش گوشی", "بازخورد لمسی هنگام کمبو و اتفاق‌های مهم", "res://assets/art/icon_vibration.png", _save.haptics_on, "haptics", true)

	var coming_section := _section("امکانات آینده")
	coming_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections_row.add_child(coming_section)
	_add_setting(coming_section, "موسیقی پس‌زمینه", "موسیقی اختصاصی باغ در به‌روزرسانی بعدی", "res://assets/art/icon_music.png", false, "music", false)
	_add_setting(coming_section, "اعلان‌ها", "یادآوری بازگشت به باغ؛ در حال توسعه", "res://assets/art/icon_push.png", false, "push", false)

	_status = Label.new()
	_status.text = "تنظیمات فعال به‌صورت خودکار ذخیره می‌شوند"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.79, 0.85, 0.75))
	layout.add_child(_status)

func _section(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.065, 0.07, 0.95), Color(0.58, 0.57, 0.39, 0.72), 18, 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", GOLD)
	column.add_child(title)
	panel.set_meta("content", column)
	return panel

func _add_setting(section: PanelContainer, title_text: String, description: String, icon_path: String, value: bool, key: String, enabled: bool) -> void:
	var column := section.get_meta("content") as VBoxContainer
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.12, 0.12, 0.93), Color(0.39, 0.53, 0.45, 0.45), 13, 8))
	column.add_child(row_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row_panel.add_child(row)
	var icon_view := TextureRect.new()
	icon_view.texture = AssetCatalog.texture(icon_path)
	icon_view.custom_minimum_size = Vector2(42, 42)
	icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon_view)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	var name := Label.new()
	name.text = title_text
	name.add_theme_font_size_override("font_size", 15)
	copy.add_child(name)
	var hint := Label.new()
	hint.text = description
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.76, 0.82, 0.73))
	copy.add_child(hint)
	if enabled:
		var toggle := CheckButton.new()
		toggle.button_pressed = value
		toggle.toggled.connect(_on_toggle.bind(key))
		toggle.add_theme_color_override("font_color", CREAM)
		toggle.add_theme_color_override("font_hover_color", GOLD)
		row.add_child(toggle)
	else:
		var soon := Label.new()
		soon.text = "به‌زودی"
		soon.add_theme_font_size_override("font_size", 11)
		soon.add_theme_color_override("font_color", GOLD)
		row.add_child(soon)

func _on_toggle(value: bool, key: String) -> void:
	match key:
		"sfx": _save.sfx_on = value
		"haptics": _save.haptics_on = value
	if _store.save(_save):
		_status.text = "تغییرات ذخیره شد ✓"
	else:
		_status.text = "ذخیرهٔ تنظیمات انجام نشد"

func _panel_style(bg: Color, border: Color, radius: int = 16, inset: int = 9) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style

func _style_button(button: Button, bg: Color, accent: Color, radius: int = 12) -> void:
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(bg, accent, radius, 6))
	button.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.12), GOLD, radius, 6))
	button.add_theme_stylebox_override("pressed", _panel_style(bg.darkened(0.12), accent.lightened(0.1), radius, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
