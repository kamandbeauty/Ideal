extends Control

var _save: SaveData
var _store: SaveStore
var _wallet: Wallet
var _progression: Progression
var _districts: Array[Dictionary] = []
var _content: VBoxContainer
var _status: Label

const GOLD := Color(1.0, 0.82, 0.43)
const CREAM := Color(1.0, 0.94, 0.78)

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	ui_theme.default_font_size = 18
	theme = ui_theme
	var directory := str(get_meta("save_directory", ""))
	_store = SaveStore.new(null, directory)
	_save = _store.load_save().data
	_wallet = Wallet.new(_save)
	_progression = Progression.new(_save, GameClock.new())
	_districts = DistrictContentLoader.load_chapter("ch01").districts
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
	shade.color = Color(0.008, 0.025, 0.03, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var back := Button.new()
	back.text = "⌂ خانه"
	back.custom_minimum_size = Vector2(90, 48)
	_style_button(back, Color(0.035, 0.14, 0.15), GOLD, 13)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	header.add_child(back)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var title := Label.new()
	title.text = "بازسازی باغ شازده"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", GOLD)
	heading.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "قدم‌به‌قدم شکوه باغ را برگردان"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	heading.add_child(subtitle)

	var wallet_panel := PanelContainer.new()
	wallet_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.09, 0.095, 0.94), Color(0.69, 0.57, 0.35, 0.85), 15, 9))
	layout.add_child(wallet_panel)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet_panel.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 18)
	scroll.add_child(_content)
	_rebuild()

func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	_status.text = "✦  %s سکه     ◈  %s معجون" % [_fa(_wallet.coins), _fa(_wallet.potions)]
	for district in _districts:
		_add_district(district)

func _add_district(district: Dictionary) -> void:
	var tasks: Array[Dictionary] = district.get("tasks", [])
	var done := 0
	for task in tasks:
		if _progression.is_task_complete(str(task.get("key", ""))):
			done += 1
	var district_id := str(district.get("id", ""))
	var asset_id := district_id.replace("-", "_")
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.055, 0.06, 0.97), Color(0.82, 0.66, 0.36, 0.92), 21, 11))
	_content.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	card.add_child(body)

	var art_frame := PanelContainer.new()
	art_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.07, 0.07), Color(0.62, 0.54, 0.36, 0.75), 15, 3))
	body.add_child(art_frame)
	var art := TextureRect.new()
	var art_path := "res://assets/art/district_%s%s.png" % [asset_id, "_lit" if done == tasks.size() else ""]
	art.texture = AssetCatalog.texture(art_path)
	art.custom_minimum_size = Vector2(0, 138)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_frame.add_child(art)

	var title_row := HBoxContainer.new()
	body.add_child(title_row)
	var district_title := Label.new()
	district_title.text = str(district.get("title", ""))
	district_title.add_theme_font_size_override("font_size", 21)
	district_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(district_title)
	var counter := Label.new()
	counter.text = "%s / %s" % [_fa(done), _fa(tasks.size())]
	counter.add_theme_color_override("font_color", GOLD)
	title_row.add_child(counter)

	var progress := ProgressBar.new()
	progress.min_value = 0
	progress.max_value = 1
	progress.value = float(done) / float(maxi(1, tasks.size()))
	progress.show_percentage = false
	progress.custom_minimum_size.y = 10
	progress.add_theme_stylebox_override("background", _panel_style(Color(0.02, 0.035, 0.035), Color(0.38, 0.43, 0.35, 0.45), 8, 0))
	progress.add_theme_stylebox_override("fill", _panel_style(Color(0.82, 0.62, 0.27), Color(1.0, 0.86, 0.5), 8, 0))
	body.add_child(progress)

	var hint := Label.new()
	hint.text = "بناهای این بخش را بساز تا صندوق گنج آزاد شود"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.78, 0.84, 0.75))
	body.add_child(hint)
	for task in tasks:
		_add_task(body, task)

	var chest: RewardBundle = district.get("chest")
	var chest_panel := PanelContainer.new()
	chest_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.075, 0.035, 0.92), Color(0.83, 0.65, 0.31, 0.85), 15, 8))
	body.add_child(chest_panel)
	var chest_row := HBoxContainer.new()
	chest_row.add_theme_constant_override("separation", 8)
	chest_panel.add_child(chest_row)
	var chest_icon := TextureRect.new()
	chest_icon.texture = AssetCatalog.texture("res://assets/art/reward_chest_open.png" if _progression.is_chest_claimed(district_id) else "res://assets/art/reward_chest.png")
	chest_icon.custom_minimum_size = Vector2(48, 48)
	chest_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chest_row.add_child(chest_icon)
	var chest_text := Label.new()
	chest_text.text = "گنج این بخش\n%s سکه + %s معجون" % [_fa(chest.coins), _fa(chest.potions)]
	chest_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chest_text.add_theme_font_size_override("font_size", 14)
	chest_row.add_child(chest_text)
	var claim := Button.new()
	claim.text = "دریافت"
	claim.custom_minimum_size = Vector2(76, 42)
	claim.disabled = _progression.is_chest_claimed(district_id) or not _progression.is_district_complete(tasks)
	if _progression.is_chest_claimed(district_id):
		claim.text = "دریافت شد ✓"
	claim.pressed.connect(_claim.bind(district_id, chest, tasks))
	_style_button(claim, Color(0.45, 0.28, 0.09), GOLD, 11)
	chest_row.add_child(claim)

func _add_task(parent: VBoxContainer, task: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.105, 0.11, 0.95), Color(0.40, 0.54, 0.46, 0.42), 14, 7))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var art := TextureRect.new()
	art.texture = AssetCatalog.texture("res://assets/art/prop_%s.png" % str(task.get("build_asset", "")))
	art.custom_minimum_size = Vector2(62, 62)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(art)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var name := Label.new()
	name.text = str(task.get("title", ""))
	name.add_theme_font_size_override("font_size", 15)
	info.add_child(name)
	var key := str(task.get("key", ""))
	var cost := int(task.get("potion_cost", 0))
	var state := Label.new()
	state.text = "ساخته شد ✓" if _progression.is_task_complete(key) else "هزینه: %s معجون" % _fa(cost)
	state.add_theme_font_size_override("font_size", 12)
	state.add_theme_color_override("font_color", Color(0.63, 0.91, 0.64) if _progression.is_task_complete(key) else Color(0.83, 0.81, 0.68))
	info.add_child(state)
	var build := Button.new()
	build.text = "✓" if _progression.is_task_complete(key) else "بساز"
	build.disabled = _progression.is_task_complete(key) or _wallet.potions < cost
	build.custom_minimum_size = Vector2(68, 42)
	build.pressed.connect(_complete.bind(key, cost))
	_style_button(build, Color(0.10, 0.29, 0.22), Color(0.68, 0.78, 0.48, 0.78), 11)
	row.add_child(build)

func _complete(key: String, cost: int) -> void:
	if _progression.try_complete_task(key, cost, _wallet):
		_store.save(_save)
		_rebuild()

func _claim(district_id: String, chest: RewardBundle, tasks: Array[Dictionary]) -> void:
	if _progression.try_claim_chest(district_id, chest, tasks, _wallet):
		_store.save(_save)
		_rebuild()

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

func _style_button(button: Button, bg: Color, accent: Color, radius: int = 12) -> void:
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
