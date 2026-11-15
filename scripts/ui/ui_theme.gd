class_name UiTheme
extends RefCounted
## One place for the palette, fonts and widget styling.
##
## Everything is built in code so the game looks the same without opening the
## editor, and so the Persian font can be the default for every control.

const BG := Color(0.043, 0.051, 0.078)
const PANEL := Color(0.075, 0.094, 0.145, 0.95)
const PANEL_SOFT := Color(0.11, 0.14, 0.2, 0.92)
const BORDER := Color(0.24, 0.32, 0.46)
const TEXT := Color(0.88, 0.92, 0.98)
const MUTED := Color(0.6, 0.68, 0.8)
const ACCENT := Color(0.4, 0.79, 1.0)
const GOLD := Color(1.0, 0.81, 0.35)
const DANGER := Color(1.0, 0.44, 0.44)
const GOOD := Color(0.46, 0.92, 0.6)

const FONT_REGULAR := "res://assets/fonts/Vazirmatn-Medium.ttf"
const FONT_BOLD := "res://assets/fonts/Vazirmatn-Bold.ttf"
const FONT_TITLE := "res://assets/fonts/Vazirmatn-Black.ttf"


## The soft dark edge that keeps the HUD readable over a bright desert.
static func vignette_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.0))
	gradient.set_color(1, Color(0.02, 0.03, 0.06, 0.5))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.05, 0.5)
	texture.width = 256
	texture.height = 256
	return texture


static func build() -> Theme:
	var theme := Theme.new()
	var regular: Font = load(FONT_REGULAR)
	var bold: Font = load(FONT_BOLD)

	theme.default_font = regular
	theme.default_font_size = 19
	for type_name in ["Label", "Button", "LineEdit", "RichTextLabel"]:
		theme.set_font("font", type_name, regular)

	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("panel", "Panel", panel_style())

	_register_button_variation(theme, "Button", PANEL_SOFT, BORDER, TEXT)
	_register_button_variation(theme, "PrimaryButton", Color(0.16, 0.38, 0.58), ACCENT, TEXT)
	_register_button_variation(theme, "DangerButton", Color(0.34, 0.16, 0.2), DANGER, TEXT)
	_register_button_variation(theme, "GhostButton", Color(0, 0, 0, 0), BORDER, MUTED)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	theme.set_font("font", "TitleLabel", bold)
	return theme


static func _register_button_variation(
	theme: Theme, type_name: String, fill: Color, border: Color, text: Color
) -> void:
	if type_name != "Button":
		theme.add_type(type_name)
		theme.set_type_variation(type_name, "Button")
		theme.set_font("font", type_name, load(FONT_BOLD))
	theme.set_stylebox("normal", type_name, button_style(fill, border))
	theme.set_stylebox("hover", type_name, button_style(fill.lightened(0.08), border.lightened(0.2)))
	theme.set_stylebox("pressed", type_name, button_style(fill.darkened(0.15), border))
	theme.set_stylebox("disabled", type_name, button_style(fill.darkened(0.35), border.darkened(0.45)))
	theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	theme.set_color("font_color", type_name, text)
	theme.set_color("font_hover_color", type_name, TEXT)
	theme.set_color("font_pressed_color", type_name, TEXT)
	theme.set_color("font_disabled_color", type_name, MUTED.darkened(0.35))


static func button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


static func slim_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


static func pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.094, 0.145, 0.88)
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
