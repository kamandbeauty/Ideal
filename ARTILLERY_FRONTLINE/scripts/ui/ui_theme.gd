class_name UITheme
extends RefCounted
## Shared Persian/RTL theme. Painted key art + nine-patch metal plates replace
## the old flat ColorRect furniture; Vazirmatn supplies shaped Persian glyphs.

const INK := Color(0.055, 0.085, 0.073, 0.96)
const PANEL := Color(0.065, 0.092, 0.080, 0.80)
const LINE := Color(0.46, 0.50, 0.38, 0.62)
const TEXT := Color(0.93, 0.92, 0.84)
const MUTED := Color(0.66, 0.70, 0.60)
const ACCENT := Color(0.88, 0.71, 0.42)
const GREEN := Color(0.52, 0.74, 0.56)
const RED := Color(0.88, 0.38, 0.27)
const UI_DIR: String = "res://assets/textures/ui/"

static var regular: Font = load("res://assets/fonts/Vazirmatn-Medium.ttf")
static var bold: Font = load("res://assets/fonts/Vazirmatn-Bold.ttf")
static var shared_theme: Theme
static var texture_cache: Dictionary = {}


static func texture(file_name: String) -> Texture2D:
	if not texture_cache.has(file_name):
		texture_cache[file_name] = load(UI_DIR + file_name)
	return texture_cache[file_name]


static func plate(file_name: String, padding: int = 18, tint: Color = Color.WHITE) -> StyleBoxTexture:
	## 96×96 authored plate; 16 px corners stay unscaled when stretched.
	var box := StyleBoxTexture.new()
	box.texture = texture(file_name)
	box.texture_margin_left = 16
	box.texture_margin_right = 16
	box.texture_margin_top = 16
	box.texture_margin_bottom = 16
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding * 0.65
	box.content_margin_bottom = padding * 0.65
	box.modulate_color = tint
	return box


static func theme() -> Theme:
	if shared_theme:
		return shared_theme
	shared_theme = Theme.new()
	shared_theme.default_font = regular
	shared_theme.default_font_size = 20
	shared_theme.set_color("font_color", "Label", TEXT)
	shared_theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.72))
	shared_theme.set_constant("shadow_offset_x", "Label", 1)
	shared_theme.set_constant("shadow_offset_y", "Label", 2)
	shared_theme.set_stylebox("normal", "Button", plate("plate_button.png", 18))
	shared_theme.set_stylebox("hover", "Button", plate("plate_button_hover.png", 18))
	shared_theme.set_stylebox("pressed", "Button", plate("plate_button_pressed.png", 18))
	shared_theme.set_stylebox("disabled", "Button", plate("plate_disabled.png", 18))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(10)
	shared_theme.set_stylebox("focus", "Button", focus)
	shared_theme.set_font("font", "Button", bold)
	shared_theme.set_font_size("font_size", "Button", 21)
	for property in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		shared_theme.set_color(property, "Button", TEXT)
	shared_theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.30))
	shared_theme.set_constant("h_separation", "Button", 10)
	shared_theme.set_stylebox("panel", "PanelContainer", plate("plate_panel.png", 20))
	shared_theme.set_stylebox("panel", "Panel", plate("plate_panel.png", 20))
	shared_theme.set_stylebox("background", "ProgressBar", plate("plate_disabled.png", 2, Color(1, 1, 1, 0.8)))
	shared_theme.set_stylebox("fill", "ProgressBar", plate("plate_button_accent.png", 2))
	# Form controls share the same machined-metal language.
	for style_name in ["normal", "hover", "pressed"]:
		shared_theme.set_stylebox(style_name, "OptionButton", plate("plate_button.png", 16))
	shared_theme.set_stylebox("disabled", "OptionButton", plate("plate_disabled.png", 16))
	shared_theme.set_stylebox("focus", "OptionButton", focus)
	shared_theme.set_font("font", "OptionButton", regular)
	shared_theme.set_font_size("font_size", "OptionButton", 19)
	shared_theme.set_color("font_color", "OptionButton", TEXT)
	shared_theme.set_color("font_hover_color", "OptionButton", TEXT)
	shared_theme.set_color("font_pressed_color", "OptionButton", TEXT)
	shared_theme.set_color("font_disabled_color", "OptionButton", MUTED)
	shared_theme.set_icon("arrow", "OptionButton", texture("chevron_down.png"))
	shared_theme.set_stylebox("panel", "PopupMenu", plate("plate_panel.png", 12))
	shared_theme.set_stylebox("hover", "PopupMenu", plate("plate_button_hover.png", 8))
	shared_theme.set_font("font", "PopupMenu", regular)
	shared_theme.set_font_size("font_size", "PopupMenu", 19)
	shared_theme.set_color("font_color", "PopupMenu", TEXT)
	shared_theme.set_color("font_hover_color", "PopupMenu", TEXT)
	shared_theme.set_icon("checked", "CheckButton", texture("check_on.png"))
	shared_theme.set_icon("unchecked", "CheckButton", texture("check_off.png"))
	shared_theme.set_font("font", "CheckButton", regular)
	shared_theme.set_font_size("font_size", "CheckButton", 19)
	shared_theme.set_color("font_color", "CheckButton", TEXT)
	shared_theme.set_color("font_pressed_color", "CheckButton", ACCENT)
	shared_theme.set_stylebox("slider", "HSlider", plate("plate_disabled.png", 3))
	shared_theme.set_stylebox("grabber_area", "HSlider", plate("plate_button_accent.png", 3))
	shared_theme.set_stylebox("grabber_area_highlight", "HSlider", plate("plate_button_accent_hover.png", 3))
	shared_theme.set_icon("grabber", "HSlider", texture("slider_grabber.png"))
	shared_theme.set_icon("grabber_highlight", "HSlider", texture("slider_grabber.png"))
	shared_theme.set_icon("grabber_disabled", "HSlider", texture("slider_grabber.png"))
	shared_theme.set_stylebox("scroll", "VScrollBar", plate("plate_disabled.png", 3))
	shared_theme.set_stylebox("grabber", "VScrollBar", plate("plate_button.png", 3))
	shared_theme.set_stylebox("grabber_highlight", "VScrollBar", plate("plate_button_hover.png", 3))
	shared_theme.set_stylebox("grabber_pressed", "VScrollBar", plate("plate_button_pressed.png", 3))
	shared_theme.set_stylebox("scroll", "HScrollBar", plate("plate_disabled.png", 3))
	shared_theme.set_stylebox("grabber", "HScrollBar", plate("plate_button.png", 3))
	return shared_theme


static func style(background: Color, border: Color, radius: int = 5) -> StyleBoxFlat:
	## Kept for small procedural HUD primitives (pips, health fills, reticles).
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
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	node.text_direction = Control.TEXT_DIRECTION_AUTO
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func button(text: String, action: Callable, accent: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 54
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.text_direction = Control.TEXT_DIRECTION_AUTO
	if accent:
		node.add_theme_stylebox_override("normal", plate("plate_button_accent.png", 18))
		node.add_theme_stylebox_override("hover", plate("plate_button_accent_hover.png", 18))
		node.add_theme_stylebox_override("pressed", plate("plate_button_accent.png", 18, Color(0.78, 0.74, 0.66)))
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			node.add_theme_color_override(key, INK)
	node.pressed.connect(func(): Sound.play_ui(); action.call())
	return node


static func place(node: Control, anchor: Vector4, margin: Vector4) -> void:
	## Explicit anchor placement, components are (left, top, right, bottom).
	## Preset helpers mirror left/right under an RTL parent, which would put the
	## fire controls on the wrong thumb side, so the HUD pins raw anchors here.
	node.anchor_left = anchor.x
	node.anchor_top = anchor.y
	node.anchor_right = anchor.z
	node.anchor_bottom = anchor.w
	node.offset_left = margin.x
	node.offset_top = margin.y
	node.offset_right = margin.z
	node.offset_bottom = margin.w


static func backdrop() -> ColorRect:
	## Opaque floor for full-screen menus so no gameplay frame shows through.
	var node := ColorRect.new()
	node.color = Color(0.02, 0.03, 0.025, 1.0)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	node.add_theme_stylebox_override("panel", plate("plate_panel.png", padding))
	node.add_child(child)
	return node


static func card(child: Control, padding: int = 18) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", plate("plate_card.png", padding))
	node.add_child(child)
	return node


static func rule() -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture("divider.png")
	node.custom_minimum_size.y = 10
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.flip_h = true
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func wrapped(text: String, size: int = 20, color: Color = MUTED) -> Label:
	var node := label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func art(file_name: String, dim: float = 1.0) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture(file_name)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.modulate = Color(dim, dim, dim, 1.0)
	return node


static func overlay(file_name: String, opacity: float = 1.0) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture(file_name)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.modulate.a = opacity
	return node


static func emblem(size_px: float) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture("emblem.png")
	node.custom_minimum_size = Vector2(size_px, size_px)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse(child)
