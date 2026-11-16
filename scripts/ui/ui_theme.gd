class_name UiTheme
extends RefCounted
## Roadside Empire casual tycoon UI palette, fonts and button variations.

const BG := Color(0.11, 0.13, 0.20)
const PANEL := Color(0.13, 0.16, 0.25, 0.97)
const PANEL_SOFT := Color(0.19, 0.23, 0.35, 0.95)
const BORDER := Color(0.30, 0.39, 0.56)
const TEXT := Color(0.96, 0.97, 1.0)
const DARK_TEXT := Color(0.20, 0.16, 0.13)
const MUTED := Color(0.68, 0.74, 0.86)
const ACCENT := Color(0.32, 0.78, 1.0)
const GOLD := Color(1.0, 0.78, 0.18)
const BOURBON := Color(0.94, 0.56, 0.18)
const GEM_PINK := Color(1.0, 0.34, 0.68)
const DANGER := Color(0.95, 0.26, 0.24)
const GOOD := Color(0.26, 0.82, 0.30)
const PURPLE := Color(0.47, 0.35, 0.96)
const CREAM := Color(0.97, 0.94, 0.88)
const CREAM_BORDER := Color(0.78, 0.70, 0.58)

const FONT_REGULAR := "res://assets/fonts/Vazirmatn-Medium.ttf"
const FONT_BOLD := "res://assets/fonts/Vazirmatn-Bold.ttf"
const FONT_TITLE := "res://assets/fonts/Vazirmatn-Black.ttf"


static func vignette_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.0))
	gradient.set_color(1, Color(0.06, 0.05, 0.08, 0.22))
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
	_register_button(theme, "PrimaryButton", GOOD, GOOD.darkened(0.28), Color.WHITE)
	_register_button(theme, "GreenButton", GOOD, GOOD.darkened(0.30), Color.WHITE)
	_register_button(theme, "PurpleButton", PURPLE, PURPLE.darkened(0.30), Color.WHITE)
	_register_button(theme, "NavButton", Color(0.24, 0.29, 0.42), Color(0.14, 0.17, 0.26), Color.WHITE)
	_register_button(theme, "CreamCard", CREAM, CREAM_BORDER, DARK_TEXT)
	_register_button(theme, "DangerButton", Color(0.46, 0.18, 0.20), DANGER, Color.WHITE)
	_register_button(theme, "GhostButton", Color(0.15, 0.18, 0.28, 0.85), BORDER, TEXT)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_font("font", "TitleLabel", bold)
	return theme


static func _register_button(
	theme: Theme, type_name: String, fill: Color, border: Color, text: Color
) -> void:
	if type_name != "Button":
		theme.add_type(type_name)
		theme.set_type_variation(type_name, "Button")
		theme.set_font("font", type_name, load(FONT_BOLD))
	theme.set_stylebox("normal", type_name, button_style(fill, border))
	theme.set_stylebox("hover", type_name, button_style(fill.lightened(0.08), border.lightened(0.15)))
	theme.set_stylebox("pressed", type_name, button_style(fill.darkened(0.12), border))
	theme.set_stylebox("disabled", type_name, button_style(Color(0.22, 0.25, 0.32, 0.85), Color(0.16, 0.18, 0.24)))
	theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	theme.set_color("font_color", type_name, text)
	theme.set_color("font_hover_color", type_name, text)
	theme.set_color("font_pressed_color", type_name, text)
	theme.set_color("font_disabled_color", type_name, MUTED.darkened(0.25))


static func button_style(fill: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 4
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	return style


static func dark_pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.15, 0.20, 0.92)
	style.border_color = Color(0.08, 0.09, 0.13)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


static func gold_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GOLD
	style.border_color = Color(0.45, 0.26, 0.04)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func cream_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = CREAM_BORDER
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 4
	style.set_corner_radius_all(12)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 7
	return style


static func green_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GOOD
	style.border_color = GOOD.darkened(0.32)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 4
	style.set_corner_radius_all(12)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 7
	return style


static func red_arrow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.22, 0.20)
	style.border_color = Color(0.55, 0.10, 0.10)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


static func slim_style(fill: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


static func pill_style() -> StyleBoxFlat:
	return dark_pill_style()


static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
