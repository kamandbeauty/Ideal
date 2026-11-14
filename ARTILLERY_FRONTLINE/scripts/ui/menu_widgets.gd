class_name MenuWidgets
extends RefCounted
## Touch-sized controls for the settings screen and the decoration of the
## menus. They follow the layout direction of the screen they are on: in
## Persian a switch is "on" to the left and a slider fills from the right.


class Switch:
	extends Control
	## An on/off switch. The whole row it sits in may forward a tap to `flip`.
	signal toggled(pressed: bool)

	const TRACK := Vector2(88.0, 42.0)

	var pressed: bool = false
	## Where the knob is drawn: slides from 0 (off) to 1 (on).
	var knob: float = 0.0

	func _init(start: bool = false) -> void:
		pressed = start
		knob = 1.0 if start else 0.0
		custom_minimum_size = Vector2(TRACK.x + 8.0, 72.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			flip()
			accept_event()

	func flip() -> void:
		set_pressed(not pressed)

	func set_pressed(value: bool) -> void:
		if pressed == value:
			return
		pressed = value
		Sound.play("ui_toggle", -9.0, 1.0 if pressed else 0.84)
		toggled.emit(pressed)
		queue_redraw()

	func _process(delta: float) -> void:
		var goal: float = 1.0 if pressed else 0.0
		if not is_equal_approx(knob, goal):
			knob = move_toward(knob, goal, delta * 9.0)
			queue_redraw()

	func _draw() -> void:
		var rtl: bool = is_layout_rtl()
		var origin := Vector2(0.0 if rtl else size.x - TRACK.x, (size.y - TRACK.y) * 0.5)
		var radius: float = TRACK.y * 0.5
		var track: Color = Color(0.16, 0.165, 0.17, 0.95).lerp(UITheme.AMBER.darkened(0.25), knob)
		draw_circle(origin + Vector2(radius, radius), radius, track, true, -1.0, true)
		draw_circle(origin + Vector2(TRACK.x - radius, radius), radius, track, true, -1.0, true)
		draw_rect(Rect2(origin + Vector2(radius, 0.0), Vector2(TRACK.x - radius * 2.0, TRACK.y)), track)
		var travel: float = (1.0 - knob) if rtl else knob
		var middle := origin + Vector2(lerpf(radius, TRACK.x - radius, travel), radius)
		draw_circle(middle, radius - 5.0, Color(0.97, 0.95, 0.9) if pressed else Color(0.62, 0.62, 0.6), true, -1.0, true)


class SlideBar:
	extends Control
	## A slider with a grabber big enough for a thumb; the whole height of its row takes the drag.
	signal value_changed(value: float)
	signal released

	const PAD: float = 20.0

	var min_value: float = 0.0
	var max_value: float = 1.0
	var step: float = 0.05
	var value: float = 0.0
	var dragging: bool = false

	func _init(low: float = 0.0, high: float = 1.0, by: float = 0.05, start: float = 0.0) -> void:
		min_value = low
		max_value = high
		step = by
		value = clampf(start, low, high)
		custom_minimum_size = Vector2(300.0, 72.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed:
				set_from(event.position.x)
			else:
				released.emit()
			queue_redraw()
			accept_event()
		elif event is InputEventMouseMotion and dragging:
			set_from(event.position.x)
			accept_event()

	func fraction() -> float:
		return clampf((value - min_value) / maxf(max_value - min_value, 0.0001), 0.0, 1.0)

	## Moves the value to where `x` (in this control's coordinates) falls on the track.
	func set_from(x: float) -> void:
		var along: float = clampf((x - PAD) / maxf(size.x - PAD * 2.0, 1.0), 0.0, 1.0)
		if is_layout_rtl():
			along = 1.0 - along
		set_value(lerpf(min_value, max_value, along))

	func set_value(raw: float) -> void:
		var stepped: float = clampf(min_value + snappedf(raw - min_value, step), min_value, max_value)
		if is_equal_approx(stepped, value):
			return
		value = stepped
		value_changed.emit(value)
		queue_redraw()

	func _draw() -> void:
		var rtl: bool = is_layout_rtl()
		var y: float = size.y * 0.5
		var from: float = PAD
		var to: float = size.x - PAD
		var at: float = lerpf(to, from, fraction()) if rtl else lerpf(from, to, fraction())
		draw_line(Vector2(from, y), Vector2(to, y), Color(0.0, 0.0, 0.0, 0.7), 10.0)
		draw_circle(Vector2(from, y), 5.0, Color(0.0, 0.0, 0.0, 0.7))
		draw_circle(Vector2(to, y), 5.0, Color(0.0, 0.0, 0.0, 0.7))
		draw_line(Vector2(to if rtl else from, y), Vector2(at, y), UITheme.AMBER, 6.0)
		draw_circle(Vector2(at, y), 22.0 if dragging else 18.0, Color(0.97, 0.95, 0.9), true, -1.0, true)
		draw_arc(Vector2(at, y), 22.0 if dragging else 18.0, 0.0, TAU, 32, UITheme.AMBER, 3.0, true)


class Glyph:
	extends Control
	## An outline from the HUD's icon set, drawn in the middle of its box.
	var kind: String = "gun"
	var length: float = 80.0
	var ink: Color = UITheme.TEXT

	func _init(icon: String = "gun", icon_length: float = 80.0) -> void:
		kind = icon
		length = icon_length
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_ink(color: Color) -> void:
		if ink != color:
			ink = color
			queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		HudWidgets.draw_icon(self, kind, size * 0.5, length, ink)


class Choices:
	extends GridContainer
	## A row (or two) of choices of which exactly one is lit. A choice may carry an outline over its
	## name, and may be locked: drawn dim under a padlock, and deaf to the thumb.
	signal chosen(index: int)

	## Height of the strip an outline is drawn in, above the name of its choice.
	const GLYPH_STRIP: float = 40.0

	var buttons: Array[Button] = []
	var glyphs: Array[Glyph] = []
	var locked: Array[int] = []
	var selected: int = -1

	func _init(labels: Array = [], start: int = 0, icons: Array = [], wrap_after: int = 0) -> void:
		# One row unless the caller asks to wrap (the title's five guns).
		if wrap_after > 0 and labels.size() > wrap_after:
			columns = wrap_after
		else:
			columns = maxi(labels.size(), 1)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_constant_override("h_separation", 6)
		add_theme_constant_override("v_separation", 6)
		for index: int in labels.size():
			var button := Button.new()
			button.text = labels[index]
			button.focus_mode = Control.FOCUS_NONE
			button.clip_text = false
			button.autowrap_mode = TextServer.AUTOWRAP_OFF
			button.custom_minimum_size = Vector2(0.0, 84.0)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_override("font", UITheme.font(true))
			var type_size: int = 24 if icons.is_empty() else (18 if labels.size() >= 5 else 21)
			button.add_theme_font_size_override("font_size", UITheme.font_size(type_size))
			button.pressed.connect(_choose.bind(index))
			add_child(button)
			buttons.append(button)
			var glyph: Glyph = null
			if index < icons.size() and String(icons[index]) != "":
				glyph = Glyph.new(String(icons[index]), 84.0)
				glyph.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
				glyph.offset_top = 4.0
				glyph.offset_bottom = GLYPH_STRIP
				button.add_child(glyph)
			glyphs.append(glyph)
		select(start)

	func select(index: int) -> void:
		selected = index
		for place: int in buttons.size():
			var button: Button = buttons[place]
			var lit: bool = place == index
			var back: Color = UITheme.AMBER.darkened(0.1) if lit else UITheme.PLATE
			var rim: Color = UITheme.AMBER.lightened(0.25) if lit else UITheme.LINE
			var ink: Color = Color(0.08, 0.06, 0.03) if lit else UITheme.TEXT
			if locked.has(place):
				back = Color(0.085, 0.088, 0.092, 0.8)
				rim = Color(0.34, 0.33, 0.3, 0.5)
				ink = Color(UITheme.MUTED, 0.55)
			for key: String in ["normal", "hover", "pressed", "disabled"]:
				var style: StyleBoxFlat = UITheme.box(back, rim, 6, 1, 12)
				if glyphs[place] != null:
					# The name sits under its outline.
					style.content_margin_top = GLYPH_STRIP
					style.content_margin_bottom = 4.0
				button.add_theme_stylebox_override(key, style)
			for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
				button.add_theme_color_override(key, ink)
			if glyphs[place] != null:
				glyphs[place].set_ink(ink)

	## Closes a choice: it cannot be taken until whatever opens it has happened.
	func lock(index: int) -> void:
		if index < 0 or index >= buttons.size() or locked.has(index):
			return
		locked.append(index)
		buttons[index].disabled = true
		var padlock := Glyph.new("lock", 22.0)
		padlock.ink = Color(UITheme.MUTED, 0.8)
		padlock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		padlock.offset_left = -34.0
		padlock.offset_top = 6.0
		padlock.offset_right = -6.0
		padlock.offset_bottom = 34.0
		buttons[index].add_child(padlock)
		select(selected)

	func is_locked(index: int) -> bool:
		return locked.has(index)

	func _choose(index: int) -> void:
		if index == selected or locked.has(index):
			return
		select(index)
		Sound.play("ui_toggle", -9.0)
		chosen.emit(index)


class Row:
	extends HBoxContainer
	## One setting: its name at the reading edge, its control at the other. A tap anywhere on a switch row flips the switch.
	var toggle: Switch

	func _init() -> void:
		add_theme_constant_override("separation", 16)
		# The whole row is the target, and it is as tall as a button.
		custom_minimum_size = Vector2(0.0, UITheme.TOUCH)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if toggle != null and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			toggle.flip()
			accept_event()


class Stripes:
	extends Control
	## The yellow-and-black warning tape of the gate, as a rule above a title.
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0.0, 12.0)
		clip_contents = true

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.07, 0.07, 0.95))
		var step: float = size.y * 2.2
		var x: float = -size.y
		while x < size.x + size.y:
			draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), Vector2(x + size.y, 0.0), Vector2(x + size.y + step * 0.5, 0.0),
				Vector2(x + step * 0.5, size.y)]), UITheme.AMBER.darkened(0.08))
			x += step


class Shade:
	extends Control
	## Darkens the side of the screen a menu column stands on and lets the street show on the other.
	var reach: float = 0.62

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED or what == NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
			queue_redraw()

	func _draw() -> void:
		var dark := Color(0.02, 0.022, 0.026, 0.9)
		var clear := Color(0.02, 0.022, 0.026, 0.0)
		var solid: float = size.x * reach * 0.42
		var far: float = size.x * reach
		if is_layout_rtl():
			draw_rect(Rect2(size.x - solid, 0.0, solid, size.y), dark)
			draw_polygon(PackedVector2Array([Vector2(size.x - far, 0.0), Vector2(size.x - solid, 0.0), Vector2(size.x - solid, size.y),
				Vector2(size.x - far, size.y)]), PackedColorArray([clear, dark, dark, clear]))
		else:
			draw_rect(Rect2(0.0, 0.0, solid, size.y), dark)
			draw_polygon(PackedVector2Array([Vector2(solid, 0.0), Vector2(far, 0.0), Vector2(far, size.y), Vector2(solid, size.y)]),
				PackedColorArray([dark, clear, clear, dark]))


class Rule:
	extends Control
	## A hairline between groups.
	var color: Color = UITheme.LINE

	func _init(height: float = 2.0) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0.0, height)

	func _draw() -> void:
		draw_rect(Rect2(0.0, size.y * 0.5 - 0.75, size.x, 1.5), color)


class Pictogram:
	extends Control
	## One of the HUD's pictograms, for use inside a menu row.
	var kind: String = "skull"
	var color: Color = UITheme.TEXT

	func _init(icon: String = "skull", side: float = 30.0, ink: Color = UITheme.TEXT) -> void:
		kind = icon
		color = ink
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(side, side)

	func _draw() -> void:
		HudWidgets.draw_icon(self, kind, size * 0.5, minf(size.x, size.y), color)
