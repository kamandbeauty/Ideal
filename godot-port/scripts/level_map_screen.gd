extends Control

const LEVEL_COUNT := 10
const GOLD := Color(1.0, 0.82, 0.43)
const CREAM := Color(1.0, 0.94, 0.78)

var _save: SaveData
var _store: SaveStore
var _progression: Progression
var _grid: GridContainer

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	ui_theme.default_font_size = 17
	theme = ui_theme
	var directory := str(get_meta("save_directory", ""))
	_store = SaveStore.new(null, directory)
	_save = _store.load_save().data
	_progression = Progression.new(_save, GameClock.new())
	_build_ui()

func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = AssetCatalog.texture("res://assets/art/map_backdrop.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var tint := ColorRect.new()
	tint.color = Color(0.008, 0.025, 0.03, 0.30)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var back := Button.new()
	back.text = "⌂ خانه"
	back.custom_minimum_size = Vector2(100, 42)
	_style_button(back, Color(0.035, 0.14, 0.15), GOLD)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	header.add_child(back)
	var title := Label.new()
	title.text = "نقشهٔ ماجراجویی باغ شازده"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)
	var stats := Label.new()
	stats.text = "جان: %s   •   مرحلهٔ باز: %s از %s" % [_fa(_save.lives), _fa(_progression.highest_unlocked_level), _fa(LEVEL_COUNT)]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats.custom_minimum_size.x = 230
	stats.add_theme_color_override("font_color", CREAM)
	header.add_child(stats)

	var guide := Label.new()
	guide.text = "مرحلهٔ دلخواهت را انتخاب کن؛ مراحل قفل‌شده با پیشروی باز می‌شوند."
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 13)
	guide.add_theme_color_override("font_color", CREAM)
	layout.add_child(guide)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(grid_center)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 10)
	grid_center.add_child(_grid)
	_build_nodes()

	var footer := Label.new()
	footer.text = "★ هر مرحله را کامل کن و باغ را گسترش بده"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.95, 0.89, 0.72))
	layout.add_child(footer)

func _build_nodes() -> void:
	for number in range(1, LEVEL_COUNT + 1):
		var unlocked := _progression.is_unlocked(number)
		var record := _save.find_level(number)
		var cleared := bool(record.get("cleared", false))
		var current := number == _save.level_number
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 196)
		var panel_color := Color(0.025, 0.12, 0.105, 0.97) if unlocked else Color(0.025, 0.05, 0.055, 0.96)
		var border_color := GOLD if current else (Color(0.45, 0.75, 0.48) if cleared else Color(0.45, 0.48, 0.40, 0.75))
		card.add_theme_stylebox_override("panel", _panel_style(panel_color, border_color, 17, 10))
		_grid.add_child(card)
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 5)
		card.add_child(column)
		var number_label := Label.new()
		number_label.text = "مرحلهٔ %s" % _fa(number)
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.add_theme_font_size_override("font_size", 21)
		number_label.add_theme_color_override("font_color", GOLD if unlocked else Color(0.58, 0.60, 0.55))
		column.add_child(number_label)
		var emblem := Label.new()
		emblem.text = "★  ★  ★" if cleared else ("♛" if unlocked else "قفل")
		emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emblem.add_theme_font_size_override("font_size", 25)
		emblem.add_theme_color_override("font_color", GOLD if unlocked else Color(0.58, 0.60, 0.55))
		column.add_child(emblem)
		var state := Label.new()
		if cleared:
			state.text = "رکورد: %s" % _fa(int(record.get("best_score", 0)))
		elif not unlocked:
			state.text = "پس از مرحلهٔ قبلی"
		elif current:
			state.text = "مرحلهٔ فعلی"
		else:
			state.text = "آمادهٔ بازی"
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state.add_theme_font_size_override("font_size", 11)
		state.add_theme_color_override("font_color", Color(0.68, 0.9, 0.66) if cleared else CREAM)
		column.add_child(state)
		var play := Button.new()
		play.text = "بازی کن" if unlocked else "قفل است"
		play.custom_minimum_size = Vector2(0, 38)
		play.disabled = not unlocked
		_style_button(play, Color(0.13, 0.34, 0.23) if unlocked else Color(0.12, 0.13, 0.12), GOLD if unlocked else Color(0.4, 0.42, 0.38), 11)
		if unlocked:
			play.pressed.connect(_start_level.bind(number))
		column.add_child(play)

func _start_level(number: int) -> void:
	if not _progression.is_unlocked(number):
		return
	get_tree().root.set_meta("selected_level_number", number)
	get_tree().change_scene_to_file("res://scenes/gameplay_screen.tscn")

func _panel_style(bg: Color, border: Color, radius: int = 15, inset: int = 8) -> StyleBoxFlat:
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

func _style_button(button: Button, bg: Color, accent: Color, radius: int = 13) -> void:
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.52))
	button.add_theme_stylebox_override("normal", _panel_style(bg, accent, radius, 6))
	button.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.12), GOLD, radius, 6))
	button.add_theme_stylebox_override("pressed", _panel_style(bg.darkened(0.12), accent.lightened(0.1), radius, 6))
	button.add_theme_stylebox_override("disabled", _panel_style(bg.darkened(0.08), accent.darkened(0.2), radius, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _fa(value: int) -> String:
	var digits := "۰۱۲۳۴۵۶۷۸۹"
	var raw := str(maxi(0, value))
	var result := ""
	for i in range(raw.length()):
		result += digits.substr(int(raw.substr(i, 1)), 1)
	return result
