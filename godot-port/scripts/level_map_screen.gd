extends Control

const LEVEL_COUNT := 10
const GOLD := Color(1.0, 0.82, 0.43)
const CREAM := Color(1.0, 0.94, 0.78)

var _save: SaveData
var _store: SaveStore
var _progression: Progression
var _content: VBoxContainer
var _wallet_label: Label

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	ui_theme.default_font_size = 18
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
	tint.color = Color(0.008, 0.025, 0.03, 0.32)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var back := Button.new()
	back.text = "⌂ خانه"
	back.custom_minimum_size = Vector2(88, 46)
	_style_button(back, Color(0.035, 0.14, 0.15), GOLD)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	header.add_child(back)
	var title := Label.new()
	title.text = "نقشهٔ ماجراجویی"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)

	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.09, 0.095, 0.96), Color(0.82, 0.66, 0.36), 15, 9))
	layout.add_child(info)
	_wallet_label = Label.new()
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_label.text = "مرحلهٔ باز: %s از %s    •    جان: %s" % [_fa(_progression.highest_unlocked_level), _fa(LEVEL_COUNT), _fa(_save.lives)]
	info.add_child(_wallet_label)

	var guide := Label.new()
	guide.text = "یکی از مرحله‌های روشن را انتخاب کن و دکمهٔ «بازی کن» را بزن"
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", 13)
	guide.add_theme_color_override("font_color", CREAM)
	layout.add_child(guide)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 9)
	scroll.add_child(_content)
	_build_nodes()

	var footer := Label.new()
	footer.text = "با کامل‌کردن هر مرحله، مسیر باغ را پیش ببر"
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
		var panel_color := Color(0.025, 0.12, 0.105, 0.97) if unlocked else Color(0.035, 0.055, 0.06, 0.94)
		var border_color := GOLD if current else (Color(0.45, 0.75, 0.48) if cleared else Color(0.45, 0.48, 0.40, 0.75))
		card.add_theme_stylebox_override("panel", _panel_style(panel_color, border_color, 16, 7))
		_content.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var number_badge := PanelContainer.new()
		number_badge.custom_minimum_size = Vector2(54, 54)
		number_badge.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.12, 0.055) if unlocked else Color(0.08, 0.09, 0.085), border_color, 13, 4))
		row.add_child(number_badge)
		var number_label := Label.new()
		number_label.text = _fa(number)
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number_label.add_theme_font_size_override("font_size", 23)
		number_label.add_theme_color_override("font_color", GOLD if unlocked else Color(0.58, 0.60, 0.55))
		number_badge.add_child(number_label)

		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		details.add_theme_constant_override("separation", 2)
		row.add_child(details)
		var name := Label.new()
		name.text = "مرحلهٔ %s" % _fa(number)
		name.add_theme_font_size_override("font_size", 17)
		name.add_theme_color_override("font_color", CREAM if unlocked else Color(0.68, 0.70, 0.65))
		details.add_child(name)
		var state := Label.new()
		if cleared:
			state.text = "تکمیل‌شده  ✓   •   رکورد: %s" % _fa(int(record.get("best_score", 0)))
		elif not unlocked:
			state.text = "🔒  پس از تکمیل مرحلهٔ قبلی باز می‌شود"
		elif current:
			state.text = "مرحلهٔ فعلی تو • آمادهٔ شروع"
		else:
			state.text = "باز است • می‌توانی دوباره بازی کنی"
		state.add_theme_font_size_override("font_size", 11)
		state.add_theme_color_override("font_color", Color(0.68, 0.9, 0.66) if cleared else Color(0.87, 0.82, 0.68))
		details.add_child(state)

		var play := Button.new()
		play.text = "بازی کن" if unlocked else "قفل"
		play.custom_minimum_size = Vector2(78, 46)
		play.disabled = not unlocked
		_style_button(play, Color(0.13, 0.34, 0.23) if unlocked else Color(0.12, 0.13, 0.12), GOLD if unlocked else Color(0.4, 0.42, 0.38), 11)
		if unlocked:
			play.pressed.connect(_start_level.bind(number))
		row.add_child(play)

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
