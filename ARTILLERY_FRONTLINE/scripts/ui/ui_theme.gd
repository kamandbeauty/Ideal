class_name UITheme
extends RefCounted
## Look of the interface: scorched steel panels, amber for the player's own
## systems, red for anything that is going wrong.

const INK := Color(0.045, 0.05, 0.055, 0.94)
const PANEL := Color(0.07, 0.075, 0.08, 0.88)
const PLATE := Color(0.13, 0.135, 0.14, 0.92)
const LINE := Color(0.6, 0.56, 0.47, 0.55)
const TEXT := Color(0.95, 0.93, 0.87)
const MUTED := Color(0.7, 0.68, 0.62)
const AMBER := Color(0.97, 0.69, 0.2)
const RED := Color(0.92, 0.23, 0.16)
const GREEN := Color(0.55, 0.8, 0.45)
const FONT_DIR: String = "res://assets/fonts/"

static var fonts: Dictionary = {}
static var shared: Theme


## Rajdhani carries Latin text, Vazirmatn carries Persian; each falls back to the other.
static func font(heavy: bool = false) -> Font:
	var key: String = Loc.language + ("_heavy" if heavy else "_regular")
	if fonts.has(key):
		return fonts[key]
	var latin: Font = load(FONT_DIR + ("Rajdhani-SemiBold.ttf" if heavy else "Rajdhani-Medium.ttf"))
	var persian: Font = load(FONT_DIR + ("Vazirmatn-Bold.ttf" if heavy else "Vazirmatn-Medium.ttf"))
	var variation := FontVariation.new()
	if Loc.language == "fa":
		variation.base_font = persian
		variation.fallbacks = [latin]
	else:
		variation.base_font = latin
		variation.fallbacks = [persian]
	fonts[key] = variation
	return variation


static func box(background: Color, border: Color = LINE, radius: int = 8, width: int = 1, padding: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding * 0.6
	style.content_margin_bottom = padding * 0.6
	return style


static func theme() -> Theme:
	if shared != null:
		return shared
	shared = Theme.new()
	refresh_fonts()
	shared.set_color("font_color", "Label", TEXT)
	shared.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.75))
	shared.set_constant("shadow_offset_x", "Label", 1)
	shared.set_constant("shadow_offset_y", "Label", 2)
	shared.set_stylebox("normal", "Button", box(PLATE, LINE, 8, 1, 22))
	shared.set_stylebox("hover", "Button", box(PLATE.lightened(0.08), AMBER, 8, 1, 22))
	shared.set_stylebox("pressed", "Button", box(PLATE.darkened(0.25), AMBER, 8, 2, 22))
	shared.set_stylebox("disabled", "Button", box(Color(0.1, 0.1, 0.1, 0.6), Color(0.3, 0.3, 0.3, 0.4), 8, 1, 22))
	shared.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), AMBER, 8, 2, 22))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		shared.set_color(key, "Button", TEXT)
	shared.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 12, 1, 26))
	shared.set_stylebox("panel", "Panel", box(PANEL, LINE, 12, 1, 26))
	shared.set_stylebox("slider", "HSlider", box(Color(0.02, 0.02, 0.02, 0.9), LINE, 4, 1, 3))
	shared.set_stylebox("grabber_area", "HSlider", box(AMBER.darkened(0.2), AMBER, 4, 0, 3))
	shared.set_stylebox("grabber_area_highlight", "HSlider", box(AMBER, AMBER, 4, 0, 3))
	for key: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		shared.set_stylebox(key, "CheckButton", StyleBoxEmpty.new())
	shared.set_color("font_color", "CheckButton", TEXT)
	shared.set_color("font_pressed_color", "CheckButton", AMBER)
	shared.set_color("font_hover_color", "CheckButton", TEXT)
	shared.set_color("font_hover_pressed_color", "CheckButton", AMBER)
	return shared


## Call after the language changes: the shared theme keeps the right script first.
static func refresh_fonts() -> void:
	if shared == null:
		return
	shared.default_font = font(false)
	shared.default_font_size = 22
	shared.set_font("font", "Button", font(true))
	shared.set_font_size("font_size", "Button", 26)
	shared.set_font("font", "CheckButton", font(false))
	shared.set_font_size("font_size", "CheckButton", 22)


static func label(text: String, size: int = 22, color: Color = TEXT, heavy: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", font(heavy))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func button(text: String, action: Callable, accent: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, 62)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_override("font", font(true))
	if accent:
		node.add_theme_stylebox_override("normal", box(AMBER.darkened(0.12), AMBER.lightened(0.2), 8, 1, 22))
		node.add_theme_stylebox_override("hover", box(AMBER, Color.WHITE, 8, 1, 22))
		node.add_theme_stylebox_override("pressed", box(AMBER.darkened(0.35), AMBER, 8, 2, 22))
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			node.add_theme_color_override(key, Color(0.08, 0.06, 0.03))
	node.pressed.connect(func() -> void:
		Sound.play("click", -8.0)
		action.call())
	return node
