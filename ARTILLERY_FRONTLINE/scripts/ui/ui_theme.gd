class_name UITheme
extends RefCounted
## Look of the interface: scorched steel plates, amber for the player's own
## systems, red for anything that is going wrong.
##
## Sizes are in canvas units. The canvas is 810 units high on 16:9 and wider
## screens (a narrower one, such as a 4:3 tablet, keeps the 1440 width and
## grows taller). On a 6.5-inch 20:9 phone one unit is about 0.084 mm: an
## 88-unit control is 7.4 mm, just under Android's 48 dp (7.6 mm), and 26-unit
## text is 2.2 mm, about 14 sp.

const INK := Color(0.035, 0.04, 0.045, 0.95)
const PANEL := Color(0.055, 0.06, 0.065, 0.92)
const PLATE := Color(0.13, 0.135, 0.14, 0.95)
## Backing of HUD read-outs: dark enough to carry text over a sunlit wall, thin enough to see through.
const HUD_PLATE := Color(0.025, 0.03, 0.035, 0.6)
const LINE := Color(0.62, 0.58, 0.49, 0.55)
const TEXT := Color(0.96, 0.94, 0.88)
const MUTED := Color(0.76, 0.74, 0.68)
const AMBER := Color(0.98, 0.7, 0.2)
const RED := Color(0.94, 0.25, 0.18)
const GREEN := Color(0.56, 0.82, 0.46)
const FONT_DIR: String = "res://assets/fonts/"
## Smallest side of anything meant to be touched in a menu.
const TOUCH: float = 88.0
const BODY: int = 26
const SMALL: int = 22
## Rajdhani is drawn small on its body; this brings Latin text up to the weight of the Persian beside it.
const LATIN_SCALE: float = 1.12

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


## Font size for text designed at `size` units, in the language now shown.
static func font_size(size: int) -> int:
	return int(round(float(size) * (1.0 if Loc.language == "fa" else LATIN_SCALE)))


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
	style.anti_aliasing = true
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
	shared.set_stylebox("normal", "Button", box(PLATE, LINE, 6, 1, 24))
	shared.set_stylebox("hover", "Button", box(PLATE.lightened(0.06), AMBER, 6, 1, 24))
	shared.set_stylebox("pressed", "Button", box(PLATE.darkened(0.3), AMBER, 6, 2, 24))
	shared.set_stylebox("disabled", "Button", box(Color(0.1, 0.1, 0.1, 0.6), Color(0.3, 0.3, 0.3, 0.4), 6, 1, 24))
	shared.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		shared.set_color(key, "Button", TEXT)
	shared.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 10, 1, 28))
	shared.set_stylebox("panel", "Panel", box(PANEL, LINE, 10, 1, 28))
	return shared


## Call after the language changes: the shared theme keeps the right script first.
static func refresh_fonts() -> void:
	if shared == null:
		return
	shared.default_font = font(false)
	shared.default_font_size = font_size(BODY)
	shared.set_font("font", "Button", font(true))
	shared.set_font_size("font_size", "Button", font_size(30))


## A label that remembers how it was meant to look, so `restyle` can redo it in another language.
static func label(text: String, size: int = BODY, color: Color = TEXT, heavy: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.set_meta("heavy", heavy)
	node.set_meta("base_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	restyle(node)
	return node


static func restyle(node: Label) -> void:
	node.add_theme_font_override("font", font(node.get_meta("heavy", false)))
	node.add_theme_font_size_override("font_size", font_size(int(node.get_meta("base_size", BODY))))


## Dark rim around the glyphs, for text that sits straight on the picture with no plate behind it.
static func outline(node: Label, width: int = 6) -> Label:
	node.add_theme_constant_override("outline_size", width)
	node.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	return node


## `style`: "plain", "accent" (the one thing this screen is for) or "danger" (asks to be confirmed).
static func button(text: String, action: Callable, style: Variant = "plain", sound: String = "click") -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, TOUCH)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_override("font", font(true))
	node.add_theme_font_size_override("font_size", font_size(30))
	# Older callers passed `true` for the accent look.
	var look: String = ("accent" if style else "plain") if style is bool else String(style)
	paint_button(node, look)
	node.pressed.connect(func() -> void:
		Sound.play(sound, -8.0)
		action.call())
	return node


static func paint_button(node: Button, look: String) -> void:
	for key: String in ["normal", "hover", "pressed"]:
		node.remove_theme_stylebox_override(key)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.remove_theme_color_override(key)
	var tone: Color = AMBER if look == "accent" else RED
	if look == "accent" or look == "danger":
		node.add_theme_stylebox_override("normal", box(tone.darkened(0.12), tone.lightened(0.25), 6, 1, 24))
		node.add_theme_stylebox_override("hover", box(tone, Color.WHITE, 6, 1, 24))
		node.add_theme_stylebox_override("pressed", box(tone.darkened(0.35), tone, 6, 2, 24))
		var ink: Color = Color(0.08, 0.06, 0.03) if look == "accent" else Color(1.0, 0.97, 0.94)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			node.add_theme_color_override(key, ink)
