extends Control

var _save: SaveData
var _store: SaveStore

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	ui_theme.default_font_size = 20
	theme = ui_theme
	var directory := str(get_meta("save_directory", ""))
	_store = SaveStore.new(null, directory)
	_save = _store.load_save().data
	_build_ui()

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(500, 0)
	layout.add_theme_constant_override("separation", 18)
	center.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var back := Button.new()
	back.text = "بازگشت"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	header.add_child(back)
	var title := Label.new()
	title.text = "تنظیمات"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)
	_add_toggle(layout, "موسیقی", _save.music_on, "music")
	_add_toggle(layout, "صدا", _save.sfx_on, "sfx")
	_add_toggle(layout, "لرزش", _save.haptics_on, "haptics")
	_add_toggle(layout, "اعلان‌ها", _save.push_on, "push")

func _add_toggle(parent: VBoxContainer, label: String, value: bool, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.button_pressed = value
	toggle.toggled.connect(_on_toggle.bind(key))
	parent.add_child(toggle)

func _on_toggle(value: bool, key: String) -> void:
	match key:
		"music": _save.music_on = value
		"sfx": _save.sfx_on = value
		"haptics": _save.haptics_on = value
		"push": _save.push_on = value
	_store.save(_save)
