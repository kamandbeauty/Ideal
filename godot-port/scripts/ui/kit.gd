class_name UiKit
extends RefCounted
## The screen kit: every panel, label, button and icon in the port is built by these functions.
##
## Ported from client/Assets/Game/Ui/UiKit.cs, with the same three rules:
##   1. coordinates are dp from the top-left of the design space (415 x 738), y growing downwards;
##   2. no colour or size is invented here — everything comes from UiTokens;
##   3. text goes through PersianText for numerals and is shaped by Godot's own TextServer.
##
## Unity generated a rounded-corner sprite at runtime because UI Toolkit/UGUI cannot round a
## rectangle. Godot has StyleBoxFlat, so the port draws the same corners with no texture at all.

const W := UiTokens.CANVAS_WIDTH
const H := UiTokens.CANVAS_HEIGHT

static var _medium: Font = null
static var _bold: Font = null
static var _textures: Dictionary = {}

# ---- fonts --------------------------------------------------------------------------------------

static func medium_font() -> Font:
	if _medium == null:
		_medium = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	return _medium

static func bold_font() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/Vazir-Bold.ttf") as Font
	return _bold

# ---- textures -----------------------------------------------------------------------------------

static func art_path(art_id: String) -> String:
	if art_id.is_empty():
		return ""
	if art_id.begins_with("res://"):
		return art_id
	return "res://assets/art/%s.png" % art_id

static func texture(art_id: String) -> Texture2D:
	var path := art_path(art_id)
	if path.is_empty():
		return null
	if _textures.has(path):
		return _textures[path] as Texture2D
	var loaded: Texture2D = null
	if ResourceLoader.exists(path):
		loaded = load(path) as Texture2D
	if loaded == null:
		push_warning("[art] missing " + path)
	_textures[path] = loaded
	return loaded

static func forget_textures() -> void:
	_textures.clear()

# ---- primitives ---------------------------------------------------------------------------------

static func box(color: Color, radius: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	if radius > 0:
		style.set_corner_radius_all(mini(radius, 40))
		style.corner_detail = 8
		style.anti_aliasing = true
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style

static func art_box(art_id: String, border: int) -> StyleBoxTexture:
	var tex := texture(art_id)
	if tex == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = float(border)
	style.texture_margin_right = float(border)
	style.texture_margin_top = float(border)
	style.texture_margin_bottom = float(border)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style

## Places a control by its top-left corner in design units, like the C# Place().
##
## Deliberately does NOT touch custom_minimum_size: a Control clamps its size up to its own minimum,
## and forcing one here made every label refuse to shrink and then draw itself centred on a rect far
## wider than its pill. Size is the only thing a fixed layout should set.
static func place(control: Control, x: float, y: float, width: float, height: float) -> Control:
	control.position = Vector2(x, y)
	control.size = Vector2(width, height)
	return control

## Fills the parent, inset by the same amount on both sides.
static func stretch(control: Control, inset_x: float = 0.0, inset_y: float = 0.0) -> Control:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = inset_x
	control.offset_top = inset_y
	control.offset_right = -inset_x
	control.offset_bottom = -inset_y
	return control

# ---- building blocks ----------------------------------------------------------------------------

static func panel(parent: Node, node_name: String, x: float, y: float, width: float, height: float,
		color: Color, radius: int = 0) -> Panel:
	var node := Panel.new()
	node.name = node_name
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", box(color, radius))
	parent.add_child(node)
	place(node, x, y, width, height)
	return node

## A panel drawn with its nine-slice art when that art exists, and as a rounded rect when it does not.
static func art_panel(parent: Node, node_name: String, x: float, y: float, width: float, height: float,
		art_id: String, border: int, fallback: Color, radius: int = 0) -> Panel:
	var node := panel(parent, node_name, x, y, width, height, fallback, radius)
	var style := art_box(art_id, border)
	if style != null:
		node.add_theme_stylebox_override("panel", style)
	return node

static func label(parent: Node, node_name: String, text: String, size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_CENTER, bold: bool = false) -> Label:
	var node := Label.new()
	node.name = node_name
	node.text = PersianText.localize(text)
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.layout_direction = Control.LAYOUT_DIRECTION_RTL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", bold_font() if bold else medium_font())
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", UiTokens.SHADOW)
	node.add_theme_constant_override("shadow_offset_y", 1)
	# Without this a Label reports its own text as its minimum width, refuses the rect it is given and
	# spills outside its panel. Autowrap turns clipping off by itself, so wrapping labels are unaffected.
	node.clip_text = true
	parent.add_child(node)
	place(node, 0.0, 0.0, W, float(size) * 1.5)
	return node

## Shrinks a label's font until its text fits the width it was given, and remembers the size it started
## at so a counter that grows and shrinks ("۹" then "۱۲۳") settles back to the design size.
static func fit_font(node: Label, max_width: float, min_size: int = 10) -> void:
	if node == null:
		return
	var font := node.get_theme_font("font")
	if font == null:
		return
	if not node.has_meta("fit_base"):
		node.set_meta("fit_base", node.get_theme_font_size("font_size"))
	var base := int(node.get_meta("fit_base"))
	var text := node.text
	if text.is_empty():
		node.add_theme_font_size_override("font_size", base)
		return
	var size := base
	while size > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 1
	node.add_theme_font_size_override("font_size", size)

## A label whose text is already shaped/numbered by the caller (counters, timers).
static func raw_label(parent: Node, node_name: String, size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_CENTER, bold: bool = false) -> Label:
	return label(parent, node_name, "", size, color, align, bold)

static func set_text(node: Label, text: String) -> void:
	if node != null:
		node.text = PersianText.localize(text)

static func set_number(node: Label, value: int) -> void:
	if node != null:
		node.text = PersianText.number(value)

static func button(parent: Node, node_name: String, text: String, x: float, y: float, width: float,
		height: float, face: Color, label_color: Color, on_press: Callable, radius: int = 0,
		bold: bool = false, art_id: String = "", border: int = 0) -> Button:
	var node := Button.new()
	node.name = node_name
	node.text = PersianText.localize(text)
	node.focus_mode = Control.FOCUS_NONE
	node.layout_direction = Control.LAYOUT_DIRECTION_RTL
	node.add_theme_font_override("font", bold_font() if bold else medium_font())
	node.add_theme_font_size_override("font_size", UiTokens.HUD_BUTTON_LABEL)
	node.add_theme_color_override("font_color", label_color)
	node.add_theme_color_override("font_hover_color", label_color)
	node.add_theme_color_override("font_pressed_color", label_color)
	node.add_theme_color_override("font_disabled_color", UiTokens.TEXT_MUTED)

	var normal: StyleBox = box(face, radius)
	var hover: StyleBox = box(face.lightened(0.08), radius)
	var pressed: StyleBox = box(face.darkened(0.12), radius)
	var disabled: StyleBox = box(Color(face.r, face.g, face.b, face.a * 0.45), radius)
	if not art_id.is_empty():
		var art := art_box(art_id, boundary_or(border, UiTokens.BORDER_BUTTON))
		if art != null:
			normal = art
			hover = art
			pressed = art
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("disabled", disabled)
	node.add_theme_stylebox_override("focus", box(UiTokens.TRANSPARENT))

	parent.add_child(node)
	place(node, x, y, width, height)
	if on_press.is_valid():
		node.pressed.connect(on_press)
	return node

static func boundary_or(value: int, fallback: int) -> int:
	return value if value > 0 else fallback

static func icon(parent: Node, node_name: String, art_id: String, x: float, y: float, width: float,
		height: float) -> TextureRect:
	var node := TextureRect.new()
	node.name = node_name
	node.texture = texture(art_id)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node.texture == null:
		node.visible = false
	parent.add_child(node)
	place(node, x, y, width, height)
	return node

## Full-bleed background picture, the first thing every screen adds.
static func backdrop(parent: Node, art_id: String, tint: Color = Color(0, 0, 0, 0)) -> TextureRect:
	var node := TextureRect.new()
	node.name = "backdrop"
	node.texture = texture(art_id)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	place(node, 0.0, 0.0, W, H)
	if tint.a > 0.0:
		var wash := color_rect(parent, "wash", tint)
		return node
	return node

static func color_rect(parent: Node, node_name: String, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.name = node_name
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	place(node, 0.0, 0.0, W, H)
	return node

## A horizontal accent rule: the cheapest ornament that still looks deliberate.
static func rule(parent: Node, x: float, y: float, width: float, color: Color, thickness: float = 2.0) -> ColorRect:
	var node := ColorRect.new()
	node.name = "rule"
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	place(node, x, y, width, thickness)
	return node

## The 48 dp touch target every button and row in the game respects.
static func hud_button(parent: Node, node_name: String, text: String, x: float, y: float,
		width: float, on_press: Callable, face: Color = UiTokens.SURFACE_RAISED,
		label_color: Color = UiTokens.TEXT) -> Button:
	return button(parent, node_name, text, x, y, width, UiTokens.HUD_TOUCH_TARGET - 8.0, face,
		label_color, on_press, UiTokens.RADIUS_MD)
