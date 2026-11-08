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
	tint.color = Color(0.008, 0.025, 0.03, 0.52)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
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
	info.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.09, 0.095, 0.94), Color(0.69, 0.57, 0.35, 0.85), 15, 9))
	layout.add_child(info)
	_wallet_label = Label.new()
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_label.text = "مرحلهٔ باز: %s از %s   •   جان: %s" % [_fa(_progression.highest_unlocked_level), _fa(LEVEL_COUNT), _fa(_save.lives)]
	info.add_child(_wallet_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	_build_nodes()

	var footer := Label.new()
	footer.text = "مراحل قفل‌شده با پیشروی در بازی باز می‌شوند"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.85, 0.87, 0.76))
	layout.add_child(footer)

func _build_nodes() -> void:
	for number in range(1, LEVEL_COUNT + 1):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER if number % 2 == 1 else BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 8)
		_content.add_child(row)
		if number % 2 == 0:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(spacer)
		row.add_child(_make_level_node(number))
		if number % 2 == 1:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(spacer)
		if number < LEVEL_COUNT:
			var connector := Label.new()
			connector.text = "✦     ◆     ✦"
			connector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			connector.add_theme_color_override("font_color", Color(0.89, 0.70, 0.36, 0.9))
			connector.add_theme_font_size_override("font_size", 16)
			_content.add_child(connector)

func _make_level_node(number: int) -> Control:
	var unlocked := _progression.is_unlocked(number)
	var record := _save.find_level(number)
	var cleared := bool(record.get("cleared", false))
	var current := number == _save.level_number
	var node := Button.new()
	node.custom_minimum_size = Vector2(196, 106)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.disabled = not unlocked
	var icon_path := "res://assets/art/node_locked.png"
	if cleared:
		icon_path = "res://assets/art/node_cleared.png"
	elif current:
		icon_path = "res://assets/art/node_current.png"
	node.icon = AssetCatalog.texture(icon_path)
	node.expand_icon = true
	node.icon_max_width = 64
	var state := "قفل" if not unlocked else ("تکمیل شد ✓" if cleared else ("مرحلهٔ بعدی" if current else "آمادهٔ بازی"))
	var score := int(record.get("best_score", 0))
	node.text = "مرحلهٔ %s\n%s%s" % [_fa(number), state, "\nرکورد: " + _fa(score) if score > 0 else ""]
	node.add_theme_font_size_override("font_size", 14)
	_style_button(node, Color(0.025, 0.12, 0.12, 0.96), Color(0.78, 0.62, 0.34, 0.86), 16)
	node.disabled = not unlocked
	if unlocked:
		node.pressed.connect(_start_level.bind(number))
	return node

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
	button.add_theme_stylebox_override("normal", _panel_style(bg, accent, radius, 7))
	button.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.12), GOLD, radius, 7))
	button.add_theme_stylebox_override("pressed", _panel_style(bg.darkened(0.12), accent.lightened(0.1), radius, 7))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _fa(value: int) -> String:
	var digits := "۰۱۲۳۴۵۶۷۸۹"
	var raw := str(maxi(0, value))
	var result := ""
	for i in range(raw.length()):
		result += digits.substr(int(raw.substr(i, 1)), 1)
	return result
