extends Control

const PERSIAN_FONT = preload("res://assets/fonts/DejaVuSans.ttf")
var content: VBoxContainer
var status: Label

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	var background := ColorRect.new()
	background.color = Color(0.19, 0.48, 0.69)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var container := CenterContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	container.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 35)
	margin.add_theme_constant_override("margin_right", 35)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	margin.add_child(content)
	show_main()

func clear_content() -> void:
	for item in content.get_children():
		content.remove_child(item)
		item.queue_free()

func add_text(text: String, size: int) -> Label:
	var item := Label.new()
	item.text = text
	item.text_direction = Control.TEXT_DIRECTION_RTL
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_override("font", PERSIAN_FONT)
	item.add_theme_font_size_override("font_size", size)
	content.add_child(item)
	return item

func add_button(text: String, callback: Callable) -> void:
	var item := Button.new()
	item.text = text
	item.text_direction = Control.TEXT_DIRECTION_RTL
	item.custom_minimum_size.y = 76
	item.add_theme_font_override("font", PERSIAN_FONT)
	item.add_theme_font_size_override("font_size", 28)
	item.pressed.connect(callback)
	content.add_child(item)

func show_main() -> void:
	clear_content()
	add_text("تکامل زامبی‌ها", 42)
	add_text("مرحله ۱ – پل آسمانی", 28)
	add_button("شروع بازی", func(): get_tree().change_scene_to_file("res://scenes/level/sky_bridge.tscn"))
	add_button("تنظیمات", show_settings)
	add_button("خروج", func(): get_tree().quit())

func show_settings() -> void:
	clear_content()
	add_text("تنظیمات", 38)
	add_button("صدا: روشن" if Preferences.sound_enabled else "صدا: خاموش", toggle_sound)
	add_button("حالت کم‌مصرف: روشن" if Preferences.low_power else "حالت کم‌مصرف: خاموش", toggle_power)
	status = add_text("", 20)
	add_button("بازگشت", show_main)

func toggle_sound() -> void:
	Preferences.sound_enabled = not Preferences.sound_enabled
	save_and_refresh()

func toggle_power() -> void:
	Preferences.low_power = not Preferences.low_power
	save_and_refresh()

func save_and_refresh() -> void:
	Preferences.apply_settings()
	var result: Error = Preferences.save_settings()
	show_settings()
	if result != OK:
		status.text = "ذخیره تنظیمات ممکن نشد."
