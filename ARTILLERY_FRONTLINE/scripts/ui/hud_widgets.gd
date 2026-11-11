class_name HudWidgets
extends RefCounted
## Small custom-drawn controls for the combat HUD. None of them takes input:
## the HUD's touch router decides what each finger is doing.


## A rectangle with its top-left and bottom-right corners cut off.
static func plate_points(area: Rect2, cut: float) -> PackedVector2Array:
	var a: Vector2 = area.position
	var b: Vector2 = area.end
	return PackedVector2Array([Vector2(a.x + cut, a.y), Vector2(b.x, a.y), Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y),
		Vector2(a.x, b.y), Vector2(a.x, a.y + cut)])


static func draw_plate(canvas: CanvasItem, area: Rect2, fill: Color, edge: Color, cut: float = 12.0, width: float = 1.5) -> void:
	if area.size.x <= cut * 2.0 + 1.0 or area.size.y <= cut * 2.0 + 1.0:
		return
	var points: PackedVector2Array = plate_points(area, cut)
	canvas.draw_colored_polygon(points, fill)
	points.append(points[0])
	canvas.draw_polyline(points, edge, width, true)


## Pictograms shared by the HUD and the menus. `size` is the side of the box the picture fills.
static func draw_icon(canvas: CanvasItem, kind: String, at: Vector2, size: float, ink: Color) -> void:
	var s: float = size
	var hollow := Color(0.0, 0.0, 0.0, 0.85 * ink.a)
	match kind:
		"wall":
			# A stretch of battlements.
			canvas.draw_rect(Rect2(at.x - s * 0.5, at.y - s * 0.1, s, s * 0.52), ink)
			for step: int in 3:
				canvas.draw_rect(Rect2(at.x - s * 0.5 + s * 0.38 * float(step), at.y - s * 0.42, s * 0.24, s * 0.34), ink)
			canvas.draw_line(at + Vector2(-s * 0.5, s * 0.16), at + Vector2(s * 0.5, s * 0.16), hollow, maxf(1.0, s * 0.045))
		"gate":
			# Two leaves under a lintel.
			canvas.draw_rect(Rect2(at.x - s * 0.5, at.y - s * 0.46, s, s * 0.16), ink)
			canvas.draw_rect(Rect2(at.x - s * 0.42, at.y - s * 0.24, s * 0.39, s * 0.68), ink)
			canvas.draw_rect(Rect2(at.x + s * 0.03, at.y - s * 0.24, s * 0.39, s * 0.68), ink)
			canvas.draw_circle(at + Vector2(-s * 0.1, s * 0.12), s * 0.045, hollow)
			canvas.draw_circle(at + Vector2(s * 0.1, s * 0.12), s * 0.045, hollow)
		"skull":
			canvas.draw_circle(at + Vector2(0.0, -s * 0.08), s * 0.38, ink)
			canvas.draw_rect(Rect2(at.x - s * 0.21, at.y + s * 0.12, s * 0.42, s * 0.32), ink)
			canvas.draw_circle(at + Vector2(-s * 0.15, -s * 0.07), s * 0.1, hollow)
			canvas.draw_circle(at + Vector2(s * 0.15, -s * 0.07), s * 0.1, hollow)
			for offset: float in [-0.07, 0.07]:
				canvas.draw_line(at + Vector2(s * offset, s * 0.27), at + Vector2(s * offset, s * 0.44), hollow, maxf(1.5, s * 0.05))
		"grenade":
			# Egg body, fuze cap, lever and the ring of the pin.
			var r: float = s * 0.5
			var body := PackedVector2Array()
			for step: int in 20:
				var angle: float = TAU * float(step) / 20.0
				body.append(at + Vector2(cos(angle) * r * 0.6, sin(angle) * r * 0.74 + r * 0.2))
			canvas.draw_colored_polygon(body, ink)
			canvas.draw_rect(Rect2(at.x - r * 0.26, at.y - r * 0.92, r * 0.52, r * 0.44), ink)
			canvas.draw_line(at + Vector2(r * 0.2, -r * 0.84), at + Vector2(r * 0.84, -r * 0.24), ink, maxf(2.0, s * 0.06), true)
			canvas.draw_arc(at + Vector2(-r * 0.52, -r * 0.8), r * 0.22, 0.0, TAU, 16, ink, maxf(2.0, s * 0.05), true)
		"fire":
			var ring: float = s * 0.4
			canvas.draw_arc(at, ring, 0.0, TAU, 40, ink, maxf(2.5, s * 0.04), true)
			canvas.draw_circle(at, s * 0.08, ink)
			for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
				var direction := Vector2(cos(angle), sin(angle))
				canvas.draw_line(at + direction * ring * 0.72, at + direction * ring * 1.38, ink, maxf(2.5, s * 0.04), true)
		"reload":
			var sweep: float = s * 0.42
			canvas.draw_arc(at, sweep, -PI * 0.25, PI * 1.3, 32, ink, maxf(3.0, s * 0.075), true)
			var tip: Vector2 = at + Vector2(cos(-PI * 0.25), sin(-PI * 0.25)) * sweep
			var k: float = s / 46.0
			canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(-2.0, -11.0) * k, tip + Vector2(11.0, 2.0) * k,
				tip + Vector2(-8.0, 6.0) * k]), ink)
		"pause":
			var w: float = s * 0.2
			var h: float = s * 0.72
			canvas.draw_rect(Rect2(at.x - w * 1.5, at.y - h * 0.5, w, h), ink)
			canvas.draw_rect(Rect2(at.x + w * 0.5, at.y - h * 0.5, w, h), ink)
		"endless":
			# A lying eight: the belt never runs out.
			canvas.draw_arc(at + Vector2(-s * 0.23, 0.0), s * 0.2, 0.0, TAU, 24, ink, maxf(2.0, s * 0.09), true)
			canvas.draw_arc(at + Vector2(s * 0.23, 0.0), s * 0.2, 0.0, TAU, 24, ink, maxf(2.0, s * 0.09), true)
		"gun":
			_draw_gun(canvas, at - Vector2(s * 0.5, 0.0), s / 100.0, ink)
		"launcher":
			_draw_launcher(canvas, at - Vector2(s * 0.5, 0.0), s / 100.0, ink)


## Twin barrels on a cradle with its pedestal; 100 units long at scale 1, drawn from `base` to the right.
static func _draw_gun(canvas: CanvasItem, base: Vector2, k: float, ink: Color) -> void:
	for offset: float in [-7.0, 7.0]:
		canvas.draw_line(base + Vector2(30.0, offset) * k, base + Vector2(100.0, offset) * k, ink, 3.0 * k)
		canvas.draw_rect(Rect2(base + Vector2(6.0, offset - 4.5) * k, Vector2(34.0, 9.0) * k), ink)
		canvas.draw_rect(Rect2(base + Vector2(92.0, offset - 3.0) * k, Vector2(8.0, 6.0) * k), ink)
	canvas.draw_rect(Rect2(base + Vector2(0.0, -3.0) * k, Vector2(10.0, 6.0) * k), ink)
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(18.0, 12.0) * k, base + Vector2(30.0, 12.0) * k,
		base + Vector2(34.0, 22.0) * k, base + Vector2(14.0, 22.0) * k]), ink)


## Tube, flared venturi, grips and the warhead.
static func _draw_launcher(canvas: CanvasItem, base: Vector2, k: float, ink: Color) -> void:
	canvas.draw_line(base + Vector2(14.0, 0.0) * k, base + Vector2(66.0, 0.0) * k, ink, 6.0 * k)
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(0.0, -8.0) * k, base + Vector2(16.0, -3.0) * k,
		base + Vector2(16.0, 3.0) * k, base + Vector2(0.0, 8.0) * k]), ink)
	canvas.draw_line(base + Vector2(34.0, 3.0) * k, base + Vector2(31.0, 16.0) * k, ink, 4.0 * k)
	canvas.draw_line(base + Vector2(48.0, 3.0) * k, base + Vector2(45.0, 16.0) * k, ink, 4.0 * k)
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(66.0, -2.5) * k, base + Vector2(74.0, -8.5) * k,
		base + Vector2(84.0, -7.0) * k, base + Vector2(100.0, 0.0) * k, base + Vector2(84.0, 7.0) * k, base + Vector2(74.0, 8.5) * k,
		base + Vector2(66.0, 2.5) * k]), ink)


class Plate:
	extends Control
	## Backing for a group of read-outs: dark glass with two cut corners, a
	## hairline edge and a short accent bar. It can carry pictograms, each of
	## which may flash on its own.
	var fill: Color = UITheme.HUD_PLATE
	var edge: Color = UITheme.LINE
	var accent: Color = UITheme.AMBER
	var cut: float = 12.0
	## Each entry: [kind, centre, size].
	var icons: Array = []
	## One value per icon, 0..1: how hard that icon is flashing red.
	var alerts := PackedFloat32Array()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func add_icon(kind: String, at: Vector2, icon_size: float) -> int:
		icons.append([kind, at, icon_size])
		alerts.append(0.0)
		queue_redraw()
		return icons.size() - 1

	func set_alert(index: int, value: float) -> void:
		if index >= 0 and index < alerts.size() and not is_equal_approx(alerts[index], value):
			alerts[index] = value
			queue_redraw()

	func strongest_alert() -> float:
		var top: float = 0.0
		for value: float in alerts:
			top = maxf(top, value)
		return top

	func _draw() -> void:
		var alarm: float = strongest_alert()
		HudWidgets.draw_plate(self, Rect2(Vector2.ZERO, size), fill.lerp(Color(0.32, 0.03, 0.02, fill.a + 0.1), alarm * 0.5),
			edge.lerp(UITheme.RED, alarm), cut)
		if accent.a > 0.0 and size.x > cut + 60.0:
			draw_line(Vector2(cut + 5.0, 1.0), Vector2(cut + 47.0, 1.0), accent.lerp(UITheme.RED, alarm), 3.0)
		for index: int in icons.size():
			var icon: Array = icons[index]
			HudWidgets.draw_icon(self, icon[0], icon[1], icon[2], UITheme.TEXT.lerp(UITheme.RED, alerts[index]))


class Meter:
	extends Control
	## Health bar with a delayed "damage" ghost so a hit reads at a glance.
	var fraction: float = 1.0
	var ghost: float = 1.0
	var flash: float = 0.0
	var broken: bool = false
	## A fixed colour for the bar (an enemy's health); transparent to colour it by how full it is.
	var tint := Color(0.0, 0.0, 0.0, 0.0)
	var ticks: int = 10

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
		draw_rect(area, Color(0.0, 0.0, 0.0, 0.62))
		if broken:
			# Nothing left to measure: the track is hatched red.
			var x: float = -size.y + 3.0
			while x < size.x:
				var from := Vector2(x, size.y)
				var to := Vector2(x + size.y, 0.0)
				if from.x < 0.0:
					from = Vector2(0.0, size.y + from.x)
				if to.x > size.x:
					to = Vector2(size.x, to.x - size.x)
				draw_line(from, to, Color(UITheme.RED, 0.8), 2.0)
				x += 9.0
			draw_rect(area, Color(UITheme.RED, 0.9), false, 2.0)
			return
		if ghost > fraction:
			draw_rect(Rect2(0.0, 0.0, size.x * ghost, size.y), Color(1.0, 0.93, 0.82, 0.8))
		var color: Color = tone().lerp(Color.WHITE, flash * 0.6)
		draw_rect(Rect2(0.0, 0.0, size.x * fraction, size.y), color)
		# A lighter top third gives the bar some body without a texture.
		draw_rect(Rect2(0.0, 0.0, size.x * fraction, size.y * 0.34), Color(1.0, 1.0, 1.0, 0.2))
		for step: int in range(1, ticks):
			var x: float = size.x * float(step) / float(ticks)
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(0.0, 0.0, 0.0, 0.45), 1.5)
		draw_rect(area, Color(0.92, 0.88, 0.78, 0.7), false, 1.5)


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
		var strength: float = 0.4 if dim else 1.0
		# The disc gives a little under the thumb.
		var r: float = radius * (0.95 if held else 1.0)
		draw_circle(middle, r, Color(0.02, 0.025, 0.03, 0.5), true, -1.0, true)
		if held:
			draw_circle(middle, r, Color(tint.r, tint.g, tint.b, 0.4), true, -1.0, true)
		elif kind == "fire":
			draw_circle(middle, r - 9.0, Color(tint.r, tint.g, tint.b, 0.22), true, -1.0, true)
		draw_arc(middle, r, 0.0, TAU, 72, Color(tint.r, tint.g, tint.b, (1.0 if held else 0.8) * strength), 4.0, true)
		draw_arc(middle, r - 8.0, 0.0, TAU, 72, Color(1.0, 1.0, 1.0, 0.13), 1.5, true)
		if progress < 1.0:
			draw_arc(middle, r - 3.5, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(1.0, 1.0, 1.0, 0.92), 5.0, true)
		HudWidgets.draw_icon(self, kind, middle, radius, Color(1.0, 0.97, 0.9, 0.96 * strength))


class Badge:
	extends Control
	## The small disc a count sits on.
	var tint: Color = UITheme.AMBER

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_tint(value: Color) -> void:
		if tint != value:
			tint = value
			queue_redraw()

	func _draw() -> void:
		var middle: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		draw_circle(middle, r, Color(0.03, 0.035, 0.04, 0.92), true, -1.0, true)
		draw_arc(middle, r, 0.0, TAU, 32, tint, 2.0, true)


class Crosshair:
	extends Control
	var hit_left: float = 0.0
	var kill: bool = false
	var head: bool = false
	var spread: float = 0.0
	## "cross" for the machine gun, "rocket" for the launcher's ring sight.
	var style: String = "cross"
	## 0..1 while the weapon in hand reloads, drawn as a ring closing round the sight; negative otherwise.
	var reload: float = -1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_style(value: String) -> void:
		if style != value:
			style = value
			queue_redraw()

	func set_reload(value: float) -> void:
		if not is_equal_approx(reload, value):
			reload = value
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
		if reload >= 0.0 and reload < 1.0:
			var around: float = 40.0
			draw_arc(middle, around, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.4), 5.0, true)
			draw_arc(middle, around, -PI * 0.5, -PI * 0.5 + TAU * reload, 48, UITheme.AMBER, 3.0, true)
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
		custom_minimum_size = Vector2(60, 84)
		size = custom_minimum_size

	func _process(delta: float) -> void:
		if visible:
			pulse += delta * 6.0
			queue_redraw()

	func _draw() -> void:
		var middle: Vector2 = size * 0.5
		var shift: float = sin(pulse) * 4.0 * side
		# Two chevrons, the leading one brighter, sliding toward the threat.
		for step: int in 2:
			var alpha: float = (0.62 + 0.38 * sin(pulse)) * (1.0 if step == 0 else 0.5)
			var at: Vector2 = middle + Vector2(shift - side * 20.0 * float(step), 0.0)
			var points := PackedVector2Array([at + Vector2(side * 24.0, 0.0), at + Vector2(-side * 6.0, -34.0), at + Vector2(side * 4.0, 0.0),
				at + Vector2(-side * 6.0, 34.0)])
			draw_colored_polygon(points, Color(color.r, color.g, color.b, alpha))
			draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0, 0, 0, 0.55), 2.0, true)


class WeaponSlot:
	extends Control
	## One weapon of the gunner: a card with its outline. The HUD's router
	## hit-tests it with `contains` and writes the round count on a label inside it.
	var kind: String = "bullet"
	var active: bool = false
	var spent: bool = false
	var progress: float = 1.0
	var refused: float = 0.0
	## The supply never runs out: the card shows a lying eight instead of a count.
	var endless: bool = false

	func _init(weapon_kind: String = "bullet") -> void:
		kind = weapon_kind
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(160, 80)
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
		var edge: Color = UITheme.AMBER if active else Color(0.9, 0.86, 0.76, 0.42)
		var fill: Color = UITheme.HUD_PLATE
		if active:
			fill = Color(UITheme.AMBER.r * 0.26, UITheme.AMBER.g * 0.22, UITheme.AMBER.b * 0.12, 0.74)
		if refused > 0.0:
			edge = UITheme.RED
			fill = fill.lerp(Color(0.42, 0.04, 0.03, 0.78), minf(1.0, refused * 2.0))
		HudWidgets.draw_plate(self, Rect2(Vector2.ZERO, size), fill, edge, 10.0, 3.0 if active else 1.5)
		if active:
			draw_line(Vector2(15.0, 2.0), Vector2(size.x * 0.46, 2.0), UITheme.AMBER, 4.0)
		var ink := Color(1.0, 0.97, 0.9, 0.96 if active else 0.72)
		if spent:
			ink.a = 0.26
		var k: float = size.x / 140.0
		var base := Vector2(14.0, size.y * 0.4)
		if kind == "rocket":
			HudWidgets._draw_launcher(self, base, k, ink)
		else:
			HudWidgets._draw_gun(self, base, k, ink)
		if endless:
			HudWidgets.draw_icon(self, "endless", Vector2(size.x - 30.0, size.y - 21.0), 30.0, Color(ink, ink.a * 0.9))
		if spent:
			draw_line(Vector2(14.0, size.y - 14.0), Vector2(size.x - 14.0, 14.0), Color(UITheme.RED, 0.75), 3.0, true)
		if progress < 1.0:
			draw_rect(Rect2(11.0, size.y - 8.0, (size.x - 22.0) * progress, 4.0), Color(1.0, 1.0, 1.0, 0.9))


class WavePips:
	extends Control
	## One mark for every wave of the siege: beaten, being fought, still to come.
	var total: int = 0
	var current: int = -1
	var cleared: int = 0
	var mirrored: bool = false
	var pulse: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(wave_total: int, wave_current: int, waves_cleared: int, right_to_left: bool) -> void:
		if total != wave_total or current != wave_current or cleared != waves_cleared or mirrored != right_to_left:
			total = wave_total
			current = wave_current
			cleared = waves_cleared
			mirrored = right_to_left
			queue_redraw()

	func _process(delta: float) -> void:
		if is_visible_in_tree() and current >= cleared and current >= 0:
			pulse += delta * 5.0
			queue_redraw()

	func _draw() -> void:
		if total <= 0:
			return
		var gap: float = 5.0
		var width: float = (size.x - gap * float(total - 1)) / float(total)
		for index: int in total:
			var place: int = (total - 1 - index) if mirrored else index
			var area := Rect2(float(place) * (width + gap), 0.0, width, size.y)
			if index < cleared:
				draw_rect(area, Color(UITheme.GREEN, 0.92))
			elif index == current:
				draw_rect(area, Color(UITheme.AMBER, 0.62 + 0.38 * sin(pulse)))
			else:
				draw_rect(area, Color(1.0, 1.0, 1.0, 0.2))


class AmmoGauge:
	extends Control
	## What is left to fire, as a picture: a belt that runs down, or one mark per rocket.
	var kind: String = "bullet"
	var fraction: float = 1.0
	var low: bool = false
	var loaded: int = 0
	var spare: int = 0
	var capacity: int = 1
	## 0..1 while reloading; negative otherwise.
	var reload: float = -1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_belt(belt_fraction: float, running_low: bool, reload_progress: float) -> void:
		if kind != "bullet" or not is_equal_approx(fraction, belt_fraction) or low != running_low or not is_equal_approx(reload, reload_progress):
			kind = "bullet"
			fraction = belt_fraction
			low = running_low
			reload = reload_progress
			queue_redraw()

	func set_rockets(in_tube: int, spares: int, most: int, reload_progress: float) -> void:
		if kind != "rocket" or loaded != in_tube or spare != spares or capacity != most or not is_equal_approx(reload, reload_progress):
			kind = "rocket"
			loaded = in_tube
			spare = spares
			capacity = most
			reload = reload_progress
			queue_redraw()

	func _draw() -> void:
		var track := Color(0.0, 0.0, 0.0, 0.55)
		if kind == "rocket":
			# The loaded round first, then the spares, then the empty places on the gunner's back.
			var places: int = maxi(capacity, 1)
			var gap: float = 6.0
			var width: float = minf(38.0, (size.x - gap * float(places - 1)) / float(places))
			var nose: float = minf(size.y * 0.7, width * 0.4)
			for index: int in places:
				var x: float = float(index) * (width + gap)
				var tone: Color = track
				if index < loaded:
					tone = UITheme.AMBER
				elif index < loaded + spare:
					tone = Color(UITheme.TEXT, 0.9)
				draw_colored_polygon(PackedVector2Array([Vector2(x, 0.0), Vector2(x + width - nose, 0.0), Vector2(x + width, size.y * 0.5),
					Vector2(x + width - nose, size.y), Vector2(x, size.y)]), tone)
			if reload >= 0.0 and reload < 1.0:
				draw_rect(Rect2(0.0, size.y + 3.0, size.x * reload, 3.0), UITheme.AMBER)
			return
		draw_rect(Rect2(Vector2.ZERO, size), track)
		if reload >= 0.0 and reload < 1.0:
			draw_rect(Rect2(0.0, 0.0, size.x * reload, size.y), UITheme.AMBER)
		else:
			draw_rect(Rect2(0.0, 0.0, size.x * fraction, size.y), Color(UITheme.RED if low else UITheme.TEXT, 0.92))
		for step: int in range(1, 8):
			var x: float = size.x * float(step) / 8.0
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(0.0, 0.0, 0.0, 0.5), 1.5)


class BannerBand:
	extends Control
	## The strip a banner is written on: dark in the middle, gone at both ends,
	## ruled above and below in the banner's colour.
	var color: Color = UITheme.AMBER

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_color(value: Color) -> void:
		if color != value:
			color = value
			queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w < 8.0 or h < 8.0:
			return
		var core := Color(0.0, 0.0, 0.0, 0.52)
		var clear := Color(0.0, 0.0, 0.0, 0.0)
		var fade: float = w * 0.3
		draw_polygon(PackedVector2Array([Vector2(0.0, 0.0), Vector2(fade, 0.0), Vector2(fade, h), Vector2(0.0, h)]),
			PackedColorArray([clear, core, core, clear]))
		draw_rect(Rect2(fade, 0.0, w - fade * 2.0, h), core)
		draw_polygon(PackedVector2Array([Vector2(w - fade, 0.0), Vector2(w, 0.0), Vector2(w, h), Vector2(w - fade, h)]),
			PackedColorArray([core, clear, clear, core]))
		var line := Color(color, 0.9)
		var faint := Color(color, 0.0)
		for y: float in [0.0, h - 2.0]:
			draw_polygon(PackedVector2Array([Vector2(0.0, y), Vector2(w * 0.5, y), Vector2(w * 0.5, y + 2.0), Vector2(0.0, y + 2.0)]),
				PackedColorArray([faint, line, line, faint]))
			draw_polygon(PackedVector2Array([Vector2(w * 0.5, y), Vector2(w, y), Vector2(w, y + 2.0), Vector2(w * 0.5, y + 2.0)]),
				PackedColorArray([line, faint, faint, line]))
