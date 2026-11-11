class_name HudWidgets
extends RefCounted
## Small custom-drawn controls for the combat HUD. None of them takes input:
## the HUD's touch router decides what each finger is doing.


class Meter:
	extends Control
	## Health bar with a delayed "damage" ghost so a hit reads at a glance.
	var fraction: float = 1.0
	var ghost: float = 1.0
	var flash: float = 0.0
	var broken: bool = false
	## A fixed colour for the bar (an enemy's health); transparent to colour it by how full it is.
	var tint := Color(0.0, 0.0, 0.0, 0.0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_fraction(value: float, quiet: bool = false) -> void:
		value = clampf(value, 0.0, 1.0)
		if value < fraction and not quiet:
			flash = 1.0
		if quiet:
			ghost = value
		fraction = value
		queue_redraw()

	func _process(delta: float) -> void:
		if ghost > fraction or flash > 0.0:
			ghost = maxf(fraction, ghost - delta * 0.35)
			flash = maxf(0.0, flash - delta * 3.0)
			queue_redraw()

	func tone() -> Color:
		if tint.a > 0.0:
			return tint
		if fraction > 0.5:
			return UITheme.GREEN.lerp(UITheme.AMBER, (1.0 - fraction) * 2.0)
		return UITheme.AMBER.lerp(UITheme.RED, clampf((0.5 - fraction) * 2.6, 0.0, 1.0))

	func _draw() -> void:
		var area := Rect2(Vector2.ZERO, size)
		draw_rect(area, Color(0.02, 0.02, 0.025, 0.72))
		if ghost > fraction:
			draw_rect(Rect2(0.0, 0.0, size.x * ghost, size.y), Color(1.0, 0.92, 0.8, 0.75))
		var color: Color = tone().lerp(Color.WHITE, flash * 0.6)
		draw_rect(Rect2(0.0, 0.0, size.x * fraction, size.y), color)
		for step: int in range(1, 10):
			var x: float = size.x * float(step) / 10.0
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(0.0, 0.0, 0.0, 0.35), 1.0)
		draw_rect(area, Color(0.9, 0.86, 0.76, 0.75), false, 2.0)
		if broken:
			draw_line(Vector2(4.0, 3.0), Vector2(size.x - 4.0, size.y - 3.0), UITheme.RED, 3.0)
			draw_line(Vector2(4.0, size.y - 3.0), Vector2(size.x - 4.0, 3.0), UITheme.RED, 3.0)


class RoundButton:
	extends Control
	## A thumb target: drawn only, hit-tested by the router with `contains`.
	var kind: String = "fire"
	var radius: float = 60.0
	var held: bool = false
	var progress: float = 1.0
	var tint: Color = UITheme.AMBER
	## Drawn faint: the button has nothing to give right now.
	var dim: bool = false

	func _init(button_kind: String = "fire", button_radius: float = 60.0) -> void:
		kind = button_kind
		radius = button_radius
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2.ONE * radius * 2.0
		size = custom_minimum_size

	func center() -> Vector2:
		return global_position + size * 0.5

	func contains(point: Vector2, slack: float = 1.15) -> bool:
		return visible and point.distance_to(center()) <= radius * slack

	func set_held(value: bool) -> void:
		if held != value:
			held = value
			queue_redraw()

	func set_progress(value: float) -> void:
		if not is_equal_approx(progress, value):
			progress = value
			queue_redraw()

	func set_dim(value: bool) -> void:
		if dim != value:
			dim = value
			queue_redraw()

	func _draw() -> void:
		var middle: Vector2 = size * 0.5
		var fill := Color(0.05, 0.05, 0.055, 0.5)
		if held:
			fill = Color(tint.r, tint.g, tint.b, 0.42)
		var strength: float = 0.4 if dim else 1.0
		draw_circle(middle, radius, fill)
		draw_arc(middle, radius, 0.0, TAU, 64, Color(tint.r, tint.g, tint.b, (0.95 if held else 0.7) * strength), 3.0, true)
		draw_arc(middle, radius - 7.0, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.12), 1.5, true)
		if progress < 1.0:
			draw_arc(middle, radius - 3.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(1.0, 1.0, 1.0, 0.9), 5.0, true)
		var ink := Color(1.0, 0.97, 0.9, 0.95 * strength)
		match kind:
			"grenade":
				# Egg body, fuze cap, lever and the ring of the pin.
				var body := PackedVector2Array()
				for step: int in 20:
					var angle: float = TAU * float(step) / 20.0
					body.append(middle + Vector2(cos(angle) * radius * 0.3, sin(angle) * radius * 0.37 + radius * 0.1))
				draw_colored_polygon(body, ink)
				draw_rect(Rect2(middle.x - radius * 0.13, middle.y - radius * 0.46, radius * 0.26, radius * 0.22), ink)
				draw_line(middle + Vector2(radius * 0.1, -radius * 0.42), middle + Vector2(radius * 0.42, -radius * 0.12), ink, 3.0, true)
				draw_arc(middle + Vector2(-radius * 0.26, -radius * 0.4), radius * 0.11, 0.0, TAU, 16, ink, 2.5, true)
			"fire":
				var r: float = radius * 0.4
				draw_arc(middle, r, 0.0, TAU, 40, ink, 3.0, true)
				draw_circle(middle, radius * 0.08, ink)
				for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
					var direction := Vector2(cos(angle), sin(angle))
					draw_line(middle + direction * r * 0.72, middle + direction * r * 1.38, ink, 3.0, true)
			"reload":
				var r: float = radius * 0.42
				draw_arc(middle, r, -PI * 0.25, PI * 1.3, 32, ink, 3.5, true)
				var tip: Vector2 = middle + Vector2(cos(-PI * 0.25), sin(-PI * 0.25)) * r
				draw_colored_polygon(PackedVector2Array([tip + Vector2(-2.0, -11.0), tip + Vector2(11.0, 2.0), tip + Vector2(-8.0, 6.0)]), ink)
			"pause":
				var w: float = radius * 0.2
				var h: float = radius * 0.72
				draw_rect(Rect2(middle.x - w * 1.5, middle.y - h * 0.5, w, h), ink)
				draw_rect(Rect2(middle.x + w * 0.5, middle.y - h * 0.5, w, h), ink)


class Crosshair:
	extends Control
	var hit_left: float = 0.0
	var kill: bool = false
	var head: bool = false
	var spread: float = 0.0
	## "cross" for the machine gun, "rocket" for the launcher's ring sight.
	var style: String = "cross"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_style(value: String) -> void:
		if style != value:
			style = value
			queue_redraw()

	func mark(lethal: bool, headshot: bool) -> void:
		hit_left = 0.22 if lethal else 0.14
		kill = lethal
		head = headshot
		queue_redraw()

	func _process(delta: float) -> void:
		if hit_left > 0.0:
			hit_left -= delta
			queue_redraw()
		if spread > 0.0:
			spread = maxf(0.0, spread - delta * 60.0)
			queue_redraw()

	func kick() -> void:
		spread = minf(spread + 2.5, 9.0)

	func _draw() -> void:
		var middle: Vector2 = size * 0.5
		var gap: float = 9.0 + spread
		var ink := Color(1.0, 0.98, 0.92, 0.9)
		var shade := Color(0.0, 0.0, 0.0, 0.55)
		if style == "rocket":
			# Ring sight with a drop mark below it.
			var ring: float = 20.0 + spread
			draw_arc(middle, ring, 0.0, TAU, 40, shade, 4.5, true)
			draw_arc(middle, ring, 0.0, TAU, 40, ink, 2.0, true)
			for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_line(middle + direction * ring, middle + direction * (ring + 9.0), shade, 4.5)
				draw_line(middle + direction * ring, middle + direction * (ring + 9.0), ink, 2.0)
		else:
			for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_line(middle + direction * gap, middle + direction * (gap + 12.0), shade, 4.5)
				draw_line(middle + direction * gap, middle + direction * (gap + 12.0), ink, 2.0)
		draw_circle(middle, 2.6, shade)
		draw_circle(middle, 1.5, ink)
		if hit_left > 0.0:
			var color: Color = UITheme.RED if kill else Color.WHITE
			if head:
				color = UITheme.AMBER if not kill else UITheme.RED
			var inner: float = 7.0
			var outer: float = 18.0 if kill else 14.0
			for direction: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				var unit: Vector2 = direction.normalized()
				draw_line(middle + unit * inner, middle + unit * outer, color, 3.0, true)


class ThreatArrow:
	extends Control
	## Edge-of-screen pointer toward an attacked target that is out of view.
	var side: float = 1.0
	var color: Color = UITheme.RED
	var pulse: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(54, 76)
		size = custom_minimum_size

	func _process(delta: float) -> void:
		if visible:
			pulse += delta * 6.0
			queue_redraw()

	func _draw() -> void:
		var alpha: float = 0.6 + 0.4 * sin(pulse)
		var tone := Color(color.r, color.g, color.b, alpha)
		var middle: Vector2 = size * 0.5
		var shift: float = sin(pulse) * 4.0 * side
		var points := PackedVector2Array([
			middle + Vector2(side * 22.0 + shift, 0.0), middle + Vector2(-side * 12.0 + shift, -30.0),
			middle + Vector2(-side * 2.0 + shift, 0.0), middle + Vector2(-side * 12.0 + shift, 30.0)])
		draw_colored_polygon(points, tone)
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0, 0, 0, 0.6), 2.0, true)


class WeaponSlot:
	extends Control
	## One weapon of the gunner: a card with its outline. The HUD's router
	## hit-tests it with `contains` and writes the round count on a label above it.
	var kind: String = "bullet"
	var active: bool = false
	var spent: bool = false
	var progress: float = 1.0
	var refused: float = 0.0

	func _init(weapon_kind: String = "bullet") -> void:
		kind = weapon_kind
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(132, 58)
		size = custom_minimum_size

	func contains(point: Vector2, slack: float = 6.0) -> bool:
		return visible and Rect2(global_position, size).grow(slack).has_point(point)

	func center() -> Vector2:
		return global_position + size * 0.5

	func set_state(is_active: bool, is_spent: bool, reload_progress: float) -> void:
		if active != is_active or spent != is_spent or not is_equal_approx(progress, reload_progress):
			active = is_active
			spent = is_spent
			progress = reload_progress
			queue_redraw()

	## Flashes red: the player asked for a weapon that has nothing left.
	func refuse() -> void:
		refused = 0.5
		queue_redraw()

	func _process(delta: float) -> void:
		if refused > 0.0:
			refused = maxf(0.0, refused - delta)
			queue_redraw()

	func _draw() -> void:
		var area := Rect2(Vector2.ZERO, size)
		var edge: Color = UITheme.AMBER if active else Color(0.9, 0.86, 0.76, 0.45)
		if refused > 0.0:
			edge = UITheme.RED
		var fill := Color(0.05, 0.05, 0.055, 0.62 if active else 0.42)
		if active:
			fill = Color(UITheme.AMBER.r * 0.22, UITheme.AMBER.g * 0.2, UITheme.AMBER.b * 0.12, 0.66)
		draw_rect(area, fill)
		draw_rect(area, edge, false, 3.0 if active else 1.5)
		var ink := Color(1.0, 0.97, 0.9, 0.95 if active else 0.7)
		if spent:
			ink.a = 0.28
		var base := Vector2(12.0, size.y * 0.5)
		if kind == "rocket":
			# Tube, flared venturi, grips and the warhead.
			draw_line(base + Vector2(14.0, 0.0), base + Vector2(66.0, 0.0), ink, 6.0)
			draw_colored_polygon(PackedVector2Array([base + Vector2(0.0, -8.0), base + Vector2(16.0, -3.0), base + Vector2(16.0, 3.0),
				base + Vector2(0.0, 8.0)]), ink)
			draw_line(base + Vector2(34.0, 3.0), base + Vector2(31.0, 16.0), ink, 4.0)
			draw_line(base + Vector2(48.0, 3.0), base + Vector2(45.0, 16.0), ink, 4.0)
			draw_colored_polygon(PackedVector2Array([base + Vector2(66.0, -2.5), base + Vector2(74.0, -8.5), base + Vector2(84.0, -7.0),
				base + Vector2(100.0, 0.0), base + Vector2(84.0, 7.0), base + Vector2(74.0, 8.5), base + Vector2(66.0, 2.5)]), ink)
		else:
			# Twin barrels on a cradle with its pedestal.
			for offset: float in [-7.0, 7.0]:
				draw_line(base + Vector2(30.0, offset), base + Vector2(100.0, offset), ink, 3.0)
				draw_rect(Rect2(base.x + 6.0, base.y + offset - 4.5, 34.0, 9.0), ink)
				draw_rect(Rect2(base.x + 92.0, base.y + offset - 3.0, 8.0, 6.0), ink)
			draw_rect(Rect2(base.x + 0.0, base.y - 3.0, 10.0, 6.0), ink)
			draw_colored_polygon(PackedVector2Array([base + Vector2(18.0, 12.0), base + Vector2(30.0, 12.0), base + Vector2(34.0, 22.0),
				base + Vector2(14.0, 22.0)]), ink)
		if progress < 1.0:
			draw_rect(Rect2(0.0, size.y - 5.0, size.x * progress, 5.0), Color(1.0, 1.0, 1.0, 0.85))
