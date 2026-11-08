extends Control

var _save: SaveData
var _store: SaveStore
var _wallet: Wallet
var _lives: Lives
var _stats_label: Label
var _progress_label: Label

const GOLD := Color(1.0, 0.82, 0.43)
const CREAM := Color(1.0, 0.94, 0.78)
const DEEP_GREEN := Color(0.035, 0.13, 0.13, 0.96)
const PANEL_DARK := Color(0.025, 0.07, 0.09, 0.94)

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	_apply_theme()
	_load_save()
	_build_ui()

func _apply_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	ui_theme.default_font_size = 20
	ui_theme.set_color("font_color", "Label", CREAM)
	ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme = ui_theme

func _load_save() -> void:
	var directory := str(get_meta("save_directory", ""))
	_store = SaveStore.new(null, directory)
	_save = _store.load_save().data
	if not FileAccess.file_exists(_store.location):
		_store.save(_save)
	_wallet = Wallet.new(_save)
	_lives = Lives.new(_save, GameClock.new())

func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = AssetCatalog.texture("res://assets/art/home_palace_lit.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.012, 0.035, 0.045, 0.57)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 10)
	layout.add_child(top_row)
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 17)
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stats_panel := PanelContainer.new()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.09, 0.10, 0.88), Color(0.66, 0.55, 0.34, 0.8), 16, 10))
	stats_panel.add_child(_stats_label)
	top_row.add_child(stats_panel)
	var settings_button := Button.new()
	settings_button.text = "⚙"
	settings_button.custom_minimum_size = Vector2(54, 54)
	_style_button(settings_button, Color(0.06, 0.19, 0.18, 0.95), GOLD)
	settings_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/settings_screen.tscn"))
	top_row.add_child(settings_button)
	_refresh_stats()

	var hero := PanelContainer.new()
	hero.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.085, 0.085, 0.91), Color(0.91, 0.72, 0.36, 0.95), 28, 22))
	layout.add_child(hero)
	var hero_body := VBoxContainer.new()
	hero_body.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_body.add_theme_constant_override("separation", 9)
	hero.add_child(hero_body)

	var eyebrow := Label.new()
	eyebrow.text = "ماجرای بازسازی باغ ایرانی"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", Color(0.79, 0.9, 0.78))
	hero_body.add_child(eyebrow)

	var emblem := TextureRect.new()
	emblem.texture = AssetCatalog.texture("res://assets/art/icon_crown.png")
	emblem.custom_minimum_size = Vector2(104, 104)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero_body.add_child(emblem)

	var title := Label.new()
	title.text = "باغ شازده"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", GOLD)
	hero_body.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "جواهرها را جور کن؛ شکوه باغ را دوباره زنده کن"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 17)
	hero_body.add_child(subtitle)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 16)
	_progress_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.63))
	hero_body.add_child(_progress_label)
	_refresh_progress()

	var start_button := Button.new()
	start_button.text = "✦   ورود به باغ و شروع بازی   ✦"
	start_button.custom_minimum_size = Vector2(0, 66)
	start_button.add_theme_font_size_override("font_size", 22)
	_style_button(start_button, Color(0.69, 0.43, 0.13, 1.0), Color(1.0, 0.88, 0.56), 18)
	start_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/gameplay_screen.tscn"))
	hero_body.add_child(start_button)

	var section_title := Label.new()
	section_title.text = "بخش‌های باغ"
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_title.add_theme_font_size_override("font_size", 19)
	section_title.add_theme_color_override("font_color", GOLD)
	layout.add_child(section_title)

	var menu_grid := GridContainer.new()
	menu_grid.columns = 2
	menu_grid.add_theme_constant_override("h_separation", 12)
	menu_grid.add_theme_constant_override("v_separation", 12)
	layout.add_child(menu_grid)
	_add_menu_button(menu_grid, "ساخت قلمرو", "باغ را گسترش بده", "res://assets/art/prop_ch01_pavilion.png", "res://scenes/district_screen.tscn")
	_add_menu_button(menu_grid, "فروشگاه", "گنج و ابزارها", "res://assets/art/reward_chest.png", "res://scenes/shop_screen.tscn")

	var footer := Label.new()
	footer.text = "به باغ شازده خوش آمدی"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 0.86))
	layout.add_child(footer)

func _panel_style(background: Color, border: Color, radius: int = 18, inset: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style

func _style_button(button: Button, background: Color, accent: Color, radius: int = 14) -> void:
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_stylebox_override("normal", _panel_style(background, accent, radius, 10))
	button.add_theme_stylebox_override("hover", _panel_style(background.lightened(0.12), GOLD, radius, 10))
	button.add_theme_stylebox_override("pressed", _panel_style(background.darkened(0.12), accent.lightened(0.1), radius, 10))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _add_menu_button(parent: GridContainer, label: String, caption: String, icon_path: String, scene_path: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 94)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = label + "\n" + caption
	button.icon = AssetCatalog.texture(icon_path)
	button.expand_icon = true
	button.icon_max_width = 42
	button.add_theme_font_size_override("font_size", 18)
	_style_button(button, Color(0.035, 0.16, 0.16, 0.94), Color(0.65, 0.57, 0.38, 0.85), 16)
	button.pressed.connect(func() -> void: get_tree().change_scene_to_file(scene_path))
	parent.add_child(button)

func _refresh_stats() -> void:
	if _stats_label == null:
		return
	_stats_label.text = "✦  %d سکه     ◈  %d معجون     ♥  %d / %d" % [
			_wallet.coins, _wallet.potions, _lives.current, _lives.max_lives
	]

func _refresh_progress() -> void:
	if _progress_label == null:
		return
	var progression := Progression.new(_save, GameClock.new())
	_progress_label.text = "مرحلهٔ بعدی: %s   •   بالاترین مرحلهٔ باز: %s" % [
		_format_persian_number(_save.level_number), _format_persian_number(progression.highest_unlocked_level)
	]

func _format_persian_number(value: int) -> String:
	var digits := "۰۱۲۳۴۵۶۷۸۹"
	var raw := str(maxi(0, value))
	var formatted := ""
	for index in range(raw.length()):
		formatted += digits.substr(int(raw.substr(index, 1)), 1)
	return formatted
