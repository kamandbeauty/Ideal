class_name GuildTheme
extends RefCounted
## The guild's palette and widgets: deep blue and violet, turquoise highlights and
## gold for money. Built in code, with the bundled Vazirmatn font as the default so
## Persian text shapes correctly without changing a single layout decision.

const BG := Color(0.055, 0.06, 0.11, 0.92)
const PANEL := Color(0.09, 0.1, 0.18, 0.88)
const PANEL_SOFT := Color(0.13, 0.15, 0.25, 0.82)
const BORDER := Color(0.3, 0.36, 0.6, 0.85)
const TEXT := Color(0.9, 0.93, 1.0)
const MUTED := Color(0.62, 0.68, 0.85)
const TURQUOISE := Color(0.36, 0.86, 0.87)
const GOLD := Color(0.94, 0.78, 0.4)
const VIOLET := Color(0.55, 0.42, 0.92)
const DANGER := Color(0.95, 0.45, 0.5)

const FONT_REGULAR := "res://assets/fonts/Vazirmatn-Medium.ttf"
const FONT_BOLD := "res://assets/fonts/Vazirmatn-Bold.ttf"


static func panel_style(color: Color = PANEL, radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func action_style(color: Color, radius: int = 74) -> StyleBoxFlat:
	var style := panel_style(color, radius)
	style.border_color = color.lightened(0.35)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	return style


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Money reads in the same Latin digits in both languages, so a counter never
## changes width when the player switches to Persian.
static func money(value: float, language: String = "en") -> String:
	return GuildLocale.t("hud.gold", [], language) + " " + GuildLocale.format_money(value)


static func font_file(bold: bool = false) -> Font:
	var path := FONT_BOLD if bold else FONT_REGULAR
	var loaded := load(path)
	if loaded is Font:
		return loaded as Font
	return null


static func build() -> Theme:
	var theme := Theme.new()
	var regular := font_file(false)
	if regular != null:
		theme.default_font = regular
	theme.default_font_size = 18
	theme.set_stylebox("panel", "Panel", panel_style())
	theme.set_color("font_color", "Label", TEXT)
	return theme
