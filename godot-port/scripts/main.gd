extends Control

const GAME_TITLE := "قصرِ شاهزاده"
const SUBTITLE := "نسخهٔ مستقل Godot"

func _ready() -> void:
	_build_placeholder_screen()

func _build_placeholder_screen() -> void:
	var background := ColorRect.new()
	background.color = Color("#101a2c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

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
	title.add_theme_font_size_override("font_size", 42)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = SUBTITLE
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	content.add_child(subtitle)

	var status := Label.new()
	status.text = "هستهٔ بازی در حال انتقال و آزمایش است"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 18)
	content.add_child(status)
