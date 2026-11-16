class_name UiTheme
extends RefCounted
## Sunny toy-town UI: orange header, white outlined cards, blue progress and
## large pictorial navigation. Text colours are dark enough on light surfaces.

const BG := Color("#e8efcf")
const PANEL := Color("#fffdf7")
const PANEL_SOFT := Color("#edf1e6")
const BORDER := CartoonPalette.INK
const TEXT := CartoonPalette.INK
const DARK_TEXT := CartoonPalette.INK
const MUTED := Color("#56616b")
const ACCENT := Color("#086e9f")
const GOLD := Color("#97520b")
const BOURBON := Color("#98520e")
const GEM_PINK := Color("#b7246a")
const DANGER := Color("#b43230")
const GOOD := CartoonPalette.POSITIVE_TEXT
const BLUE := CartoonPalette.BLUE
const ORANGE := CartoonPalette.ORANGE
const CREAM := Color("#fffdf7")
const CREAM_BORDER := CartoonPalette.INK
const TRACK := Color("#d7dfdd")
const SCRIM := Color(0.12, 0.18, 0.23, 0.50)

const FONT_REGULAR := "res://assets/fonts/Vazirmatn-Medium.ttf"
const FONT_BOLD := "res://assets/fonts/Vazirmatn-Bold.ttf"
const FONT_TITLE := "res://assets/fonts/Vazirmatn-Black.ttf"


static func vignette_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.0))
	gradient.set_color(1, Color(0.14, 0.23, 0.26, 0.035))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.08, 0.5)
	texture.width = 256
	texture.height = 256
	return texture


static func build() -> Theme:
	var theme := Theme.new()
	var regular: Font = load(FONT_REGULAR)
	var bold: Font = load(FONT_BOLD)
	theme.default_font = bold
	theme.default_font_size = 18
	for type_name in ["Label", "Button", "LineEdit", "RichTextLabel"]:
		theme.set_font("font", type_name, bold if type_name != "RichTextLabel" else regular)
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("panel", "Panel", panel_style())
	_register_button(theme, "Button", PANEL_SOFT, BORDER, TEXT)
	_register_button(theme, "PrimaryButton", CartoonPalette.ACTION_GREEN, BORDER, Color.WHITE)
	_register_button(theme, "GreenButton", CartoonPalette.ACTION_GREEN, BORDER, Color.WHITE)
	_register_button(theme, "BlueButton", BLUE, BORDER, Color.WHITE)
	_register_button(theme, "OrangeButton", ORANGE, BORDER, DARK_TEXT)
	_register_button(theme, "NavButton", CREAM, BORDER, TEXT)
	_register_button(theme, "CreamCard", CREAM, BORDER, DARK_TEXT)
	_register_button(theme, "DangerButton", Color("#f7d5c4"), BORDER, DANGER)
	_register_button(theme, "GhostButton", Color("#f3f3e9"), BORDER, TEXT)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_font("font", "TitleLabel", load(FONT_TITLE))
	return theme


static func _register_button(theme: Theme, type_name: String, fill: Color, border: Color, text: Color) -> void:
	if type_name != "Button":
		theme.add_type(type_name)
		theme.set_type_variation(type_name, "Button")
		theme.set_font("font", type_name, load(FONT_BOLD))
	theme.set_stylebox("normal", type_name, button_style(fill, border))
	theme.set_stylebox("hover", type_name, button_style(fill.lightened(0.08), border))
	theme.set_stylebox("pressed", type_name, button_style(fill.darkened(0.10), border))
	theme.set_stylebox("disabled", type_name, button_style(Color("#d4d8d2"), Color("#8e999a")))
	theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	theme.set_color("font_color", type_name, text)
	theme.set_color("font_hover_color", type_name, text)
	theme.set_color("font_pressed_color", type_name, text)
	theme.set_color("font_disabled_color", type_name, Color("#606c72"))
	if text == Color.WHITE:
		# White display lettering with a dark keyline, like the device reference.
		theme.set_color("font_outline_color", type_name, Color(0.10, 0.18, 0.22, 0.85))
		theme.set_constant("outline_size", type_name, 2)


static func button_style(fill: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.border_width_bottom = 4
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	return style


static func header_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ORANGE
	style.border_color = BORDER
	style.border_width_bottom = 3
	return style


## Legacy helper name; badges now use clean white instead of dark navy.
static func dark_pill_style() -> StyleBoxFlat:
	var style := button_style(CREAM, BORDER, 12)
	style.border_width_bottom = 3
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func gold_badge_style() -> StyleBoxFlat:
	var style := dark_pill_style()
	style.bg_color = CartoonPalette.YELLOW
	return style


static func cream_card_style() -> StyleBoxFlat:
	var style := button_style(CREAM, BORDER, 9)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 10
	return style


static func green_card_style() -> StyleBoxFlat:
	var style := cream_card_style()
	style.border_color = GOOD
	style.border_width_bottom = 5
	return style


static func red_arrow_style() -> StyleBoxFlat:
	var style := button_style(Color("#db2555"), BORDER, 18)
	style.set_border_width_all(2)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


static func slim_style(fill: Color, border: Color, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


static func pill_style() -> StyleBoxFlat:
	return dark_pill_style()


static func panel_style() -> StyleBoxFlat:
	var style := button_style(PANEL, BORDER, 14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
