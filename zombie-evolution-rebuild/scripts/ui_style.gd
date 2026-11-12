extends RefCounted

static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.095, 0.90)
	style.border_color = Color(0.42, 0.58, 0.64, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.0, 0.02, 0.04, 0.42)
	style.shadow_size = 12
	return style

static func button(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.64, 0.75, 0.75, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style

static func apply_button(control: Button) -> void:
	control.add_theme_stylebox_override("normal", button(Color(0.10, 0.22, 0.27, 0.95)))
	control.add_theme_stylebox_override("hover", button(Color(0.18, 0.35, 0.38, 1)))
	control.add_theme_stylebox_override("pressed", button(Color(0.32, 0.29, 0.16, 1)))
	control.add_theme_color_override("font_color", Color(0.92, 0.95, 0.92))
	control.add_theme_color_override("font_hover_color", Color(1, 1, 1))
