class_name CoastalHUD
extends CanvasLayer
## Original landscape mobile HUD for fixed-position coastal defense.
signal fire_down
signal fire_up
signal aim_pressed
signal weapon_pressed
signal reload_pressed
signal rocket_pressed
signal auto_toggled(enabled: bool)
signal settings_pressed
signal support_pressed(id: String)
signal resume_pressed
signal restart_pressed
signal exit_pressed

class HudIcon extends Control:
	var kind: String = "crosshair"
	var tint: Color = Color(0.92, 0.94, 0.86)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(34, 34)
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var s: float = minf(size.x, size.y)
		match kind:
			"gear":
				draw_arc(c, s * 0.24, 0, TAU, 24, tint, 3.0, true)
				for i in range(8):
					var a: float = i * TAU / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * s * 0.28, c + Vector2(cos(a), sin(a)) * s * 0.42, tint, 4.0, true)
			"crosshair":
				draw_arc(c, s * 0.3, 0, TAU, 32, tint, 2.5, true)
				draw_line(c - Vector2(s * 0.46, 0), c - Vector2(s * 0.18, 0), tint, 2.5, true)
				draw_line(c + Vector2(s * 0.18, 0), c + Vector2(s * 0.46, 0), tint, 2.5, true)
				draw_line(c - Vector2(0, s * 0.46), c - Vector2(0, s * 0.18), tint, 2.5, true)
				draw_line(c + Vector2(0, s * 0.18), c + Vector2(0, s * 0.46), tint, 2.5, true)
				draw_circle(c, 2.5, tint)
			"rocket":
				var body := PackedVector2Array([c + Vector2(0, -s * 0.42), c + Vector2(s * 0.13, -s * 0.1), c + Vector2(s * 0.1, s * 0.28), c + Vector2(-s * 0.1, s * 0.28), c + Vector2(-s * 0.13, -s * 0.1)])
				draw_colored_polygon(body, tint)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.1, s * 0.12), c + Vector2(-s * 0.3, s * 0.36), c + Vector2(-s * 0.08, s * 0.28)]), tint)
				draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.1, s * 0.12), c + Vector2(s * 0.3, s * 0.36), c + Vector2(s * 0.08, s * 0.28)]), tint)
			"repair":
				draw_rect(Rect2(c - Vector2(s * 0.09, s * 0.32), Vector2(s * 0.18, s * 0.64)), tint)
				draw_rect(Rect2(c - Vector2(s * 0.32, s * 0.09), Vector2(s * 0.64, s * 0.18)), tint)
			"crate":
				draw_rect(Rect2(c - Vector2(s * 0.32, s * 0.26), Vector2(s * 0.64, s * 0.52)), tint, false, 2.5)
				draw_line(c - Vector2(s * 0.32, s * 0.26), c + Vector2(s * 0.32, s * 0.26), tint, 2.0, true)
				draw_line(c + Vector2(s * 0.32, -s * 0.26), c + Vector2(-s * 0.32, s * 0.26), tint, 2.0, true)
			"helicopter":
				draw_circle(c + Vector2(-s * 0.05, 0), s * 0.16, tint)
				draw_rect(Rect2(c + Vector2(s * 0.05, -s * 0.05), Vector2(s * 0.34, s * 0.08)), tint)
				draw_line(c - Vector2(s * 0.42, s * 0.2), c + Vector2(s * 0.42, s * 0.2), tint, 3.0, true)
				draw_line(c, c - Vector2(0, s * 0.2), tint, 2.0, true)
			"jet":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.42), c + Vector2(s * 0.1, -s * 0.05), c + Vector2(s * 0.42, s * 0.18), c + Vector2(s * 0.1, s * 0.12), c + Vector2(s * 0.06, s * 0.36), c + Vector2(-s * 0.06, s * 0.36), c + Vector2(-s * 0.1, s * 0.12), c + Vector2(-s * 0.42, s * 0.18), c + Vector2(-s * 0.1, -s * 0.05)]), tint)
			"bullets":
				for i in range(3):
					var x: float = c.x + (i - 1) * s * 0.18
					draw_rect(Rect2(Vector2(x - s * 0.05, c.y - s * 0.28), Vector2(s * 0.1, s * 0.5)), tint)
					draw_circle(Vector2(x, c.y - s * 0.28), s * 0.05, tint)

class Crosshair extends Control:
	var hot: bool = false
	var hit_timer: float = 0.0
	var kill_timer: float = 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		if hit_timer > 0.0 or kill_timer > 0.0:
			hit_timer = maxf(0.0, hit_timer - delta)
			kill_timer = maxf(0.0, kill_timer - delta)
			queue_redraw()
	func confirm_hit(killed: bool) -> void:
		hit_timer = 0.18
		if killed:
			kill_timer = 0.45
		queue_redraw()
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var color: Color = Color(0.55, 0.95, 0.5) if hot else Color(0.9, 0.95, 0.85, 0.85)
		draw_arc(c, 14.0, 0, TAU, 32, color, 2.0, true)
		for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + dir * 20.0, c + dir * 32.0, color, 2.5, true)
		draw_circle(c, 2.0, color)
		if hit_timer > 0.0:
			var alpha: float = clampf(hit_timer / 0.18, 0.0, 1.0)
			var hit_color: Color = Color(1.0, 0.32, 0.22, alpha) if kill_timer > 0.0 else Color(1.0, 0.95, 0.75, alpha)
			var radius: float = 12.0 if kill_timer > 0.0 else 9.0
			for dir in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				draw_line(c + dir.normalized() * 6.0, c + dir.normalized() * radius, hit_color, 3.0, true)

var root: Control
var page_root: Control
var mission_label: Label
var enemies_label: Label
var round_label: Label
var timer_label: Label
var wave_pips: HBoxContainer
var threat_label: Label
var health_bar: ProgressBar
var health_label: Label
var ammo_label: Label
var reserve_label: Label
var weapon_label: Label
var auto_check: CheckButton
var fire_button: Button
var aim_button: Button
var weapon_button: Button
var reload_button: Button
var rocket_button: Button
var support_buttons: Dictionary = {}
var support_labels: Dictionary = {}
var pause_panel: Control
var result_panel: Control
var result_title: Label
var result_body: Label
var quality_select: OptionButton
var crosshair: Crosshair
var damage_overlay: ColorRect
const DEFAULT_HEALTH: float = 6000.0

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.name = "CoastalInterface"
	root.theme = UITheme.theme()
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Modal pages are siblings of the inset HUD root so they cover the whole
	# display, including the cutout area, with no gameplay frame behind them.
	page_root = Control.new()
	page_root.name = "CoastalPages"
	page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_root.layout_direction = Control.LAYOUT_DIRECTION_RTL
	page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(page_root)
	_build_top()
	_build_right()
	_build_bottom()
	_build_crosshair()
	_build_pause()
	_build_results()
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()

func _glass(child: Control, padding: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.plate("plate_panel.png", padding, Color(1, 1, 1, 0.82)))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(child)
	return panel

func _icon(kind: String, size_px: float, tint: Color = Color(0.92, 0.94, 0.86)) -> HudIcon:
	var icon := HudIcon.new()
	icon.kind = kind
	icon.tint = tint
	icon.custom_minimum_size = Vector2(size_px, size_px)
	return icon

func _build_top() -> void:
	var left := UITheme.row(10)
	UITheme.place(left, Vector4(0, 0, 0, 0), Vector4(18, 14, 268, 78))
	var settings := Button.new()
	settings.custom_minimum_size = Vector2(64, 64)
	settings.add_theme_stylebox_override("normal", UITheme.plate("plate_button.png", 0))
	settings.add_theme_stylebox_override("hover", UITheme.plate("plate_button_hover.png", 0))
	settings.add_theme_stylebox_override("pressed", UITheme.plate("plate_button_pressed.png", 0))
	var gear := _icon("gear", 40)
	gear.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	gear.offset_left = -20
	gear.offset_top = -20
	gear.offset_right = 20
	gear.offset_bottom = 20
	settings.add_child(gear)
	settings.pressed.connect(func(): settings_pressed.emit())
	left.add_child(settings)
	auto_check = CheckButton.new()
	auto_check.text = Loc.t("coastal_autofire")
	auto_check.add_theme_font_size_override("font_size", 20)
	auto_check.custom_minimum_size = Vector2(150, 56)
	auto_check.toggled.connect(func(on): auto_toggled.emit(on))
	left.add_child(_glass(auto_check, 8))
	root.add_child(left)
	var center := UITheme.column(4)
	UITheme.place(center, Vector4(0.5, 0, 0.5, 0), Vector4(-180, 14, 180, 96))
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_pips = UITheme.row(10)
	wave_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(wave_pips)
	threat_label = UITheme.label(Loc.t("coastal_threat_ahead"), 18, UITheme.ACCENT, true)
	threat_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	threat_label.add_theme_constant_override("shadow_offset_x", 1)
	threat_label.add_theme_constant_override("shadow_offset_y", 2)
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(threat_label)
	root.add_child(center)
	var info := UITheme.column(2)
	info.alignment = BoxContainer.ALIGNMENT_END
	mission_label = UITheme.label(Loc.t("coastal_title") % Loc.t("coastal_default_label"), 20, UITheme.TEXT, true)
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemies_label = UITheme.label(Loc.t("coastal_enemies") % Loc.number(0), 22, UITheme.ACCENT, true)
	enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var row := UITheme.row(16)
	round_label = UITheme.label(Loc.t("coastal_round") % [Loc.number(1), Loc.number(3)], 18, UITheme.MUTED)
	timer_label = UITheme.label(Loc.digits("00:00"), 18, UITheme.MUTED)
	row.add_child(round_label)
	row.add_child(timer_label)
	row.alignment = BoxContainer.ALIGNMENT_END
	info.add_child(mission_label)
	info.add_child(enemies_label)
	info.add_child(row)
	var panel := _glass(info, 12)
	UITheme.place(panel, Vector4(1, 0, 1, 0), Vector4(-340, 14, -18, 122))
	root.add_child(panel)

func _circular(kind: String, label_text: String, diameter: float, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(diameter, diameter)
	var style := UITheme.style(Color(0.05, 0.07, 0.08, 0.55), Color(0.85, 0.88, 0.78, 0.75), int(diameter * 0.5))
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", UITheme.style(Color(0.12, 0.15, 0.14, 0.7), UITheme.ACCENT, int(diameter * 0.5)))
	button.add_theme_stylebox_override("pressed", UITheme.style(Color(0.2, 0.24, 0.18, 0.8), UITheme.TEXT, int(diameter * 0.5)))
	var box := UITheme.column(2)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -diameter * 0.5
	box.offset_right = diameter * 0.5
	box.offset_top = -diameter * 0.5
	box.offset_bottom = diameter * 0.5
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _icon(kind, diameter * 0.42)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	if not label_text.is_empty():
		var label := UITheme.label(label_text, 16, UITheme.TEXT, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
	button.add_child(box)
	button.pressed.connect(action)
	return button

func _build_right() -> void:
	# Fire cluster is pinned to the physical right edge. UITheme.place opts
	# this cluster out of RTL geometry mirroring without changing the HUD root.
	var column := UITheme.column(12)
	UITheme.place(column, Vector4(1, 0.5, 1, 0.5), Vector4(-160, -180, -24, 180))
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	aim_button = _circular("crosshair", Loc.t("coastal_zoom"), 92.0, func(): aim_pressed.emit())
	column.add_child(aim_button)
	fire_button = _circular("bullets", Loc.t("coastal_fire"), 136.0, func(): pass)
	fire_button.button_down.connect(func(): fire_down.emit(); fire_button.scale = Vector2.ONE * 0.95)
	fire_button.button_up.connect(func(): fire_up.emit(); fire_button.scale = Vector2.ONE)
	fire_button.pivot_offset = Vector2(68, 68)
	column.add_child(fire_button)
	weapon_button = _circular("rocket", Loc.t("coastal_weapon"), 92.0, func(): weapon_pressed.emit())
	column.add_child(weapon_button)
	root.add_child(column)

func _build_bottom() -> void:
	var health_box := UITheme.column(4)
	health_label = UITheme.label(Loc.t("coastal_health") % [Loc.number(int(DEFAULT_HEALTH)), Loc.number(int(DEFAULT_HEALTH))], 18, UITheme.TEXT, true)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(280, 20)
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	var fill := UITheme.style(Color(0.35, 0.75, 0.38), Color(0.5, 0.9, 0.5), 4)
	health_bar.add_theme_stylebox_override("fill", fill)
	health_box.add_child(health_label)
	health_box.add_child(health_bar)
	var health_panel := _glass(health_box, 10)
	UITheme.place(health_panel, Vector4(1, 1, 1, 1), Vector4(-330, -96, -18, -18))
	root.add_child(health_panel)
	var supports := UITheme.row(8)
	UITheme.place(supports, Vector4(0.5, 1, 0.5, 1), Vector4(-280, -150, 280, -72))
	supports.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in ["repair", "airstrike", "helicopter", "airdrop"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(128, 72)
		button.disabled = true
		var box := UITheme.column(0)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_kind: String = {"repair": "repair", "airstrike": "jet", "helicopter": "helicopter", "airdrop": "crate"}[id]
		var icon := _icon(icon_kind, 28)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		var label := UITheme.label(Loc.support(id), 15, UITheme.TEXT, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		button.add_child(box)
		button.pressed.connect(func(): support_pressed.emit(id))
		support_buttons[id] = button
		support_labels[id] = label
		supports.add_child(button)
	root.add_child(supports)
	var ammo_box := UITheme.column(2)
	weapon_label = UITheme.label("", 17, UITheme.MUTED, true)
	ammo_label = UITheme.label(Loc.digits("140 / 140"), 30, UITheme.TEXT, true)
	reserve_label = UITheme.label(Loc.t("coastal_reserve") % Loc.number(999), 15, UITheme.MUTED)
	ammo_box.add_child(weapon_label)
	ammo_box.add_child(ammo_label)
	ammo_box.add_child(reserve_label)
	var buttons := UITheme.row(8)
	reload_button = UITheme.button(Loc.t("coastal_reload"), func(): reload_pressed.emit())
	reload_button.custom_minimum_size = Vector2(112, 52)
	rocket_button = UITheme.button(Loc.t("coastal_rocket"), func(): rocket_pressed.emit())
	rocket_button.custom_minimum_size = Vector2(112, 52)
	buttons.add_child(reload_button)
	buttons.add_child(rocket_button)
	ammo_box.add_child(buttons)
	var ammo_panel := _glass(ammo_box, 10)
	UITheme.place(ammo_panel, Vector4(0, 1, 0, 1), Vector4(18, -182, 310, -18))
	root.add_child(ammo_panel)
	damage_overlay = ColorRect.new()
	damage_overlay.color = Color(0.8, 0.1, 0.05, 0.0)
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_overlay)

func _build_crosshair() -> void:
	crosshair = Crosshair.new()
	crosshair.custom_minimum_size = Vector2(80, 80)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -40
	crosshair.offset_top = -40
	crosshair.offset_right = 40
	crosshair.offset_bottom = 40
	root.add_child(crosshair)

func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.visible = false
	pause_panel.add_child(UITheme.backdrop())
	pause_panel.add_child(UITheme.art("hero_beach.jpg", 0.34))
	pause_panel.add_child(UITheme.overlay("vignette.png", 0.95))
	var box := UITheme.column(14)
	box.custom_minimum_size = Vector2(480, 0)
	box.add_child(UITheme.label(Loc.t("coastal_pause_title"), 34, UITheme.TEXT, true))
	quality_select = OptionButton.new()
	for key in ["quality_auto", "quality_low", "quality_medium", "quality_high", "quality_ultra"]:
		quality_select.add_item(Loc.t(key))
	quality_select.select(["auto", "low", "medium", "high", "ultra"].find(Profile.data.settings.quality))
	quality_select.item_selected.connect(func(index): Profile.set_setting("quality", ["auto", "low", "medium", "high", "ultra"][index]))
	box.add_child(quality_select)
	box.add_child(UITheme.button(Loc.t("coastal_resume"), func(): resume_pressed.emit(), true))
	box.add_child(UITheme.button(Loc.t("coastal_restart"), func(): restart_pressed.emit()))
	box.add_child(UITheme.button(Loc.t("coastal_exit"), func(): exit_pressed.emit()))
	var pause_center := CenterContainer.new()
	pause_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_center.add_child(_glass(box, 24))
	pause_panel.add_child(pause_center)
	page_root.add_child(pause_panel)

func _build_results() -> void:
	result_panel = Control.new()
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	result_panel.visible = false
	result_panel.add_child(UITheme.backdrop())
	result_panel.add_child(UITheme.art("hero_beach.jpg", 0.42))
	result_panel.add_child(UITheme.overlay("vignette.png", 0.95))
	var box := UITheme.column(14)
	box.custom_minimum_size = Vector2(600, 0)
	result_title = UITheme.label(Loc.t("coastal_held"), 42, UITheme.ACCENT, true)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_body = UITheme.label("", 22, UITheme.TEXT)
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_title)
	box.add_child(result_body)
	box.add_child(UITheme.button(Loc.t("coastal_replay"), func(): restart_pressed.emit(), true))
	box.add_child(UITheme.button(Loc.t("coastal_exit"), func(): exit_pressed.emit()))
	var result_center := CenterContainer.new()
	result_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_center.add_child(_glass(box, 26))
	result_panel.add_child(result_center)
	page_root.add_child(result_panel)

func update_state(data: Dictionary) -> void:
	mission_label.text = Loc.t("coastal_title") % Loc.wave(String(data.get("label", "COASTAL DEFENSE")))
	enemies_label.text = Loc.t("coastal_enemies") % Loc.number(int(data.get("remaining", 0)))
	round_label.text = Loc.t("coastal_round") % [Loc.number(int(data.get("round", 1))), Loc.number(int(data.get("rounds", 3)))]
	var seconds: int = int(data.get("time", 0.0))
	timer_label.text = Loc.clock(seconds)
	var health: float = float(data.get("health", DEFAULT_HEALTH))
	var health_max: float = float(data.get("health_max", DEFAULT_HEALTH))
	health_bar.value = 100.0 * health / maxf(1.0, health_max)
	health_label.text = Loc.t("coastal_health") % [Loc.number(int(health)), Loc.number(int(health_max))]
	ammo_label.text = Loc.t("coastal_ammo") % [Loc.number(int(data.get("ammo", 0))), Loc.number(int(data.get("magazine", 0)))]
	reserve_label.text = Loc.t("coastal_reserve") % Loc.number(int(data.get("reserve", 0)))
	weapon_label.text = String(data.get("weapon", ""))
	reload_button.disabled = bool(data.get("reloading", false)) or int(data.get("ammo", 0)) >= int(data.get("magazine", 0))
	rocket_button.disabled = String(data.get("weapon_id", "")) == "rocket"
	auto_check.button_pressed = bool(data.get("auto", false))
	_update_pips(int(data.get("round", 1)), int(data.get("rounds", 3)))
	var supports: Array = data.get("supports", ["repair", "airstrike"])
	var cooldowns: Dictionary = data.get("support_cooldowns", {})
	var charges: Dictionary = data.get("support_charges", {})
	for id in support_buttons:
		var locked: bool = not id in supports
		var cooling: bool = float(cooldowns.get(id, 0.0)) > 0.0
		var count: int = int(charges.get(id, 0))
		support_buttons[id].disabled = locked or cooling or count <= 0
		if locked:
			support_labels[id].text = Loc.t("locked")
		elif cooling:
			support_labels[id].text = Loc.t("coastal_seconds") % Loc.number(int(ceilf(float(cooldowns[id]))))
		else:
			support_labels[id].text = "%s %s" % [Loc.support(id), Loc.number(count)]
	var intermission: float = float(data.get("intermission", 0.0))
	if intermission > 0.0:
		threat_label.text = Loc.t("coastal_next_wave") % Loc.number(int(ceilf(intermission)))
	else:
		var bearing: float = float(data.get("threat_bearing", 0.0))
		var distance: float = float(data.get("threat_distance", 0.0))
		if absf(bearing) > 55.0:
			threat_label.text = Loc.t("coastal_threat_left") if bearing > 0.0 else Loc.t("coastal_threat_right")
		else:
			threat_label.text = Loc.t("coastal_threat_distance") % Loc.number(int(distance))

func _update_pips(round_number: int, rounds: int) -> void:
	if wave_pips.get_child_count() == rounds:
		for index in range(rounds):
			var pip: Panel = wave_pips.get_child(index) as Panel
			pip.modulate = UITheme.ACCENT if index < round_number else Color(1, 1, 1, 0.28)
		return
	for child in wave_pips.get_children():
		child.queue_free()
	for index in range(rounds):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(22, 22)
		var style := UITheme.style(UITheme.ACCENT, UITheme.TEXT, 11)
		pip.add_theme_stylebox_override("panel", style)
		pip.modulate = UITheme.ACCENT if index < round_number else Color(1, 1, 1, 0.28)
		wave_pips.add_child(pip)

func set_paused(visible: bool) -> void:
	pause_panel.visible = visible

func show_result(success: bool, stats: Dictionary) -> void:
	result_panel.visible = true
	result_title.text = Loc.t("coastal_held") if success else Loc.t("coastal_lost")
	result_body.text = Loc.t("coastal_result_body") % [Loc.number(int(stats.get("round", 1))), Loc.number(int(stats.get("kills", 0))), Loc.decimal(float(stats.get("time", 0.0)))]

func confirm_hit(killed: bool) -> void:
	if crosshair:
		crosshair.confirm_hit(killed)
	Sound.play_ui("click" if not killed else "reload")

func flash_damage() -> void:
	if damage_overlay == null:
		return
	damage_overlay.color.a = 0.22
	var tween: Tween = create_tween()
	tween.tween_property(damage_overlay, "color:a", 0.0, 0.4)

func _update_safe_area() -> void:
	if not OS.has_feature("android"):
		return
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window_size.x <= 0 or safe.size.x <= 0:
		return
	var scale: Vector2 = root.size / window_size
	root.offset_left = maxf(12, safe.position.x * scale.x)
	root.offset_top = maxf(8, safe.position.y * scale.y)
	root.offset_right = -maxf(12, (window_size.x - safe.end.x) * scale.x)
	root.offset_bottom = -maxf(8, (window_size.y - safe.end.y) * scale.y)
