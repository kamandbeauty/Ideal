extends Control

const GAME_TITLE := "قصرِ شاهزاده"
const SUBTITLE := "نسخهٔ مستقل Godot"

func _ready() -> void:
	_apply_persian_theme()
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	_build_placeholder_screen()

func _apply_persian_theme() -> void:
	var medium_font := load("res://assets/fonts/Vazir-Medium.ttf") as Font
	var bold_font := load("res://assets/fonts/Vazir-Bold.ttf") as Font
	var ui_theme := Theme.new()
	ui_theme.default_font = medium_font
	ui_theme.default_font_size = 22
	theme = ui_theme
	set_meta("bold_font", bold_font)

func _build_placeholder_screen() -> void:
	var background := TextureRect.new()
	background.texture = AssetCatalog.texture("res://assets/art/board_backdrop_ch01.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var tint := ColorRect.new()
	tint.color = Color(0.055, 0.067, 0.11, 0.48)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tint)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	center.add_child(content)

	var title := Label.new()
	title.text = GAME_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	var bold_font: Font = get_meta("bold_font")
	if bold_font != null:
		title.add_theme_font_override("font", bold_font)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = SUBTITLE
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	content.add_child(subtitle)

	var status := Label.new()
	status.text = "هستهٔ بازی و محتوای فصلِ اوّل منتقل شده است"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 18)
	content.add_child(status)
