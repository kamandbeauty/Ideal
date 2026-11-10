class_name MenuMotion
extends RefCounted
## Motion vocabulary for the command interface. Every effect is a Tween on a
## visual-only property (modulate alpha, scale, pivot, minimum width), so
## layout, safe-area insets and full-bleed page rectangles never change.
## Tweens keep running while the tree is paused so the pause page can animate.

const HOVER_SCALE := 1.03
const PRESS_SCALE := 0.975


static func tween_on(node: Node) -> Tween:
	var tween: Tween = node.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


static func pivot_center(node: Control) -> void:
	if node.has_meta("pivot_ready"):
		return
	node.set_meta("pivot_ready", true)
	node.resized.connect(_update_pivot.bind(node))
	_update_pivot(node)


static func _update_pivot(node: Control) -> void:
	node.pivot_offset = node.size * 0.5


static func snap(node: Control) -> void:
	## Ends an entrance at its resting state (used by settle()). Also stops any
	## scale tween still owned by the node, so nothing keeps moving afterwards.
	if not is_instance_valid(node):
		return
	if node.has_meta("scale_tween"):
		var owned: Variant = node.get_meta("scale_tween")
		if owned is Tween and owned.is_valid():
			owned.kill()
	node.modulate.a = 1.0
	node.scale = Vector2.ONE


## True when a finish callback has no bound node or its bound node still exists.
static func target_alive(finish: Callable) -> bool:
	if finish.get_bound_arguments_count() == 0:
		return true
	return is_instance_valid(finish.get_bound_arguments()[0])


static func finish(node: Object, property: String, value: Variant) -> void:
	if is_instance_valid(node):
		node.set_indexed(property, value)


static func reveal(node: Control, delay: float, duration: float, from_scale: float = 1.0) -> Tween:
	## Fades a control in (returned, so the caller can track it), and grows it from
	## a smaller scale with a soft overshoot. The growth runs on its own tween owned
	## by the node, so hover can take over scale without cutting the fade short.
	pivot_center(node)
	node.modulate.a = 0.0
	node.scale = Vector2.ONE * from_scale
	var fade := tween_on(node)
	fade.tween_property(node, "modulate:a", 1.0, duration * 0.8).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if from_scale != 1.0:
		var grow := tween_on(node)
		grow.tween_property(node, "scale", Vector2.ONE, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		node.set_meta("scale_tween", grow)
	return fade


static func attach_press(button: Button) -> void:
	## Hover lift and press squash for menu buttons. Touch input is emulated as
	## mouse input by Godot, so phones get the same feedback as desktop.
	if button.has_meta("motion_ready"):
		return
	button.set_meta("motion_ready", true)
	button.set_meta("hovered", false)
	pivot_center(button)
	button.mouse_entered.connect(_on_hover.bind(button, true))
	button.mouse_exited.connect(_on_hover.bind(button, false))
	button.button_down.connect(_scale_to.bind(button, PRESS_SCALE, 0.07))
	button.button_up.connect(_on_release.bind(button))


static func _on_hover(button: Button, inside: bool) -> void:
	button.set_meta("hovered", inside)
	_scale_to(button, HOVER_SCALE if inside else 1.0, 0.16)


static func _on_release(button: Button) -> void:
	_scale_to(button, HOVER_SCALE if bool(button.get_meta("hovered", false)) else 1.0, 0.14)


static func _scale_to(button: Button, target: float, duration: float) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	var previous: Variant = button.get_meta("scale_tween", null)
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween := tween_on(button)
	tween.tween_property(button, "scale", Vector2.ONE * target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	button.set_meta("scale_tween", tween)


static func add_sweep(button: Button, width: float = 120.0, span: float = 430.0) -> void:
	## A soft light band that crosses an accent card every few seconds. It sits
	## under the card content and is clipped by the button bounds.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1.0, 0.95, 0.8, 0.0), Color(1.0, 0.95, 0.8, 0.34), Color(1.0, 0.95, 0.8, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = int(width)
	texture.height = 8
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var sweep := TextureRect.new()
	sweep.texture = texture
	sweep.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sweep.stretch_mode = TextureRect.STRETCH_SCALE
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep.anchor_left = 0.0
	sweep.anchor_top = 0.0
	sweep.anchor_right = 0.0
	sweep.anchor_bottom = 1.0
	sweep.offset_left = 0.0
	sweep.offset_right = width
	sweep.offset_top = 0.0
	sweep.offset_bottom = 0.0
	sweep.position.x = -width
	button.clip_contents = true
	button.add_child(sweep)
	button.move_child(sweep, 0)
	var loop := tween_on(sweep)
	loop.set_loops()
	loop.tween_interval(1.6)
	loop.tween_callback(_reset_sweep.bind(sweep, -width))
	loop.tween_property(sweep, "position:x", span, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _reset_sweep(sweep: Control, start_x: float) -> void:
	sweep.position.x = start_x


static func drift(node: Control, amount: float = 0.06, seconds: float = 14.0) -> void:
	## Slow Ken-Burns breathing on key art. Scale stays at or above 1.0, so the
	## picture always covers its full-bleed frame.
	pivot_center(node)
	var loop := tween_on(node)
	loop.set_loops()
	loop.tween_property(node, "scale", Vector2.ONE * (1.0 + amount), seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.tween_property(node, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func dust(root: Control) -> CPUParticles2D:
	## Faint warm motes drifting over the key art. Cheap CPU particles, no input.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1.0, 0.92, 0.72, 1.0), Color(1.0, 0.92, 0.72, 0.0)])
	var texture := GradientTexture2D.new()
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	texture.gradient = gradient
	var particles := CPUParticles2D.new()
	particles.texture = texture
	particles.amount = 24
	particles.lifetime = 16.0
	particles.preprocess = 16.0
	particles.local_coords = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.direction = Vector2(-1.0, -0.25)
	particles.spread = 18.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 14.0
	particles.scale_amount_min = 0.06
	particles.scale_amount_max = 0.2
	particles.color = Color(1.0, 0.9, 0.7, 0.28)
	root.add_child(particles)
	root.resized.connect(_fit_dust.bind(root, particles))
	_fit_dust(root, particles)
	return particles


static func _fit_dust(root: Control, particles: CPUParticles2D) -> void:
	particles.position = root.size * 0.5
	particles.emission_rect_extents = root.size * 0.5


static func bar_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(2)
	return box
