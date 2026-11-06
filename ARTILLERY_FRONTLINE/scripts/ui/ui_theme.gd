class_name UITheme
extends RefCounted
const INK := Color(0.055, 0.085, 0.073, 0.96)
const PANEL := Color(0.065, 0.092, 0.080, 0.80)
const LINE := Color(0.46, 0.50, 0.38, 0.62)
const TEXT := Color(0.91, 0.91, 0.82)
const MUTED := Color(0.59, 0.65, 0.56)
const ACCENT := Color(0.86, 0.69, 0.40)
const GREEN := Color(0.49, 0.70, 0.54)
const RED := Color(0.85, 0.36, 0.25)
static var regular: Font = load("res://assets/fonts/Rajdhani-Medium.ttf")
static var bold: Font = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
static var shared_theme: Theme

static func theme() -> Theme:
	if shared_theme:
		return shared_theme
	shared_theme = Theme.new()
	shared_theme.default_font = regular
	shared_theme.default_font_size = 20
	shared_theme.set_color("font_color", "Label", TEXT)
	shared_theme.set_stylebox("normal", "Button", style(PANEL, LINE))
	shared_theme.set_stylebox("hover", "Button", style(Color(0.16, 0.21, 0.16), ACCENT))
	shared_theme.set_stylebox("pressed", "Button", style(Color(0.24, 0.28, 0.19), ACCENT))
	shared_theme.set_stylebox("disabled", "Button", style(Color(0.07, 0.09, 0.075, 0.8), Color(0.2, 0.24, 0.19)))
	shared_theme.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), ACCENT))
	shared_theme.set_font("font", "Button", bold)
	shared_theme.set_font_size("font_size", "Button", 21)
	for property in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		shared_theme.set_color(property, "Button", TEXT)
	shared_theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.25))
	shared_theme.set_stylebox("panel", "PanelContainer", style(PANEL, LINE))
	shared_theme.set_stylebox("panel", "Panel", style(PANEL, LINE))
	shared_theme.set_stylebox("background", "ProgressBar", style(Color(0.12, 0.15, 0.12), LINE))
	shared_theme.set_stylebox("fill", "ProgressBar", style(ACCENT.darkened(0.2), ACCENT))
	return shared_theme

static func style(background: Color, border: Color, radius: int = 5) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

static func label(text: String, size: int = 20, color: Color = TEXT, heavy: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_font_override("font", bold if heavy else regular)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(text: String, action: Callable, accent: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 52
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if accent:
		node.add_theme_stylebox_override("normal", style(ACCENT, ACCENT))
		node.add_theme_stylebox_override("hover", style(ACCENT.lightened(0.12), TEXT))
		node.add_theme_stylebox_override("pressed", style(ACCENT.darkened(0.15), ACCENT))
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			node.add_theme_color_override(key, INK)
	node.pressed.connect(func(): Sound.play_ui(); action.call())
	return node

static func column(separation: int = 12) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node

static func row(separation: int = 12) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node

static func panel(child: Control, padding: int = 22) -> PanelContainer:
	var node := PanelContainer.new()
	var box: StyleBoxFlat = style(PANEL, LINE).duplicate()
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	node.add_theme_stylebox_override("panel", box)
	node.add_child(child)
	return node

static func rule() -> HSeparator:
	var node := HSeparator.new()
	node.add_theme_color_override("color", LINE)
	return node

static func wrapped(text: String, size: int = 20, color: Color = MUTED) -> Label:
	var node := label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node
