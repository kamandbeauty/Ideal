class_name UiKit
extends RefCounted
## The screen kit: every panel, label, button and icon in the port is built by these functions.
##
## Ported from client/Assets/Game/Ui/UiKit.cs, with the same three rules:
##   1. coordinates are dp from the top-left of the design space (415 x 738), y growing downwards;
##   2. no colour or size is invented here — everything comes from UiTokens;
##   3. text goes through PersianText for numerals and is shaped by Godot's own TextServer.
##
## Every rounded corner, bevel, gold rim, switch track and hairline on screen is a PNG in
## `assets/ui/`, drawn once by `tools/make_ui_art.py` and nine-sliced here. StyleBoxFlat survives only
## as the fallback for the case where a texture is missing, because a game whose buttons are rectangles
## the engine painted at runtime is exactly what this port was told to stop doing.

const W := UiTokens.CANVAS_WIDTH
const H := UiTokens.CANVAS_HEIGHT
## Track width of a settings switch. Shared so the screen and the knob agree on the travel.
const SWITCH_WIDTH := 56.0

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

# ---- ui plates (pictures, not rectangles) -------------------------------------------------------

## The UI furniture lives apart from the game art: `assets/ui/` is drawn by `tools/make_ui_art.py`
## from the same palette as `UiTokens`, so a reviewer can diff the two and see that nothing invented a
## colour of its own.
## Backdrops are their own folder and their own size: a screen is 738 x 415 dp of landscape, while the
## Unity plates are square, so scaling one to cover the window cropped it to a random square of itself.
## `assets/backdrops/` holds the painted 1476 x 830 versions; the Unity art stays as the fallback.
const BACKDROP_DIR := "res://assets/backdrops/"

static func backdrop_texture(art_id: String) -> Texture2D:
	if art_id.is_empty():
		return null
	var path := BACKDROP_DIR + art_id + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return texture(art_id)


static func ui_texture(art_id: String) -> Texture2D:
	var path := "res://assets/ui/%s.png" % art_id
	if _textures.has(path):
		return _textures[path] as Texture2D
	var loaded: Texture2D = null
	if ResourceLoader.exists(path):
		loaded = load(path) as Texture2D
	if loaded == null:
		push_warning("[ui art] missing " + path)
	_textures[path] = loaded
	return loaded

## A nine-slice from `assets/ui/`, tinted with `modulate_color` when a caller wants a shade of the
## same plate. Returns null when the picture is missing so every caller can fall back to code.
static func ui_box(art_id: String, border: int, tint: Color = Color(1, 1, 1, 1)) -> StyleBoxTexture:
	var tex := ui_texture(art_id)
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
	style.modulate_color = tint
	return style

static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02

## Which baked plate answers a requested face colour, and which nine-slice border goes with it. The
## pictures are the truth; the tokens are the names they were baked from.
##
## Two sizes exist because a nine-slice can never be drawn smaller than the sum of its margins: a 26 dp
## chip cut from the 96 dp plate would be forced up to 40 dp and spill out of its row. Anything under
## 40 dp tall takes the `_sm` plate and a 12 dp border.
static func plate_is_small(height: float) -> bool:
	return height <= UiTokens.PLATE_SMALL_MAX

static func plate_art(color: Color, height: float = 999.0) -> String:
	var small := "_sm" if plate_is_small(height) else ""
	if _near(color, UiTokens.GOLD):
		return "ui_button_gold" + small
	if _near(color, UiTokens.ACCENT):
		return "ui_button_accent" + small
	if _near(color, UiTokens.DANGER):
		return "ui_button_danger" + small
	if _near(color, UiTokens.SURFACE_RAISED):
		return "ui_panel_raised" + small
	return "ui_panel" + small

static func plate_border(height: float) -> int:
	return UiTokens.BORDER_PLATE_SMALL if plate_is_small(height) else UiTokens.BORDER_PLATE

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
	var art := ui_box(plate_art(color, height), plate_border(height))
	node.add_theme_stylebox_override("panel", art if art != null else box(color, radius))
	parent.add_child(node)
	place(node, x, y, width, height)
	return node

## A panel drawn with its nine-slice art when that art exists, and as a rounded rect when it does not.
static func art_panel(parent: Node, node_name: String, x: float, y: float, width: float, height: float,
		art_id: String, border: int, fallback: Color, radius: int = 0) -> Panel:
	var node := panel(parent, node_name, x, y, width, height, fallback, radius)
	# `ui_*` ids live in `assets/ui/` (drawn or painted plates); everything else is the Unity art the
	# port still ships. Without this, an `ui_` id silently resolved to nothing and the colour picked the
	# plate, which meant the id was decoration rather than a choice.
	var style: StyleBoxTexture = ui_box(art_id, border) if art_id.begins_with("ui_") else art_box(art_id, border)
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
	# `plate_id`, not `art_id`: the parameter of this function is already called art_id, and the
	# engine's parser rejects the shadowing (gdtoolkit's parser does not, which is why CI caught it).
	var plate_id := plate_art(face, height)
	var border_art := plate_border(height)
	var plate := ui_box(plate_id, border_art)
	if plate != null:
		normal = plate
		var hover_plate := ui_box(plate_id, border_art, Color(1.07, 1.07, 1.07, 1))
		var press_plate := ui_box(plate_id, border_art, Color(0.86, 0.86, 0.86, 1))
		var off_plate := ui_box(plate_id, border_art, Color(0.62, 0.62, 0.62, 0.92))
		hover = hover_plate if hover_plate != null else plate
		pressed = press_plate if press_plate != null else plate
		disabled = off_plate if off_plate != null else disabled
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

## A wash over the screen — a picture of a white square, tinted. A ColorRect would be a rectangle the
## engine painted, which is the one thing this kit no longer does.
static func color_rect(parent: Node, node_name: String, color: Color) -> TextureRect:
	var node := TextureRect.new()
	node.name = node_name
	node.texture = ui_texture("ui_veil")
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.modulate = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	place(node, 0.0, 0.0, W, H)
	return node

## A wash that fills a control of any size (a card, a cell), not the whole screen.
static func veil(parent: Node, node_name: String, color: Color) -> TextureRect:
	var node := TextureRect.new()
	node.name = node_name
	node.texture = ui_texture("ui_veil")
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.modulate = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	stretch(node, 0.0, 0.0)
	return node

## A horizontal accent rule: the cheapest ornament that still looks deliberate.
static func rule(parent: Node, x: float, y: float, width: float, color: Color, thickness: float = 2.0) -> TextureRect:
	var node := TextureRect.new()
	node.name = "rule"
	node.texture = ui_texture("ui_rule")
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.modulate = color
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
