class_name GameplayHUD
extends Control
## Persian/RTL artillery HUD. Internal telemetry codes stay ASCII; only the
## display layer is localised and numerals are rendered as Persian digits.
signal fire_requested
signal reload_requested
signal zoom_requested
signal camera_requested
signal pause_requested
signal target_requested
signal solution_requested
signal ammunition_requested(id: String)
var battle: BattleController
var overlay: TacticalOverlay
var mission_label: Label
var objective_label: Label
var bearing_label: Label
var elevation_label: Label
var range_label: Label
var target_label: Label
var target_health: ProgressBar
var status_label: Label
var notice_label: Label
var performance_label: Label
var currency_label: Label
var fire_button: Button
var reload_button: Button
var camera_button: Button
var ammo_buttons: Dictionary = {}
var notice_time: float = 0.0
var data: Dictionary = {}


func _ready() -> void:
	theme = UITheme.theme()
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay = TacticalOverlay.new()
	add_child(overlay)
	_build_top_bar()
	_build_target_card()
	_build_bottom_controls()
	notice_label = UITheme.label("", 19, UITheme.ACCENT, true)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice_label.offset_left = -430
	notice_label.offset_right = 430
	notice_label.offset_top = 105
	notice_label.offset_bottom = 145
	add_child(notice_label)
	performance_label = UITheme.label("", 14, UITheme.GREEN)
	UITheme.place(performance_label, Vector4(1, 0, 1, 0), Vector4(-420, 112, -24, 178))
	add_child(performance_label)


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_top = 18
	bar.offset_bottom = 88
	bar.add_theme_constant_override("separation", 24)
	var mission_box := UITheme.column(0)
	mission_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_label = UITheme.label("", 23, UITheme.TEXT, true)
	objective_label = UITheme.label(Loc.t("hud_primary") % [Loc.number(0), Loc.number(0)], 15, UITheme.MUTED)
	mission_box.add_child(mission_label)
	mission_box.add_child(objective_label)
	var mission_panel: PanelContainer = UITheme.panel(mission_box, 12)
	mission_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(mission_panel)
	var bearing_box := UITheme.column(0)
	bearing_box.custom_minimum_size.x = 185
	bearing_box.add_child(UITheme.label(Loc.t("hud_bearing"), 13, UITheme.MUTED))
	bearing_label = UITheme.label(Loc.digits("000.0°"), 28, UITheme.ACCENT, true)
	bearing_box.add_child(bearing_label)
	bar.add_child(UITheme.panel(bearing_box, 10))
	var side := UITheme.row(18)
	var values := UITheme.column(0)
	currency_label = UITheme.label("", 18, UITheme.ACCENT, true)
	values.add_child(currency_label)
	values.add_child(UITheme.label(Loc.t("hud_local_save"), 12, UITheme.MUTED))
	side.add_child(values)
	side.add_child(UITheme.button(Loc.t("hud_pause"), func(): pause_requested.emit()))
	bar.add_child(UITheme.panel(side, 10))
	add_child(bar)


func _build_target_card() -> void:
	var box := UITheme.column(8)
	box.custom_minimum_size.x = 285
	box.add_child(UITheme.label(Loc.t("hud_observer"), 13, UITheme.MUTED))
	target_label = UITheme.label("", 20, UITheme.TEXT, true)
	box.add_child(target_label)
	target_health = ProgressBar.new()
	target_health.custom_minimum_size = Vector2(255, 7)
	target_health.show_percentage = false
	target_health.max_value = 1.0
	target_health.value = 1.0
	box.add_child(target_health)
	box.add_child(UITheme.button(Loc.t("hud_next_target"), func(): target_requested.emit()))
	box.add_child(UITheme.button(Loc.t("hud_fire_control"), func(): solution_requested.emit(), true))
	var panel: PanelContainer = UITheme.panel(box, 16)
	UITheme.place(panel, Vector4(0, 0, 0, 0), Vector4(24, 112, 330, 330))
	add_child(panel)


func _build_bottom_controls() -> void:
	var telemetry := UITheme.column(4)
	var numbers := UITheme.row(22)
	var elevation_box := UITheme.column(0)
	elevation_box.add_child(UITheme.label(Loc.t("hud_elevation"), 13, UITheme.MUTED))
	elevation_label = UITheme.label(Loc.digits("15.0°"), 36, UITheme.TEXT, true)
	elevation_box.add_child(elevation_label)
	numbers.add_child(elevation_box)
	var status_box := UITheme.column(0)
	status_box.add_child(UITheme.label(Loc.t("hud_breech"), 13, UITheme.MUTED))
	status_label = UITheme.label(Loc.t("ready"), 25, UITheme.GREEN, true)
	status_box.add_child(status_label)
	numbers.add_child(status_box)
	telemetry.add_child(numbers)
	range_label = UITheme.label(Loc.t("hud_predicted") % [Loc.number(0), Loc.decimal(0.0)], 16, UITheme.ACCENT)
	telemetry.add_child(range_label)
	telemetry.add_child(UITheme.label(Loc.t("hud_gun"), 13, UITheme.MUTED))
	var panel: PanelContainer = UITheme.panel(telemetry, 16)
	UITheme.place(panel, Vector4(0, 1, 0, 1), Vector4(24, -174, 360, -26))
	add_child(panel)
	var ammo_box := UITheme.row(8)
	for id in ["he", "ap"]:
		var button: Button = UITheme.button(Loc.t("hud_shell_" + id) + "  " + Loc.digits("00"), func(): ammunition_requested.emit(id))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(130, 56)
		ammo_buttons[id] = button
		ammo_box.add_child(button)
	var ammo_holder := VBoxContainer.new()
	UITheme.place(ammo_holder, Vector4(0.5, 1, 0.5, 1), Vector4(-150, -112, 150, -24))
	var hint := UITheme.label(Loc.t("hud_drag_hint"), 13, UITheme.TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_holder.add_child(hint)
	ammo_holder.add_child(ammo_box)
	add_child(ammo_holder)
	fire_button = UITheme.button(Loc.t("hud_fire"), func(): fire_requested.emit(), true)
	fire_button.add_theme_font_size_override("font_size", 34)
	fire_button.add_theme_stylebox_override("normal", UITheme.plate("plate_button_accent.png", 20))
	fire_button.add_theme_stylebox_override("hover", UITheme.plate("plate_button_accent_hover.png", 20))
	fire_button.add_theme_stylebox_override("pressed", UITheme.plate("plate_button_accent.png", 20, Color(0.78, 0.74, 0.66)))
	fire_button.add_theme_stylebox_override("disabled", UITheme.plate("plate_disabled.png", 20))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		fire_button.add_theme_color_override(key, UITheme.INK)
	# Physical right-thumb placement; Persian button text is still AUTO/RTL.
	UITheme.place(fire_button, Vector4(1, 1, 1, 1), Vector4(-198, -198, -36, -36))
	fire_button.custom_minimum_size = Vector2(150, 150)
	add_child(fire_button)
	reload_button = UITheme.button(Loc.t("hud_reload"), func(): reload_requested.emit())
	UITheme.place(reload_button, Vector4(1, 1, 1, 1), Vector4(-374, -100, -212, -36))
	add_child(reload_button)
	camera_button = UITheme.button(Loc.t("hud_camera") % Loc.camera("GUN"), func(): camera_requested.emit())
	UITheme.place(camera_button, Vector4(1, 1, 1, 1), Vector4(-198, -272, -36, -212))
	add_child(camera_button)
	var zoom := UITheme.button(Loc.t("hud_zoom"), func(): zoom_requested.emit())
	UITheme.place(zoom, Vector4(1, 1, 1, 1), Vector4(-374, -272, -212, -212))
	add_child(zoom)


func bind(value: BattleController) -> void:
	if battle and battle.telemetry_changed.is_connected(update):
		battle.telemetry_changed.disconnect(update)
	if battle and battle.notice.is_connected(show_notice):
		battle.notice.disconnect(show_notice)
	battle = value
	overlay.battle = value
	battle.telemetry_changed.connect(update)
	battle.notice.connect(show_notice)
	mission_label.text = Loc.sector(battle.mission.sector) + " / " + battle.mission.title
	currency_label.text = "%s %s  /  %s %s" % [Loc.t("credits"), Loc.number(Profile.data.coins), Loc.t("stars"), Loc.number(Profile.data.stars)]
	update(battle.telemetry())


func update(value: Dictionary) -> void:
	data = value
	elevation_label.text = Loc.decimal(value.elevation) + "°"
	bearing_label.text = Loc.digits("%05.1f" % fposmod(value.yaw, 360.0)) + "°"
	range_label.text = Loc.t("hud_predicted") % [Loc.number(roundi(value.predicted_range)), Loc.decimal(value.flight_time)]
	target_label.text = value.target_name
	target_health.value = value.target_health
	objective_label.text = Loc.t("hud_primary") % [Loc.number(value.objectives), Loc.number(value.required)] + "     " + Loc.clock(value.time)
	status_label.text = Loc.state(value.state)
	status_label.add_theme_color_override("font_color", UITheme.GREEN if value.state == "READY" else UITheme.ACCENT)
	fire_button.disabled = value.state != "READY" or int(value.ammo.get(value.selected_ammo, 0)) <= 0
	reload_button.disabled = value.state != "EMPTY" or int(value.ammo.get(value.selected_ammo, 0)) <= 0
	reload_button.text = Loc.t("hud_reload_time") % Loc.decimal((1.0 - value.reload) * battle.loadout.reload_seconds()) if value.state == "RELOADING" else Loc.t("hud_reload")
	camera_button.text = Loc.t("hud_camera") % Loc.camera(value.camera)
	for id in ammo_buttons:
		var button: Button = ammo_buttons[id]
		button.text = Loc.t("hud_shell_" + id) + "  " + Loc.digits("%02d" % int(value.ammo.get(id, 0)))
		button.button_pressed = id == value.selected_ammo
		button.disabled = int(value.ammo.get(id, 0)) <= 0


func show_notice(message: String) -> void:
	notice_label.text = message
	notice_time = 3.5


func _process(delta: float) -> void:
	notice_time = maxf(0.0, notice_time - delta)
	notice_label.modulate.a = minf(1.0, notice_time)
	performance_label.visible = Profile.data.settings.show_performance
	if performance_label.visible:
		var snapshot: Dictionary = Graphics.snapshot()
		performance_label.text = Loc.t("hud_perf") % [Loc.number(roundi(snapshot.fps)), Loc.t("quality_" + String(snapshot.tier)), Loc.number(int(snapshot.draw_calls)), Loc.decimal(float(snapshot.scale) * 100, 0), Loc.number(int(snapshot.objects))]
