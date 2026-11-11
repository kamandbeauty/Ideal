extends CanvasLayer

signal retry_requested
signal menu_requested

const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
var info: Label
var tip: Label
var end_panel: CenterContainer
var end_box: VBoxContainer

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL
	add_child(root)
	info = make_label(26)
	info.set_anchors_preset(Control.PRESET_TOP_WIDE)
	info.offset_left = 20
	info.offset_right = -20
	info.offset_top = 20
	info.offset_bottom = 180
	root.add_child(info)
	tip = make_label(25)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tip.offset_left = 20
	tip.offset_right = -20
	tip.offset_top = 200
	tip.offset_bottom = 270
	root.add_child(tip)
	end_panel = CenterContainer.new()
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_panel.visible = false
	root.add_child(end_panel)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 350)
	end_panel.add_child(panel)
	end_box = VBoxContainer.new()
	end_box.add_theme_constant_override("separation", 16)
	panel.add_child(end_box)

func make_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.14, 0.2))
	label.add_theme_constant_override("outline_size", 5)
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func digits(value: int) -> String:
	var result := str(value)
	var chars := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for i in range(10):
		result = result.replace(str(i), chars[i])
	return result

func update_status(hp: float, count: int, coins: int, ammo: int, instruction: String) -> void:
	info.text = "مرحله ۱ – پل آسمانی\nسلامتی: %s    تعداد نیروها: %s\nسکه: %s    مهمات: %s" % [digits(int(maxf(hp, 0))), digits(count), digits(coins), digits(ammo)]
	tip.text = instruction

func show_result(win: bool, kills: int, soldiers: int) -> void:
	end_panel.visible = true
	var title := make_label(32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "مرحله با موفقیت به پایان رسید!" if win else "شکست خوردید!"
	end_box.add_child(title)
	var summary := make_label(25)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.text = "زامبی‌های کشته‌شده: %s\nنیروهای باقی‌مانده: %s" % [digits(kills), digits(soldiers)]
	end_box.add_child(summary)
	add_button("تکرار مرحله", retry_requested.emit)
	add_button("منوی اصلی", menu_requested.emit)

func add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.text_direction = Control.TEXT_DIRECTION_RTL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 28)
	button.custom_minimum_size.y = 70
	button.pressed.connect(action)
	end_box.add_child(button)
