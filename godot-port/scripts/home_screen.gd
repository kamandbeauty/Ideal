extends Control

var _save: SaveData
var _store: SaveStore
var _wallet: Wallet
var _lives: Lives
var _stats_label: Label

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	_apply_theme()
	_load_save()
	_build_ui()

func _apply_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	ui_theme.default_font_size = 22
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
	shade.color = Color(0.025, 0.04, 0.08, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(560, 0)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	center.add_child(layout)

	var title := Label.new()
	title.text = "باغ شازده"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.66))
	layout.add_child(title)

	var emblem := TextureRect.new()
	emblem.texture = AssetCatalog.texture("res://assets/art/icon_crown.png")
	emblem.custom_minimum_size = Vector2(78, 78)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layout.add_child(emblem)
	var subtitle := Label.new()
	subtitle.text = "جواهرها را جور کن و باغِ شاهزاده را آباد کن"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(subtitle)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(_stats_label)
	_refresh_stats()

	_add_menu_button(layout, "شروع مرحله", "res://scenes/gameplay_screen.tscn")
	_add_menu_button(layout, "ساخت قلمرو", "res://scenes/district_screen.tscn")
	_add_menu_button(layout, "فروشگاه", "res://scenes/shop_screen.tscn")
	_add_menu_button(layout, "تنظیمات", "res://scenes/settings_screen.tscn")

func _add_menu_button(parent: VBoxContainer, label: String, scene_path: String) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 60)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.76))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.24, 0.25, 0.96)
	normal.border_color = Color(0.8, 0.65, 0.34, 0.85)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	button.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.14, 0.34, 0.32, 1)
	hover.border_color = Color(1.0, 0.82, 0.48, 1)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(14)
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(scene_path)
	)
	parent.add_child(button)

func _refresh_stats() -> void:
	var progression := Progression.new(_save, GameClock.new())
	_stats_label.text = "سکه: %d     معجون: %d     جان: %d/%d     مرحله: %d" % [
		_wallet.coins, _wallet.potions, _lives.current, _lives.max_lives, progression.highest_unlocked_level
	]
